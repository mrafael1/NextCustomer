"""Tests for tools/belt_art.py (the belt's perspective top face), plus a check that the committed
source is the script's output. Run from the repo root:

    python tools/belt_art_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import belt_art as ba  # noqa: E402
import pixel_art as pa  # noqa: E402


def column(x: int) -> int:
    """The art column of stage x."""
    return (x - ba.ORIGIN[0]) // ba.SCALE


def row_of(y: int) -> int:
    """The art row of stage y."""
    return (y - ba.ORIGIN[1]) // ba.SCALE


class GeometryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rows = ba.generate()

    def test_the_grid_covers_the_belt_down_to_the_lip(self) -> None:
        self.assertEqual(len(self.rows), ba.HEIGHT)
        self.assertEqual(ba.HEIGHT * ba.SCALE, ba.FRONT_Y - ba.ORIGIN[1])
        self.assertEqual(ba.WIDTH * ba.SCALE, ba.WIDTH_PX)
        for row in self.rows:
            self.assertEqual(len(row), ba.WIDTH)
            self.assertLessEqual(set(row), ba.KEYS)

    def test_the_keys_are_in_the_palette(self) -> None:
        palette = pa.parse_palette(pa.DEFAULT_SRC / pa.PALETTE_FILE)
        for key in ba.KEYS:
            palette.index(key)

    def test_recede_meets_the_front_line_and_the_vanishing_point(self) -> None:
        self.assertAlmostEqual(ba.recede(100, ba.FRONT_Y), 100)
        self.assertAlmostEqual(ba.recede(100, ba.VANISHING_POINT[1]), ba.VANISHING_POINT[0])
        # Left of the middle an edge leans right going back, right of it left.
        self.assertGreater(ba.recede(16, 330), 16)
        self.assertLess(ba.recede(930, 330), 930)
        self.assertEqual(ba.snap(3.0), 4)
        self.assertEqual(ba.snap(2.9), 2)

    def test_the_outer_ink_follows_the_receding_edges(self) -> None:
        # Every frame row (under the guard): ink just outside the snapped edges, the frame's
        # steel just inside them, transparent past the ink.
        for y in range(ba.HOOD_FRONT[0], ba.FRONT_Y, ba.SCALE):
            row = self.rows[row_of(y)]
            left, right = ba.edges(ba.FRAME_LEFT, ba.FRAME_RIGHT, y)
            self.assertEqual(row[column(left - ba.SCALE)], ba.INK, y)
            self.assertEqual(row[column(right)], ba.INK, y)
            self.assertNotIn(row[column(left)], (ba.TRANSPARENT, ba.INK), y)
            self.assertTrue(set(row[: column(left - ba.SCALE)]) <= {ba.TRANSPARENT}, y)
            self.assertTrue(set(row[column(right) + 1 :]) <= {ba.TRANSPARENT}, y)
        # The front row spans the whole belt; the back is narrower on both sides.
        front = self.rows[-1]
        self.assertEqual(front[0], ba.INK)
        self.assertEqual(front[-1], ba.INK)
        self.assertGreater(self.rows[row_of(ba.HOOD_FRONT[0])].index(ba.INK), 0)

    def test_the_slats_lean_to_the_vanishing_point(self) -> None:
        front_y = ba.FRONT_Y - ba.SCALE
        back_y = ba.HOOD_SHADOW[1]
        for front_x in (ba.SLAT_START, ba.SLAT_START + 30 * ba.SLAT_PITCH, 898):
            for y in (front_y, back_y):
                x = ba.snap(ba.recede(front_x, y + ba.SCALE / 2))
                row = self.rows[row_of(y)]
                self.assertEqual(row[column(x)], ba.CHARCOAL, (front_x, y))
                self.assertEqual(row[column(x) + 1], ba.STEEL_DARKEST, (front_x, y))
        # Rubber between the slats, darker at the back.
        self.assertIn(ba.RUBBER_DARK, self.rows[row_of(ba.HOOD_SHADOW[1])])
        self.assertIn(ba.RUBBER, self.rows[-1])
        self.assertNotIn(ba.RUBBER_DARK, self.rows[-1])

    def test_the_guard_and_its_end_caps(self) -> None:
        # The guard's top ink row, its face bands, its foot line and its shadow on the hood.
        middle = column(640)
        bands = [self.rows[row_of(y)][middle] for y in range(ba.CAP_TOP, ba.HOOD_FRONT[0], 2)]
        self.assertEqual(bands[0], ba.INK)
        faces = [ba.guard_key(y) for y in range(ba.GUARD_TOP, ba.GUARD_FOOT, ba.SCALE)]
        self.assertEqual(bands[1:7], faces)
        self.assertEqual(bands[7], ba.INK)
        self.assertEqual(bands[8], ba.STEEL_DARKEST)
        # The caps stand one row proud of the guard, at both ends.
        top = self.rows[0]
        inked = [index for index, key in enumerate(top) if key == ba.INK]
        self.assertEqual(len(inked), 2 * ba.CAP_WIDTH // ba.SCALE)
        self.assertLess(max(inked[: len(inked) // 2]), middle)
        self.assertGreater(min(inked[len(inked) // 2 :]), middle)
        self.assertNotIn(ba.INK, top[inked[0] + ba.CAP_WIDTH : inked[-1] - ba.CAP_WIDTH])


class CommittedSourceTest(unittest.TestCase):
    def test_the_committed_source_is_up_to_date(self) -> None:
        self.assertTrue(ba.OUTPUT.exists())
        self.assertEqual(ba.OUTPUT.read_text(encoding="utf-8"), ba.source_text())
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(ba.main(["--check"]), 0)

    def test_the_source_parses_and_lints(self) -> None:
        palette = pa.parse_palette(pa.DEFAULT_SRC / pa.PALETTE_FILE)
        sprite, errors = pa.parse_sprite(ba.OUTPUT, pa.DEFAULT_SRC)
        self.assertEqual(errors, [])
        assert sprite is not None
        self.assertEqual(pa.lint_sprite(sprite, palette), [])

    def test_check_fails_on_a_stale_source(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "belt_top.txt"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(ba.main(["--out", str(out)]), 0)
            self.assertEqual(out.read_text(encoding="utf-8"), ba.source_text())
            out.write_text("stale\n", encoding="utf-8")
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(ba.main(["--check", "--out", str(out)]), 1)


if __name__ == "__main__":
    unittest.main()
