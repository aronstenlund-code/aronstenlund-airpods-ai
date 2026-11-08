"""T3 (Toby): helpers for scripts/apptest/screens.sh.

  screens_index.py rename <dir>   rename exported xcresult attachments to their attachment names (manifest.json)
  screens_index.py index <out>    write <out>/index.html: one row per screen, one column per config
"""
import html
import json
import os
import re
import sys
from pathlib import Path

SUFFIX = re.compile(r"^(?P<name>.+?)_\d+_[0-9A-Fa-f-]{36}(?P<ext>\.\w+)$")


def rename(folder: Path) -> None:
    manifest = folder / "manifest.json"
    if not manifest.exists():
        print(f"no manifest.json in {folder}")
        return
    entries = json.loads(manifest.read_text(encoding="utf-8"))
    for test in entries:
        for item in test.get("attachments", []):
            exported = folder / item["exportedFileName"]
            if not exported.exists():
                continue
            human = item.get("suggestedHumanReadableName") or exported.name
            match = SUFFIX.match(human)
            if match:
                target = match["name"] + match["ext"]
            else:
                target = human
            if target.endswith(".txt") is False and exported.suffix == ".txt":
                target += ".txt"
            exported.rename(folder / target)
    # Keep the artifact small: screenshots and text only (screen recordings and UI snapshots stay in the xcresult).
    for item in folder.iterdir():
        if item.is_file() and item.suffix not in (".png", ".txt", ".json"):
            item.unlink()
        elif item.is_dir():
            import shutil
            shutil.rmtree(item)


def config_and_screen(file_name: str):
    # <config>-<NN>-<screen>.png ; config names contain dashes, NN is two digits.
    match = re.match(r"^(?P<config>.+?)-(?P<n>\d{2})-(?P<screen>.+)\.png$", file_name)
    if not match:
        return None
    return match["config"], int(match["n"]), match["screen"]


def index(out: Path) -> None:
    configs = sorted(p.name for p in out.iterdir() if p.is_dir() and p.name != "logs")
    screens: dict[str, dict[str, str]] = {}
    order: dict[str, int] = {}
    for config in configs:
        for png in sorted((out / config).glob("*.png")):
            parsed = config_and_screen(png.name)
            if not parsed:
                continue
            _, number, screen = parsed
            screens.setdefault(screen, {})[config] = f"{config}/{png.name}"
            order[screen] = min(order.get(screen, 999), number)
    rows = sorted(screens, key=lambda s: (order[s], s))
    parts = [
        "<!doctype html><meta charset='utf-8'><title>Lumen skärmbilder</title>",
        "<style>body{font:14px system-ui;margin:16px;background:#f4f4f4}table{border-collapse:collapse}"
        "td,th{border:1px solid #ccc;padding:6px;vertical-align:top;background:#fff}"
        "img{width:200px;display:block}th{position:sticky;top:0;background:#eee}</style>",
        "<h1>Lumen skärmbilder (T3)</h1><p>Simulator only, never a verification on a device.</p>",
        "<table><tr><th>Skärm</th>" + "".join(f"<th>{html.escape(c)}</th>" for c in configs) + "</tr>",
    ]
    for screen in rows:
        cells = []
        for config in configs:
            path = screens[screen].get(config)
            cells.append(f"<td><a href='{html.escape(path)}'><img src='{html.escape(path)}' loading='lazy'></a></td>"
                         if path else "<td>–</td>")
        parts.append(f"<tr><th>{html.escape(screen)}</th>{''.join(cells)}</tr>")
    parts.append("</table>")
    (out / "index.html").write_text("\n".join(parts), encoding="utf-8")
    print(f"index.html: {len(rows)} screens x {len(configs)} configs")


if __name__ == "__main__":
    command, target = sys.argv[1], Path(sys.argv[2])
    if command == "rename":
        rename(target)
    elif command == "index":
        index(target)
    else:
        sys.exit(f"unknown command {command}")
