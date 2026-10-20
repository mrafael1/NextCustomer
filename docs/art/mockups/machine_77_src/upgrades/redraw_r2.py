"""#77 prep, round 2: redraws plain and BIG Banana and Eggs as mock-up sources (48x48, game palette).

The user found the round-1 Banana and Eggs "a bit weird", which made their BIG and GOLDEN versions
weirder. This script draws them again from simple shapes (curved fingers, egg domes, pulp cups),
then applies the game's rules: rows 0-1 empty, at most 12 colours, ink outline on every edge
pixel, light from the top left, interior lines in the ramp's darkest shade. It writes

    src/items_v2/banana.txt, banana_big.txt, eggs.txt, eggs_big.txt

(the round-1 files are kept beside them as *_r1.txt). gen_upgrades.py then makes GOLDEN from the
BIG files. The game's art/src/ is never touched: these replace art/src/items_v2/banana.txt and
eggs.txt 1:1 in the #77 build, after approval.

    python docs/art/mockups/machine_77_src/upgrades/redraw_r2.py
"""

from __future__ import annotations

import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "src" / "items_v2"
W = H = 48


def blank():
    return [["."] * W for _ in range(H)]


def outline(g, owner=None, inner=None):
    """Edge pixels (touching transparency or the canvas edge) become ink. With `owner` (an id per pixel,
    higher = nearer), a pixel of a farther part that touches a nearer part becomes `inner[id]`."""
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
            else:
                if owner is not None and owner[y][x] is not None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        o = owner[y + dy][x + dx]
                        if o is not None and o > owner[y][x] and inner.get(owner[y][x]):
                            out[y][x] = inner[owner[y][x]]
                            break
    for y in range(2):
        assert all(c == "." for c in out[y]), "rows 0-1 must stay empty"
    return out


# ------------------------------------------------------------------ Banana

def bez(p0, p1, p2, t):
    a = (1 - t) ** 2
    b = 2 * (1 - t) * t
    c = t * t
    return (a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1])


def finger_field(p0, p1, p2, n=500):
    pts = [bez(p0, p1, p2, i / n) for i in range(n + 1)]
    tans = []
    for i in range(n + 1):
        a, b = pts[max(0, i - 1)], pts[min(n, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        tans.append((dx / L, dy / L))
    return pts, tans


def width_at(t, hw, neck=1.6, tip=1.5):
    # thin neck at the crown, full by a quarter, a long belly, a tapered tip
    if t < 0.22:
        return neck + (hw - neck) * math.sin(t / 0.22 * math.pi / 2)
    if t > 0.72:
        u = (t - 0.72) / 0.28
        return hw + (tip - hw) * u * u
    return hw


def draw_fingers(fingers, stem):
    """fingers: list of (p0, ctrl, tip, half_width), back to front. stem: (p0, ctrl, p2, hw)."""
    g = blank()
    owner = [[None] * W for _ in range(H)]
    parts = [("stem", stem)] + [("finger", f) for f in fingers]
    for idx, (kind, (p0, p1, p2, hw)) in enumerate(parts):
        pts, tans = finger_field(p0, p1, p2)
        n = len(pts) - 1
        for y in range(H):
            for x in range(W):
                px, py = x + 0.5, y + 0.5
                best, bi = 1e9, 0
                for i in range(0, n + 1, 2):
                    d = (pts[i][0] - px) ** 2 + (pts[i][1] - py) ** 2
                    if d < best:
                        best, bi = d, i
                t = bi / n
                d = math.sqrt(best)
                if kind == "stem":
                    w = hw
                else:
                    w = width_at(t, hw)
                if d > w:
                    continue
                tx, ty = tans[bi]
                nx, ny = -ty, tx
                if ny < 0:
                    nx, ny = -nx, -ny
                s = ((px - pts[bi][0]) * nx + (py - pts[bi][1]) * ny) / max(w, 0.1)
                # light from the top left: the side facing up-left is lit
                lit = -s * (0.85 if ny > 0.5 else 0.7)
                if kind == "stem":
                    if t > 0.84:
                        k = "f" if lit > -0.2 else "e"     # the cut end
                    else:
                        k = "z" if lit > 0.35 else ("G" if lit > -0.35 else "g")
                else:
                    if t > 0.955:
                        k = "e"                            # the dark tip nub
                    elif t > 0.925:
                        k = "f"
                    elif t < 0.07:
                        k = "g" if lit < 0 else "G"       # green neck at the crown
                    elif t < 0.1:
                        k = "G" if lit < 0 else "z"
                    elif lit > 0.5:
                        k = "Y"
                    elif lit > -0.05:
                        k = "y"
                    elif lit > -0.6:
                        k = "M"
                    else:
                        k = "m"
                g[y][x] = k
                owner[y][x] = idx
    inner = {i: "u" for i in range(1, len(parts))}
    inner[0] = "e"
    return outline(g, owner, inner)


BANANA_STEM = ((34.5, 15.5), (37.5, 9.5), (40.5, 5.5), 2.2)

BANANA_PLAIN = [
    # back finger: tip up at the top left
    ((35.0, 16.0), (20.0, 30.0), (5.5, 13.5), 4.3),
    # middle finger
    ((35.0, 17.0), (24.0, 40.0), (6.5, 28.5), 4.6),
    # front finger: the lowest, tip at the bottom left
    ((36.0, 17.0), (32.0, 47.0), (11.5, 41.5), 4.8),
]

BANANA_BIG = [
    ((35.0, 15.0), (22.0, 20.0), (8.5, 7.0), 4.0),
    ((35.0, 15.5), (18.0, 30.0), (3.5, 12.5), 4.3),
    ((35.0, 16.5), (21.0, 38.0), (3.5, 24.0), 4.5),
    ((35.5, 17.0), (26.0, 45.0), (6.0, 35.5), 4.7),
    ((36.0, 17.5), (36.0, 48.0), (15.5, 44.0), 4.8),
]


# ------------------------------------------------------------------ Eggs

def egg_key(x, y, cx, cy, rx, ry):
    """The egg's colour at (x, y), or None outside: an upright egg, a touch narrower above its middle."""
    px, py = x + 0.5, y + 0.5
    dy = (py - cy) / ry
    dx = (px - cx) / (rx * (0.92 if dy < 0 else 1.0))
    if dx * dx + dy * dy > 1.0:
        return None
    lit = -(dx * 0.6 + dy * 0.8)
    if lit > 0.5:
        return "w"
    if lit > -0.25:
        return "c"
    return "b"


def cup_key(x, y, cx, top, rx, ry):
    """A pulp cup on the carton's front: a bowl, flat on top, rounded below, lit from the left."""
    px, py = x + 0.5, y + 0.5
    dx = (px - cx) / rx
    dy = max(0.0, py - top) / ry
    if dx * dx + dy * dy > 1.0 or py < top:
        return None
    lit = -(dx * 0.85 + dy * 0.5)
    if lit > 0.3:
        return ":"
    if lit > -0.45:
        return "-"
    return "="


def draw_carton(n):
    """An open pulp carton seen from the front and a little above: the lid leaning back, a back
    row and a front row of n eggs sitting in the tray, rounded cups along the front."""
    g = blank()
    owner = [[None] * W for _ in range(H)]
    step = 10
    width = n * step + 2
    back_dx = 2                        # the back row and the lid sit a little to the right (3/4)
    x0 = (W - width - back_dx) // 2    # the front tray's left edge
    bx0 = x0 + back_dx

    def put(x, y, k, o):
        if 0 <= x < W and 2 <= y < H:
            g[y][x] = k
            owner[y][x] = o

    # the lid, open and leaning back: its rim edge, then its inside face with cup dimples
    ly0, ly1 = 3, 11
    for y in range(ly0, ly1 + 1):
        inset = 1 if y == ly0 else 0
        for x in range(bx0 + inset, bx0 + width - inset):
            put(x, y, "-" if y == ly0 else (":" if y < ly1 else "="), 0)
    for i in range(n):
        cx = bx0 + 1 + i * step + step / 2
        for y in range(ly0 + 2, ly1):
            for x in range(W):
                d = ((x + 0.5 - cx) / 3.6) ** 2 + ((y + 0.5 - (ly0 + 4.6)) / 2.7) ** 2
                if d <= 1.0:   # a hollow: its upper wall in shade, its floor mid grey
                    put(x, y, "=" if y + 0.5 < ly0 + 3.8 else "-", 0)
    # the tray's inside, in shadow behind and between the eggs
    for y in range(ly1, 31):
        for x in range(bx0 if y < 22 else x0, bx0 + width):
            put(x, y, "=", 0)
    # the back row of eggs, its rim, the front row, its rim
    rows = [(bx0, 17.5, 20, 1), (x0, 27.0, 30, 3)]
    for bx, cy, rim, oid in rows:
        for i in range(n):
            cx = bx + 1 + i * step + step / 2
            for y in range(H):
                for x in range(W):
                    k = egg_key(x, y, cx, cy, 4.6, 6.4)
                    if k:
                        put(x, y, k, oid)
        for y in (rim, rim + 1):
            for x in range(bx, bx + width):
                put(x, y, ":" if y == rim else "-", oid + 1)
        for i in range(n + 1):                 # the cup walls rise a little between the eggs
            x = bx + 1 + i * step
            for y in (rim - 2, rim - 1):
                if g[y][x] == "=":
                    put(x, y, "-", oid + 1)
    # the front: a band, then one rounded cup per egg
    top = 32
    for x in range(x0, x0 + width):
        put(x, top, "-", 5)
        put(x, top + 1, "-", 5)
    for i in range(n):
        cx = x0 + 1 + i * step + step / 2
        for y in range(top, H):
            for x in range(W):
                k = cup_key(x, y, cx, top, step / 2 + 0.3, 11.5)
                if k:
                    put(x, y, k, 5)
    # the right end of the tray, in shade (3/4: a sliver of its side); it stops at the front band, so no
    # detached sliver is left beside the cups below it
    for y in range(ly1, top + 2):
        for x in range(x0 + width, bx0 + width):
            if g[y][x] == ".":
                put(x, y, "=", 0)
    return outline(g, owner, {1: "a", 0: "=", 2: "=", 3: "a", 4: "="})


def stand(rows):
    """Moves the drawing down so it stands on the bottom row (row 47), like every game item."""
    low = max(y for y in range(H) if any(c != "." for c in rows[y]))
    d = H - 1 - low
    return [["."] * W for _ in range(d)] + [list(r) for r in rows[:H - d]] if d else rows


def write(name, rows, note):
    OUT.mkdir(parents=True, exist_ok=True)
    rows = stand(rows)
    body = "\n".join("".join(r) for r in rows)
    target = (f"replaces art/src/items_v2/{name}.txt 1:1 after approval" if not name.endswith("_big")
              else f"would become the new source art/src/items_v2/{name}.txt after approval (the plain sprite stays {name[:-4]}.txt)")
    text = (f"; {note}\n; #77 prep mock-up source, round 2 redraw (redraw_r2.py); {target}.\n"
            f"@size 48x48\n@kind item\n{body}\n")
    (OUT / f"{name}.txt").write_text(text, encoding="utf-8")


def main():
    write("banana", draw_fingers(BANANA_PLAIN, BANANA_STEM),
          "Banana (round 2): a bunch of three curved fingers from a short green-brown stem at the top right.")
    write("banana_big", draw_fingers(BANANA_BIG, BANANA_STEM),
          "Banana BIG (round 2): a bigger bunch, five fingers fanned from the same stem.")
    write("eggs", draw_carton(3),
          "Eggs (round 2): an open pulp carton of six, two rows of three eggs, the lid leaning back.")
    write("eggs_big", draw_carton(4),
          "Eggs BIG (round 2): a wider open carton, two rows of four eggs.")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
