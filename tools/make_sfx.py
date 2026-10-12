"""Builds every sound effect in audio/sfx/ (#62) from the CC0 source excerpts in audio/src/, plus
two synthesised sounds (the scan beep and the fizzle). Standard-library Python and
deterministic: the same code and sources write the same bytes. Re-run after changing a sound or a
source excerpt, then re-import (sh tools/import.sh):

    python tools/make_sfx.py [--out=<folder>]

--out writes the sounds to another folder instead of audio/sfx/ (the tests use it).

Every output is mono, 44100 Hz, 16-bit, and is normalised so its peak is exactly its GAINS entry.
The pipeline per sound: read the source WAV (16- or 24-bit PCM, mono or stereo, any rate), fold
it to mono, cut it, convert its rate and pitch with a windowed-sinc (Lanczos, a=8) resampler, filter
it (biquads), layer it with other sources, shape it with fades, then normalise it.

Pitch is baked in here, not set at play time: the count-up's note ladder is eleven files,
bonus_00 (G4) to bonus_10 (G6), the C major pentatonic G4 A4 C5 D5 E5 G5 A5 C6 D6 E6 G6, each made
from the nearest VCSL xylophone sample at most 3 semitones away. Round-robin sets are numbered
takes (stamp_1..3, card_place_1..4, ...) that Sfx cycles in a fixed order.

audio/src/README.md lists every source, its licence and how the excerpts were cut.
"""

from __future__ import annotations

import math
import os
import random
import struct
import sys
import wave

RATE = 44100
TOOLS = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(TOOLS, "..", "audio", "src")
OUT = os.path.join(TOOLS, "..", "audio", "sfx")

# The note ladder (Sfx.play_note): (sounding note, VCSL file, semitones from the file's note).
# VCSL's xylophone, glockenspiel, marimba and hand chime files sound one octave above their names
# (measured: Xylo_Soft_G3 sounds G4, glock_soft_C5 sounds C6), so Soft_G3 is the G4 anchor.
# The timbre brightens up the ladder: soft mallets pp, then soft ff, then medium mallets ff.
LADDER = [
    ("G4", "Xylo_Soft_G3_pp_01_far", 0),
    ("A4", "Xylo_Soft_G3_pp_01_far", 2),
    ("C5", "Xylo_Soft_C4_pp_01_far", 0),
    ("D5", "Xylo_Soft_C4_pp_01_far", 2),
    ("E5", "Xylo_Soft_G4_pp_01_far", -3),
    ("G5", "Xylo_Soft_G4_ff_01_far", 0),
    ("A5", "Xylo_Soft_G4_ff_01_far", 2),
    ("C6", "Xylo_Soft_C5_ff_01_far", 0),
    ("D6", "Xylo_Medium_C5_ff_01_far", 2),
    ("E6", "Xylo_Medium_G5_ff_01_far", -3),
    ("G6", "Xylo_Medium_G5_ff_01_far", 0),
]
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# How sharp each pitched VCSL excerpt sounds against equal temperament at A4 = 440 Hz, in cents
# (measured from the strongest partial near its sounding note). src() removes it, so every note
# lands in tune with the synthesised C7 scan beep.
TUNING_CENTS = {
    "vcsl/Xylo_Soft_G3_pp_01_far.wav": 13.0,
    "vcsl/Xylo_Soft_C4_pp_01_far.wav": 12.0,
    "vcsl/Xylo_Soft_G4_pp_01_far.wav": 13.5,
    "vcsl/Xylo_Soft_C4_ff_01_far.wav": 12.0,
    "vcsl/Xylo_Soft_G4_ff_01_far.wav": 13.5,
    "vcsl/Xylo_Soft_C5_ff_01_far.wav": 15.5,
    "vcsl/Xylo_Soft_G5_ff_01_far.wav": 16.0,
    "vcsl/Xylo_Medium_C4_ff_01_far.wav": 12.0,
    "vcsl/Xylo_Medium_G4_ff_01_far.wav": 13.5,
    "vcsl/Xylo_Medium_C5_ff_01_far.wav": 15.5,
    "vcsl/Xylo_Medium_G5_ff_01_far.wav": 16.0,
    "vcsl/glock_soft_C5_02.wav": 12.0,
    "vcsl/glock_soft_G5_01.wav": 12.0,
    "vcsl/sus_C5_r01_main.wav": 1.0,
    "vcsl/Marimba_hit_Outrigger_G4_soft_01.wav": -2.0,
    "vcsl/Marimba_hit_Outrigger_C4_soft_01.wav": 4.5,
}

# Peak level of each sound relative to full scale, set on purpose so the mix is balanced and
# leaves headroom: a skipped count plays many of these close together, so nothing goes above
# 0.95. The stamps and the verdict hit hardest, the per-card scan and notes sit in the middle,
# and small details (ticks, UI) stay underneath. The ladder's peak rises with its pitch.
GAINS = {
    "scan": 0.45, "print": 0.5, "tick": 0.3,
    "stamp_1": 0.9, "stamp_2": 0.9, "stamp_3": 0.9, "stamp_paid": 0.95, "stamp_loyalty": 0.85,
    "stamp_notice": 0.6,
    "rattle_s": 0.5, "rattle_m": 0.65, "rattle_l": 0.8, "register_bell": 0.7,
    "ding": 0.55, "tag": 0.5, "link": 0.45, "copy": 0.45, "fizzle": 0.4, "denied": 0.5,
    "total": 0.85, "miss": 0.6, "pass": 0.7, "fail": 0.55, "rip": 0.65, "armed": 0.3,
    "card_place_1": 0.5, "card_place_2": 0.5, "card_place_3": 0.5, "card_place_4": 0.5,
    "card_pickup_1": 0.4, "card_pickup_2": 0.4, "card_pickup_3": 0.4,
    "card_return_1": 0.35, "card_return_2": 0.35, "slot_tick": 0.25,
    "shuffle": 0.45, "fan": 0.45, "checkout": 0.6,
    "ui_click_1": 0.35, "ui_click_2": 0.35, "ui_click_3": 0.35,
    "ui_open": 0.3, "ui_close": 0.3, "ui_back": 0.3, "ui_confirm": 0.35, "ui_switch": 0.3,
    "coin_1": 0.55, "coin_2": 0.55, "coin_3": 0.55,
}
for _i in range(len(LADDER)):
    GAINS["bonus_%02d" % _i] = round(0.40 + 0.12 * _i / (len(LADDER) - 1), 3)


def note_hz(name: str) -> float:
    """The equal-tempered frequency of a note name such as "G4" or "C#6" (A4 = 440 Hz)."""
    octave = int(name[-1])
    midi = 12 * (octave + 1) + NOTE_NAMES.index(name[:-1])
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- Reading --------------------------------------------------------------------------------


def read_wav(path: str) -> tuple[int, list[float]]:
    """Reads a 16- or 24-bit PCM WAV (plain or WAVE_FORMAT_EXTENSIBLE, any channel count) and
    returns (rate, samples) with the channels averaged to mono, as fractions of full scale."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("%s: not a RIFF WAVE file" % path)
    fmt = None
    frames = None
    pos = 12
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        size = struct.unpack_from("<I", data, pos + 4)[0]
        body = data[pos + 8:pos + 8 + size]
        if tag == b"fmt ":
            fmt = body
        elif tag == b"data":
            frames = body
        pos += 8 + size + (size & 1)
    if fmt is None or frames is None:
        raise ValueError("%s: missing fmt or data chunk" % path)
    format_tag, channels, rate = struct.unpack_from("<HHI", fmt, 0)
    bits = struct.unpack_from("<H", fmt, 14)[0]
    if format_tag == 0xFFFE:  # WAVE_FORMAT_EXTENSIBLE: the sub-format GUID starts with the tag.
        format_tag = struct.unpack_from("<H", fmt, 24)[0]
    if format_tag != 1 or bits not in (16, 24):
        raise ValueError("%s: only 16- or 24-bit PCM is supported" % path)
    width = bits // 8
    count = len(frames) // width
    if width == 2:
        values = struct.unpack("<%dh" % count, frames[:count * 2])
        scale = 1.0 / 32768
    else:
        padded = bytearray(count * 4)
        padded[1::4] = frames[0:count * 3:3]
        padded[2::4] = frames[1:count * 3:3]
        padded[3::4] = frames[2:count * 3:3]
        values = struct.unpack("<%di" % count, bytes(padded))  # 24-bit value << 8, sign kept
        scale = 1.0 / 2147483648
    frame_count = count // channels
    if channels == 1:
        return rate, [v * scale for v in values[:frame_count]]
    fold = scale / channels
    return rate, [sum(values[i * channels:(i + 1) * channels]) * fold for i in range(frame_count)]


# --- Resampling and filters -----------------------------------------------------------------


def resample(x: list[float], step: float, lobes: int = 8) -> list[float]:
    """Reads `x` at positions 0, step, 2*step, ... with a Lanczos windowed-sinc kernel of `lobes`
    lobes. step > 1 (higher pitch or a lower output rate) also narrows the kernel's pass band to
    1/step so nothing aliases. The sines are advanced by rotation, which keeps it fast and exact
    to rounding."""
    cut = min(1.0, 1.0 / step)
    half = int(math.ceil(lobes / cut))
    padded = [0.0] * half + x + [0.0] * (half + 1)
    count = int((len(x) - 1) / step) + 1
    pc = math.pi * cut
    pca = pc / lobes
    c1, s1_step = math.cos(pc), math.sin(pc)
    c2, s2_step = math.cos(pca), math.sin(pca)
    norm = lobes / (pc * pc)
    out = [0.0] * count
    for j in range(count):
        t = j * step
        base = int(t)
        first = base - half + 1  # source index of the first tap
        d = t - first
        s1, k1 = math.sin(pc * d), math.cos(pc * d)
        s2, k2 = math.sin(pca * d), math.cos(pca * d)
        acc = 0.0
        index = first + half
        for _ in range(2 * half):
            if -1e-9 < d < 1e-9:
                acc += padded[index] * cut
            elif d * cut < lobes and d * cut > -lobes:
                acc += padded[index] * (s1 * s2 * norm / (d * d)) * cut
            s1, k1 = s1 * c1 - k1 * s1_step, k1 * c1 + s1 * s1_step
            s2, k2 = s2 * c2 - k2 * s2_step, k2 * c2 + s2 * s2_step
            d -= 1.0
            index += 1
        out[j] = acc
    return out


def biquad(x: list[float], kind: str, freq: float, q: float = 0.7071,
           gain_db: float = 0.0) -> list[float]:
    """One RBJ-cookbook biquad: "lowpass", "highpass", "bandpass" or "lowshelf"."""
    w0 = 2 * math.pi * freq / RATE
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2 * q)
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bandpass":
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "lowshelf":
        amp = 10 ** (gain_db / 40)
        root = 2 * math.sqrt(amp) * alpha
        b = [amp * ((amp + 1) - (amp - 1) * cw + root), 2 * amp * ((amp - 1) - (amp + 1) * cw),
             amp * ((amp + 1) - (amp - 1) * cw - root)]
        a = [(amp + 1) + (amp - 1) * cw + root, -2 * ((amp - 1) + (amp + 1) * cw),
             (amp + 1) + (amp - 1) * cw - root]
    else:
        raise ValueError(kind)
    b0, b1, b2 = (v / a[0] for v in b)
    a1, a2 = a[1] / a[0], a[2] / a[0]
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out[i] = y
    return out


def highpass(x: list[float], freq: float) -> list[float]:
    return biquad(x, "highpass", freq)


def lowpass(x: list[float], freq: float) -> list[float]:
    return biquad(x, "lowpass", freq)


# --- Shaping and layering -------------------------------------------------------------------


def src(name: str, semitones: float = 0.0, start: float = 0.0, length: float | None = None,
        speed: float = 1.0) -> list[float]:
    """A source excerpt (path under audio/src/) as mono at RATE: cut to `start`/`length` seconds
    of the source, shifted by `semitones` (and its TUNING_CENTS removed), sped up by `speed`, and
    with DC and sub-bass rumble under 25 Hz removed."""
    rate, x = read_wav(os.path.join(SRC, *name.split("/")))
    a = int(round(start * rate))
    b = len(x) if length is None else min(len(x), a + int(round(length * rate)))
    x = x[a:b]
    shift = semitones - TUNING_CENTS.get(name, 0.0) / 100
    step = rate / RATE * 2 ** (shift / 12) * speed
    if abs(step - 1.0) > 1e-12:
        x = resample(x, step)
    return highpass(x, 25.0)


def onset(x: list[float], level: float = 0.2) -> int:
    """The first sample that reaches `level` of the sound's peak."""
    peak = max(abs(v) for v in x)
    for i, v in enumerate(x):
        if abs(v) >= level * peak:
            return i
    return 0


def from_onset(x: list[float], before: float = 0.002, level: float = 0.2) -> list[float]:
    """Drops what comes more than `before` seconds ahead of the onset."""
    return x[max(0, onset(x, level) - int(before * RATE)):]


def cut(x: list[float], length: float) -> list[float]:
    return x[:int(round(length * RATE))]


def normalised(x: list[float]) -> list[float]:
    """The sound scaled so its peak is 1."""
    peak = max(1e-12, max(abs(v) for v in x))
    return [v / peak for v in x]


def fade_in(x: list[float], seconds: float) -> list[float]:
    """A raised-cosine fade from silence over the first `seconds`."""
    n = min(len(x), max(1, int(seconds * RATE)))
    out = list(x)
    for i in range(n):
        out[i] *= math.sin(0.5 * math.pi * i / n) ** 2
    return out


def fade_out(x: list[float], seconds: float) -> list[float]:
    """A raised-cosine fade to silence over the last `seconds`; the last sample is 0."""
    n = min(len(x), max(1, int(seconds * RATE)))
    out = list(x)
    for i in range(n):
        out[len(x) - 1 - i] *= math.sin(0.5 * math.pi * i / n) ** 2
    return out


def tail(x: list[float], start: float, length: float, floor_db: float = -40.0) -> list[float]:
    """Cuts the sound to `length` seconds and fades it exponentially from `start` seconds, so it
    reaches `floor_db` at the end (a natural ring-out), then closes with a 10 ms fade."""
    x = cut(x, length)
    a = int(start * RATE)
    span = max(1, len(x) - a)
    k = math.log(10 ** (floor_db / 20)) / span
    out = list(x)
    for i in range(a, len(x)):
        out[i] *= math.exp(k * (i - a))
    return fade_out(out, 0.01)


def mix(*layers: tuple[list[float], float, float]) -> list[float]:
    """Sums (samples, offset in seconds, gain in dB) layers. Each layer is first scaled to a peak
    of 1, so a layer at -6 dB peaks 6 dB under a layer at 0 dB, whatever the source levels."""
    placed = [(int(round(offset * RATE)), 10 ** (db / 20), normalised(x))
              for x, offset, db in layers]
    out = [0.0] * max(at + len(x) for at, _, x in placed)
    for at, g, x in placed:
        for i, v in enumerate(x):
            out[at + i] += v * g
    return out


def align(x: list[float]) -> list[float]:
    """Starts the sound 1 ms before its onset, so layered transients line up."""
    return from_onset(x, before=0.001)


def finish(x: list[float], fade_in_s: float = 0.001, fade_out_s: float = 0.004) -> list[float]:
    """Every sound ends here: no DC, a clean start and a clean end (no clicks)."""
    x = highpass(x, 20.0)
    return fade_out(fade_in(x, fade_in_s), fade_out_s)


# --- Synthesis ------------------------------------------------------------------------------


def swell(t: float, attack: float, decay: float) -> float:
    """An envelope: a raised-cosine rise over `attack` seconds, then an exponential decay with
    time constant `decay` seconds."""
    if t < attack:
        return math.sin(0.5 * math.pi * t / attack) ** 2
    return math.exp(-(t - attack) / decay)


def scan() -> list[float]:
    """The scanner beep: a soft sine at C7 (above the ladder, so it never masks a note) with a
    -18 dB 2nd partial, a 4 ms attack and a short exponential decay, plus a 3 ms band-passed
    noise "laser tick" at -20 dB."""
    f = note_hz("C7")
    n = int(0.12 * RATE)
    second = 10 ** (-18 / 20)
    tone = []
    for i in range(n):
        t = i / RATE
        partials = math.sin(2 * math.pi * f * t) + second * math.sin(4 * math.pi * f * t)
        tone.append(swell(t, 0.004, 0.03) * partials)
    rng = random.Random(62)
    m = int(0.003 * RATE)
    tick = [rng.uniform(-1.0, 1.0) * math.sin(math.pi * i / m) ** 2 for i in range(m)]
    tick = biquad(tick + [0.0] * m, "bandpass", 3000.0, q=1.5)
    return finish(mix((tone, 0.0, 0.0), (normalised(tick), 0.0, -20.0)), fade_out_s=0.02)


def fizzle() -> list[float]:
    """A soft deflating "pfff": low-passed noise that swells and dies, under a quiet sine glide
    from G5 down to C5."""
    n = int(0.38 * RATE)
    rng = random.Random(7)
    noise = []
    for i in range(n):
        t = i / RATE
        noise.append(rng.uniform(-1.0, 1.0) * swell(t, 0.03, 0.11))
    noise = lowpass(lowpass(noise, 1400.0), 1400.0)
    hi, lo = note_hz("G5"), note_hz("C5")
    glide = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * hi * (lo / hi) ** min(1.0, t / 0.3) / RATE
        glide.append(math.sin(phase) * swell(t, 0.01, 0.12))
    return finish(mix((noise, 0.0, 0.0), (glide, 0.0, -14.0)), fade_out_s=0.06)


# --- Recipes --------------------------------------------------------------------------------


def bonus(index: int) -> list[float]:
    """Ladder note `index`: about 0.9 s, a 2 ms fade-in, ringing at full level for 0.35 s, then an
    exponential fade, so the last note of a row rings into the pause."""
    _, sample, semitones = LADDER[index]
    x = from_onset(src("vcsl/%s.wav" % sample, semitones), before=0.001)
    return finish(tail(x, 0.35, 0.9), fade_in_s=0.002)


def stamp(take: int) -> list[float]:
    """The multiplier stamp: a rubber stamp on paper over a soft heavy thump (a different thump per
    take, and a slightly different pitch), with a low shelf for weight."""
    paper = align(src("freesound/470710_rubber_stamp.wav", (0.0, -0.3, 0.3)[take - 1]))
    thump = align(src("kenney/impactSoft_heavy_%03d.wav" % (take - 1)))
    x = biquad(mix((paper, 0.0, 0.0), (thump, 0.0, -6.0)), "lowshelf", 120.0, gain_db=3.0)
    # Sub-bass under 50 Hz adds nothing on laptop speakers but eats the peak.
    return finish(fade_out(cut(highpass(x, 50.0), 0.28), 0.06))


def stamp_paid() -> list[float]:
    """The PAID stamp: the rubber stamp two semitones lower, a heavy punch and a cash-drawer
    "ka-chunk" under it; heavier than the multiplier stamp."""
    paper = align(src("freesound/470710_rubber_stamp.wav", -2.0))
    punch = align(src("kenney/impactPunch_heavy_000.wav"))
    chunk = align(src("freesound/452572_drawer_slam.wav"))
    x = mix((paper, 0.0, 0.0), (punch, 0.0, -4.0), (chunk, 0.0, -10.0))
    x = highpass(biquad(x, "lowshelf", 120.0, gain_db=4.0), 45.0)
    return finish(fade_out(cut(x, 0.4), 0.1))


def stamp_loyalty() -> list[float]:
    """The loyalty stamp: the rubber stamp two semitones higher with a soft C6 glockenspiel
    "points added" ping at -9 dB that rings out by 0.6 s."""
    paper = fade_out(cut(align(src("freesound/470710_rubber_stamp.wav", 2.0)), 0.25), 0.06)
    glock = tail(align(src("vcsl/glock_soft_C5_02.wav")), 0.1, 0.58)
    return finish(mix((paper, 0.0, 0.0), (glock, 0.02, -9.0)))


def stamp_notice() -> list[float]:
    """The inspection notice: a light self-inking clerk's stamp (click, hit and spring), dry."""
    x = highpass(src("freesound/448474_self_inking_stamp.wav"), 60.0)
    return finish(fade_out(cut(from_onset(x, 0.005, 0.05), 0.35), 0.05))


def rattle(name: str, length: float, fade: float) -> list[float]:
    """A cash-drawer and coin-tray rattle cut from the antique register recording (no bell)."""
    x = highpass(src("freesound/452572_rattle_%s.wav" % name), 60.0)
    return finish(fade_out(cut(from_onset(x, 0.003), length), fade), fade_in_s=0.002)


def register_bell() -> list[float]:
    """The register's "cha-ching" bell, one clean ring moved down 1.6 semitones from A6-39c to
    G6 so it sits in key with the ladder."""
    shift = 12 * math.log2(note_hz("G6") / 1720.6)
    x = highpass(align(src("freesound/452572_bell.wav", shift)), 200.0)
    return finish(tail(x, 0.3, 0.9))


def ding() -> list[float]:
    """Quota reached: a soft C6 glockenspiel with a C6 hand chime under it for warmth and the
    first 40 ms of a desk bell for the "service bell" read; rings out by 1.2 s."""
    glock = align(src("vcsl/glock_soft_C5_02.wav"))
    chime = align(src("vcsl/sus_C5_r01_main.wav"))
    bell = fade_out(cut(align(src("freesound/221515_desk_bell.wav")), 0.04), 0.015)
    return finish(tail(mix((glock, 0.0, 0.0), (chime, 0.0, -6.0), (bell, 0.0, -12.0)), 0.4, 1.2))


def tag() -> list[float]:
    """A sticker tag lands: a card tap with a soft G6 glockenspiel ping 12 dB under it."""
    tap = fade_out(cut(align(src("freesound/564128_card_tap.wav")), 0.06), 0.02)
    ping = tail(align(src("vcsl/glock_soft_G5_01.wav")), 0.06, 0.3)
    return finish(mix((tap, 0.0, 0.0), (ping, 0.01, -12.0)))


def link() -> list[float]:
    """A Bundle link: a quick glockenspiel rise from C6 to G6, 60 ms apart."""
    low = tail(align(src("vcsl/glock_soft_C5_02.wav")), 0.08, 0.35)
    high = tail(align(src("vcsl/glock_soft_G5_01.wav")), 0.08, 0.35)
    return finish(mix((low, 0.0, -1.0), (high, 0.06, 0.0)))


def copy() -> list[float]:
    """A COPY bonus flies: a card swish two semitones up for a "photocopy" brightness."""
    x = highpass(src("kenney/card-slide-3.wav", 2.0), 200.0)
    return finish(fade_out(cut(from_onset(x, 0.002), 0.16), 0.05))


def denied() -> list[float]:
    """A value set to 0, or a refused placement: Kenney's two-pluck error, one semitone up so its
    notes sit on E and G, low-passed to keep it soft."""
    x = lowpass(src("kenney/error_001.wav", 1.0), 3500.0)
    return finish(x, fade_out_s=0.02)


def total() -> list[float]:
    """The verdict slam on a pass: a medium-mallet xylophone C major chord (C5 E5 G5 C6) struck
    together over a heavy punch at -6 dB."""
    c5 = align(src("vcsl/Xylo_Medium_C4_ff_01_far.wav"))
    e5 = align(src("vcsl/Xylo_Medium_G4_ff_01_far.wav", -3.0))
    g5 = align(src("vcsl/Xylo_Medium_G4_ff_01_far.wav"))
    c6 = align(src("vcsl/Xylo_Medium_C5_ff_01_far.wav"))
    punch = align(src("kenney/impactPunch_heavy_001.wav"))
    x = mix((c5, 0.0, 0.0), (e5, 0.0, -2.0), (g5, 0.0, -2.0), (c6, 0.0, -1.0), (punch, 0.0, -6.0))
    return finish(tail(x, 0.4, 1.1))


def miss() -> list[float]:
    """The verdict slam on a fail: a dull paper thud with a soft marimba A4 at -8 dB (deflating,
    not punishing)."""
    thud = align(highpass(src("kenney/impactSoft_medium_002.wav"), 60.0))
    a4 = align(src("vcsl/Marimba_hit_Outrigger_C4_soft_01.wav", -3.0))
    return finish(tail(mix((thud, 0.0, 0.0), (a4, 0.0, -8.0)), 0.15, 0.5))


def pass_() -> list[float]:
    """Shift passed: a soft-mallet xylophone run C5 E5 G5 C6 E6, 80 ms apart, the last note ringing
    0.8 s, with a bell-tree stroke 10 dB under it as the sparkle."""
    notes = [("Xylo_Soft_C4_ff_01_far", 0.0, -3.0), ("Xylo_Soft_G4_ff_01_far", -3.0, -2.5),
             ("Xylo_Soft_G4_ff_01_far", 0.0, -2.0), ("Xylo_Soft_C5_ff_01_far", 0.0, -1.0),
             ("Xylo_Soft_G5_ff_01_far", -3.0, 0.0)]
    layers = []
    for k, (sample, semitones, db) in enumerate(notes):
        x = align(src("vcsl/%s.wav" % sample, semitones))
        ring = 0.8 if k == len(notes) - 1 else 0.45
        layers.append((tail(x, 0.1, ring), 0.08 * k, db))
    sparkle = tail(highpass(align(src("vcsl/BellTree_Stroke_3_Mid.wav")), 2000.0), 0.4, 1.1)
    layers.append((fade_in(sparkle, 0.05), 0.0, -10.0))
    return finish(mix(*layers))


def fail() -> list[float]:
    """Shift failed: a slow, polite soft-marimba descent E5 D5 A4, 180 ms apart, ending on A (the
    relative minor) for a gentle "aww"."""
    e5 = align(src("vcsl/Marimba_hit_Outrigger_G4_soft_01.wav", -3.0))
    d5 = align(src("vcsl/Marimba_hit_Outrigger_C4_soft_01.wav", 2.0))
    a4 = align(src("vcsl/Marimba_hit_Outrigger_C4_soft_01.wav", -3.0))
    x = mix((tail(e5, 0.15, 0.6), 0.0, 0.0), (tail(d5, 0.15, 0.6), 0.18, -1.0),
            (a4, 0.36, -0.5))
    return finish(tail(x, 0.7, 1.2))


def rip() -> list[float]:
    """The receipt tear: a perforated paper tear, played 1.15x faster for snap and high-passed."""
    x = highpass(src("freesound/451644_perforated_tear.wav", speed=1.15), 200.0)
    return finish(fade_out(cut(from_onset(x, 0.002), 0.36), 0.08), fade_in_s=0.002)


def armed() -> list[float]:
    """An armed effect glows: a short high-passed bell-tree shimmer (played with the ladder
    note)."""
    x = highpass(align(src("vcsl/BellTree_Hit_E5_rr1_Mid.wav")), 1500.0)
    return finish(tail(x, 0.04, 0.15), fade_in_s=0.002)


def card(name: str, length: float, fade: float, before: float = 0.003,
         level: float = 0.1) -> list[float]:
    """A card handling sound from Kenney's casino pack, cut from `before` seconds ahead of the
    first sample reaching `level` of its peak."""
    x = highpass(src("kenney/%s.wav" % name), 40.0)
    return finish(fade_out(cut(from_onset(x, before, level), length), fade), fade_in_s=0.003)


def checkout() -> list[float]:
    """The checkout key: a light metal key clack, then a drawer "chunk" 25 ms later."""
    clack = align(src("kenney/impactMetal_light_001.wav"))
    chunk = align(highpass(src("freesound/452572_drawer_chunk.wav"), 60.0))
    return finish(fade_out(cut(mix((clack, 0.0, 0.0), (chunk, 0.025, -4.0)), 0.2), 0.05))


def ui(name: str, length: float | None = None, fade: float = 0.004,
       low_cut: float = 0.0) -> list[float]:
    """An interface sound from Kenney's interface pack, softened above 9 kHz (and high-passed at
    `low_cut` Hz when set)."""
    x = lowpass(src("kenney/%s.wav" % name), 9000.0)
    if low_cut:
        x = highpass(x, low_cut)
    if length is not None:
        x = cut(x, length)
    return finish(x, fade_out_s=fade)


def coin(take: int) -> list[float]:
    """A single coin dropping into a bowl; take k is raised 2*(k-1) semitones, so the coins of the
    final receipt climb in key."""
    x = highpass(src("freesound/367273_coin_%d.wav" % take, 2.0 * (take - 1)), 300.0)
    return finish(fade_out(cut(from_onset(x, 0.002), 0.25), 0.06))


def recipes() -> dict:
    """Every sound by name, as a function that builds it."""
    out = {"scan": scan, "fizzle": fizzle}
    for i in range(len(LADDER)):
        out["bonus_%02d" % i] = lambda i=i: bonus(i)
    out["print"] = lambda: finish(
        fade_out(cut(highpass(src("freesound/210094_receipt_printer.wav"), 150.0), 0.2), 0.005),
        fade_in_s=0.005)
    out["tick"] = lambda: ui("tick_001", 0.025, 0.006)
    for take in (1, 2, 3):
        out["stamp_%d" % take] = lambda take=take: stamp(take)
    out.update({"stamp_paid": stamp_paid, "stamp_loyalty": stamp_loyalty,
                "stamp_notice": stamp_notice})
    out["rattle_s"] = lambda: rattle("s", 0.18, 0.06)
    out["rattle_m"] = lambda: rattle("m", 0.3, 0.1)
    out["rattle_l"] = lambda: rattle("l", 0.5, 0.15)
    out.update({"register_bell": register_bell, "ding": ding, "tag": tag, "link": link,
                "copy": copy, "denied": denied, "total": total, "miss": miss, "pass": pass_,
                "fail": fail, "rip": rip, "armed": armed, "checkout": checkout})
    for take in (1, 2, 3, 4):
        # Cut from just before the loudest slap, so the click or drop lands at once.
        out["card_place_%d" % take] = lambda take=take: card(
            "card-place-%d" % take, 0.22, 0.06, before=0.02, level=0.5)
    for take, name in enumerate(("card-slide-1", "card-slide-2", "card-slide-5"), 1):
        out["card_pickup_%d" % take] = lambda name=name: card(name, 0.12, 0.04)
    for take in (1, 2):
        out["card_return_%d" % take] = lambda take=take: card("card-shove-%d" % take, 0.15, 0.05)
    out["slot_tick"] = lambda: ui("tick_004", 0.05, 0.01)
    out["shuffle"] = lambda: card("card-shuffle", 0.6, 0.12)
    out["fan"] = lambda: card("card-fan-1", 0.7, 0.1)
    for take in (1, 2, 3):
        # The clicks are single pulses: the high-pass keeps them free of DC (no low thump).
        out["ui_click_%d" % take] = lambda take=take: ui("click_%03d" % take, 0.03, low_cut=150.0)
    out["ui_open"] = lambda: ui("maximize_008", 0.15, 0.04)
    out["ui_close"] = lambda: ui("minimize_008", 0.15, 0.04)
    out["ui_back"] = lambda: ui("back_001", None, 0.01)
    out["ui_confirm"] = lambda: ui("confirmation_001", None, 0.03)
    out["ui_switch"] = lambda: ui("switch_002", 0.14, 0.04)
    for take in (1, 2, 3):
        out["coin_%d" % take] = lambda take=take: coin(take)
    return out


def write_wav(name: str, samples: list[float], out: str = OUT) -> None:
    """Writes `samples` to <out>/<name>.wav, normalised so its peak is the sound's GAINS entry."""
    os.makedirs(out, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = GAINS[name] / peak
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(round(max(-1.0, min(1.0, s * scale)) * 32767)))
            for s in samples))


def main(argv: list[str] | None = None) -> None:
    args = sys.argv[1:] if argv is None else argv
    out = OUT
    for arg in args:
        if arg.startswith("--out="):
            out = arg[len("--out="):]
        else:
            sys.exit("usage: python tools/make_sfx.py [--out=<folder>]")
    for name, build in recipes().items():
        write_wav(name, build(), out)


if __name__ == "__main__":
    main()
