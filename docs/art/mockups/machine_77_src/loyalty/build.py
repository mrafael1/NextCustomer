"""Builds docs/art/mockups/machine_77_loyalty.html from template.html (#77 prep, 2026-10-20).

Inlines the sprites (machine_77_src/assets) as data URIs, the measured numbers from
machine_77_src/balance.json, and the one draw process (flow/draw77.js + flow/flow_data.json) for the odds card. Run: python docs/art/mockups/machine_77_src/loyalty/build.py
"""

import base64
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent
OUT = SRC.parent / "machine_77_loyalty.html"
SPRITES = ["banana", "coupon_slip", "eggs", "stamp_ring", "stamp_ring_empty"]


def main() -> None:
    images = {
        name: "data:image/png;base64,"
        + base64.b64encode((SRC / "assets" / f"{name}.png").read_bytes()).decode()
        for name in SPRITES
    }
    balance = json.loads((SRC / "balance.json").read_text(encoding="utf-8"))
    page = (HERE / "template.html").read_text(encoding="utf-8")
    # the odds card runs the one draw process (flow/draw77.js) on the flow page's data (run flow/gen_flow.py first)
    draw = (SRC / "flow" / "draw77.js").read_text(encoding="utf-8")
    data = (SRC / "flow" / "flow_data.json").read_text(encoding="utf-8")
    page = page.replace("__IMAGES__", json.dumps(images)).replace("__BALANCE__", json.dumps(balance))
    page = page.replace("__DRAW77__", draw).replace("__DATA__", data)
    OUT.write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
