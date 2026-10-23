"""Builds ../cart_reveal_v1.html from template.html with the game's fonts embedded (standard library only)."""
import base64
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
FONTS = HERE.parents[3] / "fonts"
FACES = [
    ("Pixelify", "PixelifySans-Variable.ttf", "400 700"),
    ("Atkinson", "AtkinsonHyperlegibleNext-Variable.ttf", "200 800"),
    ("JetBrains", "JetBrainsMono-Regular.ttf", "400"),
]

css = []
for family, file, weight in FACES:
    data = base64.b64encode((FONTS / file).read_bytes()).decode("ascii")
    css.append(
        f"@font-face{{font-family:'{family}';font-weight:{weight};font-display:block;"
        f"src:url(data:font/ttf;base64,{data}) format('truetype')}}"
    )
page = (HERE / "template.html").read_text(encoding="utf-8").replace("/*FONTS*/", "\n".join(css))
out = HERE.parent / "cart_reveal_v1.html"
out.write_text(page, encoding="utf-8")
print("wrote", out)
