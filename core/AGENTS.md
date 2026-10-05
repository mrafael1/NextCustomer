# core/: scoring and run logic

This folder holds the rules of the game. Changing behaviour here changes the design. The spec is `docs/PROTOTYPE_PLAN.md`: section 3 (rules), section 4 (pipeline) and section 5 (content). This file lists what must be protected and what is still undecided. It does not repeat the spec.

## Invariants (never break these)

- **No engine scene code.** No `Node`, no scene tree, no autoloads, no signals to the UI. Only `RefCounted`, `Resource` and plain data, so everything runs headless in tests.
- **Deterministic scoring.** `score()` is a pure function: the same row and context always give the same `ScoreResult`. No randomness, no time, no global state inside scoring.
- **Seeded randomness elsewhere.** Draws and reward offers use the run's seeded RNG only. The same seed, game version, content and player actions produce the same draws and reward offers. (Redraws and reward choices change how much of the RNG is used afterwards.)
- **Card definitions are never changed at runtime.** `CardDefinition` resources are shared by reference. Per-run state lives in `CardInstance` or run state, never on the definition.
- **Duplicates are separate instances.** Two copies of a card are two `CardInstance`s with their own IDs.
- **One result, many consumers.** The preview, the receipt, the count-up animation and the tests all use the same `ScoreResult.steps`. Every value change appears as a step with its source.

## Agreed scoring rules (prototype plan v0.2)

These are decided. Don't change them without explicit approval, and update the plan's changelog when one changes.

| Rule | Plan section |
|---|---|
| Two passes: context (tags, adjacency) for the whole row, then values left to right | 3.2, 4 |
| Per product: base → all flat bonuses → all multipliers → payout → effects for later cards | 3.2 |
| The row is compacted; "last slot" is the last filled slot | 3.1 |
| Flat bonuses add; multipliers multiply together (Eggs ×2 and Multipack ×2 = ×4) | 3.3 |
| A later Egg resets charges to 2; it never stacks a second ×2 | 3.3, 3.5 |
| Coupons neither use nor receive Egg charges | 3.5 |
| Each Coffee's +3 goes once, to the next Breakfast product after it (Coffee itself is Breakfast) | 3.3 |
| Repeat copies the final payout of the product just before it; the copy is never multiplied again and triggers nothing; after a coupon or in slot 1 it pays 0 | 3.3, 3.4 |
| A coupon breaks adjacency, except a connector (Bundle); consecutive connectors act as one bridge | 3.4 |
| Breakfast sticker affects the next slot only; wasted on a coupon or empty slot | 3.4 |
| Multipack uses the tags of the product just before it, after the context pass; nothing after a coupon or in slot 1 | 3.4 |
| Banana and Frozen peas add their base as a flat bonus when their condition is met | 5 |
| Whole euros only; no fractional multipliers in the prototype | 3.3 |
| Product tags as listed | 3.6 |

## Golden tests (must always pass)

The full list is in plan section 3.7. These two come from the original design and are never changed:

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

Add new questions here when they come up instead of guessing.
