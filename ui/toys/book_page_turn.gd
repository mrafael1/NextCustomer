class_name BookPageTurn
extends Control
## The FIGURINE BOOK's page turn (v1.30 round 2): a sleeve page swinging over the rings, drawn on
## the 2 px art grid. Turning forward, the right page lifts and narrows towards the spine (the
## next spread's right page shows from under it), then opens over the left page and lands; back,
## the same mirrored. Its width follows an ease in and out over TURN_S, in whole art px every
## frame; the sheet is the pages' slate with its pockets foreshortened and a pale edge where it
## bends. It carries its cards (review fix: the sheet was empty): the page leaving rides its front
## for the first half, squeezed towards the spine with it, and the page arriving its back for the
## second half, each darker the more edge-on it stands. FigurineBook hands it the two pages
## (play's `front` and `back`, its children while it turns) and takes them back when it lands
## (turned).

signal turned

const TURN_S := 0.24
## The sheet's shadow on the page under it and how far it bows out at most (art px).
const SHADOW := 4
const BOW := 6
## How dark a page on the sheet gets edge-on (its modulate's value, 1 when flat).
const EDGE_ON_SHADE := 0.55

## The turn's progress, 0 to 1 (-1: at rest).
var _t: float = -1.0
var _forward: bool = true
var _front: Control
var _back: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BookArt.STAGE) * ArtStyle.ART_SCALE
	visible = false


## Starts a turn (forward: the right page goes over to the left) carrying `front` (the page
## leaving, shown on the sheet's first half) and `back` (the page arriving, on its second half):
## page layers the size of the stage, children of this while it turns.
func play(forward: bool, front: Control = null, back: Control = null) -> void:
	_forward = forward
	_front = front
	_back = back
	_t = 0.0
	visible = true
	_fit_faces()
	queue_redraw()


## The pages on the sheet: its front (leaving) and back (arriving); empty at rest.
func faces() -> Array[Control]:
	var found: Array[Control] = []
	for face: Control in [_front, _back] as Array[Control]:
		if face != null:
			found.append(face)
	return found


func is_turning() -> bool:
	return _t >= 0.0


## Sets the turn `seconds` in (for tests and the screen capture; past TURN_S it lands).
func seek(seconds: float) -> void:
	if _t < 0.0:
		return
	_t = clampf(seconds / TURN_S, 0.0, 1.0)
	if _t >= 1.0:
		finish()
	else:
		_fit_faces()
		queue_redraw()


## Lands the turn now: the faces are let go (back flat and unshaded) and `turned` tells the book
## to take them.
func finish() -> void:
	if _t < 0.0:
		return
	_t = -1.0
	visible = false
	for face: Control in faces():
		face.scale = Vector2.ONE
		face.modulate = Color.WHITE
	_front = null
	_back = null
	turned.emit()


## The sheet's rect now, in stage art px (empty at rest).
func sheet_rect() -> Rect2i:
	if _t < 0.0:
		return Rect2i()
	var eased: float = _t * _t * (3.0 - 2.0 * _t)
	var page: Rect2i = BookArt.PAGE_RECTS[0]
	var spine: Rect2i = BookArt.SPINE_RECT
	var top: int = page.position.y
	var height: int = page.size.y
	var first_half: bool = eased < 0.5
	var share: float = 1.0 - eased * 2.0 if first_half else eased * 2.0 - 1.0
	var width: int = maxi(roundi(page.size.x * share / 2.0) * 2, 2)
	var on_right: bool = first_half == _forward
	if on_right:
		return Rect2i(spine.end.x, top, width, height)
	return Rect2i(spine.position.x - width, top, width, height)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta / TURN_S
	if _t >= 1.0:
		finish()
	else:
		_fit_faces()
		queue_redraw()


## The page on the sheet now squeezed to it from the spine (the front on the first half, the back
## on the second), shaded the more edge-on it stands; the other face hidden.
func _fit_faces() -> void:
	var sheet: Rect2i = sheet_rect()
	var on_right: bool = sheet.position.x >= BookArt.SPINE_RECT.end.x
	var first_half: bool = on_right == _forward
	var room: Rect2i = BookArt.PAGE_RECTS[1 if on_right else 0]
	var share: float = float(sheet.size.x) / float(room.size.x)
	var art: float = ArtStyle.ART_SCALE
	for face: Control in faces():
		var shown: bool = (face == _front) == first_half
		face.visible = shown
		if not shown:
			continue
		var spine_x: int = BookArt.SPINE_RECT.end.x if on_right else BookArt.SPINE_RECT.position.x
		face.pivot_offset = Vector2(spine_x * art, 0.0)
		face.scale = Vector2(share, 1.0)
		var value: float = lerpf(EDGE_ON_SHADE, 1.0, share)
		face.modulate = Color(value, value, value)


func _draw() -> void:
	var sheet: Rect2i = sheet_rect()
	if not sheet.has_area():
		return
	var on_right: bool = sheet.position.x >= BookArt.SPINE_RECT.end.x
	var room: Rect2i = BookArt.PAGE_RECTS[1 if on_right else 0]
	var shadow_x: int = sheet.end.x if on_right else sheet.position.x - SHADOW
	var shade: Rect2i = Rect2i(shadow_x, sheet.position.y, SHADOW, sheet.size.y).intersection(room)
	_rect(shade, Color(Palette.INK, 0.35))
	# The sheet stands taller the further it is from the spine (the page bowing towards you),
	# most when it is upright (narrowest), in 2 px columns.
	var share: float = float(sheet.size.x) / float(room.size.x)
	var bow: int = roundi(BOW * (1.0 - share))
	for step: int in range(0, sheet.size.x, 2):
		var from_spine: int = step if on_right else sheet.size.x - step - 2
		var extra: int = roundi(bow * float(from_spine) / float(maxi(sheet.size.x, 1)))
		var column: Rect2i = Rect2i(
			sheet.position.x + step, sheet.position.y - extra, 2, sheet.size.y + extra * 2
		)
		_rect(column, Palette.INK)
		_rect(column.grow_individual(0, -1, 0, -1), Palette.SLATE)
	var inner: Rect2i = sheet.grow(-1)
	if not inner.has_area():
		return
	var squeeze: float = float(inner.size.x) / float(room.size.x)
	for column: int in BookArt.COLUMNS:
		for row: int in BookArt.ROWS:
			var origin: Vector2i = (
				BookArt.POCKET_ORIGIN + Vector2i(column, row) * BookArt.POCKET_PITCH
			)
			var left: int = roundi(origin.x * squeeze)
			var width: int = maxi(roundi(BookArt.POCKET_SIZE.x * squeeze), 1)
			if not on_right:
				left = inner.size.x - left - width
			var pocket: Rect2i = Rect2i(
				inner.position.x + left, sheet.position.y + origin.y, width, BookArt.POCKET_SIZE.y
			)
			_rect(pocket, Palette.TEAL_SHADE)
			_rect(pocket.grow(-1), Palette.SLATE_DARK)
	var edge_x: int = sheet.end.x - 2 if on_right else sheet.position.x
	var edge: Rect2i = Rect2i(edge_x, sheet.position.y - bow + 1, 2, sheet.size.y + bow * 2 - 2)
	_rect(edge, Palette.TEAL_PALE)


func _rect(area: Rect2i, colour: Color) -> void:
	if not area.has_area():
		return
	var art: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(Vector2(area.position) * art, Vector2(area.size) * art), colour)
