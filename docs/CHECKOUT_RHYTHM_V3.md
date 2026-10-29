# Checkout Rhythm v3

Source: [approved working mock-up](art/mockups/checkout_rhythm_v3.html), supplied by the user on 2026-10-27. The user chose both displayed defaults: one-slot advances and a brief monitor display even for plain items.

The checkout reads the existing `ScoreResult.steps`; it never scores or changes the result. The register display and top gauge share `LedDisplay`. Only a payment advances that subtotal. The item column updates its price from the real step's `value_after` and retains its explanation while the item is scanned. Its compact rows fold only earlier overflow; the receipt keeps the complete result.

The register covers the unavailable CHECKOUT key while counting. Coins travel toward its drawer. The payment crossing the quota starts its SPEND MET celebration, including when that is the last item. The old monitor-wide climax is left out. On 2026-10-28 the user asked that the monitor no longer show the spend objective: its checkout column is hidden in planning as well as in the count, and the item column spans the paper right of the bay; the top bar and the register keep the objective. A resumed checkout has a quiet final state; planning restores the key and the original monitor layout.

`data/balance/count_up.tres` contains v3's beat lengths, payout tiers, successive-add acceleration, last-payment hold and quota hold. `CountUpPlan` keeps timing deterministic. Motion uses the count-up's tweens so taps and holds continue to work. The register celebration uses real time, following the press speed so its quota hit-stop cannot freeze it. Reduced motion retains all values and explanations while omitting movement, coin flights and flashing.

Adjacent own bonuses carry an explain-only `support_slot` on their `ScoreStep`, supplied by the scoring rule that already found the matching neighbour. This lets a Banana chain point to the previous Banana and Strawberries point to the neighbouring Produce without calculating rules in UI. Numeric results and existing step serialization are unchanged.

Bagged card givers are labelled "from the bag" with their mini pulsing beside their bonus; the bag nudges. A live giver hops, a loyalty box flips. The paid price on its ticket is restamped before the cell leaves the belt.

The implementation branch starts from the 12-shift loop branch. It also carries the already approved coupon mini artwork and ticket hover-outline correction, whose branches had advanced after that base. Those changes retain their existing tests and generated asset import files.

## Review and verification

Use the real screen capture scene with `--rhythm --checkout=<seconds>` to load the mock-up's Strawberries, Banana, Banana, Multipack, Banana, Banana row, with Produce regulars, Produce aisle run and Slot engine. The scene isolates saves and logs in a temporary folder.

New rhythm tests cover payout-only totals, quota timing, plain-item speed, heavier multipliers, retained and folded explanation lines, exact register/gauge sync and reduced motion. Existing scoring fixtures remain unchanged. Legacy assertions for bonus-by-bonus running totals, monitor-covering quota effects and the former 5-9 second budget are updated to the v3 contract.

Review captures: [last payment](art/checkout_rhythm_v3/shift_screen_effects_checkout_87_1280x720.png) and [finished checkout](art/checkout_rhythm_v3/shift_screen_effects_checkout_100_1280x720.png).

Validation on 2026-10-27:

- The full run executed all 1,631 GdUnit cases with no runtime errors; all 158 Python tool tests passed. It reported 43 failures in legacy presentation assertions and 50 queued-node cleanup warnings in the new overflow test. Those assertions now check v3 and the cleanup waits for queued deletions.
- All affected suites pass on targeted reruns: 54 checkout presentation/UI cases, 59 integration cases (the register celebration suite rerun once more after fixing its resume fixture), and the 66 unchanged golden scoring cases. No failing test remains unaddressed. The full suite was not repeated after these test-only updates.
- The 37 changed/new scripts outside the separately reproduced badge-test shutdown leak pass parser/type checking, lint and formatting. `tests/ui/giver_badge_test.gd` still emits its pre-existing resource-retention errors when checked alone; its assertions pass in the full run.
- All 531 pixel sources pass. Web and Windows exports pass. The real capture scene renders the reviewed row and finished checkout without Godot errors.

The implementation is ready for in-game review and remains uncommitted and unpushed on `feature/checkout-rhythm`.

## v3.1 polish

Source: the user approved the live mock-up [checkout_rhythm_v3_1.html](art/mockups/checkout_rhythm_v3_1.html) on 2026-10-29 (plan v0.71). It is presentation only: no rule, score, card value, beat length or save format changed, and the UI still reads the real `ScoreResult`. The game's own sizes, fonts and `Palette` win where the mock-up approximates.

- **Receipt** (`ReceiptView`, `ReceiptInk`, `ReceiptDecor`): each item line carries its giver-badge mini (the item sprite when it has no plate, as Multipack's coupon sprite) in a two-character slot inside the line's height; a name the slot would wrap steps its font down instead, so the receipt never grows. × amounts are dark amber (`MUSTARD_DARKEST`), + amounts ink, every maths symbol kept. Each item's payout figure is bold (the item amount for a plain item, the `= €Y` closing line for a multiplied one), with no rule between items. Loyalty perk lines sit on a pale teal band (`TEAL_PALE`); other cards' combo lines keep the gold band. An armed coupon prints one indented sub line, "arms " and the card's sticker summary (Multipack: "arms ×3 later with prior's tag"), its ×N amber and no amount; it prints when the count shows the arming and counts towards the fold. Planning, the count and the resumed result print the same lines (the cards are passed to all three, and to the reward machine's copy).
- **Monitor in the count** (`MonitorItemColumn`, `MonitorView`): multiplier lines keep their leading × ("× Multipack" with the amber "×3"); × amounts amber, + and payment amounts ink; giver names, "from the bag" (its own smaller label) and gives lines teal (`TEAL_DARK`), so amber means only ×.
- **Payment equation** (`PaymentEquation`, attached to each payout beat by `CountUpPlan`): at an item's payout the monitor shows "€X × N → €Y" (the × N amber, under a 2 px ink rule, at the bonus lines' 15 px on a 20 px last row so it stands out; play test 2026-10-29) in place of "Pays €N", inside the existing payout hold. X is the value before the item's first multiplier step, N the product of its multiplier steps and Y its payout; it shows only when X × N = Y exactly and there is a multiplier, so plain, flat-only, €0, copied (Repeat) and overridden payouts keep "Pays €N". Tap-skip, fast-forward, 1.5x and reduced motion keep it, and a resumed checkout's quiet final state shows the last item's equation. SPEND MET stays on the register, so it never covers the equation.
- **Planning monitor** (`MonitorItemColumn`, `MonitorStepPages`, `MonitorView`): lines that fit under the full effect stay as they were. When they don't, the layout turns compact, as the count's: the price (and the struck base) in the name row, the effect on one line at the smallest tier (cut with an ellipsis), the rule and the lines moved up, one 18 px line each, so four lines fit. Still too many go on pages of whole lines with a small "1/2" marker bottom right: page 1 first, then the next every `page_interval_s` (2.5 s in `data/balance/count_total.tres`), wrapping around, crossfading over `page_fade_s` (0.15 s; at once under reduced motion). While the pointer is on the monitor no page turns by itself; the mouse wheel (or a touchpad scroll) over it turns one page a gesture, restarts the wait and is taken, so nothing else scrolls. The monitor takes the pointer only while it shows pages in planning. The pages' timer and fades stop when the item changes or the count starts; the same item shown again on a refresh keeps its page. "+N more" is no longer used in planning; the count still folds earlier overflow into "+N earlier".

- **Sequence** (`MonitorView`, `CountUpBeats`): in a bonus or multiplier beat the giver pulses at its start, its monitor line shows at `step_line_at` (0.3) of the beat and its value lands on the item no earlier than `step_value_at` (0.55) of the beat's motion (both in `data/balance/count_total.tres`, on the count's clock, so tap-skip, fast-forward and 1.5x scale them; reduced motion shows the line and lands the value at once). The line always shows before its value, and a pending line shows at once when the next beat starts. Beat lengths are unchanged; the receipt still prints the step's line at the beat's start.
- **Flat-only payouts:** an item whose + lines add up to its payout bolds its last + amount (the one that completes the payout) instead of adding a `= €Y` line, so the receipt keeps its height.

Left open: Multipack's arm line names no tag ("arms ×3 later with prior's tag", not the mock-up's "arms ×3 for later Produce"), since the tag it picks is decided inside scoring and never reaches its step; naming it needs an explain-only field on the step in `core/`, which waits for the user's decision. A flat-only item still has no monitor equation ("Pays €N"), as the approved rule allows one only with a multiplier.

The implementation is uncommitted and unpushed on `feature/checkout-rhythm`, pending the user's in-game review.
