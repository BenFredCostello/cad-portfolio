"""Builds manifest.json from the projects/ folder.

Each project is a folder in projects/ containing:
  project.json   title, year, context, summary, description, highlights, tools, order, cover
  models/        .stl files shown in the 3D viewer
  cad/           native CAD files (.ipt, .iam, .step, ...) offered as downloads
  docs/          drawings and reports (.pdf)
  img/           photos and renders (.jpg, .png)

Run: python build.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent
PROJECTS = ROOT / "projects"


def files(folder: Path, exts=None):
    if not folder.is_dir():
        return []
    out = []
    for f in sorted(folder.iterdir()):
        if f.is_file() and (exts is None or f.suffix.lower() in exts):
            out.append({"name": f.name, "path": f.relative_to(ROOT).as_posix(), "size": f.stat().st_size})
    return out


def main():
    projects = []
    for d in sorted(PROJECTS.iterdir()):
        meta_file = d / "project.json"
        if not d.is_dir() or not meta_file.exists():
            continue
        meta = json.loads(meta_file.read_text(encoding="utf-8"))
        if meta.get("hidden"):
            continue
        meta["slug"] = d.name
        meta["models"] = files(d / "models", {".stl"})
        meta["cad"] = files(d / "cad")
        meta["docs"] = files(d / "docs", {".pdf"})
        meta["images"] = files(d / "img", {".jpg", ".jpeg", ".png", ".webp"})
        cover = meta.get("cover")
        meta["cover"] = f"projects/{d.name}/{cover}" if cover else (meta["images"][0]["path"] if meta["images"] else "")
        projects.append(meta)
    projects.sort(key=lambda p: (p.get("order", 99), -int(p.get("year", 0))))
    (ROOT / "manifest.json").write_text(json.dumps({"projects": projects}, indent=1), encoding="utf-8")
    print(f"manifest.json: {len(projects)} projects")


if __name__ == "__main__":
    main()
