"""Builds the #123 clean scene stills (Python 3 with Pillow; python build.py).

Recomposes the game's planning capture (docs/art/rule_tweaks_2/shift_screen_effects_1280x720.png)
on a newly painted store: every piece of UI (top bar, receipt, monitor, belt with its items,
stickers and tickets, hand baskets, keys) is cut from the capture, so its pixels are the game's,
and only the background and the counter around them are new. The store is painted on the 640x360
art grid in palette colours and scaled 2x, like the game's scenery.

Writes ../scene_123_now.png (the capture), ../scene_123_a.png (store at dusk),
../scene_123_b.png (spotlit counter), ../scene_123_layout.png (the composition boxes) and the
decision page ../scene_123.html (template.html with the game's fonts and the four stills embedded,
so it opens from file://).
"""
import base64
import io
import pathlib

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[3]
OUT = HERE.parent
CAPTURE = REPO / "docs" / "art" / "rule_tweaks_2" / "shift_screen_effects_1280x720.png"
SCENERY = REPO / "art" / "scenery"
ICONS = REPO / "art" / "icons"

# The game's palette (art/src/palette.txt). The capture's background is drawn hazed (modulated),
# so its colours fall outside the palette while every item, sticker and ticket stays on it: that
# is what tells a piece of UI from the wall behind it.
PALETTE = {(int(line.split()[1][0:2], 16), int(line.split()[1][2:4], 16), int(line.split()[1][4:6], 16))
           for line in (REPO / "art" / "src" / "palette.txt").read_text().splitlines()
           if line and not line.startswith(";") and len(line.split()) >= 2 and len(line.split()[1]) == 6}
FLOOR = {(0x6E, 0x45, 0x24), (0x2C, 0x35, 0x33)}  # The counter's wood and the floor band: palette, but scenery.

BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# Where each piece of the capture moves to (dy in canvas px). The belt comes down to sit right
# on top of the baskets, so the counter reads as one surface.
BELT_DY = 34
HAND_DY = 12
KEYS_DY = 30
LEDGE_Y = 674  # The basket ledge's top after HAND_DY, carried across the whole width.


def hexc(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def sample_colours(img, boxes, min_count=1):
    seen = {}
    for box in boxes:
        for c in img.crop(box).get_flattened_data():
            seen[c] = seen.get(c, 0) + 1
    return {c for c, n in seen.items() if n >= min_count}


def keyed(img, box, extra=frozenset(), band=None, keep=None, off_palette=True):
    """Crops box from img, turning its scenery transparent: off-palette (hazed) colours and extra,
    only inside band rows (crop-local), never inside keep (a crop-local rect)."""
    out = img.crop(box).convert("RGBA")
    px = out.load()
    w, h = out.size
    rows = range(h) if band is None else band
    for y in rows:
        for x in range(w):
            if keep and keep[0] <= x < keep[2] and keep[1] <= y < keep[3]:
                continue
            c = px[x, y][:3]
            if (off_palette and c not in PALETTE) or c in extra:
                px[x, y] = (0, 0, 0, 0)
    return out


class Art:
    """A 640x360 art-grid canvas with a dark and a lit colour for everything it paints."""

    def __init__(self):
        self.dark = Image.new("RGBA", (640, 360), (0, 0, 0, 0))
        self.lit = Image.new("RGBA", (640, 360), (0, 0, 0, 0))
        self.dd = ImageDraw.Draw(self.dark)
        self.dl = ImageDraw.Draw(self.lit)

    def rect(self, x, y, w, h, dark, lit=None):
        if w <= 0 or h <= 0:
            return
        self.dd.rectangle([x, y, x + w - 1, y + h - 1], fill=hexc(dark))
        self.dl.rectangle([x, y, x + w - 1, y + h - 1], fill=hexc(lit or dark))

    def dither(self, x, y, w, h, dark, lit=None, level=2, phase=0):
        """Level 1 = 25 %, 2 = 50 %, 3 = 75 % of the pixels."""
        for j in range(h):
            for i in range(w):
                ax, ay = x + i, y + j
                on = {1: (ax + phase) % 2 == 0 and ay % 2 == 0,
                      2: (ax + ay + phase) % 2 == 0,
                      3: not ((ax + phase) % 2 == 1 and ay % 2 == 1)}[level]
                if on and 0 <= ax < 640 and 0 <= ay < 360:
                    self.dark.putpixel((ax, ay), hexc(dark))
                    self.lit.putpixel((ax, ay), hexc(lit or dark))

    def combine(self, light):
        """Picks the lit colour where light(x, y) beats the Bayer threshold: flat bands, dithered edges."""
        out = Image.new("RGBA", (640, 360))
        dp, lp, op = self.dark.load(), self.lit.load(), out.load()
        for y in range(360):
            for x in range(640):
                v = light(x, y)
                # Narrow dither band at each edge so the pools stay flat inside.
                t = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16
                op[x, y] = lp[x, y] if v > 0.5 + (t - 0.5) * 0.45 else dp[x, y]
        return out


def cone(cx, top, slope, reach, x, y):
    """1 inside a lamp's light cone, falling to 0 at its reach (art px)."""
    dy = y - top
    if dy < 0 or dy > reach:
        return 0.0
    half = 3 + dy * slope
    t = abs(x - cx) / half
    return max(0.0, 1.0 - t * t) * (1.0 - (dy / reach) ** 2) * 1.6


LAMPS = [(196, 39), (494, 39), (588, 39)]  # Art px: pendants left of the monitor and on the right.


def paint_store(art, variant):
    """The world plane: ceiling, far wall with the storefront glass, a gondola run, signs."""
    a = art
    # Ceiling and far wall.
    a.rect(0, 28, 640, 12, "172c2b", "1f3b3a")
    a.rect(0, 39, 640, 1, "222a29", "2c3533")
    a.rect(0, 40, 640, 140, "1f3b3a", "2a4d4b")
    if variant == "a":
        # The storefront glass, dusk outside: sky bands, a thin warm horizon, the town's roofs.
        x0, x1, top, bottom = 150, 640, 46, 100
        for y in range(top, bottom):
            f = (y - top) / (bottom - top)
            if f < 0.5:
                c = "2a4d4b"
            elif f < 0.86:
                c = "3a7672"
            elif f < 0.92:
                c = "4f9a94"
            else:
                c = "ec8a6e"
            a.rect(x0, y, x1 - x0, 1, c)
        a.dither(x0, top + 25, x1 - x0, 2, "3a7672", level=2)
        a.dither(x0, top + 44, x1 - x0, 2, "4f9a94", level=1)
        # Roofs and a few lit windows, never outlined.
        heights = [9, 13, 7, 15, 11, 6, 12, 17, 8, 10, 14, 7, 11, 16, 9, 12, 6, 13, 10, 8]
        x = x0
        n = 0
        while x < x1:
            w = 14 + (n * 7) % 12
            hgt = heights[n % len(heights)]
            a.rect(x, bottom - hgt, w, hgt, "1f3b3a")
            for k in range(2):
                wx = x + 3 + (n * 5 + k * 6) % max(1, w - 5)
                wy = bottom - hgt + 3 + k * 4
                if (n + k) % 4 == 0 and wy < bottom - 2:
                    a.rect(wx, wy, 1, 1, "f1d27a")
            x += w
            n += 1
        # Mullions and the frame: teal, lit from the store side.
        for mx in range(x0, x1, 70):
            a.rect(mx, top - 2, 3, bottom - top + 4, "2c3533", "3a7672")
        a.rect(x0, top - 3, x1 - x0, 3, "2c3533", "3a7672")
        a.rect(x0, bottom, x1 - x0, 2, "2c3533", "3a7672")
        # Two faint reflections on the glass.
        for rx in (204, 418):
            for k in range(14):
                a.rect(rx + k, top + 30 - k * 2, 1, 2, "3a7672", "4f9a94")
    # The gondola run behind the counter: two shelves of products seen over the belt.
    gtop = 100
    a.rect(0, gtop, 640, 80, "222a29", "2c3533")
    a.rect(0, gtop, 640, 2, "2c3533", "45423d")
    products = [("2a4d4b", "3a7672"), ("3d3a36", "6f6b63"), ("4a3022", "7a5232"), ("2c3533", "5e574d"),
                ("6e2630", "a83a3c"), ("2a4d4b", "3a7672"), ("3d3a36", "8a8172"), ("7a5a1c", "b38425")]
    for row, sy in enumerate((gtop + 5, gtop + 24)):
        x = -6 * row
        n = row * 3
        while x < 640:
            dark, lit = products[(n * 3 + row) % len(products)]
            facings = 4 + (n * 3) % 3
            pw, ph = 5, 12 - (n % 2) * 2
            for f in range(facings):
                px_ = x + f * (pw + 1)
                a.rect(px_, sy + 15 - ph, pw, ph, dark, lit)
            x += facings * (pw + 1) + 4
            n += 1
        # The shelf lip, lit along its top edge.
        a.rect(0, sy + 15, 640, 3, "2c2926", "57534c")
        a.rect(0, sy + 15, 640, 1, "3d3a36", "8d8a83")
    if variant == "b":
        # Spotlit: the store is only a silhouette; the counter is the stage.
        for y in range(28, 180):
            for x in range(640):
                if a.dark.getpixel((x, y))[3]:
                    a.dark.putpixel((x, y), hexc("172c2b") if y > 41 else hexc("172c2b"))
        a.dd.rectangle([0, 100, 639, 179], fill=hexc("1f3b3a"))
    # Hanging aisle signs between the lamps, on the right where the scene is open.
    for sx, label in (((532, "4"), (612, "5")) if variant == "a" else ()):
        a.rect(sx + 6, 28, 1, 14, "45423d", "6f6b63")
        a.rect(sx + 22, 28, 1, 14, "45423d", "6f6b63")
        a.rect(sx, 42, 30, 12, "2a4d4b", "3a7672")
        a.rect(sx, 42, 30, 1, "3a7672", "4f9a94")
        a.rect(sx, 53, 30, 1, "1f3b3a", "2a4d4b")
    return art


def lamp_light(variant):
    lamps = LAMPS if variant == "a" else [(LAMPS[0][0], 39)]
    reach = 150 if variant == "a" else 140

    def light(x, y):
        v = 0.0
        for cx, top in lamps:
            v = max(v, cone(cx, top, 0.42 if variant == "a" else 0.6, reach, x, y))
        if variant == "b":
            # One broad pool behind the counter's centre, Inscryption's single lamp.
            dx = (x - 400) / 230
            dy = (y - 150) / 70
            v = max(v, 1.25 * (1 - (dx * dx + dy * dy)))
        return v

    return light


def build(variant, cap):
    art = paint_store(Art(), variant)
    world = art.combine(lamp_light(variant)).resize((1280, 720), Image.NEAREST)
    canvas = Image.new("RGBA", (1280, 720), hexc("24221f"))
    canvas.alpha_composite(world.crop((0, 56, 1280, 360)), (0, 56))

    # The counter face: one charcoal laminate under the belt, panel seams, the ticket rail's shadow.
    d = ImageDraw.Draw(canvas)
    face_top = 494 + BELT_DY
    d.rectangle([336, face_top, 1279, LEDGE_Y - 1], fill=hexc("2c2926"))
    d.rectangle([336, face_top, 1279, face_top + 5], fill=hexc("24221f"))
    for sx in range(452, 1280, 232):
        d.rectangle([sx, face_top + 6, sx + 1, LEDGE_Y - 1], fill=hexc("24221f"))
    # The register cabinet: the same laminate, so the column and the counter are one piece.
    d.rectangle([0, 392, 337, LEDGE_Y - 1], fill=hexc("2c2926"))
    d.rectangle([0, 392, 337, 397], fill=hexc("45423d"))
    d.rectangle([336, 392, 341, LEDGE_Y - 1], fill=hexc("24221f"))
    # The floor line below the ledge.
    d.rectangle([0, LEDGE_Y + 34, 1279, 719], fill=hexc("172c2b"))

    # Hand baskets (with the ledge), then the belt over them: the belt's chips may overlap.
    hand = keyed(cap, (336, 512, 1280, 700), FLOOR)
    canvas.alpha_composite(hand, (336, 512 + HAND_DY))
    ledge = cap.crop((700, 662, 720, 696)).convert("RGBA")
    for x in range(0, 346, 20):
        canvas.alpha_composite(ledge, (x, LEDGE_Y))
    # Above the belt only the capture's own wall, machine, cold case and stand colours go: the
    # stickers' anti-aliased digits are off-palette too and must stay.
    scenery = sample_colours(cap, [(486, 244, 900, 262), (940, 240, 1185, 262), (1186, 240, 1280, 262),
                                   (300, 170, 480, 262), (348, 256, 380, 330), (360, 256, 500, 296)])
    belt = keyed(cap, (348, 256, 1268, 520), FLOOR, off_palette=False)
    bp = belt.load()
    for y in range(0, 64):
        for x in range(belt.size[0]):
            if bp[x, y][:3] in scenery:
                bp[x, y] = (0, 0, 0, 0)
    # The rewards machine's NEW ITEMS label and the cold case's edge show between the stickers.
    for x0, x1 in ((610, 680), (908, 920)):
        for y in range(0, 44):
            for x in range(x0, x1):
                bp[x, y] = (0, 0, 0, 0)
    canvas.alpha_composite(belt, (348, 256 + BELT_DY))

    # The left column: receipt and printer (the paper kept whole: its text is anti-aliased), then the keys.
    receipt = keyed(cap, (30, 90, 284, 394), FLOOR, keep=(16, 2, 253, 253))
    canvas.alpha_composite(receipt, (30, 90))
    keys = cap.crop((12, 412, 326, 616)).convert("RGBA")
    canvas.alpha_composite(keys, (12, 412 + KEYS_DY))

    # The hung monitor and its rods, over the store; then the top bar.
    canvas.alpha_composite(cap.crop((484, 56, 908, 250)).convert("RGBA"), (484, 56))
    canvas.alpha_composite(cap.crop((0, 0, 1280, 58)).convert("RGBA"), (0, 0))

    # Pendant lamps over the store, drawn last so they hang in front of the wall.
    lamp = Image.open(SCENERY / "ceiling_lamp.png").convert("RGBA")
    for cx, _ in (LAMPS if variant == "a" else LAMPS[:1]):
        if cx * 2 - 37 > 300:
            d.rectangle([cx * 2 - 1, 58, cx * 2, 70], fill=hexc("45423d"))
            canvas.alpha_composite(lamp, (cx * 2 - 37, 70))
    if variant == "a":
        # Sign faces: the aisle number and its icon.
        for sx, icon in ((532, "aisle_bakery"), (612, "aisle_cold_cases")):
            ic = Image.open(ICONS / f"{icon}.png").convert("RGBA")
            ic = ic.resize((ic.width * 2, ic.height * 2), Image.NEAREST)
            canvas.alpha_composite(ic, (sx * 2 + 30 - ic.width // 2, 96 - ic.height // 2))
    return canvas


def layout(base):
    out = base.copy().convert("RGBA")
    over = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    font = ImageFont.truetype(str(REPO / "fonts" / "PixelifySans-Variable.ttf"), 24)
    boxes = [
        ((0, 58, 1280, 290), (134, 194, 182, 70), "WORLD: the store, quiet"),
        ((336, 290, 1280, LEDGE_Y + 34), (241, 210, 122, 70), "WORK: belt + baskets, one counter"),
        ((0, 58, 336, LEDGE_Y + 34), (236, 138, 110, 70), "INFO: one column"),
    ]
    for (x0, y0, x1, y1), col, label in boxes:
        d.rectangle([x0 + 2, y0 + 2, x1 - 3, y1 - 3], outline=col[:3] + (255,), width=3, fill=col)
        lx = 920 if label.startswith("WORLD") else x0 + 8  # Clear of the info column and the monitor.
        tw = d.textlength(label, font=font)
        d.rectangle([lx, y0 + 8, lx + 16 + tw, y0 + 40], fill=(31, 59, 58, 235))
        d.text((lx + 8, y0 + 10), label, fill=(251, 247, 238, 255), font=font)
    out.alpha_composite(over)
    return out


FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400 700"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]


def data_url(img):
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def page(stills):
    css = []
    for family, file, weight in FACES:
        b64 = base64.b64encode((REPO / "fonts" / file).read_bytes()).decode("ascii")
        css.append(f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
                   f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")
    html = (HERE / "template.html").read_text(encoding="utf-8").replace("/*FONTS*/", "\n".join(css))
    for key, img in stills.items():
        html = html.replace(f"/*{key}*/", data_url(img))
    (OUT / "scene_123.html").write_text(html, encoding="utf-8")


def main():
    cap = Image.open(CAPTURE).convert("RGB")
    a = build("a", cap)
    stills = {"NOW": cap, "A": a, "B": build("b", cap), "LAYOUT": layout(a)}
    for key, img in stills.items():
        img.convert("RGB").save(OUT / f"scene_123_{key.lower()}.png")
    page(stills)
    print("wrote scene_123.html and", ", ".join(f"scene_123_{k.lower()}.png" for k in stills))


if __name__ == "__main__":
    main()
