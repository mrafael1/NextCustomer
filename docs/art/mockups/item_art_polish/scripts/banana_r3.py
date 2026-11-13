"""Banana round 3: renders the current banana and the three round-3 tops (banana_r3/*.txt).

Builds the sources with tools/pixel_art.py (palette, lint, GOLDEN derive), then writes the same
previews as compose.py (x6 zoom on cream, and the in-game views: 1x bag, card, belt, basket) to
src/banana_r3/, plus a 1x/2x comparison sheet (compare.png).

    python docs/art/mockups/item_art_polish/scripts/banana_r3_draw.py
    python docs/art/mockups/item_art_polish/scripts/banana_r3.py
"""
import shutil, sys, tempfile
from pathlib import Path
from PIL import Image

R = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parents[1]
SRC = HERE / "banana_r3"
OUT = HERE / "src/banana_r3"
sys.path.insert(0, str(R / "tools"))
import pixel_art as pa  # noqa: E402

WALL = (31, 59, 58, 255); CREAM = (243, 233, 210, 255)
belt = Image.open(R / "art/scenery/belt_top.png").convert("RGBA")
bfront = Image.open(R / "art/scenery/basket_front.png").convert("RGBA")
bback = Image.open(R / "art/scenery/basket_back_left.png").convert("RGBA")
card = Image.open(R / "art/frames/reward_card.png").convert("RGBA")


def x2(im): return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def nine(src, w, h, l, r, t, b):
    out = Image.new("RGBA", (w, h)); sw, sh = src.size
    xs = [(0, l, 0, l), (l, sw - r, l, w - r), (sw - r, sw, w - r, w)]
    ys = [(0, t, 0, t), (t, sh - b, t, h - b), (sh - b, sh, h - b, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def strip(item):  # same views as compose.py
    big = x2(item); pad = 12
    one = Image.new("RGBA", (72, 200), WALL); one.alpha_composite(item, (12, 76))
    c = Image.new("RGBA", (136, 200), WALL); c.alpha_composite(nine(card, 120, 168, 4, 4, 34, 6), (8, 16))
    c.alpha_composite(big, (8 + 12, 16 + 168 - 6 - 96 - 10))
    b = Image.new("RGBA", (150, 200), WALL); b.alpha_composite(belt.crop((70, 0, 220, 86)), (0, 200 - 86))
    b.alpha_composite(big, (27, 200 - 86 + 44 - 96))
    k = Image.new("RGBA", (216, 200), WALL); k.alpha_composite(bback, (0, 200 - 88 - 18))
    k.alpha_composite(big, (60, 200 - 88 - 96 + 34)); k.alpha_composite(bfront, (0, 200 - 88))
    w = sum(i.width for i in (one, c, b, k)) + pad * 3
    s = Image.new("RGBA", (w, 200), (0, 0, 0, 0)); x = 0
    for i in (one, c, b, k): s.alpha_composite(i, (x, 0)); x += i.width + pad
    return s


def zoom(item, f=6):
    z = Image.new("RGBA", item.size, CREAM); z.alpha_composite(item)
    return z.resize((item.width * f, item.height * f), Image.NEAREST)


def to_image(sprite, palette):
    px = sprite.pixels(palette)
    im = Image.new("RGBA", (len(px[0]), len(px)))
    im.putdata([c for row in px for c in row])
    return im


def main():
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp); (t / "items_v2").mkdir()
        shutil.copy(R / "art/src/palette.txt", t / "palette.txt")
        for n in ("banana", "banana_big", "banana_golden"):
            shutil.copy(R / f"art/src/items_v2/{n}.txt", t / f"items_v2/{n.replace('banana', 'banana_cur')}.txt")
        (t / "items_v2/banana_cur_golden.txt").write_text("@derive banana_cur_big golden=yellow\n")
        for p in SRC.glob("*.txt"):
            shutil.copy(p, t / "items_v2" / p.name)
        proj = pa.load_project(t, t / "out")
        if proj.errors:
            print("LINT: " + "\n".join(proj.errors))
        ims = {s.name.split("/")[-1]: to_image(s, proj.palette) for s in proj.sprites}
        # a sprite that fails the lint is still drawn (so it can be looked at), never silently kept stale
        for path in sorted((t / "items_v2").glob("*.txt")):
            name = path.stem
            if name in ims:
                continue
            sp, _ = pa.parse_source(path, t)
            if isinstance(sp, pa.Derivation):
                base, _ = pa.parse_source(t / "items_v2" / f"{sp.base}.txt", t)
                sp = pa.derive_sprite(sp, base, proj.palette)
            ims[name] = to_image(sp, proj.palette)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, im in ims.items():
        im.save(OUT / f"{name}.png"); zoom(im).save(OUT / f"{name}_x6.png"); strip(im).save(OUT / f"{name}_views.png")
    # comparison sheet: rows plain/big/golden, columns cur v1 v2 v3; 1x then 2x on the wall colour
    cols = ["cur", "v1", "v2", "v3"]; tiers = ["", "_big", "_golden"]
    sheet = Image.new("RGBA", (len(cols) * 160, len(tiers) * 112), WALL)
    for j, tier in enumerate(tiers):
        for i, c in enumerate(cols):
            im = ims.get(f"banana_{c}{tier}")
            if im is None: continue
            sheet.alpha_composite(im, (i * 160 + 4, j * 112 + 30)); sheet.alpha_composite(x2(im), (i * 160 + 58, j * 112 + 8))
    sheet.save(OUT / "compare.png")
    print("ok", len(ims))


if __name__ == "__main__":
    main()
