class_name LoyaltyCard
extends PanelContainer
## The loyalty card (full build plan 5.2), in the pixel-art style (#55): the loyalty_card frame
## with one box per upgrade shift (plus one for a starting deck's upgrade, 7.3), each an empty
## stamp ring until an upgrade is taken. A taken upgrade stamps the next box with its initials
## (a placeholder for its perk icon until #59). Hovering a stamped box shows the upgrade's name,
## type, effect and condition, so nothing about an upgrade is shown only inside an animation.
##
## The count-up flies upgrade steps in from these boxes: box(i) belongs to the run's upgrade i.

const BOX_SIZE := Vector2(34, 34)
## The resting tilt of every stamped box.
const STAMP_TILT := -6.0
## The card's 9-slice margin in art pixels, and its padding: left, top, right, bottom.
const FRAME_MARGIN := 3
const PADDING := Vector4(10, 6, 8, 4)
const TITLE_SIZE := 11
## The initials' size: the widest ("ExCS", Extra coupon slot) just fits inside the border.
const INITIALS_SIZE := 12
## A stamped box's ink ring, in canvas pixels.
const STAMP_BORDER := 2
## The initials' ink outline: thinner than UiKit.LIGHT_OUTLINE, which would fill the letters'
## counters at this size.
const INITIALS_OUTLINE := 3

const CARD_FRAME := preload("res://art/frames/loyalty_card.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_empty.png")

var _boxes: HBoxContainer
var _box_count: int = 0
## What the boxes show now, so a refresh only rebuilds them when the upgrades change.
var _shown: Array[UpgradeDefinition] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxTexture = ArtStyle.frame_style(CARD_FRAME, FRAME_MARGIN)
	style.content_margin_left = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_right = PADDING.z
	style.content_margin_bottom = PADDING.w
	add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(self)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var title: Label = UiKit.display_label("LOYALTY\nCARD", TITLE_SIZE, false)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_boxes = HBoxContainer.new()
	_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boxes.add_theme_constant_override("separation", 4)
	# A container resets its children's rotation whenever it sorts them, so the tilt is put
	# back after every sort.
	_boxes.sort_children.connect(_tilt_stamped_boxes)
	row.add_child(_boxes)


## Shows the owned upgrades in pick order, one per box. `boxes` comes from the caller (usually
## box_count). More upgrades than boxes (debug) add boxes.
func show_upgrades(boxes: int, upgrades: Array[UpgradeDefinition]) -> void:
	if boxes == _box_count and upgrades == _shown:
		return
	_box_count = boxes
	_shown = upgrades.duplicate()
	for child: Node in _boxes.get_children():
		_boxes.remove_child(child)
		child.queue_free()
	for index: int in range(maxi(boxes, upgrades.size())):
		var upgrade: UpgradeDefinition = upgrades[index] if index < upgrades.size() else null
		_boxes.add_child(_make_box(upgrade))


## The run's boxes: one per upgrade shift (balance data), plus one when its deck has a starting
## upgrade (full build plan 7.3).
static func box_count(run: RunState) -> int:
	return run.balance.upgrade_shifts.size() + (0 if run.starter.starting_upgrade == null else 1)


## The box of the run's upgrade `index` (pick order), or null.
func box(index: int) -> Control:
	if index < 0 or index >= _shown.size() or index >= _boxes.get_child_count():
		return null
	return _boxes.get_child(index) as Control


## The stamped boxes, indexed like the run's upgrades (for the count-up's fly-ins).
func stamped_boxes() -> Array[Control]:
	var stamped: Array[Control] = []
	for index: int in range(_shown.size()):
		stamped.append(box(index))
	return stamped


## The upgrades' names, indexed like the run's upgrades, for the receipt.
static func names(upgrades: Array[UpgradeDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for upgrade: UpgradeDefinition in upgrades:
		result.append(upgrade.display_name)
	return result


## Every box's text, empty for an empty box.
func box_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in _boxes.get_children():
		texts.append((child.get_child(0) as Label).text)
	return texts


## The stamp landing on the box of upgrade `index`: big and tilted, slammed down.
func play_stamp(index: int) -> void:
	var target: Control = box(index)
	if target == null:
		return
	target.pivot_offset = BOX_SIZE / 2.0
	target.scale = Vector2(2.4, 2.4)
	target.rotation = deg_to_rad(-20.0)
	target.modulate.a = 0.0
	var slam: Tween = target.create_tween().set_parallel()
	slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(target, "scale", Vector2.ONE, 0.16)
	slam.tween_property(target, "rotation", deg_to_rad(STAMP_TILT), 0.16)
	slam.tween_property(target, "modulate:a", 1.0, 0.1)
	slam.chain().tween_property(target, "scale", Vector2(1.15, 1.15), 0.06)
	slam.chain().tween_property(target, "scale", Vector2.ONE, 0.12)


## Placeholder for the perk icon: the first two letters of the first word, then the initials of
## the others ("Coupon engine" CoE, "Category engine" CaE), so similar names stay apart.
static func initials(display_name: String) -> String:
	var words: PackedStringArray = display_name.split(" ", false)
	if words.is_empty():
		return "?"
	var text: String = words[0].substr(0, 2).capitalize()
	for word: String in words.slice(1):
		text += word.substr(0, 1).to_upper()
	return text


## A stamped box's hover text: the ticket's fields, so nothing is only in the animation.
static func tooltip_for(upgrade: UpgradeDefinition) -> String:
	var lines: PackedStringArray = PackedStringArray(
		["%s (%s)" % [upgrade.display_name, upgrade.type_label()], upgrade.effect_text]
	)
	if not upgrade.condition_text.is_empty():
		lines.append(upgrade.condition_text)
	return "\n".join(lines)


func _tilt_stamped_boxes() -> void:
	for stamped: Control in stamped_boxes():
		if stamped == null:
			continue
		stamped.pivot_offset = BOX_SIZE / 2.0
		stamped.rotation = deg_to_rad(STAMP_TILT)


func _make_box(upgrade: UpgradeDefinition) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = BOX_SIZE
	if upgrade == null:
		# The empty stamp ring, drawn at the box's size.
		var ring: StyleBoxTexture = StyleBoxTexture.new()
		ring.texture = STAMP_EMPTY
		ring.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel", ring)
		ArtStyle.use_pixel_material(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(17)
		style.set_border_width_all(STAMP_BORDER)
		style.set_content_margin_all(0)
		# The darker tomato keeps the paper initials readable (5.9:1 against 3.7:1).
		style.bg_color = Palette.TOMATO_DARK
		style.border_color = Palette.INK
		panel.add_theme_stylebox_override("panel", style)
		# PASS, not IGNORE: a tooltip needs the mouse.
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.tooltip_text = tooltip_for(upgrade)
	# The number font (MSDF Atkinson) stays crisp at the tilt and tells l from I and C from D:
	# paper with a thin ink outline.
	var label: Label = UiKit.number_label(
		initials(upgrade.display_name) if upgrade != null else "", INITIALS_SIZE, true
	)
	label.add_theme_constant_override("outline_size", INITIALS_OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
