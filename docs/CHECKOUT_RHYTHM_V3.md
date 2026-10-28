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
