# Shift screen mock-ups (2026-10-16)

Static HTML mock-ups for the shift screen rework discussed in #80 ("shift scene: rework or livelier touches"). They are a direction check, not game code: nothing here is loaded by Godot (`docs/art/` has a `.gdignore`), and no rule or layout in the game changed.

All three show the same state as `docs/art/shift_screen_1920x1080.png` on `feature/items-and-scanner` (#79): shift 5 of 8, quota €73, projected €22, an inspection closing one slot, the Multipack coupon hovered.

| Page | Capture | Idea |
|---|---|---|
| `shift_screen_a.html` | `shift_screen_a_1920x1080.png` | **A: boutique, calmed.** The 2026-10-14 boutique tone kept, with one place per fact: one sticker per item, a single corner mark (fizzle or combo), per-item payouts on the receipt with the hovered item's details expanded there, the money on the register LED only, a shorter top bar, no status line or hint text. |
| `shift_screen_b.html` | `shift_screen_b_1920x1080.png` | **B: proposals 1 + 2.** Proposal 2's layout (quota bar in the top bar, a monitor showing the hovered item, a receipt list, one big CHECKOUT) with proposal 1's warmth (a stocked store behind the counter, the waiting customers as silhouettes, a wood counter, the hand in a shopping basket). Back to the art bible's cream, teal, tomato and mustard. |
| `shift_screen_b2.html` | `shift_screen_b2_1920x1080.png` | **B2: B with relief.** Reworked on 2026-10-16 so the depth no longer distorts proportions. One camera for the whole scene: a little above counter height, with a single vanishing point far above the screen, so receding edges converge only slightly and front faces stay straight on. There is one key light from the upper left. The belt is a 74 px deep top face (about 45 cm next to a 96 px item) with a steel frame and lip; it is the counter's back edge, with a steel guard along it and no wood strip behind it, and the item sprites stand on it with contact shadows, the hovered coupon lifted 16 px. The empty slots are item-sized footprints, and the closed slot has desk-height stanchions. The hand (the deck, to be renamed Cart) sits in four teal supermarket hand baskets with two items each (about two thirds of each item shows above the front rim), on a steel ledge. It has no labels; the monitor shows an item's details when it is hovered. The monitor hangs from the ceiling. The receipt feeds into a real printer box, and the register column shares the ledge's floor line. A female cashier in a teal apron stands by the receipt. Behind the counter are distinct store sections at half scale, pushed back by a cool haze: cold cases with glass doors, a bakery shelf with wicker baskets and a clock, a fruit and veg stand under a hanging sign, and an exit sign. The wall under the monitor and the receipt is left calm. The right column is a cash register: CHECKOUT is its big bar key, Redraw a smaller key beside a quiet numeric keypad, and a cash drawer with a lock and a coin tray sits below. The belt's front flows into the steel slot rail. A polish pass put everything on the 2 px pixel grid: flat colour bands instead of gradients, stepped contact shadows, pixel fizzle and check marks, and 2 px ink outlines. It also set a colour rule: tomato means a fizzle, CHECKOUT or CLOSED. Coupons are captioned in teal, and the inspection warning is a mustard triangle. The loyalty stamps show icons instead of initials, and the closed slot is a dark plate. Only Multipack's two fizzles are marked, matching the game, where unmet bonuses don't fizzle. |
| `shift_screen_b2_count_up.html` | `shift_screen_b2_count_up_1920x1080.png` | **B2 count-up.** The same screen mid-count, on the third of four items. The hung monitor is the store's customer display and shows the big running subtotal, the latest gain and the quota bar. Paid chips sit above the scanned items, the receipt prints its lines on the right, and the hand and the keys are dimmed. The big score never covers the receipt. |
| `shift_screen_b2_mirrored.html`, `shift_screen_b2_mirrored_count_up.html` | `shift_screen_b2_mirrored_1920x1080.png`, `shift_screen_b2_mirrored_count_up_1920x1080.png` | **B2 mirrored (2026-10-17), both states.** Made for the moving belt that comes later: the register column, the printer and its receipt and the cashier move to the left, and the belt flows left toward them. Slot 1 is the slot next to the register, so it is the first item to reach the cashier, and the slots and the hand still read 1 → 7 left to right. The camera is mirrored about the screen centre, so the vanishing point stays at (640, −1600). The back wall is mirrored with the rest (cold cases at the right, the fruit and veg stand beside the cashier). Text, numbers, icons, item art and the cashier are moved but never flipped. The key light stays at the upper left. One addition: a subtle direction cue, three light-steel pixel chevrons on the steel apron under each ticket, pointing left. The page draws B2 and then runs a mirror pass (see its header comment). |

`compare_now_a_b.png` puts the current screen, A and B side by side; `compare_b_b2.png` compares B, the first B2 and the reworked B2.

The user's feedback so far: the screen gets messy quickly and should be cleaner (proposal 2 appealed); B is the liveliest; the screen felt flat and seen from above, which B2 answers; the items still need a visual improvement (#80), which these mock-ups do not attempt beyond grounding them.

## What is real and what is not

- **Real:** the item sprites, icons and scenery in `assets/art/` (copied from `feature/items-and-scanner`, since `main` doesn't have them yet), and the three fonts, loaded from the repo's `fonts/`. Item rules, payouts and fizzle texts are the ones from the #79 screenshot.
- **Approximated:** every frame (belt, counter, labels, basket, monitor, register, buttons) is flat CSS in the palette, not the 9-slice pixel-art frames. B2's counter, belt and ledge are SVG polygons from one vanishing point (slat ends rounded to 2 px), which a pixel artist can repeat: in the game the belt would be a tiled texture in a trapezoid mask with a 9-slice frame, and the stanchions are atlas slices of `rope_post` and `velvet_rope`.
- **Placeholders:** the customer silhouettes in B and B2. Real customer art would be new scope.

## Re-capturing

```sh
node docs/art/mockups/capture.js docs/art/mockups/shift_screen_b2.html /tmp/b2.png
```

It needs Playwright and a Chromium (`CHROMIUM_PATH=/path/to/chromium` to pick one).

## Planning effects mock-ups (#71, 2026-10-18)

Static HTML mock-ups for issue #71's planning effects, made after the user's play test of the first build (a band of small chips floating above each belt item), which found it flat, with numbers floating and links hard to read. Each page is built on `shift_screen_b2_mirrored.html` (#84) and shows #60's reference row (Eggs, Bread, Milk, Multipack and three Milks) under the Spot check, with Multipack hovered on the `_hover` page. Their numbers are invented; the game shows the real steps.

| Page | Hover page | Captures | Idea |
|---|---|---|---|
| `planning_effects_a.html` | `planning_effects_a_hover.html` | `planning_effects_a_1920x1080.png`, `planning_effects_a_hover_1920x1080.png` | **A: on the item.** Received effects are stickers slapped on the item (a cream "+N" price-gun label, a gold "×N" starburst, each with its giver's mini badge), a boosted item stands in a stepped pixel halo, a denied one is greyed under a rubber stamp, a giver wears a hanging ribbon ("×3 › 3 Milk"), and a price-gun tag under each item gives its pay. |
| `planning_effects_b.html` | `planning_effects_b_hover.html` | `planning_effects_b_1920x1080.png`, `planning_effects_b_hover_1920x1080.png` | **B: on the ticket and the rail.** The pay sits on the ticket (the base price struck, the final pay on a gold burst or a tomato tag), and a brass rail strip along the belt lip runs from the giver's ticket to its targets, with a factor badge dropping onto each. |
| `planning_effects_c.html` | `planning_effects_c_hover.html` | `planning_effects_c_1920x1080.png`, `planning_effects_c_hover_1920x1080.png` | **C: arcs.** Effect arcs over the belt from each giver to its targets, with tokens on the rail and result bubbles over the items. |
| `planning_effects_h1.html` | `planning_effects_h1_hover.html` | `planning_effects_h1_1920x1080.png`, `planning_effects_h1_hover_1920x1080.png` | **h1: A's stickers, halo and stamp, B's ticket pay and B's rail strips.** Stickers stack in apply order and grow upward over the item and the back wall, never onto the ticket; the ticket carries the pay; the calm brass strip says who gives what; the monitor's brief keys the stickers. Hovering a giver turns its strip bright gold with each target's gain, keeps only its stickers lit, fades the rest, and the monitor and receipt explain. |
| `planning_effects_h2.html` | `planning_effects_h2_hover.html` | `planning_effects_h2_1920x1080.png`, `planning_effects_h2_hover_1920x1080.png` | **h2: stickers and pipes.** A's stickers with C's links as chunky gold pixel pipes running in the gap under the monitor and dropping onto each boosted item, and B's ticket pay. |

The user rejected h2's pipes, A's ribbons and the first build's floating chip band, and **approved h1 as "perfect"** (2026-10-18). The game builds h1 from `planning_effects_src/H1_BUILD_SPEC.md`, which maps every mock-up value onto the game's geometry and palette; the game's captures are `docs/art/shift_screen_effects_*.png`.

### Re-generating

Each page has a generator in `planning_effects_src/gen_<name>/` (`a`, `b`, `c`, `h1`, `h2`): a Python script (standard library only) that patches `shift_screen_b2_mirrored.html` with its overlay script and stylesheet, and writes both pages here. `run.sh` rebuilds them and captures them at 1920x1080 through headless Chrome (`cap.sh`; `CHROME=<path>` picks the browser, and its profile goes to a throwaway folder in `TMPDIR`):

```sh
sh docs/art/mockups/planning_effects_src/gen_h1/run.sh
```

The base page reaches this branch with `main` (#84). Until it is merged in, the generators stop with "shift_screen_b2_mirrored.html comes from main (#84): merge main first".
