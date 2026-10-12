# Sound sources (#62)

Short excerpts of outside recordings that `tools/make_sfx.py` turns into the game's sound effects
in `audio/sfx/`. Everything here is **CC0 1.0** (public domain dedication): no attribution is
required, and the files may sit in this public repository, ship on Steam and in the web build.
Each source keeps its licence text beside it, as `fonts/` does.

Godot never imports this folder (`.gdignore`), so none of it reaches an export. Only the generated
`audio/sfx/*.wav` files do.

| Folder | What | Licence file |
|---|---|---|
| `kenney/` | Kenney's Casino Audio, Impact Sounds and Interface Sounds packs (kenney.nl), decoded from OGG, trimmed | `kenney/License.txt` (all three packs' texts) |
| `vcsl/` | Versilian Community Sample Library instrument samples (github.com/sgossner/VCSL): xylophone, glockenspiel, hand chime, bell tree, marimba | `vcsl/LICENSE` |
| `freesound/` | Freesound recordings, one row each in `freesound/ledger.tsv` (id, title, author, URL, licence, check date, the cut times) | `freesound/ledger.tsv` |

Two sounds are synthesised in `make_sfx.py` instead: `scan` (a soft C7 beep) and `fizzle`.

## Rebuilding the sounds

From the repo root:

```sh
python tools/make_sfx.py          # writes audio/sfx/*.wav (standard library only)
sh tools/import.sh                # re-imports them, writing new .wav.import files
python tools/make_sfx_test.py     # also run by the full sh tools/test.sh
```

`make_sfx.py` reads these excerpts (16- or 24-bit PCM, mono or stereo, any rate), folds them to
mono, cuts them, resamples them with a Lanczos (a=8) windowed sinc for rate changes and pitch
shifts, filters them, layers them, fades them and normalises each sound to its `GAINS` peak, then
writes mono 16-bit 44100 Hz files. It is deterministic: the test checks that two runs write the
same bytes and that the committed files are up to date.

## Where the sources come from

Downloaded on 2026-10-12, each licence checked on its page that day.

- **Kenney:** the pack zips from kenney.nl/assets/casino-audio, /impact-sounds and
  /interface-sounds (the `Audio/*.ogg` files).
- **VCSL:** raw files from github.com/sgossner/VCSL (master), under
  `Idiophones/Struck Idiophones/`: `Xylophone/{Soft,Medium} Mallets/Xylo_*_far.wav`,
  `Glockenspiel/glock_soft_{C5_02,G5_01}.wav`, `Hand Chimes/sus_C5_r01_main.wav`,
  `Bell Tree/Individual/BellTree_Hit_E5_rr1_Mid.wav`, `Bell Tree/Stroke/BellTree_Stroke_3_Mid.wav`,
  `Marimba/Marimba_hit_Outrigger_{G4,C4}_soft_01.wav`.
- **Freesound:** the original files need a login, so the excerpts are cut from each sound's
  public **HQ preview** (an OGG Vorbis file, URL in the ledger). The ledger notes this per row.

`cut_sources.py` made the excerpts once from those downloads: exact sample slices, VCSL folded to
mono and kept 24-bit, the others kept 16-bit with their channels. It needs `soundfile` (to decode
OGG), so it runs from a throwaway virtual environment, never the project's or the global Python;
its docstring has the commands. It is not part of the build.

## Measurements behind the recipes

- **VCSL names read one octave below the sounding pitch** for every instrument used here
  (measured): `Xylo_Soft_G3` sounds G4, `glock_soft_C5_02` sounds C6, `sus_C5_r01_main` sounds C6,
  `Marimba_hit_Outrigger_G4` sounds G5, `BellTree_Hit_E5` peaks at E6.
- **The xylophone and glockenspiel are tuned sharp** of A4 = 440 Hz, by 12 to 16 cents.
  `make_sfx.TUNING_CENTS` records each file's measured offset and removes it, so every note lands
  in tune with the synthesised C7 scan beep.
- **The ladder (`bonus_00`..`bonus_10`)** is the C major pentatonic G4 to G6: exact anchors at G4,
  C5, G5, C6 and G6 (apart from the tuning fix) and shifts of at most 3 semitones elsewhere. Soft
  mallets pp for G4 to E5, soft ff for G5 to C6, medium mallets ff for D6 to G6.
- **The register bell** rings at A6 - 39 cents and is moved down 1.61 semitones to G6.

## Production log

`production_log.tsv` mirrors `art/src/production_log.tsv`: one row per sound with its sources,
licence, processing, the agent's minutes, the user's review rounds and minutes, and whether it is
accepted. Update a row each time the user reviews a sound.
