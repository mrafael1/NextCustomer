"""Builds ../starter_choice_107.html from template.html (standard library only; python build.py).

Embeds the game's fonts, the card list of the readability v3 mock-up (../readability_v3_src/cards.js: every stocked
card with its short sticker text and ticket colour) and the four family glyphs that only exist on
feature/readability (C:/dev/projects/NC-read/art/icons/family_*.png), so the page opens from file:// with no server.
Item sprites, icons and frames are read from the repo's art/ folder at ../../../art/.
"""
import base64
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[3]
FONTS = REPO / "fonts"
NC_READ_ICONS = REPO.parent / "NC-read" / "art" / "icons"
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400 700"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]


def face(family, data, weight):
    b64 = base64.b64encode(data).decode("ascii")
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
            f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")


def glyphs():
    out = []
    for name in ("breakfast", "dairy", "clearance", "coupon"):
        data = base64.b64encode((NC_READ_ICONS / f"family_{name}.png").read_bytes()).decode("ascii")
        out.append(f"  {name.capitalize()}: 'data:image/png;base64,{data}'")
    return "const GLYPH_DATA = {\n" + ",\n".join(out) + "\n};"


css = [face(f, (FONTS / file).read_bytes(), w) for f, file, w in FACES]
page = (HERE / "template.html").read_text(encoding="utf-8")
page = page.replace("/*FONTS*/", "\n".join(css))
page = page.replace("/*CARDS*/", (HERE.parent / "readability_v3_src" / "cards.js").read_text(encoding="utf-8"))
page = page.replace("/*GLYPHS*/", glyphs())
out = HERE.parent / "starter_choice_107.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
