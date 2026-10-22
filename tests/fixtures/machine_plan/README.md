# Machine plan reference timelines (#77)

`tests/presentation/machine_plan_test.gd` checks `MachinePlan` (presentation/machine_plan.gd)
against `page_timelines.json`: the approved page's own timelines, from
`docs/art/mockups/machine_77_src/flow/flow_template.html` (`buildTimeline()` and
`bonusTimeline()`, the numbers the page prints with `?tl`) and look F's `plan()` from
`flow/looks/look_f.js` (bay picks, PACKED, the belt run, restocks), for fixed draws: a first
visit with a new item, a register or an UPGRADES shelf landing, 1, 2 and 3 prizes, followed by
STAMP DAY or by a BONUS TICKET visit (new item, shelf, register), each at 1x and under reduced
motion.

The page's demo cursor is still in these numbers (its hover, read and CONFIRM, and its move to the
pick); the test takes it out at the plan's wait points, so no total is summed by hand.

Regenerate (from the repo root, Node 18 or later):

    node tests/fixtures/machine_plan/make_fixtures.js

Each entry holds the draw (`tiers` in reveal order, `drawer`: `new`, `up` or `` for a register,
`copies`), `stamp_day` (its tiers, or null), the page's `T` and look F's `plan`, and for a BONUS
TICKET scenario the same under `bonus`.
