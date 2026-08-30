#!/bin/bash
# =============================================================================
# Last Call - refresh and publish
# -----------------------------------------------------------------------------
# Double-click this file in Finder. It does the whole job:
#   1. Rebuilds the data file from your workbook
#   2. Rebuilds the app page from the dashboard template
#   3. Stamps a new cache version so your phone knows to fetch the new data
#   4. Shows you what changed, asks, then publishes to GitHub
#
# If any step fails it stops and publishes nothing - a half-published app is
# worse than one showing yesterday's numbers.
# =============================================================================

set -e                                  # stop on the first error
cd "$(dirname "$0")"                    # work from this folder, wherever it is

APP="$(pwd)"
BAR="$(cd .. && pwd)"                   # the Cocktails folder, one level up
BOOK="$BAR/CocktailsClaude-Slim.xlsx"

echo ""
echo "=== Last Call ==============================================="
echo ""

# --- 1. Check the pieces are all here ----------------------------------------
command -v python3 >/dev/null || { echo "python3 not found."; exit 1; }
command -v git     >/dev/null || { echo "git not found."; exit 1; }
[ -f "$BOOK" ]                || { echo "Workbook not found at: $BOOK"; exit 1; }

# --- 2. Rebuild the data -----------------------------------------------------
echo "Reading the workbook..."
python3 "$BAR/Tools/build_cocktails_dashboard.py" --src "$BOOK" --json "$APP/cocktails.json"

# --- 3. Rebuild the app page -------------------------------------------------
echo "Rebuilding the app..."
python3 "$BAR/Tools/build_web_app.py" \
        --template "$BAR/Tools/dashboard_template.html" \
        --out "$APP/index.html"

# --- 4. Stamp a new cache version -------------------------------------------
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
print("Cache version set to", stamp)
PY

# --- 5. Show what changed, then ask ------------------------------------------
echo ""
echo "Changed files:"
git status --short
echo ""
read -p "Publish these to GitHub? [y/N] " REPLY
case "$REPLY" in
  [yY]*) ;;
  *) echo "Stopped. Nothing was published."; exit 0 ;;
esac

# --- 6. Publish --------------------------------------------------------------
git add -A
git commit -m "Refresh bar data - $STAMP"
git push
echo ""
echo "Published. On your phone: close the app fully from the app switcher"
echo "and reopen it, or it will keep showing the copy it already had."
echo ""
