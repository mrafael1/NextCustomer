"""Writes docs/art/mockups/machine_77_eggs_banana_before_after.png: Banana and Eggs, plain / BIG / GOLDEN,
round 1 (the game's current art) against round 2 (redraw_r2.py), at 1x, 2x and 4x, on the belt's rubber
and on paper. Needs Pillow (labels only); the sprites come from png/items_v2/."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PNG = HERE / "png" / "items_v2"
OUT = HERE.parents[1] / "machine_77_eggs_banana_before_after.png"
BELT, PAPER, INK, CREAM = (0x3D, 0x3A, 0x36), (0xFB, 0xF7, 0xEE), (0x2B, 0x24, 0x20), (0xF3, 0xE9, 0xD2)
TIERS = [("", "plain"), ("_big", "BIG"), ("_golden", "GOLDEN")]
ROWS = [("banana", "_r1", "Banana, round 1"), ("banana", "", "Banana, round 2"),
        ("eggs", "_r1", "Eggs, round 1"), ("eggs", "", "Eggs, round 2")]
PAD, LABEL_W, HEAD = 10, 150, 34
PANEL_W = PAD + 48 + PAD + 96 + PAD + 192 + PAD          # 1x, 2x, 4x side by side
PANEL_H = 192 + 2 * PAD


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    f, fs = font(18), font(14)
    width = LABEL_W + len(TIERS) * 2 * (PANEL_W + 4)
    height = HEAD + 22 + len(ROWS) * (PANEL_H + 6)
    sheet = Image.new("RGB", (width, height), CREAM)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 8), "Eggs and Banana: round 1 (now) vs round 2 (redraw). 1x, 2x, 4x on the belt and on paper.",
           fill=INK, font=f)
    for t, (_, tname) in enumerate(TIERS):
        for b, bname in enumerate(("belt", "paper")):
            x = LABEL_W + (t * 2 + b) * (PANEL_W + 4)
            d.text((x + PAD, HEAD + 2), f"{tname} on {bname}", fill=INK, font=fs)
    for r, (item, ver, label) in enumerate(ROWS):
        y = HEAD + 22 + r * (PANEL_H + 6)
        d.text((PAD, y + PANEL_H // 2 - 10), label, fill=INK, font=fs)
        for t, (suffix, _) in enumerate(TIERS):
            sprite = Image.open(PNG / f"{item}{suffix}{ver}.png").convert("RGBA")
            for b, bg in enumerate((BELT, PAPER)):
                x = LABEL_W + (t * 2 + b) * (PANEL_W + 4)
                d.rectangle([x, y, x + PANEL_W - 1, y + PANEL_H - 1], fill=bg)
                cx = x + PAD
                for s in (1, 2, 4):
                    im = sprite.resize((48 * s, 48 * s), Image.NEAREST)
                    sheet.paste(im, (cx, y + PAD + 192 - 48 * s), im)
                    cx += 48 * s + PAD
    sheet.save(OUT)
    print("wrote", OUT, sheet.size)


if __name__ == "__main__":
    main()
