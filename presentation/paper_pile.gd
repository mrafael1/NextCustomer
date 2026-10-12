class_name PaperPile
extends Control
## The paper pile (#60, decision D4): a placeholder fan-fold stack of receipt paper beside the
## receipt, a lasting record of how much this run has printed. It starts with the paper of
## earlier shifts, grows with every receipt line the count-up prints and, after a large total,
## its top strip curls (a huge one also spills a strip sideways). It is decorative only: the
## receipt's lines never move or rotate with it.
##
## #55's register and scanner prop re-skins it, so it stays a self-contained node with a small
## API: start() for a new row, set_height() as lines print, curl() before a large total, and
## follow() to sit at a receipt's bottom-left corner. The count-up drives it and gives it its
## settle bounce (a scale on its bottom edge; see pivot_offset).

## One strip of paper, as seen from the side of the stack.
const STRIP_SIZE := Vector2(64, 2)
## A fold line every this many pixels of height.
const FOLD_EVERY := 12.0
## Each fold's strips sit this far left or right of the middle, alternately.
const SIDE_OFFSET := 2.0
const PAPER := Color("f3eedf")
const FOLD := Color("c9c1ae")
## After a large total the top strip curls up by this much.
const CURL_DEGREES := 6.0
## After a huge total one strip spills this far sideways.
const SPILL_PX := 8.0
## Room around the strips for the side offsets, the spill and the curl.
const MARGIN := Vector2(12, 10)
## How much of the pile hides behind the followed control's left edge.
const BEHIND_PX := 12.0

## The paper's height in pixels, at most cap_px.
var height_px: float = 0.0
## The most the pile ever holds, in pixels.
var cap_px: float = 0.0
## The top strip curls (a large total).
var curled: bool = false
## One strip spills sideways (a huge total).
var spilled: bool = false
## The control whose bottom-left corner the pile sits at, or null.
var _follow: Control


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


## A large total: the top strip curls; with `spill` (a huge one) a strip also spills sideways.
func curl(spill: bool) -> void:
	curled = true
	spilled = spill
	queue_redraw()


## Sits the pile at `target`'s bottom-left corner every frame, mostly beside it and partly
## behind it (add the pile before the target, so the target draws over it). Null stops.
func follow(target: Control) -> void:
	_follow = target
	_place()


## Where the paper is drawn, in global coordinates (the strips, without the empty margin).
func paper_rect() -> Rect2:
	var bottom: float = size.y
	var top: float = bottom - height_px - (MARGIN.y if curled else 0.0)
	var left: float = (size.x - STRIP_SIZE.x) / 2.0 - SIDE_OFFSET - (SPILL_PX if spilled else 0.0)
	var right: float = (size.x + STRIP_SIZE.x) / 2.0 + SIDE_OFFSET
	var local: Rect2 = Rect2(left, top, right - left, bottom - top)
	return get_global_transform() * local


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if _follow == null or not is_instance_valid(_follow) or not _follow.is_inside_tree():
		return
	var rect: Rect2 = _follow.get_global_rect()
	# The layout position: the settle bounce scales the pile on its bottom edge.
	_move_to(Vector2(rect.position.x - size.x + BEHIND_PX, rect.end.y - size.y))


## Moves the layout position (not the scaled one) so the top-left sits at `point` (global).
func _move_to(point: Vector2) -> void:
	var parent: CanvasItem = get_parent() as CanvasItem
	position = parent.get_global_transform().affine_inverse() * point if parent != null else point


func _resize() -> void:
	size = Vector2(STRIP_SIZE.x + 2.0 * MARGIN.x, cap_px + MARGIN.y)
	# The settle bounce squashes it on its bottom edge.
	pivot_offset = Vector2(size.x / 2.0, size.y)
	_place()


func _draw() -> void:
	if height_px <= 0.0:
		return
	var left: float = (size.x - STRIP_SIZE.x) / 2.0
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
		var strip: Rect2 = Rect2(x, bottom - y - STRIP_SIZE.y, STRIP_SIZE.x, STRIP_SIZE.y)
		if curled and index == strips - 1:
			# The top strip lifts at its left end, hinged on its right end.
			var hinge: Vector2 = Vector2(strip.end.x, strip.position.y)
			draw_set_transform(hinge, deg_to_rad(CURL_DEGREES), Vector2.ONE)
			draw_rect(Rect2(-STRIP_SIZE.x, 0, STRIP_SIZE.x, STRIP_SIZE.y), PAPER)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		draw_rect(strip, PAPER)
		if fmod(y, FOLD_EVERY) == 0.0 and index > 0:
			draw_rect(Rect2(x, strip.end.y - 1.0, STRIP_SIZE.x, 1.0), FOLD)
