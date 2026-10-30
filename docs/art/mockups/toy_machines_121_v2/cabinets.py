"""#121 v2 toy machines: six per-aisle cabinets on one shared base (mock-up only, not game code).

v2.1 (2026-10-30, after the three critiques): a smaller, quieter shared body (steel-shade dial, a dark
coin-LED price decal inside the footprint, no glyph badge), capsules with a seam and a paper '?', a
cream washer, a gingham-capped pantry jar on a shelf, a white-enamel fridge with wire shelves and
frost, one calm stripe on the vending box, and a dim/ set (a palette map two steps down each ramp)
for machines that can't be used (out of coins, collected): cab_, cabLid_ (slot lid shut), cabTag_
(the COLLECTED tag over the slot), front_, capW_, plinth_, the toppers, coin and padlock.

Run from the repo root:  python docs/art/mockups/toy_machines_121_v2/cabinets.py

Reuses build.py (a copy of v1's) for the palette, Grid, glyph badge, OFF_MAP and the base machine.
Every machine is 72x140 art px like art/scenery/toy_machine.png; rows 0..18 stay empty (the page draws
the aisle's shelf-label plate there), rows 19..21 are the hanger rods, rows 22..75 are the aisle's
cabinet top, rows 76..139 are the SHARED collar, body (coin slot, crank, chute, glyph badge), stem
and foot, recoloured per aisle. Windows are night glass (teal dark + level 1 teal shade). The page
draws the remaining capsules into each cabinet's slots, then the cabinet's front overlay (crate lips,
glass glare) over them.

Outputs in toy_machines_121_v2/assets/v2/: cab_<aisle>.png, front_<aisle>.png and off/ (palette swap,
slot lid shut), plus toy_machines_121_v2/data_v2.js (slots, window rects).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build  # noqa: E402  (the copied v1 builder: palette, Grid, glyph badge, OFF_MAP)

from build import AISLE_MAPS, Grid, off, shutter  # noqa: E402

OUT = HERE / "assets" / "v2"
W, H = 72, 140


def ramp(aisle: str) -> tuple[str, str, str, str]:
    return AISLE_MAPS[aisle]


def dith(g: Grid, x: int, y: int, w: int, h: int, k: str, level: int, only: set[str] | None = None) -> None:
    """The title's 2x2 dither: 1 = the (0,0) pixel, 2 = checker, 3 = three in four."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            a, b = xx % 2, yy % 2
            on = (level == 1 and a == 0 and b == 0) or (level == 2 and a == b) or (level == 3 and not (a == 0 and b == 1))
            if on and (only is None or g.get(xx, yy) in only):
                g.set(xx, yy, k)


def glass(g: Grid, x: int, y: int, w: int, h: int, only: set[str] | None = None) -> None:
    """Night glass: teal dark, level 1 teal shade (the title's lit-bay recipe at its quiet level)."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if only is None or g.get(xx, yy) in only:
                g.set(xx, yy, "2")
    dith(g, x, y, w, h, "3", 1, {"2"})


def glare(f: Grid, x: int, y: int, n: int, k: str = "j") -> None:
    for i in range(n):
        f.set(x + i, y - i, k)


# The dim map (out of coins, collected): every colour two steps down its own ramp, so the art stays
# inside the palette and keeps its hue (title critique 3: no haze blend).
DIM_MAP = {
    "#": "#", "%": "#", ":": "-", "-": "=", "=": "%",
    "w": "a", "c": "a", "b": "-", "a": "=",
    "6": "4", "5": "3", "7": "3", "4": "2", "3": "1", "2": "8", "1": "8", "8": "8",
    "O": "R", "o": "r", "R": "r", "r": "q", "q": "v",
    "Y": "m", "y": "m", "M": "u", "m": "u", "u": "k", "n": "L", "L": "l", "l": "k", "k": "U",
    "z": "g", "G": "g", "g": "1", "h": "F", "F": "f", "f": "e", "e": "U",
    "v": "v", "V": "v", "x": "V", "X": "x",
    "A": "D", "B": "E", "C": "E", "D": "H", "E": "I", "H": "I", "I": "N", "J": "K", "K": "N", "N": "N",
    "P": "S", "Q": "T", "S": "T", "T": "U", "U": "N", "W": "i", "Z": "i", "d": "-", "i": "=",
    "j": "4", "p": "3", "s": "t", "t": "N", "9": "0", "0": "f",
}


def dim(g: Grid) -> Grid:
    o = g.copy()
    o.swap(DIM_MAP)
    return o


SLOT_NEW = (17, 88, 9, 14)       # the coin slot (ink box) the lid shuts
DECAL = (12, 107, 24, 16)        # the price decal: the page draws the coin (or padlock) and the 1 on it
TAG_AT = (14, 86)                # the COLLECTED tag hangs over the slot


def body(aisle: str) -> Grid:
    """The shared part, redrawn smaller and quieter (identity 4): a short steel collar, the aisle-colour
    body, a steel-dark face panel with the brass slot and a steel-shade dial (no white disc), a cream
    price decal inside the footprint (title 5, identity 9) and the chute. No glyph badge (identity 8)."""
    g = Grid(W, H)
    g.box(10, 76, 52, 5, "D")
    g.hline(11, 60, 77, "B")
    g.hline(11, 60, 78, "C")
    g.box(8, 80, 56, 47, "4")
    g.vline(9, 81, 125, "5")
    g.vline(10, 81, 125, "5")
    g.vline(59, 81, 125, "3")
    for x in (60, 61, 62):
        g.vline(x, 81, 125, "2")
    g.hline(9, 58, 81, "5")
    # face panel
    g.box(13, 84, 46, 21, "H")
    g.hline(14, 57, 85, "E")
    # coin slot
    sx, sy, sw, sh = SLOT_NEW
    g.box(sx, sy, sw, sh, "L")
    g.hline(sx + 1, sx + sw - 2, sy + 1, "M")
    g.rect(sx + 3, sy + 3, 3, sh - 6, "#")
    g.hline(sx + 1, sx + sw - 2, sy + sh - 2, "l")
    # dial: steel shade, small, with its bar and a brass knob
    g.disc(41, 94.5, 7.6, "#")
    g.disc(41, 94.5, 6.6, "D")
    g.disc(40.2, 93.7, 4.2, "C")
    g.disc(41, 94.5, 3.2, "D")
    g.hline(34, 48, 94, "#")
    g.hline(35, 47, 95, "E")
    g.rect(49, 94, 2, 2, "L")
    g.set(49, 93, "#")
    g.set(50, 93, "#")
    # price decal: a small coin LED (the title's RewardsMenu LED: teal black rim, slate dark face) that
    # the page fills with the coin (or the padlock) and the number-font 1; dark, so the window stays
    # the brightest part of the machine
    dx, dy, dw, dh = DECAL
    g.box(dx, dy, dw, dh, "t", "8")
    g.hline(dx + 1, dx + dw - 2, dy + 1, "s")
    # chute
    g.box(39, 107, 20, 16, "C")
    g.hline(40, 57, 108, "B")
    g.hline(40, 57, 112, "#")
    g.rect(40, 113, 18, 9, "N")
    g.hline(40, 57, 113, "I")
    # stem and foot
    g.box(28, 126, 16, 7, "D")
    g.box(14, 132, 44, 8, "E")
    g.hline(15, 56, 133, "C")
    g.swap(build.ramp_map(aisle))
    return g


def tag(g: Grid) -> None:
    """COLLECTED: a green tag with a paper tick hung over the coin slot on a string (identity 6)."""
    tx, ty = TAG_AT
    g.vline(tx + 6, 81, ty - 1, "f")
    g.box(tx, ty, 13, 11, "g")
    g.hline(tx + 1, tx + 11, ty + 1, "G")
    g.set(tx + 6, ty + 2, "#")
    tick = ["......#", ".....##", "#...##.", "##.##..", ".###..."]
    for j, row in enumerate(tick):
        for i, ch in enumerate(row):
            if ch == "#":
                g.set(tx + 3 + i, ty + 4 + j, "w")


def capsule(aisle: str) -> Grid:
    """A window capsule (identity 5, glance 3): the aisle colour all round, a single cream highlight and
    an ink seam with a paper band under it, so it reads as a capsule in a crate, an oven or a drum."""
    d, s, b, l = ramp(aisle)
    shade = s if s != b else d
    g = Grid(13, 13)
    for y, row in enumerate(build.CAPSULE_SHAPE):
        for x, ch in enumerate(row):
            if ch == "#":
                g.g[y][x] = "#"
    for y in range(13):
        for x in range(13):
            if build.INSIDE.get(x, y) == "1":
                g.g[y][x] = b if y < 6 else shade
    for x in range(13):
        if build.INSIDE.get(x, 6) == "1":
            g.set(x, 6, "#")
        if build.INSIDE.get(x, 7) == "1":
            g.set(x, 7, "c")
    g.set(10, 3, shade)
    g.set(10, 4, shade)
    g.set(3, 2, l)
    g.set(2, 3, l)
    # a '?' on the top half: a closed mystery capsule, never a bun or a lettuce (paper on dark aisle
    # colours, ink on the light ones)
    qk = "#" if b in ("h", "M", "5", "y", "z") else "w"
    for j, row in enumerate(["##.", "..#", ".#.", "...", ".#."]):
        for i, ch in enumerate(row):
            if ch == "#":
                g.set(5 + i, 1 + j, qk)
    return g


def rods(g: Grid, xs: tuple[int, ...] = (18, 51)) -> None:
    """Hanger rods from the plate (row 18) down to the first opaque pixel of the cabinet top."""
    for x in xs:
        y = 19
        while y < 76 and g.get(x, y) == "." and g.get(x + 1, y) == ".":
            g.set(x, y, "#")
            g.set(x + 1, y, "B")
            y += 1


def cabinet_box(g: Grid, aisle: str, x: int = 8, y: int = 22, w: int = 56, h: int = 54, fill: str | None = None) -> None:
    """The family's box: ink outline, ramp light rim top/left, ramp shade down the right."""
    d, s, b, l = ramp(aisle)
    g.box(x, y, w, h, fill or b)
    g.hline(x + 1, x + w - 2, y + 1, l)
    g.vline(x + 1, y + 1, y + h - 2, l)
    g.vline(x + w - 2, y + 2, y + h - 2, s if s != b else d)


def cold(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Cold cases: a display fridge in white steel enamel (so it parts from the teal wall), a cold white
    light strip, two wire shelves, frost round the glass, a steel handle and a kick grille (identity 3)."""
    g, f = body(aisle), Grid(W, H)
    g.box(8, 22, 56, 54, "B")
    g.hline(9, 62, 23, "A")
    g.vline(9, 23, 74, "A")
    g.vline(62, 24, 74, "D")
    g.box(11, 24, 50, 6, "#")
    g.rect(12, 25, 48, 4, "j")
    g.hline(12, 59, 25, "w")
    g.hline(12, 59, 28, "6")
    g.box(10, 31, 46, 42, "#")
    glass(g, 11, 32, 44, 40)
    g.hline(11, 54, 32, "4")
    # wire shelves under each row of capsules
    for sy in (52, 71):
        g.hline(11, 54, sy, "B")
    for x in range(11, 55, 2):
        g.set(x, 53, "D")
    g.box(57, 40, 4, 22, "#")
    g.vline(58, 41, 60, "A")
    g.vline(59, 41, 60, "C")
    g.rect(11, 73, 50, 2, "H")
    for x in range(12, 60, 3):
        g.set(x, 73, "N")
        g.set(x, 74, "N")
    # frost: a dither band round the glass edge, heavier in the corners (front: over the capsules)
    for x in range(11, 55):
        for y in (33, 34):
            if (x + y) % 2 == 0:
                f.set(x, y, "p")
    for y in range(33, 71):
        if y % 2 == 0:
            f.set(11, y, "p")
        else:
            f.set(54, y, "p")
    for (x, y) in ((12, 70), (11, 69), (13, 69), (12, 68), (53, 70), (54, 69), (52, 69), (53, 68),
                   (12, 36), (13, 35), (53, 36), (52, 35)):
        f.set(x, y, "6")
    glare(f, 14, 47, 8)
    glare(f, 14, 50, 3)
    slots = [(19, 58), (33, 58), (19, 39), (33, 39)]
    return g, f, slots, [11, 32, 44, 40]


def pantry(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Pantry: a storage jar on a wooden shelf, a gingham cloth cap tied with string (not the mustard
    body's metal), and a printed label with the pantry glyph (identity 2)."""
    g, f = body(aisle), Grid(W, H)
    jx0, jx1, jy0, jy1 = 11, 60, 31, 70
    shape = Grid(W, H)
    top_in, bot_in = [7, 4, 2, 1, 1, 0], [1, 2, 3]
    for y in range(jy0, jy1 + 1):
        inset = top_in[y - jy0] if y < jy0 + len(top_in) else (bot_in[y - (jy1 - 2)] if y > jy1 - 3 else 0)
        for x in range(jx0 + inset, jx1 - inset + 1):
            shape.g[y][x] = "1"
    for y in range(jy0, jy1 + 1):
        for x in range(jx0, jx1 + 1):
            if shape.get(x, y) != "1":
                continue
            edge = any(shape.get(x + dx, y + dy) != "1" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            g.g[y][x] = "#" if edge else "2"
    dith(g, jx0, jy0, jx1 - jx0 + 1, jy1 - jy0 + 1, "3", 1, {"2"})
    for y in range(jy0, jy1 + 1):
        for x in range(jx0, jx1 + 1):
            if g.get(x, y) not in ("2", "3"):
                continue
            if g.get(x - 1, y) == "#" or g.get(x, y - 1) == "#":
                g.set(x, y, "p")
            elif g.get(x + 1, y) == "#" or g.get(x, y + 1) == "#":
                g.set(x, y, "4")
    # the shelf plank the jar stands on
    g.box(7, 71, 58, 5, "S")
    g.hline(8, 63, 72, "P")
    g.hline(8, 63, 74, "T")
    # gingham cap: tomato and paper checks, a frilled edge, tied with brown string and a knot
    cap = Grid(W, H)
    for y in range(22, 31):
        for x in range(13, 59):
            if (y == 22 and x in (13, 58)):
                continue
            cap.g[y][x] = "1"
    for x in range(13, 59):
        if x % 3 == 1:
            cap.g[31][x] = "1"
    for y in range(22, 32):
        for x in range(12, 60):
            if cap.get(x, y) != "1":
                continue
            if any(cap.get(x + dx, y + dy) != "1" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g.set(x, y, "#")
                continue
            a, b = (x // 2) % 2, (y // 2) % 2
            g.set(x, y, "R" if a and b else ("w" if not a and not b else "o"))
    g.hline(16, 55, 32, "f")
    g.box(30, 31, 4, 3, "F")
    for x, y in ((29, 34), (28, 35), (34, 34), (35, 35)):
        g.set(x, y, "f")
    # label: cream paper, a mustard band, the pantry glyph between two printed lines
    g.box(19, 38, 34, 15, "#")
    g.rect(20, 39, 32, 13, "c")
    g.rect(20, 39, 32, 2, "M")
    g.hline(20, 51, 39, "y")
    g.paste(Grid.from_png(build.ROOT / "art/icons/aisle_pantry.png"), 32, 42)
    for ly in (45, 48):
        g.hline(22, 29, ly, "a")
        g.hline(43, 49, ly, "a")
    for y in range(40, 66):
        f.set(14, y, "j")
    for y in range(44, 56):
        f.set(15, y, "6")
    f.set(14, 68, "j")
    slots = [(21, 57), (36, 57), (29, 53), (14, 53)]
    return g, f, slots, [12, 36, 48, 34]


def household(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Household: a cream enamel front-loader (not grey: identity 1) with a grey control strip, a steel
    door ring, a teal drum with suds along its top and the capsules tumbled in a pile at the bottom."""
    g, f = body(aisle), Grid(W, H)
    g.box(8, 22, 56, 54, "b")
    g.hline(9, 62, 23, "c")
    g.vline(9, 23, 74, "c")
    g.vline(62, 24, 74, "a")
    g.box(8, 22, 56, 10, "-")
    g.hline(9, 62, 23, ":")
    g.hline(9, 62, 30, "=")
    for kx in (14, 22):
        g.disc(kx, 26.5, 2.6, "#")
        g.disc(kx, 26.5, 1.6, "A")
        g.set(kx, 25, "#")
    g.box(40, 24, 18, 6, "N")
    g.hline(42, 47, 26, "7")
    g.hline(42, 44, 27, "7")
    g.set(55, 26, "R")
    g.hline(9, 62, 74, "a")
    cx, cy = 36, 53
    g.disc(cx, cy, 20.5, "#")
    g.disc(cx, cy, 19.5, "D")
    g.disc(cx - 0.7, cy - 0.7, 18.6, "A")
    g.disc(cx, cy, 17.5, "C")
    g.disc(cx, cy, 16.5, "#")
    g.disc(cx, cy, 15.5, "2")
    dith(g, cx - 16, cy - 16, 33, 33, "3", 1, {"2"})
    # suds: paper and teal pale foam over the top of the drum
    for y in range(cy - 15, cy - 8):
        for x in range(cx - 16, cx + 17):
            if g.get(x, y) not in ("2", "3"):
                continue
            lvl = y - (cy - 15)
            if lvl < 3 or (lvl < 5 and (x + y) % 2 == 0) or (lvl < 7 and x % 2 == 0 and y % 2 == 0):
                g.set(x, y, "w" if (x * 3 + y) % 5 else "6")
    g.box(11, 47, 3, 12, "-")
    for x, y in ((25, 47), (24, 48), (23, 49)):
        f.set(x, y, "j")
    slots = [(39, 51), (23, 52), (31, 55)]
    return g, f, slots, [20, 37, 32, 32]


def fruit(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Fruit & veg: a market stall: scalloped striped awning, wooden posts, two crates."""
    d, s, b, l = ramp(aisle)
    g, f = body(aisle), Grid(W, H)
    g.box(9, 30, 54, 46, "T")
    for y in range(34, 75, 5):
        g.hline(10, 61, y, "U")
    for px in (6, 61):
        g.box(px, 28, 5, 48, "S")
        g.vline(px + 1, 29, 74, "Q")
        g.vline(px + 3, 29, 74, "T")
    # awning: 6 px stripes, green and paper, a scalloped edge
    y0 = 22
    g.rect(6, y0, 60, 7, "#")
    for x in range(7, 65):
        k = l if (x - 7) // 6 % 2 == 0 else "w"
        for y in range(y0 + 1, y0 + 6):
            g.set(x, y, k)
        i = (x - 7) % 6
        depth = [1, 2, 2, 2, 2, 1][i]
        for dy in range(depth):
            g.set(x, y0 + 6 + dy, k)
        g.set(x, y0 + 6 + depth, "#")
    g.hline(7, 64, y0 + 1, "z")
    for x in range(7, 65):
        if (x - 7) // 6 % 2 == 1:
            g.set(x, y0 + 1, "w")
    # crates: dark inside behind the capsules, the front lip drawn over them
    for ly in (51, 70):
        g.rect(10, ly - 5, 52, 5, "U")
        f.box(9, ly, 54, 6, "#")
        f.rect(10, ly + 1, 52, 4, "Q")
        f.hline(10, 61, ly + 1, "P")
        f.hline(10, 61, ly + 4, "S")
        for x in range(22, 61, 13):
            f.vline(x, ly + 1, ly + 4, "S")
    slots = [(11, 60), (23, 60), (35, 60), (47, 60), (11, 41), (23, 41), (35, 41), (47, 41)]
    return g, f, slots, [10, 31, 52, 44]


def bakery(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Bakery: a brick bread oven, a stone-ringed arched mouth glowing warm, two trays."""
    d, s, b, l = ramp(aisle)
    g, f = body(aisle), Grid(W, H)
    x0, x1, y0, y1 = 6, 65, 22, 75
    cx, r = 35.5, 30
    ccy = y0 + r
    shape = Grid(W, H)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if y >= ccy or (x - cx) ** 2 + (y - ccy) ** 2 <= (r + 0.3) ** 2:
                shape.g[y][x] = "1"
    for y in range(y0, y1 + 1):
        row = (y - y0) // 4
        for x in range(x0, x1 + 1):
            if shape.get(x, y) != "1":
                continue
            k = "F"
            if (y - y0) % 4 == 3 or (x + (0 if row % 2 == 0 else 4)) % 8 == 0:
                k = "f"
            elif x < cx - 10 and y < y0 + 18:
                k = "h"
            g.g[y][x] = k
            if any(shape.get(x + dx, y + dy) != "1" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g.g[y][x] = "#"
    # the mouth: stone ring (cream shade), ink edge, warm glow inside
    mx0, mx1, my0, my1 = 12, 59, 29, 73
    mcx, mr = (mx0 + mx1) / 2, (mx1 - mx0) / 2
    mcy = my0 + mr

    def inside(x: float, y: float, grow: float) -> bool:
        return (mx0 - grow <= x <= mx1 + grow) and y <= my1 and (y >= mcy or (x - mcx) ** 2 + (y - mcy) ** 2 <= (mr + grow + 0.3) ** 2)

    for y in range(my0 - 3, my1 + 1):
        for x in range(mx0 - 3, mx1 + 4):
            if inside(x, y, 0):
                g.set(x, y, "M")
            elif inside(x, y, 1):
                g.set(x, y, "#")
            elif inside(x, y, 3) and g.get(x, y) != ".":
                g.set(x, y, "b" if (x < mcx and y < mcy) else "a")
    for y in range(my0, my1 + 1):
        for x in range(mx0, mx1 + 1):
            if g.get(x, y) == "M":
                if y < my0 + 14:
                    g.set(x, y, "y")
                if y > my1 - 4:
                    g.set(x, y, "o")
    dith(g, mx0, my0, mx1 - mx0 + 1, 14, "Y", 1, {"y"})
    dith(g, mx0, my1 - 7, mx1 - mx0 + 1, 4, "o", 1, {"M"})
    for ty in (58, 72):
        g.hline(mx0, mx1, ty, "D")
        g.hline(mx0, mx1, ty + 1, "H")
    g.hline(x0, x1, 75, "#")
    slots = [(16, 59), (29, 59), (42, 59), (16, 45), (29, 45), (42, 45), (23, 32), (36, 32)]
    return g, f, slots, [12, 29, 48, 45]


def snacks(aisle: str) -> tuple[Grid, Grid, list, list]:
    """Snacks: a vending cabinet: one calm tomato light stripe (identity 10), glass with three spiral
    rows (one capsule per coil), keypad column and a pickup flap."""
    g, f = body(aisle), Grid(W, H)
    cabinet_box(g, aisle)
    g.box(10, 24, 52, 6, "R")
    g.hline(11, 60, 25, "o")
    g.hline(11, 60, 28, "r")
    g.box(10, 31, 43, 44, "#")
    glass(g, 11, 32, 41, 42)
    for cy_ in (45, 58, 71):
        for x in range(11, 52):
            p = x % 4
            if p == 0:
                g.set(x, cy_, "B")
                g.set(x, cy_ + 1, "D")
            elif p == 1:
                g.set(x, cy_ + 1, "B")
            elif p == 3:
                g.set(x, cy_, "D")
    g.box(54, 32, 8, 6, "#")
    g.rect(55, 33, 6, 4, "N")
    g.hline(56, 59, 34, "7")
    for j in range(3):
        for i in range(2):
            g.box(55 + i * 3, 40 + j * 4, 3, 3, "#")
            g.set(56 + i * 3, 41 + j * 4, "B")
    g.box(54, 63, 8, 10, "#")
    g.rect(55, 64, 6, 8, "N")
    g.hline(55, 60, 64, "H")
    glare(f, 13, 42, 7)
    glare(f, 13, 46, 3)
    slots = [(11, 58), (24, 58), (37, 58), (11, 45), (24, 45), (37, 45), (11, 32), (24, 32), (37, 32)]
    return g, f, slots, [11, 32, 41, 42]


def plinth(aisle: str) -> Grid:
    """The topper's stand; Snacks' is brown darkest so the red crisps bag parts from the red header."""
    d, s, b, l = ramp(aisle)
    if aisle == "snacks":
        d, s, b, l = "U", "U", "e", "f"
    g = Grid(36, 6)
    g.box(2, 0, 32, 5, b)
    g.hline(3, 32, 1, l)
    g.hline(3, 32, 3, s if s != b else d)
    g.hline(0, 35, 5, "%")
    return g


CABS = {"cold_cases": cold, "pantry": pantry, "household": household, "fruit_and_veg": fruit,
        "bakery": bakery, "snacks": snacks}


def main() -> None:
    for sub in ("off", "dim"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    data: dict = {"slots": {}, "win": {}, "decal": list(DECAL)}
    for aisle, fn in CABS.items():
        g, f, slots, win = fn(aisle)
        rods(g)
        g.png(OUT / f"cab_{aisle}.png")
        f.png(OUT / f"front_{aisle}.png")
        o = off(g)
        shutter(o, *SLOT_NEW)
        o.png(OUT / "off" / f"cab_{aisle}.png")
        off(f).png(OUT / "off" / f"front_{aisle}.png")
        dm = dim(g)
        dm.png(OUT / "dim" / f"cab_{aisle}.png")
        t = dm.copy()
        tag(t)
        t.png(OUT / "dim" / f"cabTag_{aisle}.png")
        shutter(dm, *SLOT_NEW)
        dm.png(OUT / "dim" / f"cabLid_{aisle}.png")
        dim(f).png(OUT / "dim" / f"front_{aisle}.png")
        c = capsule(aisle)
        c.png(OUT / f"capW_{aisle}.png")
        off(c).png(OUT / "off" / f"capW_{aisle}.png")
        dim(c).png(OUT / "dim" / f"capW_{aisle}.png")
        p = plinth(aisle)
        p.png(OUT / f"plinth_{aisle}.png")
        off(p).png(OUT / "off" / f"plinth_{aisle}.png")
        dim(p).png(OUT / "dim" / f"plinth_{aisle}.png")
        data["slots"][aisle] = slots
        data["win"][aisle] = win
    for item in build.TOPPERS.values():
        dim(Grid.from_png(build.ROOT / f"art/items_v2/{item}.png")).png(OUT / "dim" / f"item48_{item}.png")
    for name in ("coin", "padlock"):
        src = Grid.from_png(build.ROOT / f"art/icons/{name}.png")
        src.png(OUT / f"{name}.png")
        dim(src).png(OUT / "dim" / f"{name}.png")
        off(src).png(OUT / "off" / f"{name}.png")
    (HERE / "data_v2.js").write_text("// generated by cabinets.py\nconst TM2 = " + json.dumps(data) + ";\n",
                                     encoding="utf-8")
    print("cabinets written to", OUT)


if __name__ == "__main__":
    main()
