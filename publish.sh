#!/bin/bash
# =============================================================================
# Last Call - rebuild and publish
# -----------------------------------------------------------------------------
# Two ways to run it:
#
#   ./publish.sh              interactive - shows you the changes and asks first
#   ./publish.sh --auto       unattended  - used by the folder watcher, no prompts
#
# In --auto mode the passphrase comes from the macOS Keychain, so nothing has to
# stop and ask. Set that up once with:
#
#   security add-generic-password -a "$USER" -s cocktails-web -w
#
# If any step fails the whole thing stops and publishes nothing. A half-published
# app is worse than one showing yesterday's numbers.
# =============================================================================

set -euo pipefail

AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1

cd "$(dirname "$0")"
APP="$(pwd)"
BAR="$(cd .. && pwd)"
BOOK="$BAR/CocktailsClaude-Slim.xlsx"
KEYCHAIN_SERVICE="cocktails-web"
LOG="$HOME/Library/Logs/cocktailsweb.log"

mkdir -p "$(dirname "$LOG")"
say(){ echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" | tee -a "$LOG"; }

# Run a command, sending its output where it can actually be seen.
# Unattended: to the log. By hand: to the screen AND the log - otherwise a
# failure looks like the script simply stopping, with no clue why.
run(){
  if [ "$AUTO" = "1" ]; then
    "$@" >>"$LOG" 2>&1
  else
    "$@" 2>&1 | tee -a "$LOG"
  fi
}

# --- Only one run at a time ---------------------------------------------------
# mkdir is atomic, which makes it a reliable lock. Without this, saving the
# workbook twice quickly would start two publishes that fight over git.
LOCK="$APP/.publish.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  say "Another publish is already running - skipping."
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

STAMP_FILE="$APP/.last-publish"

say "--- publish start (auto=$AUTO) ---"

# Unattended runs bail out early if there is genuinely nothing new. Running by
# hand always rebuilds, so you can force a publish when you want one.
if [ "$AUTO" = "1" ] && [ -f "$STAMP_FILE" ] && [ ! "$BOOK" -nt "$STAMP_FILE" ]; then
  say "Workbook unchanged since the last publish - nothing to do."
  exit 0
fi

# --- Checks -------------------------------------------------------------------
for c in python3 git; do command -v $c >/dev/null || { say "ERROR: $c not found"; exit 1; }; done

# Check the libraries BEFORE doing any work, so a missing one is an obvious
# message rather than a stack trace buried three steps in.
for mod in openpyxl cryptography; do
  python3 -c "import $mod" 2>/dev/null || {
    say "ERROR: python3 is missing the '$mod' package."
    say "       Fix it with:  python3 -m pip install $mod"
    say "       (or add --user if it complains about an externally managed environment)"
    exit 1
  }
done
[ -f "$BOOK" ] || { say "ERROR: workbook not found at $BOOK"; exit 1; }

# --- Let the workbook settle --------------------------------------------------
# Excel and OneDrive both touch the file several times while saving. Waiting for
# the size to stop changing avoids reading a half-written file.
if [ "$AUTO" = "1" ]; then
  prev=""; for _ in 1 2 3 4 5 6 7 8 9 10; do
    cur=$(stat -f%z "$BOOK" 2>/dev/null || echo 0)
    [ "$cur" = "$prev" ] && [ -n "$prev" ] && break
    prev="$cur"; sleep 3
  done
fi

# --- 1. Build the data (to a temp file OUTSIDE the repo) ----------------------
# It must not land in this folder: the commit below adds everything here, and
# the PLAIN data is exactly what we do not want published.
PLAIN="$(mktemp -t cocktails-plain)"
trap 'rm -f "$PLAIN"; rmdir "$LOCK" 2>/dev/null || true' EXIT

say "Reading the workbook..."
run python3 "$BAR/Tools/build_cocktails_dashboard.py" --src "$BOOK" --json "$PLAIN"

# --- 2. Encrypt it ------------------------------------------------------------
say "Encrypting..."
if [ "$AUTO" = "1" ]; then
  run python3 "$BAR/Tools/encrypt_data.py" --in "$PLAIN" --out "$APP/cocktails.json" \
          --keychain "$KEYCHAIN_SERVICE"
else
  python3 "$BAR/Tools/encrypt_data.py" --in "$PLAIN" --out "$APP/cocktails.json" \
          --keychain "$KEYCHAIN_SERVICE" 2>/dev/null \
    || python3 "$BAR/Tools/encrypt_data.py" --in "$PLAIN" --out "$APP/cocktails.json"
fi
rm -f "$PLAIN"

# --- 3. Rebuild the app page --------------------------------------------------
say "Rebuilding the app..."
run python3 "$BAR/Tools/build_web_app.py" \
        --template "$BAR/Tools/dashboard_template.html" \
        --out "$APP/index.html"

# --- 4. Also refresh the desktop dashboard ------------------------------------
run python3 "$BAR/Tools/build_cocktails_dashboard.py" \
        --src "$BOOK" --out "$BAR/Cocktails-Dashboard.html"

# --- 5. Stamp a new cache version ---------------------------------------------
# Without this the phone keeps serving the copy it already has, and you would
# swear the app was broken when it is only being stubborn.
STAMP="lastcall-$(date +%Y%m%d-%H%M)"
python3 - "$APP/sw.js" "$STAMP" <<'PY'
import io, re, sys
path, stamp = sys.argv[1], sys.argv[2]
s = io.open(path, encoding="utf-8").read()
s = re.sub(r'const CACHE_VERSION = "[^"]*";',
           'const CACHE_VERSION = "%s";' % stamp, s, count=1)
io.open(path, "w", encoding="utf-8").write(s)
PY

# --- 6. Publish ---------------------------------------------------------------
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git status --porcelain)" ]; then
  if [ "$AUTO" = "0" ]; then
    echo ""; git status --short; echo ""
    read -p "Publish these to GitHub? [y/N] " REPLY
    case "$REPLY" in [yY]*) ;; *) say "Stopped. Nothing published."; exit 0 ;; esac
  fi
  git add -A
  git commit -q -m "Refresh bar data - $STAMP"
  git push -q
  say "Published $STAMP"
  [ "$AUTO" = "0" ] && echo "
Published. On your phone: close the app fully from the app switcher and reopen."
else
  say "Nothing changed - nothing published."
fi

# Remember how far we got, so the next poll can tell whether there is new work.
touch "$STAMP_FILE"

say "--- publish done ---"
