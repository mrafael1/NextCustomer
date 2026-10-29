class_name RoomSpot
extends Control
## One free spot of the cart on the deck view's shelves while a machine prize is placed
## (2026-10-29, CartPlacing; mock-up pick_skip_cart.html): a dashed gold outline round an item's
## column that pulses while the prize is held. `hot` (the held prize over it) fills it and shows
## "+1" at its top (clear of the held item, which shrinks over the pointer): dropping there adds
## the prize to the cart.

const PULSE_RATE := 4.0
const DASH := 6.0
const LINE := 3.0
const FILL_ALPHA := 0.12
const PULSE_ALPHA := 0.12
const HOT_ALPHA := 0.32
const TEXT := "+1"
const TEXT_SIZE := 28
const TEXT_HEIGHT := 40.0

## The held prize is over it.
var hot: bool = false:
	set(value):
		hot = value
		_plus.visible = value
		queue_redraw()
var _t: float = 0.0
var _plus: Label


func _init() -> void:
	name = "RoomSpot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = DeckCell.SIZE
	size = DeckCell.SIZE
	_plus = UiKit.display_label(TEXT, TEXT_SIZE, true)
	_plus.add_theme_color_override("font_color", Palette.GOLD)
	_plus.add_theme_color_override("font_shadow_color", Palette.INK)
	_plus.add_theme_constant_override("shadow_offset_y", 2)
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus.position = Vector2.ZERO
	_plus.size = Vector2(column_rect().size.x, TEXT_HEIGHT)
	_plus.visible = false
	add_child(_plus)


## The spot's outline: an item's column (its sprite and sticker), in this spot's coordinates.
static func column_rect() -> Rect2:
	return Rect2(Vector2.ZERO, ItemView.TRAY_SIZE)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = column_rect()
	var pulse: float = 0.5 + 0.5 * sin(_t * PULSE_RATE)
	var alpha: float = HOT_ALPHA if hot else FILL_ALPHA + PULSE_ALPHA * pulse
	draw_rect(rect, Color(Palette.GOLD, alpha))
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	for side: int in range(4):
		draw_dashed_line(corners[side], corners[(side + 1) % 4], Palette.GOLD, LINE, DASH)
