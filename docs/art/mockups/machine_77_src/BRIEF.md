# #77 prep brief: the receipt reward machine, item upgrades and loyalty

This is the shared brief for the prep round on issue #77 (in-run progression). Nothing here is built in the game. It is written for the user to review when they return, and for the agents that make the four prep pieces (section 4). Written 2026-10-20 from the live code on `feature/count-up-planning-look` (the uncommitted #86 build touches presentation only; `core/` and `data/` other than `count_up.tres` are as on HEAD), `docs/FULL_BUILD_PLAN.md` v0.36, the issue, and the user's decisions given before leaving.

**User decisions (2026-10-20), binding for this prep:**
- The machine's categories are **prize types**, not aisles or families.
- **ITEM UPGRADES** opens only after shifts 3, 5 and 7.
- **Register upgrades move into the machine.** The cap stays at 3 per run. Rare and legendary prizes are allowed, but for balance "either a run is doable without power or a guaranteed power needs to drop". Both options must be tested with numbers.
- **Item upgrades have two tiers on one copy:** plain → BIG (more points) → GOLDEN (stronger effect).
- **Prep wanted:** the machine flow (live), rarity reveals (live), how upgrades look, and a loyalty + balance sketch.

**Round 2 update (2026-10-20, after the user played round 1).** Where this brief and the round-2 points below disagree, round 2 wins. The full list is in `DECIDE_77.md` ("Decided 2026-10-20").
- **Decided:** option B (STAMP DAY floor, today's quotas); a guarantee may lift a drop's tier and the odds card always shows the true odds (rule 2.1 is reworded below); Regular meters as a punch ticket; BIG drawn per item with GOLDEN an automatic recolour; tempo 1x.
- **NEW ITEMS and UPGRADES are split cleanly** (the user was confused by the round-1 overlap):
  - **NEW ITEMS · "ADD TO CART"** gives one more item. It always arrives **plain**. Its rarity is the product's own (basic products Common, stronger products Rare, Milk and Eggs among them, the strongest Legendary), from a per-product table in balance data (`product_rarity.json`, a placeholder until the build measures it).
  - **UPGRADES · "IMPROVE ONE YOU OWN"** is the only source of BIG and GOLDEN. Still padlocked except after shifts 3, 5 and 7.
  - **Golden twin is removed** (it added a copy, which is NEW ITEMS' job). The tiers are now: Common = one step on one chosen copy; Rare = two steps on one plain copy (straight to GOLDEN); Legendary = **SHELF UPGRADE**, every copy of one item goes one step up (owned copies only, no new copy). An item that can't take the steps is not offered (SHELF UPGRADE needs 2 copies that can step); an empty tier steps down, then up.
  - **The landings show the difference:** NEW ITEMS flies a new plain item into the cart and the cart count goes +1 ("NEW IN CART"). UPGRADES highlights the copy you already own in the cart and changes it in place; the count stays the same ("UPGRADED").
- **Machine look:** the user liked look A but found the drum too random. Round 2 adds three looks close to A with nothing that spins: D coupon printer, E click & collect lockers, F restock hatch (`flow/looks/`).
- **Art:** Banana and Eggs redrawn (plain and BIG), GOLDEN regenerated (`upgrades/redraw_r2.py`, `upgrades/png/items_v2/`).
- **Balance:** the clean split under option B wins 22% ± 5 (BALANCE.md, "Round 2: clean split"), below the 35–40% band.

**Round 3 update (2026-10-20, after the user reviewed round 2).** Where this brief and the round-3 points below disagree, round 3 wins. Questions Q7 to Q9 are in `DECIDE_77.md`.
- **Decided:** machine look **F, restock hatch** ("I like restock hatch F"); the Banana and Eggs redraw is approved ("a lot better").
- **Proposed (Q7, not decided): the inspection bonus ticket.** Inspections land on shifts 3, 5 and 7 (`inspection_shifts`), the same shifts that open UPGRADES. Passing an inspected shift gives a **second full machine visit** after the first pick lands:
  - The first receipt is stamped "INSPECTION PASSED ✓" with the inspection's name; a BONUS TICKET stub with the same stamp prints and feeds in.
  - Choose any chute again (UPGRADES included), 3 prizes, pick 1 (Q9 asks whether to restrict the chute). NEW ITEMS and COUPONS keep the "bin it" skip.
  - The second visit starts from the state after the first: the Regular hole just punched counts, the cart holds the first prize, a register just won no longer drops. The chute's Regular meter counts the bonus visit like any visit, so shift 7's first ticket now punches its meter.
  - REGISTER's 3-stamp cap and STAMP DAY (after 2/4/6) are unchanged. A pick into a full 15-card cart uses the existing deck-full chooser.
  - In look F the second visit takes about 13.2 s at 1x (packing 1.2 s, reveal gaps 0.15 s); the first stays 18.9 s.
- **Balance (BALANCE.md, "Round 3: inspection bonus ticket"):** the bonus ticket takes the split from 22.2% to 32.1% ± 5.7; with Carrier bag and Tea bags moved to Rare it reaches 35.6% ± 5.7, inside the 35–40% band (Q8 picks the extra lever). It cannot lift shift 3 (68–69% pass), because the first bonus comes after it; only a further bonus after shift 1 lifts it (75%, 38.4% win). GOLDEN Milk rises to about 1.9 copies per run, so its nerf is more pressing.

**User note, same message:** "when currently playing, animation is a bit too fast imo." That is about the game's current count-up (#86), not this issue, and is left to the #86 workflow. For this prep it means: every live page runs at a calm pace by default and has a speed control (0.75x / 1x / 1.25x), so the user can tell us the right tempo.

---

## 1. How rewards work today (exact)

Sources: `core/run_state.gd`, `core/reward_offer.gd`, `core/upgrade_offer.gd`, `core/shift_limits.gd`, `core/coin_payout.gd`, `data/balance/balance.tres`, plan sections 5.2, 7.1, 7.2 and 8.

**Run shape.** 8 shifts. Quotas `34, 35, 53, 61, 73, 98, 111, 120` (SPEND). Hand 8, **2 redraws** per shift (`base_redraws = 2` since v0.34), row = 6 product slots + 1 coupon-only slot, cart (deck) limit **15**. The starter deck has 13 cards: Banana ×3, Bread ×2, Milk ×2, Eggs ×2, Coffee ×2, Soup, Final markdown.

**Stock (fresh profile).** 6 staples (Banana, Bread, Milk, Eggs, Coffee, Soup) + the 3 base aisles (Cold cases 5, Pantry 5, Household 4) = **20 products**, + all **8 coupons** of `coupon_pool` (Repeat, Final markdown, Breakfast sticker, Multipack, 2 for 1, Shelf swap, Clearance tag, Opening deal). Capsule unlocks widen the list between runs, never inside one.

**Run order, each step a `RunState.Phase`:**
1. **IMPULSE, before shift 1:** the impulse rack shows `impulse_rack_size` = 3 stocked products (the newest new arrival takes one slot). Pick one or skip. It uses its own derived RNG stream. The user dislikes it, so it is on hold for #77.
2. **PLANNING → checkout.** A failed shift → LOST. Passing shift 8 → WON (no offer after shift 8).
3. **REWARD, after each passed shift 1–7 (7 offers per won run):** the reward print-out lifts 3 cards (`offer_size`) out of the printer, uniform from the stock, never the same card twice.
   - The first offer always includes one combination coupon from `first_offer_pool` (Breakfast sticker, Multipack, 2 for 1).
   - Every later offer has at least 1 coupon and at least 1 `generally_useful` card (Banana, Bread, Eggs, Milk, Carrier bag, Reduced yogurt, Flickering bulb).
   - Products show a cosmetic PROMO tag.
   - Pick one or **skip**. At 15 cards a pick must replace a cart card (the deck-full chooser).
4. **UPGRADE, after shifts 2, 4 and 6 (`upgrade_shifts`), after the reward:** the "EXIT KIOSK: pick your prize" panel drops up to 3 register upgrades (`upgrade_offer_size`).
   - They come from `upgrade_pool`, never one the run owns, and each is of a different type.
   - At least one fits the cart (`UpgradeDefinition.fits` on its builds), when any unowned one does.
   - **No skip.** So a run that passes shift 6 always owns exactly 3. Each pick stamps the next box on the top bar's **LOYALTY** card (3 boxes).
5. **Inspections, on shifts 3, 5 and 7:** drawn at the previous passed checkout and printed in red on the receipt before the reward. The three are Spot check, Short belt and Coupon slot closed, never the same twice in a row.
6. **Coins, only at run end** (`CoinPayout`): table `0,0,0,0,1,1,1,1,2` by shifts passed, + 1 overtime coin per €923 of summed margin (at most 1). Coins feed the capsule machines (#63/#64), which are out-of-run and must not overlap with this machine.

**The register upgrade pool (6; Rule bender left in v0.27):**

| Upgrade | Type | Effect (data) | Supports |
|---|---|---|---|
| Extra redraw | Economy | `extra_redraws = 1` | any |
| Extra coupon slot | Economy | `extra_coupon_slots = 1` | Coupon specialist |
| Big basket | Risky | `extra_slots = 1`, `quota_percent = 15` | Clearance collector, Bulk buyer |
| Coupon engine | Coupon engine | `FirstCouponRule factor 2` | Coupon specialist |
| Category engine | Category engine | `+3` per distinct tag, on the last product | Mixed basket |
| Slot engine | Slot engine | last regular product slot ×2 | Breakfast special |

**Known balance (plan 8, memory):**
- `greedy@sensible` wins **60.5%** on the live data. The user accepted this "for now" on 2026-10-18; it was 36.7% before the second redraw.
- At v0.27, skipping every reward (upgrades still picked) won 9.6%, against 36.7% for greedy.
- The 40% main-build bar warns: Coupon specialist is 48.8%.
- Big basket is almost never picked. Category engine runs won 61% at v0.26.
- **Nobody has measured a run with no register upgrades.**

---

## 2. Proposal (under the user's decisions)

### 2.1 The machine and its flow

**Name and prop.** The "RECEIPT REWARDS" machine: a promo machine at the store exit with a receipt slot, a row of chute buttons, a drum window and a prize tray. It **replaces the reward print-out and the exit kiosk** (#66 goes, and #56's kiosk question closes). It must look nothing like the capsule machines: no coin slot, no glass globe. It reads as a supermarket loyalty terminal crossed with a ticket dispenser.

**One visit after each passed shift 1–7 (7 visits per won run):**
1. **Feed.** The receipt tears off the printer and slides into the slot. Since #83 the register is on the left and the machine on the right. If the next shift is inspected, its red notice is printed on the receipt as today, so the player reads it before choosing.
2. **Choose a chute.** Four buttons: **NEW ITEMS · COUPONS · REGISTER · UPGRADES**.
   - UPGRADES is padlocked with "OPENS AFTER SHIFT 3", and is lit only after shifts 3, 5 and 7. That gives 3 choices on 4 visits and 4 on 3 visits (recommended; Q1 has the alternatives).
   - REGISTER is padlocked "CARD FULL" once the LOYALTY card holds 3 stamps.
   - Hovering a chute opens its **odds card**: the prize list grouped by rarity with the real percentages, and the guarantee lines ("at least 1 generally useful"). The player must confirm.
3. **Draw.** The drum spins and lights chase. Calm pace: about 1.6 s at 1x, 0.3 s under reduced motion. Then **3 prizes** drop into the tray, each rolled independently against the shown odds.
4. **Reveal.** Each prize opens with its rarity's animation (2.3), the rarest one last.
5. **Pick 1**, or **bin it** (skip). Skip stays allowed for NEW ITEMS and COUPONS, as today; REGISTER and UPGRADES must pick, as the kiosk does today. The prize lands at its home (round 2):
   - **NEW ITEMS:** the cart drawer opens, a new plain item flies into an empty slot, "NEW IN CART", the cart count goes +1.
   - **COUPONS:** the coupon joins the cart, count +1.
   - **REGISTER:** a stamp on the LOYALTY card.
   - **UPGRADES:** an up-arrow flies to the copy you own (to every copy for a SHELF UPGRADE); each glints and changes in place, "UPGRADED", the count stays the same.
6. The chute's **Regular** meter fills by one (2.4).
7. **Bonus ticket (round 3, proposed, Q7).** If the shift just passed had an inspection (shifts 3, 5 and 7), the receipt was stamped "INSPECTION PASSED ✓"; after the pick lands, a BONUS TICKET stub prints and feeds in, and steps 2–6 run once more from the state the first visit left (meter, cart, owned registers). Same chutes, same rules, same 3-stamp cap; STAMP DAY is unaffected.

**Guarantees kept from today:**
- NEW ITEMS: at least 1 `generally_useful` product among the 3.
- COUPONS: the run's first COUPONS visit includes one `first_offer_pool` coupon.
- REGISTER: the 3 are of different types, and one fits the cart when any unowned one does.
- ~~A guarantee changes only *which* prize is drawn inside a rolled tier, never the tier.~~ **Round 2 (decided):** a guarantee may lift a drop's rolled tier (Regular 3's "1 of 3 at least RARE", REGISTER's "3 different types"). The odds card always shows the true odds of the whole draw, guarantees included, which the issue's test requires.

**Register cap.** The LOYALTY card keeps its 3 boxes and stays the only home of register upgrades (the name stays, see 2.4).
- `RunState` refuses a REGISTER pick at 3 owned, and the chute shows CARD FULL with the 3 stamps drawn on it.
- Owned upgrades never drop.
- If a rolled tier has no unowned upgrade left, that drop steps down a tier (then up if none). The odds card says so in one line.

### 2.2 Prize pools and rarity

**Base odds per drop, at Regular level 0: Common 75% · Rare 22% · Legendary 3%.** These shift with the Regular level (2.4).

| Chute (subtitle) | Common | Rare | Legendary |
|---|---|---|---|
| **NEW ITEMS** ("ADD TO CART") | a basic product, plain | a stronger product (Milk, Eggs among them), plain | one of the strongest products, plain |
| **COUPONS** ("ADD TO CART") | Final markdown, Breakfast sticker, Clearance tag, Shelf swap | Repeat, 2 for 1, Multipack | Opening deal |
| **REGISTER** ("STAMP YOUR CARD") | Extra redraw, Extra coupon slot, Big basket | Coupon engine, Category engine | Slot engine |
| **UPGRADES** ("IMPROVE ONE YOU OWN") | one step on one chosen copy (plain → BIG, or BIG → GOLDEN) | two steps on one plain copy (plain → GOLDEN) | **SHELF UPGRADE**: every copy of one item goes one step up (owned copies only, no new copy) |

Round 1's NEW ITEMS row (Rare = arrives BIG, Legendary = arrives GOLDEN) and UPGRADES' Legendary "Golden twin" are **removed** (round 2).

**Why these tiers:**
- **NEW ITEMS rarity comes from the product itself** (round 2). A per-product table in balance data (`product_rarity.json`; in the game a `rarity` field or a table resource) puts basic products at Common, stronger products (Milk and Eggs among them) at Rare and the strongest at Legendary. Fresh stock: 12 Common, 6 Rare, 2 Legendary (Tea bags, Carrier bag). The table is a placeholder until the build measures it. NEW ITEMS never gives BIG or GOLDEN: that is UPGRADES' job, so each chute does one thing.
- **UPGRADES** offers only items with a copy that can take the steps (a GOLDEN copy is done). Rare needs a plain copy. SHELF UPGRADE raises every copy that is not GOLDEN yet, and is offered only for an item with at least 2 such copies (on one copy it would be the Common step); a cart with none steps the Legendary roll down a tier. The odds card's tier % are over the prizes that actually drop, so they add up to 100% on short draws.
- The coupon tiers follow measured strength: the v0.27 coupon-slot duel had Opening deal on top (45%), Repeat 39%, Multipack 33.5%, and the bottom four never best. This also makes the weak coupons the common ones.
- The register tiers follow known strength: Slot engine took a best row from 70 to 126 via Repeat, Category engine runs won 61%, Big basket was almost never picked.
- **Risk:** Slot engine is Breakfast special's upgrade, and making it legendary can cost that build its viability. The simulator's viability check (`build:breakfast_special@sensible` ≥ ⅔ of greedy) decides that; the fallback is to move Slot engine to Rare.

**What the player sees per visit (3 drops, before chute rules such as REGISTER's 3 different types):**

| Regular level | Common / Rare / Legendary per drop | P(≥1 rare or better) | P(≥1 legendary) |
|---|---|---|---|
| 0 | 75 / 22 / 3 | 57.8% | 8.7% |
| 1 | 65 / 28 / 7 | 72.5% | 19.6% |
| 2 | 55 / 33 / 12 | 83.4% | 31.9% |
| 3 (max) | drop 1: 0 / 67.3 / 32.7 (37:18 renormalised); drops 2–3: 45 / 37 / 18 | 100% | 54.8% |

At Regular 3 the guarantee "1 of 3 at least RARE" works by drop 1 rolling only RARE or LEGENDARY (37:18). This is the one rule every page uses (`flow/draw77.js`; the loyalty page's odds card runs the same code). These are a starting point. They live in balance data (a `MachineOdds` resource per level) and are tuned with the simulator.

### 2.3 Rarity reveal: never colour alone

| Rarity | Shape | Light (palette) | Sound (#62 family, CC0 via `make_sfx.py`) | Label | Time at 1x |
|---|---|---|---|---|---|
| Common | plain square ticket, no burst | cream / paper `#fbf7ee` | one xylophone note + paper tick | none, or "COMMON" | 0.4 s |
| Rare | ticket with a stepped starburst behind (`sticker_burst`) | teal `#4f9a94` / `#86c2b6` | two rising notes | "RARE!" price-gun label | 0.9 s |
| Legendary | rotating sunburst (`ui/sunburst.gd`), sparkles (`sparkle.png`), a 2 px hop | gold `#ffcf3f` / mustard `#e2b33c` | the pentatonic ladder up 4 notes + register rattle | "LEGENDARY!!" rubber stamp | 1.6 s |

Under reduced motion each reveal keeps its shape, label and sound, and drops the motion. The capsule machine's sounds stay distinct.

### 2.4 Loyalty per prize type: "Regular" meters

- **Naming:** each chute has a **Regular** meter of 3 punch holes ("REGULAR ●●○"): being a regular at that counter. The word "loyalty" stays reserved for the top bar's LOYALTY card (register stamps), so the two never share a name.
- **Rises by 1 each time that chute is chosen (max 3). Resets every run**; the capsule machine may later grant "start at Regular 1 in COUPONS" (a meta bonus, not in this issue).
- **Per level:** the odds in 2.2, plus one unlock.
  - At level 2: NEW ITEMS shows its odds card with the cart's matching items highlighted. That is cosmetic, so it could be cut.
  - At level 3: **one of the 3 drops is guaranteed Rare or better**, shown on the odds card as "1 of 3 at least RARE".
- **Reachable levels per run:**
  - NEW ITEMS and COUPONS: 7 visits, so level 3 is reachable.
  - REGISTER: at most 3 picks, so level 2 at the last pick.
  - UPGRADES: 3 visits, so level 2 on the last.
  - Leaning into one chute is a real strategy, which is the issue's goal.

### 2.5 Item upgrades: two tiers on one copy

**Data model.** Each tier is a **variant `CardDefinition`** (`variant_of` = the plain card, which plan 7.3 already supports): for example `banana_big.tres` and `banana_golden.tres`.
- An upgrade swaps that one `CardInstance.definition` to the next tier. The other copies are untouched, which the issue's test requires. The only exception is UPGRADES' Legendary SHELF UPGRADE, which swaps every owned copy of one item one step up (round 2); it never adds a copy.
- "A variant counts as its base card everywhere" already holds (2 for 1, Banana pair, rules that name a card), so a Big Banana still pairs with a plain Banana.
- Every number stays an `@export` on the variant's rule resources, and `score()` doesn't change.
- A product-to-tiers table (`data/item_upgrades/`) lists which products have tiers.
- **Coupons get no tiers in v1** (Q6).

**BIG = more points (base up). GOLDEN = stronger effect (it keeps BIG's base and raises one rule field):**

| Item (sprite) | Plain (live data) | BIG | GOLDEN |
|---|---|---|---|
| **Banana** (`items_v2/banana.png`) | base 2; `AdjacentMatchBonusRule` SAME_CARD, IMMEDIATELY_AFTER, `bonus_is_base` (+2 after a Banana) | base **4** (so the pair bonus is +4) | base 4, `position` **BESIDE**: pays beside a Banana on either side |
| **Milk** (`milk.png`) | base 4; `CountEarlierTagBonusRule` Breakfast, `bonus_each 1` | base **6** | base 6, `bonus_each` **2** |
| **Eggs** (`eggs.png`) | base 1; `GrantChargedMultiplierRule` Food, `factor 2`, `charges 1` | base **3** | base 3, `charges` **2** (doubles the next 2 Food payouts) |
| **Coffee** (`coffee.png`) | base 2; `GrantNextTagBonusRule` Breakfast, `bonus 3` | base **4** | base 4, `bonus` **6** |

Values are placeholders for the simulator. The rule of thumb is that BIG is worth about +2 to +3 a row, and GOLDEN roughly doubles the item's effect.
- Eggs is already the largest single point of failure (90% / 68%), so GOLDEN Eggs is the one to watch.
- An item can be upgraded twice at most (plain → BIG → GOLDEN). GOLDEN is the end.

**Looks:**
- **BIG** is a bigger pack of the same item drawn on the same 48x48 grid (a bunch of 5 bananas, a 2 l carton, an 8-egg carton (2 rows of 4, wider but no taller than the plain 6: weak at 1x, see DECIDE), a large tin), with a cream "BIG" price-gun label on its ticket.
- **GOLDEN** is the BIG sprite remapped to the brass/gold ramp (`k l L n y Y`) with the ink outline kept, a 2-frame sparkle, and a gold-rimmed ticket. Round 2: items that are already yellow (Banana) use a darker map: the body goes brass (`L`), the lit side gold (`n`), the shade brass dark (`l`), with a 1 px paper rim on the lit top edge, so the bunch is clearly darker and more metallic than plain yellow. GOLDEN Eggs keep each egg in the gold ramp with a brass-dark rim against the grey carton and a 1–2 px paper highlight inside its upper left (no paper on the egg's edge). All sprites stand on row 47, like the game's items. Banana and Eggs were redrawn (plain and BIG) in `upgrades/redraw_r2.py`; the game's `art/src` sources stay untouched until the build.
- The golden remap can be automatic in `tools/pixel_art.py` (a palette map per source), so only BIG needs drawing: 4 sprites now, one per upgradable product later.

### 2.6 Balance: the two options and how to measure them

**Option A, "doable without power":**
- Refit the quota curve so a run with **no register upgrade** meets the #41 targets: shift 1 ≥ 97%, shift 2 ≥ 95%, equal hazard from shift 3, a 35–40% win.
- Register prizes are then pure extra power. The machine needs no pity.
- **Cost:** a 3-register run gets much easier under that curve, so we measure how much.

**Option B, "a guaranteed power drops" (recommended):**
- Keep today's curve and the 2/4/6 schedule as a **floor**. After shifts 2, 4 and 6, if the run owns fewer than 1, 2 or 3 registers, a free **STAMP DAY** ticket drops after the chosen prize: 3 register prizes at the player's REGISTER odds, pick 1 (today's kiosk rule, in the machine's look).
- Choosing REGISTER yourself gets the power earlier (after shift 1, 3 or 5) at Regular-boosted odds, but costs that visit's item or coupon.
- The curve already fits this, because the simulator models exactly 3 registers by shift 6, so it needs no refit.
- **Variant B-pity:** a single guarantee (at least 1 register by shift 4) and the rest optional. This sits between A and B.

**Measure with the existing tools (no code change):** use `--balance=<copy>`, which swaps only `upgrade_shifts`.

| Run | `upgrade_shifts` | What it stands for |
|---|---|---|
| R0 | `[]` | no register power: Option A's floor |
| R1 | `[4]` | B-pity |
| R2 | `[2, 4]` | a player who took 2 |
| R3 | `[2, 4, 6]` (live) | Option B's floor = today (expect about 60.5%) |

- For each: `sh tools/balance_sim.sh --runs=480 --seed=1 --strategy=greedy@sensible,skip@sensible --balance=res://data/balance/<copy>.tres --max-minutes=12 --cpu-percent=40`.
- Read the win rate, the per-shift pass rates and the build viability (add `build:<id>@sensible` for the 5 builds on R0 and R3).
- **Option A's curve:** R0 with `--quotas=0 --records=res://reports/r0.json`, then `python tools/quota_fit.py reports/r0.json` with the default targets. Then rerun R3 with `--quotas=<that curve>` to see what 3 registers do under it.
- **Known bias:** the simulator still gives the normal reward on a register shift, while in the machine a REGISTER pick replaces the item. So R1 to R3 overstate the register player by one reward per register. Modelling the machine itself (category choice, rarity, item upgrades) needs new `SimPlayer` code in the build, not in this prep.
- **Hygiene (memory):** run only in a **renamed scratch copy**, never in `C:/dev/projects/NextCustomer`.
  - Copy with `git -C C:/dev/projects/NextCustomer archive HEAD | tar -x -C <scratchpad>/p77/sim`. HEAD's `core/` and `data/balance/balance.tres` match the working tree.
  - Set `config/name="NextCustomer p77 sim"` so `user://` never touches the real profile.
  - Time-limit every run, and delete the copy afterwards.
  - Until these numbers exist, pages print them as "not measured", never invented.

---

## 3. Open questions for the user (with recommendations)

1. **Chute layout.**
   - **(a, recommended)** 4 buttons, with UPGRADES padlocked except after shifts 3, 5 and 7.
   - (b) 3 buttons: GROCERIES (products + coupons mixed, like today's offer) · REGISTER · UPGRADES (padlocked off-shift).
   - (c) 3 buttons, with UPGRADES taking REGISTER's place after shifts 3, 5 and 7.
   - Why (a): it keeps COUPONS as its own Regular track for the coupon builds, and makes the unlock visible.
2. **Balance option.**
   - **Recommended: B (STAMP DAY floor)** once R0–R3 are measured. It keeps today's curve, the LOYALTY card's 3 boxes and their timing as a guarantee.
   - A needs a refit and likely makes registers too strong.
   - B-pity is the fallback if B makes REGISTER feel pointless.
3. **Rarity source for NEW ITEMS.** **Decided in round 2: a rarity per product, items always plain** (the clean split).
   - ~~Round-1 recommendation: the rarity is the tier the item arrives with (plain / BIG / GOLDEN).~~ Removed: it mixed NEW ITEMS with UPGRADES.
4. **Loyalty.**
   - **Recommended:** "Regular" meters, 3 holes per chute: odds shift per level, and at level 3 one drop is guaranteed Rare or better. Reset every run. The name keeps "LOYALTY" for the register card.
   - Alternative: cut loyalty from the first build, as the issue's scope note allows, and add it after a play test.
5. **Skip and the impulse rack.**
   - **Recommended:** keep a "bin it" skip on NEW ITEMS and COUPONS (the Regular meter still counts), and **cut the impulse rack**. Shift 1 starts straight away and the first machine visit follows it.
   - Alternative: replace the rack with a machine visit before shift 1, NEW ITEMS only.
6. **Upgrade scope and art.**
   - **Recommended:** products only (no coupon tiers in v1). Two steps at most. GOLDEN as an automatic gold remap of the BIG sprite. BIG drawn per item, starting with Banana, Milk, Eggs and Coffee. A product without a BIG drawing can't be upgraded yet (it stays Common-only in NEW ITEMS).
   - Alternative: BIG as a shared overlay ("x2 pack" tag) on the plain sprite, with no redraws.

**Defaults, stated rather than asked:**
- Coins and the capsule machines are unchanged.
- Inspections are unchanged, and still printed on the receipt before the feed.
- The exit kiosk (#66) and #56's kiosk question close into this issue.
- Odds, levels and tiers are balance data; the UI only shows run state.
- Reduced motion shortens the draw and the reveals.
- Plan 5.2 and 7.2 get rewritten, with a changelog row, once decided.

---

## 4. Specs for the four prep pieces

**Common rules:**
- Follow `docs/art/mockups/screens_src/BRIEF.md` sections 0–2 (palette only, 2 px art pixels, stepped hard shadows, fonts from `../../../fonts/`, real data, no hotlinks).
- Write only `docs/art/mockups/machine_77_*.html` and captures `machine_77_*_at<t>.png` / `_1920x1080.png`. Generators, copied assets and notes go in `docs/art/mockups/machine_77_src/`.
- Copy the sprites from `art/items_v2/`, `art/icons/`, `art/frames/` and `art/effects/` into `machine_77_src/assets/` and reference them by relative path. Data URIs are fine for one self-contained page.
- **Stage:** 1280x720 CSS, captured at 1.5x (1920x1080) with `sh docs/art/mockups/count_up_86_v5_src/cap.sh <page> <out.png> "<query>" [height]`, a unique `TMPDIR` under `<scratchpad>/p77/<name>` per capture, up to 3 retries.
- Every live page takes `?at=<s>` (freeze at time s), `?rm=1` (reduced motion) and `?speed=0.75|1|1.25`.
- On-page controls: replay, speed, a reduced-motion toggle, mute (sound starts muted until a click; WebAudio placeholders for the #62 sounds).
- **Base scene:** the mirrored B2 shift screen at checkout end (from `planning_effects_h1.html`), shaded with `ScreenShade`-like 60% teal-darkest. The register, printer and receipt stay lit on the left; the machine stands on the right.

### 4.1 `machine_77_flow.html`: the machine flow (live)

- **Machine:** x 760–1180, y 70–700 (420x630).
  - Receipt slot at y 120.
  - Chute buttons row at y 250: 4 buttons, 92x64 each, labels in Pixelify 12 px. UPGRADES shows a padlock or is lit; REGISTER shows CARD FULL when 3 stamps are held.
  - Regular holes under each button (3 per chute).
  - Drum window 240x150 at y 340.
  - Prize tray at y 540: 3 tickets, 120x150 each, ItemView-style (48x48 sprite at 2x over the price sticker).
- **Timeline at 1x, about 9 s:**
  - 0.0 receipt tears off the printer
  - 0.8 it flies into the slot
  - 1.6 buttons light up
  - 2.2 hover on COUPONS opens the odds card (300x240, left of the machine: prize icons per tier, percentages, the guarantee line)
  - 4.0 confirm
  - 4.2 drum spin (1.6 s)
  - 5.8 3 drops
  - 6.2 reveals (common, rare, legendary demo order)
  - 8.2 pick
  - 8.6 the prize flies to the cart button, and the COUPONS Regular hole punches
- **Controls:**
  - a shift selector 1–7 (UPGRADES lit only on 3, 5 and 7)
  - a chute selector
  - owned-registers 0–3 (CARD FULL at 3)
  - a STAMP DAY toggle (Option B's free ticket after shifts 2, 4 and 6)
- **Data:**
  - COUPONS: real coupon names, with the `coupon_slip` + `coupon_multipack_v2` / `coupon_two_for_one_v2` icons and the slip with a printed name for the rest.
  - NEW ITEMS: Banana, Milk, Cheese, Tea bags.
  - REGISTER: the 6 real upgrades with their `effect_text`.
- **Captures:** `at=0.8, 2.6, 4.8, 6.6, 8.6`, plus `rm=1` at 6.6.

### 4.2 `machine_77_reveals.html`: rarity reveals (live)

- 3 stations side by side, 400x560 each (gutters 20). Each is a tray ticket that reveals Common, Rare or Legendary on a 3 s loop, plus a "play all" in sequence.
- Shapes, lights, labels, sounds and timings exactly as in table 2.3.
- A **greyscale toggle** (CSS `filter: grayscale(1)`) proves the non-colour signals: the shape, the label and the motion still differ.
- Legendary uses a stepped 12-ray sunburst in gold/mustard bands, `sparkle.png` frames and the "LEGENDARY!!" stamp tilted −8°.
- Rare uses `sticker_burst.png` and a teal price-gun "RARE!".
- Prizes shown: Common Breakfast sticker, Rare UPGRADES Milk › GOLDEN (round 2: NEW ITEMS never arrives BIG), Legendary Slot engine ticket (a register prize, to show a non-item reveal).
- **Captures:** each station at its peak frame, the greyscale frame, and `rm=1`.

### 4.3 `machine_77_upgrades.html`: upgrade looks (still, with a hover glint)

- **Top:** a grid of 4 rows (Banana, Milk, Eggs, Coffee) × 3 columns (plain, BIG, GOLDEN).
  - Each cell shows the item at belt size (96x96, the 48x48 sprite at 2x) on its rail ticket (`ticket_product.png`), with its price sticker (base €), sticker text from 2.5 (golden numbers in gold), and its scan-popup line (the full rule).
  - BIG in the mock-up: the plain sprite redrawn as a bigger pack by hand on the 2 px grid in canvas, or a stacked/offset double as a clearly labelled stand-in. Say in a comment which becomes an `art/src/` source.
  - GOLDEN: a canvas palette remap of the BIG pixels to `k 4a3010 / l 8a5d1a / L c8932b / n ffcf3f / y f1d27a / Y faecbc` by luminance, keeping the ink `2b2420` outline, plus a 2-frame sparkle.
- **Bottom:** a belt strip of the mirrored B2 row holding Banana, Banana (GOLDEN), Banana, Milk (BIG), Eggs, Coffee, to prove "which banana is upgraded?" needs no extra UI.
- **Size:** 1280x720. **Capture:** `machine_77_upgrades_1920x1080.png`.

### 4.4 `machine_77_loyalty.html`: loyalty and balance sketch (interactive)

- **Left half (640x720):** the machine's button row at 2x with its Regular holes.
  - Clicking a chute "picks" it: the hole punches (a stamp sound) and the odds card animates from the old to the new percentages (table 2.2), including P(≥1 rare+) and P(≥1 legendary) and the level-3 guarantee line.
  - A "new run" button resets every meter.
  - Beside it, the LOYALTY card (`loyalty_card.png`, `stamp_ring.png`) shows the 3 register stamps, to show the two names side by side.
- **Right half:** the balance sketch.
  - A small chart of the win rate for R0, R1, R2 and R3 (`greedy@sensible`, and `skip@sensible` as a second series), from `machine_77_src/balance.json`.
  - Option A's fitted curve against the live curve (8 bars per shift).
  - One verdict line per option.
  - Until `balance.json` holds the measured numbers, every value prints "not measured" in grey; the only known value is R3 at about 60.5% (live, v0.34).
  - Load the `dataviz` skill before drawing the chart.
- **Captures:** the default state, and one after 3 picks of COUPONS.

---

Brief path: `C:/dev/projects/NextCustomer/docs/art/mockups/machine_77_src/BRIEF.md`
