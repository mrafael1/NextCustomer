class_name InspectionTag
extends PanelContainer
## The current shift's inspection in the top bar (plan section 3.9): a red tag with its notice,
## visible for the whole shift, so the restriction is never shown only inside an animation.
## Hidden on shifts without an inspection. Inspections never go on the loyalty card.

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"

var _label: Label


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.TOMATO
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)
	_label = UiKit.label("", 15, Palette.PAPER)
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
