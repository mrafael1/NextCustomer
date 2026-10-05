# Next Customer: Full Build Plan

> Status: draft v0.2. **This plan will change.** Each prototype playtest round can rewrite parts of it. Update the changelog when it does.
> Starts only after the prototype passes its decision gate (`docs/PROTOTYPE_PLAN.md`, section 9).
> Engine: Godot 4.7, GDScript with static typing. Platform: Windows, mouse. Steam is the main store; itch.io hosts a web demo.

## 1. Pillars

Every feature must support at least one of these. If it doesn't, it waits.

1. **Coupons are the fun multiplier.** They create combinations that are impossible without them, and they bend the rules, not only the numbers.
2. **Scoring is readable.** It is deterministic and every payout is explained. The result can be ridiculous, but the logic is always clear.
3. **Counting points feels great.** The receipt, the printer and the climbing total are the main reward.
4. **The art has a strong identity.** A shabby 1990s discount supermarket: chunky shapes, bold outlines, cream / teal / tomato / mustard.

## 2. Scope of version 1.0

| System | Scope ceiling |
|---|---|
| Content | About 20 products, **8–10 coupons** (more than the original 6, because coupons are the core), 8 register upgrades |
| Run | 8 shifts, 3 reusable inspection rules |
| Screens | Title, shift (checkout), reward, upgrade choice, deck view, results / final receipt, settings, pause |
| Player support | Tutorial shift, resume save, audio and text-size settings, reduced motion, click-to-place and drag-and-drop (both supported) |
| Meta | 1 starting deck. **The architecture is ready for unlockable decks and cards** (section 7), but they are only added if time allows, otherwise after launch. |
| Platform | Windows with Steam (achievements, cloud save via GodotSteam). A web demo on itch.io. |

## 3. Phases

The hours follow the original 160-hour budget. Your additions (more coupons, higher art standards, a smarter upgrade design) put pressure on that budget. Section 10 lists what gets cut first.

### Phase 0: Prototype (18–24 hours + up to 12 for iteration)
See `docs/PROTOTYPE_PLAN.md`. Its result: the scoring engine, data model, shift screen with click-to-place, count-up sequencer, event log with export, and the browser build pipeline, all reused from here on.

### Phase 1: The complete run loop (about 24 hours)
- Extend to 8 shifts; quotas live in a data file
- Drag-and-drop on top of click-to-place (if it was cut from the prototype)
- Keep the event log and browser build running for every playtest round
- Framework for register upgrades (uses the same scoring hooks as coupons), with 3 placeholder upgrades
- Framework for inspections, with 1 rule
- Deck view, reward rules (controlled pool, at least one generally useful option, skip)
- Save and resume at stable points (planning and reward screens only, never mid-animation)
- Title and results screens (plain)
- **Art style frame:** one complete mock-up of the shift screen in the final style (section 6), to approve the direction before art production starts
- **Balance simulator** (section 8)
- *Done when:* one complete 8-shift run is playable, and the style frame is approved

### Phase 2: Systems and content (about 42 hours)
- About 20 products and 8–10 coupons, designed with the frameworks in section 5
- 8 register upgrades, 3 inspections
- Balance passes with the simulator plus a small playtest
- Check that at least 4 builds are viable (bulk buyer, breakfast special, coupon specialist, clearance collector, plus builds that only coupons make possible)
- *Done when:* all essential systems work, and no single build wins in more than about 40% of simulated optimal runs

### Phase 3: Art, sound and counting presentation (about 42 hours)
- Art production following the approved style frame: background, register, conveyor, card frames, product packaging, coupon designs, upgrade stickers
- Full counting presentation (section 6.2)
- Sound: scanner beep, printer, register rattle, UI sounds, 1–2 music loops
- Final receipt that can be exported as a PNG (if time allows)
- *Done when:* content freeze. The build is a release candidate.

### Phase 4: Onboarding, polish and release (about 34 hours)
- Tutorial shift (a fixed hand, guided, no penalty)
- Settings, accessibility, pause
- Steam integration: achievements, cloud save. Store page, trailer, capsule art.
- Public web demo on itch.io, built with the pipeline from the prototype (a short run, with a link to the Steam page)
- Playtest with 5–8 new players, fix bugs
- *Done when:* a stable build is ready for review and the store page is ready

### After launch, or a stretch goal: Meta progression
- Unlockable starting decks (section 7)
- Unlockable card variants and changes to cards
- More coupons, upgrades and inspections

## 4. Technical architecture

The prototype structure carries over (`core/`, `data/`, `ui/`, `presentation/`, `debug/`, `tests/`). Additions:

```
core/
  upgrade_definition.gd   # Resource: id, name, rules[], sticker art
  inspection_definition.gd# Resource: id, name, rules[], announcement text
  run_state.gd            # + upgrades[], next inspection, run history
  profile_state.gd        # meta: unlocked decks and cards, stats, settings (separate from the run save)
  save_service.gd         # run save + profile save; versioned format; Steam cloud paths
data/
  upgrades/*.tres
  inspections/*.tres
  decks/*.tres            # DeckDefinition: id, name, cards[], unlock condition
tools/
  balance_sim/            # headless simulator (section 8)
platform/
  steam_service.gd        # GodotSteam wrapper; does nothing without Steam (editor, web demo)
```

Rules:
- Products, coupons, upgrades and inspections are **all made of the same `Rule` hooks**. A new idea is a new rule script plus a data file, never a change to the scoring code.
- `score()` stays a pure function. All presentation plays back `ScoreResult.steps`.
- Save files include a format version from the first save. A run save holds the seed, so a run can be rebuilt.
- Tests run headless in CI (GdUnit4 GitHub Action) on every push.

## 5. Design frameworks

### 5.1 Coupons (the core)

Coupons fall into four types. 1.0 has at least 2 of each.

| Type | What it does | Examples |
|---|---|---|
| **Connector** | Changes adjacency | Bundle (the products on either side count as adjacent), Shelf swap (counts as adjacent to the first slot) |
| **Relabeller** | Changes tags | Breakfast sticker, Organic label (the next product becomes Produce), Clearance tag |
| **Amplifier** | Multiplies or copies | Repeat, Multipack, BOGO (the next product pays twice) |
| **Position** | Rewards placement | Final markdown, Opening deal (the first slot ×2) |

Good coupon rules:
- It creates a combination that **did not exist** without it, or it changes the best order of the row.
- Its effect fits in one line of rule text and one icon.
- It has a cost: it takes a slot, or it only works in a certain position.
- No loops: a copy never triggers effects again, and coupons cannot copy coupons.

### 5.2 Register upgrades (designed carefully)

Upgrades last for the whole run and appear as physical stickers and attachments on the register. They are offered after shifts 2, 4 and 6.

Good upgrades:
1. **Change what you draft or how you order cards.** A flat "+N to everything" is not allowed.
2. **Push towards a build without making it mandatory.** Each upgrade states which build it supports.
3. **Have a tradeoff or a condition.** For example "the first coupon pays ×2", but then the first slot must be a coupon.
4. **Use the existing hooks.** If an upgrade needs a new hook, it is a design flag to discuss.
5. **Are visible:** shown on the register and named in the receipt explanation.

| Type | Example |
|---|---|
| Rule bender | Coupons no longer break adjacency |
| Slot engine | The 6th slot ×2, but only for a product |
| Category engine | +3 per category present when the last product is scanned |
| Coupon engine | The first coupon's payout ×2 |
| Economy | +1 redraw per shift · +1 card drawn |
| Risky | One extra slot, but the quota +15% |

Upgrade offers: 3 options, from different types, at least one fitting the current deck.

### 5.3 Inspections
Visible restrictions that test a build. One is announced before the previous shift's reward choice. Never disable several parts of a build at once. Start with: only 5 slots · the 3rd product pays 0 · duplicate payouts capped at 4.

## 6. Art direction and counting presentation

### 6.1 Art pipeline
1. **Style frame (phase 1):** one screen in the final style. Approve it before any other art production.
2. **Art bible:** palette (cream paper, faded teal, tomato red, mustard yellow), outline thickness, shading rules, fonts (expressive packaging lettering · plain sans serif for rules · monospace for the receipt), icon set for tags.
3. **Production rules:** packaging must stay recognisable at slot size. Colour is never the only signal (always an icon or a label too). Brands are fictional.
4. **Open decision:** who makes the art (you, a commissioned artist, a mix)? This affects the budget and phase 3 hours. Decide during phase 1.

### 6.2 Counting presentation (driven by `ScoreResult.steps`)

For each slot:
1. The card lifts onto the scanner → beep
2. The base value pops up on the card
3. Each bonus flies in from the card that causes it (that card is highlighted) → the receipt prints a line
4. Multipliers land like a **stamp** (heavier sound, a bigger line)
5. The payout drops onto the receipt, the subtotal ticks up

Escalation:
- The pitch rises with consecutive bonuses
- The printer speeds up as the total grows; the paper starts to pile up
- Large totals make the register rattle, with a short pause before the final total
- Total vs quota: a clear pass / fail moment

Respecting the player:
- Hold to fast-forward, tap to skip to the result
- Speed settings; reduced motion (no shaking, a calmer count)
- The receipt is always a straight, readable list, even when the paper curls

## 7. Unlockable decks and cards (architecture now, content later)

The data model supports this from the prototype onwards, so adding it later is a content task:

- `DeckDefinition`: id, name, description, card list, starting upgrade (optional), unlock condition
- `CardDefinition.variant_of`: card variants (e.g. "Organic Banana" as a variant of Banana)
- `ProfileState`: unlocked decks, unlocked cards and variants, achievements. Saved separately from the run.
- Unlock conditions are data (`win a run with X`, `score Y in one checkout`, `use coupon Z N times`) and are checked when a run ends

Design rules (from the original doc): **unlocked decks have comparable starting strength**. Unlocks add options, not raw power. No permanent payout increases.

Possible ideas: Breakfast deck (start with Coffee and Milk), Coupon deck (fewer products, 2 starting coupons), Frozen deck (Frozen peas, Soup risk).
Card changes: unlock variants that replace a starting card (e.g. swap 1 Banana for an Organic Banana in the deck setup screen).

## 8. Balance simulator

A command-line tool, run headless, that uses `core/` directly:
- For a given hand, it tries every selection and order (8 choose 6 × 6! ≈ 20,000 rows) and finds the best possible score
- It simulates thousands of seeded runs with simple drafting strategies (greedy, build-focused)
- Outputs: the distribution of best scores per shift (to set quotas), win rate per build, how often each card is in the best row (finds dominant or useless cards)

It doesn't measure fun, only what is possible. Quotas are set so that a sensible but not optimal order passes.

## 9. Testing and quality

- Unit tests: every rule, every coupon, every upgrade and inspection, save and resume, seed reproducibility
- Golden tests: fixed rows with known totals (the doc's 31 / 18 example stays forever)
- Playtest rounds: end of phase 1, middle of phase 2, end of phase 3, phase 4
- Keep a list of the 3 problems that most affect understanding or fun; update it daily

## 10. Risks and what gets cut

| Risk | Response |
|---|---|
| Art takes longer than planned | Fewer unique packaging designs (reuse frames + icons) · simpler background · cut PNG export |
| Coupons create one dominant combination | Simulator + limits (max coupons per row, Repeat can't copy amplified values) |
| Upgrades feel weak or samey | Fewer upgrades (6) that are more distinct, rather than 8 average ones |
| Schedule slips | Cut in this order: meta progression → PNG export → 3rd inspection → product count (to 16) → upgrade count. **Never cut:** the scoring explanation, the counting presentation, bug-fixing time. |
| Confusing rules | Simplify effects before adding content |

Content freeze at the end of phase 3. No new features after that.

## 11. Release

- Price: proposed €3.99–5.99 (to check against similar games)
- Steam store page early (phase 2) to start collecting wishlists
- Web demo on itch.io: a short run, clear link to Steam
- Marketing hook: short clips of ordinary groceries producing an absurdly long receipt
- Track separately: store visits, wishlists, demo starts, tutorial completion, voluntary replays

## 12. Open decisions

- The exact preview vs a less prominent preview (from the prototype)
- 6 slots vs 5
- Immediate loss vs one supervisor warning
- 8 shifts vs a shorter run
- How many products 1.0 really needs
- Who makes the art, and the budget
- Whether meta progression is part of 1.0

## 13. Changelog

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-10-05 | First plan, before the prototype |
| v0.2 | 2026-10-05 | Aligned with prototype plan v0.2: click-to-place first and drag-and-drop in phase 1 if cut, browser build and event log carried over, prototype estimate 18–24 hours |
