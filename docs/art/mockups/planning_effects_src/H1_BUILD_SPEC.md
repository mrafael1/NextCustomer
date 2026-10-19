# #71 planning effects: Godot build spec for mock-up h1

Approved by the user on 2026-10-18 ("H1 is perfect"): `docs/art/mockups/planning_effects_h1.html`, `planning_effects_h1_hover.html` and their 1920x1080 captures. The generator is `planning_effects_src/gen_h1/` (`gen_h1.py`, `overlay.js`, `overlay.css`). Rejected: h2's pipes, A's ribbons, and the first build's floating chip band.

**Amendment after the user's play test of the h1 build (2026-10-19).** Two changes, marked "(amended)" below:
1. **Stickers only for factors.** The rail strips no longer carry factor badges ("×3", "+3"), calm or hot: the factor shows only as the sticker on the target. A strip still shows its body, its giver's name plate, its chevrons, and at each target the notch (lane 0) or the plain ink drop (lane 1) onto the ticket, so it still says which items it reaches; the chevrons break over each target's notch instead of around a badge. Hot strips keep their gain badges ("+€14"), now standing on the target where the factor badge was (5.1).
2. **PROJECTED by the quota.** The planning receipt's PROJECTED amount is green (`Palette.GOOD`) with the met mark (the belt's `mark_check` disc in the mark column) when the shown total reaches the shift's quota (exactly on it too), and red (`Palette.TOMATO`) under it, with the shortfall ("short €12.00") on its own row under it, above the fizzle footer (on the fizzle line itself it pushed the hint off the 1280x720 stub), so colour is never the only signal (8.2).

This spec replaces the first build's look (the chip band, pips, gives and gets tabs and frames, and the top-bar badges) with h1. It keeps the first build's data path and behaviour. Every number below is in **stage pixels at 1280x720** unless it says otherwise. 1 art texel = 2 stage px (`ArtStyle.ART_SCALE`). The mock-up's values (€10, ×3, +12) are invented. The game shows the real `ScoreResult` steps.

Rules that hold for every step: the UI never scores (it uses only steps, payouts and totals from `RunState.preview`, through `EffectGraph`); everything is statically typed; gdlint and gdformat are clean; every colour is a `Palette` constant from `art/src/palette.txt`; new art is a text source in `art/src/effects/`, built with `python tools/pixel_art.py build` and then `sh tools/import.sh`, gets a row in `art/src/production_log.tsv`, uses only palette keys, has 2 px ink outlines and light from the upper left; the sharp-pixel material goes on art only, never on text. Godot runs only through the repo scripts.

---

## 0. Verified facts this spec builds on

| Fact | Where |
|---|---|
| Stage is 1280x720 and never scales; row cell `ItemView.BELT_SIZE` 116x232 at `ShiftStage.ROW_POSITION` (364, 258); pitch 128 (`RowStrip.SEPARATION` 12) | `ui/shift_stage.gd`, `ui/row_strip.gd` |
| Cell k (0-based) left edge `C(k) = 364 + 128k`. Sprite 96x96 at cell (10, 28) → stage y 286..382; ground line y **382** (`BELT_GROUND_Y` 124) | `ui/item_view.gd` |
| Ticket (`PriceSticker`, 108x64) at cell (4, 166) → `T(k) = C(k) + 4`, stage y **424..488**; tickets 20 px apart; base label rect (8, 6, 74, 24), aisle glyph (84, 8, 18, 18), summary (6, 28, 96, 34) in ticket coords | `ui/price_sticker.gd` |
| Belt at (348, 314): top face y 326..400, **lip y 400..414** (x 348..1266), apron 414..422, rail 422..490 | `ui/belt_panel.gd` (`LIP`, `APRON`, `RAIL`) |
| Contact shadow `BELT_SHADOW` (18, −10, 74, 14) from the ground → y 372..386 | `ui/item_view.gd` |
| Monitor drawn rect (484, 56, 424, 192) → bottom y **248**; channel content `MonitorView.CONTENT_RECT` (505, 85, 382, 138); `MonitorChannel.SLIDE_HEIGHT` 124, dots at y 130 | `ui/monitor_view.gd`, `ui/monitor_channel.gd` |
| 8 and 9 slots: `WIDE_SEPARATION` 0, then the box scales to the 7-slot width (×0.95 / ×0.85); CLOSED cells come after the open ones and are never drop targets | `ui/row_strip.gd` |
| Mock-up vs game: the mock's `SL(k) = 368 + 128(k−1)` equals `T(k)`. The mock's ground is 388 (game 382), its ticket top 428 (game 424), its strip 396..412 (game lip 400..414), its ticket 112 wide (game 108). Use the game's values. | `gen_h1/overlay.js` |
| Palette has no white: the mock's `#ffffff` becomes `w` (paper). It has no alpha keys, so shadows are code-drawn ink at an alpha (precedent: `RowStrip.TICKET_SHADOW_ALPHA` 0.38) | `art/src/palette.txt`, `tools/pixel_art.py` |
| `Palette.GOLD` is the v2 gold `ffcf3f`. h1's "gold" is the **mustard ramp** (`M e2b33c`). `Palette` lacks mustard dark `b38425` and mustard darkest `7a5a1c` | `ui/palette.gd` |
| Products with drawn sprites: 10 of about 50 (`art/items_v2`). Coupon icons: 2 (multipack, two_for_one). Upgrade perk icons: none (initials until #59) | `art/` |
| `ScoreStep.multiplies` (first build) is read only by the first build's pip | grep |
| `shift_screen_b2_mirrored.html` (the generators' base) is on `origin/main` (commit 7bc6e0e, PR #84), **not** on this branch | git |

---

## 1. Colour map (mock-up → palette)

| Mock-up | Use | Palette key / `Palette` constant |
|---|---|---|
| `#e2b33c` GOLD | burst fill, hot strip fill, halo band | `M` / `MUSTARD` |
| `#f1d27a` GOLD_L | burst highlight, calm strip lit row, halo band | `y` / `MUSTARD_LIGHT` |
| `#faecbc` GOLD_P | hot strip lit row, calm name text, halo band, hot ring | `Y` / `MUSTARD_PALE` |
| `#b8892a` GOLD_D | calm strip fill, burst shade, hot strip shade | `m` / **new** `MUSTARD_DARK` (`b38425`) |
| `#8e6a1a` GOLD_DD | calm strip shade | `l` / `BRASS_DARK` (`8a5d1a`) |
| `#6e5214` chevrons, `#7a5a10` gain text | calm chevrons, gain text | `u` / **new** `MUSTARD_DARKEST` (`7a5a1c`) |
| `#fbf7ee` / `#ffffff` / `#ddcba5` | cream sticker fill / lit / shade | `w` / `w` / `b` (`PAPER`, `CREAM_SHADE`) |
| `#c2beb4` / `#dcd8ce` / `#9a968d`, text `#4a4640` | grey "pfff" sticker | `B` / `A` / `C` (`STEEL_LIGHT`, `STEEL_HIGHLIGHT`, `STEEL_PALE`), text `%` `INK_LIGHT` |
| `#a83a3c`, fill `rgba(paper, .88)` | stamp rings and text, stamp face | `r` `TOMATO_DARK`, `w` opaque |
| `#d9534f` / `#ec7d75` / `#a83a3c` | €0 tag fill / lit / shade | `R` / `o` / `r` |
| `.label.got` `#f6dd8f` + mustard band | a target ticket's face while hovered | `y` face, `M` band (new frame) |
| `.label.sel` 2 px `#faecbc`, 2 px `#e2b33c`, 2 px ink | hovered giver's ticket ring | `MUSTARD_PALE`, `MUSTARD`, `INK` |
| halo h1: `y`+ink; h2: `Y`,`M`+ink; h3: `w`,`y`,`M`+ink | halo bands, inside out | as listed |
| shadows `rgba(30,18,10,.42)` / `rgba(20,12,8,.5)` | sticker, burst, badge, strip shadows | `Color(Palette.INK, 0.42)` / `Color(Palette.INK, 0.5)` |
| copy sticker (new, not in the mock-up) | "=€6" label | `6` teal pale face, `5` teal light shade |

Add to `ui/palette.gd`: `MUSTARD_DARK := Color("b38425")` and `MUSTARD_DARKEST := Color("7a5a1c")`. Add `TEAL_PALE := Color("c3e0d4")` only if code draws it.

---

## 2. What each slot shows (presentation model)

All of this comes from one `EffectGraph` (kept) built from `ScoreResult.steps`, plus `result.payouts[slot]` and `definition.base`.

### 2.1 Stickers (what the item receives)

There is one sticker per incoming link in **step order** (= apply order). The first applied is at the top and the last at the bottom, nearest the ticket, so the column reads as a sum and the ticket is its total.

| Link (EffectLink.Kind) | Sticker | Text | Badge |
|---|---|---|---|
| BONUS (FLAT) | cream price-gun label | `"+%d"` | none if `own`; otherwise the cause's badge |
| STAMP (MULTIPLIER) | gold starburst | `"×%d"` | same |
| COPY | teal label | `"=€%d"` | the copied card (`cause_slot = linked_slot`) |
| FIZZLE (WASTED) | grey label | `"pfff"` | none if own; else the upgrade, or the resetting card |
| DENIED (PAYOUT_OVERRIDE) | no sticker: the **stamp** (2.4) | | |
| ARMED | no sticker and no pip: the **rail strip** (section 5) shows what lands | | |

Repeated fizzles: one "pfff" per distinct (cause kind, cause slot or index, step text), so a run of unused charges shows once. An item that is denied keeps its stickers, drawn **drained** (4.4) under the stamp. A sticker's diff key for the slap animation is `"%d|%d|%d|%s" % [cause_kind, cause_slot, cause_index, text]` plus the card instance.

### 2.2 Pay on the ticket (`PlanningModel.Pay`)

| State | When (`p` = payout, `b` = base) | Ticket |
|---|---|---|
| PLAIN | `p == b`, or a coupon with `p == 0` and no fizzle or denial on it | nothing |
| BOOSTED | `p > b`, not denied | base struck through + gold **pay burst** `"€%d" % p` |
| LOWERED | `0 < p < b` | base struck through + cream **plain tag** `"€%d" % p` |
| DENIED | a DENIED link has made `p == 0` | base struck through (a product) + tomato **€0 tag**: the `warning` glyph for an inspection's denial, the paper fizzle glyph for a card's own (Soup) |
| ZERO | `p == 0` and some FIZZLE link is on the slot (e.g. Multipack under Coupon engine) | tomato €0 tag with the paper fizzle glyph (a coupon's "COUPON" is never struck) |

The pay text is `"€%d"`. A coupon's title "COUPON" is never struck.

### 2.3 Halo and lift

- **Boosted** means Pay is BOOSTED. A boosted item's sprite stands **6 px raised** (`ItemView.BOOST_LIFT := 6.0`) on the lifted contact shadow (`BELT_LIFTED_SHADOW`, which already exists).
- Ring count is 1. It becomes 2 when `p >= max(b, 1) * halo_ratios[0]` and 3 when `p >= max(b, 1) * halo_ratios[1]`. The ratios live in data: `halo_ratios = [5, 20]` (section 3.4). This is h1's "1 ring, 2 at ×5 of base, 3 at ×20". The integer comparison is display only.
- A 3-ring item also gets 2 static **sparkles** at sprite-rect offsets (2, 14) and (76, −24), snapped to 2 px. They are decor and never loop.

### 2.4 Denied stamp

For a DENIED link: the stamp's big line is `"€%d" % link.value` and its caption is the cause's name in uppercase (`InspectionDefinition.display_name` for an inspection, or the card's `display_name` for its own override, e.g. "SOUP"). The sprite turns **grey** (desaturated, 4.4) only when the value is 0.

### 2.5 Giver badges (every possible giver, with no per-card art)

**Decision:** a badge is a **kind token** with the giver's **initials** in it. This covers every product, coupon and upgrade with no new per-card art. It reuses the existing initials convention the loyalty boxes already use (`LoyaltyCard.initials`), so an upgrade's badge reads exactly like its box. Per-item sprites are not used: 40 of about 50 products are still art-pending, and a 48 px sprite at badge size is mush. When #59's perk glyphs land, the LOYALTY token shows the glyph instead of the initials (one branch in `GiverBadge`). The badge's job is "from an item / a coupon / loyalty". The exact giver is named by the rail strip (items and coupons) and by the box ring on hover (upgrades).

| Giver | Token (art, 9x9 texels at 2x = 18x18) | Content |
|---|---|---|
| product (`CardDefinition.is_product()`) | `effects/badge_item`: round, `c` face, `w` lit top-left, `b` shade, ink rim | first 2 letters of the display name (`"Eg"`, `"Mi"`), ink |
| coupon | `effects/badge_coupon`: rounded square, `3` teal-shade face with a `5` dashed inner edge (the coupon ticket's dashes), ink rim | 2 letters, paper |
| upgrade | `effects/badge_stamp`: a mini stamp ring (`M` ring, `y` lit, `2` teal-dark panel), ink rim | `LoyaltyCard.initials(name)` capped at 3 chars, `MUSTARD_PALE` |
| inspection (only if an inspection ever adds a FLAT, MULTIPLIER or WASTED step; today it only stamps) | existing `art/icons/warning.png` at 2x (26x22) | none |

Initials font: Pixelify (`UiKit.display_label`), the largest of [9, 8, 7] px whose width fits 12 px. The badge hangs off the sticker's left edge (6.2).

---

## 3. New and changed code: classes and public API

### 3.1 Kept from the first build (unchanged or nearly)

- `presentation/effect_links.gd` (the matcher; `count_up_plan.gd` and `effect_tokens.gd` use it, and keep that).
- `presentation/effect_graph.gd`, `effect_link.gd`: keep. **Add** `EffectLink.gain: int` (FLAT, MULTIPLIER and COPY: `step.value_after` minus the previous value-carrying step's `value_after` on that slot (BASE, FLAT, MULTIPLIER, COPY or PAYOUT_OVERRIDE); otherwise 0) and `EffectLink.cancelled: bool` (a later PAYOUT_OVERRIDE on the same slot). Both are read from steps and score nothing. **Remove** `EffectLink.multiplies` and its use.
- `RunState.preview(card, slot)` and `tests/core/run_state_preview_test.gd`.
- `CardDrag.landing_changed`, `CardDrag.ghost()`.
- `QuotaMeter.show_hypothetical` / `shown_text` / delta slot ("› €52 (+6)").
- `LoyaltyCard.box_hovered/box_unhovered/set_relation/has_relation` and `InspectionTag.hovered/unhovered/set_relation/has_relation` (rings, and naming the inspection while ringed).
- `BeltChips`: no corner marks in planning (first build), unchanged.
- `ShiftScreen` wiring: `_effects.clear()` at the CHECKOUT click, `show_all` in `_show_belt` when not `paid`, `preview` Callable, `reduced_motion`.
- The hover logic in `PlanningEffects`: focus at once on enter; `UNFOCUS_DELAY` 0.08 s; `_pointer_on_focus` keeps focus across a refresh; `_blocked()` while not shown, dragging or landing; focus is put back after `show_all`.

### 3.2 Deleted

- `ui/chip_band.gd` and its `.uid`; `ItemView.chip_band`, `BELT_CHIP_BAND`, `GHOST_CHIP_BAND`, `DENIED_GREY`, `FIZZLED_ALPHA`, `effect_tint`, `effect_tint_for`, `RELATION_LINE/DASH/DASH_GAP`, `SOURCE_TAB`, `TARGET_TAB`, `TAB_SIZE`, `TAB_PADDING`, `_relation_tab`, `_make_tab`, `_draw_dashed`, `Relation.SOURCE/TARGET`.
- `PlanningEffects.chips/chip/pip/_rank/_paint/_pop_new/chips_for/inspection_hits`, `PIP_TEXT`, `MULTIPLIED`, `ADDED`, the `STAMP_RING`/`WARNING`/`FIZZLE` preloads that were used for chips, and `_texts`.
- `EffectMarker`: restore the file to its HEAD content (Tone, `set_icon`, `icon_texture`, `set_text`, `set_tone`, `tone`, `pop`, `QUIET_BORDER`, `PLANNING_MARGIN`, `POP_*` were planning only; grep first). Delete `tests/presentation/effect_marker_test.gd`.
- `InspectionTag.set_hits/hits_text/HITS_*/_hits` and `LoyaltyCard.set_fizzled/is_fizzled/FIZZLE_*` plus the corner node. h1's top bar shows neither; the stickers and stamps carry it.
- `ScoreStep.multiplies`, `ScoreEffect.multiplies()` and its 3 overrides, the `ScoreState.add_effect` line, and the contract test `test_armed_steps_say_whether_they_multiply`: restore the 6 core files and `tests/core/score_step_contract_test.gd` to HEAD. Nothing uses them once pips are gone, and `core/` goes back to only `RunState.preview`. Revert the PROTOTYPE_PLAN section 4 sentence about `multiplies` (step E).
- `tests/ui/item_view_effects_test.gd` (replaced by `tests/ui/item_view_planning_test.gd`).

### 3.3 New presentation model (pure, no Node)

`presentation/planning_model.gd`, `class_name PlanningModel extends RefCounted`
```gdscript
enum Pay { PLAIN, BOOSTED, LOWERED, DENIED, ZERO }
enum Glyph { NONE, FIZZLE, WARNING }
var graph: EffectGraph
var slots: Array[PlanningSlot] = []
var strips: Array[RailStripSpec] = []
static func build(result: ScoreResult, row: Array[CardDefinition],
		upgrades: Array[UpgradeDefinition], inspections: Array[InspectionDefinition],
		tuning: PlanningTuning) -> PlanningModel
static func assign_lanes(strips: Array[RailStripSpec]) -> void   # section 5.2
func key_entries() -> Array[StickerSpec]                          # section 7
func related(slot: int) -> PackedInt32Array                       # focus set, section 8
```
`presentation/planning_slot.gd`, `class_name PlanningSlot extends RefCounted`: `stickers: Array[StickerSpec]`, `pay: PlanningModel.Pay`, `pay_text: String`, `glyph: PlanningModel.Glyph`, `struck: bool`, `rings: int` (0..3), `denied: bool` (grey sprite), `stamp_amount: String`, `stamp_caption: String` (both empty when no stamp).

`presentation/sticker_spec.gd`, `class_name StickerSpec extends RefCounted`: `enum Kind { ADD, MULTIPLY, COPY, FIZZLE, MORE }`, `kind`, `text`, `badge: GiverBadge.Kind`, `badge_text`, `cause_kind: ScoreStep.SourceKind`, `cause_slot`, `cause_index`, `step_index`, `key() -> String`.

`presentation/rail_strip_spec.gd`, `class_name RailStripSpec extends RefCounted`: `giver_slot`, `name` (uppercase display name), `targets: PackedInt32Array` (ascending; for a backward strip, descending), `tokens: PackedStringArray` (one per target: the link tokens to that target joined by a space, e.g. `"+2 ×2"`), `gains: PackedInt32Array` (summed `gain` per target, −1 when `cancelled`), `lane: int` (0, 1, or −1 for overflow), `backward: bool`, `lo()`/`hi()` (the span in slots).

### 3.4 Tuning in data

`ui/planning_tuning.gd`, `class_name PlanningTuning extends Resource`, modelled on `ScanTuning`. Script defaults are neutral (0 / empty), and the values live in **`data/balance/planning.tres`**, loaded by `PlanningEffects.TUNING_PATH := "res://data/balance/planning.tres"`.

| Field | Value |
|---|---|
| `halo_ratios: PackedInt32Array` | `[5, 20]` |
| `focus_fade_s: float` | 0.12 |
| `unfocus_delay_s: float` | 0.08 (replaces the `UNFOCUS_DELAY` const) |
| `dim_item_alpha: float` | 0.4 (sprite of an unrelated item) |
| `dim_ticket_alpha: float` | 0.45 (its ticket and pay tag) |
| `dim_strip_alpha: float` | 0.3 |
| `slap_frame_s: float` | 0.04 (the sticker squash's frame) |
| `halo_step_s: float` | 0.08 (one ring per step) |

Geometry stays in code constants, as everywhere else in `ui/`.

### 3.5 New UI controls (each decor only: `MOUSE_FILTER_IGNORE`)

| File, class | Public API | Notes |
|---|---|---|
| `ui/giver_badge.gd` `GiverBadge extends Control` | `enum Kind { NONE, ITEM, COUPON, LOYALTY, INSPECTION }`; `_init(kind, initials)`; `static func initials_for(kind, name) -> String`; `set_drained(bool)` | 18x18 (inspection 26x22) |
| `ui/effect_sticker.gd` `EffectSticker extends Control` | `_init(spec: StickerSpec, tilt_deg: float)`; `spec()`; `set_drained(bool)`; `is_drained()`; `slap(reduced_motion: bool)`; `text_rect() -> Rect2` | the frame (9-slice or burst) rotated by `tilt_deg` about its centre; the Label stays upright; a shadow copy at (+2, +2) in `Color(INK, 0.42)`; the badge child at the left |
| `ui/pay_tag.gd` `PayTag extends Control` | `_init(pay, text, glyph)`; `set_dimmed(bool)`; `static func size_for(pay, text) -> Vector2` | burst, wide burst, €0 tag, plain tag |
| `ui/deny_stamp.gd` `DenyStamp extends Control` | `_init(amount, caption)`; `set_drained(bool)` | 96x68; labels rotated −9° |
| `ui/rail_strip.gd` `RailStrip extends Control` | `_init(spec: RailStripSpec)`; `lay_out(anchors: Dictionary[int, Rect2], lane_rect: Rect2, gap_fill: bool)`; `set_hot(hot: bool, gain_target: int = -1)` (−1 = all targets' gains); `set_dimmed(bool)`; `step_chevrons(reduced_motion: bool)`; `body_rect()`, `target_centres()` (amended: was `badge_rects()`), `gains()`, `parts_rect()` | section 5 |
| `ui/planning_layer.gd` `PlanningLayer extends Control` | `show_model(model, items: Array[ItemView], ghost: ItemView = null)`; `show_strips(visible: bool)`; `apply_focus(lit_causes: Callable, related: PackedInt32Array, hot_strips: Dictionary[int, int], fade_s: float)`; `clear()`; `stack(slot) -> Array[EffectSticker]`; `pay_tag(slot) -> PayTag`; `stamp(slot) -> DenyStamp`; `strips() -> Array[RailStrip]`; `static func stack_ceiling(stack_rect: Rect2) -> float`; constants in sections 4 to 6 | one per stage, size `ShiftStage.SIZE` |

### 3.6 Changed classes

- **`ShiftStage`**: new `var planning_layer: PlanningLayer`, built in `_build_belt` right after the belt is added (child order: monitor, register, receipt, belt, **planning layer**, top bar, counter, scan layers). So it draws over the items and tickets, under the top bar, the hand, the scan brackets and the drag ghost (CardDrag's overlay, `z_index` 10).
- **`ItemView`**:
  - `enum Relation { NONE, FOCUS, RELATED, DIM }`. FOCUS: the existing gold brackets. RELATED: no frame. DIM: `_stand.modulate.a` becomes `dim_item_alpha` and `_sticker.modulate.a` becomes `dim_ticket_alpha`, over `relation_fade`.
  - `const BOOST_LIFT := 6.0`. `set_boost(rings: int, reduced_motion: bool)`: shows the `ItemHalo` (4.3) and lifts. `body.position.y = -(BOOST_LIFT if boosted else 0) - (LIFT if _is_up() else 0)`. The shadow uses the lifted variant when boosted or up.
  - `set_denied(denied: bool)`: the sprite's material becomes `ArtStyle.grey_material(ArtStyle.Grey.DENIED)`, and goes back to `pixel_material()` when not denied.
  - `boost_rings() -> int`, `is_denied() -> bool`.
  - `hit_rect()` includes the raised sprite. `RowStrip.DROP_TOP := ItemView.BELT_SPRITE.y - ItemView.LIFT - ItemView.BOOST_LIFT`.
  - The count-up never sees a boost or grey: `PlanningEffects.clear()` resets both before `begin_count`.
- **`PriceSticker`**:
  - `set_pay(struck: bool, tag_rect: Rect2)` (ticket coords; empty rect = no tag). When struck, the base label is `INK_LIGHT` with a 2 px `INK` line across its text (from 3 px left of the text to 3 px right of it, at the text's vertical centre). The aisle glyph moves to `base_text_end + 4` and hides when its 18x18 rect would touch `tag_rect` grown by 2.
  - `set_got(got: bool)`: swaps the face to `effects/ticket_got` (hover target).
  - `base_text_rect() -> Rect2`, `summary_text_rect() -> Rect2` (for the tests).
- **`ArtStyle`**:
  - `enum Grey { DENIED, DRAINED }`; `static func grey_material(look) -> ShaderMaterial` (two shared materials of the new `presentation/pixel_art_grey.gdshader`: pixel_art plus luminance desaturation, with brightness and contrast uniforms. DENIED: brightness 0.78, contrast 0.9. DRAINED: brightness 0.62, contrast 0.55, the mock's `.dim` and `.denied`); `static func halo_material(rings: int) -> ShaderMaterial` (three shared materials, 4.3).
  - `set_sharp` keeps a node's grey or halo material (meta `&"pixel_art_look"`) instead of resetting it to `pixel_material()`.
- **`PlanningEffects`** (the controller; same file):
  - `setup(loyalty, tag, quota_meter, drag, layer: PlanningLayer, receipt: ReceiptView, monitor: MonitorView)`.
  - `show_all(result: ScoreResult, views: Array[CardView], run: RunState)`, which takes upgrades, inspections and quota from `run`.
  - `show_hypothetical(model, views, ghost, landing)`, `focus_card`, `focus_upgrade`, `focus_inspection`, `unfocus`, `clear`, `committed_model() -> PlanningModel` (replaces `committed_graph`), `focused_card`.
  - `tuning: PlanningTuning`.
- **`MonitorChannel`**: `set_key(entries: Array[StickerSpec])`; `key_texts() -> PackedStringArray` (tests). **`MonitorView.set_planning_key(entries)`** forwards to it.
- **`ScanController` / scan footer**: a belt giver's scan gets a **gives line** first (section 8.3).
- **`ReceiptView`** (planning only):
  - `show_relations(focus_slot: int, tokens: Dictionary[int, String])` and `clear_relations()`.
  - New `PlanMark.DENIED` (the `warning` icon) for an item denied by an inspection.
  - `set_footer_hint(text: String)`: the hint after "N fizzles · ". Default "hover an item". While an item is focused, "<Name> hovered".
- **`InspectionTag`, `LoyaltyCard`**: only the deletions in 3.2. Rings unchanged (`Palette.GOLD` 2 px).

---

## 4. Item-level look

### 4.1 Stickers (EffectSticker)

| Kind | Art | Display size | Text |
|---|---|---|---|
| ADD | `effects/sticker_label` 9-slice, margin 3 texels, `@scale 2` | h 28; w 46 for ≤2 chars, 54 for 3, else `text_w + 16` snapped to 2 | `ArtStyle.number_font()` 21 px, `INK` |
| MULTIPLY | `effects/sticker_burst` icon 31x17 (18-point burst from the mock's formula: radius `.84 + .16·|k−.5|·2` on a superellipse; fill `M`, lit `y` on the upper-left inner edge, shade `m`, ink rim) | 62x34 | 22 px `INK`; shrinks to 18 px for 4+ chars |
| COPY | `effects/sticker_label_teal` 9-slice (`6` face, `5` shade) | as ADD | 21 px `INK` |
| FIZZLE | `effects/sticker_label_grey` 9-slice (`B` face, `A` lit, `C` shade) | 60x28 | 15 px `INK_LIGHT`, 6 px left padding |
| MORE (fold) | the grey 9-slice | as ADD | `"…+%d"` 15 px `INK_LIGHT` |

- The shadow is the frame texture again at (+2, +2), modulated `Color(INK, 0.42)`.
- Tilt: the frame rotates `STICKER_TILTS := [-4.0, 3.0, -3.0, 4.0, -2.0]` degrees by stack index (mod 5), so the sharp shader keeps the texels hard. The Label stays upright and centred.
- The badge hangs left: x = −8 (MULTIPLY) or −14 (others), vertically centred, snapped to 2 px, `z` above the frame.

### 4.2 Stack placement, order and height (PlanningLayer)

- Anchor (natural 7-slot row, stage px):
  - left `x = C(k) + 72`, plus 4 for an odd stack index (the "slapped" nudge). On a scaled row, use `cell_global.x + 72·s`.
  - Bottom of the lowest sticker: `STACK_BOTTOM_Y := 374` (= ground 382 − `BOOST_LIFT` − 2). It is the same for every row size, because the belt doesn't scale.
- Order: index 0 (first applied) at the top. The last applied is at the bottom, with the highest z, so lower stickers overlap the one above (the mock's `zIndex 7 + idx`).
- Pitch: each sticker overlaps the one above by `STACK_OVERLAP := 6`.
- **Max height rule:** the ceiling is `MonitorView.DRAWN_RECT.end.y + 2 = 250` when the stack's x-range (badges included) overlaps the monitor's x-range 484..908 (in a 7-slot row that is slots 1 to 4, which are 0..3), else `ShiftStage.TOP_BAR_BOTTOM + 8 = 64`. If the stack is too tall, the overlap grows in 2 px steps up to `STACK_OVERLAP_MAX := 14`. If it is still too tall, the **earliest** stickers fold into one MORE sticker at the top (`"…+N"`), so the last-applied ones stay readable. Stickers never go under the ticket. Stacks never cover the lip lanes (`bottom 374 < lane 2 top 386`) or the monitor, and never go above the top bar's foot. A big late-game stack is welcome: it climbs the back wall.
- Over the ghost (drag): the same stack in ghost coordinates, as a child of the ghost (not scaled or tilted with `body`). Its bottom is the ghost sprite's bottom − 2 and its left is x 62.

### 4.3 Halo (shader, not sprite rings)

The **`ItemHalo`** is a `TextureRect` child of `body`, behind the sprite. It uses the sprite's texture, sits at the sprite rect grown by `(rings + 1) · 2` px on every side, and has `ArtStyle.halo_material(rings)`.

**`presentation/halo_outline.gdshader`**, `canvas_item`:
- Uniforms: `int rings`, `vec4 bands[4]`.
- It maps UV onto the enlarged grid `texel = floor(UV · (tex + 2m)) − m` with `m = rings + 1`, and finds the minimum **L1 (4-neighbour) distance** to an opaque texel (alpha > 0.5) up to `m`.
- Distance 0 is transparent (the sprite draws on top). Distance 1..rings takes band colour i: rings 1 → `[y]`; rings 2 → `[Y, M]`; rings 3 → `[w, y, M]`. Distance `m` is `INK`. Anything further is discarded.
- This reproduces the mock's chained CSS `drop-shadow` dilations (stepped diamond corners, 2 px per ring) exactly and stays on the texel grid. No new art.
- Motion: rings step out one per `halo_step_s` (set `rings` 1→N). Under reduced motion, show N at once.

### 4.4 Denied, drained and dimmed

- **Denied item:** grey sprite (`Grey.DENIED`), its stickers drained, and the **DenyStamp** over it. The stamp's top-left is the sprite rect's top-left + (2, 26), and its size is 96x68 (texels 48x34).
  - Art: `effects/deny_stamp` 48x34. A tilted (−9°) rounded rectangle on the texel grid with a 1-texel `r` ring, a 1-texel gap, and a second `r` ring 2 texels in on the long sides (the mock's formula). Face `w`, ink-free (it is a rubber stamp, the one item without an ink outline: say so in the source comment). Transparent corners.
  - Text: `"€0"` in Atkinson 800 (`ArtStyle.bold_font(800)`) 28 px, and the caption in Pixelify 11 px with spacing 1, both `TOMATO_DARK`. They form one VBox rotated −9° about the stamp's centre, the big line over the caption, gap 1. A caption wider than 70 px shrinks to 10, then 9 px, then ellipsises.
- **Drained** (unrelated while hovering, or on a denied item): the sticker's frame, shadow and badge use `Grey.DRAINED` and its label `GREY_DARK`. They stay opaque, because a see-through sticker would ghost over the art.
- **Dimmed** (hover; section 8): the item's sprite and ticket alphas from the tuning; its pay tag `dim_ticket_alpha`.

### 4.5 Ticket pay (PayTag on the layer, strike on PriceSticker)

| Pay | Art | Size | Top-left (ticket rect `t`) | Text |
|---|---|---|---|---|
| BOOSTED, text ≤ 3 chars | `effects/pay_burst` 30x16 (12-point burst, fill `M`, inner `y` highlight, shade `m`, ink rim) | 60x32 | `(t.end.x + 6 − 60, t.y − 6)` | number font 19 px `INK` |
| BOOSTED, 4+ chars | `effects/pay_burst_wide` 40x18 (16 points) | 80x36 | `(t.end.x + 6 − 80, t.y − 10)` | 20 px, shrinking to 16 px to fit `w − 16` |
| DENIED / ZERO | `effects/pay_zero` 26x13 (octagon with 2-texel cut corners, `R` fill, `o` top row, `r` bottom row, ink rim) | 52x26 | `(t.end.x + 4 − 52, t.y − 4)` | glyph at (6, 6): `effects/fizzle_paper` 7x7 (paper spark, ink stroke) or `art/icons/warning.png`; `"€0"` 17 px `PAPER` at x 18 |
| LOWERED | `effects/pay_plain` 26x13 (cream octagon, `w`, `b` shade, ink rim) | 52x26 | as above | `"€%d"` 17 px `INK` |

- Shadow: the same texture at (+3, +3) in `Color(INK, 0.42)`.
- **Never over the ticket text:** the tag's bottom is at most `t.y + 26` (the summary starts at `t.y + 28`). Its left edge is `max(natural_left, t.x + base_text_end + 4)`. If that pushes its right edge past `t.end.x + 16`, the base label drops to 18 px (`BASE_STRUCK_SIZE`) and the tag is placed again.
- On a scaled row (8 or 9 slots) the overhang is 0 (`t.end.x − w`), because the tickets are only ~7 px apart. Art sizes never scale.

---

## 5. Rail strips (who gives what to whom)

### 5.1 Geometry (natural row, stage px)

| Part | Lane 0 (primary) | Lane 1 (second) |
|---|---|---|
| Body (`LANE_RECTS`) | `Rect2(348, 400, 918, 14)`: the lip | `Rect2(348, 386, 918, 14)`: the top face's front edge, under the contact shadows (372..386) |
| Plug | ink block `(x0−2, top−2, 12, 18)`; lit pip `4x8` at `(x0+2, top+3)` (`y` calm, `Y` hot) | same |
| Stem to the giver's ticket | `INK` 6 px wide from `body.end.y + 2` to 424, with a 2 px fill centre (`MUSTARD_DARK` calm, `MUSTARD` hot) | same, crossing lane 0 over it |
| `x0` | `T(giver) + 6` | same |
| Name plate | `INK` from `x0` to `nameEnd = x0 + 14 + text_w + 6` (snapped to 2), then a 2 px `y`/`Y` divider; name in Pixelify 13 px (`ArtStyle.spaced_display_font(1)`), `MUSTARD_PALE` calm, `PAPER` hot, at `(x0 + 14, top)`. If it doesn't fit before the first target's room (`bx − 20`) − 4, it truncates with "…" | same |
| Target per target (amended: no factor badge) | centre `bx = T(t) + 26`, where the notch drops and the hot gain stands; nothing drawn on the body | centre `bx = T(t) + 84` (the target's right half, so two lanes' targets never meet) |
| Notch | ink trapezoid `(bx−8, body.end.y+2)`, `(bx+8, …)` down to `(bx±1, 424)`, with a lit triangle (`y`/`Y`) `(bx±4, body.end.y+2)` to `(bx, body.end.y+6)` | none: a 4 px ink drop from under the body to the ticket |
| End cap | at `x1 = last bx + 28` (lane 1: `+ 28` from its own bx), a pointed 8 px cap (`effects/rail_cap`, `rail_cap_hot`), flipped for a backward strip | same |
| Chevrons | `effects/rail_chevron` (`u`) / `rail_chevron_hot` (`m`), 3x5 texels, every 16 px from `nameEnd + 8` to `x1 − 12`, skipping `[bx − 16, bx + 10]` over each target's notch (amended: was `[bx − 30, bx + 26]` round a badge), pointing from giver to targets | same |
| Gap fills | for each ticket gap the strip spans (between `T(k)+108` and `T(k+1)`): `effects/rail_gap` / `rail_gap_hot` vertical 9-slice, x `T(k) + 112`, w 12, y 424..488; hot adds three 4x4 `MUSTARD_PALE` pips at y 436, 452, 468 | lane 1 strips draw no gap fills (only lane 0's do) |
| Shadow | `Color(INK, 0.5)` rect at (+2, +2) under the body | same |
| Hot ring | `INK` rect grown 6, then `MUSTARD_PALE` grown 4, under the body | (a hot strip is always drawn in lane 0: 5.3) |
| Gain badge (hot only) | `"+€%d"` centred on `bx` (amended: was after the factor badge, at `bx + 26`), `y = top − 7` (lane 1 `top − 3`), h 22, paper face, 2 px ink border, number font 14 px `MUSTARD_DARKEST`; where that meets another hot strip's gain, the strip's own name plate or the belt's end, its near edge 6 px past `bx` (after, then before); none for a target whose gain is −1 (cancelled by a denial), and none where no place is clear | same |

- Body: `effects/rail_strip` (calm: rows ink, `M`, `m`, `m`, `m`, `l`, ink) or `rail_strip_hot` (ink, `Y`, `M`, `M`, `M`, `m`, ink), as a horizontal 9-slice 6x7 texels at `@scale 2` (14 px tall), plus a 2 px ink border.
- Gain badges: a `PAPER` `StyleBoxFlat`, a 2 px `INK` border, no corner radius, and a shadow of 2 px `Color(INK, 0.45)` at (2, 2). (Amended: the factor badges are gone.)
- On a scaled row: offsets 6, 26 and 84 times `s`, snapped to 2. Gap fills are skipped when the ticket gap is < 12 px (always, at 8 and 9 slots).
- **Which links make strips:** CARD-caused links whose `cause_slot != target_slot`, of kind BONUS, STAMP, COPY or FIZZLE (an Egg reset). There is one strip per giver slot, covering all its targets. Upgrades and inspections have no strip (their givers aren't on the belt): their stickers carry the stamp badge, and the hover rings their box or chip.
- **Backward strips** (a target before its giver: COPY of an earlier item when the Repeat comes first, a coupon that links backwards): the plug is still at the giver, the cap at the leftmost target, and the chevrons point left.

### 5.2 Lane rule (overlapping strips)

- A strip's span is `[lo, hi]` in slots (giver and targets). Two strips **conflict** when `a.lo <= b.hi and b.lo <= a.hi`. Sharing a slot conflicts too: Eggs→Bread and Bread→Milk need two lanes, because Bread's plug sits under Eggs' badge.
- `assign_lanes` sorts by `(lo, giver_slot)` and gives each strip lane 0 if no strip already in lane 0 conflicts, else lane 1 if none conflicts there, else **−1 (overflow)**.
- An overflow strip isn't drawn while calm. Its targets' stickers still carry its badge, and it is drawn when its giver (or one of its targets) is hovered (5.3).
- Lane 1 is drawn after lane 0, so its stems and drops cross lane 0 on top, framed by their ink.
- Calm strips draw in **brass** (no glow). Nothing loops.

### 5.3 Hot (hover)

- Hovering item F makes **F's own strip** (F as giver) hot. That strip is drawn in **lane 0's geometry**, on top of everything else in the layer: it is promoted, even when it was in lane 1 or overflowed. It gets every target's gain badge.
- Strips that **target F** are hot too. If F's own strip already takes lane 0, they stay in their lane. They show the gain badge for F only.
- All other strips go to `dim_strip_alpha`.
- When focus ends, every strip returns to its calm lane.
- Motion: on each rebuild the chevrons step one texel (2 px) toward the targets once, over `slap_frame_s · 2`. None under reduced motion.

---

## 6. Z-order and layer contents

`PlanningLayer` children, back to front:
1. lane 0 gap fills
2. lane 0 strips (shadow, body, plate, chevrons, notches, cap, stem)
3. lane 1 strips
4. (amended) the hot strips' gain badges, with their strips (no factor badges)
5. pay tags (over the tickets' top edge)
6. the hovered giver's ticket ring (`.label.sel`: 3 bands of 2 px `MUSTARD_PALE`, `MUSTARD`, `INK` round the ticket rect)
7. sticker stacks, slot by slot from left to right
8. deny stamps
9. sparkles
10. promoted hot strips (5.3)

Halos and grey are in `ItemView`. The top bar, the hand, the scan layer and the drag ghost stay above the layer.

---

## 7. Monitor key line

The brief slide of `MonitorChannel` gets a **key row** pinned to its bottom: `KEY_HEIGHT := 34`, with a 2 px dashed `CREAM_SHADE` rule along its top (dash 6, gap 4) and entries `KEY_GAP := 12` apart, vertically centred.
- Each entry is a real `EffectSticker` at full size (badge included) followed by a 12 px bold (700) `INK` caption.
- Entries come from `PlanningModel.key_entries()`: the **first real sticker** of each kind present in the committed preview, in this order:

| Entry | Caption |
|---|---|
| own ADD or MULTIPLY (no badge) | "own rule" |
| a product's | "from an item" |
| a coupon's | "from a coupon" |
| an upgrade's | "loyalty" |
| a FIZZLE | "fizzled" |

- Entries are added while they fit the 382 px width (badge overhang counted). The rest are dropped. No stickers means no key row.
- The brief builds into `SLIDE_HEIGHT − KEY_HEIGHT − GAP` first, through the TIERS. If even the smallest tier doesn't fit, the brief is built without the key, at full height.
- The key changes only on `show_all` (every place, remove or redraw), never during a drag. `clear()` removes it.

---

## 8. Hover, receipt and monitor explanation

### 8.1 Focus sets (logic kept; looks replaced)

- **Item F hovered:** `related` = {F} ∪ givers of F's incoming CARD links ∪ targets of F's outgoing links.
  - Lit stickers: every sticker **on F**, plus every sticker anywhere **caused by F**. All other stickers are drained.
  - Items outside `related`: `Relation.DIM` (sprite `dim_item_alpha`, ticket and pay tag `dim_ticket_alpha`, stamp drained). F itself: `Relation.FOCUS` (gold brackets, its ticket ring). Others in `related`: `RELATED`.
  - The tickets of F's targets: `PriceSticker.set_got(true)`.
  - Loyalty boxes of upgrades causing links on F, and the inspection chip (named) when an inspection denies F, are ringed, as in the first build.
  - An item with no relations and no stickers shows nothing new (as #80's hover).
- **Loyalty box i hovered:** `related` = the targets of upgrade i. Lit: stickers caused by upgrade i. All strips dim. Box i ringed.
- **Inspection chip hovered:** `related` = the denied items. Their stamps stay lit. Stickers drained, strips dim, chip ringed.
- Fade: `focus_fade_s`, and at once under reduced motion. Leaving waits `unfocus_delay_s`. Focus is kept by card across a refresh and reapplied after `show_all`. Hovers are blocked while dragging or outside planning.

### 8.2 Receipt

On focus: `highlight_slot(F)` (the existing frame) and `show_relations(F, {target: token})`. The target lines get a `MUSTARD_PALE` fill and a token chip (`MUSTARD` face, 2 px `INK` border, 11 px bold) before the amount. The footer hint becomes "<Name> hovered" (amended: a long hint is cut with "…", so the footer stays one line). Unfocus clears all of it. (Amended) `show_planning(..., quota)` colours the PROJECTED amount `GOOD` with the met mark (`ReceiptView.Mark.MET`, the `mark_check` disc) at or over the quota and `TOMATO` under it, with "short €N.00" on its own row under it (above the fizzle footer); the comparison is `ShiftMargin.of(total, quota)`, a display difference like the QUOTA chip's delta, on the total the receipt shows. Planning lines of inspection-denied items show `PlanMark.DENIED` (the warning icon) instead of a check.

### 8.3 Monitor

The 0.6 s scan is unchanged. A belt item that gives gets a first footer line: `GIVES_TEXT := "%s to %s · +€%d"`, made of the giver's token (or tokens joined), the target names (up to 3 joined with ", ", else `"%d items"`), and the summed non-cancelled gains. It is printed with the existing step-line style. Its `+€N` is in `MUSTARD_DARKEST`.

---

## 9. Drag (ghost)

The behaviour is kept, the look is replaced:
- On each `landing_changed`, PlanningEffects builds a model from `preview.call(card, slot)` and paints stickers, halo, grey, stamp and pay on the views **as they stand**. Hypothetical slots before the landing go to their own view, the landing to the **ghost**, and later slots to the view to their left, as in the first build.
- The ghost carries its stack (4.2), its halo and grey, and its pay tag pinned at the ghost's (60, 70) (it has no ticket).
- **Rail strips hide during a drag** (`show_strips(false)`): strips jumping lanes as the pointer sweeps would be noise. The stickers and the QUOTA "› €N (+d)" say what the drop does. The ticket ring and focus are off.
- Off the row, or when the drag ends (dropped, let go or cancelled), the committed model comes back, strips included. These previews are never logged.

---

## 10. 8 and 9 slots, CLOSED and empty slots

- All anchors come from each view's `sprite()` and `sticker()` global rects, mapped into the layer and snapped to 2 px. Art never scales. The lanes keep their y. Offsets scale (4.2, 4.5, 5.1).
- CLOSED cells and empty slots get no sticker, pay, stamp or strip part. Spans only cover filled slots, which are contiguous from slot 0, so no strip crosses a closed or empty cell.
- With 9 slots a 62 px burst overhangs the next cell more. This is allowed: the stickers sit on the layer above the items. The layout tests still require everything to be on screen and off the ticket text.

## 11. Reduced motion

`profile.reduced_motion()` (through `PlanningEffects.reduced_motion`) turns off the sticker slap, the halo stepping, the chevron step and the hover fade. Nothing loops in either mode.

Motion with reduced motion off:
- **Slap:** only for stickers whose `key()` is new since the last `show_all`. Scale (1.2, 0.8), then (0.92, 1.08), then 1, each for `slap_frame_s`, pivoting at the sticker's bottom centre.
- **Halo:** steps out one ring per `halo_step_s`.
- **Chevrons:** step once, as in 5.3.

---

## 12. New art (text sources in `art/src/effects/`, built to `art/effects/`)

Each source has a header comment (what, where, size at 2x), `@size`, and `@kind icon`, or `@kind frame` with `@scale 2` for 9-slices. Colours come from section 1. Light is from the upper left. Outlines are 2 px ink (1 texel) except on the stamp. Shapes come from the mock's formulas through a scratch script, are drawn into the text grid, and then the scratch script is deleted. Add one batch row per asset to `production_log.tsv`.

| Asset | Kind | Texels | Look |
|---|---|---|---|
| `sticker_label` | frame @2, margin 3 | 9x9 | cream price-gun label: `w` face, `b` inner shade bottom and right, rounded 2-texel corners, ink rim |
| `sticker_label_grey` | frame @2 | 9x9 | same shape, `B` face, `A` lit, `C` shade |
| `sticker_label_teal` | frame @2 | 9x9 | same shape, `6` face, `5` shade |
| `sticker_burst` | icon | 31x17 | gold 18-point starburst (4.1) |
| `badge_item` | icon | 9x9 | round token (2.5) |
| `badge_coupon` | icon | 9x9 | rounded-square teal token with dashed edge |
| `badge_stamp` | icon | 9x9 | mini stamp ring around a teal panel |
| `deny_stamp` | icon | 48x34 | tilted rubber stamp (4.4) |
| `pay_burst` | icon | 30x16 | 12-point pay burst |
| `pay_burst_wide` | icon | 40x18 | 16-point pay burst |
| `pay_zero` | icon | 26x13 | punched tomato tag |
| `pay_plain` | icon | 26x13 | cream tag |
| `fizzle_paper` | icon | 7x7 | the fizzle spark in `w` with an ink stroke, for the tomato tag |
| `ticket_got` | frame @2, margins as `ticket_product` | 9x9 | `ticket_product` with a `y` face and `M` band |
| `rail_strip` / `rail_strip_hot` | frame @2, margin 2 | 6x7 | the strip body rows (5.1) |
| `rail_cap` / `rail_cap_hot` | icon | 5x9 | pointed end cap |
| `rail_chevron` / `rail_chevron_hot` | icon | 3x5 | chevron `>` in `u` / `m` |
| `rail_notch` / `rail_notch_hot` | icon | 9x5 | ink trapezoid with a `y` / `Y` triangle |
| `rail_gap` / `rail_gap_hot` | frame @2, margins 2 top / 3 bottom | 6x8 | gap fill: `M`/`Y` top, `m`/`M` fill, `l`/`m` bottom |
| `sparkle` | icon | 5x5 | cross, `y` arms, `w` core |

That is 25 sources. The plug, stems, badge boxes, ticket ring and drops are code-drawn rects in palette colours.

---

## 13. Tests to rewrite or add (GdUnit4; geometry checked on screen at 1280x720)

**Delete:** `tests/presentation/effect_marker_test.gd`, `tests/ui/item_view_effects_test.gd`; `test_armed_steps_say_whether_they_multiply` (reverted with core); the `multiplies` checks in `effect_graph_test.gd`; `hits` and fizzle-corner cases in `top_bar_effects_test.gd` (keep the hover and ring cases).

**New and rewritten:**
- `tests/presentation/planning_model_test.gd`:
  - stickers per slot for the reference row (eggs, bread, milk, multipack, milk, milk, milk under Spot check, with the capture's upgrades): kinds, texts, badge kinds and initials, in step order;
  - own stickers have no badge; pay states for all 5 cases (synthetic `ScoreResult`s); halo rings at ratios just below and at 5 and 20; stamp texts for an inspection and for Soup;
  - `gain` and `cancelled`; `key_entries()` order and selection;
  - `assign_lanes`: disjoint (all lane 0), touching chain (0 and 1), a triple overlap (overflow −1), backward strip spans; golden rows build without errors.
- `tests/ui/planning_effects_test.gd` (rewritten):
  - every slot shows its model (stacks, pays, stamps, halos, grey); stickers follow place, remove and redraw;
  - hover: lit and drained stickers, DIM alphas, hot strip promotion and gains, rings, receipt relations, the gives line;
  - box and chip hover; unfocus delay; focus survives a refresh;
  - drag: stickers follow the landing on views and the ghost, strips hidden, QUOTA delta, restored at the end;
  - the CHECKOUT click clears everything (layer empty, no halo, lift 0, no grey, no strike, rings off, key gone); reduced motion means no tweens.
- `tests/ui/planning_layout_test.gd` (new, geometry on the real screen at 1280x720, for 7, 8 and 9 slots and with a CLOSED cell; using the reference row and a **stress row** of 6+ stickers on one item and two overlapping strips):
  - no sticker, stamp or pay tag intersects any ticket's `base_text_rect()` or `summary_text_rect()` (pay tags may cover the ticket's top band only);
  - every stack's bottom ≤ 374, its top ≥ its ceiling (250 under the monitor's x-range, else 64);
  - every strip body lies inside its `LANE_RECTS` y-band and inside the belt's x-range 348..1266; every notch, plate and cap (and, hovered, every gain badge) lies inside `LIP_BAND := Rect2(348, 380, 918, 44)`; (amended) no factor badge on any strip in any state, each target keeps its notch or drop on its ticket, and hot gains stand on their targets and never meet; gap fills never intersect a ticket;
  - no two strips in the same lane overlap in x;
  - every layer child's global rect lies inside `Rect2(0, 0, 1280, 720)`;
  - nothing is drawn over a CLOSED cell or an empty slot.
- `tests/ui/item_view_planning_test.gd`: boost lift and halo node size per ring count; `hit_rect` and `DROP_TOP` include the boost; grey material on and off; DIM alphas on the sprite and ticket; the count-up's body moves are unaffected after clear.
- `tests/ui/price_sticker_test.gd`: strike line over the base text; glyph moved or hidden next to a tag; `set_got` face.
- `tests/ui/monitor_channel_test.gd`: the key row's entries and captions; dropped when the brief doesn't fit; cleared.
- `tests/presentation/receipt_stub_test.gd` (or a new receipt test): `show_relations`, `PlanMark.DENIED`, footer hint.
- `tests/ui/palette_colours_test.gd`: remove `chip_band.gd`; add `planning_layer.gd`, `rail_strip.gd`, `effect_sticker.gd`, `giver_badge.gd`, `pay_tag.gd`, `deny_stamp.gd`; the new Palette constants are in the palette.
- Adjust `tests/ui/captured_shift_test.gd`, `belt_chips_test.gd`, `drag_and_drop_test.gd`, `screen_capture_test.gd` and `top_bar_test.gd` to the stickers (the "chips" wording and helpers go).
- `python tools/pixel_art.py check` passes, and the resource-loading test covers `data/balance/planning.tres` (already in `data/`).

---

## 14. Plan docs (step E)

`docs/FULL_BUILD_PLAN.md` v0.36: rewrite every #71 text the first build wrote:
- the phase-3 feature bullet;
- the style-frame captures sentence (the `--effects` captures);
- the Palette sentence (tomato only on the €0 tag and the stamp; multipliers are mustard bursts);
- the Marks bullet ("planning shows stickers instead of the disc");
- the **Planning effects** bullet: a full rewrite to sections 2 to 11 here (stickers, badges, pay, halo, stamp, rail strips and lanes, key, hover, drag, clear, motion, and no top-bar badges);
- the "Marks and the receipt" tail (the count-up earns back stickers' "×3" and "+3" from the same causes);
- the "exact preview" extension;
- the "unmet conditions" item ("pfff" stickers);
- the **v0.36 changelog row**: h1, approved 2026-10-18, replacing the first build's chips; playtest-facing, no rule change.

`docs/PROTOTYPE_PLAN.md` v0.35:
- the Preview row and changelog row say stickers, halo and rail strips;
- drop the `multiplies` sentence from section 4 and from the v0.35 row (reverted);
- keep `RunState.preview(card, slot)`.

---

## 15. Build steps (exactly five, sequential)

Each step ends with `sh tools/check.sh` on its changed scripts, gdlint and gdformat clean, and its own suites through `sh tools/test.sh -a <suite>`. Steps A to D leave the game playable. Only step E runs the full suite (started in the background and waited on in the same turn).

**A. Art, palette, tuning, model (additive only, no visible change).**
- The 25 art sources (section 12), built with `pixel_art.py build`, then `sh tools/import.sh`, with production-log rows.
- `Palette.MUSTARD_DARK` / `MUSTARD_DARKEST`.
- `PlanningTuning`, `data/balance/planning.tres`.
- `PlanningModel`, `PlanningSlot`, `StickerSpec`, `RailStripSpec`, `EffectLink.gain` / `cancelled`.
- The shaders `halo_outline.gdshader` and `pixel_art_grey.gdshader`, `ArtStyle.grey_material` / `halo_material` and the `set_sharp` meta.
- Tests: `planning_model_test.gd`, palette test constants, `pixel_art.py check`.
- The first build's UI keeps working untouched.

**B. Item-level look replaces the chips.**
- `GiverBadge`, `EffectSticker`, `PayTag`, `DenyStamp`, `PlanningLayer` (stacks, stamps, pay tags, sparkles; no strips yet), `ShiftStage.planning_layer`.
- `ItemView`: boost, halo, grey, Relation {NONE, FOCUS, RELATED, DIM}, `hit_rect`/`DROP_TOP`. `PriceSticker`: `set_pay`/`set_got`.
- `PlanningEffects` switched to the model and the layer (hover keeps working through FOCUS/RELATED/DIM plus drained stickers; drag paints the views and the ghost).
- **All deletions in 3.2**, the core `multiplies` revert included.
- Tests: rewrite `planning_effects_test.gd` (data, clear and drag parts), `item_view_planning_test.gd`, `price_sticker_test.gd`, and the sticker, pay and stamp parts of `planning_layout_test.gd`, and adjust `captured_shift`, `belt_chips`, `drag_and_drop` and `top_bar_effects`.

**C. Rail strips and the monitor key.**
- `RailStrip` (calm), `assign_lanes`, gap fills, the layer's strip z-order, hidden during a drag.
- `MonitorChannel.set_key`, `MonitorView.set_planning_key`, wired from `PlanningEffects.show_all`/`clear`.
- Tests: the strip and lane parts of `planning_layout_test.gd` (lanes, lip band, 8 and 9 slots, CLOSED), `monitor_channel_test.gd`, model lanes on real rows.

**D. Hover polish, receipt and monitor explanation, motion.**
- Hot strips (promotion, gains, ring), `set_got`, the hovered ticket ring, lit and drained rules for box and chip hovers.
- `ReceiptView.show_relations`/`clear_relations`/`PlanMark.DENIED`/`set_footer_hint`, the scan's gives line.
- Slap, halo stepping, chevron step, reduced motion; tuning-driven fade and unfocus.
- Tests: the hover, reduced-motion and receipt cases, the gives line in `item_scan_test.gd`.

**E. Docs, mock-up sources, captures, full check.**
- Plan docs as in section 14.
- `docs/art/mockups/README.md`: append a new section at the **end** (to avoid conflicting with main's one-row README change from #84), "Planning effects mock-ups (#71, 2026-10-18)". It lists A, B, C, h1 and h2, each with its hover page and capture, gives one line per idea, records the rejections (h2 pipes, A ribbons, the floating chip band) and **h1 approved by the user as "perfect"**, and points to this spec and the generators.
- Generators in `planning_effects_src/gen_a`, `gen_h1`, `gen_h2`:
  - `MOCKUPS = Path(__file__).resolve().parents[2]` (= `docs/art/mockups`) for both input and output; the base page is `MOCKUPS / "shift_screen_b2_mirrored.html"`. If it is missing (it reaches this branch with main, PR #84), exit with "shift_screen_b2_mirrored.html comes from main (#84): merge main first".
  - `run.sh` and `cap.sh`: `HERE=$(cd "$(dirname "$0")" && pwd)`, Chrome from `${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}`, profile in `${TMPDIR:-/tmp}/next_customer_chrome_<name>`; no scratchpad paths anywhere.
  - If `gen_c.py`, `overlay_c.css` and `overlay_c.js` are still in this session's scratchpad, move them into `planning_effects_src/gen_c/` with the same fixes; otherwise the README says that C's generator was not kept.
- Captures through the screen-capture scene (only via the repo's Godot setup, with no windowed Godot left open): `--effects` and `--effects=multipack` at 1280x720 and 1920x1080 into `docs/art/shift_screen_effects_*.png` / `shift_screen_effects_focus_*.png`, and retake `shift_screen_1280x720.png`, `shift_screen_1920x1080.png` and `shift_screen_scan_1920x1080.png`. Compare against the h1 captures (layout, colours, z-order) and fix any drift.
- `sh tools/check.sh` (all scripts), `python tools/pixel_art.py check`, then the **full** `sh tools/test.sh` (background plus a wait loop until "Overall Summary"; never end the turn while it runs). Flag the change as playtest-facing.
