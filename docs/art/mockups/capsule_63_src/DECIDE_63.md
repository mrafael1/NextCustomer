# #63 decide list: capsule machines, the draw, the shelf and the list logic

## Decided with the user (2026-10-21)

The user answered the four questions on 2026-10-21. These answers are binding for the #63 build; the original decide
list below is kept as history (its recommendations for C and for "?" spaces were not taken).

- **Q1 look: A.** "I think A is the better one? C has too much info going." The camera cuts to the store exit
  (`capsule_63_a.html`): six big round-globe toy machines on the tiled floor by the sliding doors, with A's globe body
  (72x140 art px, 144x280 on screen). The figurine shelf is its own screen (`capsule_63_shelf.html`). C's collector wall
  and B's pop-in cabinet are not chosen.
  - For the build: the static art is A's: `scenery/toy_machine` (one body, recoloured per aisle by the new
    `@derive <source> aisle=<id>` palette map from `sign_color`, or 6 hand recolours), `scenery/exit_vestibule`,
    `frames/aisle_sign`, and for the shelf `frames/display_cabinet` and `scenery/shelf_plank`. C's
    `scenery/wall_machine`, `frames/display_case` and `scenery/exit_wall` are dropped, and so is C's fly-to-cubby beat:
    #64's draw ends on the reveal, OK goes back to the machines.
  - The machines screen carries a "Figurine shelf" button (as on A's page); the shelf's Back returns to the machines.
- **Q2 where: from the results and from the title, and coins can be kept.** "result + title and keep coins". A
  secondary "Toy machines ›" button beside New run on the results (Done returns to the results), and the machine prop
  plus the same button in the space on the right of title B (#56; Done returns to the title). Spending is never
  required and nothing nags.
  - **Default, not user-chosen:** the sub-choice for a title draw while a run is saved was not answered, so the
    recommended (a) stands: that draw gets run index `run_count` (the saved run's own index), the item rides the 3 runs
    after the saved one, and the reveal says "**In stock after your saved run**". A title draw with no saved run and a
    results draw keep the issue's `run_count - 1` and "In stock from your next run". Say so to change it to (b) or (c)
    below.
- **Q3 shelf: locked items are hidden.** "shelf is looking good. items not unlocked shouldn't be shown." No "?"
  spaces: a locked figurine has no space, no silhouette and no name anywhere on the shelf. The other Q3 parts stay as
  recommended, since the user said the shelf looks good: **the 30 capsule items only**, **names on hover**, **data
  order** (key item first). How a hidden-locked shelf still reads well (decided here, A's shelf look kept):
  - **The cabinet keeps its size.** All six aisle shelves are always there, in `balance.aisles` order, each with its
    sign (sign colour, glyph, name) and its count "**n / m**" (for example "3 / 8"). The cabinet does not grow or
    shrink with the collection, so 0, 3, 9 and 30 figurines are one layout (no reflow to test, and the 30-figurine fit
    check from the prep still holds).
  - **Figurines stand packed from the left of their plank, in data order** (key item first), at the same 70 px pitch,
    so there is never a gap that hints at a locked item. Hidden items need no fixed spot: when an earlier item in data
    order arrives later, the ones after it move one place right. That is fine, since there is no gap to fill.
  - **An aisle with nothing yet** shows a muted italic "**None yet**" on its plank, so an empty shelf reads as
    "nothing collected", not as missing content.
  - **A new profile (0 / 30)** shows "None yet" on all six shelves and one line beside the chip: "Every capsule you
    open puts its figurine here." (the "Hover a figurine for its name." hint is left out while there is nothing to
    hover).
  - **How many exist** is still told by the numbers, never by empty spaces: each aisle's "n / m", the FIGURINES
    n / 30 chip, and the machine's own "3 of 8 left". These are counts, not items, so they don't show what is locked.
    A full aisle keeps the ALL COLLECTED tag.
  - Stills: `capsule_63_shelf_partial_1920x1080.png` (9 / 30, with the hover tag), `capsule_63_shelf_fresh_1920x1080.png`
    (0 / 30), `capsule_63_shelf_full_1920x1080.png` (30 / 30). The old option stays reachable only as a not-chosen
    view (`capsule_63_shelf.html?locked=spaces`, still `capsule_63_shelf_partial_spaces_1920x1080.png`).
- **Q4 wording: TOY MACHINES.** The sign and title say TOY MACHINES; inside is a **capsule**, you get a **figurine**;
  "3 of 8 left" / "All 8 collected"; "1 coin"; "NEW!", the name, its aisle, "In stock from your next run" (or the
  saved-run line above); hint "Pick a machine: 1 coin a capsule." Never "gacha". "Capsule machines" is not chosen.

**Defaults still standing** (stated below under "Stated defaults", not changed by the answers; say so to change one):
the RNG source (`capsule_seed` + `capsule_draws` in `ProfileState`, `FORMAT_VERSION` 2, the seed made outside
`core/`); full collection (ALL COLLECTED, COLLECTION COMPLETE, coins keep adding up); 0 coins (dimmed machines, the
tomato notice); can't save (OUT OF ORDER, "Coins ?", a failed save rolls the draw back); **`RunStock.surprise_list` as
the list `start_new_run` uses until #65** (the pre-fill would lock the first list in); the `capsule` telemetry event;
the debug panel's Profile tools; the machine row in `balance.aisles` order; the plain reveal (`UiKit.pop_in`) that #64
must end on; hover and press; no changelog for the prep. The static-art default is updated for look A (above).

## Original decide list (history)

Decide prep, 2026-10-21, written before the answers above. Open `docs/art/mockups/capsule_63_index.html` first: it
links every page and still. The three looks are live: click a machine and the draw plays (the note in the bottom-right
corner switches states). The shared brief is `capsule_63_src/BRIEF.md`.

Four real questions (Q1 to Q4), each with a recommendation. Everything after them is a stated default from the issue's
"decide with the user" list: say so if you want one changed.

## Q1. The machines' look: staging and machine body

Q1 is really two choices. The three pages differ mostly in **staging** (where the machines stand and where the shelf
is). There are only two **machine bodies**: the round **globe** (A and C draw the same globe machine, C's at about 0.7x:
60x100 art px against A's 72x140) and the boxy **window** machine (B). B shares the globe's coin slot and dial block.
Any body can stand in any staging, so you can pick, for example, C's wall and cases with B's window machines.

**Staging:**

| Option | Page | What it is |
|---|---|---|
| **A: exit vestibule** | `capsule_63_a.html` | A camera cut to the store exit: six round-globe toy machines on the tiled floor between the wall and the sliding doors (EXIT sign, the street at night). Big machines (144x280), the classic silhouette. The shelf is its own screen (`capsule_63_shelf.html`, a wooden display cabinet). |
| **B: machine bank pop-in** | `capsule_63_b.html` | No camera cut: a steel vending cabinet pops in over the shaded results, the size of the other centred panels. Six boxy window machines on a shelf whose price rail carries "3 of 8 left". Separate shelf screen. The cheapest: one machine sprite and one frame. |
| **C: collector wall** | `capsule_63_c.html` | Machines and shelf are one wall at the exit. Each aisle is a column: a small wall-hung globe machine, its label, and under it a wooden case with one cubby per item, a "?" in each locked one. After OK the figurine flies into its cubby. No separate shelf screen. |

**Machine body:** the **globe** (A, C) or the **window** (B). The static art is one body either way (for C's wall
`scenery/wall_machine`, for A or B a floor machine), so the art list below holds for whichever body you pick; only its
size changes with the staging.

**Recommendation (not taken: the user chose A's staging with its globe body): C's staging with the globe body.**
Reasons:

- One place per fact (your note on the shift screen): the case under each machine *is* that machine's "what's left",
  so the shelf, the catalogue and the items-left count are the same object, and every new figurine visibly lands in
  its place. That landing is the collection's payoff, and it needs no extra screen.
- It fits the issue's hardest fit test on the panel itself: 30 figurines at 1x in 6 aisle groups plus 6 machines in
  1280x720 (the tallest case ends at y 592).
- It is a physical store fixture (wall, brackets, wooden cases), which you have preferred over flat panels, and it
  looks nothing like #77's restock hatch.
- The globe is the classic toy-machine silhouette and reads as "capsules inside" at a glance; the window body reads
  more like a vending machine. This reason holds for A's staging too, since A and C share the globe.

Costs and risks: the machines are smaller (120x200 against A's 144x280), so #64's crank and coin read smaller (the
capsule still hops to the centre for the reveal); the base aisles' cases are short (2, 2 and 3 items), which leaves
wall space on the left, and the Household case has one blank cubby; the fly-to-cubby adds 0.5 s after OK (#64,
skippable; reduced motion lands at once). If C feels too busy, **A's staging** is the fallback: the same globe body
drawn bigger, at the price of a camera cut and a second screen for the shelf. B's staging is the cut-list look.

## Q2. Where the machines are reached, keeping coins, and a title-screen draw's run index

**Recommendation (taken):** from both places, and coins can be kept.

- **After a run:** a secondary button "Toy machines ›" beside New run on the results (results look A, the till
  report). Done brings you back to the results.
- **From the title:** the space reserved on the right of title B (#56) holds a small machine prop and the same button.
  Done brings you back to the title.
- **Coins can be kept.** Spending is never required, and nothing nags. Saving coins for a machine you want is a fine
  choice, since the player picks the machine and never the item.
- **A title-screen draw's run index** (a sub-choice). The issue's rule, `run_count - 1`, is for a draw right after
  a run, and it is also right for a title draw when no run is saved: the next run started has index `run_count`, so
  the item rides runs `run_count` to `run_count + 2` (section 7.2). But with a saved run in progress, the run you
  Continue *is* the next run, and its stock was fixed when it started. So `run_count - 1` would give the item only 2
  of its 3 runs, and the reveal's "In stock from your next run" would be false (and so would section 7.2's "a capsule
  is always playable in the next run"). The options for that case:
  - **(a) Recommended, and the standing default (not answered by the user):** a title draw while a run is saved gets run index `run_count` (the saved run's own index), so
    the item rides the 3 runs after the saved one. The reveal line then says "**In stock after your saved run**".
  - (b) The title machines are switched off while a run is saved (a "Finish your run first" label on the machine
    prop; the shelf stays open).
  - (c) Keep `run_count - 1` (the item rides 2 runs) and change the reveal line in that case, for example "In stock
    after this run".

The alternative is results only, which is simpler but means a player who quit before spending has to finish another
run to reach the machines.

## Q3. The shelf: locked items, which items, names and order

**Recommendation (partly taken: the user chose locked items HIDDEN, not spaces; the rest was taken):** locked items
are **empty spaces** (a dashed box with "?"); the shelf holds **capsule items only**
(30); names show **on hover** (a tag with the name, aisle glyph and aisle); the order within an aisle is **data
order** (the key item first, so each figurine has a fixed spot).

- (Not taken.) Empty spaces show the progress the machine already states ("3 of 8 left"), and fixed spots make the shelf fill in
  like an album. Hidden locked items (see `locked=hidden` on the shelf and on C) hide nothing the machine doesn't
  already show, and make the shelf look emptier.
- Capsule items only: the shelf is the record of what came out of capsules. The 14 base-aisle products were never
  drawn, and adding them would bring the shelf to 44 and blur "collected".
- On hover: section 1 keeps the hand to art only, and printed names at 11 px under 48 px sprites are busy
  (`capsule_63_shelf.html?labels=1` shows them). Until #57 and #58 draw the sprites, the art-pending boxes print
  their names anyway.
- Data order is needed for fixed spots. Draw order would reshuffle as you collect.
- **What the stills can't settle:** 27 of the 30 collected figurines are still art-pending boxes (#57, #58). The
  locked spaces are now dark recessed slots with a "?" and no dashed border, so they read differently from a
  collected art-pending box, but how the full shelf feels depends on sprites that don't exist yet. In C, the
  `locked=hidden` view also makes locked cubbies look exactly like the spare blank cubbies (Household, Snacks), which
  is one more reason for spaces there.

## Q4. Wording

**Recommendation (taken: TOY MACHINES):**

- The sign and the title say **TOY MACHINES**. The thing inside is a **capsule**, and what you get is a **figurine**.
- Each machine's label reads "**3 of 8 left**", or "**All 8 collected**" when it is empty.
- The price reads "**1 coin**".
- The reveal says "**NEW!**", then the item's name, its aisle, and "**In stock from your next run**".
- The hint reads "**Pick a machine: 1 coin a capsule.**"

"Toy machine" is plain, warm and unmistakably not a gambling term. "Capsule machine" (`capsule_63_a.html?words=capsule`)
is the plan's word and is also allowed. Neither ever says "gacha". The figurine line says "stock" because the Run info
tab already calls the run's pool STOCK.

## Stated defaults (the rest of the issue's list; still standing after the answers)

- **The draw's RNG source:** a seed and a draw count in `ProfileState` (`capsule_seed`, `capsule_draws`), which raises
  `FORMAT_VERSION` to 2.
  - Each draw uses `EventLog.derived_stream(capsule_seed, "capsule_%d" % capsule_draws)` and passes it into
    `core/capsule_draw.gd` (no global random).
  - The seed is made outside `core/`: the screen that loads the profile (title or results) calls
    `EventLog.new_run_seed()` when the profile has no seed yet (a v1 profile, or a new one), passes it into
    `ProfileState` and logs it. `core/` (and so `SaveService`, which lives in `core/`) never makes a seed. The count
    starts at the number of unlocked items.
  - `capsule_seed` is saved as a decimal string, like `RunSave`'s `run_seed` (JSON numbers are doubles, and
    `ProfileState._read_int` rejects negative values); `capsule_draws` is a plain non-negative int.
  - A v2 profile opened by an older build fails the version check, so that build backs it up as `.bad` and replaces it
    with a fresh profile (`SaveService`'s usual treatment of a newer format), as with any format bump.
  - Why: the run save is gone by the time you draw, and a title-screen draw has no run seed. The derived stream from
    the ended run's seed would still need the seed kept in the profile. A fresh unseeded RNG can't be replayed in tests
    or from a log.
  - Quitting can't reroll a draw, because the profile is saved right after the draw. This is recorded in
    `core/AGENTS.md`'s seeded-randomness invariant. The simulator keeps its own machine pick and stream, as the issue
    says.
- **At full collection** with coins still coming in:
  - Every machine shows an empty globe with a gold ALL COLLECTED rosette and can't be picked.
  - The panel shows COLLECTION COMPLETE and "Your coins keep adding up".
  - Coins keep printing on the final receipt and the title. Nothing else spends them (no shop, no second use).
  - The entry button stays, so the shelf can still be visited.
- **At 0 coins:** the machines dim and the tomato notice reads "No coins left. Runs that pass shift 4 pay coins on the
  final receipt." (section 7.1's table pays no coins for a run lost on shifts 1 to 4, and the overtime coin comes in
  about 1 run in 10).
- **When the profile can't be saved:**
  - Every machine wears an OUT OF ORDER paper and can't be picked. The coins chip shows "?", and the tomato notice
    (with the warning triangle) reads "Your collection can't be saved right now, so the toy machines are switched
    off." (one string on every page). The shelf still shows whatever the profile could read.
  - Only coins show "?": that follows section 7.1's "you have ?" for a coin total that wasn't saved (the run's coins
    were added in memory but never written). The collection and the "n of m left" counts haven't changed since the
    profile was read, so they are shown as read.
  - A save that fails *at* a draw: the code saves before it reveals. If `SaveService.save_profile` fails, the draw is
    rolled back in memory (the coin and the item come back), the failure goes through the injected reporter, and the
    machines switch off with the same notice. So nothing is shown that wasn't saved.
- **The list `start_new_run` uses until #65:** **`RunStock.surprise_list`** (the seeded pair on a derived stream next to
  `IMPULSE_RACK_STREAM`), the plan's cut-list fallback, which has to exist anyway. It is built and tested now and
  writes nothing to `last_list`.
  - Why not the pre-fill (section 7.2: the last list, otherwise the newly listable aisle, otherwise the two base aisles
    with the most unlocked items)? Without #65's note the player can't see or change it, so the first list is written
    to `last_list` and **locks in**: it repeats every run, one base aisle disappears for good, and a machine-opened
    aisle that later becomes listable (Fruit & veg and the others) is never listed. A list is needed after as few as 3
    base-machine draws, and #65 is cuttable, so the lock-in could ship.
  - #65 then switches `start_new_run` to the note's list, pre-filled as section 7.2 says. If you'd rather keep the
    pre-fill until #65 and accept the lock-in, say so.
- **Telemetry:** log a `capsule` event with `machine` (aisle id), `item`, `run_index`, `coins_left` and `draw`. Add a
  `docs/PROTOTYPE_PLAN.md` section 8 row, and have the log summary count draws per machine.
  - Draws can happen outside a run. A draw from the results carries the ended run's `run_id` (still `EventLog.run_id`);
    a title draw carries an empty `run_id`. `run_index` identifies the run either way, and the log summary counts
    draws per machine from both kinds.
- **The debug tool:** a Profile section in the debug panel with three actions, all through `ProfileState` and
  `SaveService` (tests redirect the folder):
  - "Give coins" (+1 and +5).
  - "Draw from <machine>": the real draw, so the key item still comes first.
  - "Unlock all" and "Reset collection".

  #65 and #69 reuse it. Prepared save files would break at every `FORMAT_VERSION` change.
- **The machine row:** `balance.aisles` order. With 3 machines (machine-opened aisles cut) the row centres. The globe
  or window shows one capsule per item left (at most 8), and the label states the number, so it is never told by
  picture alone.
- **The reveal** (#63's still result, which #64 must end on): the figurine at 2x on a gold medallion, the NEW! burst,
  the name label, the aisle glyph and name, and the stock line. There is no rule text and no card. In #63 it simply
  pops in (`UiKit.pop_in`); the coin, crank, capsule and pop beats in these pages preview #64.
- **Hover and press:** an enabled machine lifts 4 px and brightens with the hand cursor. Disabled machines keep the
  arrow cursor, and each disabled state carries a label or a paper, never colour alone. The coins chip pops as it
  drops by 1. In the preview the counters change on their beats: coins as the coin goes in, "left" as the capsule
  drops, FIGURINES n / 30 at the pop (a #64 beat; the plain #63 panel updates them all with the reveal).
- **Static art for #63** (reviewed by you, logged in `production_log.tsv`). Updated for look A (decided): one
  machine body (`scenery/toy_machine`, 72x140 art px; the prep's text for C named `scenery/wall_machine`, 60x100) is
  recoloured per aisle by a palette map from `sign_color`. That needs a new `@derive` mode in
  `tools/pixel_art.py` (today it only takes `golden=<rank|yellow|egg>`), for example `@derive <source> aisle=<id>`
  mapping the body's ramp to the aisle's sign ramp, with its tests in `pixel_art_test.py`: part of #63's art cost.
  The alternative is 6 hand-made recolour sources. Also `scenery/exit_vestibule`, `frames/aisle_sign`,
  `frames/display_cabinet` and `scenery/shelf_plank` (C's `frames/display_case`, its cubby and `scenery/exit_wall` are
  dropped). #64 adds the coin,
  crank (4 frames), flap and capsule halves.
- **Changelog:** none for this prep (docs only). The build adds rows to both plans, as the issue says.

## Findings worth knowing

- Only 3 of the 30 capsule items have sprites (Strawberries, Croissant, Crisps). Until #57 and #58, 27 figurines are
  art-pending boxes. On the 1x shelf their printed names are at 8.5 px, which is barely legible, so the hover tag
  carries the name.
- `needs_list` becomes true at the 3rd base-aisle capsule (14 + 3 > 16). The 6 base-aisle capsules are 7 of the 30,
  and the first draw from each base machine is its key item. So a list can be needed after as few as 3 draws: a
  player who sticks to the base machines meets the list after 3 base-machine draws (about 3 runs at 1 coin a run).
- The issue says the machine must differ from the exit kiosk, but #77 replaces the kiosk with the restock hatch. Every
  look here avoids hatch, box and belt shapes.
