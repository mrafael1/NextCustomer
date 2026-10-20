"""Direction C (#76): the "grin purse". A brown leather kiss-lock coin purse whose two clasp knobs are its eyes and whose
opening frame is its mouth. The bigger the total, the wider it grins and the more cash and card it shows.

Draws every pose as a grid of palette keys (art/src/palette.txt; '~' is the code-drawn contact shadow). 1 art px = 2 screen
px. The grid is W x H; the purse body fills columns 6..29 at most (screen x 284..336 when the grid's left edge sits at x 274)
and stands on row 51 (screen y 400 when the grid's top sits at y 296). Columns 0..4 and 31..35 and the rows above the purse
are margin for the free props (sparkles, sweat drops, flying notes). Standard library only.
"""
import math

W, H = 36, 54
CX = 18.0          # body centre (between columns 17 and 18)
FOOT = 50          # last filled body row; row 51 is the ink outline on the counter

PALETTE = {
    '#': '#2b2420', '%': '#4a3f38', 'a': '#b39f78', 'b': '#ddcba5', 'c': '#f3e9d2', 'w': '#fbf7ee',
    '1': '#1f3b3a', '2': '#2a4d4b', '3': '#3a7672', '4': '#4f9a94', '5': '#86c2b6', '6': '#c3e0d4',
    'u': '#7a5a1c', 'm': '#b38425', 'M': '#e2b33c', 'y': '#f1d27a', 'Y': '#faecbc', 'n': '#ffcf3f',
    'g': '#3d7a45', 'G': '#5fae5a', 'z': '#a5d17e',
    'e': '#4a3022', 'f': '#7a5232', 'F': '#a87a4e', 'h': '#d2a874',
    '~': 'rgba(20,14,10,.42)',
}


class Grid:
    def __init__(self):
        self.g = [['.'] * W for _ in range(H)]

    def put(self, i, j, k):
        if 0 <= i < W and 0 <= j < H:
            self.g[j][i] = k

    def get(self, i, j):
        return self.g[j][i] if 0 <= i < W and 0 <= j < H else '.'

    def rows(self):
        return [''.join(r) for r in self.g]


def body_hw(y, top, hw_top, hw_max):
    t = min(1.0, max(0.0, (y - top) / max(1.0, (FOOT - 4 - top))))
    hw = hw_top + (hw_max - hw_top) * math.sin(t * math.pi / 2)
    cut = {FOOT: 4.0, FOOT - 1: 2.0, FOOT - 2: 1.0, FOOT - 3: 0.5}.get(y, 0.0)
    return hw - cut


def inside_body(i, y, top, hw_top, hw_max):
    if y < top or y > FOOT:
        return False
    return abs(i + 0.5 - CX) < body_hw(y, top, hw_top, hw_max)


def draw(p):
    """p: dict of pose parameters (see POSES)."""
    G = Grid()
    top = p.get('top', 30)          # row of the front frame's ends (closed: the whole frame)
    lift = p.get('lift', 0)         # whole purse raised by this many rows (a hop); the shadow stays
    hw_top, hw_max = p.get('hw', (9.5, 11.0))
    hwf = hw_top + 0.5               # frame half-width
    s = p.get('smile', 0)           # front lip: + dips in the middle (smile), - arches up (frown)
    o = p.get('open', 0)            # back frame's rise in the middle (0: shut)
    sep = p.get('sep', 0)           # clasp knobs pushed apart (each side)

    def yf(i):  # front frame top row at column i
        d = (i + 0.5 - CX) / hwf
        return top + round(s * (1 - d * d))

    def yk(i):  # back frame top row at column i (an elliptical arch meeting the front frame at the hinges)
        d = min(1.0, abs(i + 0.5 - CX) / hwf)
        return top - round(o * math.sqrt(max(0.0, 1 - d ** 2.2)))

    cols = [i for i in range(W) if abs(i + 0.5 - CX) < hwf]

    # 1. contact shadow, stepped, falling to the right (drawn in code, a modulate in Godot)
    for i in range(W):
        if abs(i + 0.5 - (CX + 2.5)) < hw_max - 1.0:
            G.put(i, FOOT + 2, '~')
        if abs(i + 0.5 - (CX + 4.5)) < hw_max - 3.5:
            G.put(i, FOOT + 3, '~')

    # 2. leather body: F fill, h lit left edge and top, f shade right and foot, a stitched seam
    for y in range(top, FOOT + 1):
        for i in range(W):
            if not inside_body(i, y, top, hw_top, hw_max):
                continue
            if y < yf(i) + 2:
                continue
            k = 'F'
            if not inside_body(i - 1, y, top, hw_top, hw_max) or not inside_body(i - 2, y, top, hw_top, hw_max) and y < FOOT - 3:
                k = 'h'
            if not inside_body(i + 1, y, top, hw_top, hw_max) or not inside_body(i + 2, y, top, hw_top, hw_max):
                k = 'f'
            if y >= FOOT - 1 or not inside_body(i, y + 2, top, hw_top, hw_max):
                k = 'f'
            G.put(i, y, k)
    # seam: a dashed stitch line 3 rows above the foot
    seam = FOOT - 4
    for i in range(W):
        if inside_body(i, seam, top, hw_top, hw_max) and inside_body(i - 2, seam, top, hw_top, hw_max) \
                and inside_body(i + 2, seam, top, hw_top, hw_max) and i % 2 == 0:
            G.put(i, seam, 'e')
    # a lit highlight band under the frame (the leather's shoulder)
    for i in cols[2:-3]:
        y = yf(i) + 2
        if G.get(i, y) == 'F':
            G.put(i, y, 'h')

    # gloss: a 2-px lit streak and a specular texel on the upper-left shoulder
    gx, gy = int(CX) - 7, yf(int(CX) - 7) + 5
    for j in range(4):
        for di in (0, 1):
            if G.get(gx + di - (j // 2), gy + j) in ('F', 'h'):
                G.put(gx + di - (j // 2), gy + j, 'h')
    if G.get(gx + 1, gy) in ('F', 'h'):
        G.put(gx + 1, gy, 'c')
    # a darker crease on the lower right (the bulge's shadow side)
    for j in range(5):
        cx = int(CX) + 6 + (j // 3)
        if G.get(cx, FOOT - 9 + j) == 'F':
            G.put(cx, FOOT - 9 + j, 'f')

    # 3. cash and card standing inside the purse: only what rises above the back frame shows (its "hair"); clipped above
    #    the front frame so nothing paints over the leather, and the lining drawn next hides the rest
    def bput(i, j, k):
        if j < yf(i) and (o > 0 or j < top):
            G.put(i, j, k)
    bx, by = CX, top + 3                                  # the fan's pivot, deep inside the purse
    for c in p.get('fan', []):                            # (kind 'note' or 'card', angle in degrees from upright, length)
        kind, ang, ln = c
        t = math.radians(ang)
        co, si = math.cos(t), math.sin(t)
        hwid = 3.0 if kind == 'card' else 2.6
        for j in range(H):
            for i in range(W):
                rx, ry = i + 0.5 - bx, j + 0.5 - by
                along = -ry * co + rx * si
                across = rx * co + ry * si
                if not (0 <= along <= ln and abs(across) <= hwid):
                    continue
                if kind == 'note':
                    k = 'G'
                    if across < -hwid + 1.1 or along > ln - 1.1:
                        k = 'z'
                    elif across > hwid - 1.1:
                        k = 'g'
                    elif ln - 4.6 < along < ln - 2.4 and abs(across) < 1.0:
                        k = 'g'                       # the note's printed mark
                else:
                    k = '4'                           # her card is teal (a cream one read as a Milk carton)
                    if across < -hwid + 1.1 or along > ln - 1.1:
                        k = '5'
                    elif across > hwid - 1.1:
                        k = '3'
                    if ln - 4.2 < along < ln - 2.0:
                        k = '2'                       # the magnetic stripe
                    elif ln - 7.4 < along < ln - 5.6 and -1.6 < across < 0.4:
                        k = 'M'                       # the chip
                bput(i, j, k)
    # notes drawn later in the list sit in front: draw order is the list order

    # 4a. mouth: the teal lining between the back frame and the front frame
    if o > 0:
        for i in cols[1:-1]:
            for y in range(yk(i) + 2, yf(i)):
                k = '1' if y <= yk(i) + 3 else '2'
                if y >= yf(i) - 2 and yf(i) - yk(i) > 6:
                    k = '3'                         # the lining's inner front wall catches the light
                G.put(i, y, k)

    # 4b. back frame: a 2-row gold arch
    if o > 0:
        for i in cols:
            G.put(i, yk(i), 'y')
            G.put(i, yk(i) + 1, 'm')

    # 5. gold teeth: coins hanging from the back lip, one per x given
    for x in p.get('teeth', []):
        ty = max(yk(x + d) for d in range(3)) + 2
        gold = x in p.get('gold', ())                 # paper-white teeth read as a grin; one gold tooth for the rich
        for dx, k in enumerate('yMm' if gold else 'wwc'):
            G.put(x + dx, ty, k)
        for dx, k in enumerate('Mmu' if gold else 'wcb'):
            if ty + 1 < yf(x + dx):
                G.put(x + dx, ty + 1, k)

    # 6. front frame: a 2-row gold bar, lit top row, with hinge caps at the ends
    for i in cols:
        G.put(i, yf(i), 'y' if i < CX + hwf - 3 else 'M')
        G.put(i, yf(i) + 1, 'M' if i < CX + hwf - 3 else 'm')
    for end in (cols[0] - 1, cols[-1] + 1):
        G.put(end, yf(cols[0] if end < CX else cols[-1]), 'M')
        G.put(end, yf(cols[0] if end < CX else cols[-1]) + 1, 'm')

    # 7. clasp knobs = eyes, 6x6 with outline, touching when shut
    eye = p.get('eyes', 'dot')
    top_mid = yk(int(CX)) if o > 0 else yf(int(CX))
    ky = top_mid - 4 + p.get('eye_dy', 0)
    for side in (-1, 1):
        kx = int(CX) - 6 - sep if side < 0 else int(CX) + sep
        knob(G, kx, ky, eye, side)
        # the knob's stem onto the frame
        G.put(kx + 2, ky + 6, 'm')
        G.put(kx + 3, ky + 6, 'm')

    # 8. strain ticks beside the knobs ("the clasp is straining")
    if p.get('strain'):
        for side in (-1, 1):
            bx = int(CX) - 6 - sep - 2 if side < 0 else int(CX) + sep + 7
            for r in (0, 2, 4):
                G.put(bx + (0 if side < 0 else 1), ky + r, '#')
                G.put(bx + (-1 if side < 0 else 2), ky + r - 1 if r else ky, '#')

    # 9. outline: every empty cell touching the purse becomes ink
    solid = {'Y', 'F', 'h', 'f', 'e', 'y', 'M', 'm', 'u', '1', '2', 'G', 'g', 'z', 'c', 'w', 'b', '4', '3'}
    snap = [row[:] for row in G.g]
    for j in range(H):
        for i in range(W):
            if snap[j][i] in ('.', '~'):
                if any(0 <= i + di < W and 0 <= j + dj < H and snap[j + dj][i + di] in solid
                       for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    G.put(i, j, '#')
    # interior line between the back frame and the lining, and under the front frame: darkest of the ramp
    for i in cols:
        if o > 0 and G.get(i, yk(i) + 2) == '1':
            pass
        if G.get(i, yf(i) + 2) in ('F', 'h'):
            G.put(i, yf(i) + 2, 'e')

    # 10. free props in the margin
    for f in p.get('fx', []):
        prop(G, *f)

    rows = G.rows()
    if lift:
        body = rows[:FOOT + 2]
        shadow = rows[FOOT + 2:]
        body = body[lift:] + ['.' * W] * lift
        rows = body + shadow
    return rows


def knob(G, x, y, eye, side):
    """A 6x6 clasp knob at (x, y): ink ring, mustard fill, a lit texel at the upper left, and the eye drawn on it."""
    ring = {(0, 1), (0, 2), (0, 3), (0, 4), (5, 1), (5, 2), (5, 3), (5, 4), (1, 0), (2, 0), (3, 0), (4, 0), (1, 5), (2, 5), (3, 5), (4, 5)}
    for j in range(6):
        for i in range(6):
            if (i, j) in ring:
                G.put(x + i, y + j, '#')
            elif 0 < i < 5 and 0 < j < 5:
                G.put(x + i, y + j, 'Y')
    G.put(x + 1, y + 1, 'w')
    G.put(x + 4, y + 4, 'M')
    G.put(x + 4, y + 3, 'y')
    G.put(x + 3, y + 4, 'y')
    inner = []  # (col, row) in the 4x4 inner square, 0..3
    lid = []
    mirror = (lambda c: 3 - c) if side > 0 else (lambda c: c)
    if eye == 'dot':
        inner = [(1, 1), (2, 1), (1, 2), (2, 2)]
    elif eye == 'right':
        inner = [(2, 1), (3, 1), (2, 2), (3, 2)]
    elif eye == 'up':
        inner = [(1, 0), (2, 0), (1, 1), (2, 1)]
    elif eye == 'down':
        inner = [(1, 2), (2, 2), (1, 3), (2, 3)]
    elif eye == 'sleepy':
        lid = [(c, 0) for c in range(4)] + [(c, 1) for c in range(4)]
        inner = [(c, 2) for c in range(4)]
    elif eye == 'happy':
        inner = [(0, 2), (1, 1), (2, 1), (3, 2)]
    elif eye == 'squeeze':
        inner = [(mirror(0), 0), (mirror(1), 1), (mirror(2), 1), (mirror(1), 2), (mirror(0), 3)]
    elif eye == 'sad':
        inner = [(1, 2), (2, 2), (1, 3), (2, 3)]
        lid = [(mirror(2), 0), (mirror(3), 0), (mirror(3), 1)]
    elif eye == 'wide':
        inner = [(1, 1), (2, 1), (1, 2), (2, 2)]
        G.put(x + 1, y + 1, 'w')
    for c, r in lid:
        G.put(x + 1 + c, y + 1 + r, 'M')
    for c, r in inner:
        G.put(x + 1 + c, y + 1 + r, '#')


SPARK = ['..#..', '.#y#.', '#ywy#', '.#y#.', '..#..']
SPARK_S = ['.#.', '#w#', '.#.']
DROP = ['.#.', '#5#', '#65#', '.##']
NOTE_FLY = ['#######', '#zGGGg#', '#GGgGg#', '#######']
NOTE_FLY2 = ['.######', '#zGGGg#', '#GgGGg#', '######.']
COIN = ['.##.', '#yM#', '#Mm#', '.##.']
BANG = ['##', 'MM', 'MM', 'MM', '##', '..', '##', 'MM', '##']
BANG_L = ['####', '#yM#', '#yM#', '#yM#', '#Mm#', '.##.', '....', '####', '#Mm#', '####']
TICK_L = ['#.', '.#', '#.']
TICK_R = ['.#', '#.', '.#']
HEART = ['.##.##.', '#ww#Yw#', '#wwwww#', '.#www#.', '..#w#..', '...#...']


def prop(G, name, x, y):
    art = {'spark': SPARK, 'spark_s': SPARK_S, 'drop': DROP, 'note': NOTE_FLY, 'note2': NOTE_FLY2, 'coin': COIN,
           'bang': BANG, 'bang_l': BANG_L, 'tick_l': TICK_L, 'tick_r': TICK_R, 'heart': HEART}[name]
    for j, row in enumerate(art):
        for i, k in enumerate(row):
            if k != '.':
                G.put(x + i, y + j, k)


# ---------------------------------------------------------------- poses
NOTE = lambda x, ty, h, lean=0: ('note', x, ty, h, lean)

N = lambda ang, ln: ('note', ang, ln)
C = lambda ang, ln: ('card', ang, ln)

POSES = {
    # the ladder: projected total (planning) or running subtotal (count-up) against the quota
    's0': dict(top=31, hw=(8.5, 11.0), eyes='sleepy'),
    's1': dict(top=30, hw=(8.5, 11.0), open=2, smile=2, sep=1, eyes='dot', fan=[N(-34, 12)]),
    's2': dict(top=30, hw=(8.5, 11.2), open=3, smile=3, sep=1, eyes='up', strain=True,
               fan=[N(-40, 14), C(30, 13)], teeth=[16]),
    's3': dict(top=30, hw=(9.0, 11.5), open=5, smile=5, sep=2, eyes='happy',
               fan=[N(-52, 16), N(-24, 18), N(34, 17), C(16, 17)], teeth=[10, 14, 18, 22], gold=(18,),
               fx=[('spark_s', 2, 12), ('spark_s', 32, 18)]),
    's4': dict(top=30, hw=(9.5, 12.0), open=6, smile=6, sep=2, eyes='squeeze',
               fan=[N(-66, 16), N(-42, 20), N(-8, 23), N(48, 19), N(70, 15), N(28, 22), C(14, 21)],
               teeth=[9, 13, 17, 21, 25], gold=(21,),
               # no sweat drops: sweat reads as "spending hurts", the very fb-p2 misreading; coins pop out instead.
               # nothing left of column 5 above row 22 (the receipt's right edge, x 282)
               fx=[('spark', 30, 2), ('spark_s', 6, 6), ('coin', 31, 26), ('spark', 31, 36), ('coin', 1, 32), ('spark_s', 2, 44)]),
    # verdicts
    'over': dict(top=30, hw=(9.0, 11.5), open=5, smile=6, sep=2, eyes='happy',
                 fan=[N(36, 14)], teeth=[12, 16, 20],
                 fx=[('note', 0, 26), ('note2', 1, 14), ('coin', 4, 36), ('heart', 28, 12), ('spark_s', 6, 6)]),
    'on': dict(top=30, hw=(8.5, 11.0), smile=3, eyes='happy', fx=[('spark_s', 31, 24), ('spark_s', 3, 26)]),
    'short': dict(top=32, hw=(9.0, 11.8), open=6, smile=-3, sep=1, eyes='sad',
                  fan=[N(-30, 14), N(28, 14)], fx=[('drop', 32, 26)]),
    # transients
    'drag_plus': dict(top=30, hw=(8.5, 11.0), open=3, smile=3, sep=1, eyes='right', lift=3,
                      fan=[N(-34, 13)], fx=[('tick_l', 3, 47), ('tick_r', 31, 47)]),
    'drag_minus': dict(top=32, hw=(9.0, 11.8), open=1, smile=0, eyes='down', fan=[N(-30, 9)]),
    'flick': dict(top=30, hw=(8.5, 11.2), open=3, smile=3, sep=1, eyes='dot',
                  fan=[N(-40, 14), C(30, 13)], teeth=[16], fx=[('note2', 0, 12), ('tick_l', 8, 13)]),
    'gasp': dict(top=30, hw=(9.5, 11.8), open=9, smile=5, sep=3, eyes='wide',
                 fan=[N(-56, 22), N(-30, 26), N(30, 26), N(56, 22), C(10, 25)],
                 teeth=[15], fx=[('bang', 33, 4), ('spark', 0, 18), ('spark_s', 31, 20)]),
    'tremble': dict(top=30, hw=(9.0, 11.5), open=4, smile=4, sep=1, eyes='up', strain=True,
                    fan=[N(-44, 16), N(30, 16), C(-14, 16)], teeth=[13, 17],
                    fx=[('tick_l', 1, 34), ('tick_l', 1, 40), ('tick_r', 33, 34), ('tick_r', 33, 40)]),
}
POSES['s4_still'] = dict(POSES['s4'], fx=[])
# the quota ding in the count-up: the gasp pose (eyes wide, clasp popped open) on the splurge body, a big "!", a note
# flicking to the register; it must look different from the planning page's settled splurge grin
POSES['peak'] = dict(POSES['s4'], open=9, sep=3, eyes='wide', strain=True,
                     fan=[N(-62, 18), N(-36, 24), N(-10, 27), N(56, 20), N(32, 25), C(12, 26)],
                     fx=[('bang_l', 31, 2), ('spark', 30, 22), ('coin', 32, 34), ('note', 0, 34), ('spark_s', 6, 4)])


def all_sprites():
    return {k: draw(v) for k, v in POSES.items()}


if __name__ == '__main__':
    import sys
    for name in sys.argv[1:] or POSES:
        print(name)
        print('\n'.join(draw(POSES[name])))
