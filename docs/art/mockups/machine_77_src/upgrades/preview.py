"""Writes preview.png: plain / BIG / GOLDEN per item at 6x on cream and teal (review sheet)."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[4] / "tools"))
import pixel_art as pa
pal = pa.parse_palette(HERE / "src" / "palette.txt")
S = int(sys.argv[1]) if len(sys.argv) > 1 else 6
items = ["banana", "milk", "eggs", "coffee"]
tiers = ["", "_big", "_golden"]
cell = 48 * S + 16
sheet = pa.blank(cell * 6, cell * 4, pal.colours["c"])
for j, it in enumerate(items):
    for i, t in enumerate(tiers):
        sp, err = pa.parse_sprite(HERE / "src" / "items_v2" / f"{it}{t}.txt", HERE / "src")
        assert sp, err
        g = pa.scale_grid([[pal.colours[k] for k in r] for r in sp.rows], S)
        for b, bg in enumerate(["c", "2"]):
            x = (b * 3 + i) * cell
            pa.paste(sheet, pa.blank(cell, cell, pal.colours[bg]), x, j * cell)
            pa.paste(sheet, g, x + 8, j * cell + 8)
(HERE / "preview.png").write_bytes(pa.encode_rgba(sheet))
print("ok")
