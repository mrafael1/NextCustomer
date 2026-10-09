# Next Customer: Full Build Plan

> Status: draft v0.23. **This plan will change.** Each full-build playtest round (section 9) can rewrite parts of it. Update the changelog when it does.
> The prototype (`docs/PROTOTYPE_PLAN.md`) closed at proto-r1. Its outside playtest and decision gate (section 9 there) were not run; their questions move to the full build's playtest rounds (section 9).
> Engine: Godot 4 (exact version pinned in `AGENTS.md`), GDScript with static typing. Platform: Windows, mouse. Steam is the main store; itch.io hosts a web demo.

## 1. Pillars

Every feature must support at least one of these. If it doesn't, it waits.

1. **Coupons are the fun multiplier.** They create combinations that are impossible without them, and they bend the rules, not only the numbers.
2. **Scoring is readable.** It is deterministic and every payout is explained. The result can be ridiculous, but the logic is always clear.
3. **Counting points feels great.** The receipt, the printer and the climbing total are the main reward.
4. **The art has a strong identity.** A shabby 1990s discount supermarket in pixel art: chunky shapes, bold outlines, cream / teal / tomato / mustard.

Pillar 2 also covers choosing: every card the player can pick or score shows its rule. A view without rules (item sprites only, as on the figurine shelf) is a catalogue, never a card in the row.

## 2. Scope of version 1.0

| System | Scope ceiling |
|---|---|
| Content | About 20 products on a new profile: the starting deck's 6 staples plus 3 base aisles, one of them small non-food goods (soap, batteries, bulbs). About 30 more products unlock through capsule machines (section 7). **8–10 coupons** (more than the original 6, because coupons are the core), 8 register upgrades |
| Run | 8 shifts, 6 shared slots + 1 coupon-only slot, 3 reusable inspection rules |
| Screens | Title, run start (shopping list, impulse rack), shift (checkout), reward print-out, upgrade choice (exit kiosk), deck view, results / final receipt (with coins), capsule machines and figurine shelf, settings, pause |
| Player support | Tutorial shift, resume save, audio and text-size settings, reduced motion, click-to-place and drag-and-drop (both supported) |
| Meta | 1 starting deck. Capsule machines at the store exit (section 7.1): about 30 product unlocks, one machine per aisle, paid with coins printed on the final receipt. No shop, nothing for sale, no microtransactions. Each run stocks the deck's staples, the listed aisles (every aisle while they fit the stock budget, then 2 the player lists), up to 3 new arrivals and the coupons (section 7.2), so a full collection plays at base-game density. Unlockable decks and card variants after launch. |
| Platform | Windows with Steam (achievements, cloud save via GodotSteam). A web demo on itch.io. |

## 3. Phases

The hours follow the original 160-hour budget. Your additions (more coupons, higher art standards, a smarter upgrade design, capsule machines) put pressure on that budget. Phase 1 gains engine prerequisites, the coupon slot and the meta's data and state; budget them at its start. The prototype's unused iteration budget (up to 12 hours) goes to these Phase 1 additions. The run stock (section 7.2) costs about 8 hours: about 3 in phase 1 (data and the pure builder), about 2 of simulator tooling in phase 2 plus the aisle authoring, and about 3 in phase 3 for the list note and shelf grouping (cuttable; the seeded random list fallback is about 0.5 hours). Section 10 lists what gets cut first.

### Phase 0: Prototype (done: proto-r1)
See `docs/PROTOTYPE_PLAN.md`. It closed at proto-r1 after the developer's own runs (see the header). Its result: the scoring engine, data model, shift screen with click-to-place, count-up sequencer, reward panel, deck view, title and results screens, placeholder sounds, event log with export, and the browser build pipeline, all reused from here on.

### Phase 1: The complete run loop (about 24 hours)
- Extend to 8 shifts; quotas live in a data file
- Drag-and-drop on top of click-to-place (cut from the prototype)
- Keep the event log and browser build running for every playtest round
- **Coupon slots** (decided, section 5.1): 6 shared slots + 1 coupon-only slot. `coupon_slot_count` in balance data, checked by kind in `RunState.can_place`; `slot_count` keeps meaning product slots (the 6 shared slots). Record the rule in `docs/PROTOTYPE_PLAN.md` section 3.1 (the rule spec `core/AGENTS.md` points to), with a changelog row, before changing `can_place`. Built before the style frame and the simulator, which both depend on it. The shift screen fits 7 slots. Content that names slot positions (Opening deal, Shelf swap, Slot engine, the "only 5 product slots" inspection, Risky's extra slot) is specified per kind
- Bundle leaves `first_offer_pool` and `reward_pool` (later `coupon_pool`) until it returns as "2 for 1" in phase 2. Multipack then fills the guaranteed first-offer slot 50% of the time instead of 33%; read coupon pick rates with that in mind. Update `reward_test`'s combination-coupon list; `bundle.tres` stays in `data/cards/`, outside every pool
- Score step contract: `source_kind` (card, upgrade, inspection) plus an index, never a −1 sentinel; an `EFFECT_ARMED` step when a card arms an effect for later cards (Eggs charges, Coffee, Multipack). Totals don't change; the step-sequence and invariant tests are updated with it
- Framework for register upgrades (uses the same scoring hooks as coupons), with 3 placeholder upgrades
- Run state: an upgrade step after the reward pick on upgrade shifts, `upgrades[]`, run history (shift, quota, total, upgrade taken). `upgrade_shifts` and `upgrade_pool` in balance data, with a test that every upgrade shift fits the run length
- Framework for inspections, with 1 rule
- Data model for unlocks: the remaining `DeckDefinition` fields and `CardDefinition.variant_of` (section 7.3)
- **Run stock** (section 7.2): `AisleDefinition` in `data/aisles/` with one placeholder base aisle holding Cheese and Frozen peas (the 3 real base aisles are authored in phase 2), and a pure `core/run_stock.gd` with tests on fixture aisles (data order, unlocked filter, budget rule, listable minimum, new arrivals, same input gives the same stock). `RewardOffer.make` and the impulse rack draw from the run's stock. `reward_pool` becomes `coupon_pool`. Add `data/aisles/` to the resource-loading test, and rewrite the reward tests that assume "every card". The aisle-size data tests (section 7.2) start in phase 2. Nothing shows yet: the budget rule stocks the placeholder aisle, so the reward pool equals today's minus Bundle
- `ProfileState` (fields in section 4), saved separately from the run (section 4)
- Coins print at the bottom of the plain final receipt (section 7.1), with the amounts in balance data, and are added to `ProfileState`
- Deck view (extend the prototype's; decided with the user: a Deck tab with products and coupons, one card per distinct card with its copies and the printed-tag counts, and a Run info tab with the owned upgrades, this and the next shift's inspections and the run's stock; same entry points as the prototype), reward rules (the run's stock, at least one generally useful option, skip)
- Impulse rack before shift 1: pick 1 of 3 stocked products or skip. Reuses the reward offer code; its offer uses a derived stream (section 4) and is logged in `run_start`; the debug replay accepts it. Update `core/AGENTS.md`'s seeded-randomness invariant to allow named derived streams
- Loyalty card greybox: 3 empty boxes beside "Shift x / y · Quota €n", stamped when an upgrade is taken. Plain 3-option upgrade panel with fixed fields (name, type, effect, condition on its own line, supported build)
- Save and resume at stable points (the impulse rack, planning, reward and upgrade screens, never mid-animation; section 4)
- Title and results screens: extend the prototype's (8 shifts, coins line)
- Telemetry stays additive: keep `decide_ms`; add `presented_ms`, `armed_ms`, `presentation_skipped`, an `upgrade` event, and `skip_used` / `skip_at_ms` on `count_up`. The count-up's tap and hold (section 6.2, "Respecting the player") are built here so the skip fields measure something; phase 3 keeps the rest of the presentation. The log summary script (cut from the prototype) is written: `tools/log_summary.py` reports the prototype's measures plus these fields, win rate per list and the second-run skip rate, each defined in `docs/PROTOTYPE_PLAN.md` section 8 ("Log summary")
- **Art style frame:** one complete mock-up of the shift screen in the final style (section 6), to approve the direction before art production starts. It includes the loyalty card and one item sprite at card, slot and flying size. Time the sprite: it sets the real hours per item
- **Balance simulator** (section 8)
- *Done when:* one complete 8-shift run is playable, and the style frame is approved

### Phase 2: Systems and content (about 42 hours)
- About 20 base products (the staples and the 3 base aisles) and 8–10 coupons, designed with the frameworks in section 5
- One of the 3 base aisles is non-food. Check what non-Food items do to Eggs and Multipack; no new "pays 0" hazards beyond Soup
- Aisles authored to the aisle rules (section 7.2): the 3 base aisles grow to about 7 through their machines, and 3 more aisles open through theirs (8/8/7). Every key item combos with a staple
- Bundle returns as "2 for 1" (section 5.1). Connectors are redesigned to link products that are not neighbours. "2 for 1" is a new card id and a new rule script. The Bundle golden rows stay on the frozen `cards_v0_4` fixture, so `ConnectorBridgeRule` stays for that fixture; a new fixture version gets the 2-for-1 rows (same product, different product, two in a row). Decide whether `is_connector` is kept for Shelf swap or retired, and update `core/AGENTS.md` and `docs/PROTOTYPE_PLAN.md` sections 3.4 and 3.7 with the approved rule change
- 7 register upgrades (decided in v0.21: "+1 card drawn" cut), 3 inspections
- Reward economy and quota curve before single-card tuning: the prototype starter passes shifts 1–4 almost always, Multipack dominates, Breakfast sticker is near blank, Eggs is a single point of failure
- Balance passes with the simulator plus a small playtest
- Simulator: a stock parameter, the list gate and the coins-per-run report (section 8)
- Check that at least 4 builds are viable (bulk buyer, breakfast special, coupon specialist, clearance collector, plus builds that only coupons make possible)
- *Done when:* all essential systems work, no single build wins in more than about 40% of simulated optimal runs, and the list gate passes

### Phase 3: Art, sound and counting presentation (about 42 hours)
- Art production following the approved style frame: background, register, conveyor, card frames, one sprite per item (section 6.1), coupon designs, loyalty card with stamps and perk icons, exit kiosk, capsule machines and figurine shelf
- Full counting presentation (section 6.2), including the dessert and the reward print-out. This comes before any other ceremony
- Exit kiosk ceremony on upgrade shifts (on the cut list, section 10)
- Capsule machines at the store exit (section 7.1): first a plain panel (choose a machine, see the figurine), then the machine scene and its animation, and the figurine shelf grouped by aisle. Visibly separate from the exit kiosk. The animation is on the cut list (section 10)
- Shopping list note at the register (section 7.2): 2 sticker lines for aisle signs, pre-filled, "Clock in", "Surprise me". Aisle sign colours are shared by the machine, the list sticker and the card band. NEW price sticker on new arrivals. If only the note is cut, the list is a seeded random pair
- Basket-drop run intro: the starting items tumble onto the conveyor and flip into cards, 3–5 s, skippable, instant with reduced motion
- Sound: scanner beep, printer, register rattle, stamp family (multiplier, PAID, loyalty), paper rip, quota ding, bonus notes generated per pitch (not one sample pitched past an octave), UI sounds, 1–2 music loops with volume ducking before the dessert
- Final receipt that can be exported as a PNG (if time allows)
- *Done when:* content freeze. The build is a release candidate.

### Phase 4: Onboarding, polish and release (about 34 hours)
- Tutorial shift (a fixed hand, guided, no penalty)
- Settings, accessibility, pause
- Steam integration: achievements, cloud save. Store page, trailer, capsule art.
- Public web demo on itch.io, built with the pipeline from the prototype (a short run, with a link to the Steam page)
- Playtest with 5–8 new players, fix bugs
- *Done when:* a stable build is ready for review and the store page is ready

### After launch
- Basket Rush shopping screen (section 7.3)
- Unlockable starting decks and card variants (section 7.3)
- More coupons, upgrades and inspections

## 4. Technical architecture

The prototype structure carries over (`core/`, `data/`, `ui/`, `presentation/`, `debug/`, `telemetry/`, `tests/`). Additions:

```
core/
  score_step.gd           # + source_kind (CARD / UPGRADE / INSPECTION) and source index; + EFFECT_ARMED
  upgrade_definition.gd   # Resource: id, name, type, effect, condition, builds[], rules[],
                          #   run modifiers (extra_redraws, extra_slots, extra_coupon_slots,
                          #   quota_percent); perk icon later (docs/PROTOTYPE_PLAN.md 3.8)
  upgrades/               # UpgradeRule and the upgrade rule scripts
  upgrade_offer.gd        # upgrade offer from the pool, one fitting the deck; pure, run RNG
  build_definition.gd     # Resource: a build measured from the deck (data/builds/)
  shift_limits.gd         # a shift's slots, redraws and quota, from balance data and upgrades
  inspection_definition.gd# Resource: id, display_name, notice_text (the announcement), rules[]
  inspections/            # InspectionRule and the inspection rule scripts
  inspection_schedule.gd  # inspected shifts; draws an inspection from the pool; pure, run RNG
  aisle_definition.gd     # Resource: id, display_name, sign colour, base_cards[], capsule_cards[] (key item first)
  run_stock.gd            # builds the run's stock (section 7.2); pure; uses RNG only for "Surprise me"
  run_state.gd            # + upgrades[] (a deck's starting upgrade first), next inspection, run history,
                          #   upgrade step, the run's stock, the impulse rack (offer, pick) before shift 1
  unlock_condition.gd     # Resource: kind (UNSET rejected), card, amount; summary text (section 7.3)
  unlock_check.gd         # pure check of an unlock condition against an ended run (section 7.3)
  profile_state.gd        # meta (the one field list): coins, run count, unlocked item ids (with the run index
                          # each came out in), last shopping list, unlocked decks and variants, coupon uses by
                          # card id (unlocks, section 7.3), first-seen flags
                          # for long animations, achievements, stats, settings (separate from the run save)
  deck_summary.gd         # the deck view's groups of copies (products, then coupons, by name) and tag counts; pure
  catalogue_definition.gd # Resource: every deck and card variant, for the end-of-run unlock check (section 7.3)
  save_service.gd         # run save + profile save; versioned format; Steam cloud paths
  run_save.gd             # the run save's snapshot (section 4): to and from JSON-friendly data; pure
  content_lookup.gd       # resolves saved ids to data/ resources (id must match the file name)
data/
  aisles/*.tres
  upgrades/*.tres
  inspections/*.tres      # InspectionDefinition (docs/PROTOTYPE_PLAN.md 3.9)
  decks/*.tres            # DeckDefinition (fields in section 7.3)
  catalogue/catalogue.tres# CatalogueDefinition: every deck and variant (a data test checks it against the files)
  balance/balance.tres    # + coupon_slot_count, upgrade_shifts, upgrade_pool, upgrade_offer_size, inspection_shifts,
                          #   inspection_pool, coin amounts (coins_by_shifts_passed, overtime_coin_euros, overtime_coin_max), aisles,
                          #   coupon_pool (replaces reward_pool), run_aisle_picks, aisle_stock_budget,
                          #   aisle_listable_min, end_cap_max, end_cap_window_runs
tools/
  balance_sim/            # headless simulator (section 8)
platform/
  steam_service.gd        # GodotSteam wrapper; does nothing without Steam (editor, web demo)
```

Rules:
- Products, coupons, upgrades and inspections are **all made of the same rule hooks** (upgrades through `UpgradeRule`, which has the same hook names as `Rule` and is asked about every slot by the scoring loop; `docs/PROTOTYPE_PLAN.md` section 3.8). A new idea is a new rule script plus a data file, never a change to the scoring code.
- `score()` stays a pure function. All presentation plays back `ScoreResult.steps`.
- Save files include a format version from the first save. The profile save (decided with the user, phase 1) is `profile.json` in `user://`: JSON (it never runs code, unlike a resource file loaded from `user://`), written to a temporary file and then moved over the save. A profile that can't be read (bad JSON, a missing or newer format version, a field of the wrong type) is reported, kept as `profile.json.bad` (then `.bad.2`, …: a backup is never overwritten), and replaced by a fresh profile. A save that can't be opened or backed up is kept as it is and never saved over in that session; a failed write leaves the save unchanged. The run save (decided with the user, phase 1; `RunSave` in `core/`) is `run.json` next to the profile, a snapshot rather than a replay, with `format_version` 1. It holds what rebuilds the run (the seed, the impulse rack's offer, pick and replaced card, the listed aisle ids, the stock's card ids, `list_skipped` and the new arrivals; `run_start` logs the same) and the whole state: the starting deck, the deck's cards with their instance ids, the next instance id, the hand (with any debug-added card), the draw pile, the row in order, the redraws used and allowed, the shift, the phase, the reward, upgrade and next-inspection offers, the upgrades in pick order, the inspections, the history and the run RNG's state, plus the telemetry's `run_id` and the played time (`run_ms`). The seed and the RNG state are decimal strings, because JSON numbers lose precision above 2^53. Ids resolve through a `ContentLookup` (`data/<kind>/<id>.tres`, whose id must match the file name), and the stock comes from its saved ids, so a resume never depends on a profile that changed after the run started. A resumed run continues exactly as if it had never stopped: the same draws, redraws, offers and inspections. It is written at every stable point: the impulse rack shown, every shift's start, every place, remove and redraw, the checkout click (so closing the game during the count-up resumes on the reward screen; the profile of a run that ends is saved at the same click) and the upgrade tickets shown. Never mid-animation, and never a picked-up card, a redraw selection or the deck-full chooser (the reward panel shows again). A checkout that ends the run deletes it. A run save that can't be read gets the profile's treatment, with its own numbering (`run.json.bad`, `.bad.2`, …): bad JSON, a missing or newer format version, a field of the wrong type, an id that no longer resolves, or a state the game can't reach (a shift outside the run, another phase, a history that doesn't fit the shift, a row card not in the hand, a draw-pile card not in the deck, a repeated instance id, …); a new run then starts and overwrites it at its first save point. Deleting it also removes a leftover temporary file. The title screen reads it without reporting or backing anything up: with a readable save it shows Continue (shift N / M) and New run, and a background click starts nothing (Enter or Space continues); New run asks first ("Abandon the run in progress? It won't count."), then deletes the save and starts a new run. An abandoned run records nothing in the profile, like a restart before the end. The shift screen resumes the save when it holds a readable run and starts a new run otherwise. Telemetry: `run_resume` and `run_abandon` (`docs/PROTOTYPE_PLAN.md` section 8), and `run_end`'s `run_ms` counts played time only.
- The stock is built before `RunState` and passed in. It is ordered staples → listed aisles (aisle data order) → new arrivals → `coupon_pool`, each in data order, never by unlock order. Unlock recency ("newest first", section 7.2) only decides which new arrivals get in, not where they sit. The stored stock ids make replay independent of the profile.
- Derived streams (impulse rack, "Surprise me") are separate `RandomNumberGenerator` instances seeded from `hash([run_seed, "<stream name>"])`, created by the caller outside `core/` (`EventLogService.derived_stream`, next to the run seeds; the rack's stream is `impulse_rack`) and passed in, so `core/` still never makes a seed.
- `CardDefinition.art_ref` stays a path; presentation loads the sprite, so `core/` stays free of art.
- Aisles reference cards; cards stay flat in `data/cards/`.
- Any summary of a result (for example coupon credit) is computed and tested in `core/`, and only after its attribution rule is agreed.
- Tests run headless in CI (GdUnit4 GitHub Action) on every push.

## 5. Design frameworks

### 5.1 Coupons (the core)

Coupons fall into four types. 1.0 has at least 2 of each type, except Connector (at least 1, a second only if adjacency payoffs justify it).

| Type | What it does | Examples |
|---|---|---|
| **Connector** | Creates adjacency between products that are not neighbours | Shelf swap (the next product also counts as just after the row's first product; built in phase 2, v0.20) |
| **Relabeller** | Changes tags | Breakfast sticker, Clearance tag (the next product gains Clearance; built in phase 2, v0.23), Organic label (the next product gains Produce; held until a card reads Produce) |
| **Amplifier** | Multiplies or copies | Repeat, Multipack, 2 for 1 (same product on both sides: the second one pays ×2; it fizzles otherwise, and two in a row both fizzle) |
| **Position** | Rewards placement | Final markdown, Opening deal (if in the first slot, the next product pays ×3; built in phase 2, v0.23) |

**Coupon slots (decided):** 6 shared slots + 1 coupon-only slot. A row holds at most `slot_count` products (6) and at most `slot_count + coupon_slot_count` cards (7); upgrades and inspections that add or remove a slot change one of these two numbers for the run or the shift. One coupon can take the coupon slot; extra coupons can still take product slots. Coupons in the row still break adjacency, so every positional coupon keeps its meaning and `score()` doesn't change. Every row that was legal before stays legal.

Good coupon rules:
- It creates a combination that **did not exist** without it, or it changes the best order of the row.
- Its effect fits in one line of rule text and one icon.
- It has a cost: it uses a slot (the coupon slot or a product slot), or it only works in a certain position.
- It is not dominated: the simulator finds hands where removing it lowers the best score. (The prototype Bundle failed this: it only repaired the gap its own slot made.)
- No loops: a copy never triggers effects again, and coupons cannot copy coupons.

### 5.2 Register upgrades (designed carefully)

Upgrades last for the whole run. They live on the **loyalty card**: it starts empty (a starting deck's upgrade comes pre-stamped in a box of its own before the upgrade-shift boxes, section 7.3), each upgrade stamps one box and shows its perk icon, and the upgrade's receipt lines and count-up fly-ins come from that box. They are offered after the shifts in `upgrade_shifts` (2, 4 and 6), after that shift's normal reward pick or skip: the receipt goes into the exit kiosk, which drops up to 3 prize tickets (see the offer rule below), fully revealed (a cosmetic "INSTANT WINNER!" gag at most, never a hidden face). The exit kiosk sells nothing and is a separate prop from the capsule machines (section 7.1).

Good upgrades:
1. **Change what you draft or how you order cards.** A flat "+N to everything" is not allowed.
2. **Push towards a build without making it mandatory.** Each upgrade states which build it supports.
3. **Have a tradeoff or a condition.** For example "the first coupon in the row pays ×2", but only the first one, and only if it pays something (`docs/PROTOTYPE_PLAN.md` section 3.8).
4. **Use the existing hooks.** If an upgrade needs a new hook, it is a design flag to discuss.
5. **Are visible:** stamped on the loyalty card and named in the receipt explanation.

| Type | Example |
|---|---|
| Rule bender | Coupons no longer break adjacency |
| Slot engine | The 6th product ×2 (coupons don't count) |
| Category engine | +3 per category present when the last product is scanned |
| Coupon engine | The first coupon's payout ×2 |
| Economy | +1 redraw per shift · +1 coupon slot ("+1 card drawn" was cut in v0.21: it overlapped the redraw) |
| Risky | One extra product slot, but the quota +15% |

Upgrade offers: 3 options, from different types, at least one fitting the current deck (since v0.21: builds are data files measured from the deck, `docs/PROTOTYPE_PLAN.md` section 3.8). The player must pick one: there is no skip. Every ticket shows the same fields in the same order: name, type, effect, condition (its own line), supported builds.

### 5.3 Inspections
Visible restrictions that test a build. One is announced before the previous shift's reward choice, printed as a red notice on the receipt under the total (before the kiosk on upgrade shifts). Inspections never go on the loyalty card. Never disable several parts of a build at once. Start with 3 of: only 5 product slots · the 3rd product pays 0 · duplicate payouts capped at 4 · the coupon slot is closed.

Phase 1 (decided, `docs/PROTOTYPE_PLAN.md` section 3.9): shifts 3, 5 and 7 are inspected, each with an inspection drawn from the pool with the run's RNG at the previous passed checkout. The placeholder is "the 3rd product pays 0", which behaves like Soup beside Frozen. During the shift, a red tag in the top bar shows it.

Phase 2 (decided, v0.22): the 3 are Spot check ("the 3rd product pays 0"), Short belt (one product slot fewer than the run has, so Big basket keeps 6) and Coupon slot closed (one coupon slot fewer), never the same one twice in a row. "Duplicate payouts capped at 4" was rejected: it disables several parts of Bulk buyer at once. A closed slot shows as a CLOSED panel on the row.

## 6. Art direction and counting presentation

### 6.1 Art pipeline
1. **Style frame (phase 1):** one screen in the final style. Approve it before any other art production. Approved by the user on 2026-10-08 as the direction ("not perfect, but enough for a style frame"); it is iterated while the phase 3 assets are made. Built as `debug/style_frame/style_frame.tscn` (the shift screen on a fixed shift 3 of 8, scored by `core/`; CHECKOUT plays the real count-up; S switches the sharp-pixel shader for nearest filtering, Tab shows Milk at its three sizes), with captures in `docs/art/` at 1280x720 and 1920x1080 (`godot --path . [--resolution 1920x1080] res://debug/style_frame/style_frame.tscn -- --capture=docs/art`; the capture takes the window's size).
2. **Art bible:** palette (cream paper, faded teal, tomato red, mustard yellow), outline thickness, shading rules, fonts (expressive packaging lettering · plain sans serif for rules · monospace for the receipt), icon set for tags. Decided with the user (v0.17), confirmed or changed by the style frame:
   - **Pixel art** on the 1280x720 canvas: 1 art pixel = 2 canvas pixels (a 640x360 grid), drawn through a sharp-pixel shader so the count-up can still rotate and scale cards without shimmer. Snapping stays off.
   - **Sizes:** an item sprite is a 32x32 grid, shown at 2x on its card and 1x where it stands alone (conveyor, run intro, shelf). Cards stay 120 wide; their height is set by a test that fits every card's title, tags and rule with the real fonts: 200 (100 art pixels), with rules at 12 px, the base value on a price-gun sticker in the corner of the sprite's box, and the sprite's top 2 rows cropped (every item leaves them empty; the converter checks it). The card keeps a text tag line (tags change during scoring) and the aisle band along its bottom (section 7.2). Frames are 9-slices whose edges and middle stretch (a tiled middle picks up neighbouring pixels at its seams once the canvas is scaled); a patterned frame, the coupon's perforation, is drawn at the card's full size.
   - **Palette:** 32 colours in ramps of ink, grey, cream, teal, tomato and mustard, plus green and brown for food; at most 12 per item. A 1 px ink outline, light from the top left, hard shading bands, no anti-aliasing, no dithering on anything that moves. The ink is a warm #2b2420.
   - **Fonts** (SIL OFL 1.1, licence texts in `fonts/`): Pixelify Sans for titles, signs and buttons; Atkinson Hyperlegible Next for rules, tags and tooltips, and at weight 750 (an MSDF-imported copy, so the count-up's slams stay sharp) for every number and price, since Pixelify's € and 2 read poorly; JetBrains Mono for the receipt. Every font must have the glyphs the game prints (€, ×, ·, —, …).
   - **Sources:** each sprite is a palette-indexed text grid in `art/src/` (ignored by Godot), turned into indexed PNGs by `tools/pixel_art.py` (Python standard library), which also lints the sources and writes contact sheets at 1x, 2x and 4x, in greyscale and as silhouettes. `art_ref` holds the PNG's `res://` path.
3. **Production rules:** packaging must stay recognisable at slot size. Colour is never the only signal (always an icon or a label too). Brands are fictional. One sprite per item, reused as the card art (shared frame + sprite + rule text), in the row, in the run intro, as the capsule figurine and on the figurine shelf. It must read at card, slot and flying size. Coupons are a shared paper-coupon frame plus one icon. Non-food items are small everyday goods, so scale stays believable. With fictional brands, silhouettes carry recognition, not lettering.
4. **Who makes the art (decided, v0.17):** the coding agent draws all of it, in the pixel-art sources above, and the user reviews every asset. The style frame times one item sprite (Milk): the agent's minutes, the review rounds and the user's review minutes, logged in `art/src/production_log.tsv` (Milk: about 2 agent minutes, 1 review round, about 2.5 user minutes). The user's review minutes per item set the phase 3 budget. A carton is an easy shape, so the first 3 sprites of phase 3 are timed again.

### 6.2 Counting presentation (driven by `ScoreResult.steps`)

For each slot:
1. The card lifts onto the scanner → beep
2. The base value pops up on the card
3. Each bonus flies in from the card that causes it (that card is highlighted) → the receipt prints a line
4. Multipliers land like a **stamp** (heavier sound, a bigger line)
5. The payout drops onto the receipt, the subtotal ticks up

An effect that arms later cards (Eggs charges, Coffee, Multipack) shows as it is armed and travels to its target. Cards that only scan and pay merge into one short beat.

Escalation:
- The pitch climbs a musical scale across the whole row, not per card
- Intensity (printer speed, paper pile, rattle) follows the run: shift number, steps in the row, the run's best checkout. Not total ÷ quota, which shrinks as quotas rise
- The subtotal changes colour with a short ding when it reaches the quota, unless that happens on the last payout
- Large totals make the register rattle, with a short pause before the final total
- Total vs quota: a clear pass / fail moment

The dessert (about 1 s from the verdict to a clickable reward):
1. A short ducked silence
2. The final total slams once (no re-count)
3. The overtime counts up: "+€N OVER QUOTA" (or "SHORT €N")
4. The receipt tears; any inspection notice prints; the printer feeds the reward print-out, which lifts into full cards beside the receipt

The run's dessert is the final receipt on the results screen, with the loyalty card stapled to it and the run's coins printed at the bottom (section 7.1).

Time budget: about 4–6 s for a full row, about 1 s from the verdict to a clickable reward, about 1.2 s to the kiosk choice (longer variants play once per profile).

Respecting the player:
- A tap speeds the count to the verdict; a second tap skips the dessert. A hold fast-forwards (a press-time threshold separates the two; the checkout click's release is ignored). Skips speed tweens up, they never kill them. The tap and the hold are built in phase 1 (200 ms threshold; `docs/PROTOTYPE_PLAN.md` section 8). The count speeds up automatically from shift 3. `count_up_ms` keeps its meaning (click to final total shown); skips are logged separately
- Pauses (hit-stop) pause the count-up's own tweens, never the engine's time scale
- Speed settings; reduced motion (no shaking, a calmer count)
- The receipt is always a straight, readable list, even when the paper curls
- No information is shown only inside an animation

## 7. Unlocks: capsule machines, aisles and decks

Design rules (from the original doc): **unlocked decks have comparable starting strength**. Unlocks add options, not raw power. No permanent payout increases.

### 7.1 Capsule machines
One capsule machine per aisle at the store exit, like the coin-op toy machines that sell little figurines. 1 coin = 1 capsule: a fixed price, no shop, no second currency, nothing for sale, no microtransactions.

- **Coins** print at the bottom of the final receipt, as part of the run's dessert: more the further the run got, a little for overtime, something even for a lost run. The amounts live in balance data. Decided with the user (phase 1, `CoinPayout` in `core/`): `coins_by_shifts_passed[shifts passed]` (placeholders 0, 0, 1, 1, 1, 1, 1, 1, 2; index 8 is a won run), plus one overtime coin per `overtime_coin_euros` (60) of margin over quota summed over the passed shifts, at most `overtime_coin_max` (1). A run lost on shift 1 or 2 pays no table coins, so losing fast doesn't farm capsules (only a shift-1 overtime of at least €60, unlikely against a €10 quota, still pays the overtime coin; the simulator checks this when it retunes the amounts); a typical run pays 1, a won run 2, a great win 3. When the profile can't be saved, the results print the run's coins but no total ("you have ?"). The results screen prints the breakdown (shifts passed, overtime, then the coins and the profile's total), and the title screen shows the total.
- **The draw:** the player picks the machine; the draw inside it is random, without duplicates, until the machine is empty (that aisle's collection is complete). The first capsule from each machine is always the aisle's key item, so later items have something to combine with.
- **The figurine:** the capsule holds the item's figurine, its plain card sprite. Unlocked figurines go on the shelf, which doubles as the catalogue (items without their cards).
- **Unlock unit:** an aisle's items through its machine, never orphan random cards from the whole catalogue. Unlocked items join the run's stock (section 7.2), which feeds the impulse rack and reward offers.
- **Pacing target:** about 1 capsule per average run, 2–3 for a great run. About 30 unlocks, finished in about 25–40 runs.
- **Wording:** "capsule machine" in this plan; in-game copy may also say "toy machine". Never "gacha", in the game or on the store page.
- **Separate from the exit kiosk:** both are props at the store exit, but the kiosk offers the mid-run upgrades and stamps the loyalty card (section 5.2). They look different and do different things.
- **Phasing:** coins on the receipt and the saved unlock state in phase 1; the machine, its animation and the figurine shelf in phase 3.

### 7.2 Run stock: the shopping list
**Unlocks widen the choice between runs, never the pool inside a run.** Offers are uniform draws, so offer quality depends only on how many products are stocked. The target is about 20 products, whatever the collection size.

Each run stocks, in data order:
1. **Staples:** the starting deck's own products (starter: Banana, Bread, Milk, Eggs, Coffee, Soup), derived from the `DeckDefinition`. Always stocked, no machine. In the starter they hold all 4 `generally_useful` cards (Banana, Bread, Eggs, Milk), and every deck's staples hold at least 2 (a data test), so the reward guarantee always has a candidate. Aisles may add up to 2 more each. A later deck brings its own staples.
2. **Listed aisles**, whole aisles only. If every listable aisle together holds at most `aisle_stock_budget` (16) products, all are stocked and the list is skipped (new profiles, the tutorial, the web demo, or a cut machine). Otherwise the player lists `run_aisle_picks` (2). An aisle is listable once it holds `aisle_listable_min` (4) items; the minimum applies to machine-opened aisles only, so an aisle with `base_cards` is always listable.
3. **New arrivals (the end-cap):** up to `end_cap_max` (3) items from unlisted aisles that came out of a capsule in the last `end_cap_window_runs` (3) runs, newest first. Decided with the user (phase 1): the profile keeps, in draw order, each unlocked item's run index: the 0-based index of the run at whose exit it came out (that run's count of earlier runs, not the count after it ended); a run with index N (N earlier runs) takes items with index N − 3 to N − 1, so a capsule from run K rides runs K + 1 to K + 3, newest first by run index, and within one run the later draw first. The newest takes one impulse-rack slot. A machine-opened aisle that is not yet listable reaches the run only this way: each of its items rides the end-cap for the 3 runs after it came out (decided with the user, phase 1: the window applies to every capsule item), so its early items can leave the stock before the aisle holds 4 and becomes listable. A capsule is always playable in the next run.
4. **Coupons:** all of `coupon_pool`. Coupons are never in aisles or capsules.

Reward offers keep the prototype's rules (`docs/PROTOTYPE_PLAN.md`, section 5) and draw from the stock: the first offer includes a combination coupon, every later offer has at least 1 coupon and at least 1 `generally_useful` card, and an offer never shows a card twice. The impulse rack shows `impulse_rack_size` (3, balance data) stocked products in random order, the newest new arrival in one of its slots; the player picks one for the deck or skips. Decided with the user (phase 1): at the deck limit a rack pick removes a deck card, as a reward pick does. The rack comes before shift 1's draw, so the pick can be drawn in shift 1.

The reward prints from the receipt as the reward print-out: coupons plus promo products (stocked products on special offer, shown as full cards).

**The shopping list:** a note at the register before the impulse rack. It is pre-filled with the last list (the first time, with the newly listable aisle if there is one, otherwise the two base aisles with the most unlocked items, ties by data order), and one click clocks in. "Surprise me" picks a pair from a derived stream (section 4). The list stores a preference, never power. No per-item toggles, ban lists or figurines turned to the wall: players would prune to the strongest cards. Also rejected: ticketed offers (a rule change with a new hook on every rule), a seeded-only flyer as the default (kept only as the fallback if the note is cut), and a stock-size valve (the 9-item aisle cap replaces it).

**Content shape (1.0, decided; easy to change later, because the stock rule works with any number of aisles):** 6 staples · 3 base aisles open from the start (5/5/4), whose machines add 2–3 each, to about 7 · 3 aisles opened by their machines (8/8/7) · 30 capsules, about 50 products · at full collection, 15 possible lists of 20–22 products (plus up to 3 new arrivals).

**Aisle rules (data tests):** every product is a staple or in exactly one aisle · 6–9 items per complete aisle · at most 2 `generally_useful` per aisle · the capsule list starts with the key item · every deck's staples hold at least 2 `generally_useful` products. Simulator rule: every key item and capsule item reaches the best row with a staple or its own aisle, so nothing is an orphan while it rides the end-cap.

**Saves and replay:** building the stock uses no RNG except "Surprise me". The stored stock (section 4) means a resume never depends on a profile that changed after the run started.

### 7.3 Decks and card variants (architecture now, content after launch)

The prototype already has `DeckDefinition` (id, name, cards) and data-driven cards. Phase 1 adds the remaining fields below, so adding decks and variants after that is a content task:

- `DeckDefinition`: id, name, description, card list, starting upgrade (optional), unlock condition. Its distinct products are its staples (section 7.2)
- `CardDefinition.variant_of`: card variants (e.g. "Organic Banana" as a variant of Banana), with their own optional unlock condition. A variant is a variant of a card that is not itself a variant, of the same kind (a data test)
- `ProfileState` (fields in section 4) holds the deck and variant unlocks. Saved separately from the run.
- Unlock conditions are data (`UnlockCondition`: kind, card, amount) and are checked when a run ends. No condition means available from the start. Decided with the user (phase 1):
  - **Win a run with X:** X is a card in the run's final deck, and the run must be won.
  - **Score Y in one checkout:** any checkout of the run that just ended totals at least Y.
  - **Use coupon Z N times:** across runs, every copy of Z in a checked-out row counts once. The run history records each shift's checked-out cards; earlier runs' counts come from `ProfileState`.
  - The check is pure (`UnlockCheck`, tested in phase 1). At the end of a run (won or lost), `ProfileState.record_run` checks every locked deck and variant in `data/catalogue/catalogue.tres` with the coupon counts from before the run, then adds the run's coupon uses and counts the run; the profile is saved at the checkout click. Decided with the user (phase 1): a run restarted before its end records nothing.
- **Starting upgrade (decided with the user):** a run started with a deck that has one owns it from the first shift. Upgrade offers skip it like any owned upgrade, it counts for redraws and scoring, and the loyalty card gives it a pre-stamped box of its own before the upgrade-shift boxes. The starter deck has none.

Possible ideas: Breakfast deck (start with Coffee and Milk), Coupon deck (fewer products, 2 starting coupons), Frozen deck (Frozen peas, Soup risk).
Card changes: unlock variants that replace a starting card (e.g. swap 1 Banana for an Organic Banana in the run start screen).

**Basket Rush (after launch):** a shopping screen that builds the starting deck. One limit: item prices in data plus a fixed basket size (a size limit alone allows 6 Eggs + 6 Milk). Dexterity never changes what ends up in the deck. It remembers the last basket, is skipped on the first run and in the web demo, and has a static mode for reduced motion. Its strength spread is checked with the simulator's run win rates.

## 8. Balance simulator

A command-line tool, run headless, that uses `core/` directly:
- For a given hand, it tries every selection and order of up to 7 cards with at most 6 products (section 5.1), including shorter rows, because a shorter row can score higher, and finds the best possible score. That is up to about 69,000 rows for a hand of 8 (40,320 seven-card rows plus the shorter ones), and about 1.6× more when an upgrade adds a slot (Extra coupon slot or Big basket; with both, the hand of 8 still caps a row at 8 cards). "+1 card drawn", which would have made it about 4×, was cut in v0.21
- It simulates thousands of seeded runs with simple drafting strategies (greedy, build-focused)
- Outputs: the distribution of best scores per shift (to set quotas), win rate per build, how often each card is in the best row (finds dominant or useless cards)
- Models the redraw, the coupon slot, the impulse rack (picked with the strategy's reward rule, decided with the user, phase 1) and a starting-deck parameter
- Reports per-shift score percentiles (used for count-up intensity) and flags dominated cards (removing them never lowers a best score)
- Values coupons against other coupons per coupon slot, not against skipping
- Takes a stock parameter. List gate: every legal list at full collection, plus the minimum states (a new aisle at 4 items, the first list after the budget is passed), has a run win rate within ±5 percentage points of the fresh-profile stock's, and no list pushes a build over the 40% bar. Reports the per-offer chance of seeing a build's key cards; at full collection it stays at least 85% of the fresh profile's
- Reports coins per run from the balance-data coin amounts; they are tuned so the median run pays about 1 coin, a great run 2–3, and the 30 unlocks take about 25–40 runs (section 7.1)

It doesn't measure fun, only what is possible. Quotas are set so that a sensible but not optimal order passes.

## 9. Testing and quality

- Unit tests: every rule, every coupon, every upgrade and inspection, the run stock, save and resume, seed reproducibility
- Data tests: the aisle rules (section 7.2)
- Golden tests: fixed rows with known totals (the doc's 31 / 18 example stays forever)
- Playtest rounds: end of phase 1, middle of phase 2, end of phase 3, phase 4. They replace the prototype's outside playtest
- The end-of-phase-1 round also asks the prototype gate's questions: can players explain a payout and their order, find a coupon combination on their own, and restart voluntarily? It also times two back-to-back runs (non-interactive reward and upgrade time about 15 s or less per run, the sum of `armed_ms` over the run's offers; fewer than about 70% of second-run presentations skipped), checks that people can name each upgrade's condition line, and asks whether players still want the impulse rack on their third restart
- Keep a list of the 3 problems that most affect understanding or fun; update it daily

## 10. Risks and what gets cut

| Risk | Response |
|---|---|
| Art takes longer than planned | Fewer unique packaging designs (reuse frames + icons) · simpler background · cut PNG export |
| Coupons create one dominant combination | Simulator + limits (max coupons per row, coupon slot count, Repeat can't copy amplified values) |
| Upgrades feel weak or samey | Fewer upgrades (6) that are more distinct, rather than 8 average ones |
| Too many ceremonies for the presentation hours | The count-up, the dessert and the final receipt come first; the kiosk ceremony, run intro and capsule-machine animation are cut before them (cut order below) |
| Players skip reward and upgrade presentations | Measure `presentation_skipped`; shorten until second-run skips are under about 70% |
| Item count multiplies art (about 30 more products) | One sprite per item, reused as the figurine · cut the machine-opened aisles whole, with their machines, before any base product; the stock rule works with any number of aisles |
| The capsule machines read as monetisation | 1 coin = 1 capsule, no shop, nothing for sale; never called "gacha"; the store page states there are no microtransactions |
| The shopping list adds friction at run start | Hidden until the budget is passed, pre-filled, one click, "Surprise me". If over about 70% of lists are never changed, make "Surprise me" the default |
| One list dominates | Simulator list gate · `run_start` logs the aisles and stock size · win rate per list in the summary script |
| The first list feels like losing an aisle | The stock gets denser, not weaker; the first list is pre-filled (section 7.2: the new aisle if there is one) and new arrivals always show up |
| Schedule slips | Cut in this order: kiosk ceremony → PNG export → run intro → capsule-machine animation (a plain machine panel stays) → shopping-list note (a seeded random list stays) → 3rd inspection → machine-opened aisles, whole, with their machines (retune the coin amounts for the 7 capsules left in the base machines) → upgrade count. Coins and saved unlocks are cut only after all of these. **Never cut:** the scoring explanation, the counting presentation (including the dessert), bug-fixing time. |
| Confusing rules | Simplify effects before adding content |

Content freeze at the end of phase 3. No new features after that.

## 11. Release

- Price: proposed €3.99–5.99 (to check against similar games)
- Steam store page in phase 3, as soon as the game has its final look (decided with the user: a page with placeholder art wouldn't sell it), to start collecting wishlists; phase 4 finishes it with the trailer
- The store page states there are no microtransactions. The capsule machines are called capsule or toy machines, never "gacha"
- Web demo on itch.io: a short run, clear link to Steam
- Marketing hook: short clips of ordinary groceries producing an absurdly long receipt
- Track separately: store visits, wishlists, demo starts, tutorial completion, voluntary replays

## 12. Open decisions

- The exact preview vs a less prominent preview (default: exact during planning; a dimmed target marker during the count-up)
- Immediate loss vs one supervisor warning
- 8 shifts vs a shorter run
- Reward mix: coupons + promo products (default) or coupons only
- Upgrades on the loyalty card (default) or on the register; customer loyalty card (default, "staff shop here too") or staff timecard (one framing for every screen)
- Whether the margin over quota ever affects rewards (default: not in 1.0; overshoot tiers are cosmetic, from per-shift percentiles; revisit with the simulator)
- Basket Rush in 1.0 (default: impulse rack only)

## 13. Changelog

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-10-05 | First plan, before the prototype |
| v0.2 | 2026-10-05 | Aligned with prototype plan v0.2: click-to-place first and drag-and-drop in phase 1 if cut, browser build and event log carried over, prototype estimate 18–24 hours |
| v0.3 | 2026-10-05 | Re-aligned with prototype plan v0.3 (15-card deck limit, seeded-RNG and stateless-rule rules, `generally_useful` card flag) · engine version defers to `AGENTS.md` · simulator row count corrected to about 29,000 |
| v0.4 | 2026-10-05 | Re-aligned with prototype plan v0.4: `telemetry/` carried over · the prototype's `DeckDefinition` has id, name and cards; phase 1 adds the other deck fields, `variant_of` and `ProfileState` · one `DeckDefinition` field list (section 7) |
| v0.5 | 2026-10-06 | From the developer's proto-r1 runs: prototype closed, no outside playtest or proto-r2; full-build playtest rounds take the gate's questions, and the end-of-phase-1 round adds timing and condition-line checks · coupon slots decided (6 shared + 1 coupon-only, phase 1) · loyalty card and exit kiosk for upgrades · reward print-out (7.2) · dessert, escalation and skip rules (6.2) · `source_kind` and `EFFECT_ARMED` · Bundle out of the pools until "2 for 1" (phase 2), so Multipack fills the guaranteed first-offer slot 50% of the time; Connector redefined · inspections print as a red receipt notice; "the coupon slot is closed" added · impulse rack in phase 1 · meta in 1.0: capsule machines and coins (7.1); the store page states no microtransactions · run stock and shopping list (7.2) replace the prototype's "reward pool: every card"; `reward_pool` becomes `coupon_pool` · `ProfileState` field list and telemetry fields · simulator: 7-card rows, redraw, coupon slot, percentiles, dominated cards, list gate, coins per run · cut order and open decisions updated · decided with the user: the shopping list (7.2) and 6 aisles at full collection · `AGENTS.md` now points to this plan (phase 1) |
| v0.6 | 2026-10-06 | Aligned with the upgrade framework (`docs/PROTOTYPE_PLAN.md` v0.13, section 3.8): `UpgradeDefinition` fields, `core/upgrades/` and `upgrade_offer.gd` in the tree, `upgrade_offer_size` in balance data, upgrades use `UpgradeRule` with the same hook names, phase 1 offers skip the "fits the deck" rule until build tags exist, and the upgrade pick has no skip (decided with the user) |
| v0.7 | 2026-10-06 | Aligned with the inspection framework (`docs/PROTOTYPE_PLAN.md` v0.14, section 3.9): `InspectionDefinition` fields, `core/inspections/` and `inspection_schedule.gd` in the tree, `inspection_shifts` (3, 5, 7) and `inspection_pool` in balance data, the placeholder "the 3rd product pays 0" (like Soup), drawn with the run's RNG at the previous passed checkout, and a red top-bar tag during the inspected shift (decided with the user) |
| v0.8 | 2026-10-06 | Unlock data model (phase 1, section 7.3), decided with the user: `DeckDefinition` gains description, starting upgrade and unlock condition; `CardDefinition` gains `variant_of` and an unlock condition · `UnlockCondition` (win a run with a card in the final deck, score Y in one checkout, use a coupon N times across runs, every checked-out copy counting once) with a pure `UnlockCheck`; hooking it up at run end comes with `ProfileState` · a deck's starting upgrade is owned from the first shift, skipped by offers, and gets a pre-stamped loyalty-card box · the run history records each shift's checked-out cards · `ProfileState` gains coupon uses by card id · section 5.2 points to the pre-stamped box |
| v0.9 | 2026-10-06 | Run stock built (phase 1, section 7.2, `docs/PROTOTYPE_PLAN.md` v0.17): `AisleDefinition` (id, name, sign colour, base cards, capsule cards), one placeholder base aisle (Cheese, Frozen peas), the stock numbers and `coupon_pool` in balance data, and a pure `RunStock` built before `RunState` and passed in; reward offers draw from it · new arrivals decided with the user: a window of run indices, newest first, later draw first within a run; the window applies to a not-yet-listable aisle's items too, so they no longer ride the end-cap until it holds 4 · `run_start` logs `listed_aisles` and `stock` · until `ProfileState` (#14) and the list note (phase 3), every run stocks a new profile's stock; the simulator does the same · the non-size aisle rules (products only, every product a staple or in exactly one aisle, at most 2 `generally_useful` per aisle, at least 2 per deck's staples) are data tests from now on |
| v0.10 | 2026-10-06 | `ProfileState` and the profile save (phase 1, sections 4 and 7.3), decided with the user: every field in section 4 (achievements, stats and settings stay empty until their content exists) · the end-of-run unlock check and coupon counts, over a new `data/catalogue/catalogue.tres` listing every deck and variant (exported builds can't list `res://` folders reliably) · only a won or lost run is recorded; a restart before the end records nothing · `profile.json` with `format_version` 1, written through a temporary file; an unreadable save is reported and kept as `profile.json.bad` (numbered, never overwritten), one that can't be opened or backed up is never saved over, and a failed write leaves the save unchanged · the shift screen loads the profile at start, builds each run's stock from it (unlocked items, last list, run count) and saves it at the checkout click that ends a run · the `run_start` and `run_end` event fields move to `RunEvents` (unchanged) |
| v0.11 | 2026-10-07 | Coins (phase 1, section 7.1), decided with the user: a table by shifts passed plus capped overtime coins, every amount in balance data (`coins_by_shifts_passed`, `overtime_coin_euros`, `overtime_coin_max`), computed by a pure `CoinPayout` and added to `ProfileState` when a run ends · the results screen prints the breakdown at the bottom of the final receipt; the title screen shows the shift count from balance data and the profile's coins (read without reporting or backing up an unreadable save) · the `redraw` event fields move to `RunEvents` (unchanged) |
| v0.12 | 2026-10-07 | Impulse rack (phase 1, sections 4, 7.2 and 8; `docs/PROTOTYPE_PLAN.md` v0.18), decided with the user: `impulse_rack_size` (3) stocked products in balance data, the newest new arrival in one slot, built by `RewardOffer.make_impulse` from the rack's derived stream (`EventLogService.derived_stream`, stream `impulse_rack`; `core/AGENTS.md` now allows named derived streams); a pick or a skip before shift 1, shown on the reward panel; at the deck limit a pick removes a deck card, as a reward does · `run_start` is logged after the rack and adds `impulse_offer`, `impulse_pick`, `impulse_replaced`, `impulse_decide_ms` and `impulse_deck_view_opened` (`starting_deck` is the deck before the rack); the run's length includes the rack; Export log names the `impulse_rack` screen · the debug panel's "New run with this seed" can replay a logged pick (or a skip) without showing the rack; a pick that isn't in the offer is refused and logged; the debug shift jump from an ended run replays its seed with its rack choice · the simulator picks the rack with each strategy's reward rule and reports impulse-rack picks |
| v0.13 | 2026-10-07 | Deck view extended (phase 1, sections 3 and 4), decided with the user: the Deck tab shows products then coupons, one card per distinct card with its number of copies (×N), and how many copies carry each printed tag; a Run info tab shows the owned upgrades (name, type, effect, condition), the inspections (this shift's while planning; the next shift's once drawn at checkout, or "inspected (announced at checkout)" when scheduled; none after the last shift) and the run's stock (its aisles, every card a reward or the impulse rack can offer, new arrivals marked NEW); the pages scroll inside a fixed area so the view fits the window at full collection · the remove-a-card chooser shows only the Deck tab and a grouped card chooses one of its copies · a pure `DeckSummary` in `core/` · entry points unchanged |
| v0.14 | 2026-10-07 | Save and resume (phase 1, sections 3 and 4; `docs/PROTOTYPE_PLAN.md` v0.19), decided with the user: a snapshot run save, `run.json` next to `profile.json` with `format_version` 1, holding the rebuild data and the whole state (deck and hand instance ids, draw pile, row, redraws, offers, upgrades, inspections, history, the RNG state and the seed as decimal strings, `run_id` and played `run_ms`), so a resumed run continues exactly · written at every stable point (the impulse rack, each shift's start, each place, remove and redraw, the checkout click, the upgrade tickets) and never mid-animation; quitting during the count-up resumes on the reward screen; a run that ends deletes it · an unreadable save gets the profile's treatment (`run.json.bad`, numbered separately) and a new run starts · the title screen shows Continue (shift N / M) and New run when a readable save exists; New run asks before abandoning it, and an abandoned run records nothing · telemetry: `run_resume` and `run_abandon`, and `run_end`'s `run_ms` counts played time only · the shift screen's debug tools move to `ShiftDebug` (unchanged, except that a `--demo-row` session plays a new run and leaves the run save untouched) |
| v0.15 | 2026-10-07 | Telemetry additions (phase 1, sections 3, 6.2 and 9; `docs/PROTOTYPE_PLAN.md` v0.20), decided with the user: an offer's timeline runs from the moment it starts presenting: `presented_ms` (fully shown: today the pop-in's end, later the print-out or kiosk ceremony), `armed_ms` (accepts clicks), `decide_ms` (unchanged) and `presentation_skipped` (always false until phase 3 adds a skippable presentation), on `reward`, `upgrade` and, prefixed `impulse_`, `run_start`; an offer shown again after the deck view keeps its first times, a resumed one starts new ones, and a debug replay of the rack applied at once logs 0; the top bar's Deck waits for the offer to arm, so `armed_ms` stays forced waiting · the target non-interactive reward and upgrade time (section 9) is the sum of `armed_ms` over a run's offers · the count-up's tap is built in phase 1: a press under 200 ms is a tap (the first speeds the count to the verdict, a second skips the dessert), a longer one a hold (fast-forward), read from input events; a press on a button that can be pressed is neither; `count_up` gains `skip_used`, `skip_at_ms` and `dessert_skipped`; phase 3 keeps the rest of the presentation |
| v0.16 | 2026-10-08 | Log summary script (phase 1, sections 3 and 9; `docs/PROTOTYPE_PLAN.md` v0.21, section 8), decided with the user: `tools/log_summary.py` in Python's standard library only, tested with unittest from `tools/test.sh`'s full run · each input file is one player (each tester sends one export; files that share a session, a tester's two exports, count as one); `--one-player` reads the game's per-session folder, the default input, as one · the second-run skip rate is `presentation_skipped` over the player's second run's offers (rewards, upgrades, the impulse rack when shown), always 0% until phase 3; the count-up tap and dessert skips are reported beside it, separately · a build is the final deck's coupons (rebuilt from `run_start` and the `reward` events, each card's kind read from `data/cards/`) plus the upgrades taken · also win rate per list and the non-interactive offer time per run against section 9's 15 s |
| v0.17 | 2026-10-08 | Art direction for the style frame (phase 1, sections 1 and 6.1), decided with the user: pixel art (1 art pixel = 2 canvas pixels on the 1280x720 canvas, a sharp-pixel shader, 32x32 item sprites at 2x on cards and 1x alone) · card height set by a font-fit test (120x200; base value on a price sticker, rules at 12 px), width unchanged · a warm-ink palette in ramps with drawing rules · fonts Pixelify Sans, Atkinson Hyperlegible Next (also bold, for numbers and prices) and JetBrains Mono · sprites as text grids converted by `tools/pixel_art.py` · the coding agent draws all the art and the user reviews it, so "who makes the art" leaves the open decisions; Milk is timed in the style frame and the first 3 phase-3 sprites again · the style frame plays the real count-up on a scored row, and the user approved it as the direction (Milk took about 2.5 minutes of review) |
| v0.18 | 2026-10-08 | Phase 1 closed; phase 2 starts (its tasks are the "Phase 2" milestone) · the Steam store page moves from phase 2 to phase 3, once the game has its final look (decided with the user; section 11), and phase 4 finishes it |
| v0.19 | 2026-10-08 | Base products (phase 2, issue #34; `docs/PROTOTYPE_PLAN.md` v0.22), decided with the user: the 3 base aisles Cold cases (teal), Pantry (mustard) and Household (grey, the non-food aisle), 5/5/4 products with 12 new ones, replace the placeholder aisle · new tags Household and Clearance; non-food items are not Food, so Eggs skips them and Multipack can double a Household or Clearance family · one new rule script (Scissors) · tomato stays off aisle signs (the inspection notice is red) · condition fizzles for silent conditional cards are issue #45 |
| v0.20 | 2026-10-08 | 2 for 1 and Shelf swap (phase 2, issue #37; `docs/PROTOTYPE_PLAN.md` v0.23), decided with the user: 2 for 1 links the same product on both sides and the second pays ×2 (an armed effect); Shelf swap links the next product to the row's first product, both ways; links can stack on one side · "same product" means a variant counts as its base card, everywhere (#39 uses it for duplicates) · `is_connector` is set only by Bundle, which stays in `data/cards/` outside every pool, and read only by its rule for the frozen fixture · 2 for 1 replaces Bundle in `coupon_pool` and `first_offer_pool` (Multipack back to a third of the guaranteed slot), and Shelf swap joins `coupon_pool` |
| v0.21 | 2026-10-08 | Register upgrades (phase 2, issue #38; `docs/PROTOTYPE_PLAN.md` v0.24), decided with the user: 7 upgrades (Rule bender, Slot engine, Category engine, Coupon engine, Extra redraw, Extra coupon slot, Big basket), "+1 card drawn" cut · Rule bender needs an upgrade context hook (approved design flag) · one raised quota for Big basket, fixed when the shift starts · shift limits (`ShiftLimits`) carry the run modifiers that #39's capacity inspections extend · build files in `data/builds/` and the offer's "fits the deck" guarantee · a row wider than 7 slots is scaled · flags for #41: Slot engine is strong (Repeat copies the doubled product), Category engine can reach +24, Big basket breaks even or loses on the current quotas |
| v0.22 | 2026-10-09 | Inspections (phase 2, issue #39; `docs/PROTOTYPE_PLAN.md` v0.25), decided with the user: Spot check, Short belt (one product slot fewer than the run has) and Coupon slot closed (one coupon slot fewer), as shift modifiers on top of the upgrades' (`ShiftLimits`) · Short belt may turn Slot engine off and Big basket counters it · "duplicate payouts capped at 4" rejected · no inspection twice in a row · CLOSED panels on the row |
| v0.23 | 2026-10-09 | Coupons (phase 2, issue #36; `docs/PROTOTYPE_PLAN.md` v0.26), decided with the user: Clearance tag (Relabeller) and Opening deal (Position, in the first slot the next product pays ×3, raised from the plan's ×2 so it competes with Final markdown for the coupon slot) join `coupon_pool`, which holds 8 coupons meeting section 5.1 · Organic label is held until a card reads Produce (none does yet; revisit with the capsule aisles, #35) · the first-offer pool is unchanged · Opening deal and the Coupon engine pull against each other (a working Opening deal is the first coupon and pays 0), accepted as its cost |
