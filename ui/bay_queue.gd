class_name BayQueue
extends Control
## The scanner bay's header (#86 round 7, mock-up count_up_86_v7_bay.html's QUEUE; over
## ScannerBay.HEADER_RECT, the scan light aside, which the bay draws): how many items wait behind
## the one in the bay ("4 LEFT", then LAST, then DONE once all are bagged) and one pip per item,
## right-aligned: gold once bagged, tomato light from the drop-in until it is bagged (green light
## once the quota is met), teal shade still to come. The pips shrink to fit beside the widest of
## the texts (pip_layout): PIP px in one row, else SMALL_PIP px in one row, else in two. With no
## count (start(0)) it reads "SCANNER" with no pips. The text is the header's bold Atkinson
## (ScannerBay.header_font). Display only: the count and the order are the count-up's.

## The header's rect (bay coordinates), the text's left and lift, the pips' right edge and their
## gap to the widest text.
const RECT := Rect2(2, 2, 108, 15)
const TEXT_X := 21.0
const TEXT_LIFT := 0.0
const FONT_SIZE := 9
const RIGHT_EDGE := 106.0
const TEXT_GAP := 4.0
const PIP := 6.0
const SMALL_PIP := 4.0
const PIP_GAP := 2.0
## The pips' tops (bay coordinates): one row of PIP, one row of SMALL_PIP, two rows of SMALL_PIP.
const PIP_TOP := 6.0
const SMALL_PIP_TOP := 7.0
const TWO_ROW_TOPS: Array[float] = [4.0, 10.0]
const IDLE_TEXT := "SCANNER"
const LEFT_TEXT := "%d LEFT"
const LAST_TEXT := "LAST"
const DONE_TEXT := "DONE"
const TEXT_COLOR := Palette.MUSTARD_PALE
const BAGGED_COLOR := Palette.GOLD
const IN_COLOR := Palette.TOMATO_LIGHT
const IN_MET_COLOR := Palette.GREEN_LIGHT
const TO_COME_COLOR := Palette.TEAL_SHADE

var _label: Label
var _items: int = 0
## The last item that dropped in (-1 before the first), and the bagged ones.
var _last_in: int = -1
var _bagged: Array[bool] = []
var _met: bool = false
var _rects: Array[Rect2] = []


func _init() -> void:
	name = "BayQueue"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	_label = UiKit.display_label(IDLE_TEXT, FONT_SIZE, false)
	_label.add_theme_font_override("font", ScannerBay.header_font())
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(TEXT_X, RECT.position.y - TEXT_LIFT) - RECT.position
	_label.size = Vector2(RECT.end.x - TEXT_X, RECT.size.y)
	add_child(_label)


func _ready() -> void:
	_label.position = Vector2(TEXT_X, RECT.position.y - TEXT_LIFT) - RECT.position
	_label.size = Vector2(RECT.end.x - TEXT_X, RECT.size.y)


func _draw() -> void:
	var colours: Array[Color] = pip_colours()
	for index: int in range(_rects.size()):
		draw_rect(Rect2(_rects[index].position - RECT.position, _rects[index].size), colours[index])


## A count of `items` starts: none in yet, "n LEFT" (n = items), every pip to come; 0 reads
## "SCANNER" with no pips.
func start(items: int) -> void:
	_items = maxi(0, items)
	_last_in = -1
	_bagged.clear()
	_bagged.resize(_items)
	_bagged.fill(false)
	_met = false
	_rects = pip_layout(_items)
	_refresh()


## Item `index` dropped into the bay.
func enter(index: int) -> void:
	_last_in = maxi(_last_in, index)
	_refresh()


## Item `index` is in the bag.
func bag(index: int) -> void:
	if index >= 0 and index < _items:
		_bagged[index] = true
	_refresh()


## Every item in the bag: DONE.
func finish() -> void:
	_last_in = _items - 1
	_bagged.fill(true)
	_refresh()


## The quota met (the items in the bay green), or not.
func set_met(met: bool) -> void:
	_met = met
	queue_redraw()


## The same count again, nothing in yet (a reset keeps the count).
func restart() -> void:
	start(_items)


## The header's text, the pips' rects (bay coordinates) and their colours now.
func text() -> String:
	return _label.text


func pip_rects() -> Array[Rect2]:
	return _rects.duplicate()


func pip_colours() -> Array[Color]:
	var colours: Array[Color] = []
	for index: int in range(_rects.size()):
		if _bagged[index]:
			colours.append(BAGGED_COLOR)
		elif index <= _last_in:
			colours.append(IN_MET_COLOR if _met else IN_COLOR)
		else:
			colours.append(TO_COME_COLOR)
	return colours


## The header's text for `items` with item `last_in` the last in and `done` once all are bagged.
## Pure.
static func text_for(items: int, last_in: int, done: bool) -> String:
	if items <= 0:
		return IDLE_TEXT
	if done:
		return DONE_TEXT
	var waiting: int = items - 1 - last_in
	return LEFT_TEXT % waiting if waiting > 0 else LAST_TEXT


## The pips' rects (bay coordinates) for `items`, right-aligned on RIGHT_EDGE beside the widest
## header text: the first of one row of PIP, one row of SMALL_PIP and two rows of SMALL_PIP that
## fits.
static func pip_layout(items: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if items <= 0:
		return rects
	var room: float = RIGHT_EDGE - (TEXT_X + widest_text(items) + TEXT_GAP)
	if _row_width(items, PIP) <= room:
		_add_row(rects, items, PIP, PIP_TOP)
	elif _row_width(items, SMALL_PIP) <= room:
		_add_row(rects, items, SMALL_PIP, SMALL_PIP_TOP)
	else:
		var first: int = ceili(items / 2.0)
		_add_row(rects, first, SMALL_PIP, TWO_ROW_TOPS[0])
		_add_row(rects, items - first, SMALL_PIP, TWO_ROW_TOPS[1])
	return rects


## The widest header text a count of `items` shows (px, in the header's font).
static func widest_text(items: int) -> float:
	var font: Font = ScannerBay.header_font()
	var widest: float = 0.0
	for shown: String in [LEFT_TEXT % maxi(1, items - 1), LAST_TEXT, DONE_TEXT]:
		var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		widest = maxf(widest, width)
	return widest


static func _row_width(count: int, pip: float) -> float:
	return count * pip + (count - 1) * PIP_GAP


static func _add_row(rects: Array[Rect2], count: int, pip: float, top: float) -> void:
	var left: float = RIGHT_EDGE - _row_width(count, pip)
	for index: int in range(count):
		rects.append(Rect2(left + index * (pip + PIP_GAP), top, pip, pip))


func _refresh() -> void:
	var done: bool = _items > 0 and not _bagged.has(false)
	_label.text = text_for(_items, _last_in, done)
	queue_redraw()
