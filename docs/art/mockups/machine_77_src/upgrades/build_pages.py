"""Builds docs/art/mockups/machine_77_upgrades.html (and _bay.html) with the tier sprites as data URIs."""
import base64, json, re
from pathlib import Path
HERE = Path(__file__).resolve().parent
MOCK = HERE.parents[1]
PNG = HERE / "png" / "items_v2"
img = {p.stem: "data:image/png;base64," + base64.b64encode(p.read_bytes()).decode() for p in sorted(PNG.glob("*.png")) if not p.stem.endswith("_r1")}  # round-1 copies stay out
tier_js = (HERE / "tier.js").read_text(encoding="utf-8")

def fill(t):
    return t.replace("/*TIER_JS*/", tier_js).replace("/*IMG*/", json.dumps(img)).replace("/*TIER_CSS*/", "")

page = fill((HERE / "upgrades_template.html").read_text(encoding="utf-8"))
(MOCK / "machine_77_upgrades.html").write_text(page, encoding="utf-8")
print("wrote machine_77_upgrades.html", len(page))
bay_t = HERE / "bay_patch.py"
if bay_t.exists():
    ns = {"HERE": HERE, "MOCK": MOCK, "img": img, "tier_js": tier_js}
    exec(bay_t.read_text(encoding="utf-8"), ns)
