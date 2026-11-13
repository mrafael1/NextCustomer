# Machine odds reference tables (#77)

`tests/core/machine_odds_test.gd` checks the GDScript `MachineOdds` against these tables to 1e-9.
They come from the approved draw process, `docs/art/mockups/machine_77_src/flow/draw77.js`
(`DRAW77.stats`: every possible draw enumerated with its probability), on small pools: NEW ITEMS
with the guarantee swap, COUPONS on the first and a later draw, REGISTER with owned upgrades and
the "3 different types" rule (incl. short draws), and UPGRADES on carts of the live chains.

The build extension that draw77 doesn't have is off in these states: REGISTER's "one fits your
cart" (the in-memory upgrades fit nothing). The brute-force enumerator in the same test covers it.
(The first NEW ITEMS draw's new arrival, another one, went with the end-cap in v1.32.)

Regenerate (from the repo root, Node 18 or later):

    node tests/fixtures/machine_odds/make_fixtures.js

Each file holds `odds` (the weights per Regular level) and `states`: the chute, the level, the
`input` the test builds its context from, and the `expected` numbers (`share` per drop over all
drops, `first` for drop 1, `rest` for drops 2-3, `p_rare_plus`, `p_legendary`, `p_short`,
`p_held`, `guarded`, and `in_draw`: each prize key `kind:id:rarity` to its chance to be drawn).
