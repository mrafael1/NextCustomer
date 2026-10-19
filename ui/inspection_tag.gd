class_name InspectionTag
extends PanelContainer
## The current shift's inspection in the top bar (plan section 3.9; #80 step 10, mock-up B2): a
## paper chip with the mustard warning sign and "Inspection · <effect>" in the body font (each
## inspection's chip_text, from data, e.g. "Inspection · −1 slot"), visible for the whole shift, so
## the restriction is never shown only inside an animation. Hovering it shows each inspection's
## name and notice. Hidden on shifts without an inspection. Inspections never go on the loyalty
## card.
##
## Planning effects (#71): hovering it reports hovered / unhovered (its tooltip stays);
## set_relation rings it in gold and, for an inspection that causes the hovered item's effect,
## prints that inspection's name instead of the effects (one tag shows every inspection). The
## items it hits show its stamp on the belt (PlanningLayer), so the chip carries no count.

## The pointer entered or left the tag.
signal hovered
signal unhovered

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"
const FONT_SIZE := 14
const FONT_WEIGHT := 700
## The warning sign (13x11 art) at 2x.
const ICON_SIZE := Vector2(26, 22)
## The gold ring's line (#71).
const RING_WIDTH := 2.0

const CHIP_FRAME := preload("res://art/frames/chip_warn.png")
const WARNING := preload("res://art/icons/warning.png")

var _label: Label
var _inspections: Array[InspectionDefinition] = []
## The effects' text (show_inspections), printed while no cause is named.
var _effects_text: String = ""
var _ringed: bool = false


func _init() -> void:
	name = "InspectionTag"
	var style: StyleBoxTexture = ArtStyle.frame_style(CHIP_FRAME, FramedButton.FRAME_MARGIN)
	style.content_margin_left = TopBar.CHIP_PADDING
	style.content_margin_right = TopBar.CHIP_PADDING
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.y = TopBar.ROW_SIZE.y
	ArtStyle.use_pixel_material(self)
	# PASS, not IGNORE: the tooltip needs the mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", TopBar.CHIP_SEPARATION)
	add_child(row)
	var icon: TextureRect = UiKit.sprite(WARNING)
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_label = UiKit.body_label("", FONT_SIZE, Palette.INK)
	_label.add_theme_font_override("font", ArtStyle.bold_font(FONT_WEIGHT))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A named inspection keeps the chip's width (set_relation).
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	visible = false


## Shows the shift's inspections by their effects (empty: hidden). Hovering shows each one's
## name and notice.
func show_inspections(inspections: Array[InspectionDefinition]) -> void:
	visible = not inspections.is_empty()
	_inspections = inspections.duplicate()
	var tips: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		tips.append("INSPECTION: %s\n%s" % [inspection.display_name, inspection.notice_text])
	_effects_text = " · ".join(PackedStringArray(["Inspection"]) + effects(inspections))
	_label.text = _effects_text
	custom_minimum_size.x = 0.0
	tooltip_text = "\n\n".join(tips)


## Rings the tag in gold (#71), or takes the ring off. `cause`: the shift's inspection (its
## index) that causes the hovered item's effect: the tag prints its name until the ring comes off,
## keeping its width meanwhile (a shorter name would shift the top bar under the pointer).
func set_relation(related: bool, cause: int = -1) -> void:
	_ringed = related
	var named: bool = related and cause >= 0 and cause < _inspections.size()
	if named and _label.text == _effects_text:
		custom_minimum_size.x = size.x
	elif not named:
		custom_minimum_size.x = 0.0
	_label.text = _inspections[cause].display_name if named else _effects_text
	queue_redraw()


func has_relation() -> bool:
	return _ringed


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit()
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit()


## The gold ring round the chip while it is related to the hovered item (over the frame).
func _draw() -> void:
	if _ringed:
		draw_rect(
			Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0), Palette.GOLD, false, RING_WIDTH
		)


## The label printing the text (for layout tests).
func label() -> Label:
	return _label


## The tag's text (for tests).
func text() -> String:
	return _label.text


## Where each of the shift's inspections is shown (all on this tag), indexed like the shift's
## inspections (a step's source_index), for the count-up.
func sources(inspections: Array[InspectionDefinition]) -> Array[Control]:
	var controls: Array[Control] = []
	for _inspection: InspectionDefinition in inspections:
		controls.append(self)
	return controls


## The inspections' names, indexed like the shift's inspections, for the receipt.
static func names(inspections: Array[InspectionDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		result.append(inspection.display_name)
	return result


## The inspections' chip texts (the name for one without), indexed like the shift's inspections.
static func effects(inspections: Array[InspectionDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		var effect: String = inspection.chip_text
		result.append(effect if not effect.is_empty() else inspection.display_name)
	return result


## The notice for the next shift's inspection, or "" when it isn't inspected.
static func next_notice(next_inspection: InspectionDefinition) -> String:
	if next_inspection == null:
		return ""
	return NEXT_NOTICE % next_inspection.notice_text
