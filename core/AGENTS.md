# core/: scoring and run logic

This folder holds the rules of the game. Changing behaviour here changes the design. The spec is `docs/PROTOTYPE_PLAN.md`: section 3 (rules), section 4 (pipeline) and section 5 (content). This file lists what must be protected and what is still undecided. It restates only the invariants an agent must never break; the details and reasons are in the plan.

## Invariants (never break these)

- **No engine scene code.** No `Node`, no scene tree, no autoloads, no signals to the UI. Only `RefCounted`, `Resource` and plain data, so everything runs headless in tests.
- **Deterministic scoring.** `score()` is a pure function: the same row and context always give the same `ScoreResult`. No randomness, no time, no global state inside scoring.
- **Seeds come from outside.** `core/` never makes a seed. New run seeds are passed in from a randomized `RandomNumberGenerator` owned outside `core/` (plan section 2).
- **Seeded randomness elsewhere.** Draws, reward offers, upgrade offers and inspection draws use the run's seeded `RandomNumberGenerator` instance only. Never use `Array.shuffle()`, `pick_random()`, `randi()`, `randf()` or any other global random function: they use the global RNG and silently break replay from a seed. The same seed, game version, content and player actions produce the same draws, reward offers, upgrade offers and inspections. (Redraws and reward and upgrade choices change how much of the RNG is used afterwards.)
- **Rules are stateless.** A loaded `Resource` is cached and shared, so a rule never stores anything on itself. This holds for card rules, upgrade rules (`core/upgrades/`) and inspection rules (`core/inspections/`) alike. Per-score state (Egg charges, waiting Coffee bonuses) lives in a state object created for each `score()` call. Numbers inside rules (Cheese's +4, Eggs' 2 charges) are `@export` fields on rule resources in `data/`, not literals in `core/` scripts. Their script defaults are neutral (0 for bonuses, 1 for multipliers, 0 for charges), because Godot omits values equal to the default from `.tres` files and a non-neutral default would let a script edit silently change card data and the golden fixture. A test enforces this (plan section 3.7).
- **Products and coupons are told apart by data.** `CardDefinition.kind` says product or coupon (its default, `UNSET`, is rejected by a test), and `is_connector` marks coupons that bridge adjacency (plan section 4). Scoring reads these fields to tell products from coupons and connectors, never card ids.
- **Card definitions are never changed at runtime.** `CardDefinition` resources are shared by reference. Per-run state lives in `CardInstance` or run state, never on the definition.
- **Duplicates are separate instances.** Two copies of a card are two `CardInstance`s with their own IDs.
- **One result, many consumers.** The preview, the receipt, the count-up animation and the tests all use the same `ScoreResult.steps`. Every value change appears as a step with its source.

## Agreed scoring rules

The agreed rules are the ones written in the plan: section 3.1 (row), 3.2 (order of resolution), 3.3 (stacking), 3.4 (adjacency), 3.5 (other rules), 3.6 (tags), 3.8 (upgrades), 3.9 (inspections) and the card rules in section 5. They are decided. Don't change them without explicit approval, and update the plan's changelog when one changes. This file doesn't copy them, so the plan is the single source.

## Golden tests (must always pass)

The full list is in plan section 3.7. They run on the frozen fixture `tests/fixtures/cards_v0_4/` (named for the rules version it froze), not on the live `data/` files, so tuning values never breaks them. The fixture is self-contained and built as described in plan section 3.7; never point it at `data/`. These two come from the original design and their expected totals are never changed:

| Row | Total |
|---|---|
| Eggs, Bread, Cheese, Banana, Banana, Repeat | 31 |
| Banana, Repeat, Bread, Eggs, Banana, Cheese | 18 |

If a change makes any test in section 3.7 fail, the change is wrong unless the user has approved a rule change.

## Unresolved decisions: ask before implementing

The plan does not decide these interactions. **Don't pick an answer.** If a task needs one, stop and ask, then record the decision in the plan (section 3 and the changelog) and add a test for it.

| Question | Why it matters |
|---|---|
| *(none open right now)* | |

Add new questions here when they come up instead of guessing.
