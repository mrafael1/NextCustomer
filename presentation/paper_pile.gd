class_name PaperPile
extends Control
## The paper pile (#60, decision D4): a fan-fold stack of receipt paper on the counter at the
## hanging receipt's foot (#55: paper fed from the register's printer onto the counter), a lasting
## record of how much this run has printed. It is drawn in code on the 2 px art grid in the art
## palette: paper-white strips with fold lines and ink caps. It starts with the paper of earlier
## shifts, grows with every receipt line the count-up prints and, after a large total, its top
## curls (a huge one also spills a strip sideways). It is decorative only: the receipt's lines
## never move or rotate with it.
##
## Joined to a receipt (join(), the shift screen's mode; style frame v2's delta), the pile is the
## receipt's paper running on into fan folds on the counter: its top fold spans exactly the
## receipt, each later fold sits FOLD_SHIFT left or right of it, alternately, and every fold has
## an ink cap at both ends and a crease along its top. The receipt ends at most at the pile's top
## (top_y()), so height_changed tells it to fit again whenever that top moves; the shift screen
## shows the pile only while the receipt reaches that top (ShiftStage). Unjoined, it is the plain
## stack of 64 px strips it was in #60.
##
## It stays a self-contained node with a small API: start() for a new row, set_height() as
## lines print, curl() before a large total, and join() to stand under a receipt. The count-up
## drives it and gives it its settle bounce (a scale on its bottom edge; see pivot_offset).

## The paper's top may have moved: start(), set_height() and curl() emit it.
signal height_changed

## One strip of paper, as seen from the side of the stack (its width is strip_width).
const STRIP_SIZE := Vector2(64, 2)
## A fold line every this many pixels of height.
const FOLD_EVERY := 12.0
## Each fold's strips sit this far left or right of the middle, alternately (unjoined).
const SIDE_OFFSET := 2.0
## Joined: the later folds' sideways shift from the receipt's span.
const FOLD_SHIFT := 4.0
## Joined: the crease along each fold's top.
const CREASE_PX := 2.0
const PAPER := Palette.PAPER
const FOLD := Color("c7beab")
const EDGE := ArtStyle.INK
## The ink edges' width (one art pixel).
const EDGE_PX := 2.0
## After a large total the top strip curls up by this much (unjoined).
const CURL_DEGREES := 6.0
## After a huge total one strip spills this far sideways.
const SPILL_PX := 8.0
## Room around the strips for the side offsets, the spill and the curl (joined, the curled top
## fold rises MARGIN.y).
const MARGIN := Vector2(12, 10)

## The paper's height in pixels, at most cap_px.
var height_px: float = 0.0
## The most the pile ever holds, in pixels.
var cap_px: float = 0.0
## The top strip curls (a large total).
var curled: bool = false
## One strip spills sideways (a huge total).
var spilled: bool = false
## The strips' width: STRIP_SIZE.x, or the joined receipt's width.
var strip_width: float = STRIP_SIZE.x
## The receipt the pile is joined to (a sibling), or null.
var _receipt: Control
## Joined: the counter line the pile stands on, in the parent's coordinates.
var _bottom_y: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A new row: the pile holds `start_px` of earlier paper (at most `cap`), flat and tidy.
func start(start_px: float, cap: float) -> void:
	cap_px = maxf(0.0, cap)
	curled = false
	spilled = false
	_resize()
	set_height(start_px)


## The paper's height, clamped to 0..cap_px.
func set_height(px: float) -> void:
	height_px = clampf(px, 0.0, cap_px)
	queue_redraw()
	height_changed.emit()


## A large total: the top strip curls; with `spill` (a huge one) a strip also spills sideways.
func curl(spill: bool) -> void:
	curled = true
	spilled = spill
	queue_redraw()
	height_changed.emit()


## Stands the pile on `bottom_y` (the parent's coordinates) under `receipt`, a sibling added
## before the pile (so the top fold covers the receipt's foot): its strips take the receipt's
## width and its top fold continues the receipt's paper.
func join(receipt: Control, bottom_y: float) -> void:
	_receipt = receipt
	_bottom_y = bottom_y
	strip_width = receipt.size.x
	_resize()


func is_joined() -> bool:
	return _receipt != null


## The paper's top in the parent's coordinates (the layout position, without the settle
## bounce): where a joined receipt ends. With no paper, the bottom.
func top_y() -> float:
	var top: float = position.y + size.y - height_px
	if curled and is_joined() and height_px > 0.0:
		top -= MARGIN.y
	return top


## Where the paper is drawn, in global coordinates (the strips, without the empty margin).
func paper_rect() -> Rect2:
	var local: Rect2
	if is_joined():
		local = Rect2(Vector2((size.x - strip_width) / 2.0, size.y), Vector2(strip_width, 0.0))
		for index: int in range(fold_count()):
			local = local.merge(fold_rect(index))
	else:
		var bottom: float = size.y
		var top: float = bottom - height_px - (MARGIN.y if curled else 0.0)
		var left: float = (
			(size.x - strip_width) / 2.0 - SIDE_OFFSET - (SPILL_PX if spilled else 0.0)
		)
		var right: float = (size.x + strip_width) / 2.0 + SIDE_OFFSET
		local = Rect2(left, top, right - left, bottom - top)
	return get_global_transform() * local


## Joined: the number of folds shown (the bottom one may be cut short).
func fold_count() -> int:
	return ceili(height_px / FOLD_EVERY)


## Joined: fold `index`'s paper in local coordinates, counted from the top (fold 0 spans the
## receipt; curled, it rises MARGIN.y).
func fold_rect(index: int) -> Rect2:
	var paper_top: float = size.y - height_px
	var top: float = paper_top + index * FOLD_EVERY
	var height: float = minf(FOLD_EVERY, height_px - index * FOLD_EVERY)
	var x: float = (size.x - strip_width) / 2.0 + _fold_x(index)
	var rect: Rect2 = Rect2(x, top, strip_width, height)
	if index == 0 and curled:
		rect = rect.grow_side(SIDE_TOP, MARGIN.y)
	return rect


## Joined: the fold that spills on a huge total (a third of the way down; never the top fold),
## or -1.
func spilled_fold() -> int:
	if not spilled or fold_count() < 2:
		return -1
	return maxi(1, floori(fold_count() / 3.0))


func _fold_x(index: int) -> float:
	var x: float = 0.0
	if index > 0:
		x = -FOLD_SHIFT if index % 2 == 1 else FOLD_SHIFT
	if index == spilled_fold():
		x -= SPILL_PX
	return x


func _resize() -> void:
	size = Vector2(strip_width + 2.0 * MARGIN.x, cap_px + MARGIN.y)
	# The settle bounce squashes it on its bottom edge.
	pivot_offset = Vector2(size.x / 2.0, size.y)
	if is_joined():
		position = Vector2(
			_receipt.position.x + (_receipt.size.x - size.x) / 2.0, _bottom_y - size.y
		)


func _draw() -> void:
	if height_px <= 0.0:
		return
	if is_joined():
		_draw_joined()
		return
	var left: float = (size.x - strip_width) / 2.0
	var bottom: float = size.y
	var strips: int = ceili(height_px / STRIP_SIZE.y)
	# A strip a third of the way down from the top spills on a huge total.
	var spilled_strip: int = maxi(0, strips - 1 - floori(strips / 3.0))
	for index: int in range(strips):
		var y: float = index * STRIP_SIZE.y
		var fold: int = floori(y / FOLD_EVERY)
		var x: float = left + (SIDE_OFFSET if fold % 2 == 0 else -SIDE_OFFSET)
		if spilled and index == spilled_strip:
			x -= SPILL_PX
		var strip: Rect2 = Rect2(x, bottom - y - STRIP_SIZE.y, strip_width, STRIP_SIZE.y)
		if curled and index == strips - 1:
			# The top strip lifts at its left end, hinged on its right end.
			var hinge: Vector2 = Vector2(strip.end.x, strip.position.y)
			draw_set_transform(hinge, deg_to_rad(CURL_DEGREES), Vector2.ONE)
			draw_rect(Rect2(-strip_width, 0, strip_width, STRIP_SIZE.y), PAPER)
			draw_rect(Rect2(-strip_width, -EDGE_PX, strip_width, EDGE_PX), EDGE)
			draw_rect(Rect2(-strip_width, 0, EDGE_PX, STRIP_SIZE.y), EDGE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		draw_rect(strip, PAPER)
		if fmod(y, FOLD_EVERY) == 0.0 and index > 0:
			draw_rect(Rect2(x, strip.end.y - 1.0, strip_width, 1.0), FOLD)
		# The ink cap on the left end, and the ink edge on the top strip.
		draw_rect(Rect2(x, strip.position.y, EDGE_PX, STRIP_SIZE.y), EDGE)
		if index == strips - 1:
			draw_rect(Rect2(x, strip.position.y - EDGE_PX, strip_width, EDGE_PX), EDGE)


## The receipt's paper running on into folds: each with a crease along its top (fold 0's is the
## join with the receipt's foot) and an ink cap at both ends; the bottom fold rests on the
## counter on an ink edge. A curled top fold shows a second crease where it lifted from.
func _draw_joined() -> void:
	for index: int in range(fold_count()):
		var strip: Rect2 = fold_rect(index)
		draw_rect(strip, PAPER)
		draw_rect(Rect2(strip.position, Vector2(strip.size.x, CREASE_PX)), FOLD)
		if index == 0 and curled:
			var lip: float = strip.position.y + MARGIN.y
			draw_rect(Rect2(strip.position.x, lip, strip.size.x, CREASE_PX), FOLD)
		draw_rect(Rect2(strip.position, Vector2(EDGE_PX, strip.size.y)), EDGE)
		draw_rect(Rect2(strip.end.x - EDGE_PX, strip.position.y, EDGE_PX, strip.size.y), EDGE)
	var last: Rect2 = fold_rect(fold_count() - 1)
	draw_rect(Rect2(last.position.x, size.y - EDGE_PX, last.size.x, EDGE_PX), EDGE)
