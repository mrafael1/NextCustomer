"""Banana with a clean crown: fingers (back to front), then the stalk, then a brown crown knob on top."""
import math, sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
from banana_r2 import blank, finger_field, width_at, outline, stand, W, H

def draw(fingers, stem, crown):
    g = blank(); owner = [[None] * W for _ in range(H)]
    parts = [("finger", f) for f in fingers] + [("stem", stem)]
    for idx, (kind, (p0, p1, p2, hw)) in enumerate(parts):
        pts, tans = finger_field(p0, p1, p2)
        n = len(pts) - 1
        for y in range(H):
            for x in range(W):
                px, py = x + 0.5, y + 0.5
                best, bi = 1e9, 0
                for i in range(0, n + 1, 2):
                    d = (pts[i][0] - px) ** 2 + (pts[i][1] - py) ** 2
                    if d < best: best, bi = d, i
                t = bi / n; d = math.sqrt(best)
                w = hw if kind == "stem" else width_at(t, hw, neck=NECK)
                if d > w: continue
                tx, ty = tans[bi]; nx, ny = -ty, tx
                if ny < 0: nx, ny = -nx, -ny
                s = ((px - pts[bi][0]) * nx + (py - pts[bi][1]) * ny) / max(w, 0.1)
                lit = -s * (0.85 if ny > 0.5 else 0.7)
                if kind == "stem":
                    if t > 0.84: k = "f" if lit > -0.2 else "e"
                    else: k = "z" if lit > 0.35 else ("G" if lit > -0.35 else "g")
                else:
                    if t > 0.955: k = "e"
                    elif t > 0.925: k = "f"
                    elif t < GREEN: k = "g" if lit < 0 else "G"
                    elif False: pass
                    elif lit > 0.5: k = "Y"
                    elif lit > -0.05: k = "y"
                    elif lit > -0.6: k = "M"
                    else: k = "m"
                g[y][x] = k; owner[y][x] = idx
    # crown knob: an ellipse over the junction, lit top-left
    cx, cy, rx, ry = crown
    ci = len(parts)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            u, v = (px - cx) / rx, (py - cy) / ry
            if u * u + v * v > 1: continue
            lit = -(u * 0.6 + v * 0.8)
            g[y][x] = "F" if lit > 0.35 else ("f" if lit > -0.35 else "e")
            owner[y][x] = ci
    inner = {i: "u" for i in range(len(parts))}
    inner[len(parts) - 1] = None
    out = outline(g, owner, inner)
    # an ink ring round the crown wherever it meets anything else
    for y in range(H):
        for x in range(W):
            if owner[y][x] != ci or out[y][x] == "#": continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                if owner[y+dy][x+dx] != ci: out[y][x] = "#"; break
    return out

NECK = 1.6; GREEN = 0.09
STEM = ((36.0, 13.5), (38.5, 9.0), (40.5, 5.5), 2.0)
CROWN = (35.0, 16.0, 3.6, 2.9)
PLAIN = [
    ((33.5, 17.5), (20.0, 30.0), (5.5, 13.5), 4.3),
    ((35.0, 18.0), (24.0, 40.0), (6.5, 28.5), 4.6),
    ((36.5, 18.0), (32.0, 47.0), (11.5, 41.5), 4.8),
]
BIG = [
    ((33.0, 16.5), (22.0, 20.0), (8.5, 7.0), 4.0),
    ((33.5, 17.0), (18.0, 30.0), (3.5, 12.5), 4.3),
    ((35.0, 17.5), (21.0, 38.0), (3.5, 24.0), 4.5),
    ((36.0, 18.0), (26.0, 45.0), (6.0, 35.5), 4.7),
    ((37.0, 18.0), (36.0, 48.0), (15.5, 44.0), 4.8),
]
def tidy(rows):
    g = [list(r) for r in rows]
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            n = [g[y][x+1], g[y][x-1], g[y+1][x], g[y-1][x]]
            if g[y][x] == "." and sum(c != "." for c in n) >= 3: g[y][x] = "#"
            if g[y][x] == "u" and g[y][x-1] == "#" and g[y][x+1] == "#": g[y][x] = "#"
    return g
def dump(rows):
    rows = tidy(rows)
    return "\n".join("".join(r) for r in stand(rows))
if __name__ == "__main__":
    import pathlib
    o = pathlib.Path(__file__).parent / "out"; o.mkdir(exist_ok=True)
    (o / "banana.grid").write_text(dump(draw(PLAIN, STEM, CROWN)))
    (o / "banana_big.grid").write_text(dump(draw(BIG, STEM, CROWN)))
