"""Writes shots/index.json from specs.txt, run_log.txt and the shots present (polish audit)."""

import json
import pathlib

BASE = pathlib.Path(__file__).parent
SIZES = ["1920x1080", "1280x720"]
SCENES = {
    "sc": "res://debug/screen_capture/screen_capture.tscn",
    "au": "res://debug/screen_capture/capture_audit.tscn",
}

sources = {}
for line in (BASE / "run_log.txt").read_text().splitlines():
    parts = line.split()
    if len(parts) == 3 and parts[0] == "OK":
        sources[parts[1]] = parts[2]

shots = []
missing = []
for line in (BASE / "specs.txt").read_text().splitlines():
    if not line.strip():
        continue
    area, state, kind, args = line.split("|", 3)
    for size in SIZES:
        name = f"{area}_{state}_{size}"
        file = BASE / "shots" / f"{name}.png"
        capture_arg = "--out=<file>" if kind == "au" else "--capture=<folder>"
        command = f"godot --path . --resolution {size} {SCENES[kind]} -- {capture_arg} {args}".strip()
        entry = {
            "file": f"{name}.png",
            "area": area,
            "state": state,
            "size": size,
            "produced_by": command,
            "tool_file_name": sources.get(name, ""),
        }
        if file.exists():
            shots.append(entry)
        else:
            missing.append(entry)

(BASE / "shots" / "index.json").write_text(
    json.dumps({"shots": shots, "missing": missing}, indent=1) + "\n"
)
print(f"{len(shots)} shots, {len(missing)} missing")
for entry in missing:
    print("missing", entry["file"])
