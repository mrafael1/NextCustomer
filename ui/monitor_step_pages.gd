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
##
## v1.14 (the user's "fix the missing subtotal across pages"): each page may have a head, the line
## over its rows (the item column's base price line on the first page, the carried line,
## MonitorBaseLine.make_carried, on a later one), in the page so it turns with it, a row's pitch
## above the rows (an INLINE head, a coupon's, as its first row). The page cue (MonitorPager, at
## `pager_foot`: pips, the subtotal, MORE or FIRST and a chevron) shows with more than one page; a
## click on it turns to the next page, and it lights while held. A turn slides the page shown in
## from SLIDE px along its way (from the right to go on, from the left to go back, as the wrap from
## the last page to the first does; inside the column's frame) as it fades in (not under reduced
## motion).

signal turned(page: int)

const MARKER_TEXT := "%d/%d"
const MARKER_HEIGHT := 14.0
const MARKER_SIZE := 10
const MARKER_WEIGHT := 800
const MARKER_COLOR := Palette.INK_LIGHT
## How far a page shown slides in from as it fades in (no further than the column's inset, so it
## stays inside its frame).
const SLIDE := 6.0

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Where the marker's foot sits, its left edge (the pages' coordinates: the item column puts it
## at its header's right end, PR #138 round 2); none (x below 0): bottom right, under the lines.
var marker_foot: Vector2 = Vector2(-1, -1):
	set(value):
		marker_foot = value
		_show_marker()
## Whether marker_foot's x is the marker's right edge (the item column's header end) rather than
## its left.
var marker_right: bool = false:
	set(value):
		marker_right = value
		_show_marker()

## Where the page cue's foot sits, its left edge (the pages' coordinates; the item column puts it
## on the total's line at the payout zone's left).
var pager_foot: Vector2 = Vector2.ZERO:
	set(value):
		pager_foot = value
		_place_pager()

var _pages: Array[Control] = []
var _rows: Array[Array] = []
var _heads: Array[Control] = []
var _pager: MonitorPager
var _page: int = 0
var _held: bool = false
var _interval: float = 0.0
var _fade: float = 0.0
var _timer: Timer
var _marker: Label
var _fades: Array[Tween] = []


## `page_rows`: each page's rows (in no parent yet), laid out from the page's top; `room` the step
## area's size (the marker at its foot); `heads`: each page's head (in no parent yet, or null; see
## the class comment), set above its rows.
func _init(
	page_rows: Array[Array], room: Vector2, interval: float, fade: float, heads: Array[Control] = []
) -> void:
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
		var top: Control = heads[index] if index < heads.size() else null
		if top != null:
			if top.get_parent() != null:
				top.reparent(holder, false)
			else:
				holder.add_child(top)
			var inline: bool = bool(top.get_meta(MonitorCarry.INLINE, false))
			top.position = Vector2(0, 0.0 if inline else -top.size.y)
		_heads.append(top)
		_pages.append(holder)
		_rows.append(shown)
	if _pages.size() > 1:
		_pager = MonitorPager.new()
		_pager.pressed.connect(turn.bind(1))
		add_child(_pager)
		_pager.show_page(0, _pages.size())
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
	if _pager != null:
		_pager.reduced_motion = reduced_motion
		_pager.show_page(_page, _pages.size())
		_place_pager()
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


## The page cue (null with one page), and the page shown's head (null for none).
func pager() -> MonitorPager:
	return _pager


func head() -> Control:
	return _heads[_page] if _page < _heads.size() else null


## Whether any page has a head.
func has_heads() -> bool:
	return _heads.any(func(top: Control) -> bool: return top != null)


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
	if _pager != null:
		_pager.lit = held
	_wait()


## Shows the next page (`direction` 1) or the previous one (-1), wrapping around, and starts the
## wait again.
func turn(direction: int) -> void:
	if _pages.size() < 2 or direction == 0:
		return
	var old: Control = _pages[_page]
	var was: int = _page
	_page = posmod(_page + signi(direction), _pages.size())
	var shown: Control = _pages[_page]
	_stop_fades()
	for page_control: Control in _pages:
		page_control.visible = page_control == shown or page_control == old
		page_control.modulate.a = 1.0
		page_control.position = Vector2.ZERO
	if _fade <= 0.0 or _reduced() or not is_inside_tree():
		old.visible = old == shown
	else:
		shown.modulate.a = 0.0
		# From the right going on, from the left going back (a wrap to the first page too).
		shown.position = Vector2(SLIDE * signi(_page - was), 0)
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(old, "modulate:a", 0.0, _fade)
		tween.tween_property(shown, "modulate:a", 1.0, _fade)
		tween.tween_property(shown, "position:x", 0.0, _fade * 2.0).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func() -> void: old.visible = old == _pages[_page])
		_fades.append(tween)
	_show_marker()
	if _pager != null:
		_pager.show_page(_page, _pages.size())
		_place_pager()
	_wait()
	turned.emit(_page)


## `lines` (rows) on pages `room` px tall, each placed under the one before it on its page, each
## page's texts at one size (MonitorStepRow.even_sizes).
static func lay_out(lines: Array[Control], room: float) -> Array[Array]:
	var paged: Array[Array] = [[]]
	var top: float = 0.0
	for row: Control in lines:
		if top + row.size.y > room + 0.5 and not paged[-1].is_empty():
			paged.append([])
			top = 0.0
		row.position = Vector2(0, top)
		paged[-1].append(row)
		top += row.size.y
	for shown: Array in paged:
		MonitorStepRow.even_sizes(shown)
	return paged


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
	if marker_foot.x >= 0.0:
		var left: float = marker_foot.x - shown.x if marker_right else marker_foot.x
		_marker.position = Vector2(left, marker_foot.y - shown.y)
	else:
		_marker.position = Vector2(size.x - shown.x, size.y - shown.y)


## The page cue's foot on pager_foot, its left edge there.
func _place_pager() -> void:
	if _pager != null:
		_pager.position = Vector2(pager_foot.x, pager_foot.y - _pager.size.y)


func _stop_fades() -> void:
	for tween: Tween in _fades:
		if tween != null and tween.is_valid():
			tween.kill()
	_fades.clear()
	for page_control: Control in _pages:
		page_control.position = Vector2.ZERO


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
