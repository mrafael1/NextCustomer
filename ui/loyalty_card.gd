class_name LoyaltyCard
extends PanelContainer
## The loyalty card (full build plan 5.2), in the pixel-art style (#55): the loyalty_card frame
## with one box per upgrade shift (plus one for a starting deck's upgrade, 7.3), each an empty
## stamp ring until an upgrade is taken. A taken upgrade stamps the next box with its initials
## (a placeholder for its perk icon until #59). Hovering a stamped box shows the upgrade's name,
## type, effect and condition, so nothing about an upgrade is shown only inside an animation.
##
## The count-up flies upgrade steps in from these boxes: box(i) belongs to the run's upgrade i.
##
## The top bar's face (#80 step 10, mock-up B2; `chip`): the teal LOYALTY chip with B2's 13x13
## stamp rings at 2x, upright: a mustard ring around the teal panel for a stamp, a dashed ring
## for an empty box. #59's 7x7 perk glyphs go in the rings; until then the initials stay, in
## mustard pale, as large as fits inside the ring. The final receipt keeps the card face.
##
## Planning effects (#71): hovering a stamped box reports box_hovered / box_unhovered (its
## tooltip stays); set_relation rings a box in gold (the hovered item's cause, or the hovered box
## itself). A rebuild (the upgrades changed) clears it. An upgrade's fizzles show as "pfff"
## stickers with its badge on the belt (PlanningLayer), not on its box.

## The pointer entered or left the stamped box of the run's upgrade `index`.
signal box_hovered(index: int)
signal box_unhovered(index: int)

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

## The chip face's boxes (the 13x13 rings at 2x), their gap, and the initials' sizes: the largest
## that fits inside both rings (CHIP_RING px: the mustard light and mustard texels at 2x, which
## leaves the teal panel's 18 px), down to the smallest.
const CHIP_BOX_SIZE := Vector2(26, 26)
const CHIP_BOX_GAP := 8
const CHIP_RING := 4
const CHIP_INITIALS_SIZES: Array[int] = [12, 11, 10, 9, 8, 7]
## A related box's gold ring (#71): its line, outside the box by RING_OUTSET.
const RING_WIDTH := 2
const RING_OUTSET := 2
const RING_NAME := "RelationRing"

const CARD_FRAME := preload("res://art/frames/loyalty_card.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_empty.png")
const RING := preload("res://art/icons/stamp_ring.png")
const RING_EMPTY := preload("res://art/icons/stamp_ring_empty.png")

var _boxes: HBoxContainer
var _box_count: int = 0
## What the boxes show now, so a refresh only rebuilds them when the upgrades change.
var _shown: Array[UpgradeDefinition] = []
## The top bar's chip face (else the card face).
var _chip: bool = false
var _box_size: Vector2 = BOX_SIZE


## `chip`: the top bar's face; else the card (the final receipt's).
func _init(chip: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = chip
	_box_size = CHIP_BOX_SIZE if chip else BOX_SIZE
	var style: StyleBoxTexture = ArtStyle.frame_style(
		TopBar.CHIP_FRAME if chip else CARD_FRAME, FRAME_MARGIN
	)
	style.content_margin_left = float(TopBar.CHIP_PADDING) if chip else PADDING.x
	style.content_margin_top = 0.0 if chip else PADDING.y
	style.content_margin_right = float(TopBar.CHIP_PADDING) if chip else PADDING.z
	style.content_margin_bottom = 0.0 if chip else PADDING.w
	add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(self)
	if chip:
		custom_minimum_size.y = TopBar.ROW_SIZE.y
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", TopBar.CHIP_SEPARATION if chip else 6)
	add_child(row)
	var title: Label = (
		TopBar.key_label("LOYALTY")
		if chip
		else UiKit.display_label("LOYALTY\nCARD", TITLE_SIZE, false)
	)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_boxes = HBoxContainer.new()
	_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boxes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boxes.add_theme_constant_override("separation", CHIP_BOX_GAP if chip else 4)
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
		var made: PanelContainer = _make_box(upgrade)
		_boxes.add_child(made)
		if upgrade != null:
			_add_relation_parts(made)
			made.mouse_entered.connect(box_hovered.emit.bind(index))
			made.mouse_exited.connect(box_unhovered.emit.bind(index))


## Rings the box of upgrade `index` in gold (#71), or takes the ring off.
func set_relation(index: int, related: bool) -> void:
	var ring: Control = _part(index, RING_NAME)
	if ring != null:
		ring.visible = related


## Whether the box of upgrade `index` is ringed.
func has_relation(index: int) -> bool:
	var ring: Control = _part(index, RING_NAME)
	return ring != null and ring.visible


## Takes every ring off.
func clear_relations() -> void:
	for index: int in range(_shown.size()):
		set_relation(index, false)


## The ring (`part_name`) of upgrade `index`'s box, or null.
func _part(index: int, part_name: String) -> Control:
	var stamped: Control = box(index)
	return stamped.get_node_or_null(part_name) as Control if stamped != null else null


## A stamped box's hidden gold ring (round, just outside the box). It takes no clicks; the box's
## first child stays its label (box_texts).
func _add_relation_parts(stamped: PanelContainer) -> void:
	var ring: Panel = Panel.new()
	ring.name = RING_NAME
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = Palette.GOLD
	line.set_border_width_all(RING_WIDTH)
	line.set_corner_radius_all(int(_box_size.x / 2.0) + RING_OUTSET)
	line.set_expand_margin_all(RING_OUTSET)
	ring.add_theme_stylebox_override("panel", line)
	ring.visible = false
	stamped.add_child(ring)


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
	target.pivot_offset = _box_size / 2.0
	target.scale = Vector2(2.4, 2.4)
	target.rotation = deg_to_rad(-20.0)
	target.modulate.a = 0.0
	var slam: Tween = target.create_tween().set_parallel()
	slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(target, "scale", Vector2.ONE, 0.16)
	slam.tween_property(target, "rotation", stamp_tilt(), 0.16)
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


## A stamped box's resting tilt in radians: STAMP_TILT on the card, upright on the chip (B2).
func stamp_tilt() -> float:
	return 0.0 if _chip else deg_to_rad(STAMP_TILT)


func _tilt_stamped_boxes() -> void:
	for stamped: Control in stamped_boxes():
		if stamped == null:
			continue
		stamped.pivot_offset = _box_size / 2.0
		stamped.rotation = stamp_tilt()


func _make_box(upgrade: UpgradeDefinition) -> PanelContainer:
	if _chip:
		return _make_ring(upgrade)
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


## The chip face's box: B2's ring (dashed when empty) at 2x, the initials in mustard pale at the
## largest CHIP_INITIALS_SIZES size that fits inside the rings.
func _make_ring(upgrade: UpgradeDefinition) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CHIP_BOX_SIZE
	var ring: StyleBoxTexture = StyleBoxTexture.new()
	ring.texture = RING if upgrade != null else RING_EMPTY
	ring.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", ring)
	ArtStyle.use_pixel_material(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = UiKit.number_label("", CHIP_INITIALS_SIZES[0], false)
	label.add_theme_color_override("font_color", Palette.MUSTARD_PALE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	if upgrade == null:
		return panel
	# PASS, not IGNORE: a tooltip needs the mouse.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = tooltip_for(upgrade)
	label.text = initials(upgrade.display_name)
	label.add_theme_font_size_override("font_size", chip_initials_size(label.text))
	return panel


## The largest CHIP_INITIALS_SIZES size at which `text` fits inside the chip's rings (else the
## smallest). Measured with the number font itself: the new box is not in the tree yet, so its
## label ignores theme overrides and would report the default font's width at every size.
static func chip_initials_size(text: String) -> int:
	var inside: float = CHIP_BOX_SIZE.x - 2.0 * CHIP_RING
	var font: Font = ArtStyle.number_font()
	for font_size: int in CHIP_INITIALS_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= inside:
			return font_size
	return CHIP_INITIALS_SIZES[-1]
