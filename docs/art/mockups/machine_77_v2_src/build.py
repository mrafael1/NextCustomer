"""Builds docs/art/mockups/machine_77_v2.html from machine_77_v2_template.html.

Every 'folder/name.png' string in the template is a sprite from art/; they are inlined as data URIs into the IMG
table (with their sizes), so the page needs only the repo's fonts next to it. Standard library only.
Run: python docs/art/mockups/machine_77_v2_src/build.py
"""

import base64
import json
import re
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ART = ROOT / "art"


def main() -> None:
    template = (HERE / "machine_77_v2_template.html").read_text(encoding="utf-8")
    names = sorted(set(re.findall(r"'([a-z0-9_]+/[a-z0-9_]+\.png)'", template)))
    table = {}
    for name in names:
        data = (ART / name).read_bytes()
        width, height = struct.unpack(">II", data[16:24])
        uri = "data:image/png;base64," + base64.b64encode(data).decode("ascii")
        table[name] = {"src": uri, "w": width, "h": height}
    page = template.replace("__IMAGES__", json.dumps(table))
    out = HERE.parent / "machine_77_v2.html"
    out.write_text(page, encoding="utf-8")
    print(f"{out} ({len(names)} sprites, {len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
