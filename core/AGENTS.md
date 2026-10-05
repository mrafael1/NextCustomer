# core/: scoring and run logic

This folder holds the rules of the game. Changing behaviour here changes the design. The spec is `docs/PROTOTYPE_PLAN.md`: section 3 (rules), section 4 (pipeline) and section 5 (content). This file lists what must be protected and what is still undecided. It does not repeat the spec.

## Invariants (never break these)

- **No engine scene code.** No `Node`, no scene tree, no autoloads, no signals to the UI. Only `RefCounted`, `Resource` and plain data, so everything runs headless in tests.
- **Deterministic scoring.** `score()` is a pure function: the same row and context always give the same `ScoreResult`. No randomness, no time, no global state inside scoring.
- **Seeded randomness elsewhere.** Draws and reward offers use the run's seeded `RandomNumberGenerator` instance only. Never use `Array.shuffle()`, `pick_random()`, `randi()`, `randf()` or any other global random function: they use the global RNG and silently break replay from a seed. The same seed, game version, content and player actions produce the same draws and reward offers. (Redraws and reward choices change how much of the RNG is used afterwards.)
- **Rules are stateless.** A loaded `Resource` is cached and shared, so a rule never stores anything on itself. Per-score state (Egg charges, waiting Coffee bonuses) lives in a state object created for each `score()` call. Numbers inside rules (Cheese's +4, Eggs' 2 charges) are `@export` fields on rule resources in `data/`, not literals in `core/` scripts.
- **Card definitions are never changed at runtime.** `CardDefinition` resources are shared by reference. Per-run state lives in `CardInstance` or run state, never on the definition.
- **Duplicates are separate instances.** Two copies of a card are two `CardInstance`s with their own IDs.
- **One result, many consumers.** The preview, the receipt, the count-up animation and the tests all use the same `ScoreResult.steps`. Every value change appears as a step with its source.

## Agreed scoring rules

The agreed rules are the ones written in the plan: section 3.1 (row), 3.2 (order of resolution), 3.3 (stacking), 3.4 (adjacency), 3.5 (other rules), 3.6 (tags) and the card rules in section 5. They are decided. Don't change them without explicit approval, and update the plan's changelog when one changes. This file doesn't copy them, so the plan is the single source.

## Golden tests (must always pass)

The full list is in plan section 3.7. They run on the frozen fixture `tests/fixtures/cards_v0_2/` (named for the rules version it froze), not on the live `data/` files, so tuning values never breaks them. These two come from the original design and their expected totals are never changed:

| Row | Total |
|---|---|
| Eggs, Bread, Cheese, Banana, Banana, Repeat | 31 |
| Banana, Repeat, Bread, Eggs, Banana, Cheese | 18 |

If a change makes any test in section 3.7 fail, the change is wrong unless the user has approved a rule change.

## Unresolved decisions: ask before implementing

The plan does not decide these interactions. **Don't pick an answer.** If a task needs one, stop and ask, then record the decision in the plan (section 3 and the changelog) and add a test for it.

| Question | Why it matters |
|---|---|
| Soup "pays 0" beside Frozen: does it set the payout to 0 after flat bonuses and multipliers, or set the base to 0 (so flat bonuses like Coffee's +3 still count)? | A stickered Soup with a Coffee bonus scores differently |
| Does a product that pays 0 still use up an Egg charge? | Changes Eggs value next to Soup |
| Bundle in the first or last slot (a product on only one side): no effect, or something else? | Edge case in every row |
| Breakfast sticker on a product that is already Breakfast: wasted, or another effect? | Affects how good the sticker is |
| Scoring: a Coffee bonus with no later Breakfast product: is it simply lost, or does it apply somewhere else? | Changes totals |
| Presentation: should an unused effect (e.g. a Coffee bonus that found no target) appear on the receipt as wasted? | Readability; doesn't change totals |
| Can the player commit an empty or one-card row? | Scoring of edge rows and UI validation |
| Bundle next to a coupon that isn't a connector (e.g. Banana, Bundle, Multipack, Banana): does it bridge over that coupon, link only to the nearest product, or do nothing? | Edge case in any row with two coupons together |
| Between shifts, is each hand drawn from the whole deck (everything reshuffled), or are used cards set aside until the deck runs out? | Changes how often a card appears and what the 15-card limit means |
| Which cards carry the `generally_useful` flag used by reward offers? | Needed before reward offers are built |

Add new questions here when they come up instead of guessing.
