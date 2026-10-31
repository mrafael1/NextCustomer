"""Builds ../ambiance_123.html from template.html (standard library only; python build.py).

Embeds the game's fonts and the planning capture the page lights
(docs/art/rule_tweaks_2/shift_screen_effects_1280x720.png), so the page opens from file:// and
its canvas can read the capture's pixels with no server.
"""
import base64
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[3]
FONTS = REPO / "fonts"
BASE = REPO / "docs" / "art" / "rule_tweaks_2" / "shift_screen_effects_1280x720.png"
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400 700"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]


def face(family, data, weight):
    b64 = base64.b64encode(data).decode("ascii")
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
            f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")


css = [face(f, (FONTS / file).read_bytes(), w) for f, file, w in FACES]
page = (HERE / "template.html").read_text(encoding="utf-8")
page = page.replace("/*FONTS*/", "\n".join(css))
page = page.replace("/*BASE*/", "data:image/png;base64," + base64.b64encode(BASE.read_bytes()).decode("ascii"))
out = HERE.parent / "ambiance_123.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
