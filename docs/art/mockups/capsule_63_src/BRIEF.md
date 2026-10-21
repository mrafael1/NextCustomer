# #63 mock-up brief: capsule machines, the draw and the figurine shelf

Brief for the decide-round mock-ups of issue #63 ("Capsule machines: plain panel, draw, figurine shelf and list
logic"). Nothing is decided: the pages are options to choose from. Written 2026-10-21 from the code at 481cfbe (PR #88's
#86 work plus the UI test speed-up), `docs/FULL_BUILD_PLAN.md` sections 1, 4, 6.1, 6.2, 7.1, 7.2, 10 and 11, issues #63
and #64, `data/aisles/*.tres`, and the earlier decide preps (`screens_src/BRIEF.md`, `DECIDE_56.md`, `purse_src/DECIDE_76.md`,
`machine_77_src/DECIDE_77.md` in the main tree).

## 0. Ground rules

- **Mock-ups only.** No game code, data, art sources or plans change. The pages live in `docs/art/mockups/capsule_63_*`,
  the shared code, assets and notes in `docs/art/mockups/capsule_63_src/`.
- **Live pages.** The user judges motion and juice on live, animated HTML better than on stills (#86), so each look is a
  clickable page: click a machine and the draw plays. URL parameters freeze any state for the stills
  (`capsule_63_src/capsule.js` lists them: `state`, `coins`, `nosave`, `draw` + `t`, `land`, `rm`, `words`, `locked`,
  `labels`, `hover`, `cap`).
- **Stills.** `capsule_63_src/capture_all.sh` rebuilds every still, one headless Chrome at a time (1280x720 at 1.5x,
  so 1920x1080), with a throwaway profile removed after each capture.
- **Pixel art.** 1 art px = 2 canvas px. Machines, cabinets and backdrops are painted on canvases at art resolution with
  palette colours only (`art/src/palette.txt`), 1 px ink outlines, flat bands, hard stepped shadows, light from the upper
  left. Fonts by role: Pixelify Sans (signs, titles, buttons), Atkinson Hyperlegible Next (body, every number at 750),
  JetBrains Mono (receipts; not used here). Reused frames: `button.png`, `sign.png`, `top_button.png`, `popup.png`,
  `sticker_label.png`, `sticker_burst.png`, `sparkle.png`, `warning.png`, `art_pending_v2.png`; aisle glyphs and item
  sprites from `docs/art/mockups/assets/art/`.
- **Real data only.** Aisles in `BalanceDefinition.aisles` order with their `sign_color`s and `capsule_cards` (key item
  first). Of the 30 capsule items only Strawberries, Croissant and Crisps have sprites; the other 27 show the art-pending
  box with the name printed in it, as the game does until #57 and #58.

## 1. What exists in the code (481cfbe)

- `ProfileState` (`FORMAT_VERSION` 1, pure): `coins`, `run_count`, `unlocked_items: Dictionary[StringName, int]` (item id
  to run index, kept in draw order), `last_list`, `seen`, `settings`. `record_run` counts the ended run and pays coins.
  Nothing spends a coin, unlocks an item or writes `last_list` yet.
- `AisleDefinition.capsule_cards`, key item first: Cold cases Cream, Ham ends · Pantry Sugar cubes, Mixed herbs ·
  Household Egg timer, Chipped mug, Odd socks · Fruit & veg Fruit salad, Strawberries, Grapefruit, Wonky carrot, Lemon,
  Bruised apples, Soft tomatoes, Potatoes · Bakery Baguette, Scone, Croissant, Broken biscuit, Iced bun, Birthday
  candles, Squashed cake, Stale doughnut · Snacks Crisps, Cereal bar, Bent lolly, Pick 'n' mix, Stale popcorn,
  Breadsticks, Dusty toffees. 30 in all (2/2/3/8/8/7).
- Sign colours: Cold cases #4f9a94, Pantry #e2b33c, Household #8a8172, Fruit & veg #3d7a45, Bakery #d2a874, Snacks
  #7a5232. Each aisle has a 9x9 glyph (`art/icons/aisle_<id>.png`), which section 6.1 says the machines reuse.
- `RunStock.needs_list` (3 base aisles hold 14 of the 16-product budget, so the 3rd base-aisle capsule makes a list
  needed), `EventLog.derived_stream(run_seed, name)` and `IMPULSE_RACK_STREAM` in `telemetry/event_log.gd`.
- `SimChain._draw_capsule` already draws key-first, then uniformly among those left, with its own machine pick.

## 2. Constraints from the plans and issues

- Section 7.1: one machine per aisle at the store exit, coin-op toy machines with figurines; 1 coin = 1 capsule; no
  shop, no second currency; never "gacha" (game and store page, section 11); separate from, and different from, the
  exit kiosk. **Since #77** (being built on `feature/receipt-rewards-machine`) the mid-run reward machine is the
  restock hatch (look F: stock bays, boxes on a little belt, curtained hatch), which replaces the print-out and the
  kiosk. The capsule machines must not look like it: these looks use glass globes or windows, capsules, cranks and coin
  slots, and none uses boxes, belts or hatches.
- Section 1 and 7.1: the panel and the shelf show no rule text; the figurine is the item's plain sprite.
- Section 6.1: colour is never the only signal (the sign names the aisle and shows its glyph); sprites stand alone at
  1x (48x48 canvas px) on the shelf and at 2x (96x96) in the reveal.
- Section 6.2: no information only inside an animation; the reveal stays as the readable result; reduced motion fades
  in place. #64 owns the animation's beats, timings and skips; these pages preview a 2.6 s version only so the looks can
  be judged in motion.
- Section 10: the animation (#64) is 4th on the cut list; #63's plain panel and static machine and shelf art stay if it
  is cut. Cutting the machine-opened aisles leaves 3 machines (the layouts centre a shorter row).
- The issue's fit tests: 6 machines, the figurine view and the full shelf at 1280x720; every figurine inside its aisle
  group; disabled states; coins drop by 1.

## 3. The pages

| Page | What it shows |
|---|---|
| `capsule_63_index.html` | links and a one-screen summary |
| `capsule_63_a.html` | Look A, the exit vestibule: six round-globe machines on the tiled floor by the sliding doors (camera cut to the exit) |
| `capsule_63_b.html` | Look B, the machine bank pop-in: six boxy window machines in a steel cabinet over the shaded results |
| `capsule_63_c.html` | Look C, the collector wall: a small wall machine above each aisle's wooden display case; the figurine flies into its cubby |
| `capsule_63_shelf.html` | the separate figurine shelf for A and B: full and partial, locked as spaces or hidden, names on hover or printed |

States on every look page: partial collection (9 of 30, 2 coins), fresh, full collection (3 coins), 0 coins, profile
can't be saved, reduced motion, and a frozen draw at any time `t`.

## 4. Shared behaviour in all three looks (the mock-ups' defaults)

- Each machine: aisle sign (sign colour, glyph, name in Pixelify), a glass globe or window with one capsule per item
  left, a cream "1 coin" price-gun label, a coin slot, a crank or dial, a chute. Under it a label: "3 of 8 left", or
  "All 8 collected".
- Coins chip and a FIGURINES n / 30 chip.
- States: empty machine (empty globe, gold ALL COLLECTED rosette, not clickable, no price); 0 coins (machines dimmed,
  tomato notice "No coins left. Runs that pass shift 4 pay coins on the final receipt."); profile can't be saved (OUT OF ORDER paper taped
  on each machine, "Coins ?", notice "Your collection can't be saved right now, so the toy machines are switched off.", the same string
  on every page; only coins show "?", following section 7.1's "you have ?").
- The draw: the coin and the item are spent and recorded at the click (before any animation). The preview: coin flies
  into the slot (0.42 s), crank turns (0.58 s), capsule drops into the chute, hops forward, shakes and pops (1.26 s), the
  figurine rises on a gold medallion (0.36 s). A tap during it jumps to the reveal.
- The reveal (what #63's plain panel shows, and what #64 must end on): the figurine at 2x on a gold medallion, a NEW!
  burst, the name on a cream label, the aisle glyph and name, "In stock from your next run", OK (or click anywhere).
- Reduced motion: the reveal fades in place in 0.3 s; nothing flies, shakes or turns.
