# Purse mock-ups: brief (#76, decide prep, 2026-10-19)

For the agents drawing `docs/art/mockups/purse_*` pages. Nothing in #76 is decided yet. The pages give the user options to choose from. They are not game code.

## 0. Status: read this first

- **The plan says the purse was dropped.** `docs/FULL_BUILD_PLAN.md` v0.34 (#80, 2026-10-17): "dropped against the recommendation: the paper pile … and #76's purse". `purse_closed` and `purse_open` were retired in commit f9a46f5. Their old sources are in git history (`git show f9a46f5^:art/src/scenery/purse_closed.txt`, and the same for `purse_open.txt`), along with the static velvet clasp purse from style frame v2 (`docs/art/style_frame_v2_planning_1280x720.png`, about 184x100 at the bottom of the counter). Issue #76 is still open on the Phase 3 milestone. One option the user must have is **"keep it dropped / cut list"**. Every page should make the case on its own merits.
- What #76 answers is the fb-p2 finding: players thought a **lower** total wins, as if they were saving the customer money. The user's framing idea is a supermarket for rich people who *want* to spend, so the bigger the total, the happier the purse. The plan (section 9, item 3) says this framing must not depend on a cut-list feature such as the run intro (#67). If the purse carries the framing, it is that kind of feature.

## 1. Base scene and rules for the pages

- Copy `docs/art/mockups/planning_effects_h1.html` (approved "just perfect"). It is self-contained, uses `../../../fonts/` and `assets/art/…` by relative path, and is drawn in 1280x720 CSS px. Add the purse as an overlay, the way `planning_effects_src/gen_h1/` patches its base: a `purse_src/gen_<x>/gen_<x>.py` (standard library only) that writes `purse_<x>.html`, plus a `run.sh` that captures through a copy of `planning_effects_src/gen_h1/cap.sh` (headless Chrome, 1.5x, giving 1920x1080). `shift_screen_b2_mirrored.html` is **not** on this branch, so build from the h1 page itself.
- Game truth for geometry: `docs/art/shift_screen_effects_1280x720.png`, `docs/art/shift_screen_1920x1080.png` and the constants in `ui/shift_stage.gd`.
- Pixel art: a 2 px grid, 2 px ink outlines, flat colour bands, stepped contact shadows falling a few px to the right, and the key light from the upper left. The colours come only from `art/src/palette.txt` (it has 67 colours; the "32-colour" figure is out of date). Fonts: Pixelify (display), Atkinson Hyperlegible Next (numbers and text), JetBrains Mono (receipt).
- Colour rules already agreed:
  - **Tomato** means a fizzle, CHECKOUT or CLOSED only. No tomato purse, and no tomato for "short".
  - Pillar 4 keeps velvet and brass for the CLOSED stanchions and the monitor's LED. h1's brass rail strips were approved on top of that.
  - So a **velvet** purse (the old one) or a brass-heavy one breaks pillar 4. If a page uses it, say so in a caption. Safe options: **brown leather** (`e 4a3022`, `f 7a5232`, `F a87a4e`, `h d2a874`) or teal (`1`–`6`), with a mustard or gold clasp (`M`, `y`, `n`).
  - Cash is green (`g`, `G`, `z`) and a card is cream or teal; coins are mustard, as in the cash drawer's tray.
- Scale: a 96 px item is about 25 cm on the counter layer, so a real purse is about 80–100 px wide. Sprites are drawn at 1 art px = 2 screen px, like the 48x48 items.

## 2. Where it fits: free counter space (1280x720 stage px)

Since the mirror (#83), "below the tray" no longer exists. The register, printer, receipt and cashier are at the left. The belt runs from x 348 to 1266. The hand sits in four baskets from x 362 to 1254, y 514–696, on the steel ledge. The counter front between the price rail's foot (y 494) and the baskets is reserved: a scanned basket item rises into that 20 px gap. The gaps between baskets are about 16 px wide. The wall under the monitor (y 248–290) is behind the counter, and h1's stickers grow up into it. I measured the capture and found one real free counter spot, plus two places that could carry a purse at small size:

| # | Spot | Free rect | Purse rect to draw | Notes |
|---|---|---|---|---|
| **A** (recommended) | **The counter top by the register, in front of the cashier**, between the printer box and the belt | Wood visible from x 296 to about 350 (the belt frame slants from about x 358 at y 340 to about 350 at y 400) and from y 326 to 400 (the column's light edge) | **Rect2(284, 326, 52, 72)** for the body. A bulging card or note may rise to about y 296 over the cashier's apron, since she stands behind the counter. | It reads as the customer setting her purse down to pay at the register. The purse stays **left of x 336**, because during the reward print-out the shade covers everything right of `REGISTER_RECT.end.x` = 336 (`ShiftScreen._process`), so a purse there stays lit with the register and the receipt. It overlaps the printer box's right end (which ends at x 296) by about 12 px, in front of it. It must stay clear of the receipt (x 46–282, rising from y 340) and of slot 1's item, halo and stickers (the cell starts at x 364; Eggs art is at x 385–460). It is small: 52 px is about 14 cm, a clutch or a fat wallet rather than a handbag. Making it bigger would need a layout change, such as narrowing the printer, which is a game change. |
| **B** | **The top bar's QUOTA chip** (the purse *carries the quota*) | The chip is about Rect2(142, 9, 396, 38) (`TopBar` POSITION (16, 9), ROW_SIZE 1248x38). Inside it: "QUOTA €73", the bar (≥ 80 x 14), the amount (4 reserved digits), then the check or the drag-delta slot (26 px) | A 32x32 purse icon at the bar's right end, or the bar redrawn as the purse's "spend gauge" (a seam that fills with cash), about Rect2(250, 12, 180, 32) | This answers the issue's question "replaces the LED quota bar?". It needs fixed widths, because `QuotaMeter` keeps reserved widths so the bar never moves during a drag. It is not "on the counter", so it is a variant of A or a companion to it. |
| **C** | **The monitor (customer display)** during the count | `LedDisplay` COUNT layout's quota row: "QUOTA €N · bar · €N to go" (COUNT_QUOTA_ROW 276x22 in the LED's frame, screen Rect2(493, 75, 406, 158)) | A 24–32 px purse at the row's left or right end that reacts with the bar | This only shows from CHECKOUT to the verdict, because in planning the monitor shows the store channel. It is good as a counting echo of A, not as the main home. |

Ruled out: the narrow brown strip x 336–362 between the register and the first basket (26 px), the cash drawer (`DRAWER_RECT` 12, 624, 314x76, which is register furniture, and the seed line must stay), and the wall left of the receipt (x 0–46).

## 3. What it can react to (display only, never scoring)

Numbers that already exist, and where they live:

| Phase | Number | Source (read, never computed) |
|---|---|---|
| Planning | **Projected total** of the row on the belt | The screen's preview (`run.preview`) goes to `QuotaMeter.show_projected(amount, quota)` and to the receipt's PROJECTED line. In planning the LED is blank (store channel). |
| Planning, drag | **Would-be total and its change**: "› €58 (+6)" (`›` because the fonts lack `→`) | `QuotaMeter.show_hypothetical(amount, delta, quota)` (#71, decision 4A), from `RunState.preview(card, slot)`. It shows until the drag ends. |
| Count-up | **Running subtotal** and **quota met** | `LedDisplay.reading_changed(amount, quota, met)` and `mode_changed(BLANK / PROJECTED / SUBTOTAL / TOTAL)`. `met` flips at the count-up's **quota ding** beat (`CountUpPlan`), and the chip's check disc appears then. `CountUp.step_landed(index)` and `beat_started(...)` give per-beat timing. |
| Count-up | **Size of the total**: NORMAL / LARGE / HUGE | `CountUpPlan.size` / `CountUpIntensity.is_large/is_huge`, measured against the best earlier checkout (`count_up.tres`: large_floor 50, large ×1.25, huge ×2.0), **never against the quota** (D3). It drives the held breath (pause 500 / 700 ms), the rattle and the register bell. |
| Verdict / dessert (#61) | **TOTAL**, then the **margin**: "+€N OVER QUOTA", "ON QUOTA" (exactly on it is a pass) or "SHORT €N" | core `ShiftMargin` (Kind OVER / ON / SHORT). `CountUpDessert`: the slam lands on the monitor's total, the margin counts with `pass`/`fail`, the **PAID** stamp lands on every passed shift, the receipt tears (`rip`), and the next-shift notice prints. The reward print-out takes over at `CountUp.printer_feed`. All of it runs within a 1.0 s budget from the verdict to the armed print-out. |
| Run end | Overtime coins | `CoinPayout`: €923 of summed overtime per coin, at most 1 (`balance.tres`). Going over quota barely pays, so the purse should not promise more than the game gives. |

Reaction ideas to offer, each **shape plus motion, never colour alone**:

- **Steps on the projected total and the subtotal against the quota** (display arithmetic, like `QuotaMeter.fill_fraction`, with the thresholds as `@export` tuning in `data/balance/`): closed and slim → clasp straining → card or notes poking out → **open and gleaming at the quota** (with a check or "PAID"-style mark) → overstuffed with sparkles and sweat drops past it. A 3–5 step ladder.
- **Planning drag**: the purse leans toward the delta: a small hop or gleam for "+6", a slump for a negative change. The delta number stays on the QUOTA chip.
- **Count-up**: a hop on each gain beat (on the note ladder's beats, not every tick), and a "gasp" (the clasp pops) on the quota ding. During the held breath before TOTAL it trembles (except under reduced motion).
- **Verdict**: OVER → the purse empties happily (notes flutter into the cash drawer, which can already pop open with coins) with a mustard "THANK YOU" tag. ON QUOTA → a satisfied snap shut. SHORT → it stays half full and sags, with a tag in ink (not tomato) such as "she wanted to spend €21 more". This frames a short shift as the customer not getting to spend, never as saving money.
- **Sound (#62)**: no new samples were decided. Candidates from the existing `Sfx` set are `ding` / `register_bell` / `stamp_paid` / `tick`, or one new CC0 "clasp" sample through `tools/make_sfx.py`. Remember the fb-p2 complaint about the counting sound: nothing should follow the subtotal per tick.

## 4. Framing copy to try (the user decides the words)

- On the purse or the QUOTA chip: "Budget: at least €73" (from the issue), "She came to spend €73+" or "Spend at least €73". The quota is a *minimum spend*.
- The fb-p2 fix only works if a new player reads "more is better" **before** the first CHECKOUT, so show it in planning, not only in the dessert.

## 5. Constraints every page must respect

1. **The UI never calculates a score** (`AGENTS.md`). The purse shows the ScoreResult's or preview's numbers and the core margin. Its step thresholds are display ratios kept as tuning data, and they never rescore.
2. **No colour-only signal**: every state differs in shape, pose, prop or text (as the quota chip's check disc does).
3. **Reduced motion** turns off the loops (gleam, tremble, sweat). The pose changes stay, as instant swaps or fades.
4. **Layout inside 1280x720**: it must not cover the receipt, the CHECKOUT/Redraw keys, slot 1's item and stickers, the top bar's other chips, or the monitor. In spot A it stays left of x 336 for the print-out shade.
5. **Stillness rules**: the receipt never shakes with the register. Decide whether the purse rattles with the register (it stands on the counter beside it) or holds still.
6. Real numbers in range: the quotas are €34, 35, 53, 61, 73, 98, 111, 120 (shifts 1–8). The reference state is shift 5/8, quota €73. h1's row projects €182 (+€109 over). Also show an under-quota planning state (for example €52, with a drag "› €58 (+6)") and a SHORT verdict (for example €52 / €73, "SHORT €21").

## 6. Questions the pages should let the user answer (from #76)

1. What it reacts to: the projected total in planning, the count-up's subtotal against the quota, or both, and how many steps.
2. Purse, clutch or wallet; one purse for the run, or a new one per shift or customer.
3. Its sound, and whether reduced motion freezes it (default: loops off, poses kept).
4. Whether it carries the quota ("Budget: at least €73") and replaces the QUOTA chip's bar (spot B), or the LED bar on the monitor.
5. Where it sits in the phase 3 order, and whether it goes on the cut list, given that v0.34 already dropped it.
