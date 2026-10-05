# Next Customer: Prototype Plan

> Status: draft v0.1, written before development starts. Update it after every playtest round (see the changelog at the bottom).
> Source: the original "Receipt Rogue" game design plan, plus the decisions made in planning.
> Engine: Godot 4.7, GDScript with static typing.

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
- 8 products and 5 coupons (section 5)
- One shift: read the quota, draw 8, redraw up to 2 once, drag up to 6 cards into ordered slots, see the live projected total, run checkout
- The point-count sequence: receipt lines print one by one, the source of each bonus is highlighted, the subtotal ticks up, with beep and print sounds and a fast-forward option
- A run of 5 shifts with quotas 10 / 15 / 22 / 32 / 48 (placeholders)
- After each successful shift, pick 1 of 3 stock cards or skip; deck view; 18-card limit with replacement
- Win and lose screens, instant restart
- Seeded random numbers (the seed is shown on screen, and a run can be replayed from its seed)
- A playtest log written automatically (section 8)
- A debug panel: set the seed, add any card to the hand, skip to a shift

### Out of scope (deliberately)

Art, register upgrades, inspections, tutorial, saving, settings menus, meta progression, unlockable decks, Steam, and more than 8 shifts.

Placeholder visuals: coloured rectangles with the card name, tags, base value and rule text. Use a readable sans-serif font for rules and a monospace font for the receipt.

## 3. Rules specification (prototype defaults)

The original design doc is the base. These decisions resolve its ambiguities. Each one can be changed after playtests.

| Topic | Decision |
|---|---|
| Resolution order per product | base → its own flat bonuses → multipliers from earlier cards and coupons → payout added to the subtotal → effects passed to later cards |
| Flat before multiply | Always. Values are whole euros. Round down after each multiplication. |
| "Immediately after" | The previous slot. A coupon breaks adjacency **unless the coupon's rule says otherwise** (see Bundle). |
| "Beside" | The slot directly to the left or right |
| Coffee "+3 to the next Breakfast product" | The next Breakfast product anywhere later in the row, not only the adjacent slot |
| Eggs | Doubles the next 2 Food payouts. An Egg is Food. An Egg does not boost itself, but it can use up a charge left by an earlier Egg. A later Egg resets the charges to 2; it does not stack. Coupons neither use up nor receive the charge. |
| Repeat | Copies the final payout of the product just before it. It does not rescan the product or trigger its effects. Repeat right after another coupon pays 0. |
| Loss | A checkout below the quota ends the run (no warning in v1) |
| Preview | The exact projected total is always visible, and hovering a card shows its calculation |

### Product tags

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

### Required test cases (written before the UI)

- The doc's example: Eggs, Bread, Cheese, Banana, Banana, Repeat = **31**
- The same cards in the weaker order: Banana, Repeat, Bread, Eggs, Banana, Cheese = **18**
- A coupon between Bread and Cheese cancels the Cheese bonus. With Bundle it does not.
- Eggs → Eggs → Food, Food, Food: the second Eggs uses one charge, then resets to 2
- Repeat after a coupon pays 0
- Coffee boosts the next Breakfast product even when it is not adjacent
- Soup beside Frozen peas pays 0
- Duplicate cards are separate instances (two Bananas from the deck are different objects)
- The redraw cannot bring back a card that was just replaced
- The same seed gives the same draws

## 4. Architecture (built to last, not thrown away)

The prototype code is the start of the real game. Only the presentation layer is temporary.

```
res://
  core/                 # pure logic: no Nodes, no scene tree, fully testable
    card_definition.gd  # Resource: id, name, tags, base, rules[], art_ref
    card_instance.gd    # a reference to a definition + a unique instance id
    rule.gd             # base class for product and coupon rules (hook methods)
    rules/              # one script per reusable trigger and effect
    scoring.gd          # score(row, context) -> ScoreResult {total, steps[]}
    score_step.gd       # one explanation line: slot, source, kind, value change, text
    deck.gd             # draw, redraw, reward insertion, seeded RNG
    run_state.gd        # deck, shift, quota, seed, (later: upgrades, inspection)
  data/
    cards/*.tres        # one CardDefinition resource per card
    decks/starter.tres  # DeckDefinition (ready for unlockable decks later)
    balance/quotas.tres # quotas and reward pool, tunable without code changes
  ui/                   # scenes: shift screen, reward screen, results screen
  presentation/         # count-up sequencer: plays back the ScoreResult steps
  debug/                # debug panel, playtest logger
  tests/                # GdUnit4 tests, runnable headless
```

### The scoring pipeline (key decision)

Coupons need to be able to **change the rules**, not only add numbers. So scoring runs in two passes:

1. **Context pass** (the whole row, before any values are calculated): rules can change *tags* ("the next product gains Breakfast") and *adjacency* ("the products on either side of me count as adjacent"). This produces a final list of tags and neighbours for each slot.
2. **Value pass** (left to right): each product goes through base → flat bonuses → multipliers → payout → effects for later cards, using the results of the context pass.

Every rule overrides only the hooks it needs (`modify_context`, `flat_bonus`, `multiplier`, `on_scanned`, `copy_payout` …). Register upgrades and inspections in the full build will use the **same hooks**, so no rewrite will be needed.

`score()` is a pure function. The live preview, the hover explanation, the animated receipt and the tests all use the same `ScoreResult`, so they can never disagree.

## 5. Prototype content

### Products (from the design doc)

| Card | Base | Rule |
|---|---|---|
| Banana | 2 | Double its base if immediately after another Banana |
| Bread | 3 | No rule (other cards build on it) |
| Cheese | 3 | +4 if immediately after Bread |
| Eggs | 1 | Double the next 2 Food payouts (resets, does not stack) |
| Milk | 3 | +2 for each earlier Breakfast product |
| Coffee | 2 | +3 to the next Breakfast product |
| Soup | 5 | Pays 0 if beside a Frozen product |
| Frozen peas | 3 | Double its base if beside another Frozen product |

### Coupons (the fun multiplier: 2 from the doc + 3 that create combinations)

| Coupon | Rule | What it tests |
|---|---|---|
| Repeat | Copy the payout of the product just before it | Plain amplification |
| Final markdown | +6 if in the last slot | Position pressure, competes with Repeat |
| **Bundle** | The products on either side of it count as adjacent to each other | Coupons that *enable* combinations instead of breaking them |
| **Breakfast sticker** | The next product gains the Breakfast tag | Changing tags creates new builds (Banana into a Milk build) |
| **Multipack** | ×2 to every later product that shares a tag with the product just before this coupon | A big multiplier with an ordering puzzle around it |

Starting deck (12 cards): 3 Banana, 2 Bread, 2 Milk, 2 Eggs, 2 Coffee, 1 Soup.
Reward pool: every card above, including Cheese, Frozen peas and all 5 coupons. Each set of 3 offers has at least 1 coupon and at least 1 card that is generally useful.

## 6. Build schedule (about 18 hours plus iteration rounds)

| Day | Work | Done when |
|---|---|---|
| 1 | Project setup, GdUnit4, card data resources, scoring engine with both passes, all tests from section 3 | Tests pass headless. The 31 / 18 examples are correct. |
| 2 | Shift screen: draw, redraw, drag and also click-to-place into 6 slots, live preview, hover explanations, deck and seed, debug panel | One shift is playable from start to finish |
| 3 | Count-up sequencer and sounds, reward screen, 5-shift run, win and lose screens, restart, playtest logger. First playtest with 1–2 people. | A stranger can play a complete run without being told what to do |

## 7. Playtest protocol

- **Who:** 5–8 people who like short strategy games, ideally not friends who have heard the design.
- **How:** give them the build and a single sentence ("meet the quota each shift"). Watch silently. Don't teach.
- **Afterwards, ask:**
  1. Explain how your biggest checkout scored.
  2. Which coupon did you like most, and why?
  3. Was there a moment when you found a combination by yourself?
  4. Did you want to play again? (Watch whether they restart on their own before you ask.)
  5. What was confusing?

## 8. What we measure (automatic log)

The prototype writes one JSON line per checkout to `user://playtest_logs/<date>_<seed>.jsonl`:

- seed, shift, quota, the 8 cards drawn, redraw used and which cards were replaced
- the final order, the score, pass or fail
- **how many times the order was rearranged before committing** and **the number of distinct projected totals seen** (a sign of blind shuffling)
- time spent planning, time spent watching the count-up, whether fast-forward was used
- reward offered and reward picked (or skipped)
- whether the player restarted, and how long after losing or winning

A small script summarises the logs: average rearrangements, how often each coupon was picked, win rate per shift, which builds appear.

## 9. Decision gate after each playtest round

| Result | Signals | Next step |
|---|---|---|
| **Go** | Most players explain a payout, find a coupon combination on their own, and restart voluntarily | Start the full build (phase 1) |
| **Iterate** | The core is promising, but specific problems appear (section 10) | One iteration round, up to about 6 hours, changing one major variable at a time, then retest |
| **Pivot** | Ordering is ignored or feels like solving a spreadsheet, even after an iteration | Change the core mechanic (see the bottom rows of section 10) |
| **Stop** | Two iteration rounds without improvement in replay intent | Stop or rethink the concept |

At most **2 iteration rounds** (about 12 hours in total) before a Go / Pivot / Stop decision is forced.

## 10. Likely iterations from playtests

These are prepared answers to likely findings. Choose based on what is actually observed, not in advance.

| Observation | Possible iterations (choose one at a time) |
|---|---|
| **Players shuffle blindly** (many rearrangements, can't explain the score) | Show the change in total when hovering a slot instead of the full preview · show the full total only after placing all cards · reduce the hand to 7 · simplify the rule text |
| **Players ignore the order** (they put the cards in any order and pass) | Raise quotas · make adjacency rules stronger · add more cards that depend on position |
| **Coupons feel weak or optional** | Raise multiplier values · let a coupon not use up a slot (place it *between* products) · guarantee a coupon in the first reward |
| **Coupons too strong, one combination dominates** (e.g. Multipack + Repeat every run) | Limit Multipack to the next 3 products · Repeat cannot copy a payout that was multiplied by a coupon · add a coupon limit per checkout |
| **Everyone drafts the same build** | Change the reward offers · make duplicates weaker · test new products that pull in a different direction |
| **Bad draws feel unfair** | 2 redraws instead of 1 · a smaller starting deck · a softer quota curve · draw 9 |
| **Counting feels flat** | Faster pacing at the start · rising pitch with each bonus · bigger print line for multipliers · a short pause before the final total |
| **Counting too slow** | Auto speed-up after the first shift · hold-to-fast-forward by default · combine flat bonuses into one line |
| **Runs too short or too easy** | Increase quotas from shift 3 · prepare the 8-shift structure for the full build |
| **Hand management is the fun, not ordering** (pivot) | Fewer slots, more discards: the choice moves to which cards to keep |
| **The receipt is the fun, not the decisions** (pivot) | More automatic chains, fewer manual choices: the game moves towards an idle or arcade feel |

Rules for iterating: **one major variable per round**, card values tweaked only in data files, every round tagged in git (`proto-r1`, `proto-r2` …) and listed in the changelog.

## 11. Changelog

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-10-05 | First plan, before development |
