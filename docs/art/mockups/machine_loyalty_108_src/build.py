"""Builds ../machine_loyalty_108.html from template.html (python build.py; needs Pillow).

Embeds the game's fonts (Pixelify Sans, Atkinson Hyperlegible Next, JetBrains Mono), scorer.js (the example rows'
scorer and every perk on the page; node scorer_test.js prints its numbers) and the loyalty ticket's octagon ring
(art/icons/stamp_ring.png) recoloured in each family's colours, so a page opened from file:// needs no pixel reads.
Every other sprite is loaded from the repo's art/ folder by a relative path.
"""
import base64
import io
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[3]
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]
# the ring's two gold tones become the family's light and face (NC-read data/families/*.tres); the centre stays teal
RING_LIGHT, RING_FACE = (241, 210, 122), (226, 179, 60)
FAMILY_RING = {
    # neutral (position) perks: silver, so they no longer read as Breakfast's gold; Today: today's gold perk tickets
    "Neutral": ("#ecebe4", "#c7beab"),
    "Mixed": ("#ecebe4", "#c7beab"),
    "Today": ("#f1d27a", "#e2b33c"),
    "Breakfast": ("#f1d27a", "#e2b33c"),
    "Bakery": ("#ddcba5", "#d2a874"),
    "Produce": ("#a5d17e", "#5fae5a"),
    "Dairy": ("#86c2b6", "#4f9a94"),
    "Frozen": ("#fbf7ee", "#c3e0d4"),
    "Snack": ("#a87a4e", "#7a5232"),
    "Household": ("#8a8172", "#5e574d"),
    "Clearance": ("#d9534f", "#a83a3c"),
    "Food": ("#f5bfa0", "#ec8a6e"),
    "Coupon": ("#ecebe4", "#a9a59b"),
}


def rgb(hex_colour):
    n = int(hex_colour[1:], 16)
    return (n >> 16, (n >> 8) & 255, n & 255)


def face(family, data, weight):
    b64 = base64.b64encode(data).decode("ascii")
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
            f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")


def rings():
    src = Image.open(REPO / "art" / "icons" / "stamp_ring.png").convert("RGBA")
    out = []
    for fam, (light, body) in FAMILY_RING.items():
        im = src.copy()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if (r, g, b) == RING_LIGHT:
                    px[x, y] = rgb(light) + (a,)
                elif (r, g, b) == RING_FACE:
                    px[x, y] = rgb(body) + (a,)
        buf = io.BytesIO()
        im.save(buf, "PNG")
        out.append(f"  {fam}: 'data:image/png;base64,{base64.b64encode(buf.getvalue()).decode('ascii')}'")
    return "const RING = {\n" + ",\n".join(out) + "\n};"


css = [face(f, (REPO / "fonts" / file).read_bytes(), w) for f, file, w in FACES]
page = (HERE / "template.html").read_text(encoding="utf-8")
page = page.replace("/*FONTS*/", "\n".join(css))
scorer = (HERE / "scorer.js").read_text(encoding="utf-8").replace(
    "if (typeof module !== 'undefined') module.exports", "if (false) module.exports")
page = page.replace("/*SCORER*/", scorer)
page = page.replace("/*RINGS*/", rings())
out = HERE.parent / "machine_loyalty_108.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
