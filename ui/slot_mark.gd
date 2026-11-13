class_name SlotMark
extends Control
## A loyalty upgrade's mark on a slot of the belt (2026-10-24, #106 follow-up: "loyalty slot
## engine should put an effect on 6th slot"): the Slot engine pays x2 for whatever card is in
## slot 6, so that slot wears a talker, a small loyalty tag hanging under the right end of its
## ticket on the price rail (as an item tier's tag hangs under the left end, PriceSticker), its
## top tucked behind the ticket. It holds the upgrade's perk icon (UpgradeDefinition.icon_ref; its
## initials on a loyalty badge when it has none) and its factor ("×2"). It shows whether the slot
## is empty or filled, in planning and on the belt while the shift is counted, where it rides with
## its cell; when the upgrade's step lands on the slot it fires (fire: a punch, a flash and a swing
## about its hook, like a shelf wobbler). RowStrip places it (show_slot_marks); BeltRide fires it.
##
## The tag is the slot_talker 9-slice (badge_stamp's mustard ring around a teal dark face) over
## its hard shadow (ink at SHADOW_ALPHA at SHADOW_OFFSET), its parts on the 2 px art grid. Decor
## only: it takes no clicks, and its numbers are the rule's data (NthSlotMultiplierRule).
##
## An inspection's mark (2026-10-28, rule tweaks 2: Spot check's dead slot 3) is the same tag in
## the 0€ pay tag's tomato (slot_talker_inspection) with the warning sign and "0€" in paper, so
## the slot reads as the wasted one before anything is put there; it fires when the inspection
## zeroes the card there (NthSlotZeroPayoutRule). One owner per fact (2026-11-02, shift scene
## polish v2 ticket brief section 3): while a card stands on that slot its ticket's pay tag owns
## the "0€", so the mark (a zero_slot one) shrinks to a cause-only chip (set_compact: the
## slot_chip_inspection art, the warning sign alone, no text), centred under the ticket; on an
## empty slot it is the full "⚠ 0€" talker, the only 0€ shown then. Either way its hover tip names
## the cause (ZERO_TIP: "Spot check: this slot pays 0€").
##
## Every day event aimed at a slot wears one (2026-10-31: "day event that impact a specific slot
## should be shown visually on slot"): Happy hour's "+3€" rides on the row's last filled slot (on
## slot 1 while the belt is empty: the next card is the last), and Extra till's slot more says
## EXTRA. A boon's mark is the tag in green (slot_talker_boon) with the boon coin and its text in
## paper; a malus's is the tomato one with the warning sign. It fires when the event's step lands
## on its slot.
##
## A worn pin's event marks its slots the same way (#132): Express lane's ends
## (EndSlotsMultiplierRule) wear its "×2" on the row's first and last open slots, which stay
## put as the row fills (the user's call of 2026-11-02: slot 5 of 5, not the last item). An
## ends mark (is_ends) is the express tag (slot_talker_express's light green with the
## express chevrons and its factor in ink), and RowStrip marks the slot
## itself too (SlotLane: a green plate round its ticket and a painted lane on its belt patch).
## A Double checkout's rows are planned one at a time on the belt, so each row gets its own.

## The tag's height, of which its top TUCKED px hide behind the ticket, and its insides: the
## frame's margin (art pixels), the padding from its left side to the icon (just inside the ring)
## and from the text to its right side (the glyphs' own bearing clears the ring), and the gap
## between them (none: the text's own bearing parts them). Its width fits its text (width_for):
## kept tight, so it clears a tier tag under the same ticket's left end (RowStrip.slot_mark_rect).
const HEIGHT := 24.0
const TUCKED := 2.0
const FRAME_MARGIN := 3
const PADDING := 4.0
const TEXT_PADDING := 4.0
const GAP := 0.0
const TEXT_SIZE := 16
const TEXT_FORMAT := "×%d"
## The text's colour on the teal face: the loyalty stamp's mustard pale.
const TEXT_COLOR := Palette.MUSTARD_PALE
## An inspection's mark: its text and the text's colour on the tomato face.
const INSPECTION_TEXT := "0€"
const INSPECTION_TEXT_COLOR := Palette.PAPER
## A zero slot's hover tip: the inspection's name and INSPECTION_TEXT.
const ZERO_TIP := "%s · Anything in this slot pays %s this shift."
## The zero slot tip's tag.
const ZERO_TAG := "THIS SHIFT"
## A day event's flat bonus on its slot (Happy hour: LastCardBonusRule), with its sign; and the
## mark of an event's extra slot (Extra till).
const BONUS_FORMAT := "+%d€"
const MALUS_FORMAT := "−%d€"
const EXTRA_TEXT := "EXTRA"
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.42
## The fire: a punch to 1 + FIRE_PUNCH easing back over FIRE_S, flashed by EffectSticker.FLASH
## for its FLASH_S (the planning stickers' fire), and a swing about the hook from SWING_DEG,
## SWINGS half swings fading out.
const FIRE_PUNCH := 0.45
const FIRE_S := 0.6
const SWING_DEG := 9.0
const SWINGS := 3.0
const INNER_NAME := &"Inner"
const SHADOW_NAME := &"Shadow"
const FRAME_NAME := &"Frame"
const ICON_NAME := &"Icon"
const TEXT_NAME := &"Factor"
const CHIP_NAME := &"Chip"
const CHIP_SHADOW_NAME := &"ChipShadow"

const TALKER := preload("res://art/effects/slot_talker.png")
const INSPECTION_TALKER := preload("res://art/effects/slot_talker_inspection.png")
const BOON_TALKER := preload("res://art/effects/slot_talker_boon.png")
const EXPRESS_TALKER := preload("res://art/effects/slot_talker_express.png")
const CHIP := preload("res://art/effects/slot_chip_inspection.png")
const WARNING := preload("res://art/icons/warning.png")
const BOON_ICON := preload("res://art/icons/boon.png")
const EXPRESS_ICON := preload("res://art/icons/express.png")
## An ends mark's text colour on the light green face.
const EXPRESS_TEXT_COLOR := Palette.INK

## The slot it marks (0-based), the upgrade's index in the run's upgrades and the rule's factor;
## for an inspection's mark, the inspection's index in the shift's inspections (else -1), and
## whether the day event is a boon (the green tag), and whether it marks the row's ends (the
## express tag, Express lane's).
var slot: int = -1
var upgrade_index: int = -1
var factor: int = 1
var inspection_index: int = -1
var boon: bool = false
var ends: bool = false
## Whether it marks a slot an inspection pays 0€ (NthSlotZeroPayoutRule; set_zero_tip): it shrinks
## to the cause-only chip while a card stands there (set_compact).
var zero_slot: bool = false
var _inner: Control
var _icon: Control
var _label: Label
var _fire_tween: Tween
var _fired: int = 0
var _compact: bool = false
var _full_size: Vector2 = Vector2.ZERO


func _init(
	mark_slot: int,
	mark_upgrade: int,
	mark_factor: int,
	upgrade: UpgradeDefinition = null,
	mark_inspection: int = -1,
	mark_text: String = INSPECTION_TEXT,
	mark_boon: bool = false,
	mark_ends: bool = false
) -> void:
	slot = mark_slot
	upgrade_index = mark_upgrade
	factor = mark_factor
	inspection_index = mark_inspection
	var inspected: bool = is_inspection()
	boon = inspected and mark_boon
	ends = inspected and mark_ends
	name = ("InspectionMark%d" if inspected else "SlotMark%d") % slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption: String = mark_text if inspected else TEXT_FORMAT % factor
	_label = UiKit.display_label(caption, TEXT_SIZE, false)
	_label.name = TEXT_NAME
	var text_color: Color = INSPECTION_TEXT_COLOR if inspected else TEXT_COLOR
	_label.add_theme_color_override("font_color", EXPRESS_TEXT_COLOR if ends else text_color)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon = _day_icon(boon, ends) if inspected else _icon_for(upgrade)
	_icon.name = ICON_NAME
	var text_width: float = ceilf(_label.get_minimum_size().x)
	size = Vector2(width_for(_icon.size.x, text_width), HEIGHT)
	custom_minimum_size = size
	_full_size = size
	_inner = Control.new()
	_inner.name = INNER_NAME
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.size = size
	# It hangs from its hook, the top's middle: the punch and the swing turn about it.
	_inner.pivot_offset = Vector2(size.x / 2.0, 0.0)
	add_child(_inner)
	var shadow: Panel = _frame(inspected, boon, ends)
	shadow.name = SHADOW_NAME
	shadow.position = SHADOW_OFFSET
	shadow.size = size
	shadow.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
	_inner.add_child(shadow)
	var frame: Panel = _frame(inspected, boon, ends)
	frame.name = FRAME_NAME
	frame.size = size
	_inner.add_child(frame)
	# The icon and the text sit in the middle of the part that shows under the ticket.
	var shown: Rect2 = visible_rect()
	var icon_top: float = shown.position.y + (shown.size.y - _icon.size.y) / 2.0
	_icon.position = Vector2(PADDING, icon_top).snappedf(ArtStyle.ART_SCALE)
	_inner.add_child(_icon)
	var text_left: float = _icon.position.x + _icon.size.x + GAP
	_label.position = Vector2(text_left, shown.position.y)
	_label.size = Vector2(size.x - TEXT_PADDING - text_left, shown.size.y)
	_inner.add_child(_label)


## The marks of `run`'s shift: its upgrades' and its events' on its row (marks_for). The events
## are scoring's (WeekSchedule.shift_events: the day's, the week's, the worn pins'), so a mark's
## inspection_index is its steps' source_index.
static func run_marks(run: RunState) -> Array[SlotMark]:
	var open: int = RowCapacity.card_limit(run.limits)
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	return marks_for(run.upgrades, events, run.row.size(), open)


## The marks of `upgrades` (the run's, in pick order): one for each rule that multiplies a fixed
## slot (NthSlotMultiplierRule with a slot and a factor other than 1), on that slot; and the
## shift's `inspections`' (inspection_marks, for a row of `row_size` cards in `slot_count` open
## slots), first.
static func marks_for(
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition] = [],
	row_size: int = 0,
	slot_count: int = 0
) -> Array[SlotMark]:
	var marks: Array[SlotMark] = inspection_marks(inspections, row_size, slot_count)
	for index: int in range(upgrades.size()):
		for rule: UpgradeRule in upgrades[index].rules:
			var slot_rule: NthSlotMultiplierRule = rule as NthSlotMultiplierRule
			if slot_rule == null or slot_rule.slot_number <= 0 or slot_rule.factor == 1:
				continue
			marks.append(
				SlotMark.new(slot_rule.slot_number - 1, index, slot_rule.factor, upgrades[index])
			)
	return marks


## The marks of the shift's day events `inspections` (2026-10-31), in order: on its slot, each
## rule that zeroes a fixed slot (NthSlotZeroPayoutRule: "0€"); on the row's last filled slot
## (slot 1 for an empty row of `row_size` 0), each last card bonus (LastCardBonusRule: "+3€");
## on the row's first and last of its `slot_count` open slots (the last filled one when
## `slot_count` is 0, unknown), each ends multiplier (EndSlotsMultiplierRule: "×2",
## #132); and on each slot an event adds, the last of
## the `slot_count` open slots, EXTRA. A row of `slot_count` 0 (unknown) gets no EXTRA marks.
static func inspection_marks(
	inspections: Array[InspectionDefinition], row_size: int = 0, slot_count: int = 0
) -> Array[SlotMark]:
	var marks: Array[SlotMark] = []
	var last_slot: int = maxi(row_size - 1, 0)
	var extra: int = 0
	for index: int in range(inspections.size()):
		var event: InspectionDefinition = inspections[index]
		var good: bool = event.is_boon()
		for rule: InspectionRule in event.rules:
			var zero_rule: NthSlotZeroPayoutRule = rule as NthSlotZeroPayoutRule
			if zero_rule != null and zero_rule.slot_number > 0:
				var zero: SlotMark = SlotMark.new(zero_rule.slot_number - 1, -1, 1, null, index)
				zero.set_zero_tip(event.display_name)
				marks.append(zero)
			var last_rule: LastCardBonusRule = rule as LastCardBonusRule
			if last_rule != null and last_rule.bonus != 0:
				var amount: int = absi(last_rule.bonus)
				var caption: String = (
					BONUS_FORMAT % amount if last_rule.bonus > 0 else MALUS_FORMAT % amount
				)
				marks.append(SlotMark.new(last_slot, -1, 1, null, index, caption, good))
			var ends_rule: EndSlotsMultiplierRule = rule as EndSlotsMultiplierRule
			if ends_rule != null and ends_rule.factor != 1:
				var ends_text: String = TEXT_FORMAT % ends_rule.factor
				var end: int = slot_count - 1 if slot_count > 0 else last_slot
				for end_slot: int in [0] if end == 0 else [0, end]:
					marks.append(
						SlotMark.new(
							end_slot, -1, ends_rule.factor, null, index, ends_text, good, true
						)
					)
		for _added: int in range(maxi(event.extra_slots, 0)):
			var extra_slot: int = slot_count - 1 - extra
			extra += 1
			if slot_count > 0 and extra_slot >= 0:
				marks.append(SlotMark.new(extra_slot, -1, 1, null, index, EXTRA_TEXT, good))
	return marks


## Whether it is an inspection's mark (the dead slot's), not a loyalty upgrade's.
func is_inspection() -> bool:
	return inspection_index >= 0


## Makes it a zero slot's mark (zero_slot) of the inspection `inspection_name`: its hover tip
## names the cause (ZERO_TIP), so it takes the mouse (it still takes no clicks: PASS).
func set_zero_tip(inspection_name: String) -> void:
	zero_slot = true
	TipTarget.cover_text(
		self, ZERO_TIP % [inspection_name, INSPECTION_TEXT], TipSpec.Kind.STATUS, ZERO_TAG
	)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shrinks a zero slot's mark to the cause-only chip (`compact`: a card stands on its slot, its
## ticket shows the 0€) or grows it back to the full talker; other marks never shrink. The chip is
## the slot_chip_inspection art over its hard shadow, its top tucked behind the ticket like the
## talker's; RowStrip hangs it again (centred under the ticket when it is the slot's only mark).
func set_compact(compact: bool) -> void:
	var shrink: bool = compact and zero_slot
	if shrink == _compact:
		return
	_compact = shrink
	if shrink and _inner.get_node_or_null(NodePath(CHIP_NAME)) == null:
		for chip_name: StringName in [CHIP_SHADOW_NAME, CHIP_NAME]:
			var chip: TextureRect = UiKit.sprite(CHIP)
			chip.name = chip_name
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.size = CHIP.get_size() * ArtStyle.ART_SCALE
			if chip_name == CHIP_SHADOW_NAME:
				chip.position = SHADOW_OFFSET
				chip.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
			_inner.add_child(chip)
	for part: Node in _inner.get_children():
		var chip_part: bool = part.name == CHIP_NAME or part.name == CHIP_SHADOW_NAME
		(part as CanvasItem).visible = chip_part == shrink
	# The minimum first: a size under it would be clamped.
	custom_minimum_size = CHIP.get_size() * ArtStyle.ART_SCALE if shrink else _full_size
	size = custom_minimum_size
	_inner.size = size
	_inner.pivot_offset = Vector2(size.x / 2.0, 0.0)


## Whether it shows as the cause-only chip (set_compact).
func is_compact() -> bool:
	return _compact


## Whether its text shows (not on the cause-only chip).
func shows_text() -> bool:
	return _label.visible


## The tag's width for an icon and a text this wide: the padding, the icon, the gap, the text
## and its padding, rounded up to the art grid.
static func width_for(icon_width: float, text_width: float) -> float:
	var width: float = PADDING + icon_width + GAP + text_width + TEXT_PADDING
	return ceilf(width / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## The part of the tag that shows under the ticket (its own coordinates): all but its top TUCKED
## px.
func visible_rect() -> Rect2:
	return Rect2(0.0, TUCKED, size.x, size.y - TUCKED)


## The upgrade's step landed on the slot (BeltRide): a punch, a flash and a swing about the hook
## on `make_tween`'s tweens when given; none under `reduced_motion` or out of the tree.
func fire(reduced_motion: bool, make_tween: Callable = Callable()) -> void:
	_fired += 1
	if _fire_tween != null:
		_fire_tween.kill()
		_fire_tween = null
	_punch(1.0)
	if reduced_motion or not is_inside_tree():
		return
	_fire_tween = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_fire_tween.tween_method(_punch, 0.0, 1.0, FIRE_S)


## How many times it fired (for tests).
func fired_count() -> int:
	return _fired


## Whether a fire is still playing (for tests).
func is_firing() -> bool:
	return _fire_tween != null and _fire_tween.is_running()


## The factor's text (for tests).
func text() -> String:
	return _label.text


## The perk icon, or the initials' badge (for tests).
func icon() -> Control:
	return _icon


## The part that punches and swings: the shadow, the face, the icon and the text (for tests).
func inner() -> Control:
	return _inner


## The fire at `progress` (0 to 1): scaled 1 + FIRE_PUNCH easing back to 1, swung about the hook
## and fading, and flashed for the first EffectSticker.FLASH_S.
func _punch(progress: float) -> void:
	var left: float = 1.0 - progress
	_inner.scale = Vector2.ONE * (1.0 + FIRE_PUNCH * left * left * left)
	_inner.rotation_degrees = SWING_DEG * left * sin(progress * PI * SWINGS)
	var flashing: bool = progress < 1.0 and progress * FIRE_S < EffectSticker.FLASH_S
	var flash: float = EffectSticker.FLASH if flashing else 1.0
	_inner.modulate = Color(flash, flash, flash)


## The tag's face: the slot_talker 9-slice, slot_talker_inspection's for an inspection (a malus),
## slot_talker_boon's for a boon, or slot_talker_express's for the row's ends (`at_ends`).
static func _frame(inspected: bool, good: bool = false, at_ends: bool = false) -> Panel:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: Texture2D = TALKER
	if inspected:
		texture = BOON_TALKER if good else INSPECTION_TALKER
		if at_ends:
			texture = EXPRESS_TALKER
	panel.add_theme_stylebox_override("panel", ArtStyle.frame_style(texture, FRAME_MARGIN))
	ArtStyle.use_pixel_material(panel)
	return panel


## The upgrade's perk icon at the art scale, or its initials on a loyalty badge (no icon, or no
## upgrade: its name's initials, "?" for none).
static func _icon_for(upgrade: UpgradeDefinition) -> Control:
	if upgrade != null and upgrade.icon_ref != "" and ResourceLoader.exists(upgrade.icon_ref):
		var texture: Texture2D = load(upgrade.icon_ref) as Texture2D
		var sprite: TextureRect = UiKit.sprite(texture)
		sprite.size = texture.get_size() * ArtStyle.ART_SCALE
		return sprite
	var badge_name: String = upgrade.display_name if upgrade != null else ""
	return GiverBadge.new(
		GiverBadge.Kind.LOYALTY, GiverBadge.initials_for(GiverBadge.Kind.LOYALTY, badge_name)
	)


## A day event's icon at the art scale: the express chevrons for the row's ends (`at_ends`), the
## boon coin for a boon, else the warning sign.
static func _day_icon(good: bool, at_ends: bool = false) -> Control:
	var texture: Texture2D = BOON_ICON if good else WARNING
	if at_ends:
		texture = EXPRESS_ICON
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.size = texture.get_size() * ArtStyle.ART_SCALE
	return sprite
