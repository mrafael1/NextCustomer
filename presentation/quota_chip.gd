class_name QuotaChip
extends PanelContainer
## The lasting "QUOTA" chip (#60, decision D5): a drawn check icon and a label, so the quota
## being met never shows by colour alone. The count-up pops it in on the register LED's quota
## line (#55: LedDisplay.quota_anchor(), over "QUOTA €N") when the subtotal reaches the quota; it
## stays there until the next count-up frees it, and hides while its anchor is empty (the LED
## showing the next shift's projected total, or nothing).

const TEXT := "QUOTA"
const FONT_SIZE := 18
## The compact face that fits the LED's quota line: a smaller text and thinner margins.
const COMPACT_FONT_SIZE := 14
const COMPACT_MARGIN := 1
const MARGIN := 2
## The chip's room past the text it covers, so its border stays off the glyphs.
const COVER_SLACK := 2.0

## Returns the global rect the chip sits in (right-aligned, centred vertically); an empty rect
## hides it. Empty Callable: no anchor yet.
var _anchor: Callable
## Returns the width of the right-aligned text the chip covers (LedDisplay.quota_text_width());
## the chip is at least that wide plus COVER_SLACK, up to its anchor's width. Empty Callable: the
## chip's own minimum width.
var _cover_width: Callable
var _style: StyleBoxFlat
var _text: Label


func _init() -> void:
	name = "QuotaChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.GOOD
	_style.border_color = Palette.INK
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	_style.content_margin_left = 6
	_style.content_margin_right = 8
	_style.content_margin_top = MARGIN
	_style.content_margin_bottom = MARGIN
	add_theme_stylebox_override("panel", _style)
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
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.text = TEXT
	_text.add_theme_font_size_override("font_size", FONT_SIZE)
	_text.add_theme_color_override("font_color", Palette.INK)
	row.add_child(_text)


## Sits in `anchor`'s rect from now on, every frame: right-aligned and centred vertically in
## it, hidden while it is empty. `cover_width`, when given, returns the width of the
## right-aligned text the chip covers (the LED's "QUOTA €N"), and the chip widens to cover it.
## `compact` gives the smaller face that fits the LED's quota line.
func follow_anchor(
	anchor: Callable, cover_width: Callable = Callable(), compact: bool = true
) -> void:
	_anchor = anchor
	_cover_width = cover_width
	_text.add_theme_font_size_override("font_size", COMPACT_FONT_SIZE if compact else FONT_SIZE)
	var vertical: int = COMPACT_MARGIN if compact else MARGIN
	_style.content_margin_top = vertical
	_style.content_margin_bottom = vertical
	_place()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	var rect: Rect2 = _anchor.call() as Rect2 if _anchor.is_valid() else Rect2()
	visible = rect.has_area()
	if not visible:
		return
	var minimum: Vector2 = get_combined_minimum_size()
	var width: float = minimum.x
	if _cover_width.is_valid():
		var cover: float = ceilf(_cover_width.call() as float) + COVER_SLACK
		width = minf(maxf(width, cover), rect.size.x)
	size = Vector2(width, minimum.y)
	pivot_offset = size / 2.0
	# The layout position: the pop scales the chip on its centre.
	_move_to(Vector2(rect.end.x - size.x, rect.get_center().y - size.y / 2.0))


## Moves the layout position (not the scaled one) so the top-left sits at `point` (global).
func _move_to(point: Vector2) -> void:
	var parent: CanvasItem = get_parent() as CanvasItem
	position = parent.get_global_transform().affine_inverse() * point if parent != null else point
