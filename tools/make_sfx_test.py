"""Tests for tools/make_sfx.py: the generator is deterministic, the committed sounds in audio/sfx/
are up to date, and the count-up's `bonus` note and `ding` bell have the agreed shape (#60, D1
and D5). Run from the repo root:

    python tools/make_sfx_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import cmath
import math
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sfx  # noqa: E402

COMMITTED = Path(__file__).resolve().parent.parent / "audio" / "sfx"


def read_wav(path: Path) -> tuple[tuple[int, int, int], list[float]]:
    """Returns ((channels, sample width, rate), samples as fractions of full scale)."""
    with wave.open(str(path), "rb") as w:
        params = (w.getnchannels(), w.getsampwidth(), w.getframerate())
        frames = w.readframes(w.getnframes())
    count = len(frames) // 2
    return params, [s / 32767 for s in struct.unpack("<%dh" % count, frames)]


def level(samples: list[float], freq: float) -> float:
    """The magnitude of the signal's spectrum at `freq` (one DFT bin at any frequency)."""
    step = -2j * math.pi * freq / make_sfx.RATE
    return abs(sum(s * cmath.exp(step * i) for i, s in enumerate(samples)))


def db(ratio: float) -> float:
    return 20 * math.log10(ratio)


class GeneratedSoundsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temp = tempfile.TemporaryDirectory()
        cls.out = Path(cls._temp.name)
        make_sfx.main([f"--out={cls.out}"])

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temp.cleanup()

    def test_same_code_writes_the_same_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as again:
            make_sfx.main([f"--out={again}"])
            names = sorted(p.name for p in self.out.glob("*.wav"))
            self.assertEqual(names, sorted(p.name for p in Path(again).glob("*.wav")))
            for name in names:
                self.assertEqual((self.out / name).read_bytes(), (Path(again) / name).read_bytes(),
                                 name)

    def test_committed_sounds_are_up_to_date(self) -> None:
        # Within one step of 16-bit rounding, in case another platform's math library differs in
        # the last bit. Re-run tools/make_sfx.py (and sh tools/import.sh) if this fails.
        generated = sorted(p.name for p in self.out.glob("*.wav"))
        self.assertEqual(generated, sorted(p.name for p in COMMITTED.glob("*.wav")))
        for name in generated:
            params, fresh = read_wav(self.out / name)
            committed_params, committed = read_wav(COMMITTED / name)
            self.assertEqual(params, committed_params, name)
            self.assertEqual(len(fresh), len(committed), name)
            worst = max(abs(a - b) for a, b in zip(fresh, committed))
            self.assertLessEqual(worst, 1.5 / 32767, name)

    def test_every_sound_is_mono_22050_hz_16_bit(self) -> None:
        for path in self.out.glob("*.wav"):
            params, _ = read_wav(path)
            self.assertEqual(params, (1, 2, make_sfx.RATE), path.name)

    def test_bonus_is_a_steady_g5_with_soft_harmonics(self) -> None:
        _, samples = read_wav(self.out / "bonus.wav")
        self.assertEqual(len(samples), int(make_sfx.RATE * 0.22))
        self.assertAlmostEqual(max(abs(s) for s in samples), 0.40, delta=0.001)
        self._assert_short_attack(samples)
        fundamental = level(samples, 783.99)
        # G5 itself, not a semitone either side.
        self.assertGreater(fundamental, 4 * level(samples, 783.99 * 2 ** (1 / 12)))
        self.assertGreater(fundamental, 4 * level(samples, 783.99 * 2 ** (-1 / 12)))
        self.assertAlmostEqual(db(level(samples, 2 * 783.99) / fundamental), -12.0, delta=1.0)
        self.assertAlmostEqual(db(level(samples, 3 * 783.99) / fundamental), -20.0, delta=1.0)
        # No pitch glide: the second half is still G5.
        tail = samples[len(samples) // 2:]
        self.assertGreater(level(tail, 783.99), 4 * level(tail, 783.99 * 2 ** (1 / 12)))
        # Decays: the last 20 ms are much quieter than the first.
        self.assertLess(self._peak(samples, -0.02), 0.1 * self._peak(samples, 0.02))

    def test_ding_is_a_c6_bell(self) -> None:
        _, samples = read_wav(self.out / "ding.wav")
        self.assertAlmostEqual(max(abs(s) for s in samples), 0.50, delta=0.001)
        self._assert_short_attack(samples)
        fundamental = level(samples, 1046.5)
        self.assertGreater(fundamental, 4 * level(samples, 1046.5 * 2 ** (1 / 12)))
        self.assertAlmostEqual(db(level(samples, 2093.0) / fundamental), -10.0, delta=1.0)
        # Still ringing after 300 ms, gone by the end.
        at_300_ms = int(0.3 * make_sfx.RATE)
        self.assertGreater(max(abs(s) for s in samples[at_300_ms:at_300_ms + 200]), 0.1)
        self.assertLess(self._peak(samples, -0.02), 0.05)

    def _assert_short_attack(self, samples: list[float]) -> None:
        self.assertEqual(samples[0], 0.0)
        loudest = max(range(len(samples)), key=lambda i: abs(samples[i]))
        self.assertLess(loudest, int(0.012 * make_sfx.RATE))

    @staticmethod
    def _peak(samples: list[float], seconds: float) -> float:
        """The peak of the first (seconds > 0) or last (seconds < 0) stretch of the sound."""
        n = int(abs(seconds) * make_sfx.RATE)
        part = samples[:n] if seconds > 0 else samples[-n:]
        return max(abs(s) for s in part)


if __name__ == "__main__":
    unittest.main()
