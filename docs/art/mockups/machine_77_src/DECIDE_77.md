# #77 decide list: the RECEIPT REWARDS machine, item upgrades and loyalty

Decide prep, round 3, 2026-10-20. Nothing is built. Round 2's last question (Q3, the machine look) is answered:
**F, restock hatch**. Round 3 measures your balance idea ("inspection can give a second ticket draw?") and shows it
in look F. Three questions are left (Q7 to Q9), plus the defaults Claude takes without asking. All the pages and
stills are on one page, `docs/art/mockups/machine_77_index.html` (captures: `machine_77_index_1920x1080.png` and
`machine_77_index_full.png`). The shared brief is `machine_77_src/BRIEF.md`. The simulator numbers and how they were
measured are in `machine_77_src/BALANCE.md` ("Round 3: inspection bonus ticket").

## Decided 2026-10-20

| | Decision | What it means |
|---|---|---|
| Q1 Power | **B: STAMP DAY floor** | After shifts 2, 4 and 6, a LOYALTY card behind 1 / 2 / 3 stamps gets a free register pick. Today's quotas stay. |
| Q2 Guarantees | **Yes** | A guarantee may lift a drop's rolled tier (Regular 3's "1 of 3 at least RARE", REGISTER's "3 different types"). The odds card always shows the true odds. |
| Q4 Meters | **A: punch ticket** | 3 holes under each chute key. A hole is punched only when a later visit can use it. |
| Q5 Upgrade art | **BIG drawn per item, GOLDEN an automatic recolour** | You said BIG and GOLDEN look good and the effects are "perfect". |
| Q6 Tempo | **1x** | About 20.5 s a visit (the page's default). |
| Chutes | **Clean split of NEW ITEMS and UPGRADES** | See below. You were confused by the difference in round 1. |
| Art | **Banana and Eggs redrawn: approved** | Plain and BIG redrawn, GOLDEN regenerated. You said they are "a lot better". Before/after: `machine_77_eggs_banana_before_after.png`. |
| Q3 Machine look | **F: restock hatch** | "I like restock hatch F." Three stock bays drop a box each onto a runway into the RESTOCK door; the boxes come out of the curtained hatch on a little checkout belt, stop at their gates in the tray and split open on the reveal. The flow page now opens on F; D, E, A, B and C stay on the MACHINE LOOK row for comparison. |

You also liked: the receipt-to-machine transition ("really good"), the rarity reveals ("simple and nice"), and
the punch-ticket meters. All three are kept as they were.

**The clean split** (now on the flow page):
- **NEW ITEMS · "ADD TO CART"** gives you one more item. It always arrives **plain**. Its rarity is the product's
  own: basic products are Common, stronger products Rare (Milk and Eggs among them), the strongest Legendary (`product_rarity.json`, a placeholder
  until the build measures it). Fresh stock: 12 Common, 6 Rare, 2 Legendary (Tea bags, Carrier bag).
- **UPGRADES · "IMPROVE ONE YOU OWN"** is the only way to get BIG or GOLDEN. Still padlocked except after shifts 3,
  5 and 7.
  - Common: one step on one chosen copy (plain → BIG, or BIG → GOLDEN).
  - Rare: two steps on one plain copy (straight to GOLDEN).
  - Legendary: **SHELF UPGRADE**, every copy of one item goes one step up. No new copy. Offered only for an item
    with 2 or more copies that can step (on one copy it would just be the Common step); if no item qualifies, the
    Legendary roll steps down a tier.
  - Golden twin is gone (it added a copy, which is NEW ITEMS' job). An item that can't take the steps is not
    offered. The odds card's tier % are over the prizes that actually drop, so they add up to 100% on short draws.
- **The landing shows the difference.** NEW ITEMS: a new plain item flies into an empty cart slot, "NEW IN CART",
  the count goes +1. UPGRADES: an up-arrow flies to the copy you own, it glints and changes in place, "UPGRADED",
  the count stays the same.

## What to open first

1. `machine_77_flow.html`: opens on look F. Try shift 3 (Spot check passed): after the first pick, the BONUS TICKET
   stub prints and the second visit runs. `?inspection=off` shows the same shift with one ticket.
2. The bonus stills, `machine_77_flow_f_bonus_1_*.png` to `machine_77_flow_f_bonus_9_*.png`, for the beats without
   playing.
3. `machine_77_loyalty.html`: the balance chart, with round 3's rows under "ROUND 3: INSPECTION BONUS TICKET"
   (still: `machine_77_balance_r3_page.png`).

## Round 3: the inspection bonus ticket (proposed)

**The rule.** Inspections land on shifts 3, 5 and 7 (`inspection_shifts`: Spot check, Short belt, Coupon slot
closed), the same shifts that open UPGRADES. **Passing an inspected shift gives a second full machine visit**:
choose any chute again (UPGRADES included, since it is open on those shifts), 3 prizes, pick 1. The chute's Regular
meter counts it like any visit. REGISTER's 3-stamp cap and STAMP DAY are unchanged (STAMP DAY is after 2/4/6, so the
two never meet).

**How it looks in F** (`machine_77_flow.html`, on by default at shifts 3, 5 and 7):
- The first receipt carries an "INSPECTION PASSED ✓" stamp with the inspection's name (PAID moved down to make room).
- After the first pick lands, a "BONUS TICKET!" stamp covers the machine's head ("Inspection passed: Spot check"), and a
  short stub with the same stamp prints and feeds into the slot. The display holds "BONUS TICKET!" for about 1.5 s,
  then "PICK A CHUTE AGAIN" for 0.9 s; the chute keys go back to unlit (none looks chosen) and relight, and the ORDER /
  BONUS slip shows "?" on its lines until you confirm a chute (on both visits).
- The second odds card starts from the state after the first pick: the REGULAR hole just punched already counts, the
  cart holds the first prize, a register just won no longer drops. A red band says what changed ("REGULAR 1 › 2").
- The hatch packs 3 more boxes (packing 1.2 s instead of 1.8 s, reveal gaps 0.15 s), then reveal, pick, landing,
  punch. The second visit takes about **13.2 s** at 1x (13.6 s for UPGRADES, 8.3 s under reduced motion); the first
  visit stays 18.9 s.
- The odds cards are exact on the second visit too: 472 new states checked at 100,000 rolls each, largest gap
  0.55 points (sampling noise; re-rolled at 400,000 it fell to 0.08).

**Round-3 numbers** (greedy@sensible, option B, the clean split, live quotas 34 … 120; ± is the 95% interval):

| Row | What the run gets | Runs | Win | Shift 3 pass |
|---|---|---|---|---|
| r2 | Round 2: split, UPGRADES blind, no bonus | 316 | 22.2% ± 4.6 | 66% |
| **R3a** | + bonus ticket after 3/5/7 | 262 | **32.1% ± 5.7** | 68% |
| **R3b** | R3a + Carrier bag and Tea bags Rare (were Legendary) | 275 | **35.6% ± 5.7** (in the band) | 69% |
| R3c | R3a, Breakfast special build (#42 check) | 281 | 28.8% ± 5.3: **passes** (bar ⅔ × 32.1% = 21.4%) | 60% |
| R3d | R3b, Breakfast special build | not run (time cap) | | |
| R3e | R3b + a bonus ticket after shift 1 too | 203 | 38.4% ± 6.7 (in the band) | **75%** |

- **The bonus ticket is worth about +10 points** (22% → 32%, significant: z ≈ 2.7), **but this is an upper bound**:
  the simulated UPGRADES player picks the best item at each rolled tier, while the design draws (item, tier) prizes,
  so the best item (often Milk) is not always offered. The bonus doubles the UPGRADES visits, so it doubles this bias. It helps shifts 4–8 (shift 5 pass 78% → 92%,
  shift 6 71% → 82%).
- **It cannot lift shift 3**, because the first bonus comes after it: shift 3 stays at 68–69% and is now where most
  runs end. Only R3e (an extra bonus after shift 1) lifts it, to 75%, on fewer runs.
- **Carrier bag and Tea bags to Rare** add about +3.5 points and put R3b in the 35–40% band, right at its 35% edge;
  with the optimistic UPGRADES player, R3b could fall below 35% once the build draws item-named prizes. R3b and R3e differ by
  3 points, inside the noise.
- **GOLDEN Milk gets worse:** about 1.9 copies per run (4.4–4.8 GOLDEN copies in all, double round 2), because up to
  6 UPGRADES visits a run turn almost every Milk, Eggs and Coffee GOLDEN. A GOLDEN Milk nerf will pull these rows
  down a few points, so the build re-measures after it.
- What the model leaves out: drops that name their item (see above; the build re-runs R3a/R3b with them), and the
  Regular-3 guarantee on UPGRADES and NEW ITEMS (a small bias the other way); the blind player takes UPGRADES on both visits whenever a copy can step; COUPONS is
  still mixed into the offer; "3 different types" is not in the register draw; the impulse rack is still in the
  runs. Differences under about 7 points between rows are not reliable.

---

## Q7. Adopt the inspection bonus ticket?

Header: `Bonus`.
- **Yes, after every passed inspected shift: 3, 5 and 7 (Recommended).** It is the biggest single lever measured
  (+10 points, an optimistic upper bound), it turns an inspection into something to look forward to, and in F it
  costs one stub and about 13 s.
- Yes, but only after shift 3: a smaller gain (not measured), and fewer GOLDEN copies.
- No: the split stays at 22%, and the band needs other levers (product rarity, quotas, UPGRADES on top of the reward).

## Q8. Which extra lever, on top of the bonus ticket?

Header: `Lever`. R3a alone is 32%, below the 35–40% band.
- **Carrier bag and Tea bags to Rare (Recommended):** R3b, 35.6% ± 5.7, at the band's lower edge. It is a
  balance-data change only, and those two were the most-picked products before the split made them 3% per drop.
  R3a/R3b are optimistic (see above), so R3b may land below 35% in the build; if it does, the gentler shift-3 quota
  is the next lever.
- Also a bonus ticket after shift 1 (R3e, 38.4% ± 6.7): the only measured lever that lifts the shift-3 wall
  (69% → 75%), but shift 1 has no inspection, so the "inspection passed" story breaks.
- A gentler shift-3 quota (53 → about 45) instead: aims at the wall directly, not measured yet.
- Carrier/Tea to Rare and a gentler shift-3 quota together: the build measures the pair.

## Q9. What may the bonus ticket pick?

Header: `Bonus pick`.
- **Any chute, same rules as the first ticket (Recommended):** NEW ITEMS, COUPONS, REGISTER (if the card isn't full)
  or UPGRADES; the chute's Regular meter counts it. Simplest to explain, and it is what the flow page shows.
- A different chute from the first ticket: forces variety, but blocks a double UPGRADES on the shift you need it.
- UPGRADES only ("the inspector's reward"): the clearest theme, but it piles on GOLDEN copies (GOLDEN Milk is
  already the problem) and does nothing for a cart with no item that can step.

---

## Defaults (taken without asking; say if you want one changed)

**Machine and flow**
- One visit after each passed shift 1–7, with 4 chute keys: NEW ITEMS · COUPONS · REGISTER · UPGRADES. UPGRADES is
  padlocked except after shifts 3, 5 and 7. REGISTER shows CARD FULL at 3 stamps.
- Subtitles on the keys: NEW ITEMS "ADD TO CART", COUPONS "ADD TO CART", REGISTER "STAMP YOUR CARD", UPGRADES
  "IMPROVE ONE YOU OWN".
- The machine replaces the reward print-out and the exit kiosk. #66 and #56's kiosk question close into #77.
- The impulse rack is cut. Shift 1 starts straight away, and the first visit follows it.
- NEW ITEMS and COUPONS keep a "bin it" skip. REGISTER and UPGRADES must pick, as the kiosk does today.
- Each odds card is exact: tier % per drop, each prize's % of being among the 3, all from one draw process.
  Round 2 checked 44 states against 100,000 seeded rolls each; the largest gap was 0.51 points (sampling noise; it
  halves at 400,000 rolls).
- NEW ITEMS always holds 1 generally useful product. If none drops, the last drop whose rarity has one is swapped
  for one of the same rarity. It is skipped only when all 3 drops roll Legendary and no generally useful Legendary
  is stocked: 0.003% of draws at Regular 0, 1.06% at Regular 3 (for example Pantry + Bakery). The fresh stock
  always holds (Carrier bag is stocked).
- A rarity with nothing in it steps down a tier, then up (for example Cold cases + Snacks has no Legendary product).
  The odds card says so.
- The first-COUPONS guarantee (Breakfast sticker, Multipack or 2 for 1) applies to any drop whose tier holds one. It
  always holds without changing a tier.
- "One fits your cart" stays, inside the rolled tier.
- Inspections are unchanged and still printed on the receipt before the feed. If Q7 is yes, a passed inspection
  also stamps "INSPECTION PASSED ✓" on the receipt and prints the BONUS TICKET stub after the first pick.

**Bonus ticket details (if Q7 is yes)**
- The second visit starts from the state after the first: the meter hole just punched counts, the cart holds the
  first prize, a register just won no longer drops. The odds card's red band names what changed.
- Shift 7's first ticket now punches its REGULAR meter, because the bonus visit can use it (the punch-ticket rule:
  a hole is punched only when a later visit can use it).
- The 15-card cart limit bites sooner (the shift-3 demo goes 14 → 15 → 16). A pick into a full cart uses the game's
  existing deck-full chooser; the page only says "cart full: swap 1 out".
- The bonus visit keeps the "bin it" skip on NEW ITEMS and COUPONS, like the first.
- Known page gaps: the page's invented history of earlier shifts doesn't include their bonus tickets, and the
  LEGENDARY!! label overlaps the RESTOCK hood (from round 2's F); both are fixed in the build. Coins and the capsule machines
  (#63/#64) are unchanged and look nothing like this machine.

**Reveals** (`machine_77_reveals.html`, unchanged)
- One at a time, rarest last. Five signals per rarity: shape, pips, label, motion and time, and sound. Colour is
  never the only signal.
- Common keeps its small COMMON tab. The stamp reads "LEGENDARY!!". Under reduced motion each reveal takes
  0.3 s and keeps its shape, label and sound.
- At game size (120x150 tickets) the rule text drops to about 7 px, so it moves to a hover card.

**Register prizes and balance**
- Tiers are balance data: Common = Extra redraw, Extra coupon slot, Big basket; Rare = Coupon engine, Category
  engine; Legendary = Slot engine. The odds start at 75/22/3 per drop and move to 45/37/18 at Regular 3.
- Slot engine stays Legendary. Under the split, Breakfast special passes the #42 check (18.9% against 14.8%). The
  build reruns the check for all 5 builds at 480+ runs; if Breakfast special fails, Slot engine moves to Rare.
- **Getting back to the 35–40% band** is Q7 and Q8 now (round 3 measured the bonus ticket and the softer product
  rarity table). Not measured yet, kept as later levers: a gentler shift-3 quota, a STAMP DAY after shift 1, and
  UPGRADES given on top of the visit's reward instead of replacing it.
- After a GOLDEN Milk nerf, the build re-measures the chosen rows and reruns the #42 check for all 5 builds
  (R3d, Breakfast special under R3b, was not run; its bar would be 23.7%).
- A STAMP DAY stamp doesn't raise the REGISTER meter. A meter only rises when a later draw can use it. NEW ITEMS
  and COUPONS can reach Regular 3; REGISTER stops at 2. UPGRADES stops at 2 without the bonus ticket; with it (Q7 yes),
  UPGRADES has up to 6 visits and can reach Regular 3, as the flow page and `check_odds.js` show.

**Item upgrades** (`machine_77_upgrades.html`, `machine_77_upgrades_bay.html`)
- Products only, no coupon tiers in v1. Two steps at most on one copy: plain → BIG (+2 price) → GOLDEN (BIG's price
  and one rule field up). Each tier is a variant card, and a variant counts as its base card everywhere.
- Banana, Milk, Eggs and Coffee get BIG drawings first. A product without one can't be upgraded yet; it still drops
  from NEW ITEMS at its own rarity.
- GOLDEN is an automatic palette map in `tools/pixel_art.py`. Items that are already yellow (Banana) use a darker
  map (brass body, gold lit side, a 1 px paper rim), so they read as brass and gold. GOLDEN Eggs get a brass-dark
  rim so their round tops read against the grey carton. BIG Eggs is 8 eggs, only wider than the plain 6, which is
  weak at 1x; a taller carton is the fix if you want BIG to read on the belt.
- The numbers are the brief's placeholders. GOLDEN Milk (`bonus_each 2`) is the strongest, so it gets nerfed.
  GOLDEN Banana's BESIDE barely matters (0.06 GOLDEN Bananas per run), so it gets a real effect, for example the
  pair bonus counting twice. Both are re-measured once the tiers are data.
- The BIG / GOLDEN tag hangs under the ticket's left end, and a 6-step shine crosses an item on hover.
- The Banana and Eggs redraws go into `art/src/` in the build (the prep sources are in
  `machine_77_src/upgrades/src/items_v2/`). Left to polish: plain and BIG Eggs differ mostly in width at 1x, and
  the egg tops are a little squat.

**Build and tools**
- The machine goes into `SimPlayer` for real: separate NEW ITEMS and COUPONS chutes, "3 different types", and a
  blind chute choice from the shown odds. Every row is rerun with 480+ runs.
- Flagged, not fixed: `tools/balance_sim.sh` reuses one work folder (`reports/balance_sim`) and one search cache,
  so two runs at once in the same checkout overwrite each other's shards. The build either fixes the tool or runs
  one simulation at a time.
- Plan sections 5.2 and 7.2 are rewritten, with a changelog row, once Q7 to Q9 are decided (the look is F).

---

## Round 2 for reference

### Round-2 numbers (greedy@sensible, option B, live quotas 34 … 120; ± is the 95% interval)

| What the run gets | Win | Shift 3 pass |
|---|---|---|
| **B + clean split, UPGRADES taken blind** | **22.2% ± 4.6** (316 runs) | 66% |
| Same, Breakfast special build (#42 check) | 18.9% ± 3.9 (387 runs): **passes** (bar ⅔ × 22.2% = 14.8%) | 60% |
| B + product-rarity NEW ITEMS, no UPGRADES | 25.4% ± 4.8 (319 runs) | 66% |
| Round 1: B, today's uniform offer, no upgrades | 30–32% | 77–80% |
| Round 1: B + items arriving BIG / GOLDEN, blind | 35% ± 10 (85 runs) | 80% |
| Today (kiosk after 2/4/6, free) | 61% | 94.5% |

- **The split lands at 22%, below the 35–40% band.** Most of the drop is product rarity (about −5 to −6 points):
  Carrier bag and Tea bags, the two most-picked products, are now Legendary at 3% per drop.
- **Blind UPGRADES add nothing measurable** (22% against 25%): taking UPGRADES costs that visit's reward. Round 1's
  gain came from NEW ITEMS arriving BIG or GOLDEN, which the split removes.
- **Shift 3 is now the wall** (60–66% pass).
- GOLDEN Milk still ends up in about 1.2–1.4 copies per run, so it is still the one to nerf.
- What the model leaves out: COUPONS is still mixed into the offer, "3 different types" is not in the register
  draw, the blind UPGRADES player is crude, and the impulse rack is still in the runs.

The lever is now Q8.

### Q3 as it was asked (decided: F)

Header: `Machine`. You said A was closest, but the drum felt too random. D, E and F keep A's teal cabinet, mustard
head, cream chute keys, punch tickets, receipt slot and odds card, and drop the drum and chasing bulbs. Nothing in
them spins. All six run the same flow, odds, reveals, pick and landings (`machine_77_flow.html`, MACHINE LOOK row).
Stills: `machine_77_flow_{d,e,f}_*.png`.

- **D: coupon printer (Recommended)**: while your receipt feeds in, a small screen ticks its lines and says
  "RECEIPT OK" (that only proves the quota was met, before you pick a chute). After you confirm, the printer prints
  3 reward slips; each tears off, drops straight down between the two screens and slides along the tray to its
  cell. All 3 slips print the same lines (shift, quota, spend): nothing on a slip says why it got its prize,
  because the prize is a plain roll at the odds card's odds. Only the PRIZE line differs: it prints ● / ◆◆ / ★★★
  as it is revealed. It carries on the receipt story you liked (receipt in, rewards print out), the tray and
  tickets stay where A has them, and the printer can reuse the game's receipt printer. Draw 1.5 s, the last slip
  lands 1.1 s later; visit about 20.2 s.
- **E: click & collect lockers**: an order screen lists "ORDER No. 0437" with one row per locker. Each locker packs
  (a bar fills), turns green, and its door swings open on a paper bag, which becomes the ticket. Each row then
  shows the prize name and its rarity word. Calm and clear, but the lockers replace A's tray, and three doors that
  open and close are the most new art. Draw 1.6 s, visit about 20.2 s.
- **F: restock hatch**: three stock bays drop a box each through a trapdoor onto a runway under the bays, which
  carries it into the RESTOCK door; it comes out of the curtained hatch below on a little checkout belt (the game's
  belt colours) and stops at its gate in the tray; its tape splits open on the reveal. Each box stays on screen
  the whole way (under 0.1 s inside the hatch), and the bay box is the belt box made small (same tape, same
  number tag). The most "supermarket" motion, but the busiest, and the hatch sticks out past the cabinet's right edge.
  Draw 1.8 s, visit about 20.7 s.
- **A / B / C as in round 1**: prize drum, scratch & win, price-drop peg board.

Why D: of the three, it changes the least about A (same window, same tray), it continues the receipt story
(receipt in, slips out) without claiming the receipt picks the prize, and its motion is a printer, which the game
already has. The receipt screen is decoration: the prize is a pure roll at the odds card's odds. If you want prizes
to depend on your basket, that would be a new rule to decide, not part of this look.
