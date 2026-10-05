# Next Customer: Prototype Plan

> Status: draft v0.3, written before development starts. Update it after every playtest round (see the changelog at the bottom).
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
- One shift: read the quota, draw 8, redraw up to 2 once, place up to 6 cards in order with **click-to-place** (select a card, click a slot), see the live projected total, run checkout
- The point-count sequence: receipt lines print one by one, the source of each bonus is highlighted, the subtotal ticks up, with beep and print sounds and a fast-forward option
- A run of 5 shifts with quotas 10 / 15 / 22 / 32 / 48 (placeholders)
- After each successful shift, pick 1 of 3 stock cards or skip; deck view; 15-card limit with replacement (the 13-card start deck reaches it after two picks, so replacement is reachable from the third reward)
- Win and lose screens, instant restart
- Seeded random numbers (the seed is shown on screen, and a run can be replayed from its seed)
- An event log written automatically, which can be exported from the browser (section 8)
- **A browser build** for playtesters (section 7), plus a Windows build as a fallback
- A debug panel: set the seed, add any card to the hand, skip to a shift. It exists in development builds only; playtest builds exclude it (export feature tag), so playtesters can't spoil the data. Any use in a development build is logged as a `debug` event.
- **Drag-and-drop only if time allows.** It is the first thing cut (section 6).

### Out of scope (deliberately)

Art, register upgrades, inspections, tutorial, saving, settings menus, meta progression, unlockable decks, Steam, and more than 8 shifts.

Placeholder visuals: coloured rectangles with the card name, tags, base value and rule text. Use a readable sans-serif font for rules and a monospace font for the receipt.

## 3. Rules specification (prototype defaults)

The original design doc is the base. These decisions resolve its ambiguities. Each one can be changed after playtests.

### 3.1 The row

- The checkout row is **compacted**: cards always fill slots from the left, with no gaps. Removing a card shifts the ones after it to the left.
- The **last slot** means the last filled slot.
- Coupons take a slot like products.

### 3.2 Order of resolution

Scoring runs in two passes (section 4):

1. **Context pass:** tag changes and adjacency changes from coupons are applied to the whole row first.
2. **Value pass, left to right**, for each product:
   1. Base value
   2. **+ all flat bonuses** (its own rule, Coffee bonuses waiting for it, and so on)
   3. **× all multipliers** (Eggs charges, Multipack, …)
   4. Payout added to the subtotal
   5. Its effects for later cards become active (Eggs charges, Coffee bonus, …)

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
| Bundle | In the context pass, the product before Bundle and the product after it count as adjacent to each other (for both "immediately after" and "beside"). Several connector coupons in a row act as one bridge. |
| Repeat after Bundle | Still pays 0. Repeat only copies a *product* in the slot just before it; Bundle does not change that. |
| Breakfast sticker | Affects the next slot only. If that slot is a coupon or empty, the sticker is wasted. |
| Multipack | Uses the tags of the product just before it (after the context pass). In slot 1, or after a coupon, it does nothing. |

### 3.5 Other rules

| Topic | Decision |
|---|---|
| Eggs | Doubles the next 2 Food payouts. An Egg is Food. An Egg does not boost itself, but it can use up a charge left by an earlier Egg. Coupons neither use up nor receive the charge. |
| Coffee "+3 to the next Breakfast product" | The next Breakfast product anywhere later in the row, not only the adjacent slot |
| Loss | A checkout below the quota ends the run (no warning in v1) |
| Preview | The exact projected total is always visible. The receipt preview shows each line. |

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
| Milk, Multipack, Cheese | 3 + 0 + 6 = **9** | Multipack by a shared tag (Dairy) |
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

Golden rows use a frozen copy of the card data (`tests/fixtures/cards_v0_2/`, named for the rules version it froze), so tuning values in `data/` between playtest rounds doesn't break them. The live data gets its own tests with expected totals that are updated when values change.

Also tested: duplicate cards are separate instances · the redraw cannot bring back a card that was just replaced · the same seed gives the same draws.

## 4. Architecture (built to last, not thrown away)

The prototype code is the start of the real game. Only the presentation layer is temporary.

```
res://
  core/                 # pure logic: no Nodes, no scene tree, fully testable
    card_definition.gd  # Resource: id, name, tags, base, rules[], generally_useful, art_ref
    card_instance.gd    # a reference to a definition + a unique instance id
    rule.gd             # base class for product and coupon rules (hook methods)
    rules/              # one script per reusable trigger and effect
    scoring.gd          # score(row, context) -> ScoreResult {total, steps[]}
    score_step.gd       # one explanation line: slot, source, kind, value change, text
    deck.gd             # draw, redraw, reward insertion; takes the run's RandomNumberGenerator
    run_state.gd        # deck, shift, quota, seed, (later: upgrades, inspection)
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

1. **Context pass** (the whole row, before any values are calculated): rules can change *tags* ("the next product gains Breakfast") and *adjacency* ("the products on either side of me count as adjacent"). This produces a final list of tags and neighbours for each slot.
2. **Value pass** (left to right): each product goes through base → flat bonuses → multipliers → payout → effects for later cards, using the results of the context pass (section 3.2).

Every rule overrides only the hooks it needs (`modify_context`, `flat_bonus`, `multiplier`, `on_scanned`, `copy_payout` …). Register upgrades and inspections in the full build will use the **same hooks**, so no rewrite will be needed.

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
| **Breakfast sticker** | The next product gains the Breakfast tag | Changing tags creates new builds (Banana into a Milk build) |
| **Multipack** | ×2 to every later product that shares a tag with the product just before this coupon | A big multiplier with an ordering puzzle around it |

### Starting deck (13 cards, with an early coupon)

3 Banana, 2 Bread, 2 Milk, 2 Eggs, 2 Coffee, 1 Soup **+ 1 Repeat**.

Coupons are the core of the game, so players meet one from the first shift instead of waiting for a reward.

### Rewards
- Reward pool: every card above, including Cheese, Frozen peas and all 5 coupons.
- **The first reward offer always includes one of the combination coupons** (Bundle, Breakfast sticker or Multipack).
- Each later set of 3 offers has at least 1 coupon and at least 1 card that is generally useful (a `generally_useful` flag on the card's data resource; which cards carry it is tuned in `data/`, not decided in code; the list is still an open question in `core/AGENTS.md`).

## 6. Build schedule (18 hours is the target, 24 is realistic)

The two-pass engine, click-to-place UI, count-up animation, browser export and logging all compete for time. The schedule puts the risky technical parts first.

| Day | Work | Done when |
|---|---|---|
| 1 | Project setup, GdUnit4, **browser export check with an empty scene** (catches export problems early), card data resources, scoring engine with both passes, all tests from section 3.7 | Tests pass headless. An empty web build runs in the browser. |
| 2 | Shift screen: draw, redraw, click-to-place into 6 slots, live preview and receipt explanation, deck and seed, debug panel, event logger with all event types | One shift is playable and logged from start to finish |
| 3 | Count-up sequencer and sounds, reward screen, 5-shift run, win and lose screens, restart, log export, web build uploaded. First playtest with 1–2 people. | A stranger can play a complete run in the browser without being told what to do, and send back the log |

### What gets cut if time runs out (in this order)

1. **Drag-and-drop.** Click-to-place tests selection and ordering just as well.
2. Hover breakdown for each card (the receipt explanation stays)
3. Debug panel features other than the seed
4. The log summary script (read the logs by hand)
5. Sound beyond the scanner beep and printer

**Never cut:** the scoring engine and its tests, the count-up sequence, the event log, the browser build.

## 7. Browser delivery

Playtesters open a link instead of downloading a build. This lowers the barrier for strangers and matches the web demo planned for the full build.

- Godot 4 web export with GDScript (C# could not export to the web)
- **Single-threaded export** so it runs on itch.io without special server headers
- Hosted on a **private itch.io page** (restricted or password-protected), with a Windows build as a fallback
- A "click to start" title screen so browsers allow audio
- Fonts embedded in the build; test in Chrome and Firefox (Safari if possible)
- On the web, `user://` is stored in the browser, so the log has to be exported (section 8)
- Every build shows its version (e.g. `proto-r1`) on the title screen and in the log

## 8. Event log

The prototype writes one JSON line per **event** to `user://playtest_logs/<session_id>.jsonl`. Each line contains: `session_id`, `run_id`, `seq` (order number), `time`, `build`, `type`, and the data for that type. Each event is written by opening the file, appending the line and closing it again (`FileAccess.READ_WRITE` then `seek_end()`; `WRITE` and `WRITE_READ` truncate the file, so use them only to create it the first time). On the web, `user://` is persisted to the browser's storage asynchronously and a long-open file is not guaranteed to be saved, so keeping a file open and flushing it is not enough. Test this early: play a few events, close the tab, reopen the build and check the log survived.

Choices and actions that happen after a checkout (rewards, the end of a run, restarts) are their own events. They are not stuffed into the checkout record.

| Event | Data |
|---|---|
| `run_start` | seed, starting deck |
| `shift_start` | shift, quota, the 8 cards drawn |
| `redraw` | cards replaced, cards received |
| `checkout` | final order, score, pass or fail, number of rearrangements before committing, number of distinct projected totals seen, planning time, count-up time, fast-forward used, input method (click or drag) |
| `reward` | the 3 cards offered, card picked or skipped, card replaced (at the 15-card limit), time to decide, whether the deck view was opened |
| `run_end` | win or loss, shift reached, last score, run length |
| `restart` | time since `run_end`, from which screen |
| `log_export` | when the player exported the log |
| `debug` | which debug action was used and its arguments (development builds only) |

**Getting the log back:** the title and results screens have an **Export log** button that downloads the file (on the web, via `JavaScriptBridge.download_buffer`). Playtesters send that file. On desktop the button opens the log folder.

A small script summarises the logs: rearrangements per checkout, how often each coupon was picked, win rate per shift, which builds appear, restart rate.

### How to read the numbers

**A high rearrangement count is a clue, not proof of blind shuffling.** A player might rearrange a lot because they are exploring combinations on purpose. Always combine the count with the interview (section 9):

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
