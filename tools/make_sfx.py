"""Generates the placeholder sound effects in audio/sfx/ (plan section 2: beep and printer,
plus count-up juice). Pure Python, no dependencies, and deterministic: the same code writes the
same bytes. Re-run after changing a sound:

    python tools/make_sfx.py [--out=<folder>]

--out writes the sounds to another folder instead of audio/sfx/ (the tests use it).

Every sound is short, mono, 22050 Hz, 16-bit. Pitch escalation happens at play time
(AudioStreamPlayer.pitch_scale), so one file per sound is enough. `bonus` is the count-up's note
ladder (Sfx.play_note): one steady G5 that Sfx pitches from G4 (x0.5) to G6 (x2.0).
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")


def envelope(i, n, attack=0.005, release=0.6):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = (1.0 - i / n) ** (1.0 / max(release, 0.01))
    return a * r


def tone(freq, seconds, wave_shape="sine", volume=0.5, sweep_to=None, release=0.6):
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq if sweep_to is None else freq + (sweep_to - freq) * i / n
        phase += 2 * math.pi * f / RATE
        if wave_shape == "sine":
            s = math.sin(phase)
        elif wave_shape == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        else:  # saw
            s = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        out.append(s * volume * envelope(i, n, release=release))
    return out


def noise(seconds, volume=0.5, release=0.5, lowpass=0.0, seed=1):
    rng = random.Random(seed)
    n = int(RATE * seconds)
    out = []
    last = 0.0
    for i in range(n):
        s = rng.uniform(-1, 1)
        if lowpass:
            k = lowpass * (1.0 - i / n) + 0.02
            last += (s - last) * k
            s = last * 2.5
        out.append(s * volume * envelope(i, n, release=release))
    return out


def partials(freq, seconds, levels_db, decay, attack=0.005, fade=0.01):
    """A steady pitched note with no glide and no noise: one sine per entry of `levels_db`
    (harmonic number -> level in dB relative to the fundamental), a linear attack, an exponential
    decay with time constant `decay` seconds, and a short linear fade at the end so the cut
    doesn't click."""
    n = int(RATE * seconds)
    fade_n = max(1, int(RATE * fade))
    gains = [(h, 10 ** (db / 20)) for h, db in sorted(levels_db.items())]
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(g * math.sin(2 * math.pi * freq * h * t) for h, g in gains)
        a = min(1.0, t / attack) * math.exp(-t / decay) * min(1.0, (n - i) / fade_n)
        out.append(s * a)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(seconds):
    return [0.0] * int(RATE * seconds)


# Peak level of each sound relative to full scale, set on purpose so the mix is balanced:
# the stamp and the final total hit hardest, the per-card scan/print sit in the middle, and
# small details (fizzle, tick, click) stay underneath.
GAINS = {
    "stamp": 0.95, "total": 0.8, "miss": 0.8, "pass": 0.7, "fail": 0.7, "denied": 0.7,
    "print": 0.65, "scan": 0.6, "tag": 0.55, "link": 0.55, "ding": 0.5, "copy": 0.5,
    "fizzle": 0.45, "bonus": 0.4, "tick": 0.4, "click": 0.4,
}


def write_wav(name, samples, out=OUT):
    """Writes `samples` to <out>/<name>.wav, normalised to the sound's peak in GAINS."""
    os.makedirs(out, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    # Normalise every sound to its own target peak (always leaves headroom for overlaps).
    scale = GAINS.get(name, 0.6) / peak
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def note(semitones_from_c5):
    return 523.25 * 2 ** (semitones_from_c5 / 12)


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    out = OUT
    for arg in args:
        if arg.startswith("--out="):
            out = arg[len("--out="):]
        else:
            sys.exit("usage: python tools/make_sfx.py [--out=<folder>]")

    def save(name, samples):
        write_wav(name, samples, out)

    # Scanner beep: a short bright square.
    save("scan", tone(1760, 0.075, "square", 0.35, release=0.3))
    # Count-up note (the note ladder): a steady G5, pitched per gain by Sfx.play_note. A sine with
    # a soft 2nd and 3rd harmonic, a 5 ms attack and a ~70 ms decay: a short in-key pluck.
    save("bonus", partials(783.99, 0.22, {1: 0.0, 2: -12.0, 3: -20.0}, decay=0.07))
    # Multiplier stamp: a mid-range "clack" you hear on laptop speakers, over a body thump.
    save("stamp", mix(tone(180, 0.2, "sine", 0.7, sweep_to=90, release=0.7),
                      tone(620, 0.05, "square", 0.35, sweep_to=420, release=0.3),
                      noise(0.08, 0.55, release=0.35, lowpass=0.45, seed=3)))
    # Receipt printer: dot-matrix clicks.
    clicks = []
    for k in range(6):
        clicks += noise(0.012, 0.5, release=0.4, seed=10 + k) + silence(0.016)
    save("print", clicks)
    # Soup denied: a rough low buzz.
    save("denied", tone(110, 0.28, "square", 0.45, sweep_to=90, release=0.8))
    # Fizzle: a soft deflating "pfff".
    save("fizzle", mix(noise(0.45, 0.45, release=0.9, lowpass=0.35, seed=7),
                       tone(420, 0.35, "sine", 0.12, sweep_to=160, release=0.9)))
    # Sticker tag: two-note chime.
    save("tag", concat(tone(note(7), 0.07, "sine", 0.5), tone(note(12), 0.12, "sine", 0.5)))
    # Bundle link: a quick rising arpeggio.
    save("link", concat(*[tone(note(n), 0.055, "sine", 0.45, release=0.4) for n in (0, 4, 7)]))
    # Copy: a short "photocopier" swish.
    save("copy", noise(0.14, 0.35, release=0.6, lowpass=0.5, seed=5))
    # Final total: a bright chord.
    save("total", mix(*[tone(note(n), 0.6, "sine", 0.3, release=0.8) for n in (0, 4, 7, 12)]))
    # Shift passed: an upward arpeggio. Shift failed: a sad descending trombone.
    save("pass", concat(*[tone(note(n), 0.09, "square", 0.25, release=0.5) for n in (0, 4, 7, 12)],
                        tone(note(16), 0.3, "square", 0.25, release=0.9)))
    save("fail", concat(*[tone(note(n) / 2, 0.22, "saw", 0.3, sweep_to=note(n) / 2 * 0.97,
                               release=0.9) for n in (7, 6, 5)],
                        tone(note(4) / 2, 0.6, "saw", 0.3, sweep_to=note(4) / 2 * 0.9, release=0.95)))
    # A missed quota: a dull low thud instead of the bright total chord.
    save("miss", mix(tone(85, 0.35, "sine", 0.8, sweep_to=60, release=0.8),
                     noise(0.18, 0.3, release=0.6, lowpass=0.2, seed=11)))
    # One dot-matrix tick, played as the subtotal rolls.
    save("tick", noise(0.009, 0.5, release=0.3, seed=4))
    # UI click.
    save("click", noise(0.02, 0.4, release=0.3, seed=2))
    # Quota reached mid-count: a C6 bell (sine plus its octave partial at -10 dB), a 5 ms attack
    # and a ~350 ms decay. In key with the note ladder and the C-major total chord.
    save("ding", partials(1046.5, 1.0, {1: 0.0, 2: -10.0}, decay=0.35, fade=0.03))


if __name__ == "__main__":
    main()
