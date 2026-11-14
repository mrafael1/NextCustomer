class_name SpotlightShade
extends Control
## The tutorial's dim (tutorial plan section 1.3, mock-up docs/art/mockups/tutorial.html): it
## shades its rect but its holes (the rings' rects, padded) and, unlike ScreenShade, lets every
## click inside a hole through to what lies under it, while it takes the clicks everywhere else
## (outside_clicked, so the callout can shake). Gating stays logical in the screens' handlers: the
## shade only keeps a stray click from landing. `dimmed` off keeps the clicks but draws nothing.

signal outside_clicked

## The dim's colour (the mock-up's rgba(8,18,18,.52), the art's teal black).
const DIM := Color(Palette.TEAL_BLACK, 0.52)

var color: Color = DIM
## Whether it draws (it takes the clicks outside its holes either way).
var dimmed: bool = true:
	set(value):
		dimmed = value
		queue_redraw()
## The holes, in global coordinates.
var _holes: Array[Rect2] = []


func _init() -> void:
	name = "SpotlightShade"
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets the holes (global rects; none shades everything) and redraws.
func set_holes(rects: Array[Rect2]) -> void:
	_holes = []
	for rect: Rect2 in rects:
		if rect.has_area():
			_holes.append(rect)
	queue_redraw()


## The holes (global).
func holes() -> Array[Rect2]:
	return _holes.duplicate()


## Whether the global `point` lies in a hole (a click there goes through).
func in_hole(point: Vector2) -> bool:
	for hole: Rect2 in _holes:
		if hole.has_point(point):
			return true
	return false


## The rects it dims (global): its rect less every hole, as non-overlapping bands (so the dim
## never doubles where two cut-outs meet).
func shaded_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [get_global_rect()]
	for hole: Rect2 in _holes:
		var next: Array[Rect2] = []
		for rect: Rect2 in rects:
			next.append_array(_cut(rect, hole))
		rects = next
	return rects


## A hole lets the click through: the point is not this control's (`point` is local).
func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	return not in_hole(get_global_transform() * point)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		outside_clicked.emit()


func _draw() -> void:
	if not dimmed:
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	for rect: Rect2 in shaded_rects():
		draw_rect(to_local * rect, color)


## `rect` less `hole`: up to four bands (above, under, and beside it on its rows).
static func _cut(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var cut: Rect2 = rect.intersection(hole)
	if not cut.has_area():
		return [rect]
	var parts: Array[Rect2] = [
		Rect2(rect.position.x, rect.position.y, rect.size.x, cut.position.y - rect.position.y),
		Rect2(rect.position.x, cut.end.y, rect.size.x, rect.end.y - cut.end.y),
		Rect2(rect.position.x, cut.position.y, cut.position.x - rect.position.x, cut.size.y),
		Rect2(cut.end.x, cut.position.y, rect.end.x - cut.end.x, cut.size.y),
	]
	var kept: Array[Rect2] = []
	for part: Rect2 in parts:
		if part.has_area():
			kept.append(part)
	return kept
