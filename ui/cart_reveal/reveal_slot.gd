class_name RevealSlot
extends Control
## An empty place in the cart reveal's cart (mock-up cart_reveal_v1.html, v0.51): a 100x120
## dashed outline with a "?" in it, teal shade for a product, tomato for the coupon. Its pick's
## tile covers it when it lands.

const DASH := 6.0
const LINE := 2.0
const MARK_SIZE := 30

var color: Color = Palette.TEAL_SHADE
var _mark: Label


func _init(coupon: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = RevealTile.SIZE
	color = Palette.TOMATO if coupon else Palette.TEAL_SHADE
	_mark = UiKit.body_label("?", MARK_SIZE, color)
	_mark.add_theme_font_override("font", CartReveal.font(800))
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mark.size = size
	add_child(_mark)


## A dashed `rect` outline (LINE px wide, inside the rect) on `item`, dashes `dash` px long.
static func dashed_rect(item: CanvasItem, rect: Rect2, line_color: Color, dash: float) -> void:
	var half: float = LINE / 2.0
	var inner: Rect2 = rect.grow(-half)
	var corners: Array[Vector2] = [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y),
	]
	for side: int in corners.size():
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % corners.size()]
		item.draw_dashed_line(from, to, line_color, LINE, dash, false)


func _draw() -> void:
	dashed_rect(self, Rect2(Vector2.ZERO, size), color, DASH)
