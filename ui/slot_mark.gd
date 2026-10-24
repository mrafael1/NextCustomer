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

const TALKER := preload("res://art/effects/slot_talker.png")

## The slot it marks (0-based), the upgrade's index in the run's upgrades and the rule's factor.
var slot: int = -1
var upgrade_index: int = -1
var factor: int = 1
var _inner: Control
var _icon: Control
var _label: Label
var _fire_tween: Tween
var _fired: int = 0


func _init(
	mark_slot: int, mark_upgrade: int, mark_factor: int, upgrade: UpgradeDefinition = null
) -> void:
	slot = mark_slot
	upgrade_index = mark_upgrade
	factor = mark_factor
	name = "SlotMark%d" % slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiKit.display_label(TEXT_FORMAT % factor, TEXT_SIZE, false)
	_label.name = TEXT_NAME
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon = _icon_for(upgrade)
	_icon.name = ICON_NAME
	var text_width: float = ceilf(_label.get_minimum_size().x)
	size = Vector2(width_for(_icon.size.x, text_width), HEIGHT)
	custom_minimum_size = size
	_inner = Control.new()
	_inner.name = INNER_NAME
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.size = size
	# It hangs from its hook, the top's middle: the punch and the swing turn about it.
	_inner.pivot_offset = Vector2(size.x / 2.0, 0.0)
	add_child(_inner)
	var shadow: Panel = _frame()
	shadow.name = SHADOW_NAME
	shadow.position = SHADOW_OFFSET
	shadow.size = size
	shadow.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
	_inner.add_child(shadow)
	var frame: Panel = _frame()
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


## The marks of `upgrades` (the run's, in pick order): one for each rule that multiplies a fixed
## slot (NthSlotMultiplierRule with a slot and a factor other than 1), on that slot.
static func marks_for(upgrades: Array[UpgradeDefinition]) -> Array[SlotMark]:
	var marks: Array[SlotMark] = []
	for index: int in range(upgrades.size()):
		for rule: UpgradeRule in upgrades[index].rules:
			var slot_rule: NthSlotMultiplierRule = rule as NthSlotMultiplierRule
			if slot_rule == null or slot_rule.slot_number <= 0 or slot_rule.factor == 1:
				continue
			marks.append(
				SlotMark.new(slot_rule.slot_number - 1, index, slot_rule.factor, upgrades[index])
			)
	return marks


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


## The tag's face: the slot_talker 9-slice.
static func _frame() -> Panel:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ArtStyle.frame_style(TALKER, FRAME_MARGIN))
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
