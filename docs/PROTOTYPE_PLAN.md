# Next Customer: Prototype Plan

> Status: v0.9, closed at proto-r1. The full build (`docs/FULL_BUILD_PLAN.md`) has taken over; this plan stays the scoring-rule spec (sections 3–5) and changes only when a rule does.
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
- A run of 5 shifts with quotas 10 / 15 / 22 / 32 / 48 (placeholders)
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
   2. **+ all flat bonuses** (its own rule, Coffee bonuses waiting for it, and so on)
   3. **× all multipliers** (Eggs charges, Multipack, …)
   4. Payout added to the subtotal
   5. Its effects for later cards become active (Eggs charges, Coffee bonus, Multipack's ×2, …)

Coupons go through the same steps at their own slot. A coupon has base 0 and no tags, so it never receives an Egg charge, a Coffee bonus, a Multipack ×2 or any other effect aimed at products. Its payout comes only from its own rule: Final markdown's +6 is its own flat bonus, and Repeat's payout is the copy (section 3.3). Every coupon appears on the receipt, even when it pays 0.

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
| Repeat | Copies the final payout (after all flat bonuses and multipliers) of the product just before it. The copy is never multiplied again and never triggers effects. |

### 3.4 Adjacency

| Term | Meaning |
|---|---|
| "Immediately after X" | The slot just before this card holds X, after the context pass |
| "Beside X" | The slot just before or just after this card holds X |
| A coupon between two products | **Breaks adjacency** between them, unless the coupon is a connector (Bundle) |
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
| Wasted effects ("fizzles") | Every effect that does nothing gets its own 0-value receipt step, so the count-up can play a small "fizzle" on that card and players learn why an order was worse: a Coffee bonus with no later Breakfast product · Egg charges left unused, or wiped by a later Egg's reset · a Breakfast sticker on a coupon, an empty slot or a product that is already Breakfast · a Bundle that bridges nothing · a Multipack with no product before it, or whose ×2 hits no later product · Repeat with nothing to copy · Final markdown outside the last slot. The scoring needs to be **juicy**: the steps carry everything the count-up needs (source slots for fly-ins, separate multiplier steps for stamps, running values, fizzles). |

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

Golden rows use a frozen copy of the card data, `tests/fixtures/cards_v0_4/` (named for the rules version it froze), so tuning values in `data/` between playtest rounds doesn't break them. The live data gets its own tests with expected totals that are updated when values change.

How the fixture is built:
- It is **self-contained**: each card `.tres` embeds its rule resources as sub-resources and references nothing in `data/`. A test checks that no file in the fixture mentions `res://data/`.
- Write it by hand from the values in sections 3.6 and 5. If you start from copies of `data/` files, remove their `uid=` strings and let Godot assign new ones on import, because two resources must never share a UID.
- It freezes **values**, not rule scripts. Rule scripts are shared with the game, so changing a rule script can still change golden totals, and that is a rule change that needs approval.
- Rule scripts give every `@export` number a neutral default (0 for bonuses, 1 for multipliers, 0 for charges). Godot doesn't write a value to a `.tres` file when it equals the script default, so a non-neutral default would let a script change silently alter the fixture.

No row may depend on a question that is still in the unresolved table of `core/AGENTS.md`.

Also tested: duplicate cards are separate instances · the redraw cannot bring back a card that was just replaced · the same seed gives the same draws · a restart uses a new seed (the test injects the seed source) · every `@export` number in a rule script defaults to its neutral value · no card in `data/` or the fixture has `kind` left at `UNSET` · every `.tres` and `.tscn` in `data/`, `ui/`, `presentation/`, `debug/`, `telemetry/` and the fixture loads, and is of the expected type (`tools/test.sh` also fails on any Godot error printed while loading).

## 4. Architecture (built to last, not thrown away)

The prototype code is the start of the real game. Only the presentation layer is temporary.

```
res://
  core/                 # pure logic: no Nodes, no scene tree, fully testable
    card_definition.gd  # Resource: id, name, kind (UNSET, PRODUCT or COUPON), is_connector, tags, base, rules[], rule_text, generally_useful, art_ref
    deck_definition.gd  # Resource: id, name, cards[]
    card_instance.gd    # a reference to a definition + a unique instance id
    rule.gd             # base class for product and coupon rules (hook methods)
    rules/              # one script per reusable rule (shared by cards, numbers set in data)
    effects/            # per-score effects that rules leave for later products
    score_state.gd      # working state of one score() call (tags, adjacency, effects, steps)
    scoring.gd          # score(row) -> ScoreResult {total, payouts[], tags[], steps[]}
    score_step.gd       # one explanation line: slot, source, step_type, value change, text
    deck.gd             # draw, redraw, reward insertion; takes the run's RandomNumberGenerator
    run_state.gd        # deck, shift, quota, seed, (later: upgrades, inspection)
    row_capacity.gd     # row limits by kind: slot_count products, + coupon_slot_count cards (3.1)
  data/
    cards/*.tres        # one CardDefinition resource per card
    decks/starter.tres  # DeckDefinition (ready for unlockable decks later)
    balance/quotas.tres # quotas and reward pool, tunable without code changes
  ui/                   # scenes: shift screen, reward screen, results screen
  presentation/         # count-up sequencer: plays back the ScoreResult steps
  debug/                # debug panel (excluded from playtest builds)
  telemetry/            # event logger, log export (included in playtest builds)
  tests/                # GdUnit4 tests, runnable headless
```

### The scoring pipeline (key decision)

Coupons need to be able to **change the rules**, not only add numbers. So scoring runs in two passes:

1. **Context pass** (the whole row, before any values are calculated): rules can change *tags* ("the product in the next slot gains Breakfast"), and connectors change *adjacency* ("the products on either side of me count as adjacent"). This produces a final list of tags and neighbours for each slot.
2. **Value pass** (left to right): each card, product or coupon, goes through base → flat bonuses → multipliers → payout → effects for later cards, using the results of the context pass (section 3.2).

`kind` tells the passes whether a slot holds a product or a coupon (coupons break adjacency, never receive product effects, and can't be copied by Repeat). `is_connector` marks coupons like Bundle that bridge adjacency instead of breaking it. Adjacency changes still go through the context hook (`modify_context`), so later coupons and upgrades can change adjacency the same way; Bundle's rule uses that hook and reads `is_connector` to treat consecutive connectors as one bridge. It links the product immediately before a run of connectors to the product immediately after it (section 3.4). When either neighbour isn't a product (Bundle at an end of the row, or next to a coupon that isn't a connector), nothing is bridged (section 3.4). Code reads the flags, never card ids. `kind`'s first value is `UNSET`, so every card file must state its kind (Godot doesn't write a value that equals the default).

Every rule overrides only the hooks it needs (`modify_context`, `flat_bonus`, `multiplier`, `copied_from`, `final_payout`, `wasted_reason`, `on_scanned`). Effects a card leaves for later products (Egg charges, a waiting Coffee bonus, Multipack's ×2) are objects that live in the per-score state, so rules stay stateless; an effect reports what it wasted through `waste_reason` (at the end of the row) or `reset_reason` (when a later card of the same group replaces it). Every step type, its fields and the playback order are documented in `core/score_step.gd`. Register upgrades and inspections in the full build will use the **same hooks**, so no rewrite will be needed.

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

### Coupons (the fun multiplier: 2 from the doc + 3 that create combinations)

| Coupon | Rule | What it tests |
|---|---|---|
| Repeat | Copy the payout of the product just before it | Plain amplification |
| Final markdown | +6 if in the last slot | Position pressure, competes with Repeat |
| **Bundle** | The products on either side of it count as adjacent to each other | Coupons that *enable* combinations instead of breaking them |
| **Breakfast sticker** | The product in the next slot gains the Breakfast tag | Changing tags creates new builds (Banana into a Milk build) |
| **Multipack** | ×2 to every later product that shares a tag with the product just before this coupon | A big multiplier with an ordering puzzle around it |

### Starting deck (13 cards, with an early coupon)

3 Banana, 2 Bread, 2 Milk, 2 Eggs, 2 Coffee, 1 Soup **+ 1 Repeat**.

Coupons are the core of the game, so players meet one from the first shift instead of waiting for a reward.

### Rewards
- Reward pool: every card above, including Cheese, Frozen peas and all 5 coupons.
- **The first reward offer always includes one of the combination coupons** (Bundle, Breakfast sticker or Multipack).
- Each later set of 3 offers has at least 1 coupon and at least 1 card that is generally useful (a `generally_useful` flag on the card's data resource, tuned in `data/`, not decided in code). Decided with the user: Bread, Eggs, Milk and Banana are generally useful; Cheese, Coffee, Soup and Frozen peas stay situational.
- The reward pool, the first-offer pool (Bundle, Breakfast sticker, Multipack) and the offer size (3) live in `data/balance/balance.tres`. An offer never shows the same card twice.

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
| `run_start` | seed (a new random seed for every run, including after a restart), starting deck |
| `shift_start` | shift, quota, the 8 cards drawn |
| `redraw` | cards replaced, cards received |
| `checkout` | shift, final order, score, quota, pass or fail, placements, removals, rearrangements, distinct projected totals, planning time, input method (click or drag); see the definitions below. Logged at the checkout click, so closing the game during the count-up loses nothing. |
| `count_up` | shift, count-up time, fast-forward used. Logged when the count-up ends. |
| `reward` | shift, the 3 cards offered, card picked (empty if skipped), skipped, card replaced (at the 15-card limit, else empty), time to decide (`decide_ms`), whether the deck view was opened |
| `run_end` | win or loss, shift reached, last score, run length |
| `restart` | time since `run_end`, from which screen |
| `log_export` | which screen the export was started from, number of session files joined |
| `debug` | which debug action was used and its arguments (development builds only) |

### Checkout measures

| Field | Definition |
|---|---|
| placements | Number of times a card was put into a slot. Moving a card already in the row counts as 1 placement and 0 removals. Redraws don't count. |
| removals | Number of times a card was taken out of the row. Removing one card counts once, even though the cards after it shift left. |
| rearrangements | `placements` minus the number of cards committed. Placing each committed card once gives 0; every extra placement counts 1. |
| distinct projected totals | Number of different preview totals shown for rows with the same number of cards as the committed row. A total seen again counts once. |
| planning time | From `shift_start` to the checkout click, in ms of `t_ms`, minus the time the player was away within that span. On the web, "away" means the page was hidden (`document.visibilitychange`: another tab, minimised): canvas focus would also drop on any click outside the game, e.g. on the itch.io page, while the player can still see the hand. On desktop it means the window was unfocused (`focus_exited` / `focus_entered`). Focus changes after the click don't count. Check this in the browser test: switch tabs during a shift and confirm the planning time doesn't include it. |
| count-up time | From the checkout click to the moment the final total is shown, in ms of `t_ms` (not including the short pause after it). |

**Getting the log back:** an **Export log** button is visible on every screen: title, shift, reward and results. It downloads **every file** in `user://playtest_logs/`, joined into one `.jsonl` file in name order (each line already carries its `session_id`), so sessions from before a reload or a closed tab are included. On the web it uses `JavaScriptBridge.download_buffer`. On desktop it writes the same joined file to `user://playtest_export.jsonl` and opens that folder, so desktop testers also send one file. The `log_export` event is written, and its file closed, **before** the files are read, so the exported file contains it. Playtesters send that one file.

A small script summarises the logs: rearrangements per checkout, each coupon's pick rate (picks divided by the times it was offered, with each run's first offer reported separately, because it always contains a combination coupon; the `reward` event's `shift` identifies it), win rate per shift, which builds appear, restart rate.

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
