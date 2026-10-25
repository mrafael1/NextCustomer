"""Builds ../readability_v3.html from template.html (Pillow for the hand cut-outs; python build.py).

Embeds the game's fonts (Pixelify Sans for item names, Atkinson Hyperlegible Next for body text and numbers,
JetBrains Mono for the receipt), cards.js (every stocked card and its ticket colour; python cards.py rewrites it from
data/cards) and the hand items cut out of the planning capture, so section 4 can grey them out one by one (a page
opened from file:// cannot read an image's pixels itself).
"""
import base64
import io
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE.parents[3] / "fonts"
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]
# the hand on the planning capture: each item above its basket's rim, by x range (the wall behind is one flat brown)
CAPTURE = HERE.parent / "premium_machine_ref_shift3_planning_no_announce.png"
WALL = (110, 69, 36)
HAND = [("banana", 372, 462), ("soup", 476, 552), ("milk", 618, 682), ("cereal", 700, 780),
        ("eggs", 838, 914), ("banana", 924, 1012), ("cereal", 1060, 1140), ("scissors", 1172, 1222)]
TEAL = {(134, 194, 182), (95, 176, 168)}


def face(family, data, weight):
    b64 = base64.b64encode(data).decode("ascii")
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
            f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")


def hand_cutouts():
    im = Image.open(CAPTURE).convert("RGB")
    out = []
    for item_id, x0, x1 in HAND:
        # the basket's rim: the first ink row with the rim's teal two rows under it
        def rim(x):
            for y in range(560, 600):
                if im.getpixel((x, y)) == (43, 36, 32) and im.getpixel((x, y + 2)) in TEAL:
                    return y
            return 590
        y0 = 500
        cut = Image.new("RGBA", (x1 - x0, 600 - y0), (0, 0, 0, 0))
        top, bottom = 999, 0
        for x in range(x0, x1):
            r = rim(x)
            for y in range(y0, r):
                px = im.getpixel((x, y))
                if px != WALL:
                    cut.putpixel((x - x0, y - y0), px + (255,))
                    top, bottom = min(top, y), max(bottom, y)
        cut = cut.crop((0, top - y0, x1 - x0, bottom - y0 + 1))
        buf = io.BytesIO()
        cut.save(buf, "PNG")
        uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")
        out.append(f"{{id:'{item_id}', x:{x0}, y:{top}, w:{x1 - x0}, h:{bottom - top + 1}, src:'{uri}'}}")
    return "const HAND = [\n  " + ",\n  ".join(out) + "\n];"


css = [face(f, (FONTS / file).read_bytes(), w) for f, file, w in FACES]
page = (HERE / "template.html").read_text(encoding="utf-8")
page = page.replace("/*FONTS*/", "\n".join(css))
page = page.replace("/*CARDS*/", (HERE / "cards.js").read_text(encoding="utf-8"))
page = page.replace("/*HAND*/", hand_cutouts())
out = HERE.parent / "readability_v3.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
