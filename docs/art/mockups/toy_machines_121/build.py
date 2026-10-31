"""#121 toy machines redraw: builds the mock-up's sprites into toy_machines_121/assets/ and the
layout data into toy_machines_121/data.js. Mock-up only, not game code and not tools/pixel_art.py.

Run from the repo root:  python docs/art/mockups/toy_machines_121/build.py

Everything is drawn in palette keys (art/src/palette.txt), 1 art px = 2 screen px in the page.
- items: the real art/items_v2/<id>.png sprites (48x48) and the real art/minis/<id>.png (7x7); no cuts.
- silhouettes: mid grey '=' fill, light rim ':' on top/left edges, ink '#' on the others.
- off/: every sprite again through OFF_MAP (BROKE / OUT OF ORDER: a palette swap, not a filter);
  machine sprites there also get a shut coin-slot lid.
- machines: A and B start from art/scenery/toy_machine.png recoloured per aisle like
  tools/pixel_art.py AISLE_MAPS; A gets a new body front (lineup card window, small coin slot,
  crank and chute); C draws six cabinet tops over the shared body.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
ASSETS = OUT / "assets"

PALETTE: dict[str, tuple[int, int, int, int]] = {}
for line in (ROOT / "art/src/palette.txt").read_text(encoding="utf-8").splitlines():
    if not line or line.startswith(";"):
        continue
    key, rest = line[0], line[2:].split()
    if key == ".":
        PALETTE["."] = (0, 0, 0, 0)
        continue
    h = rest[0]
    PALETTE[key] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
BY_RGBA = {v: k for k, v in PALETTE.items()}

AISLE_MAPS = {
    "cold_cases": ("2", "3", "4", "5"),
    "pantry": ("m", "m", "M", "y"),
    "household": ("=", "=", "-", ":"),
    "fruit_and_veg": ("1", "g", "g", "G"),
    "bakery": ("F", "F", "h", "b"),
    "snacks": ("e", "e", "f", "F"),
}
AISLES = [
    ("cold_cases", "Cold cases", ["cream", "ham_ends"]),
    ("pantry", "Pantry", ["sugar_cubes", "mixed_herbs"]),
    ("household", "Household", ["egg_timer", "chipped_mug", "odd_socks"]),
    ("fruit_and_veg", "Fruit & veg", ["fruit_salad", "strawberries", "grapefruit", "wonky_carrot", "lemon",
                                      "bruised_apples", "soft_tomatoes", "potatoes"]),
    ("bakery", "Bakery", ["baguette", "scone", "croissant", "broken_biscuit", "iced_bun", "birthday_candles",
                          "squashed_cake", "stale_doughnut"]),
    ("snacks", "Snacks", ["crisps", "cereal_bar", "bent_lolly", "pick_n_mix", "stale_popcorn", "breadsticks",
                          "dusty_toffees"]),
]
NAMES = {
    "cream": "Cream", "ham_ends": "Ham ends", "sugar_cubes": "Sugar cubes", "mixed_herbs": "Mixed herbs",
    "egg_timer": "Egg timer", "chipped_mug": "Chipped mug", "odd_socks": "Odd socks", "fruit_salad": "Fruit salad",
    "strawberries": "Strawberries", "grapefruit": "Grapefruit", "wonky_carrot": "Wonky carrot", "lemon": "Lemon",
    "bruised_apples": "Bruised apples", "soft_tomatoes": "Soft tomatoes", "potatoes": "Potatoes",
    "baguette": "Baguette", "scone": "Scone", "croissant": "Croissant", "broken_biscuit": "Broken biscuit",
    "iced_bun": "Iced bun", "birthday_candles": "Birthday candles", "squashed_cake": "Squashed cake",
    "stale_doughnut": "Stale doughnut", "crisps": "Crisps", "cereal_bar": "Cereal bar", "bent_lolly": "Bent lolly",
    "pick_n_mix": "Pick 'n' mix", "stale_popcorn": "Stale popcorn", "breadsticks": "Breadsticks",
    "dusty_toffees": "Dusty toffees",
}


# ---------------------------------------------------------------- key grids
class Grid:
    def __init__(self, w: int, h: int, fill: str = ".") -> None:
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    @classmethod
    def from_png(cls, path: Path) -> "Grid":
        im = Image.open(path).convert("RGBA")
        g = cls(im.width, im.height)
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                c = px[x, y]
                g.g[y][x] = "." if c[3] == 0 else BY_RGBA[c]
        return g

    def copy(self) -> "Grid":
        n = Grid(self.w, self.h)
        n.g = [row[:] for row in self.g]
        return n

    def get(self, x: int, y: int) -> str:
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else "."

    def set(self, x: int, y: int, k: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = k

    def rect(self, x: int, y: int, w: int, h: int, k: str) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, k)

    def box(self, x: int, y: int, w: int, h: int, fill: str, ink: str = "#") -> None:
        self.rect(x, y, w, h, ink)
        self.rect(x + 1, y + 1, w - 2, h - 2, fill)

    def hline(self, x0: int, x1: int, y: int, k: str) -> None:
        for x in range(x0, x1 + 1):
            self.set(x, y, k)

    def vline(self, x: int, y0: int, y1: int, k: str) -> None:
        for y in range(y0, y1 + 1):
            self.set(x, y, k)

    def disc(self, cx: float, cy: float, r: float, k: str) -> None:
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.set(x, y, k)

    def paste(self, other: "Grid", ox: int, oy: int, mask: "Grid | None" = None) -> None:
        for y in range(other.h):
            for x in range(other.w):
                k = other.g[y][x]
                if k == ".":
                    continue
                if mask is not None and not mask.get(ox + x, oy + y) == "1":
                    continue
                self.set(ox + x, oy + y, k)

    def swap(self, mapping: dict[str, str]) -> None:
        for row in self.g:
            for i, k in enumerate(row):
                row[i] = mapping.get(k, k)

    def outline(self) -> None:
        """Ink every opaque pixel that touches a transparent one (4-neighbours) or the edge."""
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] == ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy) == ".":
                        edge.append((x, y))
                        break
        for x, y in edge:
            self.g[y][x] = "#"

    def png(self, path: Path) -> None:
        im = Image.new("RGBA", (self.w, self.h))
        im.putdata([PALETTE[k] for row in self.g for k in row])
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)


def ramp_map(aisle: str) -> dict[str, str]:
    return dict(zip(("2", "3", "4", "5"), AISLE_MAPS[aisle]))


# ---------------------------------------------------------------- items
def silhouette(src: Grid) -> Grid:
    """A shadowed figurine, not a hole: mid grey '=' fill, a light rim ':' where light from the top left
    meets the edge, ink '#' on the other edges (critique: flat near-black blobs read as holes)."""
    o = Grid(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            if src.g[y][x] == ".":
                continue
            up, lf = src.get(x, y - 1) == ".", src.get(x - 1, y) == "."
            dn, rt = src.get(x, y + 1) == ".", src.get(x + 1, y) == "."
            o.g[y][x] = ":" if (up or lf) else ("#" if (dn or rt) else "=")
    return o


def _nearest(rgb: tuple[float, float, float]) -> str:
    best, bk = 1e9, "#"
    for k, c in PALETTE.items():
        if k == ".":
            continue
        d = sum((a - b) ** 2 for a, b in zip(rgb, c[:3]))
        if d < best:
            best, bk = d, k
    return bk


OFF_MAP: dict[str, str] = {}
for _k, _c in PALETTE.items():
    if _k == ".":
        continue
    _l = 0.3 * _c[0] + 0.59 * _c[1] + 0.11 * _c[2]
    OFF_MAP[_k] = _nearest(tuple((_l + 0.3 * (v - _l)) * 0.74 for v in _c[:3]))


def off(g: Grid) -> Grid:
    """The machine with its lights out: a palette swap (desaturated, darker), never a brightness filter."""
    o = g.copy()
    o.swap(OFF_MAP)
    return o


def shutter(g: Grid, x: int, y: int, w: int, h: int) -> None:
    """A shut coin-slot lid: a steel plate with a red bar across, so BROKE shows by shape, not tint."""
    g.box(x, y, w, h, "D")
    g.hline(x + 1, x + w - 2, y + 1, "B")
    g.rect(x + 1, y + h // 2 - 1, w - 2, 2, "r")


QMARK = ["###.", "...#", "..#.", ".#..", "....", ".#.."]  # 4x6 '?'


def qmark_tile(size: int, aisle: str) -> Grid:
    """A closed capsule token with a paper '?': what a '?' mode shows instead of an item."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = Grid(size, size)
    r = size / 2 - 1.5
    c = (size - 1) / 2
    g.disc(c, c + 0.5, r + 1, "#")
    g.disc(c, c + 0.5, r, b)
    for y in range(size):
        for x in range(size):
            if g.g[y][x] == b and (x - c) + (y - c) > r * 0.9:
                g.g[y][x] = s if s != d else d
            if g.g[y][x] == b and (x - c) + (y - c) < -r * 1.0:
                g.g[y][x] = l
    sc = max(1, size // 12)
    ox = int(c - 2 * sc + 1)
    oy = int(c - 3 * sc + 1)
    for j, row in enumerate(QMARK):
        for i, ch in enumerate(row):
            if ch == "#":
                g.rect(ox + i * sc, oy + j * sc, sc, sc, "w")
    return g


# ---------------------------------------------------------------- capsules
CAPSULE_SHAPE = [
    "....#####....",
    "..##.....##..",
    ".#.........#.",
    "#...........#",
    "#...........#",
    "#...........#",
    "#...........#",
    "#...........#",
    "#...........#",
    "#...........#",
    ".#.........#.",
    "..##.....##..",
    "....#####....",
]


def capsule_inside() -> Grid:
    """'1' where a pixel lies inside the 13x13 capsule outline."""
    m = Grid(13, 13)
    for y, row in enumerate(CAPSULE_SHAPE):
        xs = [i for i, ch in enumerate(row) if ch == "#"]
        for x in range(xs[0] + 1, xs[-1]):
            if y not in (0, 12):
                m.g[y][x] = "1"
    return m


INSIDE = capsule_inside()


def capsule_a(aisle: str, mini: Grid | None) -> Grid:
    """Look A: today's capsule (aisle top half, glass bottom half) with the mini peeking in the glass."""
    g = Grid.from_png(ROOT / "art/scenery/toy_capsule.png")
    g.swap(ramp_map(aisle))
    if mini is not None:
        glass = Grid(13, 13)
        for y in range(7, 12):
            for x in range(13):
                if INSIDE.get(x, y) == "1":
                    glass.g[y][x] = "1"
        g.paste(mini, 3, 7, mask=glass)
    return g


def capsule_b(aisle: str, inner: Grid | None, closed: bool) -> Grid:
    """Look B: a clear capsule with a thin aisle cap; the figurine (mini) stands inside."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = Grid(13, 13)
    for y, row in enumerate(CAPSULE_SHAPE):
        for x, ch in enumerate(row):
            if ch == "#":
                g.g[y][x] = "#"
    for y in range(13):
        for x in range(13):
            if INSIDE.get(x, y) != "1":
                continue
            if closed:
                g.g[y][x] = b
            elif y <= 2:
                g.g[y][x] = b
            elif y == 3:
                g.g[y][x] = "#"
            else:
                g.g[y][x] = "j"
    if closed:
        # one closed token, no seam, a small paper '?' on it
        g.hline(4, 6, 2, l)
        q = ["##.", "..#", ".#.", "...", ".#."]
        for j, row in enumerate(q):
            for i, ch in enumerate(row):
                if ch == "#":
                    g.set(5 + i, 4 + j, "w")
        return g
    g.hline(4, 6, 1, l)
    g.set(10, 6, "p")
    g.set(10, 7, "p")
    g.set(2, 5, "w")
    if inner is not None:
        g.paste(inner, 3, 4, mask=INSIDE)
    return g


# ---------------------------------------------------------------- machines
BASE = Grid.from_png(ROOT / "art/scenery/toy_machine.png")


def machine_b(aisle: str) -> Grid:
    g = BASE.copy()
    g.swap(ramp_map(aisle))
    return g


SLOT_BASE = (17, 91, 11, 15)    # the base machine's brass coin slot (ink box), shut by BROKE
SLOT_A = (14, 116, 9, 10)


def machine_a(aisle: str) -> Grid:
    """The globe machine with a lineup card on its front (the full body width, three 14 px cells: the
    real minis at 2x), and a lower strip with the coin slot, crank and chute."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = BASE.copy()
    g.swap(ramp_map(aisle))
    for y in range(88, 127):
        for x in range(13, 59):
            g.set(x, y, b)
    g.box(10, 86, 52, 29, "B")          # steel frame
    g.hline(11, 60, 87, "A")
    g.box(12, 88, 48, 25, "w")          # the printed card
    g.rect(13, 89, 46, 3, b)            # aisle band
    g.hline(13, 58, 89, l)
    g.hline(13, 58, 91, d if d != b else "#")
    g.box(14, 116, 9, 10, "L")
    g.hline(15, 21, 117, "n")
    g.rect(17, 118, 3, 6, "#")
    g.hline(15, 21, 124, "l")
    g.disc(31, 120.5, 5.6, "#")
    g.disc(31, 120.5, 4.6, "B")
    g.disc(30, 119.5, 2.6, "A")
    g.hline(27, 35, 120, "#")
    g.hline(28, 34, 121, "H")
    g.rect(35, 119, 2, 3, "M")
    g.box(40, 115, 17, 12, "C")
    g.box(41, 120, 15, 6, "N")
    g.hline(41, 55, 116, "B")
    return g


A_CARD_CELLS = [(13, 96), (29, 96), (45, 96)]   # top-left of each 14x14 cell (art px)


def glyph_badge(aisle: str) -> Grid:
    """The aisle glyph on a paper disc (11x11), repeated on the machine body so the aisle never
    reads by colour alone."""
    g = Grid(11, 11)
    g.disc(5, 5, 5.4, "#")
    g.disc(5, 5, 4.4, "w")
    g.paste(Grid.from_png(ROOT / f"art/icons/aisle_{aisle}.png"), 1, 1)
    return g


def shared_body(aisle: str) -> Grid:
    """C: the base machine's sign and body (rows 84..139), everything between cleared."""
    g = BASE.copy()
    g.swap(ramp_map(aisle))
    for y in range(19, 84):
        for x in range(72):
            g.g[y][x] = "."
    return g


# C cabinets: every top fits x 6..65 (the 56 px body + 4 art px) and starts at y 22, so the sign
# (rows 0..18) keeps 3 rows of visible rods under it. Slots are top-left corners of 14x14 cells
# (the real 7x7 minis at 2x), one per item the aisle can hold, at least 1 art px apart.
TOP_X0, TOP_X1, TOP_Y0 = 6, 65, 22


def rods(g: Grid, top: int, xs: tuple[int, ...] = (18, 51)) -> None:
    for x in xs:
        for y in range(19, top):
            g.set(x - 1, y, "#")
            g.set(x, y, "B")
            g.set(x + 1, y, "#")


def cabinet_cold(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Cold cases: a display fridge. Dark back wall (depth, like the oven), lit header, steel door frame."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0)
    x0, y0, w, h = TOP_X0, TOP_Y0, TOP_X1 - TOP_X0 + 1, 84 - TOP_Y0
    g.box(x0, y0, w, h, b)
    g.hline(x0 + 1, x0 + w - 2, y0 + 1, l)
    g.vline(x0 + 1, y0 + 1, y0 + h - 2, l)
    g.vline(x0 + w - 2, y0 + 2, y0 + h - 2, s)
    g.box(x0 + 3, y0 + 2, w - 6, 5, "#")
    g.rect(x0 + 4, y0 + 3, w - 8, 3, "j")
    g.hline(x0 + 4, x0 + w - 5, y0 + 5, "6")
    gx, gy, gw, gh = 10, 30, 52, 51
    g.box(gx - 2, gy - 2, gw + 4, gh + 4, "#")
    g.rect(gx - 1, gy - 1, gw + 2, 1, "B")
    g.vline(gx - 1, gy - 1, gy + gh, "B")
    g.vline(gx + gw, gy - 1, gy + gh, "E")
    g.hline(gx - 1, gx + gw, gy + gh, "E")
    g.rect(gx, gy, gw, gh, "2")
    g.rect(gx, gy, gw, 2, "3")
    slots = []
    for sy in (45, 62, 79):
        g.hline(gx, gx + gw - 1, sy, "6")
        g.hline(gx, gx + gw - 1, sy + 1, "3")
        for c in range(3):
            slots.append((gx + 1 + c * 17, sy - 14))
    g.box(63, 46, 2, 16, "B")
    g.hline(x0, x0 + w - 1, 83, "#")
    return g, slots, {"window": [gx, gy, gw, gh]}


def cabinet_pantry(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Pantry: a big storage jar, mustard screw lid."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0, (24, 47))
    jx0, jx1, jy0, jy1 = 8, 63, 30, 83
    shape = Grid(72, 140)
    for y in range(jy0, jy1 + 1):
        inset = 0
        if y < jy0 + 5:
            inset = [7, 4, 2, 1, 0][y - jy0]
        if y > jy1 - 3:
            inset = [1, 2, 3][y - (jy1 - 2)]
        for x in range(jx0 + inset, jx1 - inset + 1):
            shape.g[y][x] = "1"
    for y in range(jy0, jy1 + 1):
        for x in range(jx0, jx1 + 1):
            if shape.get(x, y) == "1":
                edge = any(shape.get(x + dx, y + dy) != "1" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                g.g[y][x] = "#" if edge else "p"
    for y in range(jy0 + 2, jy1 - 2):
        for x in range(jx1 - 4, jx1):
            if g.g[y][x] == "p":
                g.g[y][x] = "5"
    g.box(16, 22, 40, 8, b)
    g.hline(17, 54, 23, l)
    for x in range(18, 54, 3):
        g.vline(x, 24, 27, d)
    g.hline(17, 54, 28, d)
    slots = [(12, 36), (29, 36), (46, 36), (12, 52), (29, 52), (46, 52), (12, 68), (29, 68), (46, 68)]
    return g, slots, {"window": [jx0 + 2, jy0 + 4, jx1 - jx0 - 3, jy1 - jy0 - 6]}


def cabinet_household(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Household: a front-loader with knobs on top and a round porthole."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0)
    x0, y0, w, h = 8, TOP_Y0, 56, 84 - TOP_Y0
    g.box(x0, y0, w, h, "B")
    g.hline(x0 + 1, x0 + w - 2, y0 + 1, "A")
    g.vline(x0 + w - 2, y0 + 2, y0 + h - 2, "C")
    g.box(x0, y0, w, 9, b)
    g.hline(x0 + 1, x0 + w - 2, y0 + 1, l)
    g.disc(x0 + 7, y0 + 4.5, 2.6, "#")
    g.disc(x0 + 7, y0 + 4.5, 1.6, "A")
    g.disc(x0 + 15, y0 + 4.5, 2.6, "#")
    g.disc(x0 + 15, y0 + 4.5, 1.6, "A")
    g.box(x0 + 32, y0 + 2, 18, 5, "N")
    g.hline(x0 + 34, x0 + 38, y0 + 4, "7")
    cx, cy = 36, 56
    g.disc(cx, cy, 22.5, "#")
    g.disc(cx, cy, 21.5, "C")
    g.disc(cx - 0.6, cy - 0.6, 20.5, "A")
    g.disc(cx, cy, 19.5, "D")
    g.disc(cx, cy, 18.5, "#")
    g.disc(cx, cy, 17.5, "H")
    g.disc(cx - 1, cy - 1, 16.2, "E")
    g.hline(x0, x0 + w - 1, 83, "#")
    slots = [(29, 41), (22, 55), (37, 55)]
    return g, slots, {"porthole": [cx, cy, 17], "window": [cx - 16, cy - 16, 32, 32]}


def cabinet_fruit(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Fruit & veg: a market stall: scalloped awning, wooden posts, three crate tiers."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0)
    for px in (6, 61):
        g.box(px, 28, 5, 56, "S")
        g.vline(px + 1, 29, 82, "Q")
        g.vline(px + 3, 29, 82, "T")
    g.box(10, 31, 52, 53, "T")
    for y in range(34, 83, 4):
        g.hline(11, 60, y, "U")
    slots = []
    lips = []
    for ty in (33, 49, 65):
        for c in range(3):
            slots.append((12 + c * 17, ty))
        lips.append([10, ty + 11, 52, 4])
    g.rect(TOP_X0, TOP_Y0, TOP_X1 - TOP_X0 + 1, 7, "#")
    for x in range(TOP_X0 + 1, TOP_X1):
        k = l if (x - TOP_X0 - 1) // 6 % 2 == 0 else "w"
        for y in range(TOP_Y0 + 1, TOP_Y0 + 6):
            g.set(x, y, k)
    for x in range(TOP_X0 + 1, TOP_X1, 6):
        for i in range(6):
            if x + i >= TOP_X1:
                break
            k = l if (x - TOP_X0 - 1) // 6 % 2 == 0 else "w"
            depth = [1, 2, 2, 2, 2, 1][i]
            for dy in range(depth):
                g.set(x + i, TOP_Y0 + 6 + dy, k)
            g.set(x + i, TOP_Y0 + 6 + depth, "#")
    g.hline(TOP_X0 + 1, TOP_X1 - 1, TOP_Y0 + 1, "A")
    return g, slots, {"lips": lips, "window": [11, 31, 50, 52]}


def crate_lip(w: int, aisle: str) -> Grid:
    g = Grid(w, 4)
    g.box(0, 0, w, 4, "Q")
    g.hline(1, w - 2, 1, "P")
    for x in range(17, w - 1, 17):
        g.vline(x, 1, 2, "T")
    return g


def cabinet_bakery(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Bakery: a brick bread oven, arched mouth with a warm glow and three trays (8 slots)."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0 + 2)
    x0, x1, y0, y1 = TOP_X0, TOP_X1, TOP_Y0, 83
    cx = (x0 + x1) / 2
    r = (x1 - x0) / 2
    shape = Grid(72, 140)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if y >= y0 + r or (x - cx) ** 2 + (y - (y0 + r)) ** 2 <= (r + 0.3) ** 2:
                shape.g[y][x] = "1"
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if shape.get(x, y) != "1":
                continue
            row = (y - y0) // 4
            off_ = 0 if row % 2 == 0 else 4
            k = b
            if (y - y0) % 4 == 3 or (x + off_) % 8 == 0:
                k = s
            if x < cx - 12 and y < y0 + 20 and k == b:
                k = l
            g.g[y][x] = k
            if any(shape.get(x + dx, y + dy) != "1" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g.g[y][x] = "#"
    mx0, mx1, my0, my1 = 12, 59, 27, 81
    mcx = (mx0 + mx1) / 2
    mr = (mx1 - mx0) / 2
    for y in range(my0 - 1, my1 + 2):
        for x in range(mx0 - 1, mx1 + 2):
            inside = y >= my0 + mr or (x - mcx) ** 2 + (y - (my0 + mr)) ** 2 <= (mr + 0.3) ** 2
            ring = y >= my0 + mr - 1 or (x - mcx) ** 2 + (y - (my0 + mr)) ** 2 <= (mr + 1.3) ** 2
            if y > my1 + 1:
                continue
            if inside and mx0 <= x <= mx1 and y <= my1:
                g.g[y][x] = "Y"
            elif ring and g.g[y][x] != ".":
                g.g[y][x] = "#"
    for y in range(my0, my1 + 1):
        for x in range(mx0, mx1 + 1):
            if g.g[y][x] == "Y":
                if y > my1 - 5:
                    g.g[y][x] = "o"
                elif y > my1 - 16:
                    g.g[y][x] = "y"
    slots = [(21, 36), (37, 36)] + [(13 + c * 16, 51) for c in range(3)] + [(13 + c * 16, 66) for c in range(3)]
    for ty in (50, 65, 80):
        g.hline(mx0, mx1, ty, "D")
        g.hline(mx0, mx1, ty + 1, "H")
    g.hline(x0, x1, 83, "#")
    return g, slots, {"mouth": [mx0, my0, mx1 - mx0 + 1, my1 - my0 + 1],
                      "window": [mx0, my0 + 6, mx1 - mx0 + 1, my1 - my0 - 6]}


def cabinet_snacks(aisle: str) -> tuple[Grid, list[tuple[int, int]], dict]:
    """Snacks: a vending tower: light box, a light glass with three spiral rows, keypad column."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = shared_body(aisle)
    rods(g, TOP_Y0)
    x0, y0, w, h = 8, TOP_Y0, 56, 84 - TOP_Y0
    g.box(x0, y0, w, h, b)
    g.vline(x0 + 1, y0 + 1, y0 + h - 2, l)
    g.vline(x0 + w - 2, y0 + 1, y0 + h - 2, d)
    g.box(x0 + 2, y0 + 2, w - 4, 6, "R")
    g.hline(x0 + 3, x0 + w - 4, y0 + 3, "o")
    g.hline(x0 + 3, x0 + w - 4, y0 + 6, "r")
    for x in range(x0 + 6, x0 + w - 6, 4):
        g.set(x, y0 + 4, "Y")
        g.set(x + 1, y0 + 5, "Y")
    gx, gy, gw, gh = 11, 31, 45, 51
    g.box(gx - 1, gy - 1, gw + 2, gh + 2, "#")
    g.rect(gx, gy, gw, gh, "A")
    g.rect(gx, gy, gw, 2, "W")
    g.rect(gx + gw - 2, gy, 2, gh, "B")
    slots = []
    for ry in (32, 49, 66):
        for c in range(3):
            slots.append((gx + 1 + c * 15, ry))
    coils = [[gx, ry + 13, gw, 2] for ry in (32, 49, 66)]
    kx = 57
    g.box(kx, gy - 1, 6, 22, "N")
    g.rect(kx + 1, gy, 4, 3, "7")
    for j in range(4):
        g.set(kx + 2, gy + 5 + j * 3, "B")
        g.set(kx + 3, gy + 5 + j * 3, "B")
    g.box(kx, gy + 23, 6, 9, "L")
    g.rect(kx + 2, gy + 25, 2, 5, "#")
    g.hline(x0, x0 + w - 1, 83, "#")
    return g, slots, {"coils": coils, "window": [gx, gy, gw, gh]}


def coil_strip(w: int, phase: int) -> Grid:
    g = Grid(w, 2)
    for x in range(w):
        if (x + phase) % 4 == 0:
            g.set(x, 0, "B")
            g.set(x, 1, "D")
        elif (x + phase) % 4 == 1:
            g.set(x, 1, "B")
        elif (x + phase) % 4 == 3:
            g.set(x, 0, "D")
    return g


CABINETS = {
    "cold_cases": cabinet_cold, "pantry": cabinet_pantry, "household": cabinet_household,
    "fruit_and_veg": cabinet_fruit, "bakery": cabinet_bakery, "snacks": cabinet_snacks,
}

# B: one emblem per aisle, chosen for how fast its silhouette says the aisle (critique: Cream read as
# a spray bottle, Egg timer as a timer, Fruit salad as confetti, the baguette's diagonal broke the row).
TOPPERS = {
    "cold_cases": "ham_ends", "pantry": "sugar_cubes", "household": "odd_socks",
    "fruit_and_veg": "strawberries", "bakery": "croissant", "snacks": "crisps",
}


def plinth(aisle: str) -> Grid:
    """B: the stand under the topper: a 4 art px block in the aisle colour on a 1 px wider contact shadow."""
    d, s, b, l = AISLE_MAPS[aisle]
    g = Grid(36, 6)
    g.box(2, 0, 32, 5, b)
    g.hline(3, 32, 1, l)
    g.hline(3, 32, 3, s if s != b else d)
    g.hline(0, 35, 5, "%")
    return g


def bottom_pad(path: Path) -> int:
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    for y in range(im.height - 1, -1, -1):
        if any(a.getpixel((x, y)) for x in range(im.width)):
            return im.height - 1 - y
    return 0


def save_both(g: Grid, name: str, extra_off=None) -> None:
    g.png(ASSETS / name)
    o = off(g)
    if extra_off:
        extra_off(o)
    o.png(ASSETS / "off" / name)


def main() -> None:
    for p in ASSETS.glob("**/*.png"):
        p.unlink()
    data: dict = {"aisles": [], "slotsC": {}, "extrasC": {}, "toppers": TOPPERS, "topperPad": {},
                  "aCells": A_CARD_CELLS}
    data["globeSlots"] = [[24, 69], [36, 70], [48, 69], [30, 59], [42, 59], [19, 60], [53, 60], [36, 49]]
    for aisle, name, items in AISLES:
        data["aisles"].append({"id": aisle, "name": name, "items": items, "names": [NAMES[i] for i in items],
                               "ramp": [("#%02x%02x%02x" % PALETTE[k][:3]) for k in AISLE_MAPS[aisle]]})
        save_both(machine_a(aisle), f"machine_a_{aisle}.png", lambda o: shutter(o, *SLOT_A))
        save_both(machine_b(aisle), f"machine_b_{aisle}.png", lambda o: shutter(o, *SLOT_BASE))
        g, slots, extra = CABINETS[aisle](aisle)
        save_both(g, f"machine_c_{aisle}.png", lambda o: shutter(o, *SLOT_BASE))
        data["slotsC"][aisle] = slots
        data["extrasC"][aisle] = extra
        save_both(plinth(aisle), f"plinth_{aisle}.png")
        save_both(glyph_badge(aisle), f"badge_{aisle}.png")
        save_both(qmark_tile(7, aisle), f"q7_{aisle}.png")
        save_both(qmark_tile(48, aisle), f"q48_{aisle}.png")
        save_both(capsule_a(aisle, None), f"capA_{aisle}.png")
        for item in items:
            big = Grid.from_png(ROOT / f"art/items_v2/{item}.png")
            mini = Grid.from_png(ROOT / f"art/minis/{item}.png")
            save_both(big, f"item48_{item}.png")
            save_both(silhouette(big), f"item48s_{item}.png")
            save_both(mini, f"mini_{item}.png")
            save_both(silhouette(mini), f"minis_{item}.png")
    for aisle, item in TOPPERS.items():
        data["topperPad"][aisle] = bottom_pad(ROOT / f"art/items_v2/{item}.png")
    save_both(crate_lip(52, "fruit_and_veg"), "crate_lip.png")
    for p in range(4):
        save_both(coil_strip(45, p), f"coil_{p}.png")
    for src, dst in (("art/scenery/exit_vestibule.png", "exit_vestibule.png"), ("art/icons/coin.png", "coin.png"),
                     ("art/icons/warning.png", "warning.png")):
        Image.open(ROOT / src).convert("RGBA").save(ASSETS / dst)
    save_both(Grid.from_png(ROOT / "art/effects/sticker_label.png"), "sticker_label.png")
    save_both(Grid.from_png(ROOT / "art/icons/coin.png"), "coin.png")
    for aisle, _, _ in AISLES:
        Image.open(ROOT / f"art/icons/aisle_{aisle}.png").convert("RGBA").save(ASSETS / f"glyph_{aisle}.png")
    ui = ROOT / "docs/art/mockups/capsule_63_src/assets"
    for f in ("button.png", "sign.png", "top_button.png", "sticker_burst.png"):
        Image.open(ui / f).convert("RGBA").save(ASSETS / f)
    (OUT / "data.js").write_text("// generated by build.py\nconst TM = " + json.dumps(data) + ";\n", encoding="utf-8")
    print("assets:", len(list(ASSETS.glob("**/*.png"))))


if __name__ == "__main__":
    main()
