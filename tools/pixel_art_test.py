"""Tests for tools/pixel_art.py, on synthetic sources in temporary folders, plus a check that the
committed art is up to date. Run from the repo root:

    python tools/pixel_art_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import contextlib
import io
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_art as pa  # noqa: E402

PALETTE = """; test palette
. transparent
# 2b2420 ink
c f3e9d2 cream
4 4f9a94 teal
R d9534f tomato
"""

# A 4x3 frame: no outline rule outside items.
FRAME = """@size 4x3
@kind frame
#cc#
c44c
#RR#
"""


def item_source(rows: list[str]) -> str:
    return "@size 32x32\n@kind item\n" + "\n".join(rows) + "\n"


def boxed_item(fill: str = "c") -> list[str]:
    """A 32x32 item: an ink-outlined 10x10 box at the bottom."""
    rows = ["." * 32 for _ in range(22)]
    rows.append("." * 11 + "#" * 10 + "." * 11)
    rows.extend("." * 11 + "#" + fill * 8 + "#" + "." * 11 for _ in range(8))
    rows.append("." * 11 + "#" * 10 + "." * 11)
    return rows


class Workspace:
    """A temporary art/src + art pair."""

    def __init__(self, root: Path) -> None:
        self.src = root / "art" / "src"
        self.out = root / "art"
        self.src.mkdir(parents=True)
        (self.src / pa.PALETTE_FILE).write_text(PALETTE, encoding="utf-8")

    def add(self, name: str, text: str) -> Path:
        path = self.src / f"{name}.txt"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def load(self) -> pa.Project:
        return pa.load_project(self.src, self.out)


class TempTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.ws = Workspace(self.root)

    def tearDown(self) -> None:
        self._tmp.cleanup()


class PaletteTest(TempTestCase):
    def test_transparent_is_index_zero_and_colours_parse(self) -> None:
        path = self.root / "p.txt"
        path.write_text("# 2b2420 ink\n. transparent\nc #f3e9d2 cream\n", encoding="utf-8")
        palette = pa.parse_palette(path)
        self.assertEqual(palette.keys, [".", "#", "c"])
        self.assertEqual(palette.colours["c"], (0xF3, 0xE9, 0xD2, 255))
        self.assertEqual(palette.colours["."], (0, 0, 0, 0))

    def test_rejects_bad_palettes(self) -> None:
        cases = {
            "duplicate": ". t\n# 2b2420 ink\n# 000000 again\n",
            "no transparent": "# 2b2420 ink\n",
            "no ink": ". t\nc f3e9d2 cream\n",
            "bad hex": ". t\n# 2b24 ink\n",
            "long key": ". t\n# 2b2420 ink\nab 000000 x\n",
            "directive key": ". t\n# 2b2420 ink\n@ 000000 x\n",
        }
        for label, text in cases.items():
            with self.subTest(label):
                path = self.root / "bad.txt"
                path.write_text(text, encoding="utf-8")
                with self.assertRaises(pa.ArtError):
                    pa.parse_palette(path)


class SourceTest(TempTestCase):
    def test_frame_parses_with_comments_and_scale(self) -> None:
        self.ws.add("frames/f", "; a comment\n@size 4x3\n@kind frame\n@scale 2\n\n#cc#\nc44c\n#RR#\n")
        project = self.ws.load()
        self.assertEqual(project.errors, [])
        (sprite,) = project.sprites
        self.assertEqual((sprite.name, sprite.width, sprite.height, sprite.scale),
                         ("frames/f", 4, 3, 2))
        self.assertEqual(len(sprite.pixels(project.palette)), 6)

    def test_format_errors(self) -> None:
        cases = {
            "missing size": ("@kind frame\n#c\n", "missing @size"),
            "missing kind": ("@size 2x1\n#c\n", "missing @kind"),
            "unknown kind": ("@size 2x1\n@kind hat\n#c\n", "unknown @kind"),
            "unknown directive": ("@size 2x1\n@kind frame\n@mirror x\n#c\n", "unknown directive"),
            "bad scale": ("@size 2x1\n@kind frame\n@scale 0\n#c\n", "@scale takes"),
            "row count": ("@size 2x2\n@kind frame\n#c\n", "has 1"),
            "row width": ("@size 2x1\n@kind frame\n#cc\n", "3 wide"),
            "late directive": ("@size 2x1\n@kind frame\n#c\n@scale 2\n", "come before"),
        }
        for label, (text, message) in cases.items():
            with self.subTest(label):
                self.ws.add("frames/bad", text)
                project = self.ws.load()
                self.assertEqual(project.sprites, [])
                self.assertTrue(any(message in e for e in project.errors), project.errors)


class LintTest(TempTestCase):
    def test_a_clean_item_passes(self) -> None:
        self.ws.add("items/box", item_source(boxed_item()))
        project = self.ws.load()
        self.assertEqual(project.errors, [])
        self.assertEqual(len(project.sprites), 1)

    def test_unknown_keys_are_reported_and_not_built(self) -> None:
        self.ws.add("items/box", item_source(boxed_item("Z")))
        project = self.ws.load()
        self.assertEqual(project.sprites, [])
        self.assertIn("items/box: keys not in the palette: Z", project.errors)

    def test_item_must_be_32x32(self) -> None:
        self.ws.add("items/small", "@size 3x3\n@kind item\n###\n#c#\n###\n")
        project = self.ws.load()
        self.assertTrue(any("an item is 32x32" in e for e in project.errors), project.errors)

    def test_outline_must_be_ink(self) -> None:
        rows = boxed_item()
        rows[25] = rows[25][:11] + "c" + rows[25][12:]
        self.ws.add("items/box", item_source(rows))
        project = self.ws.load()
        self.assertTrue(any("pixel (11, 25)" in e for e in project.errors), project.errors)

    def test_item_colour_cap(self) -> None:
        # Ink counts: ink plus 11 colours passes, ink plus 12 doesn't.
        keys = "abcdefghijkl"
        palette = ". t\n# 2b2420 ink\n" + "".join(f"{k} {i:02x}0000 c{i}\n"
                                                  for i, k in enumerate(keys))
        (self.ws.src / pa.PALETTE_FILE).write_text(palette, encoding="utf-8")
        for count, expected_error in ((11, False), (12, True)):
            with self.subTest(count):
                used = keys[:count]
                rows = boxed_item("a")
                rows[23] = "." * 11 + "#" + used[:8] + "#" + "." * 11
                rows[24] = "." * 11 + "#" + used[8:].ljust(8, "a") + "#" + "." * 11
                self.ws.add("items/box", item_source(rows))
                errors = self.ws.load().errors
                self.assertEqual(any("at most 12 colours, got 13" in e for e in errors),
                                 expected_error, errors)

    def test_item_is_drawn_at_scale_1(self) -> None:
        source = item_source(boxed_item()).replace("@kind item", "@kind item\n@scale 2")
        self.ws.add("items/box", source)
        errors = self.ws.load().errors
        self.assertTrue(any("drawn at @scale 1" in e for e in errors), errors)

    def test_item_top_rows_stay_empty(self) -> None:
        rows = boxed_item()
        rows[1] = "." * 15 + "#" + "." * 16
        self.ws.add("items/box", item_source(rows))
        errors = self.ws.load().errors
        self.assertTrue(any("row 1 must be transparent" in e for e in errors), errors)

    def test_other_kinds_skip_the_item_rules(self) -> None:
        self.ws.add("frames/f", FRAME)
        self.assertEqual(self.ws.load().errors, [])


class PngTest(TempTestCase):
    def test_indexed_round_trip(self) -> None:
        self.ws.add("frames/f", FRAME)
        project = self.ws.load()
        (sprite,) = project.sprites
        data = pa.encode_indexed(sprite, project.palette)
        self.assertEqual(pa.decode_png(data), sprite.pixels(project.palette))
        self.assertIn(b"PLTE", data)
        self.assertIn(b"tRNS", data)

    def test_scaled_round_trip(self) -> None:
        self.ws.add("frames/f", FRAME.replace("@kind frame", "@kind frame\n@scale 3"))
        project = self.ws.load()
        (sprite,) = project.sprites
        decoded = pa.decode_png(pa.encode_indexed(sprite, project.palette))
        self.assertEqual((len(decoded[0]), len(decoded)), (12, 9))
        self.assertEqual(decoded, sprite.pixels(project.palette))

    def test_rgba_round_trip(self) -> None:
        grid = [[(1, 2, 3, 255), (0, 0, 0, 0)], [(9, 8, 7, 128), (255, 255, 255, 255)]]
        self.assertEqual(pa.decode_png(pa.encode_rgba(grid)), grid)

    def test_decodes_every_filter_type(self) -> None:
        width, height = 3, 5
        rows = [bytes((x * 40 + y * 7) % 256 for x in range(width * 4)) for y in range(height)]
        raw = bytearray()
        previous = bytes(width * 4)
        for filter_type, row in enumerate(rows):
            raw.append(filter_type)
            raw.extend(_filter(filter_type, row, previous, 4))
            previous = row
        data = (pa.PNG_SIGNATURE
                + pa._chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + pa._chunk(b"IDAT", zlib.compress(bytes(raw)))
                + pa._chunk(b"IEND", b""))
        decoded = pa.decode_png(data)
        expected = [[tuple(row[x * 4:x * 4 + 4]) for x in range(width)] for row in rows]
        self.assertEqual(pa.normalised(decoded), pa.normalised(expected))

    def test_rejects_non_png(self) -> None:
        with self.assertRaises(pa.ArtError):
            pa.decode_png(b"GIF89a")

    def test_rejects_bad_crc_and_short_data(self) -> None:
        data = pa.encode_rgba([[(1, 2, 3, 255)] * 4] * 4)
        corrupt = bytearray(data)
        corrupt[data.index(b"IDAT") + 4] ^= 0xFF
        with self.assertRaises(pa.ArtError):
            pa.decode_png(bytes(corrupt))
        short = (pa.PNG_SIGNATURE
                 + pa._chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 6, 0, 0, 0))
                 + pa._chunk(b"IDAT", zlib.compress(bytes(5)))
                 + pa._chunk(b"IEND", b""))
        with self.assertRaises(pa.ArtError):
            pa.decode_png(short)


def _filter(filter_type: int, row: bytes, previous: bytes, bpp: int) -> bytes:
    out = bytearray()
    for i, value in enumerate(row):
        left = row[i - bpp] if i >= bpp else 0
        up = previous[i]
        up_left = previous[i - bpp] if i >= bpp else 0
        predictor = [0, left, up, (left + up) // 2, pa._paeth(left, up, up_left)][filter_type]
        out.append((value - predictor) & 0xFF)
    return bytes(out)


def _recompressed(data: bytes) -> bytes:
    """The same PNG with its image data compressed at another level (other bytes)."""
    start = data.index(b"IDAT") - 4
    length = struct.unpack(">I", data[start:start + 4])[0]
    raw = zlib.decompress(data[start + 8:start + 8 + length])
    return (data[:start] + pa._chunk(b"IDAT", zlib.compress(raw, 1))
            + pa._chunk(b"IEND", b""))


class BuildCheckTest(TempTestCase):
    def test_build_then_check_is_clean_and_build_is_idempotent(self) -> None:
        self.ws.add("frames/f", FRAME)
        project = self.ws.load()
        self.assertEqual([p.name for p in pa.build(project)], ["f.png"])
        self.assertTrue((self.ws.out / "frames" / "f.png").exists())
        self.assertEqual(pa.check(project), [])
        self.assertEqual(pa.build(project), [])

    def test_check_reports_missing_stale_and_orphans(self) -> None:
        self.ws.add("frames/f", FRAME)
        project = self.ws.load()
        self.assertTrue(any("is missing" in p for p in pa.check(project)))
        pa.build(project)
        self.ws.add("frames/f", FRAME.replace("c44c", "cRRc"))
        self.assertTrue(any("is stale" in p for p in pa.check(self.ws.load())))
        (self.ws.out / "frames" / "old.png").write_bytes(b"x")
        self.assertTrue(any("old.png has no source" in p for p in pa.check(self.ws.load())))

    def test_check_finds_orphans_in_folders_without_sources(self) -> None:
        self.ws.add("frames/f", FRAME)
        pa.build(self.ws.load())
        (self.ws.src / "frames" / "f.txt").unlink()
        (self.ws.out / "loose.png").write_bytes(b"x")
        problems = pa.check(self.ws.load())
        self.assertTrue(any("frames/f.png has no source" in p for p in problems), problems)
        self.assertTrue(any("loose.png has no source" in p for p in problems), problems)

    def test_a_source_with_errors_is_not_an_orphan(self) -> None:
        self.ws.add("frames/f", FRAME)
        pa.build(self.ws.load())
        self.ws.add("frames/f", FRAME.replace("c44c", "cZZc"))
        problems = pa.check(self.ws.load())
        self.assertTrue(any("not checked: its source has errors" in p for p in problems),
                        problems)
        self.assertFalse(any("has no source" in p for p in problems), problems)

    def test_build_compares_pixels_and_palette_not_bytes(self) -> None:
        self.ws.add("frames/f", FRAME)
        project = self.ws.load()
        pa.build(project)
        target = self.ws.out / "frames" / "f.png"
        (sprite,) = project.sprites
        # The same image compressed at another level: build leaves it alone.
        target.write_bytes(_recompressed(pa.encode_indexed(sprite, project.palette)))
        self.assertEqual(pa.build(project), [])
        # A palette change is stale even for a colour no pixel uses.
        unused = PALETTE.replace("R d9534f", "R 000001")
        self.ws.add("frames/f", FRAME.replace("#RR#", "####"))
        pa.build(self.ws.load())
        (self.ws.src / pa.PALETTE_FILE).write_text(unused, encoding="utf-8")
        self.assertTrue(any("is stale" in p for p in pa.check(self.ws.load())))

    def test_check_compares_pixels_and_palette_not_bytes(self) -> None:
        self.ws.add("frames/f", FRAME)
        project = self.ws.load()
        pa.build(project)
        target = self.ws.out / "frames" / "f.png"
        target.write_bytes(_recompressed(target.read_bytes()))
        self.assertEqual(pa.check(project), [])
        # The same pixels as RGBA have no palette: stale.
        (sprite,) = project.sprites
        target.write_bytes(pa.encode_rgba(sprite.pixels(project.palette)))
        self.assertTrue(any("is stale" in p for p in pa.check(project)))

    def test_sheet_writes_previews_and_contact_sheet(self) -> None:
        self.ws.add("frames/f", FRAME)
        self.ws.add("items/box", item_source(boxed_item()))
        reports = self.root / "reports"
        written = pa.write_sheets(self.ws.load(), reports)
        self.assertIn(reports / "preview" / "items__box.png", written)
        sheet = pa.decode_png((reports / "contact_sheet.png").read_bytes())
        self.assertGreater(len(sheet), 64)
        self.assertEqual((reports / "contact_sheet.txt").read_text(encoding="utf-8"),
                         "frames/f\nitems/box\n")
        preview = pa.decode_png((reports / "preview" / "frames__f.png").read_bytes())
        self.assertGreater(len(preview[0]), 4 * 8)

    def test_main_exit_codes(self) -> None:
        self.ws.add("frames/f", FRAME)
        args = ["--src", str(self.ws.src), "--out", str(self.ws.out),
                "--reports", str(self.root / "reports")]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(pa.main(["check", *args]), 1)
            self.assertEqual(pa.main(["build", *args]), 0)
            self.assertEqual(pa.main(["check", *args]), 0)
            self.assertEqual(pa.main(["sheet", *args]), 0)
            (self.ws.src / pa.PALETTE_FILE).write_text("# 2b2420 ink\n", encoding="utf-8")
            self.assertEqual(pa.main(["check", *args]), 2)


class CommittedArtTest(unittest.TestCase):
    def test_the_repo_art_is_clean_and_up_to_date(self) -> None:
        project = pa.load_project(pa.DEFAULT_SRC, pa.DEFAULT_OUT)
        self.assertEqual(pa.check(project), [])
        self.assertIn("items/milk", [s.name for s in project.sprites])


if __name__ == "__main__":
    unittest.main()
