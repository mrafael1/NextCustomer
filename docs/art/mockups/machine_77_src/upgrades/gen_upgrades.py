"""#77 prep: builds the BIG and GOLDEN tier sources for Banana, Milk, Eggs and Coffee.

Reads the real 48x48 sources in art/src/items_v2/ (read only) and writes NEW sources to
docs/art/mockups/machine_77_src/upgrades/src/items_v2/<item>_{big,golden}.txt, plus a copy of
art/src/palette.txt, so tools/pixel_art.py can lint and build them out of the game tree:

    python docs/art/mockups/machine_77_src/upgrades/gen_upgrades.py
    python tools/pixel_art.py check --src docs/art/mockups/machine_77_src/upgrades/src \
        --out docs/art/mockups/machine_77_src/upgrades/png
    (build / sheet the same way, --reports docs/art/mockups/machine_77_src/upgrades/sheet)

BIG is "a bigger pack of the same item" on the same grid, built from the plain rows:
  - Banana: round 2 draws it by hand (redraw_r2.py): five fingers from the same stem.
  - Milk:   a wider 2 l carton (front face widened, gable kept), "2L" printed on the label.
  - Eggs:   round 2 draws it by hand (redraw_r2.py): a wider open carton, 2 rows of 4.
  - Coffee: a wider jar (two bean periods inserted, the label emblem kept).
GOLDEN is the BIG rows remapped to the brass/gold ramp by luminance, ink kept, plus a light streak.
In the game the BIG files would become art/src/items_v2/<item>_big.txt sources (hand-touched);
GOLDEN would be a palette map in tools/pixel_art.py, not a drawn source.
"""

from __future__ import annotations

import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]
ART_SRC = REPO / "art" / "src"
OUT = HERE / "src" / "items_v2"
W = H = 48


def load(name: str) -> list[list[str]]:
    rows = []
    for line in (ART_SRC / "items_v2" / f"{name}.txt").read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith(";") or s.startswith("@"):
            continue
        rows.append(list(s))
    assert len(rows) == H and all(len(r) == W for r in rows), name
    return rows


def blank() -> list[list[str]]:
    return [["."] * W for _ in range(H)]


def paste(dst, src, dx, dy, rows=None):
    for y, row in enumerate(src):
        if rows is not None and y not in rows:
            continue
        for x, k in enumerate(row):
            if k == ".":
                continue
            X, Y = x + dx, y + dy
            if 0 <= X < W and 0 <= Y < H:
                dst[Y][X] = k


def reink(g):
    """Every opaque pixel on the outline (touching transparency or the edge) becomes ink; rows 0-1 cleared."""
    for y in range(2):
        g[y] = ["."] * W
    out = [r[:] for r in g]
    for y in range(H):
        for x in range(W):
            if g[y][x] in (".", "#"):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if not (0 <= X < W and 0 <= Y < H) or g[Y][X] == ".":
                    out[y][x] = "#"
                    break
    return out


def insert_cols(rows, at, src_cols):
    """Inserts copies of columns src_cols (a list of indices) at index `at` in every row."""
    return [r[:at] + [r[c] for c in src_cols] + r[at:] for r in rows]


def shift_x(rows, dx):
    out = []
    for r in rows:
        if dx < 0:
            assert all(k == "." for k in r[:-dx])
            r = r[-dx:] + ["."] * -dx
        elif dx > 0:
            r = ["."] * dx + r[:-dx]
        out.append(r)
    return out


def fit(rows):
    """Crops rows wider than 48 (only transparent columns may be dropped) to 48, centred on content."""
    width = len(rows[0])
    if width == W:
        return rows
    used = [x for x in range(width) if any(r[x] != "." for r in rows)]
    lo, hi = used[0], used[-1]
    content = hi - lo + 1
    assert content <= W, content
    start = max(0, lo - (W - content) // 2)
    start = min(start, width - W) if width >= W else start
    out = [r[start:start + W] for r in rows]
    if width < W:
        out = [r + ["."] * (W - len(r)) for r in rows]
    return out


# ---------------------------------------------------------------- BIG sprites

def banana_big():
    plain = load("banana")
    g = blank()
    # the back bunch: up 5, left 3, its fingers a shade darker (in shadow behind the front bunch)
    shade = {"Y": "y", "y": "M", "M": "m", "m": "u", "e": "e", "G": "g", "g": "g"}
    back = [[shade.get(k, k) for k in r] for r in plain]
    paste(g, back, -3, -5)
    g = reink(g)
    paste(g, plain, 3, 0)
    return reink(g)


def milk_big():
    plain = load("milk")
    k = 10
    out = []
    for y, r in enumerate(plain):
        row = r[:]
        xs = [x for x, c in enumerate(row) if c != "."]
        if not xs:
            out.append(row + ["."] * k)
            continue
        left = xs[0]
        if y >= 22:                       # the box: widen the front face inside the left wall
            at = 14
        elif y >= 9:                      # the gable's front face: widen just inside the slope
            at = left + 3
        else:                             # the ridge fin: widen it (a longer ridge on a wider carton)
            at = left + 2
        fillsrc = at
        row = row[:at] + [row[fillsrc]] * k + row[at:]
        out.append(row)
    out = fit(out)
    # "2L" in paper on the teal label, left of the milk drop (3x5 digits, 1 px apart)
    x0 = min(x for x in range(W) if out[31][x] == "4") + 3
    two = ["www", "..w", "www", "w..", "www"]
    ell = ["w..", "w..", "w..", "w..", "www"]
    for j in range(5):
        for i in range(3):
            if two[j][i] == "w":
                out[31 + j][x0 + i] = "w"
            if ell[j][i] == "w":
                out[31 + j][x0 + 4 + i] = "w"
    return reink(out)


def eggs_big():
    plain = load("eggs")
    g = blank()
    # back row: the lid and the first egg row (rows 4..31), lifted 2
    paste(g, plain, 0, -2, rows=range(4, 28))
    g = reink(g)
    # front row: from the rim line (row 15) down, with 7 of the 11 identical cup rows removed, moved down 7
    keep = [y for y in range(15, 48) if not (33 <= y <= 39)]
    front = [plain[y] for y in keep]
    top = H - len(front)
    for j, r in enumerate(front):
        for x, c in enumerate(r):
            if c != ".":
                g[top + j][x] = c
    # the rim line of the front row sits under the back eggs: ink above it, so the rows separate
    return reink(g)


def coffee_big():
    plain = load("coffee")
    rows = insert_cols(plain, 29, list(range(29, 34)) + list(range(29, 34)))
    rows = fit(rows)
    return reink(rows)


# ---------------------------------------------------------------- GOLDEN

PALETTE: dict[str, tuple[int, int, int]] = {}


def read_palette():
    for line in (ART_SRC / "palette.txt").read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith(";"):
            continue
        p = s.split()
        if p[0] == ".":
            continue
        h = p[1]
        PALETTE[p[0]] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def luma(key):
    r, g, b = PALETTE[key]
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


RAMP = ["k", "l", "L", "n", "y", "Y"]   # brass darkest -> mustard pale (dark to light)


GOLD_STEPS = ["k", "l", "L", "n", "Y"]


# Eggs GOLDEN: only the eggs go gold (cream shade -> gold, cream -> mustard light, paper -> pale: a soft ramp, so the shade split does not read as stripes); the pulp carton keeps its
# grey ramp, so it doesn't turn into a dark brass block. The paper glint is kept only on each egg's top edge (an arc),
# not as the diagonal streak, which read as stripes on the small eggs.
# Round 2 (redrawn eggs, bigger shade side): gold body, brass shade, pale shine, brass-dark seams, so the
# eggs read as metal rather than as yellow eggs.
# Review fix: the paper tops on the egg's edge vanished against the grey carton, so the eggs read as yellow
# triangles. Now the whole egg stays in the gold ramp (light side pale gold, body gold, shade brass) and paper is
# only a 1-2 px highlight inside each egg's upper left, never on its edge.
EGGS_GOLD = {"b": "L", "c": "n", "w": "Y", "a": "l"}

# Round 2, Banana GOLDEN: the rank remap turned a yellow banana into a slightly brighter yellow banana
# (the item is already on the gold end of the ramp), so it read as "yellow", not "gold". A yellow item
# is shifted one step darker and made shiny: its body (mustard) becomes brass, its light shade gold,
# its lightest shade a paper shine, its dark shades brass dark/darkest, and the green crown and the
# brown tips go brass too, so the whole bunch is one metal. Brass under a gold-and-white edge is what
# makes metal read as metal next to a plain yellow banana.
# Review fix: the old map made the body (mustard light y) gold n, which is brighter than plain yellow. Now the body
# is brass L, the lit side gold n, the shade brass dark l, seams and tips brass darkest k, and a 1 px paper rim runs
# along the lit top edge: the bunch is clearly darker and more metallic than the plain banana.
BANANA_GOLD = {"Y": "n", "y": "L", "M": "l", "m": "k", "u": "k", "e": "k", "f": "l",
               "z": "n", "G": "L", "g": "l"}


def golden_banana(rows):
    out = [[BANANA_GOLD.get(c, c) for c in r] for r in rows]
    for y in range(1, H):           # the rim: a lit pixel with the outline right above it
        for x in range(W):
            if rows[y][x] == "Y" and rows[y - 1][x] == "#":
                out[y][x] = "w"
    return reink(out)


# Round 2: Banana and Eggs are redrawn by hand (redraw_r2.py writes src/items_v2/<item>.txt and
# <item>_big.txt); this script only makes their GOLDEN from those BIG files.
REDRAWN = {"banana", "eggs"}


def load_redrawn(name: str) -> list[list[str]]:
    rows = []
    for line in (OUT / f"{name}.txt").read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith(";") or s.startswith("@"):
            continue
        rows.append(list(s))
    assert len(rows) == H and all(len(r) == W for r in rows), name
    return rows


def golden_eggs(rows):
    out = [[EGGS_GOLD.get(c, c) for c in r] for r in rows]
    egg = ("w", "c", "b")
    for y in range(1, H - 1):       # a brass-dark rim where the egg meets the grey carton, so its round top reads
        for x in range(1, W - 1):
            if rows[y][x] in egg and any(rows[y + dy][x + dx] not in egg + ("a",) for dx, dy in ((-1, 0), (0, -1), (1, 0))):
                out[y][x] = "l"
    seen = set()
    for y in range(H):              # one highlight per egg: its light patch's top-left inner pixel and the next one
        for x in range(W):
            if rows[y][x] != "w" or (x, y) in seen:
                continue
            comp, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                cx, cy = todo.pop()
                comp.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < W and 0 <= ny < H and rows[ny][nx] == "w" and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            inner = [(cx, cy) for cx, cy in comp
                     if all(rows[cy + dy][cx + dx] in egg for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)))]
            if not inner:
                continue
            hx, hy = min(inner, key=lambda p: (p[0] + p[1], p[1]))
            out[hy][hx] = "w"
            if (hx + 1, hy) in inner:
                out[hy][hx + 1] = "w"
    return reink(out)


def golden(rows):
    """Rank remap: the item's own shades, dark to light, spread over brass darkest -> gold -> pale.

    Ink stays. Then a 1 px paper glint runs diagonally across the lit gold, so it reads as metal."""
    used = sorted({c for r in rows for c in r} - {".", "#"}, key=luma)
    n = len(used)
    mapping = {c: GOLD_STEPS[min(len(GOLD_STEPS) - 1, int(i * len(GOLD_STEPS) / n))] for i, c in enumerate(used)}
    out = [[mapping.get(c, c) for c in r] for r in rows]
    for y in range(H):
        for x in range(W):
            if out[y][x] in ("n", "Y", "L") and (x + y) % 19 == 0:
                out[y][x] = "w"
    return reink(out)


def write(name, rows, note):
    OUT.mkdir(parents=True, exist_ok=True)
    body = "\n".join("".join(r) for r in rows)
    item = name.split("_")[0]
    if name.endswith("_golden") and item in REDRAWN:
        src = f"generated by gen_upgrades.py from this folder's {item}_big.txt (the round-2 redraw)"
    elif name.endswith("_golden"):
        src = f"generated by gen_upgrades.py from this folder's {item}_big.txt"
    elif name.endswith("_big"):
        src = f"generated by gen_upgrades.py from art/src/items_v2/{item}.txt"
    else:
        src = f"a copy of art/src/items_v2/{name}.txt"
    target = (f"in the game GOLDEN is a palette map of art/src/items_v2/{item}_big.txt, not a drawn source"
              if name.endswith("_golden") else f"target: art/src/items_v2/{name}.txt")
    text = (f"; {note}\n; #77 prep mock-up source, {src}; {target}.\n"
            f"@size 48x48\n@kind item\n{body}\n")
    (OUT / f"{name}.txt").write_text(text, encoding="utf-8")


def main():
    read_palette()
    shutil.copy(ART_SRC / "palette.txt", HERE / "src" / "palette.txt") if (HERE / "src").exists() else None
    (HERE / "src").mkdir(exist_ok=True)
    shutil.copy(ART_SRC / "palette.txt", HERE / "src" / "palette.txt")
    items = {
        "banana": (banana_big, "Banana BIG: a bigger bunch, five fingers."),
        "milk": (milk_big, "Milk BIG: a wider 2 l carton, 2L on the label."),
        "eggs": (eggs_big, "Eggs BIG: a wider carton, two rows of four."),
        "coffee": (coffee_big, "Coffee BIG: a wider jar."),
    }
    for name, (fn, note) in items.items():
        if name in REDRAWN:
            big = load_redrawn(f"{name}_big")
            note = note.replace(":", " (round 2 redraw):", 1)
        else:
            big = fn()
            write(f"{name}_big", big, note)
            write(name, load(name), f"{name} plain: a copy of art/src/items_v2/{name}.txt")
        gold = {"eggs": golden_eggs, "banana": golden_banana}.get(name, golden)(big)
        write(f"{name}_golden", gold, note.replace("BIG", "GOLDEN (BIG remapped to brass/gold)"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
