"""Crops a region of a still and scales it up (nearest) for review: python zoom.py in.png out.png x y w h [k]."""
import sys
from PIL import Image
a = sys.argv
x, y, w, h = map(int, a[3:7]); k = int(a[7]) if len(a) > 7 else 2
im = Image.open(a[1]).crop((x, y, x + w, y + h))
im.resize((w * k, h * k), Image.NEAREST).save(a[2])
