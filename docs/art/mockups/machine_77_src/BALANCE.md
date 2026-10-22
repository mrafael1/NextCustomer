# #77 balance sketch: register power in the RECEIPT REWARDS machine

Measured 2026-10-20 with the game's balance simulator (greedy drafting with sensible rows, `greedy@sensible`; fresh profile; live data at HEAD 1ed5d2e). The runs used throwaway git worktrees outside the repo, with a scratch change to `tools/balance_sim/sim_player.gd` that models the machine. That change is not in the game; the patch is in `balance/p77_sim_player.patch`. Nothing in the game, data or tests was changed. The page `../machine_77_loyalty.html` shows these numbers (`balance.json`); the raw analysis is in `balance/analyzed.json` (first pass) and `balance/analyzed_fix.json` (fix pass, records kept in `balance/records_fix/`).

**\* marks an optimistic row:** the simulated player compares the rolled prizes (REGISTER drops or UPGRADES drops) with the reward before choosing a chute. A real player confirms a chute after seeing only its odds, so these rows are upper bounds.

## Answer first

- **Register upgrades are most of a run's power.** A run with no register upgrade wins **1%** on today's quotas. Its totals hardly grow: the median shift-8 total is €80 with no registers, against €274 today. Today's **61%** depends on Category engine and Slot engine, which 97–98% of runs take.
- **Option A ("a run is doable without power") does not work with today's registers.** To bring a no-register run to the 35–40% band, quotas from shift 3 on have to roughly halve (shift 8: €120 → €63). Under that curve, any run that gets 3 registers wins **80–96%**, and a run that skips every reward but takes the registers wins **94%**. The build would also stop "growing" over a run, which is #77's goal.
- **Option B ("a guaranteed power drops": the STAMP DAY floor after shifts 2, 4, 6) works with today's quotas, so it is the recommendation.**
  - With the brief's rarity tiers, a player who never chooses REGISTER and only takes the free stamps wins **32%** (206 runs; a fix-pass rerun of the same scenario gave 30%, 148 runs).
  - A player who chooses REGISTER blindly on 30% of visits wins **33%**.
  - With item upgrades taken **blind** (UPGRADES chosen whenever it is open, before seeing the drops), the never-REGISTER player wins **35% ± 10** (85 runs). The earlier **40%\*** for that case came from a player who saw the UPGRADES drops before choosing, with a NEW ITEMS meter that was also raised by coupon picks, so it is an upper bound, not "back in the band".
  - Honest range for option B: **about 30–40%** for a player who never chooses REGISTER, depending on how well UPGRADES is used, against today's 61%. A player who also chooses REGISTER after seeing the 3 prizes wins 53%\* (57%\* with upgrades); a real player sees only the odds, so expect roughly 33–53% overall.
- **The rarity tiers are the main balance lever.** Today's kiosk offers 3 of the 6 registers uniformly, with one that fits the cart and 3 different types, so nearly every run gets both engines. The machine's draw (Coupon/Category engine Rare, Slot engine Legendary, timing unchanged: 2/4/6, free) takes the win rate from **61% to 32%**. That gap is the tiers **plus** the loss of the "fits" and "different types" guarantees. The fix pass separated the fits part: adding "one fits your cart" inside the rolled tier gave **24% ± 8** (109 runs), no better than without it, so the tiers carry the drop. "3 different types" is still not modelled.
- **Item upgrades add about +3 to +8 points.** Blind: 30–32% → 35% under option B. Seeing the drops first\*: 61% → 69% today and 32% → 40% under B. **GOLDEN Milk** ends up in **1.0–1.5 copies per run** (1.46 with blind UPGRADES, where every open visit is taken). It is the one to nerf, ahead of GOLDEN Coffee and GOLDEN Eggs (0.4 each, blind).

## Results

All numbers come from greedy@sensible (the Breakfast row uses `build:breakfast_special@sensible`). Every run was played with all quotas at 0 (`--quotas=0 --records`) and then replayed under a curve (the replay of `tools/quota_fit.py`, which includes Big basket's raise). Each scenario therefore sees the same runs under both curves. "±" is the 95% interval.

Live curve: `34, 35, 53, 61, 73, 98, 111, 120`. Option A's curve, fitted with `quota_fit.py`'s default targets to the 627 R0 runs (no register power): `37, 38, 40, 46, 47, 53, 54, 63`.

| Scenario | What the machine does | Runs | Win, live curve | Win, option A curve |
|---|---|---|---|---|
| **today** | kiosk after 2/4/6, free, on top of the 7 rewards (live game) | 314 | **60.8%** ± 5.4 | 90.8% |
| **R0** | no register upgrade at all | 627 | **0.8%** ± 0.7 | 36.5% (fit target) |
| R1 | 1 free register after shift 4 | 283 | 9.5% | 62.5% |
| R2 | 2 free registers after shifts 2 and 4 | 242 | 51.7% | 88.8% |
| A-blind | REGISTER chosen on 30% of visits (blind), costs that visit's item, rarity tiers, no floor | 279 | **14.3%** ± 4.1 | 62.4% |
| A-greedy\* | REGISTER chosen when its best prize beats the best item, costs the item, rarity tiers, no floor | 283 | 51.6% | 93.6% |
| **B-stamp** | STAMP DAY only: free register pick after 2/4/6 at rarity odds; never chooses REGISTER | 206 | **31.6%** ± 6.3 | 80.1% |
| B-stamp, rerun (fix pass) | same scenario and seeds, rerun to keep the records | 148 | 30.4% ± 7.4 | 77.0% |
| B-stamp + fits (fix pass) | as B-stamp, plus "one fits your cart": when no drop fits, one drop is swapped for a fitting register of the same tier | 109 | 23.9% ± 8.0 | 77.1% |
| B-blind | STAMP DAY + REGISTER on 30% of visits (blind, costs the item) | 266 | **33.1%** ± 5.7 | 82.7% |
| B-greedy\* | STAMP DAY + REGISTER when best | 345 | 53.0% | 94.5% |
| B-pity\* | floor of 1 register by shift 4 + REGISTER when best | 182 | 45.6% | 91.8% |
| today + items\* | today, plus UPGRADES after 3/5/7 (chosen after seeing its drops) and NEW ITEMS arriving BIG/GOLDEN (meter shared with coupons) | 103 | 68.9% ± 8.9 | 91.3% |
| **B-stamp + items, blind** (fix pass) | B-stamp, UPGRADES taken whenever open (before seeing the drops); NEW ITEMS meter rises only on product picks | 85 | **35.3%** ± 10.2 | 83.5% |
| B-stamp + items\* | B-stamp, UPGRADES chosen after seeing its drops; NEW ITEMS meter shared with coupons | 122 | 40.2% ± 8.7 | 86.1% |
| B-greedy\* + items\* | B-greedy, plus item upgrades as above | 237 | 56.5% | 95.8% |
| B-stamp, Breakfast build (fix pass) | B-stamp with `build:breakfast_special@sensible` (the #42 viability check) | 150 | 18.7% ± 6.2 | 76.7% |
| today, skip\@sensible | live game, skipping every reward | 600 | 23.5% | 93.7% |
| R0, skip\@sensible | no registers, skipping every reward | 600 | 0.0% | 0.0% |

**NEW ITEMS rarity in the \* item rows is overstated.** The first pass merged NEW ITEMS and COUPONS into the one reward offer and raised the NEW ITEMS level on every item or coupon visit, so it reached level 3 by the 4th such visit. The fix pass raises it only when the player takes a product.

**Per-shift pass rates (live curve), shifts 1–8:**

| Scenario | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| today | 99.7 | 99.0 | 94.5 | 92.5 | 92.3 | 87.6 | 92.2 | 94.6 |
| R0 | 99.2 | 99.0 | 52.1 | 62.9 | 50.0 | 38.6 | 33.3 | 38.5 |
| B-stamp | 98.5 | 98.5 | 77.0 | 81.8 | 81.0 | 77.5 | 89.9 | 91.5 |
| B-stamp, rerun | 98.6 | 98.6 | 79.2 | 80.7 | 81.5 | 74.7 | 89.3 | 90.0 |
| B-stamp + items, blind | 98.8 | 98.8 | 79.5 | 78.8 | 88.5 | 80.4 | 89.2 | 90.9 |
| B-stamp + items\* | 99.2 | 98.3 | 79.8 | 86.3 | 85.4 | 82.9 | 87.9 | 96.1 |

Under option B, shift 3 is the wall (77–80%): only one register is owned by then, and it is usually a Common one. That is the shift to watch if B is chosen. The fixes are a lower shift-3 quota, a STAMP DAY after shift 1 instead of 2, or Category engine at Common.

**Which registers end up owned (share of runs):**

| Scenario | Category engine | Slot engine | Coupon engine | Extra redraw | Extra coupon slot | Big basket |
|---|---|---|---|---|---|---|
| today | 98% | 97% | 70% | 23% | 12% | 0% |
| B-stamp | 94% | **21%** | 72% | 96% | 17% | 1% |
| B-stamp, rerun | 94% | 21% | 72% | 97% | 16% | 1% |
| B-blind | 95% | 29% | 74% | 90% | 13% | 0% |
| B-greedy\* | 97% | 57% | 64% | 76% | 6% | 0% |

**Engines matter (traceable figures, fix-pass records, live curve):**
- B-stamp rerun: runs with Category engine by shift 6 win 31.7% (139 runs), without 11.1% (9 runs). Runs with Slot engine win 38.7% (31), without 28.2% (117).
- B-stamp + items, blind: with Category engine by shift 6 35.8% (81), without 25% (4). With Slot engine 47.1% (17), without 32.4% (68).
- The first pass also quoted "without Category engine by shift 6: 17% today, 8% B-stamp, 22% B-greedy" and "with/without Slot engine: 62% vs 27% today, 37% vs 30% B-stamp". Those came from an ad-hoc pass over records that were deleted with the first worktree, so they can't be traced. The fix-pass numbers above replace them for B-stamp. The "without Category engine" samples are tiny (4–12 runs): the direction holds (much worse without it), the size does not.

**Builds (live curve, win rate, runs):**
- Today: Coupon specialist 53% (165), Breakfast special 68% (80), Mixed basket 82% (51).
- B-stamp: Coupon specialist 30% (120), Breakfast special 32% (44), Mixed basket 40% (35). These are greedy runs grouped by the build they ended up with, a self-selected subset, **not** the #42 viability check.
- **The #42 viability check under B-stamp** (fix pass): `build:breakfast_special@sensible` wins **18.7% ± 6.2** (150 runs), against greedy's 30.4% (rerun) to 31.6%. Viable needs ⅔ of greedy, 20.3–21.1%. Breakfast special **fails narrowly**, inside the noise. With Slot engine Legendary, only about 21% of B runs own it at all. So "Slot engine Legendary keeps Breakfast special viable" is **not shown**; the brief's fallback (Slot engine to Rare) stays on the table. The other builds were not checked.

**Item upgrades (copies per run in the final cart):**
- B-stamp + items, blind (fix pass): GOLDEN Milk 1.46, GOLDEN Coffee 0.44, GOLDEN Eggs 0.42, BIG Milk 0.27, BIG Eggs 0.14; Banana (BIG or GOLDEN) 0.08. 2.85 upgraded copies per run, because the blind player takes every open UPGRADES visit.
- B-stamp + items\* (first pass): GOLDEN Milk 1.02, BIG Milk 0.34, GOLDEN Eggs 0.29, GOLDEN Coffee 0.19; BIG/GOLDEN Banana and BIG Eggs 0.05 or less.
- Upgrades go nearly always to GOLDEN, because a Rare or Legendary UPGRADES drop gives two tiers.
- Milk's `bonus_each 2` is the strongest change. Banana's BESIDE barely matters, so Banana needs a stronger GOLDEN (for example the pair bonus counting twice) or no GOLDEN at all.

## Method

1. **Worktrees.** First pass: `git worktree add <scratchpad>/wt77 HEAD --detach`, with `config/name` renamed so `user://` never touches the real profile. Fix pass: a fresh worktree `wt77b` (renamed "NC Scratch p77b"), same HEAD, same patch plus three flags. Each simulator run used `--duel-samples=0 --orphan-samples=0 --offer-samples=0` and a time limit (first pass 10 min at 40% CPU; fix pass 22–26 min at 25% CPU, 4 runs in parallel). Both worktrees, their user-data folders and their Godot processes were removed afterwards.
2. **R0/R1/R2** are balance copies with `upgrade_shifts` = `[]`, `[4]` and `[2, 4]`. No code change was needed, so these are today's free kiosk with fewer stamps.
3. **The machine model** (environment variable `P77` read by the scratch `SimPlayer`; see `balance/p77_sim_player.patch`) replaces the reward-plus-kiosk step after each passed shift:
   - **REGISTER visit:** 3 drops, each rolled Common/Rare/Legendary at the brief's odds for the chute's Regular level (75/22/3, 65/28/7, 55/33/12, 45/37/18; at level 3, drop 1 is lifted out of Common). The tiers are Extra redraw/Extra coupon slot/Big basket, Coupon engine/Category engine, and Slot engine. Owned registers never drop, and an empty tier steps down, then up. The player picks the best of the 3 as the simulator's upgrade picker does. **The visit replaces that shift's reward** (the brief's "costs that visit's item").
   - **STAMP DAY:** after shifts 2/4/6, if the run owns fewer than 1/2/3 registers, a free REGISTER draw follows the visit. It does not raise the REGISTER level.
   - **Item upgrades:** after shifts 3/5/7, the player may take an UPGRADES visit instead of the reward. It rolls 3 drops; Common gives one tier, Rare or Legendary gives two (Golden twin is modelled as two tiers). The best copy to upgrade is judged by the simulator's greedy valuation. Products in a reward offer may arrive BIG (Rare) or GOLDEN (Legendary) at the NEW ITEMS Regular level.
   - **Tiers:** runtime variant cards (`variant_of` the plain card) per the brief's table 2.5. BIG is base +2. GOLDEN keeps BIG's base and sets Banana `position BESIDE`, Milk `bonus_each 2`, Eggs `charges 2`, Coffee `bonus 6`.
   - **Fix-pass flags:** `upblind` (UPGRADES is chosen whenever it is open and a copy can be upgraded, before its drops are seen; the copy is then picked from the drops), `itemsfix` (the NEW ITEMS level rises only when the reward taken is a product), `fits` (when no register drop fits the deck, one drop is swapped for a fitting, unowned register of the same tier, if that tier has one).
4. **Curves:** `python tools/quota_fit.py r0_all_records.json` with the #41 default targets gave option A's curve. Every scenario's records were replayed under both curves by `balance/analyze.py` (same rules as `quota_fit.py`; checked against its output: 58.3% on a test file in both). `analyze.py` now also writes the engine breakdowns (`conditional_live`).
5. **Parallel runs.** `tools/balance_sim.sh` clears and reuses one work folder (`reports/balance_sim`, shard files `shard_N.json`) and one search cache per project. Two runs in the same worktree at once delete or overwrite each other's shard files. The fix pass found this when a parallel attempt failed at the merge, threw those results away, and reran with a per-run work folder (`balance/balance_sim_p77.sh`, `P77NAME`) and a per-run `--cache`. The first pass ran its chains partly in parallel in one worktree. A clash there shows up as a failed merge rather than wrong numbers in most cases, and the B-stamp rerun (30.4%, 148 runs) matches the first pass (31.6%, 206 runs) within noise, as does today (60.8% against the known 60.5%). Still, treat the first-pass rows as unverified against this; rerun them with per-run folders when the machine is built.

## Caveats

- **NEW ITEMS and COUPONS are not separate chutes in the model.** Item visits use today's mixed reward offer, so coupon rarity, the COUPONS Regular meter and its level-3 guarantee are not measured.
- **"3 different types" is not in the register draw.** "One fits your cart" was added in the fix pass (B-stamp + fits) and changed nothing measurable.
- **The level-3 lift conflicts with the brief.** Lifting drop 1 out of Common changes a tier, which brief rule 2.1 says a guarantee never does, and "3 different types" can also override a rolled tier (Extra redraw and Extra coupon slot are both Economy). This needs a decision; the model uses the lift.
- **\* rows peek at the prizes**, so A-greedy, B-greedy, B-pity, today + items and B-stamp + items (both first-pass item rows) are upper bounds. The blind rows are crude stand-ins for a player who reads only the odds (REGISTER on 30% of visits; UPGRADES always when open).
- **The impulse rack is still in the runs** (the brief recommends cutting it). Its pick is worth a few points at most, the same in every scenario.
- **Samples are small:** 85–627 runs, ±4 to ±10 points. Differences under about 8 points between single-batch rows are not reliable. The headline gaps (61 vs 32, 1 vs 37) are well outside the noise; the item-upgrade gain (+3 to +8) is not.
- **Every number is the sensible simulated player** (greedy drafting, hill-climbed rows), not a real player; the row calibration tool can compare them once playtest logs of the machine exist.

## Recommendation

1. **Choose option B (STAMP DAY floor after shifts 2, 4, 6)** and keep today's quota curve. It meets the user's rule ("a guaranteed power needs to drop"). With the brief's rarity tiers a never-REGISTER player lands at about 30–32%, or 35% ± 10 with item upgrades taken blind (40%\* if the drops could be seen first), against today's 61%. So #77 would also undo most of the 2-redraw overshoot the user accepted "for now"; it may land a little under the 35–40% band, not inside it.
2. **Don't choose option A unless registers are also weakened.** Its refit halves late quotas, and any run with the engines then wins 80–96%.
3. **Treat the register tiers as balance data.** If B plays too hard (shift 3 at 77–80% is the weak spot), first move Category engine to Common or put STAMP DAY after shift 1. If too easy, move Coupon engine up to Legendary.
4. **Open: Slot engine's tier.** Under B with Slot engine Legendary, Breakfast special narrowly fails the #42 viability check (18.7% against ⅔ × 30–32% = 20–21%, inside the noise). Keep the brief's fallback (Slot engine to Rare) on the table, and rerun the check for every build with more runs before choosing.
5. **Item upgrades:** keep them, but **nerf GOLDEN Milk** (e.g. BIG base +1 instead of +2, or keep `bonus_each` 1 and give GOLDEN Milk a different effect) and give GOLDEN Banana a real effect. Re-measure once the tiers are data.
6. **When building:** put the machine into `SimPlayer` for real, with separate NEW ITEMS/COUPONS chutes, "3 different types", and a blind chute choice from the shown odds (the expected value per chute). Then rerun this table with 480+ runs per row, one run per worktree or per-run work folders, and the `build:<id>@sensible` viability check.

## Files

- `../machine_77_loyalty.html`: the page (Regular meter variants A/B/C, STAMP DAY toggle, level table, odds card, LOYALTY card, balance sketch). Built by `loyalty/build.py` from `loyalty/template.html` and `balance.json`.
- `../machine_77_balance_*.png`: stills (default; 3 COUPONS picks; meter variants B and C; REGISTER CARD FULL; a STAMP DAY stamp; the full page with its caption).
- `balance/`:
  - `p77_sim_player.patch`: the scratch simulator change, fix-pass flags included.
  - First pass: `run.sh`, `run2.sh`, `chain*.sh`.
  - Fix pass: `run3.sh`, `fixpass.sh`, `balance_sim_p77.sh` (the per-run work folder).
  - `analyze.py`: the replay under a curve, plus engine breakdowns.
  - `analyzed.json` (first pass) and `analyzed_fix.json` (fix pass).
  - `records_fix/*.json.gz`: the fix-pass records. Gunzip them, then run `python analyze.py <folder> 37,38,40,46,47,53,54,63 out.json b_stamp_rerun ...`.
  - `make_balance_json.py` and `verdicts.json`: the page's data. Run `python make_balance_json.py analyzed.json analyzed_fix.json`.

## Round 2: clean split

Measured 2026-10-20 after the user's round-1 decisions (option B STAMP DAY, guarantees may lift a tier, NEW ITEMS / UPGRADES clean split). Same method as above: greedy@sensible, fresh profile, HEAD 1ed5d2e, `--quotas=0 --records`, replayed under the live curve with `balance/analyze.py`, seed 1 (the round-1 seeds). One throwaway worktree outside the repo, one simulation at a time at 60% CPU, about 28 min per row; the worktree, its user-data folder and its Godot processes were removed afterwards.

**What the model does** (patch `balance/p77b_split.patch` = round 1's patch plus two flags, `prodrarity` and `split`; scripts `balance/run4.sh`, `balance/chain.sh`):
- **Registers:** option B only. STAMP DAY after shifts 2/4/6 at the REGISTER odds (Coupon/Category engine Rare, Slot engine Legendary); the player never chooses REGISTER.
- **NEW ITEMS** (`prodrarity`): every product slot of today's offer is redrawn as a **plain** stocked product of a rolled tier, using `product_rarity.json` (75/22/3 at Regular 0, rising with the NEW ITEMS level, which rises only when a product is taken). An empty tier steps down, then up. If no card is generally useful, one product is swapped for a generally useful one of the same tier. Coupon slots stay as today (COUPONS is still not its own chute).
- **UPGRADES** (`split`): after shifts 3, 5 and 7, taken **blind** whenever an upgradable copy exists (Banana, Milk, Eggs, Coffee, as in round 1), and it costs that visit's reward. 3 drops at the UPGRADES level: Common = one step on one chosen copy, Rare = two steps on one plain copy (to GOLDEN), Legendary = shelf upgrade (every copy of one item one step up, no new copy). A tier with no valid target steps down, then up. The player then takes the best prize among the drops, but the drops only roll **tiers**: for each tier rolled, the model scores every upgradable item in the cart and takes the best one (often Milk). In the designed draw (`flow/draw77.js`) each drop is an (item, tier) prize, so the best item is not always offered (3 Common drops over 4 items leave Milk out about 25% of the time). The UPGRADES rows are therefore **upper bounds**. No Golden twin.
- BIG/GOLDEN effects are round 1's (BIG base +2; GOLDEN Milk `bonus_each 2`, Eggs `charges 2`, Coffee `bonus 6`, Banana `BESIDE`).

| Row | Scenario | Runs | Win, live curve | Win, option A curve |
|---|---|---|---|---|
| 1 | **B-stamp + split, UPGRADES blind** (greedy) | 316 | **22.2% ± 4.6** | 80.4% |
| 2 | Same, `build:breakfast_special@sensible` (#42 check) | 387 | **18.9% ± 3.9** | 83.2% |
| 3 | B-stamp + product-rarity NEW ITEMS, no UPGRADES | 319 | **25.4% ± 4.8** | 78.1% |
| r1 | Round 1: B-stamp, uniform offer, no upgrades | 148–206 | 30.4–31.6% | 77–80% |
| r1 | Round 1: B-stamp + items, blind (old tiers, BIG/GOLDEN arrivals) | 85 | 35.3% ± 10.2 | 83.5% |

**Per-shift pass rates (live curve), shifts 1–8:**

| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| 1. split, blind | 99.1 | 98.4 | **66.2** | 83.8 | 77.8 | 70.7 | 91.5 | 81.4 |
| 2. split, Breakfast | 99.0 | 99.0 | **60.4** | 88.6 | 76.4 | 69.7 | 77.8 | 86.9 |
| 3. product rarity only | 99.1 | 98.4 | **65.9** | 83.9 | 82.6 | 76.1 | 83.3 | 90.0 |
| round 1 B-stamp + items, blind | 98.8 | 98.8 | 79.5 | 78.8 | 88.5 | 80.4 | 89.2 | 90.9 |

**Upgraded copies per run (final cart):**
- Row 1: **GOLDEN 1.96** (Milk 1.16, Coffee 0.40, Eggs 0.35, Banana 0.06), BIG 0.86 (Milk 0.42, Banana 0.21, Eggs 0.14, Coffee 0.09); 2.82 upgraded copies in all.
- Row 2: **GOLDEN 2.17** (Milk 1.40, Eggs 0.47, Coffee 0.30, Banana 0.00), BIG 0.70; 2.86 in all.
- Round 1 blind row for comparison: GOLDEN 2.32 (Milk 1.46), 2.85 in all. The split moves about 0.4 copies a run from GOLDEN to BIG (a Common drop is now one step only, and shelf upgrades add BIG copies), but GOLDEN Milk is still about one copy per run.

**Registers owned (row 1):** Category engine 95%, Extra redraw 94%, Coupon engine 76%, Slot engine 19%, Extra coupon slot 17%. Runs with Slot engine win 39% (61 runs), without 18% (255).

**Reading it:**
- **The clean split lands at 22% ± 5, below round 1's 35% ± 10 and below the 35–40% band.** The intervals barely touch; the round-1 row had only 85 runs.
- **Product rarity is the bigger cost: about −5 to −6 points** (row 3, 25%, against round 1's uniform offer at 30–32%). Carrier bag and Tea bags (the two most-picked products) are now Legendary at 3% per drop, and Milk, Eggs, Cereal and Butter Rare, so the best cards turn up much less often. Shift 3 drops from 77–80% to 66%: it is now clearly the wall.
- **Blind UPGRADES add nothing measurable** (row 1, 22%, against row 3, 25%: inside the noise, if anything slightly worse). Taking UPGRADES costs the shift's reward, and a single BIG step is often worth less than the item it replaces. Round 1's +3 to +8 points came from NEW ITEMS arriving BIG/GOLDEN, which the split removes.
- **Breakfast special passes the #42 viability check here:** 18.9% against ⅔ × 22.2% = 14.8% (85% of greedy). Its round-1 bar (20.3–21.1%) came from a greedy rate that is now lower. Slot engine Legendary still keeps Slot engine rare (23% of these runs).
- **Levers, if the band is the target:** the product rarity table is the strongest (e.g. Carrier bag and Tea bags to Rare, or Common odds lower at Regular 0); then a gentler shift-3 quota or STAMP DAY after shift 1 (the shift-3 wall); then making UPGRADES worth its cost (e.g. UPGRADES on top of the reward instead of replacing it). None of these were measured.

**Caveats (round 2):** COUPONS is still mixed into the offer, not its own chute; "3 different types" is still not in the register draw; only Banana, Milk, Eggs and Coffee can be upgraded; the blind UPGRADES player is crude (always takes it when open); the impulse rack is still in the runs; the rarity table is a placeholder. Records: `balance/records_split/*.json.gz`; analysis: `balance/analyzed_split.json`; `balance.json` and `../machine_77_loyalty.html` now show the three rows under "ROUND 2: CLEAN SPLIT".

## Round 3: inspection bonus ticket

Measured 2026-10-20 for the user's idea "inspection can give a second ticket draw?". Same method as round 2: greedy@sensible, fresh profile, HEAD 1ed5d2e, `--quotas=0 --records`, replayed under the live curve `34, 35, 53, 61, 73, 98, 111, 120` with `balance/analyze.py`. One throwaway worktree outside the repo (`config/name` "NC Scratch p77c"), one simulation at a time at 60% CPU. The worktree, its user-data folder and its Godot processes were removed afterwards. Nothing in the game changed.

**The rule modelled** (patch `balance/p77c_bonus.patch` = round 2's patch plus three flags; scripts `balance/run5.sh`, `balance/chain6.sh`):
- **Bonus ticket** (`bonus`): after a **passed shift that had an inspection** (shifts 3, 5 and 7, `inspection_shifts`), the player gets a **second full machine visit**: a fresh reward offer, 3 prizes, pick 1. The chute's Regular meter counts it as a visit. The REGISTER cap and STAMP DAY are unchanged (STAMP DAY is after 2/4/6, so it never meets the bonus).
- **Policy:** visit 1 is round 2's (UPGRADES taken blind when open and a copy can step). Visit 2: UPGRADES again if a copy can still step (blind), else the normal reward (NEW ITEMS/COUPONS, today's mixed offer with product rarity).
- **R3b** (`rarityfile=p77_rarity_b.json`, saved in `balance/`): Carrier bag and Tea bags moved from Legendary to Rare in the product rarity table (Legendary keeps Lemon, Iced bun, Squashed cake).
- **R3e** (`bonusextra=1`): a free second visit also after shift 1 (UPGRADES is not open then, so it is a reward visit).
- Everything else is round 2 row 1: option B registers (never chooses REGISTER), product-rarity NEW ITEMS, round-2 UPGRADES tiers, round-1 BIG/GOLDEN effects.

| Row | Scenario | Runs | Win, live curve | Win, option A curve |
|---|---|---|---|---|
| r2 | Round 2 row 1: split, UPGRADES blind, no bonus | 316 | 22.2% ± 4.6 | 80.4% |
| **R3a** | split + bonus ticket after 3/5/7 (greedy) | 262 | **32.1% ± 5.7** | 84.4% |
| **R3b** | R3a + Carrier bag, Tea bags Rare | 275 | **35.6% ± 5.7** | 85.1% |
| R3c | R3a, `build:breakfast_special@sensible` (#42 check) | 281 | **28.8% ± 5.3**: passes (bar ⅔ × 32.1% = 21.4%; 90% of greedy) | 88.3% |
| R3d | R3b, Breakfast build | not run | (time cap) | |
| R3e | R3b + bonus ticket also after shift 1 | 203 | **38.4% ± 6.7** | 86.2% |

Runs per row: R3a 192 (seed 1, 26 min) + 70 (seed 1001, 10 min); R3b 206 + 69 the same way; R3c 281 (32 min); R3e 203 (32 min, under the 250 asked: the 150-minute cap was reached). The bonus visits make a run about 35% slower to simulate than round 2.

**Per-shift pass rates (live curve), shifts 1–8:**

| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| r2. split, no bonus | 99.1 | 98.4 | 66.2 | 83.8 | 77.8 | 70.7 | 91.5 | 81.4 |
| R3a | 98.9 | 98.5 | **67.8** | 87.9 | 92.1 | 82.1 | 82.6 | 88.4 |
| R3b | 98.9 | 98.5 | **69.4** | 90.9 | 90.5 | 85.6 | 86.3 | 86.7 |
| R3c (Breakfast) | 98.6 | 99.3 | **60.4** | 91.6 | 89.5 | 82.4 | 80.4 | 90.0 |
| R3e | 98.5 | 98.5 | **74.6** | 85.7 | 91.3 | 80.9 | 90.3 | 92.9 |

**Upgraded copies per run (final cart):**
- R3a: **GOLDEN 4.45** (Milk 1.91, Eggs 1.20, Coffee 1.17, Banana 0.18), BIG 1.02 (Banana 0.53, Eggs 0.23, Milk 0.17, Coffee 0.10); 5.47 in all.
- R3b: GOLDEN 4.41 (Milk 1.92, Eggs 1.19, Coffee 1.14, Banana 0.16), BIG 1.04; 5.45 in all.
- R3c: GOLDEN 4.76 (Milk 2.13, Eggs 1.40, Coffee 1.19, Banana 0.05), BIG 0.80; 5.56 in all.
- R3e: GOLDEN 4.42 (Milk 1.92, Eggs 1.20, Coffee 1.12, Banana 0.18), BIG 1.04; 5.46 in all.
- Round 2 row 1 for comparison: GOLDEN 1.96 (Milk 1.16), 2.82 in all. The bonus ticket roughly doubles the upgraded copies: with up to 6 UPGRADES visits a run, almost every Milk, Eggs and Coffee copy ends GOLDEN.

**Slot engine ownership** (share of runs; with / without Slot engine, live win rate):
- R3a: 19.8%; 53.8% (52 runs) / 26.7% (210).
- R3b: 21.5%; 64.4% (59) / 27.8% (216).
- R3c: 24.6%; 53.6% (69) / 20.8% (212).
- R3e: 19.2%; 56.4% (39) / 34.1% (164).
- Category engine 93–95%, Extra redraw 91–94%, Coupon engine 74–79%, Extra coupon slot 11–19% in every row. Median shift-8 total: €182 (R3a), €192 (R3b), €168 (R3c), €203 (R3e).

**Reading it:**
- **The bonus ticket is worth about +10 points** (22% → 32%; the intervals touch by 0.4 points, but the difference is significant, z ≈ 2.7, and r2 and R3a share seeds 1–192 with identical shifts 1–3). Part of it is optimistic: see the first caveat. It lands in shifts 4–8 (shift 5 pass 78% → 92%, shift 6 71% → 82%), as expected for a reward that comes after shift 3.
- **It does not fix the shift-3 wall.** Shift 3 stays at 68–69% (66% in round 2): the first bonus comes after it. It is now the shift where most runs end.
- **Carrier bag and Tea bags to Rare add about +3.5 points** (32% → 36%), inside the noise on its own but in the expected direction (round 2 measured product rarity at −5 to −6).
- **R3b (bonus ticket + those two products Rare) lands at 35.6% ± 5.7, inside the 35–40% band.** R3e (plus a free bonus after shift 1) lands at 38.4% ± 6.7, also inside, and is the only row that lifts shift 3 (75%). The +3 points between R3b and R3e are inside the noise.
- **Breakfast special passes the #42 check** under R3a (28.8% against a 21.4% bar). R3d (the check on R3b) was not run; with R3b's greedy rate the bar would be 23.7%.
- **Watch GOLDEN Milk harder.** About 1.9 GOLDEN Milk copies per run (2.1 in Breakfast runs), and 4.4–4.8 GOLDEN copies in all. The bonus ticket makes round 2's "nerf GOLDEN Milk" more pressing, and a GOLDEN nerf would pull these rows down a few points.

**Caveats (round 3):** **the UPGRADES rows are upper bounds.** The simulated player picks any item at a rolled tier (the best one, often Milk), while the design draws (item, tier) prizes, so the best item is often not among the 3 (about 25% of the time for Milk on 3 Common drops over 4 items). The bonus ticket doubles the UPGRADES visits (up to 6 a run), so it doubles this bias too: the +10 points, R3b's 35.6% (right at the band's 35% edge) and the 1.9 GOLDEN Milk copies per run are all optimistic, and R3b could fall below 35% once the build draws (item, tier) prizes. A smaller bias runs the other way: with the bonus, the UPGRADES meter reaches Regular 3 on visits 4–6 and the model rolls 45/37/18 there without the designed Regular-3 guarantee (drop 1 at least RARE), and NEW ITEMS at Regular 3 lacks it too, which slightly understates those visits. The build re-measures with item-named drops and the guarantee. Also: the blind player takes UPGRADES on both visits whenever a copy can step, which is crude (a real player may prefer an item on the second ticket); a second visit overwrites the shift's `card_picked` in the records (the win rates and final carts are unaffected); COUPONS is still mixed into the offer; "3 different types" is still not in the register draw; only Banana, Milk, Eggs and Coffee can be upgraded; the impulse rack is still in the runs; R3e has 203 runs; ± is ±5.3 to ±6.7, so differences under about 7 points between rows are not reliable. Records: `balance/records_bonus/*.json.gz` (`index.txt` lists each batch); analysis: `balance/analyzed_bonus.json`. `balance.json` and `../machine_77_loyalty.html` show the four rows under "ROUND 3: INSPECTION BONUS TICKET"; to keep the chart readable, five superseded round-1 rows (R1, R2, B-pity, today + items\*, B-greedy\* + items\*) stay in `balance.json` with `hidden: true` and are left off the chart. Rebuild: `python balance/make_balance_json.py balance/analyzed.json balance/analyzed_fix.json balance/analyzed_split.json balance/analyzed_bonus.json`, then `python loyalty/build.py`.
