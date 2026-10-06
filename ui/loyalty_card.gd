class_name LoyaltyCard
extends PanelContainer
## The loyalty card greybox (full build plan 5.2): one box per upgrade shift, empty until an
## upgrade is taken. A taken upgrade stamps the next box with its initials (a placeholder for
## its perk icon). Hovering a stamped box shows the upgrade's name, type, effect and condition,
## so nothing about an upgrade is shown only inside an animation.
##
## The count-up flies upgrade steps in from these boxes: box(i) belongs to the run's upgrade i.

const BOX_SIZE := Vector2(34, 34)
## The resting tilt of every stamped box.
const STAMP_TILT := -6.0

var _boxes: HBoxContainer
var _box_count: int = 0
## What the boxes show now, so a refresh only rebuilds them when the upgrades change.
var _shown: Array[UpgradeDefinition] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.CREAM
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var title: Label = UiKit.label("LOYALTY\nCARD", 10, Palette.INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_boxes = HBoxContainer.new()
	_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boxes.add_theme_constant_override("separation", 4)
	# A container resets its children's rotation whenever it sorts them, so the tilt is put
	# back after every sort.
	_boxes.sort_children.connect(_tilt_stamped_boxes)
	row.add_child(_boxes)


## Shows the owned upgrades in pick order, one per box. `box_count` is the number of upgrade
## shifts (balance data); more upgrades than boxes (debug) add boxes.
func show_upgrades(box_count: int, upgrades: Array[UpgradeDefinition]) -> void:
	if box_count == _box_count and upgrades == _shown:
		return
	_box_count = box_count
	_shown = upgrades.duplicate()
	for child: Node in _boxes.get_children():
		_boxes.remove_child(child)
		child.queue_free()
	for index: int in range(maxi(box_count, upgrades.size())):
		var upgrade: UpgradeDefinition = upgrades[index] if index < upgrades.size() else null
		_boxes.add_child(_make_box(upgrade))


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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(17)
	style.set_border_width_all(2)
	style.set_content_margin_all(0)
	if upgrade == null:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(Palette.INK, 0.35)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		style.bg_color = Palette.TOMATO
		style.border_color = Palette.INK
		# PASS, not IGNORE: a tooltip needs the mouse.
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.tooltip_text = tooltip_for(upgrade)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = UiKit.label(
		initials(upgrade.display_name) if upgrade != null else "", 12, Palette.PAPER
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
