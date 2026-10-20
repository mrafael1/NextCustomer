"""Direction B (#76): the wallet's frames and the budget tag's faces as palette-key text grids (standard library only).

Every sprite is built from a few shape predicates on a 2 px texel grid (ink outline, lit edge at the upper left, shaded edge
at the lower right, as the game's sprites are drawn), then checked against art/src/palette.txt.
"""
import math
import pathlib

REPO = pathlib.Path(__file__).resolve().parents[5]
W, H = 26, 52  # the wallet canvas in texels: spot A, Rect2(284, 296, 52, 104) on the stage (body from y 326)


def palette():
    keys = {}
    for line in (REPO / 'art/src/palette.txt').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith(';'):
            continue
        k, v = line.split()[:2]
        keys[k] = None if k == '.' else '#' + v
    return keys


class Grid:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.g = [['.'] * w for _ in range(h)]

    def px(self, i, j, c):
        if 0 <= i < self.w and 0 <= j < self.h:
            self.g[j][i] = c

    def shape(self, inside, fill, lit, shade, ol='#'):
        ins = lambda i, j: 0 <= i < self.w and 0 <= j < self.h and inside(i, j)
        edge = lambda i, j: ins(i, j) and not (ins(i - 1, j) and ins(i + 1, j) and ins(i, j - 1) and ins(i, j + 1))
        out = []
        for j in range(self.h):
            for i in range(self.w):
                if not ins(i, j):
                    continue
                if edge(i, j):
                    c = ol
                elif edge(i - 1, j) or edge(i, j - 1):
                    c = lit
                elif edge(i + 1, j) or edge(i, j + 1):
                    c = shade
                else:
                    c = fill
                out.append((i, j, c))
        for i, j, c in out:
            self.px(i, j, c)

    def put(self, rows, x, y):
        for j, r in enumerate(rows):
            for i, c in enumerate(r):
                if c != '.':
                    self.px(x + i, y + j, c)

    def rows(self):
        return [''.join(r) for r in self.g]


LEATHER = ('F', 'h', 'f')         # brown leather: fill, lit, shade (pillar 4 keeps velvet and brass for CLOSED and the LED)
LINING = ('f', 'F', 'e')          # the flap's inside, seen when it is open
NOTE = ('G', 'z', 'g')            # cash is green
CARD = ('c', 'w', 'b')            # a cream card with a teal band
STUD = ['.##.', '#yM#', '#Mu#', '.##.']           # the mustard clasp stud
COIN = ['.###.', '#yMM#', '#MMm#', '.###.']


def body(G, top, bulge=0, bottom=50, x0=2, x1=23, sag=0):
    """The wallet's front: a rounded slab; bulge pushes the sides out, sag dips the top edge in the middle."""
    def inside(i, j):
        t0 = top + round(sag * math.sin(math.pi * min(max((i - x0) / max(x1 - x0, 1), 0), 1)))
        if j < t0 or j > bottom:
            return False
        t = (j - top) / max(bottom - top, 1)
        b = round(bulge * math.sin(math.pi * t))
        xl, xr = x0 - b, x1 + b
        if i < xl or i > xr:
            return False
        return min(i - xl, xr - i) + min(j - t0, bottom - j) >= 1
    G.shape(inside, *LEATHER)
    # stitching one texel inside the sides and the bottom (every other texel, the leather's darkest line)
    for j in range(top + 4, bottom - 1, 2):
        t = (j - top) / max(bottom - top, 1)
        b = round(bulge * math.sin(math.pi * t))
        G.px(x0 - b + 2, j, 'f')
        G.px(x1 + b - 2, j, 'f')
    for i in range(x0 + 3, x1 - 2, 2):
        G.px(i, bottom - 2, 'f')


def flap_closed(G, top, depth, tip, lift=0, x0=2, x1=23):
    """The closed flap over the body's top: a band across, a tongue down the middle with the stud at its end;
    lift pulls the tongue up off the body and opens a dark gap under it (the strain)."""
    tl, tr = 8, 17                     # the tongue, 10 texels wide, centred on the 26-texel canvas
    tb = top + depth + tip - lift      # the tongue's bottom row
    def inside(i, j):
        if j < top or i < x0 or i > x1:
            return False
        if j <= top + depth:
            return True
        if not (tl <= i <= tr) or j > tb:
            return False
        return not (j == tb and i in (tl, tr))
    if lift:
        for j in range(tb + 1, top + depth + tip + 1):
            for i in range(tl + 1, tr):
                G.px(i, j, 'e')
    G.shape(inside, *LEATHER)
    for i in range(x0 + 2, x1 - 1, 2):
        G.px(i, top + 2, 'h')
    sy = tb - 4
    G.put(STUD, 11, sy)
    return sy


def flap_open(G, top, height, x0=3, x1=22):
    """The flap thrown back behind the wallet's mouth: its lining shows, the stud is on its top edge."""
    def inside(i, j):
        if j < top or j > top + height:
            return False
        k = (top + height - j) // 2
        return x0 + k // 2 <= i <= x1 - k // 2
    G.shape(inside, *LINING)
    cx = (x0 + x1) // 2
    G.put(STUD, cx - 1, top - 2)


def note(G, x, y, w=8, h=8):
    """A banknote standing in the wallet: green paper, a pale inset border and a darker portrait oval."""
    G.shape(lambda i, j: x <= i < x + w and y <= j < y + h, *NOTE)
    cx = x + w // 2
    for i in range(cx - 2, cx + 1):
        G.px(i, y + 3, 'g')
        G.px(i, y + 4, 'g')
    G.px(cx - 1, y + 3, 'z')


def note_flat(G, x, y, w=13, h=6):
    """A banknote lying across the top of the pile (overstuffed)."""
    G.shape(lambda i, j: x <= i < x + w and y <= j < y + h, *NOTE)
    for j in (y + 2, y + 3):
        G.px(x + w // 2 - 1, j, 'g')
        G.px(x + w // 2, j, 'g')


def bill(G, x, y, w=14, h=6):
    """A banknote seen lying in a wad (landscape, as cash reads at a glance): green paper, a pale corner mark and a
    dark portrait disc in the middle. Review fix: the old upright slabs read as bottles or a cactus."""
    G.shape(lambda i, j: x <= i < x + w and y <= j < y + h, *NOTE)
    cx, cy = x + w // 2, y + h // 2
    for i in (cx - 1, cx):
        G.px(i, cy - 1, 'g')
        G.px(i, cy, 'g')
    G.px(cx - 2, cy, 'g')
    G.px(cx + 1, cy - 1, 'g')
    G.px(x + 2, y + h - 3, 'z')
    G.px(x + w - 3, y + 2, 'z')


def emboss(G, x, y):
    """A debossed euro sign on the wallet's front (brown dark, a lit lip under it); replaces the little tag, whose
    white box read as a robot face at stage size."""
    rows = ['..###', '.#...', '####.', '.#...', '####.', '..###']
    for j, r in enumerate(rows):
        for i, c in enumerate(r):
            if c == '#':
                G.px(x + i, y + j + 1, 'h')
    for j, r in enumerate(rows):
        for i, c in enumerate(r):
            if c == '#':
                G.px(x + i, y + j, 'e')


def card(G, x, y, w, h):
    G.shape(lambda i, j: x <= i < x + w and y <= j < y + h, *CARD)
    for i in range(x + 1, x + w - 1):
        G.px(i, y + 2, '4')
        G.px(i, y + 3, '3')


def mouth(G, top, x0=3, x1=22):
    """The open wallet's mouth: a dark line under the notes along the body's top edge."""
    for i in range(x0 + 1, x1):
        G.px(i, top + 1, 'e')


def mini_tag(G, x, y, face, string_from=None):
    """The wallet's little hang-tag (11 x 8): the same face as the budget tag on the HUD."""
    if string_from:
        sx, sy = string_from
        n = max(abs(x - sx), abs(y + 1 - sy))
        for k in range(n + 1):
            G.px(round(sx + (x - sx) * k / max(n, 1)), round(sy + (y + 1 - sy) * k / max(n, 1)), 'a')
    G.shape(lambda i, j: x <= i < x + 11 and y <= j < y + 8 and not (i - x < 2 and (j - y == 0 or j - y == 7)), *CARD)
    G.px(x + 1, y + 3, '#')
    G.px(x + 1, y + 4, '#')
    G.put(['.##', '#..', '###', '#..', '.##'], x + 5, y + 1)


# ---------- faces ----------
# big faces: 11 x 10 on the budget tag (2 px texels); '#' ink, 'h' blush (brown light), 'w' eye shine / teeth, '%' mouth inside
FACE = {
    's0': ['...........', '...........', '..##...##..', '..##...##..', '...........', '...........', '...........',
           '...#####...', '...........', '...........'],
    's1': ['...........', '...........', '..##...##..', '..##...##..', '...........', '...........', '.h.......h.',
           '..#.....#..', '...#####...', '...........'],
    's2': ['...........', '.###...###.', '.#w#...#w#.', '.###...###.', '...........', '.h..###..h.', '....#%#....',
           '....#%#....', '....###....', '...........'],
    's3': ['...........', '...........', '..#.....#..', '.#.#...#.#.', '...........', '.h#######h.', '..#%%%%%#..',
           '..#%%%%%#..', '...#####...', '...........'],
    's4': ['.........5.', '.#.....#.55', '..#...#..55', '.#.....#...', '...........', '.#########.', '.#wwwwwww#.',
           '..#%%%%%#..', '...#####...', '...........'],
    'over': ['...........', '...........', '..#.....#..', '.#.#...#.#.', '...........', '.h.......h.', '..#.....#..',
             '...#####...', '...........', '...........'],
    'on': ['...........', '...........', '...........', '.###...###.', '...........', '.h.......h.', '...#...#...',
           '....###....', '...........', '...........'],
    'short': ['...#...#...', '.##.....##.', '...........', '..##...##..', '..##...##..', '...........', '...........',
              '....###....', '...#...#...', '..#.....#..'],
}
# mini faces: 7 x 4 on the wallet's own tag
MINI = {
    's0': ['.#...#.', '.......', '..###..', '.......'],
    's1': ['.#...#.', '.......', '.#...#.', '..###..'],
    's2': ['##...##', '.......', '..###..', '..#%#..'],
    's3': ['#.#.#.#', '.......', '#######', '.#%%%#.'],
    's4': ['#.#.#.#', '.......', '#######', '#wwwww#'],
    'over': ['.......', '#.#.#.#', '.#...#.', '..###..'],
    'on': ['.......', '##...##', '.#...#.', '..###..'],
    'short': ['#.....#', '.#...#.', '..###..', '.#...#.'],
}


def wallet(state):
    G = Grid()
    if state == 's0':      # slim and shut: projected or counted total under half the budget
        body(G, 36)
        flap_closed(G, 36, 3, 4)
        emboss(G, 10, 42)
    elif state == 's1':    # bulging, the clasp strains, a card corner pokes out
        card(G, 4, 28, 8, 8)
        body(G, 33, bulge=1)
        sy = flap_closed(G, 33, 3, 4, lift=1)
        for d in (1, 2):   # strain creases fanning from the stud
            G.px(10 - d, sy + 2 - d, 'f')
            G.px(15 + d, sy + 2 - d, 'f')
        emboss(G, 10, 42)
    elif state == 's2':    # nearly there: a wad of notes pokes out of the top, the stud is about to pop
        card(G, 3, 26, 8, 8)
        bill(G, 9, 27, 14, 6)
        bill(G, 6, 24, 14, 6)
        body(G, 31, bulge=2)
        sy = flap_closed(G, 31, 3, 4, lift=2)
        for d in (1, 2, 3):
            G.px(10 - d, sy + 2 - d, 'f')
            G.px(15 + d, sy + 2 - d, 'f')
        emboss(G, 10, 42)
    elif state == 's3':    # budget met: the flap flies open, the wad fans out
        flap_open(G, 22, 8)
        bill(G, 1, 27, 14, 6)
        bill(G, 10, 25, 14, 6)
        card(G, 14, 21, 9, 7)
        bill(G, 3, 22, 14, 6)
        bill(G, 8, 18, 14, 6)
        body(G, 31, bulge=1)
        mouth(G, 31)
        G.put(STUD, 11, 32)
        emboss(G, 10, 41)
    elif state == 's4':    # way over: overstuffed, the wad towers, a note slips out, a coin rolled out
        flap_open(G, 20, 8)
        bill(G, 0, 26, 14, 6)
        bill(G, 11, 24, 14, 6)
        bill(G, 2, 21, 15, 6)
        card(G, 15, 18, 9, 7)
        bill(G, 7, 17, 14, 6)
        bill(G, 1, 13, 14, 6)
        bill(G, 9, 10, 14, 6)
        body(G, 30, bulge=3)
        mouth(G, 30)
        G.put(STUD, 11, 31)
        bill(G, 0, 38, 9, 5)       # one note slipping out over the front
        emboss(G, 11, 41)
        G.put(COIN, 20, 47)
    elif state == 'hop':   # planning drag, the would-be total rises: the S1 pose (lifted by the page)
        card(G, 4, 28, 8, 8)
        body(G, 33, bulge=1)
        flap_closed(G, 33, 3, 4, lift=1)
        emboss(G, 10, 42)
    elif state == 'slump':  # planning drag, the would-be total falls: the S1 pose sags
        card(G, 4, 30, 8, 6)
        body(G, 34, bulge=1, sag=2)
        flap_closed(G, 34, 3, 4)
        emboss(G, 10, 43)
    elif state == 'over':  # verdict OVER: the wallet has paid, empty and open; notes flutter to the drawer (stickers)
        flap_open(G, 28, 7)
        body(G, 36)
        mouth(G, 36)
        G.put(STUD, 11, 37)
        emboss(G, 10, 42)
    elif state == 'on':    # verdict ON QUOTA: a satisfied snap shut, slim again
        body(G, 36)
        flap_closed(G, 36, 3, 4)
        emboss(G, 10, 42)
    elif state == 'short':  # verdict SHORT: half full and sagging, one limp note, the flap hangs half open
        flap_open(G, 28, 5, x0=4, x1=20)
        bill(G, 5, 28, 13, 6)
        for i in range(6, 17):   # the limp note folds forward over the lip
            G.px(i, 33, 'g')
        body(G, 32, bulge=1, sag=3)
        emboss(G, 10, 42)
    return G.rows()


STATES = ['s0', 's1', 's2', 's3', 's4', 'hop', 'slump', 'over', 'on', 'short']


def check(pal):
    used = set()
    for s in STATES:
        rows = wallet(s)
        assert len(rows) == H and all(len(r) == W for r in rows), s
        used |= set(''.join(rows))
    for d in (FACE, MINI):
        for k, rows in d.items():
            assert len({len(r) for r in rows}) == 1, k
            used |= set(''.join(rows))
    bad = used - set(pal)
    if bad:
        raise SystemExit('not in palette: ' + ''.join(sorted(bad)))


if __name__ == '__main__':
    p = palette()
    check(p)
    for s in STATES:
        print(s)
        print('\n'.join(wallet(s)))
