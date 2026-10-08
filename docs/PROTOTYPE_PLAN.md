# Next Customer: Prototype Plan

> Status: v0.23, closed at proto-r1. The full build (`docs/FULL_BUILD_PLAN.md`) has taken over; this plan stays the scoring-rule spec (sections 3–5) and changes only when a rule does.
> Source: the original "Receipt Rogue" game design plan, plus the decisions made in planning.
> Engine: Godot 4 (exact version pinned in `AGENTS.md`), GDScript with static typing. Playtest builds are delivered in the browser.

## 1. The question the prototype answers

**Is choosing groceries and coupons, then arranging their scanning order, fun enough to replay?**

All prototype work serves that question. Everything else waits for the full build (`docs/FULL_BUILD_PLAN.md`).

The prototype has to show three things:

1. **Ordering is a real decision.** Players find a better order by understanding combinations, not by shuffling cards blindly until the preview goes up.
2. **Coupons are the fun multiplier.** They create combinations that ordinary products cannot make alone, and players actively want them.
3. **Counting points feels good.** Watching the receipt print and the total climb is satisfying, even with placeholder visuals.

## 2. Scope

### In scope

- The full scoring engine with coupon hook points (section 4), with unit tests
- 8 products and 5 coupons (section 5), with one coupon in the starting deck
- One shift: read the quota, draw 8, redraw up to 2 once, place up to 6 products and 7 cards in order (section 3.1) with **click-to-place** (select a card, click a slot), see the live projected total, run checkout
- The point-count sequence: receipt lines print one by one, the source of each bonus is highlighted, the subtotal ticks up, with beep and print sounds and a fast-forward option
- A run of 5 shifts with quotas 10 / 15 / 22 / 32 / 48 (placeholders; 8 shifts, quotas 10 / 13 / 17 / 22 / 27 / 33 / 40 / 48 since v0.12)
- After each successful shift, pick 1 of 3 stock cards or skip; deck view; 15-card limit with replacement (the 13-card start deck reaches it after two picks, so replacement is reachable from the third reward)
- Win and lose screens, instant restart. A restart starts a new run with a **new random seed**; replaying a fixed seed is only possible from the debug panel. New run seeds come from a randomized `RandomNumberGenerator` owned outside `core/` (the same one that makes the `session_id`) and are passed in when a run is created; `core/` never makes its own seeds.
- Seeded random numbers (the seed is shown on screen, and a run can be replayed from its seed in development builds)
- An event log written automatically, which can be exported from the browser (section 8), and a small script that summarises the logs
- **A browser build** for playtesters (section 7), plus a Windows build as a fallback
- A debug panel: set the seed, add any card to the hand, skip to a shift. It exists in development builds only, so playtesters can't spoil the data: both export presets carry the `playtest` feature tag and exclude `debug/*`, and the panel is loaded with `load()` only when `OS.has_feature("playtest")` is false. It is never preloaded or placed in a shipped scene, and scripts outside `debug/` never name a `debug/` class (no type hints, `.new()` or `is` checks): the excluded classes don't exist in a playtest build, so such a reference would fail to compile there. They load the panel scene by path and treat it as a plain `Control`. Any use in a development build is logged as a `debug` event.
- **Drag-and-drop only if time allows.** It is the first thing cut (section 6).

### Out of scope (deliberately)

Art, register upgrades, inspections, tutorial, saving, settings menus, meta progression, unlockable decks, Steam, and more than 8 shifts.

Placeholder visuals: coloured rectangles with the card name, tags, base value and rule text. Use a readable sans-serif font for rules and a monospace font for the receipt.

## 3. Rules specification (prototype defaults)

The original design doc is the base. These decisions resolve its ambiguities. Each one can be changed after playtests.

### 3.1 The row

- The checkout row is **compacted**: cards always fill slots from the left, with no gaps. Removing a card shifts the ones after it to the left.
- The **last slot** means the last filled slot.
- The row has **6 shared slots + 1 coupon-only slot** (decided with the user, v0.9): it holds at most `slot_count` products (6) and at most `slot_count + coupon_slot_count` cards (7), both in balance data. One coupon can take the coupon slot; extra coupons can still take product slots. The check is by `kind`, never card ids.
- The coupon slot is a capacity, not a position: the row stays one flat, compacted, ordered list, so a product can sit in the 7th slot when a coupon is earlier. Coupons in the row still break adjacency exactly as before, so scoring doesn't change, and every row that was legal before stays legal.

### 3.2 Order of resolution

Scoring runs in two passes (section 4):

1. **Context pass:** tag changes and adjacency changes from coupons are applied to the whole row first.
2. **Value pass, left to right**, for each card, product or coupon:
   1. Base value
   2. **+ all flat bonuses** (its own rule, Coffee bonuses waiting for it, and so on; upgrade bonuses come last, section 3.8)
   3. **× all multipliers** (Eggs charges, Multipack, …; upgrade multipliers come last, after any copy, section 3.8)
   4. Payout added to the subtotal
   5. Its effects for later cards become active (Eggs charges, Coffee bonus, Multipack's ×2, …), each with an `EFFECT_ARMED` step that changes no value (section 4)

Coupons go through the same steps at their own slot. A coupon has base 0 and no tags, so it never receives an Egg charge, a Coffee bonus, a Multipack ×2 or any other effect aimed at products. Its payout comes only from its own rule and upgrades (section 3.8): Final markdown's +6 is its own flat bonus, and Repeat's payout is the copy (section 3.3). Every coupon appears on the receipt, even when it pays 0.

### 3.3 Stacking

| Case | Rule |
|---|---|
| Several flat bonuses on one product | They add together |
| Several multipliers on one product | They multiply together: Eggs ×2 and Multipack ×2 = ×4 |
| Flat and multiplier | All flat bonuses first, then all multipliers. The order within a step does not matter. |
| Values | Whole euros only. All prototype multipliers are ×2, so no rounding is needed. If fractional multipliers are added later, round down after each product. |
| Two Eggs | A later Egg resets the charges to 2. It does **not** add a second ×2. |
| Two Multipacks | Each applies separately (they stack ×2 × ×2). Watch this in playtests. |
| Two Coffees | Each Coffee's +3 goes **once** to the next Breakfast product after it. Coffee is Breakfast, so in Coffee → Coffee → Bread, the first bonus goes to the second Coffee and the second bonus goes to Bread. |
| Repeat | Copies the final payout (after all flat bonuses and multipliers) of the product just before it. The copy is never multiplied again by card or effect multipliers (an upgrade can multiply it, section 3.8) and never triggers effects. |

### 3.4 Adjacency

| Term | Meaning |
|---|---|
| "Immediately after X" | A product counted as just before this card is X, after the context pass: the product in the slot just before it, or one a coupon links to it (2 for 1, Shelf swap, Bundle) |
| "Beside X" | A product counted as just before or just after this card is X |
| A coupon between two products | **Breaks adjacency** between them, unless a coupon's rule links them |
| Links (since v0.23) | A link works both ways (the earlier product also counts as just before the later one), and one side can hold several products: a product keeps its real neighbour and gains every product linked to it. A rule that names a neighbour checks them all. |
| "Same product" (since v0.23) | The same card, where a variant counts as its base card (`variant_of`, one level). It applies everywhere a rule compares products: 2 for 1, Banana-style "same card" bonuses, rules that name a card (Cheese after Organic Bread gets +4) and duplicates (inspections, phase 2). Decided with the user. |
| "First product" (since v0.23) | The row's first product, coupons skipped. |
| 2 for 1 | When the same product is on both sides of it, the two count as adjacent (context pass), and the second pays ×2: an armed effect for that one slot, so it stacks with Eggs and Multipack and a Repeat after it copies the doubled payout. Otherwise it fizzles; two in a row both fizzle (each has a coupon beside it). |
| Shelf swap | In the context pass, the product in the next slot also counts as just after the row's first product (and the first product as just before it). It fizzles when the next slot holds no product, or when that product is the row's first. |
| Bundle | In the context pass, the product before Bundle and the product after it count as adjacent to each other (for both "immediately after" and "beside"). Several connector coupons in a row act as one bridge. When a neighbour isn't a product (Bundle at an end of the row, or next to a coupon that isn't a connector), Bundle bridges nothing and breaks adjacency like any coupon. |
| Repeat after Bundle | Still pays 0. Repeat only copies a *product* in the slot just before it; Bundle does not change that. |
| Breakfast sticker | Affects the next slot only. If that slot is a coupon or empty, or the product there is already Breakfast, the sticker is wasted. |
| Multipack | Uses the tags of the product just before it (after the context pass). In slot 1, or after a coupon, it does nothing. |

### 3.5 Other rules

| Topic | Decision |
|---|---|
| Eggs | Doubles the next 2 Food payouts. An Egg is Food. An Egg does not boost itself, but it can use up a charge left by an earlier Egg. Coupons neither use up nor receive the charge. |
| Coffee "+3 to the next Breakfast product" | The next Breakfast product anywhere later in the row, not only the adjacent slot. With no later Breakfast product, the bonus is lost. |
| Soup "pays 0 if beside a Frozen product" | The final payout becomes 0, after flat bonuses and multipliers. Bonuses aimed at Soup (e.g. a Coffee +3) are spent and lost. |
| A product that pays 0 | Still uses up an Egg charge (Soup is Food). |
| Drawing | Every shift draws 8 from the whole deck, freshly shuffled. Cards replaced by the redraw are set aside for the rest of that shift. |
| Loss | A checkout below the quota ends the run (no warning in v1) |
| Checkout | Always allowed, whatever the row holds: an empty row scores 0 (and fails the quota), a one-card row scores that card. |
| Preview | The exact projected total is always visible. The receipt preview shows each line. |
| Wasted effects ("fizzles") | Every effect that does nothing gets its own 0-value receipt step, so the count-up can play a small "fizzle" on that card and players learn why an order was worse: a Coffee bonus with no later Breakfast product (and a Flickering bulb's with no later Clearance product, v0.22) · Egg charges left unused, or wiped by a later Egg's reset (and a Tea bags charge left unused) · a Breakfast sticker on a coupon, an empty slot or a product that is already Breakfast · a Bundle that bridges nothing · a Multipack with no product before it, or whose ×2 hits no later product · Repeat with nothing to copy · Final markdown (or Batteries) outside the last slot · Scissors with no coupon before it (it counts every earlier coupon, whether or not that coupon did anything) · 2 for 1 without a product on both sides, or without the same product on both sides · Shelf swap with no product in the next slot, or when that product is the row's first. An effect that was armed and then fizzles keeps its `EFFECT_ARMED` step, so the count-up shows it armed first. The scoring needs to be **juicy**: the steps carry everything the count-up needs (source slots for fly-ins, armed effects, separate multiplier steps for stamps, running values, fizzles). |

### 3.6 Product tags

| Product | Tags |
|---|---|
| Banana | Food, Produce |
| Bread | Food, Breakfast, Bakery |
| Cheese | Food, Dairy |
| Eggs | Food, Breakfast |
| Milk | Food, Breakfast, Dairy |
| Coffee | Breakfast (not Food) |
| Soup | Food |
| Frozen peas | Food, Frozen, Produce |

The base aisles' products (full build phase 2, v0.22) add two tags: **Household** for non-food goods (not Food, so Eggs skips them) and **Clearance** for reduced items.

| Product | Tags |
|---|---|
| Butter | Food, Dairy |
| Yogurt | Food, Dairy, Breakfast |
| Reduced yogurt | Food, Dairy, Clearance |
| Cereal | Food, Breakfast |
| Tea bags | Breakfast (not Food) |
| Crackers | Food, Bakery |
| Dented can | Food, Clearance |
| Day-old buns | Food, Bakery, Clearance |
| Carrier bag | Household |
| Scissors | Household |
| Batteries | Household |
| Flickering bulb | Household, Clearance |

### 3.7 Required test cases (written before the UI)

| Row | Expected | What it checks |
|---|---|---|
| Eggs, Bread, Cheese, Banana, Banana, Repeat | **31** | The doc's example |
| Banana, Repeat, Bread, Eggs, Banana, Cheese | **18** | The doc's weaker order |
| Eggs, Banana, Banana | 1 + 4 + 8 = **13** | Banana pair: (2 + 2) × 2 |
| Banana, Bundle, Banana | 2 + 0 + 4 = **6** | Bundle connects the pair |
| Banana, Repeat, Banana | 2 + 2 + 2 = **6** | A coupon breaks the pair |
| Bread, Bundle, Cheese | 3 + 0 + 7 = **10** | Bundle connects Bread and Cheese |
| Eggs, Bread, Multipack, Bread | 1 + 6 + 0 + 12 = **19** | Eggs ×2 and Multipack ×2 stack to ×4 |
| Milk, Multipack, Cheese | 3 + 0 + 6 = **9** | Multipack by a shared tag (Food and Dairy) |
| Coffee, Coffee, Bread | 2 + 5 + 6 = **13** | Each Coffee bonus used once |
| Breakfast sticker, Banana, Milk | 0 + 2 + 5 = **7** | The sticker makes Banana Breakfast for Milk |
| Eggs, Eggs, Bread, Bread, Bread | 1 + 2 + 6 + 6 + 3 = **18** | The second Egg uses a charge, then resets to 2 |
| Repeat, Repeat | **0** | Repeat after a coupon (or in slot 1) pays 0 |
| Soup, Frozen peas | 0 + 3 = **3** | Soup beside Frozen pays 0 |
| Bread, Final markdown | 3 + 6 = **9** | Final markdown in the last slot |
| Final markdown, Bread | 0 + 3 = **3** | Final markdown outside the last slot pays nothing |
| Eggs, Bread, Repeat, Bread | 1 + 6 + 6 + 6 = **19** | Repeat doesn't use up an Egg charge, so the second Bread is still doubled |
| Bread, Multipack, Bread, Repeat | 3 + 0 + 6 + 6 = **15** | The Repeat copy is not multiplied again |
| Multipack, Bread, Bread | 0 + 3 + 3 = **6** | Multipack in slot 1 does nothing |
| Bread, Repeat, Multipack, Bread | 3 + 3 + 0 + 3 = **9** | Multipack right after a coupon does nothing |
| Breakfast sticker, Repeat, Banana, Milk | 0 + 0 + 2 + 3 = **5** | The sticker lands on a coupon and is wasted, so Banana stays non-Breakfast |
| Frozen peas, Frozen peas | 6 + 6 = **12** | "Beside" works in both directions, so both get the bonus |
| Soup, Bundle, Frozen peas | 0 + 0 + 3 = **3** | Bundle makes Soup count as beside Frozen peas |
| Soup, Repeat, Frozen peas | 5 + 5 + 3 = **13** | A coupon breaks the pair, so Soup keeps its value |
| Eggs, Coffee, Bread, Bread | 1 + 2 + 12 + 6 = **21** | Coffee isn't Food, so it doesn't use an Egg charge; Coffee's +3 is added before the ×2 |
| Coffee, Banana, Bread | 2 + 2 + 6 = **10** | Coffee's bonus skips a non-Breakfast product and reaches a later one |
| Coffee, Bread, Milk | 2 + 6 + 7 = **15** | Milk counts every earlier Breakfast product (+2 each) |
| Coffee, Repeat, Bread | 2 + 2 + 6 = **10** | The Repeat copy doesn't trigger Coffee's bonus a second time |
| Coffee, Multipack, Banana, Bread | 2 + 0 + 2 + 12 = **16** | Multipack matches on a tag other than Food (Breakfast), skips a product that shares no tag, and reaches past the next slot; Coffee's +3 is added before the ×2 |
| Bread, Multipack, Bread, Multipack, Bread | 3 + 0 + 6 + 0 + 12 = **21** | Two Multipacks stack (×2 × ×2) |
| Breakfast sticker, Banana, Multipack, Coffee, Bread | 0 + 2 + 0 + 4 + 12 = **18** | Multipack sees the Breakfast tag added by the sticker, so Coffee is doubled |
| Banana, Bundle, Bundle, Banana | 2 + 0 + 0 + 4 = **6** | Two connectors in a row act as one bridge |
| Bread, Bundle, Repeat | 3 + 0 + 0 = **3** | Repeat after Bundle pays 0 |
| Coffee, Breakfast sticker, Soup, Frozen peas, Bread | 2 + 0 + 0 + 3 + 3 = **8** | Soup's payout becomes 0 even after Coffee's +3, and the bonus is spent (Bread doesn't get it) |
| Eggs, Soup, Frozen peas, Bread | 1 + 0 + 6 + 3 = **10** | Soup paying 0 still uses an Egg charge |
| Banana, Bundle, Multipack, Banana | 2 + 0 + 0 + 2 = **4** | Bundle next to a coupon that isn't a connector bridges nothing |
| Bundle, Banana, Banana, Bundle | 0 + 2 + 4 + 0 = **6** | Bundle at either end of the row does nothing |
| Bread, Coffee | 3 + 2 = **5** | A Coffee bonus with no later Breakfast product is lost |
| Breakfast sticker, Bread, Milk | 0 + 3 + 5 = **8** | A sticker on a product that is already Breakfast is wasted |
| Bread, Repeat, Repeat | 3 + 3 + 0 = **6** | Repeat after a coupon that paid something still pays 0 (it copies only products) |
| Coffee, Breakfast sticker, Banana | 2 + 0 + 5 = **7** | Coffee's bonus reaches a product made Breakfast by the sticker |
| Coffee, Multipack, Breakfast sticker, Banana | 2 + 0 + 0 + 10 = **12** | Multipack reaches a later product that gained the shared tag from the sticker |

**2 for 1 and Shelf swap (v0.23).** These rows run on their own frozen fixture, `tests/fixtures/cards_v0_5/` (Banana, Bread, Cheese, Eggs, Frozen peas, Repeat, Soup, 2 for 1, Shelf swap), so the `cards_v0_4` rows, Bundle's included, stay exactly as they were.

| Row | Expected | Tests |
|---|---|---|
| Banana, 2 for 1, Banana | 2 + 0 + 8 = **10** | The pair is linked, Banana's bonus applies, then ×2 |
| Bread, 2 for 1, Cheese | 3 + 0 + 3 = **6** | Different products: it fizzles and breaks adjacency |
| Banana, 2 for 1, 2 for 1, Banana | 2 + 0 + 0 + 2 = **4** | Two in a row both fizzle |
| Frozen peas, 2 for 1, Frozen peas | 6 + 0 + 12 = **18** | The link works for "beside" too |
| Eggs, Banana, 2 for 1, Banana, Repeat | 1 + 4 + 0 + 16 + 16 = **37** | The ×2 stacks with Eggs; Repeat copies the doubled payout |
| Bread, Banana, Shelf swap, Cheese | 3 + 2 + 0 + 7 = **12** | Cheese counts as just after Bread, the first product |
| Soup, Bread, Shelf swap, Frozen peas | 0 + 3 + 0 + 3 = **6** | Shelf swap's cost: Soup is now beside Frozen |
| Frozen peas, Bread, Shelf swap, Frozen peas | 6 + 3 + 0 + 6 = **15** | The link works both ways |
| Banana, 2 for 1, Banana, Shelf swap, Banana | 2 + 0 + 8 + 0 + 4 = **14** | Two links on one side of the first Banana |

Golden rows use a frozen copy of the card data, `tests/fixtures/cards_v0_4/` (named for the rules version it froze), so tuning values in `data/` between playtest rounds doesn't break them. The live data gets its own tests with expected totals that are updated when values change.

How the fixture is built:
- It is **self-contained**: each card `.tres` embeds its rule resources as sub-resources and references nothing in `data/`. A test checks that no file in the fixture mentions `res://data/`.
- Write it by hand from the values in sections 3.6 and 5. If you start from copies of `data/` files, remove their `uid=` strings and let Godot assign new ones on import, because two resources must never share a UID.
- It freezes **values**, not rule scripts. Rule scripts are shared with the game, so changing a rule script can still change golden totals, and that is a rule change that needs approval.
- Rule scripts give every `@export` number a neutral default (0 for bonuses, 1 for multipliers, 0 for charges). Godot doesn't write a value to a `.tres` file when it equals the script default, so a non-neutral default would let a script change silently alter the fixture.

No row may depend on a question that is still in the unresolved table of `core/AGENTS.md`.

Also tested: duplicate cards are separate instances · the redraw cannot bring back a card that was just replaced · the same seed gives the same draws · a restart uses a new seed (the test injects the seed source) · every `@export` number in a rule or upgrade script defaults to its neutral value · no card in `data/` or the fixture has `kind` left at `UNSET`, and no upgrade has `type` left at `UNSET` · every `.tres` and `.tscn` in `data/` (including `data/upgrades/` and `data/inspections/`), `ui/`, `presentation/`, `debug/`, `telemetry/` and the fixture loads, and is of the expected type (`tools/test.sh` also fails on any Godot error printed while loading) · scoring with no upgrades, or with upgrades whose rules do nothing, gives exactly the steps it gives without the upgrade argument, on every golden row (section 3.8), and the same holds for inspections (section 3.9).

### 3.8 Upgrades (full build phase 1)

Decided with the user (v0.13). Register upgrades (`docs/FULL_BUILD_PLAN.md` section 5.2) last for the whole run and live on the loyalty card. Phase 1 has 3 placeholder upgrades; their numbers are `@export` fields in `data/upgrades/`.

**Scoring.** `Scoring.score(row, upgrades)` takes the run's upgrades in pick order; the default is none, and with no upgrades every result is exactly what it was before upgrades existed. The live preview and the checkout pass the same upgrades, so they never disagree. An upgrade's rules (`UpgradeRule` scripts in `core/upgrades/`, stateless like card rules, with the same hook names: `flat_bonus`, `multiplier`, `wasted_reason`) are asked about every slot by the scoring loop. They are never attached to a card definition.

| Topic | Rule |
|---|---|
| Stacking | Flat bonuses: the card's own, then effects, then upgrades. Multipliers: the card's own, then effects, then upgrades. All flat bonuses still come before all multipliers (section 3.3), so an Egg charge doubles an upgrade's flat bonus. |
| Upgrade multipliers and copies | Upgrade multipliers come after a copy, so a Repeat's copied payout can be multiplied by an upgrade. A card's own and effect multipliers still come before the copy and never touch it (section 3.3). Products never copy, so for a product the upgrade multipliers come straight after its other multipliers. Order per slot: `BASE`, `FLAT` (own, effects, upgrades), `MULTIPLIER` (own, effects), `COPY`, `MULTIPLIER` (upgrades), `PAYOUT_OVERRIDE`, `PAYOUT`, `EFFECT_ARMED`, then `WASTED` (the card's own, then upgrades). |
| Effects | Upgrades never receive or arm card effects. |
| Copies | A copy never re-triggers upgrades. A Repeat copies the earlier product's final payout, which already includes anything an upgrade added to that product. Only an upgrade's own rule can multiply the Repeat itself (the Coupon engine, when the Repeat is the first coupon). |
| Payout overrides | An upgrade bonus aimed at a card whose payout is overridden (Soup beside Frozen) is spent like any bonus aimed at Soup (section 3.5): its step stays on the receipt, the payout becomes 0, and there is no `WASTED` step. |
| Nothing to multiply | An upgrade multiplier aimed at a card whose value is 0 at that point gets no `MULTIPLIER` step. It fizzles instead: a `WASTED` step with the upgrade's reason, after the card's own `WASTED` steps. |
| Source | Upgrade steps have `source_kind` `UPGRADE` and `source_index` = the upgrade's index in the run's upgrades (pick order). `slot` and `source_slot` are both the slot the step lands on (never −1). The text is the rule's receipt text, or the upgrade's name. |

| Upgrade | Type | Rule | Data |
|---|---|---|---|
| Coupon engine | Coupon engine | The first coupon in the row (the lowest slot holding a coupon) pays ×2, after its own rules: Final markdown's +6 becomes 12, and a Repeat's copy is doubled. Only the first coupon. If it has nothing to multiply (a Breakfast sticker, a Multipack, a Repeat with nothing to copy, a Final markdown outside the last slot), it fizzles with the reason "the first coupon paid nothing". With no coupon in the row it does nothing and has no step: the receipt doesn't mention it, because there is no card to fizzle on. | `factor` 2 |
| Category engine | Category engine | +3 for each different tag among the row's products, using tags after the context pass (a Breakfast sticker's tag counts), as a flat bonus on the **last product** in the row (not the last slot: a coupon after it doesn't take the bonus, and a Repeat after it copies it). It comes after that product's own and effect flat bonuses, so the product's multipliers apply to it. With no product in the row, no step. | `bonus_per_tag` 3 |
| Extra redraw | Economy | One more redraw each shift. No scoring step. | `extra_redraws` 1 |

**Redraws.** A shift allows 1 redraw plus the `extra_redraws` of every owned upgrade. Each redraw replaces up to `redraw_limit` hand cards (never row cards), and every redraw rule holds for each one: cards replaced by any redraw are set aside for the rest of the shift.

**The upgrade step.**
- Upgrade shifts are the 1-based shift numbers in `upgrade_shifts` in balance data (2, 4 and 6). A test checks that each one is a shift of the run and not the last one.
- When an upgrade shift is passed, checkout builds the reward offer and then the upgrade offer, both from the run's seeded RNG, so later draws never depend on UI timing.
- The offer: up to `upgrade_offer_size` (3) upgrades from `upgrade_pool` that the run doesn't own yet, each of a different type, chosen from the pool shuffled with the run's RNG. Placeholder limitation: the 3 placeholders have 3 different types, so the offers on shifts 2, 4 and 6 hold 3, 2 and 1 options. The rule "at least one fitting the current deck" (`docs/FULL_BUILD_PLAN.md` section 5.2) waits for build tags in phase 2. An empty offer (every pool upgrade owned) skips the step.
- The upgrade step comes after that shift's reward pick or skip, and after any deck-full replacement. The player **must** pick one of the offered tickets: there is no skip. Only an offered upgrade is accepted. It joins the run's upgrades (in pick order) and applies from the next shift on.
- Losing a shift ends the run as before, with no upgrade. The last shift has no reward and no upgrade.
- Run history: one entry per played shift, with the shift number, quota, total, pass or fail, the reward card picked (or skipped, or none offered), the upgrade taken (or none) and the cards checked out (`played`, in row order, since v0.16).
- A starting deck's upgrade (`docs/FULL_BUILD_PLAN.md` section 7.3, since v0.16) is owned from the first shift, first in the run's upgrades (index 0). Offers skip it like any owned upgrade, and the loyalty card gives it a pre-stamped box before the upgrade-shift boxes. The starter deck has none.

`UpgradeDefinition` fields: `id`, `display_name`, `type` (`RULE_BENDER`, `SLOT_ENGINE`, `CATEGORY_ENGINE`, `COUPON_ENGINE`, `ECONOMY`, `RISKY`; its default `UNSET` is rejected by a test, like `CardDefinition.kind`), `effect_text`, `condition_text` (its own line on the ticket; may be empty), `supported_build`, `rules` (scoring) and run modifiers (`extra_redraws`). Perk icons come later; the greybox shows the name's initials.

### 3.9 Inspections (full build phase 1)

Decided with the user (v0.14). Inspections (`docs/FULL_BUILD_PLAN.md` section 5.3) are visible restrictions on one shift. Phase 1 has the framework and 1 placeholder inspection; the 3 real ones come in phase 2. Inspections never go on the loyalty card.

**Scoring.** `Scoring.score(row, upgrades, inspections)` takes the shift's inspections; the default is none, and with no inspections (or inspections whose rules do nothing) every result is exactly what it was before inspections existed. The live preview and the checkout pass the same inspections. An inspection's rules (`InspectionRule` scripts in `core/inspections/`, stateless like card rules, with the same hook names; phase 1 needs only `final_payout`) are asked about every slot by the scoring loop and are never attached to a card.

| Topic | Rule |
|---|---|
| Order | An inspection's payout override comes after the card's own overrides, just before `PAYOUT`. Order per slot: `BASE`, `FLAT`, `MULTIPLIER`, `COPY`, `MULTIPLIER` (upgrades), `PAYOUT_OVERRIDE` (the card's own, then inspections), `PAYOUT`, `EFFECT_ARMED`, `WASTED`. |
| No change, no step | An override that leaves the value as it is has no step (a 3rd product that is a Soup beside Frozen is already 0: only Soup's own override step). |
| Source | Inspection steps have `source_kind` `INSPECTION` and `source_index` = the inspection's index in the shift's inspections. `slot` and `source_slot` are both the slot the step lands on. The text is the rule's receipt text, or the inspection's name; the receipt prints it after the inspection's name ("Spot check: the 3rd product pays €0"). |
| Copies | A copy never re-triggers an inspection. A Repeat copies the earlier product's final payout, so after an inspected product it copies 0. |

| Inspection | Rule | Data |
|---|---|---|
| Spot check | The 3rd product in the row pays 0. Products are counted in row order and coupons are skipped. Like Soup beside Frozen (section 3.5): the payout becomes 0 after flat bonuses and multipliers, so bonuses aimed at it (a Coffee +3, an upgrade bonus) are spent with no `WASTED` step, and it still uses up an Egg charge. It still arms its own effects (a 3rd Eggs still doubles the next 2 Food payouts, a 3rd Coffee still sends its +3 on). With fewer than 3 products it does nothing and has no step. | `product_number` 3 |

**Inspected shifts.**
- The inspected shifts are the 1-based shift numbers in `inspection_shifts` in balance data (3, 5 and 7). A test checks that each one is a shift of the run and never shift 1, since it is announced on the previous shift's receipt.
- When a shift is passed and the next shift is inspected, checkout draws its inspection uniformly from `inspection_pool` with the run's RNG, after the reward offer and the upgrade offer. An empty pool draws nothing (and uses no RNG), so the shift is played without one. Losing a shift, or winning the last one, announces nothing.
- The announced inspection is kept through the reward and upgrade steps and applies to the next shift only. One shift has at most one inspection in phase 1.
- Run history: each entry also records the inspection its shift was played under (or none).

**Presentation.** On a passed shift followed by an inspected one, the count-up prints the red notice "INSPECTION NEXT SHIFT: …" under the total, before the reward print-out (and so before the kiosk on upgrade shifts); the reward panel repeats it in red, so the pick can take it into account. During the inspected shift a red tag in the top bar shows the notice (hover: the name), and its steps play from that tag. The results screen's history has an Inspection column.

`InspectionDefinition` fields: `id`, `display_name`, `notice_text` (the announcement) and `rules` (scoring). Capacity restrictions (only 5 product slots, the coupon slot is closed) will add run modifiers when they are built in phase 2.

## 4. Architecture (built to last, not thrown away)

The prototype code is the start of the real game. Only the presentation layer is temporary.

```
res://
  core/                 # pure logic: no Nodes, no scene tree, fully testable
    card_definition.gd  # Resource: id, name, kind (UNSET, PRODUCT or COUPON), is_connector, tags, base, rules[], rule_text, generally_useful, art_ref, variant_of, unlock_condition
    deck_definition.gd  # Resource: id, name, description, cards[], starting_upgrade, unlock_condition (full build plan 7.3)
    card_instance.gd    # a reference to a definition + a unique instance id
    rule.gd             # base class for product and coupon rules (hook methods)
    rules/              # one script per reusable rule (shared by cards, numbers set in data)
    effects/            # per-score effects that rules leave for later products
    upgrade_definition.gd # Resource: id, display_name, type, effect_text, condition_text, supported_build, rules[], extra_redraws (3.8)
    upgrades/           # UpgradeRule base class and one script per upgrade rule (numbers set in data, 3.8)
    upgrade_offer.gd    # builds an upgrade offer from the pool with the run's RandomNumberGenerator (3.8)
    inspection_definition.gd # Resource: id, display_name, notice_text, rules[] (3.9)
    inspections/        # InspectionRule base class and one script per inspection rule (numbers set in data, 3.9)
    inspection_schedule.gd # which shifts are inspected; draws an inspection with the run's RandomNumberGenerator (3.9)
    score_state.gd      # working state of one score() call (tags, adjacency, effects, steps)
    scoring.gd          # score(row, upgrades, inspections) -> ScoreResult {total, payouts[], tags[], steps[]}
    score_step.gd       # one explanation line: slot, source (source_kind + slot or index), step_type, value change, text
    deck.gd             # draw, redraw, reward insertion; takes the run's RandomNumberGenerator
    run_stock.gd        # the run's stock: staples, listed aisles, new arrivals, coupon pool (full build 7.2)
    run_state.gd        # stock, deck, shift, quota, seed, redraws, upgrades[], upgrade offer and step, inspections[] and the next one, history
    shift_record.gd     # one run-history entry: shift, quota, total, passed, reward, upgrade (3.8), inspection (3.9), cards played
    row_capacity.gd     # row limits by kind: slot_count products, + coupon_slot_count cards (3.1)
  data/
    cards/*.tres        # one CardDefinition resource per card
    decks/starter.tres  # DeckDefinition (ready for unlockable decks later)
    upgrades/*.tres     # one UpgradeDefinition resource per upgrade (3.8)
    inspections/*.tres  # one InspectionDefinition resource per inspection (3.9)
    aisles/*.tres       # one AisleDefinition resource per aisle (full build 7.2)
    balance/balance.tres # quotas, aisles, coupon pool and stock numbers, upgrade shifts and pool, inspection shifts and pool, tunable without code changes
  ui/                   # scenes: shift screen, reward screen, upgrade ticket panel, loyalty card, results screen with run history
  presentation/         # count-up sequencer: plays back the ScoreResult steps
  debug/                # debug panel (excluded from playtest builds)
  telemetry/            # event logger, log export, upgrade event builders (run_events.gd) (included in playtest builds)
  tests/                # GdUnit4 tests, runnable headless
```

### The scoring pipeline (key decision)

Coupons need to be able to **change the rules**, not only add numbers. So scoring runs in two passes:

1. **Context pass** (the whole row, before any values are calculated): rules can change *tags* ("the product in the next slot gains Breakfast"), and connectors change *adjacency* ("the products on either side of me count as adjacent"). This produces a final list of tags and neighbours for each slot.
2. **Value pass** (left to right): each card, product or coupon, goes through base → flat bonuses → multipliers → payout → effects for later cards, using the results of the context pass (section 3.2).

`kind` tells the passes whether a slot holds a product or a coupon (coupons break adjacency, never receive product effects, and can't be copied by Repeat). `is_connector` marks coupons like Bundle that bridge adjacency instead of breaking it; since v0.23 only Bundle's rule reads it, for the frozen `cards_v0_4` fixture, and no card in a pool sets it (`data/cards/bundle.tres` keeps it, outside every pool). Adjacency changes go through the context hook (`modify_context`) and `ScoreState.link_products`, so coupons and upgrades change adjacency the same way: 2 for 1 and Shelf swap make their links in their own rules, and Bundle's rule reads `is_connector` to treat consecutive connectors as one bridge. It links the product immediately before a run of connectors to the product immediately after it (section 3.4). When either neighbour isn't a product (Bundle at an end of the row, or next to a coupon that isn't a connector), nothing is bridged (section 3.4). Code reads the flags, never card ids. `kind`'s first value is `UNSET`, so every card file must state its kind (Godot doesn't write a value that equals the default).

Every rule overrides only the hooks it needs (`modify_context`, `flat_bonus`, `multiplier`, `copied_from`, `final_payout`, `wasted_reason`, `on_scanned`). Effects a card leaves for later products (Egg charges, a waiting Coffee bonus, Multipack's ×2) are objects that live in the per-score state, so rules stay stateless; an effect reports what it wasted through `waste_reason` (at the end of the row) or `reset_reason` (when a later card of the same group replaces it). Every step type, its fields and the playback order are documented in `core/score_step.gd`. Register upgrades use the same hook names through `UpgradeRule` (section 3.8), and inspections through `InspectionRule` (section 3.9).

The step contract (v0.11):
- **Source.** Every step has a `source_kind`: `CARD` (the card in `source_slot`), `UPGRADE` or `INSPECTION` (entry `source_index` of the run's upgrades or inspections). Card steps have `source_index` 0. Upgrade steps (section 3.8) set `source_slot` to the slot they land on. A non-card source is never a −1 sentinel in `source_slot`: consumers branch on `source_kind`.
- **Armed effects.** When a card's rule registers an effect for later cards (Eggs' charges, Coffee's bonus, Multipack's ×2; every effect goes through `ScoreState.add_effect`), an `EFFECT_ARMED` step follows the card's `PAYOUT`: `slot` and `source_slot` are the arming card, `value` is the effect's bonus or factor from the rule's data, `value_after` is the card's payout and `subtotal` is unchanged, and `text` is the effect's receipt text (the same text as the later steps it causes). A Multipack with no product before it arms nothing and fizzles instead.
- **Order per slot.** `BASE`, `FLAT`, `MULTIPLIER`, `COPY`, `PAYOUT_OVERRIDE`, `PAYOUT`, then one `EFFECT_ARMED` per armed effect, then the card's own `WASTED` steps. Upgrades add their `FLAT` steps after the effects' and their `MULTIPLIER` steps after `COPY`, and their `WASTED` steps after the card's own (section 3.8). Inspections add their `PAYOUT_OVERRIDE` steps after the card's own (section 3.9). An Egg reset arms the new Egg first; the old Egg's "wiped by a reset" `WASTED` step follows straight after. Context-pass steps come before the first slot, and leftover effects fizzle after the last.
- **Consumers.** The receipt prints no line for `EFFECT_ARMED` (what the effect does is printed where it lands, or as its fizzle). The count-up gives it a short beat on the arming card. Totals and every golden total are unchanged.

`score()` is a pure function. The live preview, the receipt explanation, the animated count-up and the tests all use the same `ScoreResult`, so they can never disagree.

## 5. Prototype content

### Products (from the design doc)

| Card | Base | Rule |
|---|---|---|
| Banana | 2 | **+ its base value (+2) as a flat bonus** if immediately after another Banana |
| Bread | 3 | No rule (other cards build on it) |
| Cheese | 3 | +4 if immediately after Bread |
| Eggs | 1 | Double the next 2 Food payouts (resets, does not stack) |
| Milk | 3 | +2 for each earlier Breakfast product |
| Coffee | 2 | +3 to the next Breakfast product |
| Soup | 5 | Pays 0 if beside a Frozen product |
| Frozen peas | 3 | **+ its base value (+3) as a flat bonus** if beside another Frozen product |

### Base aisles (full build phase 2, v0.22)

Decided with the user (issue #34). The 3 base aisles are open from the start (`docs/FULL_BUILD_PLAN.md` section 7.2): 14 products, within the stock budget of 16, so a new profile stocks them all and skips the list. Cheese and Frozen peas move from phase 1's placeholder aisle into Cold cases. Sign colours come from the art palette (section 6.1 there); tomato stays off aisle signs, because inspection notices are red, and each sign shows its name, so colour is never the only signal. Every number is an `@export` field in `data/`; only Scissors needed a new rule script. The numbers are starting values for the simulator (`docs/FULL_BUILD_PLAN.md` section 8).

| Card | Aisle | Base | Rule | Generally useful |
|---|---|---|---|---|
| Cheese | Cold cases (teal) | 3 | +4 if immediately after Bread | |
| Frozen peas | Cold cases | 3 | + its base value (+3) as a flat bonus if beside another Frozen product | |
| Butter | Cold cases | 2 | +3 if beside a Bakery product | yes |
| Yogurt | Cold cases | 2 | +3 if immediately after Banana | |
| Reduced yogurt | Cold cases | 2 | +3 if beside a Clearance product | |
| Cereal | Pantry (mustard) | 2 | +3 if beside Milk | yes |
| Tea bags | Pantry | 1 | Double the next Breakfast payout (its own charges: it never resets Eggs) | |
| Crackers | Pantry | 2 | +3 if beside Soup | |
| Dented can | Pantry | 2 | +2 for each earlier Clearance product | |
| Day-old buns | Pantry | 2 | +3 if immediately after a Clearance product | |
| Carrier bag | Household (grey) | 1 | +1 for each earlier Food product | yes |
| Scissors | Household | 1 | +2 for each earlier coupon | |
| Batteries | Household | 1 | +4 if in the last slot | |
| Flickering bulb | Household | 1 | +3 to the next Clearance product | |

- **Scissors** counts every coupon before it in the row, whether or not that coupon did anything (decided with the user), and none after it. With no earlier coupon it fizzles ("no coupon before it", section 3.5). It counts any coupon, not only coupons in the coupon-only slot.
- **Tea bags** fizzles like Eggs when its charge is unused ("1 charge unused"). Every Tea bags prints Breakfast, so a second Tea always spends the first one's charge: its reset can't happen.
- **Batteries** and **Flickering bulb** fizzle like Final markdown and Coffee ("not in the last slot", "no Clearance product after it").
- The other conditional products pay no bonus when their condition fails, silently, like Banana, Cheese and Milk. Showing those as fizzles is issue #45.

### Coupons (the fun multiplier: 2 from the doc + 3 that create combinations)

| Coupon | Rule | What it tests |
|---|---|---|
| Repeat | Copy the payout of the product just before it | Plain amplification |
| Final markdown | +6 if in the last slot | Position pressure, competes with Repeat |
| **Bundle** | The products on either side of it count as adjacent to each other | Coupons that *enable* combinations instead of breaking them. Replaced by 2 for 1 (v0.23): out of every pool (`bundle.tres` stays in `data/cards/`), and its golden rows stay on `cards_v0_4` |
| **2 for 1** (v0.23) | Same product on both sides: they count as adjacent; the second pays ×2 | An Amplifier that rewards placing a pair around it |
| **Shelf swap** (v0.23) | The product in the next slot also counts as just after the first product | A Connector: adjacency between products that are not neighbours |
| **Breakfast sticker** | The product in the next slot gains the Breakfast tag | Changing tags creates new builds (Banana into a Milk build) |
| **Multipack** | ×2 to every later product that shares a tag with the product just before this coupon | A big multiplier with an ordering puzzle around it |

### Starting deck (13 cards, with an early coupon)

3 Banana, 2 Bread, 2 Milk, 2 Eggs, 2 Coffee, 1 Soup **+ 1 Repeat**.

Coupons are the core of the game, so players meet one from the first shift instead of waiting for a reward.

### Rewards
- Offers draw from the run's stock (`docs/FULL_BUILD_PLAN.md` section 7.2, since v0.17): the starting deck's products, the listed aisles, the new arrivals and `coupon_pool`. Since v0.22 the 3 base aisles (14 products) fit the stock budget and there are no unlocks yet, so the stock is the 6 staples, the 14 base-aisle products and the 6 coupons in `coupon_pool`. Bundle returned as 2 for 1 (v0.23), which takes its place in `coupon_pool` and the first-offer pool, and Shelf swap joins `coupon_pool`; `bundle.tres` stays in `data/cards/`, outside every pool, and its rule stays for the frozen `cards_v0_4` golden fixture.
- **The first reward offer always includes one of the combination coupons** (Breakfast sticker, Multipack or 2 for 1).
- Each later set of 3 offers has at least 1 coupon and at least 1 card that is generally useful (a `generally_useful` flag on the card's data resource, tuned in `data/`, not decided in code). Decided with the user: Bread, Eggs, Milk and Banana are generally useful; Cheese, Coffee, Soup and Frozen peas stay situational. Each base aisle has one: Butter, Cereal and Carrier bag (v0.22).
- The aisles, `coupon_pool` (which replaced `reward_pool` in v0.17), the first-offer pool (Breakfast sticker, Multipack, 2 for 1; a stocked one is offered) and the offer size (3) live in `data/balance/balance.tres`. An offer never shows the same card twice, and never a card outside the run's stock.

## 6. Build schedule (18 hours is the target, 24 is realistic)

The two-pass engine, click-to-place UI, count-up animation, browser export and logging all compete for time. The schedule puts the risky technical parts first.

| Day | Work | Done when |
|---|---|---|
| 1 | Project setup, GdUnit4, **browser export check with an empty scene** (catches export problems early), card data resources, scoring engine with both passes, all tests from section 3.7 | Tests pass headless. An empty web build runs in the browser. |
| 2 | Shift screen: draw, redraw, click-to-place into 6 slots (7 since v0.9, section 3.1), live preview and receipt explanation, deck and seed, debug panel, event logger with all event types, and a **first rough count-up** for checkout (scan, fly-ins from the source card, multiplier stamps, fizzles, ticking subtotal, fast-forward) so the scoring feel is tested from the first playable build | One shift is playable, counted up and logged from start to finish |
| 3 | Count-up polish and sounds, reward screen, 5-shift run, win and lose screens, restart, log export, log summary script, web build uploaded. First playtest with 1–2 people. | A stranger can play a complete run in the browser without being told what to do, and send back the log |

### What gets cut if time runs out (in this order)

1. **Drag-and-drop.** Click-to-place tests selection and ordering just as well.
2. Debug panel features other than the seed
3. The log summary script (read the logs by hand)

**Never cut:** the scoring engine and its tests, the count-up sequence, the event log, the browser build.

## 7. Browser delivery

Playtesters open a link instead of downloading a build. This lowers the barrier for strangers and matches the web demo planned for the full build.

- Godot 4 web export with GDScript (C# could not export to the web)
- **Single-threaded export** so it runs on itch.io without special server headers
- Hosted on a **private itch.io page** (restricted or password-protected), with a Windows build as a fallback
- A "click to start" title screen so browsers allow audio
- Fonts embedded in the build; test in Chrome and Firefox (Safari if possible)
- On the web, `user://` is stored in the browser, so the log has to be exported (section 8)
- **Known risk (day 3, with the log export):** two tabs of the same build share the browser storage, and each tab writes back its own copy of `user://`, so one tab can wipe the other's log. Ask testers to keep one tab open; consider storing each event per key (e.g. through `JavaScriptBridge`) when building the export.
- Every build shows its build label (e.g. `proto-r1`, the project setting `next_customer/build_label`) on the title screen and in the log

## 8. Event log

The prototype writes one JSON line per **event** to `user://playtest_logs/<start time>_<session_id>.jsonl`, where the start time is UTC like `20261005T143000`, so name order is chronological. A **session** is one launch of the game (one page load on the web); its `session_id` is random and made with its own `RandomNumberGenerator`, never the run's. Each line contains:

- `session_id`, `run_id`, `seq` (order number within the session), `build` (the build label), `type`, and the data for that type
- `time`: wall-clock time in ISO 8601 UTC, written as `Time.get_datetime_string_from_system(true) + "Z"` (e.g. `2026-10-05T14:30:00Z`), for matching logs to interviews
- `t_ms`: milliseconds since launch from `Time.get_ticks_msec()`, a monotonic clock used for every duration

At startup the logger creates the folder with `DirAccess.make_dir_recursive_absolute("user://playtest_logs")`, because `FileAccess.open` doesn't create folders. If opening the file returns null, it reports `FileAccess.get_open_error()` through its error reporter (`push_error` by default, a recorder in tests; see `AGENTS.md`) instead of failing silently. Each event is written by opening the file, appending the line and closing it again (`FileAccess.READ_WRITE` then `seek_end()`; `WRITE` and `WRITE_READ` truncate the file, so use them only to create it the first time). On the web, `user://` is persisted to the browser's storage asynchronously and a long-open file is not guaranteed to be saved, so keeping a file open and flushing it is not enough. Test this early: play a few events, close the tab, reopen the build and check the log survived.

Choices and actions that happen after a checkout (rewards, the end of a run, restarts) are their own events. They are not stuffed into the checkout record.

| Event | Data |
|---|---|
| `run_start` | seed (a new random seed for every run, including after a restart), starting deck, number of shifts (`shift_count`, since v0.12), the run's stock (since v0.17): the aisles stocked whole (`listed_aisles`, ids in data order; every listable aisle when the list is skipped) and the stocked card ids in stock order (`stock`). Since v0.18 it is logged once the impulse rack before shift 1 is picked or skipped, with the products offered (`impulse_offer`, ids in offer order; empty without a rack), the one picked (`impulse_pick`, empty for a skip), the deck card it replaced at the 15-card limit (`impulse_replaced`, else empty), the time to decide (`impulse_decide_ms`) and whether the deck view was opened (`impulse_deck_view_opened`); the starting deck is the deck before the rack. Since v0.20 the rack's presentation times, defined as for `reward` (see "Offer presentation times" below): `impulse_presented_ms`, `impulse_armed_ms` and `impulse_presentation_skipped`. Without a rack, for a debug replay of it applied at once, or for a `--demo-row` run, which skips it in code (the player never sees the rack), `impulse_decide_ms`, `impulse_presented_ms` and `impulse_armed_ms` are 0 and `impulse_presentation_skipped` is false; a replayed pick that is refused, or that opens the deck-full chooser, leaves the rack to the player and logs its real times |
| `shift_start` | shift, quota, the 8 cards drawn, the shift's inspections (`inspections`, ids, since v0.14) |
| `redraw` | cards replaced, cards received |
| `checkout` | shift, final order, score, quota, pass or fail, placements, removals, rearrangements, distinct projected totals, planning time, input method (`click`, `drag` or `both`, since v0.15); see the definitions below. The inspection announced for the next shift (`next_inspection`, id or empty, since v0.14). Logged at the checkout click, so closing the game during the count-up loses nothing. |
| `count_up` | shift, count-up time (`count_up_ms`), fast-forward used (`fast_forward_used`). Since v0.20 the taps (see "Count-up input" below): `skip_used`, `skip_at_ms` and `dessert_skipped`. Logged when the count-up ends. |
| `reward` | shift, the 3 cards offered, card picked (empty if skipped), skipped, card replaced (at the 15-card limit, else empty), time to decide (`decide_ms`), whether the deck view was opened. Since v0.20 the offer's presentation times (see "Offer presentation times" below): `presented_ms`, `armed_ms` and `presentation_skipped` |
| `upgrade` | shift, the upgrades offered (`offered`, ids in offer order), the upgrade picked (`picked`), time to decide (`decide_ms`, from the tickets appearing to the pick, like `reward`). Logged after the `reward` event on upgrade shifts (section 3.8); there is no skip. Since v0.13. Since v0.20 the tickets' presentation times, as for `reward`: `presented_ms`, `armed_ms` and `presentation_skipped` |
| `run_end` | win or loss, shift reached, last score, run length (from the run's start, impulse rack included, since v0.18; played time only, across resumes, since v0.19), the upgrades owned (`upgrades`, ids in pick order, since v0.13) |
| `run_resume` | Since v0.19: a saved run continues (`docs/FULL_BUILD_PLAN.md` section 4), logged under the saved run's `run_id`: the shift (1-based), the save point it continues from (`phase`: `impulse_rack`, `planning`, `reward` or `upgrade`) and the played time so far (`run_ms`). No `shift_start` is logged again; a resumed shift's checkout measures count from the resume |
| `run_abandon` | Since v0.19: the title screen's New run abandons a saved run, logged under the saved run's `run_id`: the shift (1-based), the save point (`phase`, as in `run_resume`) and the played time up to its last save (`run_ms`). The run records nothing in the profile |
| `restart` | time since `run_end`, from which screen |
| `log_export` | which screen the export was started from (`impulse_rack` since v0.18), number of session files joined |
| `debug` | which debug action was used and its arguments (development builds only) |

### Checkout measures

| Field | Definition |
|---|---|
| placements | Number of times a card was put into a slot. Moving a card already in the row counts as 1 placement and 0 removals. Redraws don't count. |
| removals | Number of times a card was taken out of the row. Removing one card counts once, even though the cards after it shift left. |
| rearrangements | `placements` minus the number of cards committed. Placing each committed card once gives 0; every extra placement counts 1. |
| distinct projected totals | Number of different preview totals shown for rows with the same number of cards as the committed row. A total seen again counts once. |
| planning time | From `shift_start` to the checkout click, in ms of `t_ms`, minus the time the player was away within that span. On the web, "away" means the page was hidden (`document.visibilitychange`: another tab, minimised): canvas focus would also drop on any click outside the game, e.g. on the itch.io page, while the player can still see the hand. On desktop it means the window was unfocused (`focus_exited` / `focus_entered`). Focus changes after the click don't count. Check this in the browser test: switch tabs during a shift and confirm the planning time doesn't include it. |
| input method | How this shift's placements and removals were made: `click` (click-to-place only), `drag` (drag-and-drop only) or `both`. A shift with neither counts as `click`. A drag counts exactly like the clicks it replaces: a drop on a slot is 1 placement (a move within the row too), and a row card dropped anywhere else goes back to the hand as 1 removal. |
| count-up time | From the checkout click to the moment the final total is shown, in ms of `t_ms` (not including the short pause after it). |

### Offer presentation times (since v0.20)

An offer is the impulse rack (logged in `run_start` with the `impulse_` prefix), a reward (`reward`) or the upgrade tickets (`upgrade`). Its times are in ms of `t_ms`, all measured from the moment the offer **starts presenting** (its panel is shown), so they read as one timeline: presented, then armed, then decided.

| Field | Definition |
|---|---|
| `presented_ms` | Since v0.20. Until the offer is fully shown: today the end of the panel's pop-in (0.22 s of game time, taken when its tween really finishes; in `t_ms` it can land up to a frame early, e.g. on the first frame after loading); later phase 3's reward print-out or kiosk ceremony. |
| `armed_ms` | Since v0.20. Until the offer accepts clicks: today 350 ms after it is shown, once the mouse button is up (so a click meant for the count-up never picks a card or ticket). Until then the top bar's **Deck** button does nothing either, so the deck view can't hide an offer before it arms. |
| `decide_ms` | Unchanged: until the choice is applied (a pick or a skip; at the deck limit, once the card to remove is chosen in the deck-full chooser, so the time spent in the chooser is included). |
| `presentation_skipped` | Since v0.20. The player skipped the offer's presentation. Phase 1 has no skippable offer presentation, so it is always false; phase 3's print-out and kiosk ceremony set it. |

A moment the choice came before is logged as −1 ("not reached"). The panels only take a choice once armed, so in practice only `presented_ms` could be −1, after a very slow frame. An offer shown again after the deck view or the deck-full chooser keeps its first presentation's times (the timeline starts at the first show, as `decide_ms` always did). An offer shown again when a saved run resumes (`run_resume`) starts a new timeline at that show.

The full build's target "non-interactive reward and upgrade time about 15 s or less per run" (`docs/FULL_BUILD_PLAN.md` section 9) is the sum of `armed_ms` over a run's offers: its `reward` and `upgrade` events plus `run_start`'s `impulse_armed_ms`.

### Count-up input (since v0.20)

During the count-up, a press of Space or the left mouse button (anywhere except on a button that can be pressed: Deck and Export log stay clickable, while a press on a disabled one, such as CHECKOUT during its own count, counts) is a **tap** when released within 200 ms, and a **hold** once held longer (`HOLD_THRESHOLD_MS` in `presentation/count_up.gd`). Presses are read from the input events themselves, so a press and release within one frame (a touchpad tap) is still a tap. The checkout click is neither: a press still held when the count-up starts is ignored up to its release, and so is the second click of a double-click on CHECKOUT (a double-click press within 500 ms of the start, `CHECKOUT_DOUBLE_CLICK_MS`; a later one, such as the second of two quick taps, is a tap). A tap after the count-up ends does nothing. Skips only speed the animations up, so every receipt line, sound and shake still happens and the receipt ends up the same.

| Field | Definition |
|---|---|
| `fast_forward_used` | A hold sped the count-up up (×5 while held, from the threshold on). Before v0.20 any press counted, however short; since v0.20 a press released within the threshold is a tap instead. |
| `skip_used` | Since v0.20. At least one tap during this count-up. The first tap plays every remaining step at ×12 up to the final total (the verdict); the part after it (the total slam, pass or fail, the next-shift notice) then plays at normal speed. |
| `skip_at_ms` | Since v0.20. From the checkout click to the first tap, in ms of `t_ms`; −1 without a tap. |
| `dessert_skipped` | Since v0.20. A tap also skipped the part after the total: a second tap, or a first one after the verdict. Everything left plays at ×30. |

The fastest of a hold and the taps wins. `count_up_ms` keeps its meaning (click to final total shown), so after a tap it measures the sped-up count.

**Getting the log back:** an **Export log** button is visible on every screen: title, shift, reward and results. It downloads **every file** in `user://playtest_logs/`, joined into one `.jsonl` file in name order (each line already carries its `session_id`), so sessions from before a reload or a closed tab are included. On the web it uses `JavaScriptBridge.download_buffer`. On desktop it writes the same joined file to `user://playtest_export.jsonl` and opens that folder, so desktop testers also send one file. The `log_export` event is written, and its file closed, **before** the files are read, so the exported file contains it. Playtesters send that one file.

### Log summary (since v0.21)

`tools/log_summary.py` (Python 3.11+, standard library only; the command is in `AGENTS.md`) summarises the logs on stdout and in `reports/log_summary/report.txt`; `--json=<path>` also writes the same numbers as JSON. Every rate is printed with its counts, and as "-" when nothing was counted. It exits with 0, or 2 on bad arguments (including a `--report` or `--json` path that can't be written, checked before anything is printed, or a `--data` folder with no `cards/*.tres`) or input with no readable event. Its measures, as built (decided with the user):

- **Players and runs.** Each input file is one player (each tester sends one exported file); a folder means every `.jsonl` file in it, each one player, named by its file name (or folder/name when two inputs share a name, as every desktop `playtest_export.jsonl` does). Files that share a `session_id` are joined into one player and the report says so: an export holds every session of its install, so they are the same tester's exports (a later one that grew), and a run or a session is never split between players. The game's own `playtest_logs` folder holds one file per session, so `--one-player` treats every file given as one player; with no path, the desktop game's folder (`%APPDATA%/Godot/app_userdata/Next Customer/playtest_logs`) is read as one player and its files are listed. A run is one `run_id`, joined across the player's sessions (`run_resume` continues it, `run_abandon` ends it as abandoned), and runs are ordered by their first event (`time`, then session order): **run 2** is the player's second run. Events with the same `session_id` and `seq` count once (a file given twice, or the same session in two exports); malformed lines are skipped and counted; unknown event types are ignored; missing fields (older builds) leave their measure out, and so do numbers that are not finite or beyond 10^15, and a `shift` or `shift_count` that is not a whole number from 1 to 99. The report lists the build labels present, and `--build=<label>` keeps whole runs by the build they started on (their `run_start`'s label, else their first event's), so a run resumed on a later build stays whole; run numbers still count every run of the player, and events outside runs (restarts) are kept by their own label.
- **Debug runs** are left out by default (development play) and counted; `--include-debug` keeps them. A run is a debug run when a `debug` event carries its `run_id`, or when it is the next run after a `set_seed` debug event or a `skip_to_shift` from an ended run (both are logged under the old run just before the new one starts): the session's next `run_start`, or, since the impulse rack is a save point and `run_start` is only logged once it is picked, a run resumed or abandoned at its impulse rack in that session or a later one. A later run whose `run_start` `seed` is that action's seed (`set_seed`'s, or the ended run's) is a debug run too.
- **Runs:** started, won or lost (`run_end`'s `result`), abandoned (`run_abandon`), unfinished (neither); runs without a `run_start` are counted by cause: abandoned or unfinished at the impulse rack (a `run_abandon` or `run_resume` with phase `impulse_rack`, since `run_start` is only logged once the rack is picked or skipped), else started in a session not given; win rate = won / (won + lost); **restart rate** = `restart` events / `run_end` events, also by screen; runs resumed (with a `run_resume`).
- **Rearrangements per checkout:** the median, mean, 90th percentile and a distribution of the logged `rearrangements`, the same for placements, removals, distinct projected totals and planning time, and the share of each input method. **High / Low** as in "How to read the numbers" below: a checkout of 3 or more cards (`final_order`) is High when its rearrangements are at least twice its cards; a player is High when more than half of their counted checkouts are.
- **Pick rates:** for each card, picks / times offered over `reward` events, with each run's **first reward offer** (its `reward` with the lowest `shift`; it always holds a combination coupon) reported apart from the later ones; coupons and products alike. Also the reward skip rate (skipped / rewards), the impulse rack's pick and skip rates over the racks shown (`run_start` with a non-empty `impulse_offer`, leaving out never-shown racks with all times 0, a debug replay or a `--demo-row` run, which are counted) with each product's picks / offers, and the most-picked products (reward picks and the shown racks' picks).
- **Builds:** each won or lost run's final deck is rebuilt from `run_start` (`starting_deck`, then `impulse_pick` replacing `impulse_replaced`) and every `reward` (`picked` replacing `replaced`). Its **build** is the final deck's coupons with their copies (e.g. "Multipack x2 + Repeat") plus the upgrades taken (`run_end`'s `upgrades`, else the `upgrade` events' picks). A card is a coupon or a product by its `kind` in `data/cards/`, never a list in the script; an unknown id is reported. Each build's runs and win rate (won / runs), and each coupon set alone.
- **Win rate per shift:** for each shift n, checkouts at shift n that passed / checkouts at shift n, with the runs that reached it (a `shift_start` or `checkout` at n), grouped by `run_start`'s `shift_count` (unknown for a `run_start` before v0.12; proto-r1 had 5 shifts); runs without a `run_start` are left out and counted.
- **Win rate per list:** runs grouped by `run_start`'s `listed_aisles` (sorted; every listable aisle when the list is skipped), with won / (won + lost).
- **Offer presentation times:** `presented_ms`, `armed_ms` and `decide_ms` per offer type (impulse rack, reward, upgrade), leaving out −1 ("not reached") values and offers never shown (a debug or `--demo-row` rack, all times 0), which are counted. **Non-interactive offer time** per run is the sum of `armed_ms` over its shown offers, against the full build's target of about 15 s or less (for all runs, won runs, run 1 and run 2). It covers ended (won or lost) runs whose every shown offer logged `armed_ms`; runs not ended and partial runs (an offer without `armed_ms`, logged before v0.20, or with −1) are left out and counted.
- **Count-up:** `count_up_ms`; the rates of `fast_forward_used`, `skip_used` and `dessert_skipped` over the `count_up` events that log them; `skip_at_ms` over the taps.
- **Second-run skip rate:** `presentation_skipped` over run 2's shown offers (its rewards, upgrades and impulse rack), against the full build's target of fewer than about 70% (`docs/FULL_BUILD_PLAN.md` section 9). It is always 0% until phase 3 adds skippable presentations, and the report says so. The count-up tap rate (`skip_used`) and `dessert_skipped` over run 2's `count_up` events are reported beside it, separately, and all three over all runs.

### How to read the numbers

**A high rearrangement count is a clue, not proof of blind shuffling.** A player might rearrange a lot because they are exploring combinations on purpose. Always combine the count with the interview (section 9).

Provisional threshold, for checkouts of 3 or more cards: a checkout is **High** when its rearrangements are at least twice the number of cards committed (14 or more for a full 7-card row), otherwise **Low**. Checkouts of 0–2 cards are left out. A player is High when most of their checkouts are. Re-check the threshold against the first round's logs and record any change in the changelog.

| Rearrangements | Player can explain the payout and why they chose the order | Interpretation |
|---|---|---|
| High | Yes | Exploring: likely fine, maybe the preview is used as a calculator |
| High | No | Probably blind shuffling: a problem |
| Low | Yes | Understands the combinations: the goal |
| Low | No | Not engaging with the order: a problem |

## 9. Playtest protocol and decision gate

### Protocol

- **Who:** 5–8 people who like short strategy games, ideally not friends who have heard the design.
- **How:** send them the browser link and a single sentence ("meet the quota each shift"). If you can watch (in person or screen share), watch silently and don't teach. Ask everyone to export the log at the end.
- **Afterwards, ask:**
  1. Explain how your biggest checkout scored.
  2. Why did you put your cards in that order on your last shift?
  3. Which coupon did you like most, and why?
  4. Was there a moment when you found a combination by yourself?
  5. Did you want to play again? (Check in the log whether they restarted on their own before you asked.)
  6. What was confusing?

Questions 1 and 2 are what turn the rearrangement count into a real signal (section 8).

Not run: the prototype closed at proto-r1 after the developer's own runs. The gate's questions move to the full build's playtest rounds (`docs/FULL_BUILD_PLAN.md`, section 9).

### Decision gate after each round

| Result | Signals | Next step |
|---|---|---|
| **Go** | Most players can explain a payout and their order, find a coupon combination on their own, and restart voluntarily | Start the full build (phase 1) |
| **Iterate** | The core is promising, but specific problems appear (section 10) | One iteration round, up to about 6 hours, changing one major variable at a time, then retest |
| **Pivot** | Ordering is ignored or feels like solving a spreadsheet, even after an iteration | Change the core mechanic (see the bottom rows of section 10) |
| **Stop** | Two iteration rounds without improvement in replay intent | Stop or rethink the concept |

At most **2 iteration rounds** (about 12 hours in total) before a Go / Pivot / Stop decision is forced.

## 10. Likely iterations from playtests

These are prepared answers to likely findings. Choose based on what is actually observed, not in advance.

| Observation | Possible iterations (choose one at a time) |
|---|---|
| **Players seem to shuffle blindly** (a high rearrangement count *and* they cannot explain their order or the payout) | Show the change in total when hovering a slot instead of the full preview · show the full total only after placing all cards · reduce the hand to 7 · simplify the rule text |
| **Players ignore the order** (they put the cards in any order and pass) | Raise quotas · make adjacency rules stronger · add more cards that depend on position |
| **Coupons feel weak or optional** | Raise multiplier values · let a coupon not use up a slot (place it *between* products) · a second coupon in the starting deck |
| **Coupons too strong, one combination dominates** (e.g. Multipack + Repeat every run) | Limit Multipack to the next 3 products · Repeat cannot copy a payout that was multiplied by a coupon · stacked Multipacks don't multiply each other · add a coupon limit per checkout |
| **Everyone drafts the same build** | Change the reward offers · make duplicates weaker · test new products that pull in a different direction |
| **Bad draws feel unfair** | 2 redraws instead of 1 · a smaller starting deck · a softer quota curve · draw 9 |
| **Counting feels flat** | Faster pacing at the start · rising pitch with each bonus · bigger print line for multipliers · a short pause before the final total |
| **Counting too slow** | Auto speed-up after the first shift · hold-to-fast-forward by default · combine flat bonuses into one line |
| **Click-to-place feels clumsy** | Add drag-and-drop (if it was cut) · keyboard number keys for slots |
| **Runs too short or too easy** | Increase quotas from shift 3 · prepare the 8-shift structure for the full build |
| **Hand management is the fun, not ordering** (pivot) | Fewer slots, more discards: the choice moves to which cards to keep |
| **The receipt is the fun, not the decisions** (pivot) | More automatic chains, fewer manual choices: the game moves towards an idle or arcade feel |

Rules for iterating: **one major variable per round**, card values tweaked only in data files, every round tagged in git (`proto-r1`, `proto-r2` …) and listed in the changelog.

## 11. Changelog

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-10-05 | First plan, before development |
| v0.2 | 2026-10-05 | Banana and Frozen peas use "+ base as a flat bonus" · stacking and adjacency fully specified, with more test cases · a coupon in the starting deck and a combination coupon in the first reward · browser delivery for playtests · event log with separate reward, run-end and restart events, plus log export · rearrangement count treated as a clue combined with the interview · click-to-place first, drag-and-drop cut first · realistic estimate of 18–24 hours |
| v0.3 | 2026-10-05 | Deck limit lowered from 18 to 15 so replacement is reachable · event log opens, appends and closes per event (web persistence) · golden tests run on frozen card data · the debug panel is excluded from playtest builds and its use is logged · rules are stateless · 9 more required test cases · a `generally_useful` card flag · engine version pinned in `AGENTS.md` only · rule numbers live in data · all randomness uses the run's seeded RNG |
| v0.4 | 2026-10-05 | Coupons go through the value pass at their own slot (base 0, no tags) · card definitions get `kind` and `is_connector`, plus a `DeckDefinition` script · 9 more required test cases (none depends on an unresolved question), and test 8 notes that Food is also shared · the golden fixture (`cards_v0_4`) is self-contained and built by hand, and rule scripts use neutral `@export` defaults · the debug panel is excluded from playtest exports (`debug/*`) and loaded only without the `playtest` tag · a restart uses a new seed from an RNG outside `core/` · Bundle bridges through the context hook and uses `is_connector` to join consecutive connectors; its edge cases stay unresolved · `kind` starts at `UNSET`, and the step field is `step_type` · scripts outside `debug/` never name `debug/` classes · every coupon gets a receipt line, even at 0 · the build label is the project setting `next_customer/build_label` · the log summary script is in scope (day 3) · Breakfast sticker text says "next slot" · the cut list holds only items in scope · a test loads every scene and resource in the game folders and the fixture (section 3.7), and `tools/test.sh` fails on any Godot error · code that reports errors takes an injectable reporter, so tests never print errors · event log: sessions with time-ordered file names, `time` (exact format) and `t_ms`, planning time paused on window focus loss (works on the web), desktop export also writes one joined file, `reward` records the shift, folder creation and open errors, checkout measures defined, provisional High threshold, export bundles every session file from any screen, `log_export` written before the export, coupon pick rate per offer |
| v0.5 | 2026-10-06 | Decided with the user before building the scoring engine: Soup's final payout becomes 0 (bonuses aimed at it are spent) · a product that pays 0 still uses an Egg charge · Bundle bridges nothing when a neighbour isn't a product · an unused Coffee bonus is lost · a Breakfast sticker on a Breakfast product is wasted · every shift draws from the whole deck, freshly shuffled · 6 test rows for these decisions, plus 3 found by mutation testing (41 in total) · wasted effects get their own receipt step ("fizzles"), and the scoring must be juicy · hook names and the `core/` tree match the engine (`copied_from`, `final_payout`, `wasted_reason`, `effects/`, `score_state.gd`, `rule_text`) · a copy step always names the copied slot, and an Egg reset's fizzle names the Egg that reset it |
| v0.6 | 2026-10-06 | Checkout is always allowed, even with an empty or one-card row (decided with the user) · a first rough count-up moves into day 2, so juice is tested from the first playable build; day 3 polishes it and adds sound · `checkout` is logged at the click and a new `count_up` event carries count-up time and fast-forward · on the web, planning time pauses only while the page is hidden · known risk noted: two open tabs can overwrite each other's log |
| v0.7 | 2026-10-06 | Day 3: generally useful cards decided with the user (Bread, Eggs, Milk, Banana) · reward pool, first-offer pool and offer size in balance data · `reward` event fields spelled out · placeholder sounds generated by `tools/make_sfx.py`, receipt in JetBrains Mono (SIL OFL) · in-game buttons never take keyboard focus (Space is the fast-forward key) · reward and results buttons only react once the mouse is released after they appear · a shade blocks clicks behind panels · `deck_view_opened` counts only views the player chose |
| v0.8 | 2026-10-06 | Closed at proto-r1 after the developer's runs; the outside playtest and decision gate were not run, and their questions move to the full build's playtest rounds · this plan stays the scoring-rule spec · decisions taken from the runs (coupon slots, Bundle as "2 for 1", run stock) are recorded in `docs/FULL_BUILD_PLAN.md` v0.5 and land here when phase 1 or 2 changes the rule |
| v0.9 | 2026-10-06 | Coupon slots, decided with the user (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 5.1): the row has 6 shared slots + 1 coupon-only slot, at most 6 products and 7 cards (`coupon_slot_count` in balance data, checked by `kind` in `RunState.can_place`) · the row stays flat and compacted, coupons still break adjacency, scoring and every golden total are unchanged · the shift screen shows 7 identical slots (no panel is marked as the coupon slot, so coupons don't look tied to one position), a "Products n/6 · Coupon slot n/1" count, and a short notice when a product doesn't fit · the section 8 High threshold for a full row is now 14 rearrangements (twice 7 cards) |
| v0.10 | 2026-10-06 | Bundle out of the offer pools (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 5.1): removed from `reward_pool` and `first_offer_pool` in balance data until it returns as "2 for 1" in phase 2 · the first-offer pool is now Breakfast sticker or Multipack, so Multipack fills the guaranteed first-offer slot 50% of the time instead of 33%; read coupon pick rates with that in mind · `bundle.tres` stays in `data/cards/` outside every pool, and its rule and golden rows stay on the frozen `cards_v0_4` fixture · scoring and every golden total are unchanged |
| v0.11 | 2026-10-06 | Score step contract (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 4): every step has a `source_kind` (`CARD`, `UPGRADE`, `INSPECTION`) and a `source_index` for non-card sources, never a −1 sentinel; all steps are `CARD` today · a new `EFFECT_ARMED` step right after a card's `PAYOUT` for each effect it arms for later cards (Eggs, Coffee, Multipack), with the effect's bonus or factor and receipt text; the card's own fizzles now come after it, and an Egg reset's fizzle follows the new Egg's `EFFECT_ARMED` (section 4) · `to_dictionary()` gains `source_kind` and `source_index` · the receipt prints no line for it; the count-up plays a short beat (the arming card glows and pulses, the effect's name floats up, a soft high "bonus" sound, about 0.18 s; fast-forward speeds it up like every beat), so a row with armers plays about 0.2 s longer per armed effect · the count-up looks up a step's source card only when `source_kind` is `CARD` · scoring and every golden total are unchanged |
| v0.12 | 2026-10-06 | 8 shifts (full build phase 1, `docs/FULL_BUILD_PLAN.md`): quotas 10 / 13 / 17 / 22 / 27 / 33 / 40 / 48 in `data/balance/balance.tres`, chosen with the user as placeholders until the balance simulator (phase 2) · the number of shifts is the number of quotas; the shift header, results screen, last-shift win and the debug panel's shift jump all follow it · `run_start` gains `shift_count`, so `shift_reached` in `run_end` reads against it (proto-r1 logs have 5 shifts) · scoring and every golden total are unchanged |
| v0.13 | 2026-10-06 | Upgrades (full build phase 1, section 3.8; `docs/FULL_BUILD_PLAN.md` section 5.2), decided with the user: 3 placeholder upgrades in `data/upgrades/` (Coupon engine: the first coupon pays ×2, fizzling when it pays nothing; Category engine: +3 per different product tag on the last product; Extra redraw: one more redraw each shift) · `score(row, upgrades)`: upgrade flat bonuses after effects, upgrade multipliers after effects and after a copy, upgrade steps with `source_kind` `UPGRADE` and `source_index`; with no upgrades every result and every golden total is unchanged · a shift allows 1 + `extra_redraws` redraws · after the reward pick or skip on the shifts in `upgrade_shifts` (2, 4, 6), the player **must** pick 1 of up to `upgrade_offer_size` (3) unowned upgrades of different types from `upgrade_pool`, built at checkout from the run's RNG (with 3 placeholders the offers hold 3, 2 and 1) · run history: one entry per played shift · shift screen: after the reward (and any deck-full replacement) on an upgrade shift, a plain ticket panel ("EXIT KIOSK: pick your prize") shows 1–3 tickets with the fields name, type, effect, condition (its own line, "No condition" when empty) and supported build; no skip button, tickets react only once the mouse is released after the panel appears, the shade blocks clicks behind it, and the top bar's Deck button opens the deck and comes back to the tickets · loyalty card greybox beside the shift and quota: one box per upgrade shift, a picked upgrade stamps the next box with its initials (first word's first two letters plus the other words' initials, so "Coupon engine" CoE and "Category engine" CaE differ) with a stamp punch and the stamp sound; hovering a stamped box shows its name, type, effect and condition · count-up: upgrade bonuses and factors fly in from the upgrade's box, its fizzles puff out of the box; receipt lines name the upgrade · the redraw button shows the redraws left ("Redraw up to 2 (1 left)") · the results screen lists the run history (shift, total / quota, pass or fail, card picked or skipped, upgrade taken) · event log: a new `upgrade` event (shift, offered, picked, `decide_ms`), and `run_end` gains `upgrades` (section 8) · debug panel: give an upgrade directly (restarts the current shift with a fresh hand) |
| v0.14 | 2026-10-06 | Inspections (full build phase 1, section 3.9; `docs/FULL_BUILD_PLAN.md` section 5.3), decided with the user: 1 placeholder inspection in `data/inspections/`, Spot check: the 3rd product pays 0, like Soup beside Frozen (products only, after bonuses and multipliers, bonuses aimed at it spent, it still uses an Egg charge and still arms its own effects, a Repeat after it copies 0) · `score(row, upgrades, inspections)`: inspection payout overrides after the card's own, steps with `source_kind` `INSPECTION` and `source_index`; with no inspections every result and every golden total is unchanged · `inspection_shifts` (3, 5, 7) and `inspection_pool` in balance data: a passed shift before an inspected one draws its inspection from the run's RNG after the reward and upgrade offers · run history records each shift's inspection · count-up: a red "INSPECTION NEXT SHIFT" notice under the total, before the reward and the kiosk; the reward panel repeats it; a red tag in the top bar during the inspected shift, where its steps play from · results screen: an Inspection column · event log: `inspections` in `shift_start`, `next_inspection` in `checkout` (section 8) · debug panel: set or clear the shift's inspection (restarts the shift) · balance simulator: inspected shifts are searched under their inspection, and the search cache keeps them apart |
| v0.15 | 2026-10-06 | Drag-and-drop on top of click-to-place (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 3): a press still picks a card up as a click does; moving 8 px with the button held drags it (a ghost card follows the mouse; the slot where it would land lights up, or the card there that would be pushed right, and nothing lights up where it cannot go); releasing on a slot places it there (a filled slot pushes the cards right, like a click), anywhere else lets go (a row card goes back to the hand). A card already picked up can be dragged too: a click on it now lets go on the release instead of the press. No scoring or rule change · event log: `input_method` in `checkout` is `click`, `drag` or `both` (section 8) |
| v0.16 | 2026-10-06 | Unlock data model (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 7.3), decided with the user: deck description, starting upgrade (owned from the first shift, first in the run's upgrades, skipped by offers, a pre-stamped loyalty-card box) and unlock condition; card `variant_of` and unlock condition · the run history records each shift's checked-out cards (`played`), for coupon-use unlocks. No scoring change |
| v0.17 | 2026-10-06 | Run stock (full build phase 1, `docs/FULL_BUILD_PLAN.md` section 7.2): reward offers draw from the run's stock, built before the run by a pure `RunStock` (staples, listed aisles, new arrivals, `coupon_pool`, each in data order) and passed to `RunState` · `reward_pool` becomes `coupon_pool` (Repeat, Final markdown, Breakfast sticker, Multipack); the first offer's combination coupon must be stocked · `AisleDefinition` in `data/aisles/`, with one placeholder base aisle (Cheese, Frozen peas); the budget rule stocks it, so the stock holds the same 12 cards as the old reward pool. Its order is new (staples first), so a seed's reward offers differ from v0.16 · event log: `listed_aisles` and `stock` in `run_start` (section 8). No scoring change |
| v0.18 | 2026-10-07 | Impulse rack (full build phase 1, `docs/FULL_BUILD_PLAN.md` v0.12, section 7.2): event schema only, no rule change · `run_start` is logged after the rack choice and adds `impulse_offer`, `impulse_pick`, `impulse_replaced`, `impulse_decide_ms` and `impulse_deck_view_opened`; `starting_deck` is the deck before the rack · run length includes the rack · `log_export` can name the `impulse_rack` screen |
| v0.19 | 2026-10-07 | Save and resume (full build phase 1, `docs/FULL_BUILD_PLAN.md` v0.14, section 4): event schema only, no rule change · new `run_resume` (shift, phase, `run_ms`) and `run_abandon` (shift, phase, `run_ms`) events, logged under the saved run's `run_id` · `run_end`'s run length counts played time only, across resumes |
| v0.20 | 2026-10-07 | Telemetry additions and the count-up tap (full build phase 1, `docs/FULL_BUILD_PLAN.md` v0.15, sections 3 and 6.2), decided with the user: event schema and count-up input only, no rule change · offers (the impulse rack, rewards, the upgrade tickets) log a presentation timeline from the offer's show: `presented_ms` (fully shown: the pop-in's end), `armed_ms` (accepts clicks) and `presentation_skipped` (always false until phase 3's ceremonies), beside the unchanged `decide_ms`, on `reward` and `upgrade` and as `impulse_presented_ms`, `impulse_armed_ms` and `impulse_presentation_skipped` on `run_start`; −1 for a moment the choice came before; the full build's non-interactive reward and upgrade time is the sum of `armed_ms` (section 8); the top bar's Deck waits for the offer to arm · count-up: a press released within 200 ms is a tap; the first tap speeds the count to the verdict (×12), a second tap (or a first one after the verdict) skips the dessert (×30); only a press held past 200 ms fast-forwards (×5); the checkout click and clicks on buttons that can be pressed are neither; presses are read from input events, so a same-frame tap counts; skips never cut a line, sound or shake · `count_up` gains `skip_used`, `skip_at_ms` and `dessert_skipped`; `fast_forward_used` no longer counts short presses · the shift screen's hint reads "tap Space or the mouse to skip the count, hold to fast-forward" |
| v0.21 | 2026-10-08 | Log summary script (full build phase 1, `docs/FULL_BUILD_PLAN.md` v0.16, section 3), decided with the user: tooling only, no rule or event change · `tools/log_summary.py`, Python standard library only, with unittest tests that `tools/test.sh` runs in its full run · each input file is one player (`--one-player` for the game's own per-session folder, the default input), and files that share a session (a tester's two exports) are one; runs joined across sessions by `run_id` and ordered by their first event, so run 2 is the player's second run · debug runs left out by default · the measures are defined in section 8 ("Log summary"): the prototype's (rearrangements and High / Low, pick rates with the first reward offer apart, win rate per shift, builds, restart rate) plus the v0.20 offer and count-up fields, win rate per list, the non-interactive offer time and the second-run skip rate (`presentation_skipped` over run 2's offers, with the count-up tap and dessert skips reported separately) · a build is the final deck's coupons, rebuilt from `run_start` and the `reward` events with each card's `kind` read from `data/cards/`, plus the upgrades taken |
| v0.22 | 2026-10-08 | Base products (full build phase 2, `docs/FULL_BUILD_PLAN.md` v0.19, issue #34), decided with the user: the 3 base aisles replace the placeholder aisle: Cold cases (Cheese, Frozen peas, Butter, Yogurt, Reduced yogurt), Pantry (Cereal, Tea bags, Crackers, Dented can, Day-old buns) and Household (Carrier bag, Scissors, Batteries, Flickering bulb), 12 new products (section 5) · new tags Household and Clearance (3.6) · Scissors' new rule counts every earlier coupon and fizzles with none (3.5); Tea bags, Batteries and Flickering bulb reuse existing rules and their fizzles · the reward stock is now 20 products and 4 coupons · Butter, Cereal and Carrier bag are generally useful · no change to existing cards or golden totals |
| v0.23 | 2026-10-08 | 2 for 1 and Shelf swap (full build phase 2, `docs/FULL_BUILD_PLAN.md` v0.20, issue #37), decided with the user: adjacency links work both ways and one side can hold several products (3.4) · "same product" is the same card, a variant counting as its base card, everywhere a rule compares products, including rules that name a card (3.4) · 2 for 1: same product on both sides, linked, the second pays ×2 as an armed effect; otherwise it fizzles, two in a row both fizzle · Shelf swap: the next product also counts as just after the row's first product (coupons skipped); it fizzles with no product next, or when that product is the first · `is_connector` is read only by Bundle's rule for the frozen fixture · new golden fixture `cards_v0_5` with 9 rows (3.7); every `cards_v0_4` row unchanged · 2 for 1 takes Bundle's place in `coupon_pool` and the first-offer pool, and Shelf swap joins `coupon_pool` (section 5) |
