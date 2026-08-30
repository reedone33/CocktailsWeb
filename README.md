# Last Call

Reed's home bar as an installable web app. Built from the same workbook the
cocktail dashboard uses; no Excel connection at run time.

Live at `https://reedone33.github.io/CocktailsWeb/` once GitHub Pages is on.

## How it fits together

The workbook stays the master copy. A build script reads it and writes a small
data file that the app fetches. Nothing on the internet can touch the workbook.

    CocktailsClaude-Slim.xlsx  ->  build script  ->  cocktails.json  ->  the app

## What's in this folder

| File | What it is |
|---|---|
| `index.html` | The whole app - layout, tabs, charts, the bar grid |
| `cocktails.json` | The published data, ~765 KB, rebuilt from the workbook |
| `vendor/chart.umd.js` | Chart.js, kept locally so charts work with no signal |
| `sw.js` | Service worker. Carries `CACHE_VERSION`, restamped on every publish |
| `manifest.webmanifest` | Home screen name and icon |
| `icons/` | App icons, carried over from the old iOS app |
| `update.command` | Double-click: rebuild, restamp, commit, push |

The two build scripts live one folder up, in `../Tools/`, alongside the
workbook. That is deliberate - they are shared with the older
`Cocktails-Dashboard.html`, so there is only ever one copy of the logic.

## Refreshing it

Double-click `update.command`. It rebuilds, shows you what changed, asks before
publishing, and stops on the first error.

**On your phone, close the app fully from the app switcher and reopen it.**
The service worker serves the copy it already has until you do, which is the
usual reason numbers look old after a refresh.

## Installing it on your phone

Open the site in Safari, tap Share, then "Add to Home Screen". It gets its own
icon and opens without browser chrome.

## The tabs

**Bar** is the landing screen: every spirit type you own as a tile, tap through
to a searchable, sortable list. It shows only bottles with something left in
them and some alcohol in them - the proof test is what keeps ice, egg white and
lemon wedges out.

The other ten - Infographic, Ingredients, Recipes, Drink History, Consumption,
Pour Costs, Inventory & Costs, Rums, Foursquare, Unused - are carried over from
the dashboard unchanged.

## Things worth knowing

- **The repo has to stay public.** GitHub Pages only publishes from a public
  repo on the free plan. Nothing here is sensitive except bottle prices; if
  that changes, encrypt `cocktails.json` rather than making the repo private
  (a private repo just takes the site offline).
- **Amount Remaining is mixed units.** Most bottles hold a 0-1 fraction, but 34
  hold a plain count (Underberg 10, Beefeater 80). The app shows a bar for
  fractions and the raw number for anything above 1.
- **Don't let a Cowork session run git in this folder.** It leaves a
  `.git/index.lock` behind that it cannot delete, which then breaks the next
  commit from GitHub Desktop. If that happens: `rm -f .git/index.lock`.
- **`update.command` runs `git add -A`**, so anything left lying about in this
  folder gets published. Keep it clean.
