class_name MonitorStepPages
extends Control
## Planning's step lines on pages (Checkout Rhythm v3.1, mock-up checkout_rhythm_v3_1.html,
## scenario h): MonitorItemColumn's compact layout puts whole lines on each page when they don't
## all fit under its one-line effect. Page 1 shows first; the next one comes every
## `interval` seconds (CountTotalTuning.page_interval_s), wrapping around, the pages crossfading
## over `fade` seconds (page_fade_s; at once under reduced motion). The marker ("1/2", MARKER_TEXT)
## sits bottom right, under the lines. While held (the pointer on the monitor) no page turns by
## itself; turn (the mouse wheel) shows the next or previous one and starts the wait again.
## Its timer and fades are its own (real time, never the count's clock) and go with it.

signal turned(page: int)

const MARKER_TEXT := "%d/%d"
const MARKER_HEIGHT := 14.0
const MARKER_SIZE := 10
const MARKER_WEIGHT := 800
const MARKER_COLOR := Palette.INK_LIGHT

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _pages: Array[Control] = []
var _rows: Array[Array] = []
var _page: int = 0
var _held: bool = false
var _interval: float = 0.0
var _fade: float = 0.0
var _timer: Timer
var _marker: Label
var _fades: Array[Tween] = []


## `page_rows`: each page's rows (in no parent yet), laid out from the page's top; `room` the step
## area's size (the marker at its foot).
func _init(page_rows: Array[Array], room: Vector2, interval: float, fade: float) -> void:
	name = "Pages"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = room
	_interval = interval
	_fade = fade
	for index: int in range(page_rows.size()):
		var holder: Control = Control.new()
		holder.name = "Page%d" % index
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size = room
		holder.visible = index == 0
		add_child(holder)
		var shown: Array[Control] = []
		for row: Variant in page_rows[index]:
			var control: Control = row as Control
			holder.add_child(control)
			shown.append(control)
		_pages.append(holder)
		_rows.append(shown)
	if _pages.size() > 1:
		_marker = MonitorKit.bold("", MARKER_SIZE, MARKER_WEIGHT, MARKER_COLOR, MARKER_HEIGHT)
		_marker.name = "Marker"
		_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_marker)
		_show_marker()
	_timer = Timer.new()
	_timer.name = "PageTimer"
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)


func _ready() -> void:
	_show_marker()
	_wait()


## How many pages, the one shown (from 0), its rows, and every page's rows in order.
func count() -> int:
	return _pages.size()


func page() -> int:
	return _page


func rows() -> Array[Control]:
	var shown: Array[Control] = []
	if not _rows.is_empty():
		shown.assign(_rows[_page])
	return shown


func all_rows() -> Array[Control]:
	var every: Array[Control] = []
	for shown: Array in _rows:
		for row: Variant in shown:
			every.append(row as Control)
	return every


## The "1/2" marker (null with one page) and the page timer, for checks.
func marker() -> Label:
	return _marker


func timer() -> Timer:
	return _timer


## Whether no page turns by itself now (the pointer on the monitor).
func is_held() -> bool:
	return _held


## The pointer comes onto the monitor (`held`: no page turns by itself) or leaves it (the wait
## starts again from the start).
func hold(held: bool) -> void:
	if held == _held:
		return
	_held = held
	_wait()


## Shows the next page (`direction` 1) or the previous one (-1), wrapping around, and starts the
## wait again.
func turn(direction: int) -> void:
	if _pages.size() < 2 or direction == 0:
		return
	var old: Control = _pages[_page]
	_page = posmod(_page + signi(direction), _pages.size())
	var shown: Control = _pages[_page]
	_stop_fades()
	for page_control: Control in _pages:
		page_control.visible = page_control == shown or page_control == old
		page_control.modulate.a = 1.0
	if _fade <= 0.0 or _reduced() or not is_inside_tree():
		old.visible = old == shown
	else:
		shown.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(old, "modulate:a", 0.0, _fade)
		tween.tween_property(shown, "modulate:a", 1.0, _fade)
		tween.chain().tween_callback(func() -> void: old.visible = old == _pages[_page])
		_fades.append(tween)
	_show_marker()
	_wait()
	turned.emit(_page)


## Nothing turns any more (the item changed, the count started).
func stop() -> void:
	_timer.stop()
	_stop_fades()


func _on_timeout() -> void:
	turn(1)


## The timer waits `interval` for the next page, unless held, alone or never turning.
func _wait() -> void:
	if _timer == null:
		return
	_timer.stop()
	if _held or _pages.size() < 2 or _interval <= 0.0 or not is_inside_tree():
		return
	_timer.start(_interval)


func _show_marker() -> void:
	if _marker == null:
		return
	_marker.text = MARKER_TEXT % [_page + 1, _pages.size()]
	# Its own size (the font's, once in the tree), its foot on the step area's.
	_marker.size = Vector2.ZERO
	var shown: Vector2 = _marker.get_combined_minimum_size()
	_marker.size = shown
	_marker.position = Vector2(size.x - shown.x, size.y - shown.y)


func _stop_fades() -> void:
	for tween: Tween in _fades:
		if tween != null and tween.is_valid():
			tween.kill()
	_fades.clear()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
