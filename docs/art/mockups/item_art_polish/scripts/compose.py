import sys, pathlib
from PIL import Image
R = pathlib.Path(r"C:/dev/projects/NC-item-art"); OUT = R / "docs/art/mockups/item_art_polish/src"
BEFORE = pathlib.Path(sys.argv[1])
WALL = (31, 59, 58, 255); CREAM = (243, 233, 210, 255)
belt = Image.open(R / "art/scenery/belt_top.png").convert("RGBA")
bfront = Image.open(R / "art/scenery/basket_front.png").convert("RGBA")
bback = Image.open(R / "art/scenery/basket_back_left.png").convert("RGBA")
card = Image.open(R / "art/frames/reward_card.png").convert("RGBA")
def x2(im): return im.resize((im.width * 2, im.height * 2), Image.NEAREST)
def nine(src, w, h, l, r, t, b):
    out = Image.new("RGBA", (w, h))
    sw, sh = src.size
    xs = [(0, l, 0, l), (l, sw - r, l, w - r), (sw - r, sw, w - r, w)]
    ys = [(0, t, 0, t), (t, sh - b, t, h - b), (sh - b, sh, h - b, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out
def strip(item):
    big = x2(item); pad = 12
    # 1x: flying into the paper bag (ItemView.SPRITE_SIZE x PaperBag.ITEM_SCALE 0.5)
    one = Image.new("RGBA", (72, 200), WALL); one.alpha_composite(item, (12, 76))
    # card: a REWARDS card face (120x168, CardView size) with the item at 2x
    c = Image.new("RGBA", (136, 200), WALL); c.alpha_composite(nine(card, 120, 168, 4, 4, 34, 6), (8, 16))
    c.alpha_composite(big, (8 + 12, 16 + 168 - 6 - 96 - 10))
    # belt: the item at 2x standing on the belt top
    b = Image.new("RGBA", (150, 200), WALL); b.alpha_composite(belt.crop((70, 0, 220, 86)), (0, 200 - 86))
    b.alpha_composite(big, (27, 200 - 86 + 44 - 96))
    # basket slot: 2x, sunk behind the hand basket's front
    k = Image.new("RGBA", (216, 200), WALL); k.alpha_composite(bback, (0, 200 - 88 - 18))
    k.alpha_composite(big, (60, 200 - 88 - 96 + 34)); k.alpha_composite(bfront, (0, 200 - 88))
    w = sum(i.width for i in (one, c, b, k)) + pad * 3
    s = Image.new("RGBA", (w, 200), (0, 0, 0, 0)); x = 0
    for i in (one, c, b, k): s.alpha_composite(i, (x, 0)); x += i.width + pad
    return s
def zoom(item, f=6):
    z = Image.new("RGBA", item.size, CREAM); z.alpha_composite(item); return z.resize((item.width * f, item.height * f), Image.NEAREST)
for n in ["crisps", "crisps_big", "crisps_golden", "lemon", "lemon_big", "lemon_golden", "banana", "banana_big", "banana_golden"]:
    for tag, im in (("before", Image.open(BEFORE / f"items_v2_{n}.png")), ("after", Image.open(R / f"art/items_v2/{n}.png"))):
        im = im.convert("RGBA")
        strip(im).save(OUT / f"{n}_{tag}_views.png"); zoom(im).save(OUT / f"{n}_{tag}_x6.png")
        im.save(OUT / f"{n}_{tag}.png")
print("ok")
