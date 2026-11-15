# Ben Costello · CAD portfolio

Live site: https://benfredcostello.github.io/cad-portfolio/

Each folder in `projects/` is one project:

| Path | What goes there |
|---|---|
| `project.json` | Title, year, course, summary, description, highlights, tools. Set `"hidden": true` to keep a project off the site. |
| `models/` | `.stl` files shown in the 3D viewer |
| `cad/` | Native Inventor/STEP files offered as downloads |
| `docs/` | Drawings and reports (PDF) |
| `img/` | Photos and renders |

After changing projects, run `python build.py` to refresh `manifest.json`, then push to `main`. GitHub Pages serves the site straight from the branch (the sync script does both for you).

## Automatic sync
`tools/setup.ps1` clones this repo to `Documents\cad-portfolio` and schedules `tools/sync.ps1` daily. The sync:
1. copies new CAD files from Downloads and OneDrive into `_inbox\` (never published). Move the ones you want into a project's `cad\` folder.
2. exports STLs with Inventor for any published part that doesn't have one.
3. commits and pushes.

Patterns in `tools/ignore.txt` are never picked up.
