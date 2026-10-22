class_name ScreenShade
extends Control
## The shift screen's shade (#61, #80, #77): it dims the screen behind the RECEIPT REWARDS
## machine, the deck view and the results, and takes every click on its rect, so nothing behind
## it can be picked. It may leave one hole unshaded (set_hole; the machine leaves none). The hole
## still takes the clicks: only its dimming is left out.

## The shade's colour.
var color: Color = Color(0, 0, 0, 0.5)
## The unshaded hole, in global coordinates (none when it has no area).
var _hole: Rect2 = Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var to_local: Transform2D = get_global_transform().affine_inverse()
	for rect: Rect2 in shaded_rects():
		draw_rect(to_local * rect, color)


## Leaves `rect` (global) unshaded from now on; an empty rect shades everything again. Redraws,
## as the shade's own rect may have moved since (the owner sets both every frame).
func set_hole(rect: Rect2) -> void:
	_hole = rect
	queue_redraw()


## The unshaded hole (global), or an empty rect.
func hole() -> Rect2:
	return _hole


## The rects the shade dims (global): its rect but the hole, as up to four bands (above the hole,
## under it, and beside it on the hole's rows).
func shaded_rects() -> Array[Rect2]:
	var area: Rect2 = get_global_rect()
	var cut: Rect2 = area.intersection(_hole)
	if not cut.has_area():
		return [area]
	var rects: Array[Rect2] = [
		Rect2(area.position.x, area.position.y, area.size.x, cut.position.y - area.position.y),
		Rect2(area.position.x, cut.end.y, area.size.x, area.end.y - cut.end.y),
		Rect2(area.position.x, cut.position.y, cut.position.x - area.position.x, cut.size.y),
		Rect2(cut.end.x, cut.position.y, area.end.x - cut.end.x, cut.size.y),
	]
	var shaded: Array[Rect2] = []
	for rect: Rect2 in rects:
		if rect.has_area():
			shaded.append(rect)
	return shaded
