"""Generates the #56 results mock-ups (final receipt), two directions.

Run from the repo root:  python docs/art/mockups/screens_src/gen_results/gen.py
Writes docs/art/mockups/screens_results_a.html, _a_over, _a_printing, screens_results_b.html, _b_over,
and the cork tile docs/art/mockups/screens_src/assets/results_cork.png (palette colours only).
The receipt lines are built with FinalReceipt's exact formats ("%3d  %-13s  %-4s  %s", WIDTH 44).
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path("docs/art/mockups")
WIDTH = 44

INK = "#2b2420"

# ---------------------------------------------------------------- receipt lines (FinalReceipt)
WON_SHIFTS = [
    (1, 41, 34, True, "Tea bags", ""),
    (2, 52, 35, True, "Multipack", "upgrade Coupon engine"),
    (3, 60, 53, True, "skipped", "inspection Spot check"),
    (4, 88, 61, True, "Strawberries", "upgrade Slot engine"),
    (5, 95, 73, True, "2 for 1", "inspection Short belt"),
    (6, 131, 98, True, "Croissant", "upgrade Big basket"),
    (7, 140, 111, True, "Birthday candles", "inspection Coupon slot closed"),
    (8, 151, 120, True, "—", ""),
]
LOST_SHIFTS = WON_SHIFTS[:5] + [(6, 86, 98, False, "—", "")]


def coin_line(left: str, right: str) -> str:
    return left + " " * max(WIDTH - len(left) - len(right), 1) + right


def receipt(won: bool) -> list[tuple[str, str, bool]]:
    """(text, tone, failed) in print order, the headline first."""
    shifts = WON_SHIFTS if won else LOST_SHIFTS
    out: list[tuple[str, str, bool]] = [("RUN WON!" if won else "RUN OVER", "head", False)]
    out.append(("-" * WIDTH, "rule", False))
    overtime = 0
    passed = 0
    for n, total, quota, ok, card, detail in shifts:
        main = "%3d  %-13s  %-4s  %s" % (n, "€%d / €%d" % (total, quota), "pass" if ok else "fail", card)
        out.append((main, "shift", not ok))
        if detail:
            out.append((" " * 5 + detail, "detail", not ok))
        if ok:
            passed += 1
            overtime += total - quota
    if not won:
        out.append(("Shift 6 / 8: short by €12", "short", True))
    out.append(("-" * WIDTH, "rule", False))
    shift_coins = passed // 4  # the sample's payout: 8 passed +2, 5 passed +1
    owned = 3 + shift_coins
    out.append((coin_line("Shifts passed %d" % passed, "+%d" % shift_coins), "coins", False))
    out.append((coin_line("Overtime €%d" % overtime, "+0"), "coins", False))
    out.append((coin_line("COINS +%d" % shift_coins, "you have %d" % owned), "total", False))
    return out


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;")


# ---------------------------------------------------------------- shared pieces
FONTS = """
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
@font-face { font-family: JBMono; src: url(../../../fonts/JetBrainsMono-Regular.ttf); }
"""

BASE_CSS = """
:root {
  --ink: #2b2420; --ink-light: #4a3f38; --muted: #8a8172; --paper: #fbf7ee; --cream: #f3e9d2;
  --cream-shade: #ddcba5; --mustard: #e2b33c; --mustard-light: #f1d27a; --mustard-pale: #faecbc;
  --tomato: #d9534f; --tomato-dark: #a83a3c; --tomato-light: #ec8a6e; --teal: #4f9a94; --teal-panel: #2a4d4b; --teal-dark: #1f3b3a;
  --good: #5fae5a; --good-dark: #3d7a45; --gold: #ffcf3f; --brass: #8a5d1a;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 1280px; height: 720px; overflow: hidden; background: var(--teal-dark); }
img, .px { image-rendering: pixelated; }
.stage { position: relative; width: 1280px; height: 720px; font-family: Atkinson, sans-serif; color: var(--ink); overflow: hidden; }
.abs { position: absolute; }
.num { font-family: Atkinson; font-weight: 750; }

/* top bar: the game's chip row (TopBar), unshaded and clickable over the results */
.topbar { left: 0; top: 0; width: 1280px; height: 56px; background: var(--teal-dark); border-bottom: 2px solid var(--ink); z-index: 20; }
.tbrow { left: 16px; top: 9px; width: 1248px; height: 38px; display: flex; gap: 12px; z-index: 21; }
.chip { position: relative; height: 38px; display: flex; align-items: center; gap: 8px; padding: 0 12px; flex: none;
  border: 6px solid transparent; border-image: url(screens_src/assets/chip.png) 3 fill / 6px stretch; image-rendering: pixelated; color: var(--paper); }
.chip .k { font-family: Pixelify; font-size: 15px; letter-spacing: 1px; color: var(--mustard-pale); }
.chip .v { font-family: Atkinson; font-weight: 750; font-size: 20px; }
.bar { flex: 1; height: 14px; background: rgba(0,0,0,.35); border: 2px solid var(--ink); position: relative; }
.bar i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--mustard); box-shadow: inset 0 3px 0 var(--mustard-light); }
.tstamp { position: relative; width: 26px; height: 26px; }
.tstamp img { position: absolute; inset: 0; width: 26px; height: 26px; }
.tstamp b { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-family: Atkinson; font-weight: 750;
  font-size: 9px; color: var(--mustard-pale); }
.tbtn { position: relative; height: 38px; padding: 0 12px; display: flex; align-items: center; gap: 6px; font-family: Pixelify; font-size: 16px; flex: none;
  color: var(--paper); border: 6px solid transparent; border-image: url(screens_src/assets/top_button.png) 3 fill / 6px stretch; image-rendering: pixelated; }

/* framed buttons (FramedButton): button.png for the primary action, sign.png for secondary ones; 9-slice margin 3 at 2x */
.fbtn { position: absolute; display: flex; align-items: center; justify-content: center; font-family: Pixelify; color: var(--paper);
  border: 6px solid transparent; image-rendering: pixelated; z-index: 12;
  text-shadow: 3px 0 0 var(--ink), -3px 0 0 var(--ink), 0 3px 0 var(--ink), 0 -3px 0 var(--ink), 2px 2px 0 var(--ink), -2px 2px 0 var(--ink), 2px -2px 0 var(--ink), -2px -2px 0 var(--ink); }
.fbtn.primary { border-image: url(screens_src/assets/button.png) 3 fill / 6px stretch; }
.fbtn.sign { border-image: url(screens_src/assets/sign.png) 3 fill / 6px stretch; }
.fbtn::after { content: ""; position: absolute; left: 0; right: -6px; bottom: -12px; height: 6px; background: rgba(20,10,6,.4); }

/* the receipt's mono lines (ResultsPanel: 16 px lines, 13 px dim details, WIDTH 44) */
.lines { font-family: JBMono; white-space: pre; }
.lines div { height: 21px; line-height: 21px; font-size: 16px; color: var(--ink); position: relative; }
.lines div.rule { color: var(--muted); }
.lines div.detail { height: 17px; line-height: 17px; font-size: 13px; color: rgba(43,36,32,.55); }
.lines div.fail { color: var(--tomato); }
.lines div.detail.fail { color: rgba(217,83,79,.55); }
.lines div.short { color: var(--tomato); }
.lines div.total { color: var(--teal); }
.lines div.hide { visibility: hidden; }
.lines .gut { position: absolute; left: 432px; top: 2px; width: 26px; height: 26px; }
.lines div.detail .gut { display: none; }
.lines .gut.tick { left: 436px; top: 4px; width: 18px; height: 16px; }
.lines .gut { top: -2px; }
.lines .gut.fz { left: 432px; top: -3px; width: 26px; height: 26px; }
/* the COINS total gets the receipt's own focus band (the mustard row highlight the shift receipt uses on hover) */
.lines div.hl::before { content: ""; position: absolute; left: -8px; top: -2px; width: 468px; height: 25px; z-index: -1;
  background: var(--mustard-pale); border: 2px solid var(--mustard); }
.spark { position: absolute; z-index: 16; }

/* the loyalty card face (LoyaltyCard, card face): loyalty_card.png 9-slice, LOYALTY / CARD title, 34x34 boxes, stamps tilted -6 deg */
.lcard { position: absolute; display: flex; align-items: center; gap: 6px; padding: 0 2px 0 4px; height: 50px;
  border: 6px solid transparent; border-image: url(screens_src/assets/loyalty_card.png) 3 fill / 6px stretch; image-rendering: pixelated; z-index: 14; }
.lcard .t { font-family: Pixelify; font-size: 11px; line-height: 12px; color: var(--ink); }
.lcard .boxes { display: flex; gap: 4px; }
.lcard .bx { position: relative; width: 34px; height: 34px; }
.lcard .bx img { position: absolute; left: 0; top: 0; width: 34px; height: 34px; }
.lcard .bx.st { transform: rotate(-6deg); }
.lcard .bx b { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-family: Atkinson; font-weight: 750; font-size: 12px;
  color: var(--mustard-pale); text-shadow: 1px 0 0 var(--ink), -1px 0 0 var(--ink), 0 1px 0 var(--ink), 0 -1px 0 var(--ink); }
.staple { position: absolute; width: 20px; height: 5px; background: var(--muted); box-shadow: 0 2px 0 rgba(43,36,32,.35); z-index: 15; }
"""

TOPBAR = """
  <div class="abs topbar"></div>
  <div class="abs tbrow">
    <div class="chip"><span class="k">SHIFT</span><span class="v">{shift}/8</span></div>
    <div class="chip" style="flex:1"><span class="k">QUOTA</span><span class="v">€{quota}</span><span class="bar"><i style="width:{fill}%"></i></span><span class="v" style="color:var(--mustard-light)">€{last}</span></div>
    <div class="chip"><span class="k">LOYALTY</span>{stamps}</div>
    <div class="tbtn"><img src="screens_src/assets/cart.png" style="width:24px;height:18px">Cart <span class="num" style="margin-left:2px">15/15</span></div>
    <div class="tbtn" style="padding:0 10px"><img src="screens_src/assets/menu.png" style="width:20px;height:18px"></div>
  </div>
"""


def topbar(won: bool) -> str:
    inits = ["CoE", "SlE", "BiB"] if won else ["CoE", "SlE"]
    stamps = ""
    for i in range(3):
        if i < len(inits):
            stamps += f'<span class="tstamp"><img src="screens_src/assets/stamp_ring.png"><b>{inits[i]}</b></span>'
        else:
            stamps += '<span class="tstamp"><img src="screens_src/assets/stamp_ring_empty.png"></span>'
    return TOPBAR.replace("{stamps}", stamps).replace("{last}", "151" if won else "86").replace(
        "{shift}", "8" if won else "6").replace("{quota}", "120" if won else "98").replace("{fill}", "100" if won else "88")


def loyalty_card(won: bool, left: int, top: int, tilt: float) -> str:
    inits = ["CoE", "SlE", "BiB"] if won else ["CoE", "SlE"]
    boxes = ""
    for i in range(3):
        if i < len(inits):
            boxes += f'<span class="bx st"><img src="screens_src/assets/stamp_ring.png"><b>{inits[i]}</b></span>'
        else:
            boxes += '<span class="bx"><img src="screens_src/assets/stamp_ring_empty.png"></span>'
    card = (
        f'<div class="lcard" style="left:{left}px;top:{top}px;transform:rotate({tilt}deg)">'
        f'<span class="t">LOYALTY<br>CARD</span><span class="boxes">{boxes}</span></div>'
    )
    # staple across the card's top edge, at its centre (ResultsPanel._draw_staple); card is ~178 wide
    card += f'<div class="staple" style="left:{left + 79}px;top:{top - 1}px;transform:rotate({tilt}deg)"></div>'
    return card


# a 7x7 art-pixel tick (green on an ink outline) at 2x = 14 px, so the marks fit the 21 px lines: a proposed icon
# (art/src/icons/mark_tick_small); mark_check (13x13, 26 px) is taller than a receipt line
CHECK = (
    '<svg class="gut tick" viewBox="0 0 9 8" shape-rendering="crispEdges">'
    '<path d="M6 0h3v3h-1v1h-1v1h-1v1h-1v1h-1v1h-1v-1h-1v-1h-1v-1h-1v-3h3v1h1v-1h1z" fill="#2b2420"/>'
    '<path d="M7 1h1v2h-1v1h-1v1h-1v1h-1v1h-1v-1h-1v-1h-1v-1h-1v-1h1v1h1v1h1v-1h1v-1h1v-1h1z" fill="#5fae5a"/>'
    '<rect x="7" y="1" width="1" height="1" fill="#a5d17e"/></svg>'
)
# a 9x9 art-pixel coin (gold, mustard, brass, ink outline) for the COINS line's gutter: a proposed new icon (art/src/icons/coin)
COIN = (
    '<svg class="gut" viewBox="0 0 13 13" shape-rendering="crispEdges">'
    '<rect x="4" y="1" width="5" height="1" fill="#2b2420"/><rect x="2" y="2" width="2" height="1" fill="#2b2420"/><rect x="9" y="2" width="2" height="1" fill="#2b2420"/>'
    '<rect x="1" y="4" width="1" height="5" fill="#2b2420"/><rect x="11" y="4" width="1" height="5" fill="#2b2420"/><rect x="2" y="3" width="1" height="1" fill="#2b2420"/>'
    '<rect x="10" y="3" width="1" height="1" fill="#2b2420"/><rect x="2" y="9" width="1" height="1" fill="#2b2420"/><rect x="10" y="9" width="1" height="1" fill="#2b2420"/>'
    '<rect x="2" y="10" width="2" height="1" fill="#2b2420"/><rect x="9" y="10" width="2" height="1" fill="#2b2420"/><rect x="4" y="11" width="5" height="1" fill="#2b2420"/>'
    '<rect x="4" y="2" width="5" height="9" fill="#e2b33c"/><rect x="3" y="3" width="7" height="7" fill="#e2b33c"/><rect x="2" y="4" width="9" height="5" fill="#e2b33c"/>'
    '<rect x="3" y="3" width="3" height="1" fill="#ffcf3f"/><rect x="2" y="4" width="2" height="3" fill="#ffcf3f"/><rect x="4" y="2" width="4" height="1" fill="#ffcf3f"/>'
    '<rect x="9" y="7" width="2" height="2" fill="#8a5d1a"/><rect x="5" y="10" width="4" height="1" fill="#8a5d1a"/><rect x="8" y="9" width="2" height="1" fill="#8a5d1a"/>'
    '<rect x="6" y="4" width="1" height="5" fill="#8a5d1a"/><rect x="5" y="5" width="1" height="1" fill="#8a5d1a"/>'
    "</svg>"
)


# a 9x9 art-pixel gold sparkle with an ink outline (proposed art/src/effects/sparkle_gold; the game's sparkle.png is
# mustard-light on paper, so it vanishes on the receipt)
SPARK = (
    '<svg class="spark" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px" viewBox="0 0 9 9" shape-rendering="crispEdges">'
    '<rect x="4" y="0" width="1" height="1" fill="#2b2420"/><rect x="3" y="1" width="1" height="1" fill="#2b2420"/><rect x="4" y="1" width="1" height="1" fill="#ffcf3f"/><rect x="5" y="1" width="1" height="1" fill="#2b2420"/><rect x="3" y="2" width="1" height="1" fill="#2b2420"/><rect x="4" y="2" width="1" height="1" fill="#ffcf3f"/><rect x="5" y="2" width="1" height="1" fill="#2b2420"/><rect x="1" y="3" width="1" height="1" fill="#2b2420"/><rect x="2" y="3" width="1" height="1" fill="#2b2420"/><rect x="3" y="3" width="1" height="1" fill="#ffcf3f"/><rect x="4" y="3" width="1" height="1" fill="#e2b33c"/><rect x="5" y="3" width="1" height="1" fill="#ffcf3f"/><rect x="6" y="3" width="1" height="1" fill="#2b2420"/><rect x="7" y="3" width="1" height="1" fill="#2b2420"/><rect x="0" y="4" width="1" height="1" fill="#2b2420"/><rect x="1" y="4" width="1" height="1" fill="#ffcf3f"/><rect x="2" y="4" width="1" height="1" fill="#ffcf3f"/><rect x="3" y="4" width="1" height="1" fill="#e2b33c"/><rect x="4" y="4" width="1" height="1" fill="#fbf7ee"/><rect x="5" y="4" width="1" height="1" fill="#e2b33c"/><rect x="6" y="4" width="1" height="1" fill="#ffcf3f"/><rect x="7" y="4" width="1" height="1" fill="#ffcf3f"/><rect x="8" y="4" width="1" height="1" fill="#2b2420"/><rect x="1" y="5" width="1" height="1" fill="#2b2420"/><rect x="2" y="5" width="1" height="1" fill="#2b2420"/><rect x="3" y="5" width="1" height="1" fill="#ffcf3f"/><rect x="4" y="5" width="1" height="1" fill="#e2b33c"/><rect x="5" y="5" width="1" height="1" fill="#ffcf3f"/><rect x="6" y="5" width="1" height="1" fill="#2b2420"/><rect x="7" y="5" width="1" height="1" fill="#2b2420"/><rect x="3" y="6" width="1" height="1" fill="#2b2420"/><rect x="4" y="6" width="1" height="1" fill="#ffcf3f"/><rect x="5" y="6" width="1" height="1" fill="#2b2420"/><rect x="3" y="7" width="1" height="1" fill="#2b2420"/><rect x="4" y="7" width="1" height="1" fill="#ffcf3f"/><rect x="5" y="7" width="1" height="1" fill="#2b2420"/><rect x="4" y="8" width="1" height="1" fill="#2b2420"/></svg>'
)


def sparkles(points: list[tuple[int, int, int]]) -> str:
    return "".join(SPARK.replace("{x}", str(x)).replace("{y}", str(y)).replace("{s}", str(sz)) for x, y, sz in points)


def lines_html(won: bool, upto: int | None = None, gutter: bool = True) -> str:
    rows = receipt(won)[1:]
    out = []
    for i, (text, tone, failed) in enumerate(rows):
        cls = [tone]
        if failed and tone in ("shift", "detail"):
            cls.append("fail")
        if upto is not None and i >= upto:
            cls.append("hide")
        extra = ""
        if gutter and tone == "shift" and not failed:
            extra = CHECK
        if gutter and tone == "shift" and failed:
            extra = '<img class="gut px fz" src="screens_src/assets/mark_fizzle.png">'
        if gutter and tone == "total":
            extra = COIN
            cls.append("hl")
        out.append(f'<div class="{" ".join(cls)}">{esc(text)}{extra}</div>')
    return "".join(out)  # no newlines: .lines is white-space: pre


def zigzag(w: int, h: int, tooth: int = 8, depth: int = 4, inset: int = 0) -> str:
    """A pixel-stepped torn edge, top and bottom, as a CSS polygon."""
    pts = []
    x = inset
    # top edge, left to right
    while x < w - inset:
        pts.append((x, depth))
        pts.append((x + tooth // 2, inset))
        x += tooth
    pts.append((w - inset, depth))
    pts.append((w - inset, h - depth))
    x = w - inset
    while x > inset:
        pts.append((x, h - depth))
        pts.append((x - tooth // 2, h - inset))
        x -= tooth
    pts.append((inset, h - depth))
    return "polygon(" + ",".join(f"{px}px {py}px" for px, py in pts) + ")"


def stepped_zigzag(w: int, h: int, tooth: int = 8, depth: int = 4) -> str:
    """Same torn edge but in 2 px steps (no diagonal anti-aliasing): a staircase per tooth."""
    pts = []
    x = 0
    while x < w:
        # rise from depth to 0 over tooth/2 in 2px steps, then fall
        for s in range(0, depth + 1, 2):
            pts.append((x + s, depth - s))
            pts.append((x + s + 2, depth - s))
        for s in range(depth, -1, -2):
            pts.append((x + tooth - s - 2, depth - s))
            pts.append((x + tooth - s, depth - s))
        x += tooth
    pts.append((w, depth))
    pts.append((w, h - depth))
    x = w
    while x > 0:
        for s in range(0, depth + 1, 2):
            pts.append((x - s, h - depth + s))
            pts.append((x - s - 2, h - depth + s))
        for s in range(depth, -1, -2):
            pts.append((x - tooth + s + 2, h - depth + s))
            pts.append((x - tooth + s, h - depth + s))
        x -= tooth
    pts.append((0, h - depth))
    return "polygon(" + ",".join(f"{px}px {py}px" for px, py in pts) + ")"


def torn_top(w: int, h: int, tooth: int = 8, depth: int = 4) -> str:
    """The torn top edge only; the bottom is straight (the report is still feeding out of the printer)."""
    full = stepped_zigzag(w, h, tooth, depth)
    pts = full[len("polygon("):-1].split(",")
    top = [q for q in pts if float(q.split()[1][:-2]) <= depth]
    return "polygon(" + ",".join(top + [f"{w}px {h}px", f"0px {h}px"]) + ")"


def make_end_backdrop() -> None:
    """The A backdrop: the real game capture (shift 5) cleaned for the end of the run. The printer's paper is torn off (the
    wall behind it is refilled row by row from the wall just right of it), and the inspection's CLOSED slot becomes an
    ordinary empty slot (shifts 6 and 8 have no inspection). All 1920x1080 pixel coordinates."""
    im = Image.open(ROOT / "screens_src/assets/results_bg_shift_1920x1080.png").convert("RGB")
    for y in range(166, 510):
        c = im.getpixel((432, y))
        for x in range(64, 430):
            im.putpixel((x, y), c)
    slot = im.crop((1512, 634, 1675, 733))
    im.paste(slot, (1704, 634))
    blank = im.crop((1530, 650, 1570, 720))
    im.paste(blank, (1765, 650))
    im.paste(blank, (1790, 650))
    im.save(ROOT / "screens_src/assets/results_bg_end_1920x1080.png")


def receipt_height(won: bool, upto: int | None = None) -> int:
    rows = receipt(won)[1:]
    if upto is not None:
        rows = rows[:upto]
    return sum(17 if t == "detail" else 21 for _, t, _ in rows)


def page(title: str, header: str, css: str, body: str) -> str:
    return (
        "<!doctype html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"
        f"<title>{title}</title>\n{header}\n<style>\n{FONTS}{BASE_CSS}{css}\n</style>\n</head>\n<body>\n"
        f'<div class="stage">\n{body}\n</div>\n</body>\n</html>\n'
    )


# ================================================================= A: end-of-day till report on the counter
A_HEADER = """<!--
  #56 RESULTS, OPTION A: END-OF-DAY TILL REPORT ON THE COUNTER (decide prep, 2026-10-19; nothing decided).
  Idea: the camera never leaves the mirrored B2 counter. The register prints the run's final receipt as a long end-of-day
  till report that lands on the belt, torn off with a pixel-stepped tear top and bottom and a hard stepped shadow. The
  register column stays unshaded (as beside #61's reward print-out) and its two keys relabel: the big tomato CHECKOUT key
  becomes "New run", the cream Redraw key becomes "Export log". So the buttons are the machine you played on all run.
  Receipt: FinalReceipt's lines verbatim, JetBrains Mono 16 px / 13 px details, 44 columns kept (423 px at 9.6 px/char);
  RUN WON! / RUN OVER printed at 44 px in Pixelify, GOOD or tomato with the 6 px ink outline (light text rule); the loyalty
  card face stapled at the top-right beside the headline, covering no line. Decor only: a "NEXT CUSTOMER · REG 3" header
  (the shift receipt's own header string), a gutter right of column 44 with mark_check beside each pass line and a gold
  coin beside the COINS total (pass/fail words stay; colour is never the only signal).
  New art/src sources: frames/till_report (paper 9-slice with a torn top and bottom edge, patterned so drawn at full width
  or tiled), icons/coin (9x9). Reused: mark_check, loyalty_card, stamp_ring(_empty), key faces (key_checkout, key_cream).
  Behaviour changes (label for the user): New run and Export log move OUT of the panel onto the register keys; the
  register column is left unshaded during the results. Print timing is unchanged (80 ms lines, tap prints the rest, New run
  armed at 350 ms, clickable mid-print: see screens_results_a_printing). The arm/disabled state would show as the key's
  existing _off face (key_checkout_off).
  Fit check: the 8-shift won history with coins (19 lines) and the longest pick name "Birthday candles" and longest detail
  "inspection Coupon slot closed"; the lost run adds the shortfall line. Backdrop: the real game capture
  docs/art/shift_screen_1920x1080.png (copied), shaded black .5 from y 64, with a redrawn top bar for shift 8/8.
  Art-director pass (2026-10-19): the backdrop is cleaned for the end of the run (make_end_backdrop: printer paper torn off,
  leaving a torn stub; the shift-5 CLOSED slot is an empty slot 7; the capture's stray tooltip is covered by the report,
  which now lies left of centre, next to the register it came from). Decor proposals, all on the paper: gold sparkles by the
  RUN WON! headline (new effects/sparkle_gold, 9x9; won runs only), the receipt's mustard focus band on the COINS total,
  mark_fizzle beside a fail line. Mid-print the report is shorter, with a straight bottom edge (still feeding).
-->"""

A_CSS = """
.bg { left: 0; top: 0; width: 1280px; height: 720px; }
.shade { background: rgba(0,0,0,.5); z-index: 5; }
/* register keys, as h1 draws them (mirrored: left column) */
.key { position: absolute; z-index: 8; display: flex; align-items: center; justify-content: center; border: 4px solid var(--ink); border-radius: 6px; }
.checkout { left: 20px; top: 422px; width: 296px; height: 82px; padding-top: 14px;
  background: linear-gradient(var(--tomato-light), var(--tomato-light)) 0 0 / 100% 10px no-repeat, linear-gradient(#f5bfa0, #f5bfa0) 0 10px / 100% 2px no-repeat, var(--tomato);
  box-shadow: inset 2px 0 0 rgba(245,191,160,.55), inset -2px -4px 0 var(--tomato-dark), 6px 6px 0 rgba(20,10,6,.45);
  gap: 14px; font-family: Pixelify; font-size: 34px; color: var(--paper); letter-spacing: 1px;
  text-shadow: 3px 0 0 var(--ink), -3px 0 0 var(--ink), 0 3px 0 var(--ink), 0 -3px 0 var(--ink), 2px 2px 0 var(--ink), -2px 2px 0 var(--ink), 2px -2px 0 var(--ink), -2px -2px 0 var(--ink); }
.redraw { left: 20px; top: 518px; width: 198px; height: 54px; padding-top: 10px; color: var(--ink);
  background: linear-gradient(#fbf7ee, #fbf7ee) 0 0 / 100% 8px no-repeat, linear-gradient(#ffffff, #ffffff) 0 8px / 100% 2px no-repeat, #ece0c6;
  box-shadow: inset 2px 0 0 rgba(255,255,255,.6), inset -2px -4px 0 var(--cream-shade), 6px 6px 0 rgba(20,10,6,.4);
  font-family: Pixelify; font-size: 21px; }
.keyhint { left: 20px; top: 588px; width: 198px; text-align: center; font-size: 11px; font-weight: 650; color: var(--cream-shade); z-index: 8; }
/* the till report: ink outline + paper, both clipped to the torn edge; a hard stepped shadow under it */
.tr-shadow { background: rgba(20,10,6,.5); z-index: 9; }
.tr-ink { background: var(--ink); z-index: 10; }
.tr-paper { background: var(--paper); z-index: 11; }
.tr-paper .band { position: absolute; left: 0; right: 0; height: 2px; background: #ece0c6; }
.tr-in { z-index: 12; }
.tr-in .hd { font-family: JBMono; font-size: 13px; color: var(--ink-light); letter-spacing: .5px; }
.headline { font-family: Pixelify; font-size: 44px; line-height: 52px; letter-spacing: 1px;
  text-shadow: 3px 0 0 var(--ink), -3px 0 0 var(--ink), 0 3px 0 var(--ink), 0 -3px 0 var(--ink), 2px 2px 0 var(--ink), -2px 2px 0 var(--ink), 2px -2px 0 var(--ink), -2px -2px 0 var(--ink); }
.tapnote { font-family: Atkinson; font-weight: 650; font-size: 13px; color: var(--paper); z-index: 12;
  text-shadow: 2px 0 0 var(--ink), -2px 0 0 var(--ink), 0 2px 0 var(--ink), 0 -2px 0 var(--ink); }
.cursor { width: 26px; height: 30px; z-index: 30; }
"""


def option_a(won: bool, printing: bool = False) -> str:
    upto = 9 if printing else None  # mid-print: through shift 5's detail line
    W = 506
    pad_l = 30
    head_h = 18 + 6 + 52 + 10  # header line, gap, headline row, gap
    H_full = 26 + head_h + receipt_height(won) + 30
    H = 26 + head_h + receipt_height(won, upto) + 18 if printing else H_full
    # the report lies on the belt close to the register it came out of (left of centre), clear of the CLOSED-slot column
    left = 432
    top = max(64 + 14, 64 + (720 - 64 - H_full) // 2 - 8)
    color = "var(--good)" if won else "var(--tomato)"
    body = ['<img class="abs bg px" src="screens_src/assets/results_bg_end_1920x1080.png">']
    # the backdrop (make_end_backdrop) has the printer's paper torn off: only a torn stub is left in the printer's slot
    stub = torn_top(236, 16)
    body.append(f'<div class="abs" style="left:45px;top:322px;width:236px;height:16px;background:var(--ink);clip-path:{stub}"></div>')
    body.append(f'<div class="abs" style="left:47px;top:324px;width:232px;height:14px;background:var(--paper);clip-path:{torn_top(232, 14)}"></div>')
    # slot 7 in the backdrop is an ordinary empty slot now (no inspection on shift 6 or 8); its number
    body.append('<div class="abs num" style="left:1136px;top:436px;width:108px;text-align:center;font-size:32px;color:#5e574d">7</div>')
    body.append('<div class="abs" style="left:493px;top:75px;width:406px;height:158px;background:var(--paper)"></div>')
    body.append('<div class="abs" style="left:505px;top:86px;width:382px;display:flex;justify-content:space-between;font-family:Pixelify;font-size:24px;color:var(--ink)"><span>SHIFT ' + ('8/8' if won else '6/8') + '</span><span>QUOTA €' + ('120' if won else '98') + '</span></div>')
    body.append(topbar(won))
    # shade from y 64, leaving the register column (COLUMN_RECT 0,400 336x300) lit
    body.append('<div class="abs shade" style="left:0;top:64px;width:1280px;height:336px"></div>')
    body.append('<div class="abs shade" style="left:336px;top:400px;width:944px;height:320px"></div>')
    body.append('<div class="abs shade" style="left:0;top:700px;width:336px;height:20px"></div>')
    # keys
    body.append('<div class="key checkout">New run</div>')
    body.append('<div class="key redraw">Export log</div>')
    # the till report
    clip = torn_top(W, H) if printing else stepped_zigzag(W, H)
    clip_in = torn_top(W - 4, H - 2) if printing else stepped_zigzag(W - 4, H - 4)
    body.append(f'<div class="abs tr-shadow" style="left:{left + 8}px;top:{top + 8}px;width:{W}px;height:{H}px;clip-path:{clip}"></div>')
    body.append(f'<div class="abs tr-ink" style="left:{left}px;top:{top}px;width:{W}px;height:{H}px;clip-path:{clip}"></div>')
    body.append(
        f'<div class="abs tr-paper" style="left:{left + 2}px;top:{top + 2}px;width:{W - 4}px;height:{H - 4}px;clip-path:{clip_in}">'
        f'<div class="band" style="top:14px"></div><div class="band" style="bottom:14px"></div></div>'
    )
    ix = left + pad_l
    iy = top + 26
    shown_lines = lines_html(won, upto)
    body.append(
        f'<div class="abs tr-in" style="left:{ix}px;top:{iy}px;width:{W - pad_l - 10}px">'
        f'<div class="hd">NEXT CUSTOMER · REG 3</div>'
        f'<div class="headline" style="margin-top:6px;color:{color}">{"RUN WON!" if won else "RUN OVER"}</div>'
        f'<div class="lines" style="margin-top:10px">{shown_lines}</div></div>'
    )
    # loyalty card stapled at the top-right corner, beside the headline
    body.append(loyalty_card(won, left + W - 178 - 4, iy + 22, -4))
    if won:
        # gold sparkles around the headline: the celebration lives on the paper, not floating over the scene
        body.append(sparkles([(ix - 26, iy + 44, 18), (ix + 200, iy + 22, 18), (ix + 222, iy + 60, 18)]))
    if printing:
        # a printing cue under the last printed line: the rest of the report is still in the printer (hidden lines keep the size)
        body.append(
            f'<div class="abs tapnote" style="left:{left + 40}px;top:{top + H + 12}px;width:{W - 80}px;text-align:center;padding:4px 8px;background:var(--ink)">'
            "MOCK-UP NOTE (not game text): mid-print, 80 ms a line, the report still feeding; New run is already armed</div>"
        )
        # pointer on the armed New run key
        body.append(
            '<svg class="abs cursor" style="left:236px;top:470px" viewBox="0 0 13 15" shape-rendering="crispEdges">'
            '<path d="M1 1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h-3v1h1v1h1v2h-2v-1h-1v-2h-1v1h-1v1h-1z" fill="#fbf7ee" stroke="#2b2420" stroke-width="1"/></svg>'
        )
    name = "Results A" + (" over" if not won else "") + (" printing" if printing else "")
    return page(name, A_HEADER, A_CSS, "\n".join(body))


# ================================================================= B: staff noticeboard
B_HEADER = """<!--
  #56 RESULTS, OPTION B: STAFF NOTICEBOARD (decide prep, 2026-10-19; nothing decided).
  Idea: at the end of the run the camera cuts from the counter to the staff-room wall: a cork noticeboard in a wood frame,
  the run's final receipt pinned to it with two brass push pins, and the headline slapped on as a tilted rubber stamp
  (RUN WON! in GOOD green, RUN OVER in tomato), in the family of the SPOT CHECK and PAID stamps. Beside the board hangs the
  staff time clock: its face is the store's wall clock, and its punch button is New run (button.png framed button);
  Export log is the secondary sign.png button on its base. The top bar stays on top and clickable.
  The brief's "clock-out card" is NOT used as the receipt: section 12 of the plan fixes the framing as the customer
  loyalty card, not a staff timecard. The time clock is only the prop that holds the New run button; drop it and put both
  buttons on the board's lower rail if it reads as staff framing.
  Receipt: FinalReceipt verbatim, JetBrains Mono 16/13 px, 44 columns; the loyalty card face stapled top-right beside the
  stamp. Same gutter marks as A (mark_check per pass, a coin on the COINS total).
  New art/src sources: scenery/noticeboard (cork tile, generated here as screens_src/assets/results_cork.png from palette
  browns, plus a wood 9-slice frame), scenery/time_clock (steel box; reuses wall_clock), effects/headline_stamp (a 9-slice
  rubber-stamp border, worn), icons/push_pin, icons/coin. Reused: loyalty_card, stamp_ring, mark_check, button, sign, chip.
  Behaviour changes (label for the user): the results leave the shift screen for a full-screen wall (today they pop in over
  the shaded counter). The cut itself would replace pop_in (0.22 s); print timing is unchanged (80 ms lines, tap prints
  the rest, New run armed at 350 ms, clickable mid-print). The headline stamp lands as line 0.
  Fit check: the 8-shift won history (19 lines), "Birthday candles", "inspection Coupon slot closed"; RUN OVER adds the
  shortfall line. Art-director pass: same coin band, fail mark and gold sparkles as A.
-->"""

B_CSS = """
.wall { left: 0; top: 56px; width: 1280px; height: 664px; background: #e4d6b9; }
.wall .mould { position: absolute; left: 0; right: 0; height: 10px; background: #cdbb98; border-top: 2px solid #ece0c6; border-bottom: 2px solid #b9a47c; }
.wains { left: 0; top: 620px; width: 1280px; height: 100px; background: #a8703a; border-top: 4px solid var(--ink); }
.wains i { position: absolute; top: 0; bottom: 0; width: 2px; background: #6e4524; }
.wains .cap { position: absolute; left: 0; right: 0; top: 0; height: 6px; background: #c98c4e; border-bottom: 2px solid #6e4524; }
.board-shadow { background: rgba(43,36,32,.35); }
.board { border: 4px solid var(--ink); background: #6e4524; }
.board .frame-lit { position: absolute; left: 0; top: 0; right: 0; height: 4px; background: #a8703a; }
.board .frame-lit2 { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; background: #a8703a; }
.cork { position: absolute; left: 14px; top: 14px; right: 14px; bottom: 14px; border: 2px solid var(--ink);
  background: url(screens_src/assets/results_cork.png) 0 0 / 64px 64px repeat; image-rendering: pixelated; }
.paper-shadow { background: rgba(43,36,32,.38); }
.paper { background: var(--paper); border: 2px solid var(--ink); box-shadow: inset -2px -2px 0 #ece0c6; }
.pin { width: 16px; height: 16px; z-index: 16; }
.stamp { font-family: Pixelify; font-size: 44px; line-height: 50px; letter-spacing: 2px; padding: 2px 14px 4px; border: 4px solid; z-index: 13;
  transform: rotate(-5deg); transform-origin: left center; }
.stamp .wear { position: absolute; width: 4px; height: 2px; background: var(--paper); }
.clock-box { background: #c7c3b8; border: 4px solid var(--ink); box-shadow: inset 4px 4px 0 #ecebe4, inset -4px -4px 0 #8d8a83; }
.clock-shadow { background: rgba(43,36,32,.35); }
.slot { background: #24221f; border: 2px solid var(--ink); box-shadow: inset 0 2px 0 #45423d; }
.plate { background: #a9a59b; border: 2px solid var(--ink); box-shadow: inset 2px 2px 0 #c7c3b8, inset -2px -2px 0 #6f6b63; }
.plaque { width: 220px; height: 32px; z-index: 9; display: flex; align-items: center; justify-content: center; font-family: Pixelify; font-size: 17px;
  letter-spacing: 2px; color: #4a3010; background: #c8932b; border: 2px solid var(--ink); box-shadow: inset 2px 2px 0 #ffcf3f, inset -2px -2px 0 #8a5d1a, 4px 4px 0 rgba(43,36,32,.35); }
.screw { width: 6px; height: 6px; background: #6f6b63; border: 2px solid var(--ink); }
"""

PIN_SVG = (
    '<svg class="abs pin" style="left:{x}px;top:{y}px" viewBox="0 0 8 8" shape-rendering="crispEdges">'
    '<rect x="2" y="0" width="4" height="1" fill="#2b2420"/><rect x="1" y="1" width="1" height="1" fill="#2b2420"/><rect x="6" y="1" width="1" height="1" fill="#2b2420"/>'
    '<rect x="0" y="2" width="1" height="3" fill="#2b2420"/><rect x="7" y="2" width="1" height="3" fill="#2b2420"/><rect x="1" y="5" width="1" height="1" fill="#2b2420"/>'
    '<rect x="6" y="5" width="1" height="1" fill="#2b2420"/><rect x="2" y="6" width="4" height="1" fill="#2b2420"/>'
    '<rect x="2" y="1" width="4" height="5" fill="#c8932b"/><rect x="1" y="2" width="6" height="3" fill="#c8932b"/>'
    '<rect x="2" y="2" width="2" height="1" fill="#ffcf3f"/><rect x="2" y="3" width="1" height="1" fill="#ffcf3f"/>'
    '<rect x="5" y="4" width="1" height="1" fill="#8a5d1a"/><rect x="3" y="5" width="3" height="1" fill="#8a5d1a"/>'
    '<rect x="5" y="7" width="2" height="1" fill="rgba(43,36,32,.45)"/></svg>'
)


def make_cork() -> None:
    """A 32x32 art-pixel cork tile in palette browns (base #a87a4e, flecks #7a5232, #d2a874, #c98c4e)."""
    rnd = random.Random(56)
    base = (0xA8, 0x7A, 0x4E)
    flecks = [(0x7A, 0x52, 0x32), (0xD2, 0xA8, 0x74), (0xC9, 0x8C, 0x4E)]
    im = Image.new("RGB", (32, 32), base)
    for _ in range(150):
        x, y = rnd.randrange(32), rnd.randrange(32)
        im.putpixel((x, y), flecks[rnd.randrange(3)])
    im.save(ROOT / "screens_src/assets/results_cork.png")


def option_b(won: bool) -> str:
    rows_h = receipt_height(won)
    W = 500
    pad_l = 30
    head_h = 62 + 10
    H = 24 + head_h + rows_h + 26
    # the board
    bx, by, bw, bh = 96, 76, 720, 604 if True else 0
    body = ['<div class="abs wall"><div class="mould" style="top:28px"></div></div>']
    wains = '<div class="abs wains"><div class="cap"></div>' + "".join(
        f'<i style="left:{x}px"></i>' for x in range(40, 1280, 120)
    ) + "</div>"
    body.append(wains)
    body.append(topbar(won))
    body.append(f'<div class="abs board-shadow" style="left:{bx + 10}px;top:{by + 10}px;width:{bw}px;height:{bh}px"></div>')
    body.append(
        f'<div class="abs board" style="left:{bx}px;top:{by}px;width:{bw}px;height:{bh}px">'
        '<div class="frame-lit"></div><div class="frame-lit2"></div><div class="cork"></div></div>'
    )
    body.append(
        f'<div class="abs plaque" style="left:{bx + bw // 2 - 110}px;top:{by - 14}px">STAFF NOTICES</div>'
    )
    # the receipt, pinned
    px_ = bx + (bw - W) // 2 - 10
    py_ = by + 26 + max(0, (bh - 52 - H) // 2)
    body.append(f'<div class="abs paper-shadow" style="left:{px_ + 8}px;top:{py_ + 8}px;width:{W}px;height:{H}px"></div>')
    body.append(f'<div class="abs paper" style="left:{px_}px;top:{py_}px;width:{W}px;height:{H}px;z-index:11"></div>')
    body.append(PIN_SVG.replace("{x}", str(px_ + 18)).replace("{y}", str(py_ - 6)))
    body.append(PIN_SVG.replace("{x}", str(px_ + W // 2 - 8)).replace("{y}", str(py_ + H - 12)))
    color = "var(--good)" if won else "var(--tomato)"
    word = "RUN WON!" if won else "RUN OVER"
    ix = px_ + pad_l
    iy = py_ + 24
    wear = "".join(
        f'<i class="wear" style="left:{x}px;top:{y}px"></i>' for x, y in [(22, 10), (64, 40), (130, 6), (176, 44), (210, 18)]
    )
    body.append(
        f'<div class="abs stamp" style="left:{ix - 4}px;top:{iy + 6}px;color:{color};border-color:{color}">{word}{wear}</div>'
    )
    body.append(
        f'<div class="abs" style="left:{ix}px;top:{iy + head_h}px;z-index:12"><div class="lines">{lines_html(won)}</div></div>'
    )
    body.append(loyalty_card(won, px_ + W - 178 - 6, iy - 4, -4))
    if won:
        body.append(sparkles([(ix - 24, iy + 4, 18), (ix + 238, iy - 8, 18), (ix + 258, iy + 34, 18)]))
    # the time clock with New run and Export log
    cx, cy, cw, ch = 880, 120, 300, 470
    body.append(f'<div class="abs clock-shadow" style="left:{cx + 10}px;top:{cy + 10}px;width:{cw}px;height:{ch}px"></div>')
    body.append(f'<div class="abs clock-box" style="left:{cx}px;top:{cy}px;width:{cw}px;height:{ch}px;z-index:10"></div>')
    body.append(f'<div class="abs plate" style="left:{cx + 70}px;top:{cy + 22}px;width:160px;height:160px;z-index:11"></div>')
    body.append(
        f'<img class="abs px" src="screens_src/assets/wall_clock.png" style="left:{cx + 62}px;top:{cy + 14}px;width:176px;height:176px;z-index:12">'
    )
    for sx, sy in [(cx + 16, cy + 16), (cx + cw - 26, cy + 16), (cx + 16, cy + ch - 26), (cx + cw - 26, cy + ch - 26)]:
        body.append(f'<div class="abs screw" style="left:{sx}px;top:{sy}px;z-index:11"></div>')
    body.append(f'<div class="abs slot" style="left:{cx + 50}px;top:{cy + 214}px;width:200px;height:16px;z-index:11"></div>')
    body.append(
        f'<div class="fbtn primary" style="left:{cx + 40}px;top:{cy + 262}px;width:220px;height:72px;font-size:30px">New run</div>'
    )
    body.append(
        f'<div class="fbtn sign" style="left:{cx + 60}px;top:{cy + 376}px;width:180px;height:48px;font-size:19px">Export log</div>'
    )
    name = "Results B" + (" over" if not won else "")
    return page(name, B_HEADER, B_CSS, "\n".join(body))


def main() -> None:
    make_cork()
    make_end_backdrop()
    (ROOT / "screens_results_a.html").write_text(option_a(True), encoding="utf-8")
    (ROOT / "screens_results_a_over.html").write_text(option_a(False), encoding="utf-8")
    (ROOT / "screens_results_a_printing.html").write_text(option_a(True, printing=True), encoding="utf-8")
    (ROOT / "screens_results_b.html").write_text(option_b(True), encoding="utf-8")
    (ROOT / "screens_results_b_over.html").write_text(option_b(False), encoding="utf-8")
    for won in (True, False):
        for text, _, _ in receipt(won):
            assert len(text) <= WIDTH, text
    print("ok")


if __name__ == "__main__":
    main()
