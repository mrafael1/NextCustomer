"""Builds ../readability_v2.html from template.html with the game's fonts embedded (standard library only).

Pixelify Sans (item names, decided on v1), Atkinson Hyperlegible Next (body text and numbers) and
JetBrains Mono (the receipt) come from the repo's fonts/ folder, so the page works offline and the
stills are deterministic.
"""
import base64
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE.parents[3] / "fonts"
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
page = (HERE / "template.html").read_text(encoding="utf-8").replace("/*FONTS*/", "\n".join(css))
out = HERE.parent / "readability_v2.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
