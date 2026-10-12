"""One-time cut of the source excerpts in this folder (#62). Not part of the build: the committed
excerpts are the sources, and tools/make_sfx.py turns them into audio/sfx/. Re-run this only to
re-cut an excerpt from a fresh download.

It needs libsndfile to decode OGG, so run it from a throwaway virtual environment outside the repo
(never install into the project or the global Python):

    python -m venv <tmp>/venv
    <tmp>/venv/Scripts/python -m pip install soundfile numpy
    <tmp>/venv/Scripts/python -I audio/src/cut_sources.py <downloads> <repo root>

<downloads> holds the files named in README.md ("Where the sources come from"):
kenney/{casino,impact,interface}/... (the unzipped packs), vcsl/<file>.wav and
freesound/<id>.ogg (each sound's HQ preview).

Each excerpt is an exact sample slice of the downloaded file, decoded once to PCM WAV. VCSL
excerpts are folded to mono ((left + right) / 2) and kept 24-bit; Kenney and Freesound excerpts
keep their channels and are written 16-bit (they are decoded from OGG Vorbis). Nothing else is
changed: no gain, no fades, no filters. make_sfx.py does all the processing.
"""

import os
import sys

import numpy as np
import soundfile as sf

DOWNLOADS, REPO = sys.argv[1], sys.argv[2]
SRC = os.path.join(REPO, "audio", "src")

# (folder, output name, source path under DOWNLOADS, start s, length s or None for the rest)
CUTS = []
for name, start, length in [
    ("casino/Audio/card-place-1.ogg", 0.06, 0.30),
    ("casino/Audio/card-place-2.ogg", 0.03, 0.28),
    ("casino/Audio/card-place-3.ogg", 0.22, 0.32),
    ("casino/Audio/card-place-4.ogg", 0.0, None),
    ("casino/Audio/card-slide-1.ogg", 0.085, 0.20),
    ("casino/Audio/card-slide-2.ogg", 0.0, 0.30),
    ("casino/Audio/card-slide-3.ogg", 0.0, 0.30),
    ("casino/Audio/card-slide-5.ogg", 0.0, 0.25),
    ("casino/Audio/card-shove-1.ogg", 0.0, 0.35),
    ("casino/Audio/card-shove-2.ogg", 0.0, 0.35),
    ("casino/Audio/card-fan-1.ogg", 0.0, 0.72),
    ("casino/Audio/card-shuffle.ogg", 0.0, 0.75),
    ("impact/Audio/impactSoft_heavy_000.ogg", 0.0, 0.45),
    ("impact/Audio/impactSoft_heavy_001.ogg", 0.0, 0.45),
    ("impact/Audio/impactSoft_heavy_002.ogg", 0.0, 0.45),
    ("impact/Audio/impactPunch_heavy_000.ogg", 0.0, 0.40),
    ("impact/Audio/impactPunch_heavy_001.ogg", 0.0, 0.40),
    ("impact/Audio/impactSoft_medium_002.ogg", 0.0, None),
    ("impact/Audio/impactMetal_light_001.ogg", 0.0, 0.25),
    ("interface/Audio/click_001.ogg", 0.0, None),
    ("interface/Audio/click_002.ogg", 0.0, None),
    ("interface/Audio/click_003.ogg", 0.0, None),
    ("interface/Audio/tick_001.ogg", 0.0, None),
    ("interface/Audio/tick_004.ogg", 0.0, None),
    ("interface/Audio/error_001.ogg", 0.0, None),
    ("interface/Audio/maximize_008.ogg", 0.0, None),
    ("interface/Audio/minimize_008.ogg", 0.0, None),
    ("interface/Audio/back_001.ogg", 0.0, None),
    ("interface/Audio/confirmation_001.ogg", 0.0, None),
    ("interface/Audio/switch_002.ogg", 0.0, 0.20),
]:
    CUTS.append(("kenney", os.path.basename(name)[:-4] + ".wav", "kenney/" + name, start, length))
for name, length in [
    ("Xylo_Soft_G3_pp_01_far", 1.1), ("Xylo_Soft_C4_pp_01_far", 1.1),
    ("Xylo_Soft_G4_pp_01_far", 1.1), ("Xylo_Soft_C4_ff_01_far", 1.0),
    ("Xylo_Soft_G4_ff_01_far", 1.1), ("Xylo_Soft_C5_ff_01_far", 1.1),
    ("Xylo_Soft_G5_ff_01_far", 1.0), ("Xylo_Medium_C4_ff_01_far", 1.2),
    ("Xylo_Medium_G4_ff_01_far", 1.0), ("Xylo_Medium_C5_ff_01_far", 1.2),
    ("Xylo_Medium_G5_ff_01_far", 1.1), ("glock_soft_C5_02", 1.3), ("glock_soft_G5_01", 0.5),
    ("sus_C5_r01_main", 1.3), ("BellTree_Hit_E5_rr1_Mid", 0.3), ("BellTree_Stroke_3_Mid", 1.3),
    ("Marimba_hit_Outrigger_G4_soft_01", 1.2), ("Marimba_hit_Outrigger_C4_soft_01", 1.2),
]:
    CUTS.append(("vcsl", name + ".wav", "vcsl/" + name + ".wav", 0.0, length))
for out, sound_id, start, length in [
    ("210094_receipt_printer.wav", "210094", 2.32, 0.26),
    ("470710_rubber_stamp.wav", "470710", 0.48, 0.50),
    ("452572_rattle_s.wav", "452572", 63.04, 0.22),
    ("452572_rattle_m.wav", "452572", 26.48, 0.34),
    ("452572_rattle_l.wav", "452572", 9.08, 0.56),
    ("452572_bell.wav", "452572", 83.80, 0.90),
    ("452572_drawer_chunk.wav", "452572", 106.55, 0.25),
    ("452572_drawer_slam.wav", "452572", 57.53, 0.30),
    ("448474_self_inking_stamp.wav", "448474", 1.07, 0.38),
    ("221515_desk_bell.wav", "221515", 0.275, 0.06),
    ("564128_card_tap.wav", "564128", 6.10, 0.08),
    ("451644_perforated_tear.wav", "451644", 0.415, 0.42),
    ("367273_coin_1.wav", "367273", 1.585, 0.27),
    ("367273_coin_2.wav", "367273", 4.858, 0.27),
    ("367273_coin_3.wav", "367273", 6.774, 0.27),
]:
    CUTS.append(("freesound", out, "freesound/%s.ogg" % sound_id, start, length))

for folder, out, source, start, length in CUTS:
    x, rate = sf.read(os.path.join(DOWNLOADS, source), dtype="float64", always_2d=True)
    a = int(round(start * rate))
    b = len(x) if length is None else min(len(x), a + int(round(length * rate)))
    excerpt = x[a:b]
    if folder == "vcsl":
        excerpt = excerpt.mean(axis=1, keepdims=True)
    excerpt = np.clip(excerpt, -1.0, 1.0 - 1.0 / 8388608)
    os.makedirs(os.path.join(SRC, folder), exist_ok=True)
    dest = os.path.join(SRC, folder, out)
    sf.write(dest, excerpt, rate, subtype="PCM_24" if folder == "vcsl" else "PCM_16")
    print("%s/%s: %s %.3f + %.3f s" % (folder, out, source, start, (b - a) / rate))
