"""Trims the empty page background off the bottom of a section still (needs Pillow; skipped without it)."""
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit(0)
for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    bg = im.getpixel((im.width - 1, im.height - 1))
    y = im.height - 1
    while y > 0 and all(im.getpixel((x, y)) == bg for x in range(0, im.width, 4)):
        y -= 1
    im.crop((0, 0, im.width, min(im.height, y + 16))).save(path)
