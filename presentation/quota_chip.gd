class_name QuotaChip
extends PanelContainer
## The lasting "QUOTA" chip (#60, decision D5): a drawn check icon and a label, so the quota
## being met never shows by colour alone. The count-up pops it in beside the subtotal when the
## subtotal reaches the quota; it stays there until the next count-up frees it, and hides while
## the subtotal shows nothing (planning the next shift).

const TEXT := "QUOTA"
## Pixels between the subtotal's text and the chip.
const GAP := 12.0

## The subtotal label it sits beside, or null.
var _label: Label


func _init() -> void:
	name = "QuotaChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.GOOD
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	# The check is drawn, not a glyph, so every font shows it.
	var icon: Control = Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var check: Line2D = Line2D.new()
	check.width = 3.0
	check.default_color = Palette.INK
	check.points = PackedVector2Array([Vector2(2, 9), Vector2(6, 13), Vector2(14, 3)])
	icon.add_child(check)
	row.add_child(icon)
	var text: Label = Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = TEXT
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Palette.INK)
	row.add_child(text)


## Sits just right of `label`'s text from now on, every frame.
func follow(label: Label) -> void:
	_label = label
	_place()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if _label == null or not is_instance_valid(_label):
		visible = false
		return
	visible = _label.is_visible_in_tree() and not _label.text.is_empty()
	size = get_combined_minimum_size()
	pivot_offset = size / 2.0
	# The label's layout rect, without a punch's scale.
	var origin: Vector2 = _label.position
	var parent: CanvasItem = _label.get_parent() as CanvasItem
	if parent != null:
		origin = parent.get_global_transform() * origin
	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right: float = origin.x + width
	match _label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			right = origin.x + (_label.size.x + width) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			right = origin.x + _label.size.x
	var middle: float = origin.y + _label.size.y / 2.0
	# The layout position: the pop scales the chip on its centre.
	_move_to(Vector2(right + GAP, middle - size.y / 2.0))


## Moves the layout position (not the scaled one) so the top-left sits at `point` (global).
func _move_to(point: Vector2) -> void:
	var parent: CanvasItem = get_parent() as CanvasItem
	position = parent.get_global_transform().affine_inverse() * point if parent != null else point
