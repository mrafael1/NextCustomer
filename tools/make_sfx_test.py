"""Tests for tools/make_sfx.py (#62): the generator writes every agreed sound and nothing else, is
deterministic, matches the committed files in audio/sfx/, writes mono 16-bit 44100 Hz files whose
peaks are their GAINS entries, and tunes every note of the count-up's ladder within 25 cents. Run
from the repo root:

    python tools/make_sfx_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import cmath
import math
import os
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sfx  # noqa: E402

COMMITTED = Path(__file__).resolve().parent.parent / "audio" / "sfx"

# The sound names the game's Sfx relies on (#62's contract between the generator and the game).
ROUND_ROBIN = {"stamp": 3, "card_place": 4, "card_pickup": 3, "card_return": 2, "ui_click": 3,
               "coin": 3}
SINGLE = ["scan", "print", "tick", "stamp_paid", "stamp_loyalty", "stamp_notice", "rattle_s",
          "rattle_m", "rattle_l", "register_bell", "ding", "tag", "link", "copy", "fizzle",
          "denied", "total", "miss", "pass", "fail", "rip", "armed", "slot_tick", "shuffle", "fan",
          "checkout", "ui_open", "ui_close", "ui_back", "ui_confirm", "ui_switch"]
LADDER = ["G4", "A4", "C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6"]
FIXED_NAMES = sorted(
    SINGLE + ["%s_%d" % (base, take) for base, count in ROUND_ROBIN.items()
              for take in range(1, count + 1)]
    + ["bonus_%02d" % i for i in range(len(LADDER))])


def read_wav(path: Path) -> tuple[tuple[int, int, int], list[float]]:
    """Returns ((channels, sample width, rate), samples as fractions of full scale)."""
    with wave.open(str(path), "rb") as w:
        params = (w.getnchannels(), w.getsampwidth(), w.getframerate())
        frames = w.readframes(w.getnframes())
    count = len(frames) // 2
    return params, [s / 32767 for s in struct.unpack("<%dh" % count, frames)]


def level(samples: list[float], freq: float, rate: int = make_sfx.RATE) -> float:
    """The magnitude of the signal's Hann-windowed spectrum at `freq` (one DFT bin at any
    frequency)."""
    n = len(samples)
    step = cmath.exp(-2j * math.pi * freq / rate)
    phasor = 1 + 0j
    acc = 0j
    for i, s in enumerate(samples):
        acc += s * (0.5 - 0.5 * math.cos(2 * math.pi * i / n)) * phasor
        phasor *= step
    return abs(acc)


def strongest_cents(samples: list[float], freq: float, rate: int = make_sfx.RATE) -> float:
    """Where the strongest partial within a semitone of `freq` sits, in cents from `freq`."""
    def at(cents: float) -> float:
        return level(samples, freq * 2 ** (cents / 1200), rate)

    best = max(range(-100, 101, 5), key=at)
    return max((best + c / 2 for c in range(-10, 11)), key=at)


class GeneratedSoundsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temp = tempfile.TemporaryDirectory()
        cls.out = Path(cls._temp.name)
        make_sfx.main([f"--out={cls.out}"])
        cls.sounds = {p.stem: read_wav(p) for p in cls.out.glob("*.wav")}

    @classmethod
    def tearDownClass(cls) -> None:
        cls._temp.cleanup()

    def test_writes_every_agreed_sound_and_nothing_else(self) -> None:
        self.assertEqual(sorted(self.sounds), FIXED_NAMES)
        self.assertEqual(sorted(make_sfx.GAINS), FIXED_NAMES)

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
        self.assertEqual(sorted(self.sounds), sorted(p.stem for p in COMMITTED.glob("*.wav")))
        for name, (params, fresh) in self.sounds.items():
            committed_params, committed = read_wav(COMMITTED / (name + ".wav"))
            self.assertEqual(params, committed_params, name)
            self.assertEqual(len(fresh), len(committed), name)
            worst = max(abs(a - b) for a, b in zip(fresh, committed))
            self.assertLessEqual(worst, 1.5 / 32767, name)

    def test_every_sound_is_mono_44100_hz_16_bit(self) -> None:
        self.assertEqual(make_sfx.RATE, 44100)
        for name, (params, _) in self.sounds.items():
            self.assertEqual(params, (1, 2, 44100), name)

    def test_peaks_match_gains_with_headroom(self) -> None:
        for name, (_, samples) in self.sounds.items():
            self.assertAlmostEqual(max(abs(s) for s in samples), make_sfx.GAINS[name],
                                   delta=0.6 / 32767, msg=name)
            self.assertLessEqual(make_sfx.GAINS[name], 0.95, name)

    def test_ladder_peaks_rise_from_0_40_to_0_52(self) -> None:
        peaks = [make_sfx.GAINS["bonus_%02d" % i] for i in range(len(LADDER))]
        self.assertAlmostEqual(peaks[0], 0.40)
        self.assertAlmostEqual(peaks[-1], 0.52)
        self.assertEqual(peaks, sorted(set(peaks)))

    def test_every_sound_starts_and_ends_silent_without_dc(self) -> None:
        for name, (_, samples) in self.sounds.items():
            self.assertEqual(samples[0], 0.0, name)
            self.assertLessEqual(abs(samples[-1]), 1 / 32767, name)
            self.assertLess(abs(sum(samples) / len(samples)), 0.005, name)

    def test_each_ladder_note_is_its_pitch_within_25_cents(self) -> None:
        for i, note in enumerate(LADDER):
            _, samples = self.sounds["bonus_%02d" % i]
            body = samples[int(0.01 * make_sfx.RATE):int(0.21 * make_sfx.RATE)]
            cents = strongest_cents(body, make_sfx.note_hz(note))
            self.assertLessEqual(abs(cents), 25, "%s is %+.1f cents" % (note, cents))

    def test_ladder_notes_ring_about_0_9_s_with_a_soft_start(self) -> None:
        for i in range(len(LADDER)):
            name = "bonus_%02d" % i
            _, samples = self.sounds[name]
            self.assertEqual(len(samples), int(round(0.9 * make_sfx.RATE)))
            # The 2 ms fade-in: the first millisecond stays under half the peak.
            self.assertLess(max(abs(s) for s in samples[:44]), 0.5 * make_sfx.GAINS[name])

    def test_scan_is_a_c7_beep_and_ding_a_c6_bell(self) -> None:
        for name, note in (("scan", "C7"), ("ding", "C6")):
            _, samples = self.sounds[name]
            body = samples[int(0.005 * make_sfx.RATE):int(0.105 * make_sfx.RATE)]
            cents = strongest_cents(body, make_sfx.note_hz(note))
            self.assertLessEqual(abs(cents), 25, "%s is %+.1f cents" % (name, cents))


class PipelineTest(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.folder = Path(self._temp.name)

    def tearDown(self) -> None:
        self._temp.cleanup()

    def _write(self, name: str, rate: int, bits: int, frames: list[tuple[int, ...]],
               extensible: bool = False) -> str:
        channels = len(frames[0])
        width = bits // 8
        data = b"".join(v.to_bytes(width, "little", signed=True) for f in frames for v in f)
        if extensible:
            guid_tail = b"\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"
            fmt = struct.pack("<HHIIHHHHIH", 0xFFFE, channels, rate, rate * channels * width,
                              channels * width, bits, 22, bits, 0, 1) + guid_tail
        else:
            fmt = struct.pack("<HHIIHH", 1, channels, rate, rate * channels * width,
                              channels * width, bits)
        body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
        body += b"LIST" + struct.pack("<I", 3) + b"abc\x00"  # an odd-sized chunk to skip
        body += b"data" + struct.pack("<I", len(data)) + data
        path = str(self.folder / name)
        with open(path, "wb") as f:
            f.write(b"RIFF" + struct.pack("<I", len(body)) + body)
        return path

    def test_reads_16_bit_mono(self) -> None:
        path = self._write("a.wav", 22050, 16, [(0,), (16384,), (-32768,)])
        self.assertEqual(make_sfx.read_wav(path), (22050, [0.0, 0.5, -1.0]))

    def test_reads_24_bit_stereo_and_folds_it_to_mono(self) -> None:
        frames = [(4194304, 0), (-8388608, -8388608), (8388607, -8388607)]
        for extensible in (False, True):
            path = self._write("b.wav", 48000, 24, frames, extensible)
            rate, samples = make_sfx.read_wav(path)
            self.assertEqual(rate, 48000)
            self.assertEqual(len(samples), 3)
            for got, want in zip(samples, (0.25, -1.0, 0.0)):
                self.assertAlmostEqual(got, want, places=6)

    def test_rejects_other_formats(self) -> None:
        path = self._write("c.wav", 44100, 16, [(0,)])
        with open(path, "r+b") as f:  # Rewrite the format tag as IEEE float.
            f.seek(20)
            f.write(struct.pack("<H", 3))
        with self.assertRaises(ValueError):
            make_sfx.read_wav(path)

    def test_resampler_shifts_pitch_by_the_requested_semitones(self) -> None:
        rate = make_sfx.RATE
        sine = [math.sin(2 * math.pi * 440.0 * i / rate) for i in range(rate // 5)]
        for semitones in (-3.0, 2.0, 3.0):
            out = make_sfx.resample(sine, 2 ** (semitones / 12))
            self.assertAlmostEqual(len(out), len(sine) / 2 ** (semitones / 12), delta=1.0)
            body = out[len(out) // 4:3 * len(out) // 4]
            cents = strongest_cents(body, 440.0 * 2 ** (semitones / 12))
            self.assertLessEqual(abs(cents), 2.0, semitones)
            # Lanczos keeps the level: within 0.1 dB away from the edges.
            self.assertAlmostEqual(max(abs(s) for s in body), 1.0, delta=0.012)

    def test_resampler_converts_48_khz_to_44_1_khz(self) -> None:
        sine = [math.sin(2 * math.pi * 1000.0 * i / 48000) for i in range(9600)]
        out = make_sfx.resample(sine, 48000 / make_sfx.RATE)
        body = out[len(out) // 4:3 * len(out) // 4]
        self.assertLessEqual(abs(strongest_cents(body, 1000.0)), 2.0)

    def test_resampler_filters_what_would_alias(self) -> None:
        # A 20 kHz tone read 1.5x faster would fold down to 14.1 kHz; the narrowed kernel removes
        # it instead.
        sine = [math.sin(2 * math.pi * 20000.0 * i / make_sfx.RATE) for i in range(8820)]
        out = make_sfx.resample(sine, 1.5)
        body = out[len(out) // 4:3 * len(out) // 4]
        self.assertLess(max(abs(s) for s in body), 0.05)

    def test_mix_scales_each_layer_to_its_peak(self) -> None:
        loud = [0.0, 0.8, -0.4]
        quiet = [0.01, -0.02]
        mixed = make_sfx.mix((loud, 0.0, 0.0), (quiet, 0.0, -6.0))
        self.assertAlmostEqual(mixed[1], 1.0 - 10 ** (-6 / 20))

    def test_note_names_are_equal_tempered(self) -> None:
        self.assertAlmostEqual(make_sfx.note_hz("A4"), 440.0)
        self.assertAlmostEqual(make_sfx.note_hz("C7"), 2093.0045, places=3)
        self.assertAlmostEqual(make_sfx.note_hz("G4"), 391.9954, places=3)

    def test_rejects_unknown_arguments(self) -> None:
        with self.assertRaises(SystemExit):
            make_sfx.main(["--bogus"])
        self.assertFalse(os.listdir(self.folder))


if __name__ == "__main__":
    unittest.main()
