"""Writes v3_planning_fg.png: v2_planning.png's pixels where it differs from v3_planning_empty.png
(the same shift with nothing on the belt), transparent elsewhere, so a moving crop of an item,
its stickers or its ticket carries none of the wall or belt behind it. Only the belt and ticket
rail band (y 230 to 520) is kept."""
import pathlib
from PIL import Image, ImageChops, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
full = Image.open(HERE / "v2_planning.png").convert("RGB")
empty = Image.open(HERE / "v3_planning_empty.png").convert("RGB")
diff = ImageChops.difference(full, empty).convert("L").point(lambda v: 255 if v > 18 else 0)
mask = diff.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))  # close pin holes
band = Image.new("L", full.size, 0)
band.paste(255, (0, 230, 1280, 520))
mask = ImageChops.multiply(mask, band)
out = full.convert("RGBA")
out.putalpha(mask)
out.save(HERE / "v3_planning_fg.png", optimize=True)
print("v3_planning_fg.png written")
