# Last Call

Reed's home bar as an installable web app. Built from the same workbook the
cocktail dashboard uses; no Excel connection at run time.

Live at `https://reedone33.github.io/CocktailsWeb/`.

## How it fits together

The workbook stays the master copy. When it changes, a watcher rebuilds the
data, encrypts it, and publishes. Nothing on the internet can touch the workbook.

    CocktailsClaude-Slim.xlsx  ->  build  ->  encrypt  ->  cocktails.json  ->  the app

Logging a drink happens in Excel or through the `cocktail-log` Claude skill.
The app itself is read-only.

## What's in this folder

| File | What it is |
|---|---|
| `index.html` | The whole app - layout, tabs, charts, the bar grid, the unlock screen |
| `cocktails.json` | The published data, encrypted (AES-256-GCM), ~146 KB |
| `vendor/chart.umd.js` | Chart.js, kept locally so charts work with no signal |
| `sw.js` | Service worker. Carries `CACHE_VERSION`, restamped on every publish |
| `publish.sh` | Does the actual work. `--auto` for the watcher, no flag to run it by hand |
| `update.command` | Double-click to publish manually. Just calls `publish.sh` |
| `com.reed.cocktailsweb.plist` | The watcher definition (see setup below) |
| `manifest.webmanifest`, `icons/` | Home screen name and icon |

The build scripts live one folder up in `../Tools/`, shared with the older
`Cocktails-Dashboard.html` so there is only ever one copy of the logic.

**`index.html` is generated.** To change the app, edit `../Tools/dashboard_template.html`
or `../Tools/build_web_app.py` and rebuild - editing `index.html` directly gets
overwritten on the next publish.

## Automatic publishing

A `launchd` job watches the workbook. Save it - or let the `cocktail-log` skill
write to it - and within about a minute the app is rebuilt and pushed. No
interaction, as long as the Mac is on.

### Requirements

The Mac's `python3` needs two packages. Install them with the interpreter itself,
not with `pip3` - on this Mac they are not the same Python:

    python3 -m pip install openpyxl cryptography

`publish.sh` checks for both before doing anything and names the fix if either
is missing.

### One-time setup

1. **Store the passphrase in the Keychain.** It is read from there so the
   publisher never has to stop and ask. The Keychain is encrypted and stays on
   this Mac; a file here would sync to OneDrive.

       security add-generic-password -a "$USER" -s cocktails-web -w

   It prompts for the value, so the passphrase stays out of your shell history.

2. **Install the watcher.**

       cp "com.reed.cocktailsweb.plist" ~/Library/LaunchAgents/
       launchctl load ~/Library/LaunchAgents/com.reed.cocktailsweb.plist

3. **Test it** by touching the workbook and watching the log:

       tail -f ~/Library/Logs/cocktailsweb.log

### Turning it off

    launchctl unload ~/Library/LaunchAgents/com.reed.cocktailsweb.plist

### When it doesn't fire

- `~/Library/Logs/cocktailsweb.log` is the script's own log; check it first.
- `~/Library/Logs/cocktailsweb-launchd.log` catches anything that failed before
  the script got going - usually a wrong path or a missing command.
- A stale `.publish.lock` folder blocks every run. Delete it if a publish was
  interrupted.
- `launchctl list | grep cocktailsweb` shows whether the job is loaded.

## The passphrase

The site is public - GitHub Pages cannot serve a private repository on the free
plan - so the data is encrypted and the URL alone is useless. The app asks for
the passphrase on first open. Tick **Remember on this device** and it won't ask
again on that device; it stores the passphrase in that browser's local storage,
which is fine on your own phone and not fine on a shared computer.

Forgetting the passphrase means republishing with a new one. There is no
recovery - that is the point.

## Installing it on your phone

Open the site in Safari, tap Share, then "Add to Home Screen".

**After a refresh, close the app fully from the app switcher and reopen it.**
The service worker serves the copy it already has until you do. This is the
usual reason numbers look old.

## Things worth knowing

- **The repo must stay public.** Pages won't serve a private repo on the free
  plan. The encryption is what protects the data, not the repo visibility.
- **Amount Remaining is mixed units.** Most bottles hold a 0-1 fraction, but 34
  hold a plain count (Underberg 10, Beefeater 80). The app shows a bar for
  fractions and the raw number for anything above 1.
- **`publish.sh` runs `git add -A`**, so anything left lying about in this folder
  gets published. The plain data is written to a temp file outside the folder
  for exactly this reason. Keep it clean.
- **Don't let a Cowork session run git in this folder.** It leaves a
  `.git/index.lock` it cannot delete, which breaks the next commit from GitHub
  Desktop. If that happens: `rm -f .git/index.lock`.
