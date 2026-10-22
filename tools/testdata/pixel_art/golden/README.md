# GOLDEN palette map references (#77)

Test data for `tools/pixel_art_test.py` (`GoldenReferenceTest`): `tools/pixel_art.py`'s `@derive`
maps must turn each `<item>_big.txt` into `<item>_golden.png` pixel for pixel.

- `*_golden.png`: the approved #77 prep's GOLDEN sprites, copied from
  `docs/art/mockups/machine_77_src/upgrades/png/items_v2/` (made by `gen_upgrades.py`).
- `*_big.txt`: their BIG inputs, as in `art/src/items_v2/` when the references were copied (comments
  dropped). They are frozen here: editing the game's BIG sources doesn't change this test.
- `palette.txt`: `art/src/palette.txt` at the same time.

Maps: Banana `yellow`, Eggs `egg`, Milk and Coffee `rank`.
