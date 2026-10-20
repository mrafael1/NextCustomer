# #76 decide list: the rich customer's purse (prep, 2026-10-19)

Nothing here is decided. The pages are linked from `docs/art/mockups/purse_index.html`. Every direction sits at spot A: the counter by the register, body Rect2(284, 326, 52, 72), left of x 336 so the reward print-out's shade leaves it lit. Reference state: shift 5/8, quota €73 (`balance.tres` quotas 34, 35, 53, 61, 73, 98, 111, 120), h1's row projecting €182 (+€109), an under-quota €52 with a drag "› €58 (+6)", and SHORT €52 / €73.

Status: plan v0.34 (#80) dropped the purse against the recommendation, and its art was retired in f9a46f5. #76 is still open on Phase 3, so keeping it dropped is a real option (Q1, D).

## Four questions for the user

### Q1. Bring the purse back, or keep it dropped?
- **A. Framing words, plus a purse on the counter.** Rename the QUOTA chip's label to a minimum spend (Q4) and add the purse.
- **B. The chip becomes the purse** (direction B): a BUDGET tag with a face replaces the chip's bar, and a wallet sits on the counter.
- **D. Keep it dropped.** Change the chip wording only. #76 closes.

**Recommendation: A, with the purse on the cut list and the words off it.** All three reviewers found the same thing: at 52 px the purse adds motion and charm, but at a glance the chip's words do the framing. The words are the fb-p2 fix that section 9 keeps off the cut list, and they cost a label change. The purse is the juice on top (memory: the user wants juicy), and it can be cut without losing the framing.

### Q2. Which purse?
- **A. Fat leather frame purse** (purse_a*): cash and a card bulge out over 5 steps; empties, snaps shut or sags at the verdict.
- **B. Slim wallet** (purse_b*): a debossed €, a few notes; it leans on the tag.
- **C. Grin purse** (purse_c*): kiss-lock knobs as eyes and the mouth as a grin; notes and a card fan up.

**Recommendation: A.** It matches B2's grounded store and h1's pixel style, its steps differ by shape in greyscale, and it is the closest to the purse the user picked in #75. C reads emotion best, but it is a cartoon character next to a realistic cashier, its tag covers the printer, and steps 1 and 2 look alike at game size. If the user wants more personality, the middle road is A's body with C's gasp on the quota ding.

### Q3. What does it react to, and in how many steps?
- **A. Both phases**: the projected total in planning (`QuotaMeter.show_projected` and the drag's `show_hypothetical`) and the count-up subtotal (`LedDisplay.reading_changed`, with `met` at the quota ding). 5 steps on shown ÷ quota (A's thresholds: 0.4, 0.7, 0.9, 1.0), plus OVER, ON and SHORT poses from core `ShiftMargin`.
- **B. Count-up only.** Planning stays calm, but the "more is better" signal comes after the first CHECKOUT, which is too late for fb-p2.
- **C. Planning only.** It goes quiet during the count, which is the juiciest moment.

**Recommendation: A, both phases, 5 steps.** The fb-p2 fix has to show before the first CHECKOUT, and the count is where it pays off. Steps change only when the ratio crosses a threshold, never per tick. On a drag the purse hops for +N and slumps for −N without changing step until the drop lands. The thresholds are `@export` display ratios in `data/balance/`, like `QuotaMeter.fill_fraction`. It never rescores.

### Q4. Does it carry the quota, and does it replace the bar?
- **A. Rename the label and keep the bars**: the chip reads "BUDGET €73+" (or "SPEND €73+", or "at least €73") with the same bar and check, and the monitor's count row reads "BUDGET €73 · bar · €N to go".
- **B. Replace the bar** with B's stitched pocket on a face tag (rework QuotaMeter, keeping its fixed widths).
- **C. Keep "QUOTA"** and let the purse alone carry the framing.

**Recommendation: A, renamed with the bars kept.** It gets the words B proved, with no QuotaMeter rework and no new chip art. The bar already moves without jumping during a drag (#71). The user picks the exact words. The label is a player string only: `quota` stays the name in code, data and logs, as Deck became Cart.

## Defaults (stated, not asked)
- **One purse for the whole run.** No per-customer or per-shift variants: that is a later idea, on the cut list.
- **Sound:** one new CC0 "clasp click", made through `tools/make_sfx.py`, plays only when the step changes (planning and count). No new sound at the quota ding, because the count-up's ding already plays there. Nothing follows the subtotal per tick (the fb-p2 counting complaint). The verdict reuses the existing `stamp_paid` / `fail` cues.
- **Reduced motion:** the loops stop (gleam, sparkles, tremble, flying notes, the burst rays). Poses swap instantly and coins rest on the counter.
- **It holds still when the register rattles**, like the receipt, so the stillness rule stays simple.
- **Size stays at spot A's 52x72.** Narrowing the printer to make it bigger would be a layout change and is not part of #76.
- **Colours:** brown leather, a mustard clasp, green cash and a teal card. No tomato (a short shift sags in ink), no velvet and no brass (pillar 4).
- **The SHORT tag reads "she wanted to spend €21 more"** (ink), framing a short shift as the customer missing out, never as savings.
- **Overtime barely pays** (€923 per coin, at most 1), so past the quota the purse tops out at BURST. Nothing grows without limit.
- **Phase 3 order:** the label rename lands with #61 or #56, whichever comes first (off the cut list). The purse comes after #56 and #57 and #58, before #69, and #69 decides whether to cut it.

## Build plan sketch (if Q1 = A)
1. **Art:** `art/src/scenery/purse_calm.txt`, `purse_peek`, `purse_bulge`, `purse_strain`, `purse_burst`, `purse_over`, `purse_short`, plus the parts `purse_note`, `purse_coin` and `purse_card` (26x36 art px, 2 screen px per art px, palette colours only), each with a `production_log.tsv` row; build with `python tools/pixel_art.py build`, then `sh tools/import.sh`. One CC0 clasp source in `audio/src/` with its licence, and `audio/sfx/clasp.wav` through `make_sfx.py`.
2. **Data:** `data/balance/purse.tres` (`PurseTuning`: step ratios, hop height, step tween ms, burst ms) as `@export` fields.
3. **Scene and script:** `ui/customer_purse.tscn` and `ui/customer_purse.gd` (class_name CustomerPurse). Its root API: `show_amount(amount: int, quota: int)`, `show_delta(delta: int)`, `show_verdict(kind: ShiftMargin.Kind)`, `set_reduced_motion(on: bool)`, plus a read-only `step`. `ShiftScreen` places it at spot A and feeds it the same numbers it gives the QuotaMeter and the LED (preview, hypothetical, `reading_changed`, dessert margin). The purse never touches `core/` scoring.
4. **Wording:** the QUOTA chip and the LED count row label become the chosen words. Update the player-string tests.
5. **Tests:** `tests/ui/customer_purse_test.gd` checks that the purse sits inside 1280x720, that its rect (with the rising notes) stays left of `REGISTER_RECT.end.x` (336), and that it overlaps neither the receipt, slot 1's item and stickers, the CHECKOUT/Redraw keys nor the top bar. It also checks that the step follows the shown amount (feed values across each threshold, in planning and through `reading_changed`, and assert the step), that a drag delta never changes the step, that the verdict poses match OVER/ON/SHORT, and that reduced motion runs no looping tweens. `captured_shift_test` gets the purse in the capture. `data/` is already in the resource-loading test.
6. **Docs:** plan section 6.1 (assets and the purse), section 9 (the framing words), the changelog (playtest-facing), and a recapture of `docs/art/shift_screen_*.png` through `debug/screen_capture`. Then the user plays it.
