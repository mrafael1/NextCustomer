"""Builds docs/art/mockups/family_identities_128.html from template.html and scorer.js.

Inlines the fonts, the item sprites and the family glyphs as data: URIs (one self-contained page), and runs
the ordering study once with node (study_dump.js) so the page opens with its numbers. Run from anywhere:
    python docs/art/mockups/family_identities_128_src/build.py
"""

from __future__ import annotations

import base64
import json
import re
import subprocess
from pathlib import Path

SRC = Path(__file__).resolve().parent
ROOT = SRC.parents[3]
OUT = SRC.parent / "family_identities_128.html"
GLYPHS = {
    "Breakfast": "art/icons/family_breakfast.png", "Clearance": "art/icons/family_clearance.png",
    "Dairy": "art/icons/family_dairy.png", "Bakery": "art/icons/aisle_bakery.png",
    "Produce": "art/icons/aisle_fruit_and_veg.png", "Snack": "art/icons/aisle_snacks.png",
    "Household": "art/icons/aisle_household.png", "Frozen": "art/icons/aisle_cold_cases.png",
}


def data_uri(path: Path) -> str:
    mime = "font/ttf" if path.suffix == ".ttf" else "image/png"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def main() -> None:
    scorer = (SRC / "scorer.js").read_text(encoding="utf-8")
    ids = re.findall(r"^  (\w+):\s+\{name:", scorer, re.M)
    sprites = {i: data_uri(ROOT / "art/items_v2" / f"{i}.png") for i in ids}
    glyphs = {k: data_uri(ROOT / v) for k, v in GLYPHS.items()}
    study = subprocess.run(["node", str(SRC / "study_dump.js")], check=True, capture_output=True, text=True).stdout
    json.loads(study)
    page = (SRC / "template.html").read_text(encoding="utf-8")
    page = page.replace("__SCORER_JS__", scorer)
    page = page.replace("__SPRITES__", json.dumps(sprites)).replace("__GLYPHS__", json.dumps(glyphs))
    page = page.replace("__STUDY__", study.strip())
    page = re.sub(r"__ASSET:([^_][^\s'\"()]*?)__", lambda m: data_uri(ROOT / m.group(1)), page)
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB, {len(sprites)} sprites)")


if __name__ == "__main__":
    main()
