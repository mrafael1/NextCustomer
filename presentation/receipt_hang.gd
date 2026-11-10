class_name ReceiptHang
extends RefCounted
## The shift screen's receipt hanging from the overhead printer (left column v2, the user's pick of
## 2026-11-09: mock-up docs/art/mockups/left_column_v2.html, its receiptDown(), stubDown() and
## tail()): ReceiptView's fit-down mode (fit_up with `hang`). The paper's top, its header, stays at
## the printer's slot and the paper feeds DOWN: at an anchored count each new line lengthens it
## over FEED_SECONDS (several at once: up to FEED_MAX_SECONDS), in whole art px, so the line
## prints at its free end; the next planning after a count POPS the new stub out of the slot
## (POP: its fraction out over time, overshooting and settling), the paper's slot clipping what is
## still inside. Under the paper's foot hangs a torn edge (draw_tail). Display only: the view says
## how tall its lines are.

## The feed: a line's length in FEED_SECONDS, several lines at once in FEED_MAX_SECONDS at most.
const FEED_SECONDS := 0.14
const FEED_MAX_SECONDS := 0.42
## The pitch a line's feed is timed by (ReceiptRows.MAX_PITCH).
const LINE_PX := ReceiptRows.MAX_PITCH
## The next day's stub's pop (the mock-up's POP): [ms, fraction of the stub out of the slot].
const POP: Array[Vector2] = [
	Vector2(0, 0.0),
	Vector2(60, 0.55),
	Vector2(120, 1.0375),
	Vector2(170, 1.0375),
	Vector2(210, 0.9875),
	Vector2(250, 1.0),
]
## The torn tail: a TAIL_MARGIN art px strip in the paper's face over its foot's outline, then
## teeth 1 and 2 art px long by turns, each with an ink tip.
const TAIL_MARGIN := 3
const TAIL_TEETH := 2

## Called after each feed step (the view keeps its newest line in view).
var on_step: Callable = Callable()

var _view: Control
## The slot's y (the view's parent's px): the paper's top.
var _top: float = 0.0
var _feed: Tween
var _pop: Tween
## The pop's clock (s; below 0: no pop).
var _pop_t: float = -1.0


## Hangs `view` from `top` (its parent's px).
func _init(view: Control, top: float) -> void:
	_view = view
	_top = top


## The paper `tall` px long: fed down to it (`feed`: a count's new lines, unless it shrinks or a
## pop plays), else at once; its top on the slot.
func fit(tall: float, feed: bool) -> void:
	var grows: bool = tall > _view.size.y + 0.5 and _view.size.y > 0.0
	if feed and grows and _pop_t < 0.0 and _view.is_inside_tree():
		_feed_to(tall)
	elif not is_feeding() or tall < _view.size.y:
		stop_feed()
		_view.size.y = tall
	place()


## The paper's top: the slot, less the stub's part still inside it while it pops (whole art px).
func place() -> void:
	var cell: float = ArtStyle.ART_SCALE
	var out: float = pop_fraction(_pop_t * 1000.0) if _pop_t >= 0.0 else 1.0
	_view.position.y = _top - roundf((1.0 - out) * _view.size.y / cell) * cell


## Pops the paper out of the slot (the next day's stub, `tall` px long).
func pop(tall: float) -> void:
	stop_feed()
	_view.size.y = tall
	if _pop != null:
		_pop.kill()
	_pop_t = 0.0
	place()
	_pop = _view.create_tween()
	_pop.tween_method(_set_pop, 0.0, pop_seconds(), pop_seconds())
	# A method, not a lambda: a lambda would hold this hang and the tween it holds alive (a cycle).
	_pop.finished.connect(_set_pop.bind(-1.0))


## The pop to its end at once (a count starting, tests).
func finish_pop() -> void:
	if _pop != null:
		_pop.kill()
		_pop = null
	_set_pop(-1.0)


func stop_feed() -> void:
	if _feed != null:
		_feed.kill()
		_feed = null


func is_feeding() -> bool:
	return _feed != null and _feed.is_running()


func is_popping() -> bool:
	return _pop_t >= 0.0


## The stub's fraction out of the slot `ms` milliseconds into its pop (POP, piecewise linear).
static func pop_fraction(ms: float) -> float:
	if ms <= POP[0].x:
		return POP[0].y
	for index: int in range(1, POP.size()):
		if ms <= POP[index].x:
			var a: Vector2 = POP[index - 1]
			var b: Vector2 = POP[index]
			return lerpf(a.y, b.y, (ms - a.x) / (b.x - a.x))
	return POP[-1].y


## The pop's length (s).
static func pop_seconds() -> float:
	return POP[-1].x / 1000.0


## The paper's free end on `item` (its own canvas, `size` its paper's): its foot's outline gives
## way to a TAIL_MARGIN art px strip in `face`, then teeth 1 and 2 art px long by turns, each with
## an ink tip, ink sides down to the teeth. `teeth_colour` (alpha above 0) colours the teeth
## instead of `face` (payday's brass foot, ReceiptPayday.draw_foot).
static func draw_tail(
	item: CanvasItem, size: Vector2, face: Color, teeth_colour: Color = Color(0, 0, 0, 0)
) -> void:
	var tooth: Color = teeth_colour if teeth_colour.a > 0.0 else face
	var p: float = ArtStyle.ART_SCALE
	var foot: float = size.y - p
	var strip: float = (TAIL_MARGIN + 1) * p
	item.draw_rect(Rect2(p, foot, size.x - 2.0 * p, strip), face)
	item.draw_rect(Rect2(0.0, foot, p, strip), Palette.INK)
	item.draw_rect(Rect2(size.x - p, foot, p, strip), Palette.INK)
	var teeth: float = foot + strip
	var columns: int = floori(size.x / p)
	for column: int in range(columns):
		var long: float = (1 + column % TAIL_TEETH) * p
		var x: float = column * p
		if column == 0 or column == columns - 1:
			item.draw_rect(Rect2(x, teeth, p, long), Palette.INK)
			continue
		item.draw_rect(Rect2(x, teeth, p, long), tooth)
		item.draw_rect(Rect2(x, teeth + long, p, p), Palette.INK)


## The tail's height under the paper's foot (px): its strip less the outline row, its longest
## tooth and its tip.
static func tail_height() -> float:
	return (TAIL_MARGIN + TAIL_TEETH + 1) * ArtStyle.ART_SCALE


func _feed_to(tall: float) -> void:
	var from: float = _view.size.y
	stop_feed()
	var lines: float = maxf((tall - from) / LINE_PX, 1.0)
	var seconds: float = minf(FEED_SECONDS * lines, FEED_MAX_SECONDS)
	_feed = _view.create_tween()
	_feed.tween_method(_set_fed.bind(tall), from, tall, seconds)


## The paper fed to `height` in whole art px, never past the feed's `goal` (an odd goal lands on
## itself, as an unfed fit would).
func _set_fed(height: float, goal: float) -> void:
	var cell: float = ArtStyle.ART_SCALE
	var stepped: float = minf(roundf(height / cell) * cell, goal)
	_view.size.y = maxf(stepped, _view.get_combined_minimum_size().y)
	place()
	if on_step.is_valid():
		on_step.call()


func _set_pop(t: float) -> void:
	_pop_t = t
	place()
