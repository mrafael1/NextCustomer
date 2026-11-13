"""Crisps: a pillow pack with a short crimped seal on top, a body as wide as the seal that puffs out
at the sides, fold creases from the seal's corners, sheen top left, and the oval window of crisps."""
import pathlib
W = H = 48
SRC = pathlib.Path(r"C:/dev/projects/NC-item-art/art/src/items_v2")

def old(n):
    return [l.rstrip("\n") for l in open(SRC / f"{n}.txt") if not l.startswith((";", "@"))][:48]

# the window (ring, cream, crisps) copied from the approved plain sprite: rows 20-38, x 12-35
OLD = old("crisps")
WINDOW = {}
for y in range(20, 39):
    for x in range(12, 36):
        c = OLD[y][x]
        if c in "qcmyMbw": WINDOW[(x - 12, y - 20)] = c

# body width profile: how far each side puffs out past the seal, row by row from the seal down
PUFF = [0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 1, 1, 0, 0]

def pack(x0, y0, w, body_rows, win_dx, win_dy, g, owner, idx):
    """Seal from (x0, y0), w wide (ink ends included); the body's last row is y0 + 3 + body_rows,
    then an ink bottom row."""
    x1 = x0 + w - 1
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c; owner[y][x] = idx
    # teeth tips, coloured teeth, ridges, seal foot
    for x in range(x0, x1 + 1):
        if (x - x0) % 2 == 1 and x != x1: put(x, y0, "#")
    for x in range(x0, x1 + 1):
        f = (x - x0) / max(1, w - 1)
        lit = "o" if f < 0.62 else ("R" if f < 0.85 else ("r" if f < 0.92 else "q"))
        put(x, y0 + 1, "#" if (x - x0) % 2 == 0 or x in (x0, x1) else lit)
        ridge = ("o" if (x - x0) % 2 else "r") if f < 0.62 else ("R" if (x - x0) % 2 else "r")
        if f >= 0.92: ridge = "q"
        put(x, y0 + 2, "#" if x in (x0, x1) else ridge)
        put(x, y0 + 3, "#" if x in (x0, x1) or x in (x0 + 1, x1 - 1) else ("q" if (x - x0) % 2 else "r"))
    # body
    n = body_rows
    for i in range(n):
        y = y0 + 4 + i
        p = PUFF[min(len(PUFF) - 1, round(i * (len(PUFF) - 1) / (n - 1)))]
        L, R = x0 - p, x1 + p
        for x in range(L, R + 1):
            if x in (L, R): c = "#"
            else:
                k = x - L
                kr = R - x
                if kr <= 2: c = "q"
                elif kr <= 6: c = "r"
                elif i >= n - BOTTOM: c = "r"
                elif k == 1: c = "R"
                elif k == 2: c = "o"
                elif k == 3: c = "O" if i < n * 0.55 else "o"
                else: c = "R"
            put(x, y, c)
    # the bottom seal: a dark ridged strip and its teeth
    yb = y0 + 4 + n
    for x in range(x0, x1 + 1):
        put(x, yb, "#" if x in (x0, x1) else ("q" if (x - x0) % 2 else "r"))
        put(x, yb + 1, "#" if (x - x0) % 2 == 0 or x == x1 else "r")
        if (x - x0) % 2 == 1 and x != x1: put(x, yb + 2, "#")
    # sheen streak under the seal, top left
    for x in range(x0 + 3, x0 + 3 + int(w * 0.36)): put(x, y0 + 5, "o")
    for x in range(x0 + 4, x0 + 4 + int(w * 0.22)): put(x, y0 + 5, "O" if x % 3 else "o")
    for x in range(x0 + 2, x0 + 2 + int(w * 0.14)): put(x, y0 + 6, "o")
    # fold creases from the seal's corners
    for k in range(1, 4):
        put(x0 + 1 + k, y0 + 3 + k, "r")
        put(x1 - 1 - k, y0 + 3 + k, "q")
    # window
    if win_dx is not None:
        for (dx, dy), c in WINDOW.items(): put(x0 + win_dx + dx, y0 + win_dy + dy, c)
    return g

BOTTOM = 4

def blank():
    return [["."] * W for _ in range(H)], [[None] * W for _ in range(H)]

def overlap_ink(g, owner):
    """A farther pack's pixels that touch a nearer pack become ink (1 px edge between packs)."""
    out = [r[:] for r in g]
    for y in range(H):
        for x in range(W):
            if owner[y][x] is None or g[y][x] == "#": continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H and owner[Y][X] is not None and owner[Y][X] > owner[y][x]:
                    out[y][x] = "#"; break
    return out

def plain():
    g, o = blank()
    pack(9, 6, 30, 35, 3, 13, g, o, 0)
    return g

def big():
    g, o = blank()
    pack(17, 3, 26, 31, None, None, g, o, 0)
    pack(4, 10, 28, 31, 0, 12, g, o, 1)
    return g

if __name__ == "__main__":
    out = pathlib.Path(__file__).parent / "out"; out.mkdir(exist_ok=True)
    (out / "crisps.grid").write_text("\n".join("".join(r) for r in plain()))
    (out / "crisps_big.grid").write_text("\n".join("".join(r) for r in big()))
