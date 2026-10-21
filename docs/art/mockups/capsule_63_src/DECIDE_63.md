# #63 decide list: capsule machines, the draw, the shelf and the list logic

Decide prep, 2026-10-21. Nothing is decided. Open `docs/art/mockups/capsule_63_index.html` first: it links every page
and still. The three looks are live: click a machine and the draw plays (the note in the bottom-right corner switches
states). The shared brief is `capsule_63_src/BRIEF.md`.

Four real questions (Q1 to Q4), each with a recommendation. Everything after them is a stated default from the issue's
"decide with the user" list: say so if you want one changed.

## Q1. The machines' look

| Option | Page | What it is |
|---|---|---|
| **A: exit vestibule** | `capsule_63_a.html` | A camera cut to the store exit: six round-globe toy machines on the tiled floor between the wall and the sliding doors (EXIT sign, the street at night). Big machines (144x280), the classic silhouette. The shelf is its own screen (`capsule_63_shelf.html`, a wooden display cabinet). |
| **B: machine bank pop-in** | `capsule_63_b.html` | No camera cut: a steel vending cabinet pops in over the shaded results, the size of the other centred panels. Six boxy window machines on a shelf whose price rail carries "3 of 8 left". Separate shelf screen. The cheapest: one machine sprite and one frame. |
| **C: collector wall** | `capsule_63_c.html` | Machines and shelf are one wall at the exit. Each aisle is a column: a small wall-hung globe machine, its label, and under it a wooden case with one cubby per item, a "?" in each locked one. After OK the figurine flies into its cubby. No separate shelf screen. |

**Recommendation: C.** Reasons:

- One place per fact (your note on the shift screen): the case under each machine *is* that machine's "what's left",
  so the shelf, the catalogue and the items-left count are the same object, and every new figurine visibly lands in
  its place. That landing is the collection's payoff, and it needs no extra screen.
- It fits the issue's hardest fit test on the panel itself: 30 figurines at 1x in 6 aisle groups plus 6 machines in
  1280x720 (the tallest case ends at y 592).
- It is a physical store fixture (wall, brackets, wooden cases), which you have preferred over flat panels, and it
  looks nothing like #77's restock hatch.

Costs and risks: the machines are smaller (120x200 against A's 144x280), so #64's crank and coin read smaller (the
capsule still hops to the centre for the reveal); the base aisles' cases are short (2, 2 and 3 items), which leaves
wall space on the left, and the Household case has one blank cubby; the fly-to-cubby adds 0.5 s after OK (#64,
skippable; reduced motion lands at once). If C feels too busy, **A** is the fallback: the most iconic machines, at the
price of a camera cut and a second screen for the shelf. B is the cut-list look.

## Q2. Where the machines are reached, keeping coins, and a title-screen draw's run index

**Recommendation:** from both places, and coins can be kept.

- **After a run:** a secondary button "Toy machines ›" beside New run on the results (results look A, the till
  report). Done brings you back to the results.
- **From the title:** the space reserved on the right of title B (#56) holds a small machine prop and the same button.
  Done brings you back to the title.
- **Coins can be kept.** Spending is never required, and nothing nags. Saving coins for a machine you want is a fine
  choice, since the player picks the machine and never the item.
- **A title-screen draw's run index is `run_count - 1`,** the same as right after the last run (the issue's rule).
  The item is in the next run's stock whether or not a run is in progress. With a saved run in progress, its stock is
  already fixed, so the new arrival rides 2 runs instead of 3. That is simpler than a second rule.

The alternative is results only, which is simpler but means a player who quit before spending has to finish another
run to reach the machines.

## Q3. The shelf: locked items, which items, names and order

**Recommendation:** locked items are **empty spaces** (a dashed box with "?"); the shelf holds **capsule items only**
(30); names show **on hover** (a tag with the name, aisle glyph and aisle); the order within an aisle is **data
order** (the key item first, so each figurine has a fixed spot).

- Empty spaces show the progress the machine already states ("3 of 8 left"), and fixed spots make the shelf fill in
  like an album. Hidden locked items (see `locked=hidden` on the shelf and on C) hide nothing the machine doesn't
  already show, and make the shelf look emptier.
- Capsule items only: the shelf is the record of what came out of capsules. The 14 base-aisle products were never
  drawn, and adding them would bring the shelf to 44 and blur "collected".
- On hover: section 1 keeps the hand to art only, and printed names at 11 px under 48 px sprites are busy
  (`capsule_63_shelf.html?labels=1` shows them). Until #57 and #58 draw the sprites, the art-pending boxes print
  their names anyway.
- Data order is needed for fixed spots. Draw order would reshuffle as you collect.

## Q4. Wording

**Recommendation:**

- The sign and the title say **TOY MACHINES**. The thing inside is a **capsule**, and what you get is a **figurine**.
- Each machine's label reads "**3 of 8 left**", or "**All 8 collected**" when it is empty.
- The price reads "**1 coin**".
- The reveal says "**NEW!**", then the item's name, its aisle, and "**In stock from your next run**".
- The hint reads "**Pick a machine: 1 coin a capsule.**"

"Toy machine" is plain, warm and unmistakably not a gambling term. "Capsule machine" (`capsule_63_a.html?words=capsule`)
is the plan's word and is also allowed. Neither ever says "gacha". The figurine line says "stock" because the Run info
tab already calls the run's pool STOCK.

## Stated defaults (the rest of the issue's list)

- **The draw's RNG source:** a seed and a draw count in `ProfileState` (`capsule_seed`, `capsule_draws`), which raises
  `FORMAT_VERSION` to 2.
  - Each draw uses `EventLog.derived_stream(capsule_seed, "capsule_%d" % capsule_draws)` and passes it into
    `core/capsule_draw.gd` (no global random).
  - A v1 profile gets its seed when it is loaded. The seed is made outside `core/` by `SaveService` and logged; the
    count starts at the number of unlocked items.
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
- **When the profile can't be saved:**
  - Every machine wears an OUT OF ORDER paper and can't be picked. The coins chip shows "?", and the tomato notice
    (with the warning triangle) explains why. The shelf still shows whatever the profile could read.
  - A save that fails *at* a draw: the code saves before it reveals. If `SaveService.save_profile` fails, the draw is
    rolled back in memory (the coin and the item come back), the failure goes through the injected reporter, and the
    machines switch off with the same notice. So nothing is shown that wasn't saved.
- **The list `start_new_run` uses until #65:** the **pre-fill** (section 7.2: the last list, otherwise the newly
  listable aisle, otherwise the two base aisles with the most unlocked items, ties by data order). It writes
  `last_list`. It is what #65's note will show by default, so nothing changes for players when the note lands.
  `RunStock.surprise_list` (the seeded pair on a derived stream next to `IMPULSE_RACK_STREAM`) is built and tested now,
  and it stays the cut-list fallback.
- **Telemetry:** log a `capsule` event with `machine` (aisle id), `item`, `run_index`, `coins_left` and `draw`. Add a
  `docs/PROTOTYPE_PLAN.md` section 8 row, and have the log summary count draws per machine.
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
  drops by 1.
- **Static art for #63** (reviewed by you, logged in `production_log.tsv`). One machine body (look C:
  `scenery/wall_machine`, 60x100 art px) is recoloured per aisle by a palette map from `sign_color`, the way GOLDEN's
  `@derive` maps palettes. Also `frames/display_case` and its cubby, and `scenery/exit_wall`. #64 adds the coin,
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
