class_name InspectionTag
extends PanelContainer
## The current shift's inspection in the top bar (plan section 3.9): the red inspection_tag frame
## (#55) with its notice in the body font, visible for the whole shift, so the restriction is
## never shown only inside an animation. Hidden on shifts without an inspection. Inspections
## never go on the loyalty card.

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"
## The tag's 9-slice margin in art pixels, and its padding: left, top, right, bottom.
const FRAME_MARGIN := 3
const PADDING := Vector4(10, 4, 10, 6)
const FONT_SIZE := 15

const TAG_FRAME := preload("res://art/frames/inspection_tag.png")

var _label: Label


func _init() -> void:
	var style: StyleBoxTexture = ArtStyle.frame_style(TAG_FRAME, FRAME_MARGIN)
	style.content_margin_left = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_right = PADDING.z
	style.content_margin_bottom = PADDING.w
	add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(self)
	_label = UiKit.body_label("", FONT_SIZE, Palette.PAPER)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Palette.INK)
	add_child(_label)
	visible = false


## Shows the shift's inspections (empty: hidden). Hovering shows each one's name and notice.
func show_inspections(inspections: Array[InspectionDefinition]) -> void:
	visible = not inspections.is_empty()
	var notices: PackedStringArray = PackedStringArray()
	var tips: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		notices.append(inspection.notice_text)
		tips.append("INSPECTION: %s\n%s" % [inspection.display_name, inspection.notice_text])
	_label.text = "INSPECTION  " + "  ·  ".join(notices)
	tooltip_text = "\n\n".join(tips)


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


## The notice for the next shift's inspection, or "" when it isn't inspected.
static func next_notice(next_inspection: InspectionDefinition) -> String:
	if next_inspection == null:
		return ""
	return NEXT_NOTICE % next_inspection.notice_text
