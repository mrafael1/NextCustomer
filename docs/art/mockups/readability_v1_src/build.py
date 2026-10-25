"""Builds ../readability_v1.html from template.html with every font embedded (standard library only).

The game's fonts come from fonts/. The pixel-font candidates (VT323, Jersey 15, DotGothic16, all OFL) are
fetched from Google Fonts at build time (latin subset only), so the built page works offline and the stills
are deterministic. The fetched files are not kept.
"""
import base64
import pathlib
import re
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE.parents[3] / "fonts"
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400 700"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]
GOOGLE = ["VT323", "Jersey 15", "DotGothic16"]


def face(family, data, weight):
    b64 = base64.b64encode(data).decode("ascii")
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
            f"src:url(data:font/ttf;base64,{b64}) format('truetype')}}")


def fetch(url):
    # a plain user agent gets TrueType files from the CSS API
    req = urllib.request.Request(url, headers={"User-Agent": "python-urllib"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


css = [face(f, (FONTS / file).read_bytes(), w) for f, file, w in FACES]
for family in GOOGLE:
    sheet = fetch("https://fonts.googleapis.com/css2?family=" + family.replace(" ", "+")).decode("utf-8")
    url = re.search(r"src:\s*url\((https://[^)]+)\)", sheet).group(1)
    css.append(face(family, fetch(url), "400"))
    print("embedded", family)
page = (HERE / "template.html").read_text(encoding="utf-8").replace("/*FONTS*/", "\n".join(css))
out = HERE.parent / "readability_v1.html"
out.write_text(page, encoding="utf-8")
print("wrote", out, f"({out.stat().st_size // 1024} KB)")
