class_name OverheadPrinter
extends Control
## The receipt printer hung at the top of the register's column (left column v2, the user's pick of
## 2026-11-09: mock-up docs/art/mockups/left_column_v2.html, its printer()): an overhead printer
## lit from above, drawn on the art grid. Two brackets up to the ceiling; its steel body with a lit
## top edge and a shaded foot, the face's recess, the green LED and the tomato feed key, the paper
## roll seen through its window, the vents, and a status strip along its foot that blinks while
## it prints; under it the lip, the slot, and the cutter's teeth, where the paper comes out
## (ShiftStage.RECEIPT_TOP: the receipt feeds DOWN from there). It prints through a count
## (count_started to finished: the rows, the total and the dessert's lines) and for a short burst
## (print_burst) each time the planning stub is printed again. Reduced motion keeps the strip lit
## and still. Decor only: it takes no clicks and never scores.

## The printer in art px (ShiftStage.PRINTER_RECT at ArtStyle.ART_SCALE).
const WIDTH := 135
const HEIGHT := 24
## The brackets' left columns (the right one from the right end).
const BRACKET_X := 12
const BRACKET_RIGHT := 18
## The status strip's blink (seconds a phase) and a planning burst's length.
const BLINK_SECONDS := 0.12
const BURST_SECONDS := 0.45
## The roll window: its left column and width (art px), and its rows.
const ROLL_X := 25
const ROLL_WIDTH := 76
## The vents' left column.
const VENT_X := 108

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _counting: bool = false
var _burst: float = 0.0
var _time: float = 0.0


func _init() -> void:
	name = "OverheadPrinter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	set_process(false)


## Prints while `count_up` counts (its start to its end).
func follow(count_up: CountUp) -> void:
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _set_counting(true))
	count_up.finished.connect(func() -> void: _set_counting(false))


## A short burst of printing (the planning stub printed again), `seconds` long.
func print_burst(seconds: float = BURST_SECONDS) -> void:
	_burst = maxf(_burst, seconds)
	set_process(true)
	queue_redraw()


## Whether it prints now (the count, or a burst).
func is_printing() -> bool:
	return _counting or _burst > 0.0


## Whether the status strip is lit now: blinking while it prints (lit and still under reduced
## motion), dim when idle.
func strip_lit() -> bool:
	if not is_printing():
		return false
	if _reduced():
		return true
	return floori(_time / BLINK_SECONDS) % 2 == 0


func _set_counting(on: bool) -> void:
	_counting = on
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_burst = maxf(0.0, _burst - delta)
	if not is_printing():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var w: int = WIDTH
	# The brackets up to the ceiling.
	for x: int in [BRACKET_X, w - BRACKET_RIGHT]:
		_cell(x, 0, 6, 2, Palette.INK)
		_cell(x + 1, 0, 4, 2, Palette.STEEL_DARK)
	# The body: ink outline, the steel lit from above, a shaded foot.
	_cell(0, 2, w, 1, Palette.INK)
	_cell(0, 3, 1, 17, Palette.INK)
	_cell(w - 1, 3, 1, 17, Palette.INK)
	_cell(1, 3, w - 2, 17, Palette.STEEL_SHADE)
	_cell(1, 3, w - 2, 1, Palette.STEEL_LIGHT)
	_cell(1, 4, w - 2, 1, Palette.STEEL)
	_cell(1, 18, w - 2, 2, Palette.STEEL_DARK)
	# The face's recess edges.
	_cell(4, 6, w - 8, 1, Palette.INK)
	_cell(4, 16, w - 8, 1, Palette.STEEL_PALE)
	# The LED and the feed key.
	_cell(7, 8, 4, 4, Palette.INK)
	_cell(8, 9, 2, 2, Palette.GOOD)
	_cell(8, 9, 1, 1, Palette.GREEN_LIGHT)
	_cell(13, 8, 7, 5, Palette.INK)
	_cell(14, 9, 5, 3, Palette.TOMATO)
	_cell(14, 9, 5, 1, Palette.TOMATO_LIGHT)
	# The roll behind its window.
	_cell(ROLL_X, 7, ROLL_WIDTH, 9, Palette.INK)
	for row: int in range(7):
		_cell(ROLL_X + 1, 8 + row, ROLL_WIDTH - 2, 1, Palette.CREAM if row % 2 else Palette.PAPER)
	_cell(ROLL_X + 1, 8, 2, 7, Palette.CREAM_SHADE)
	_cell(ROLL_X + ROLL_WIDTH - 3, 8, 2, 7, Palette.CREAM_SHADE)
	_cell(ROLL_X + 1, 14, ROLL_WIDTH - 2, 1, Palette.CREAM_SHADE)
	_cell(ROLL_X + 5, 8, 10, 1, Palette.PAPER)
	# The vents.
	for row: int in range(8, 15, 2):
		_cell(VENT_X, row, w - VENT_X - 8, 1, Palette.INK)
	# The status strip: blinking while it prints.
	_cell(4, 17, w - 8, 1, Palette.TEAL_LIGHT if strip_lit() else Palette.TEAL_SHADE)
	# The lip, the slot, and the cutter's teeth over the paper.
	_cell(0, 20, w, 1, Palette.INK)
	_cell(3, 21, w - 6, 1, Palette.STEEL_DARK)
	_cell(4, 22, w - 8, 1, Palette.INK)
	for x: int in range(4, w - 4):
		_cell(x, 23, 1, 1, Palette.STEEL_LIGHT if x % 2 else Palette.INK)


func _cell(x: int, y: int, width: int, height: int, colour: Color) -> void:
	var cell: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(x * cell, y * cell, width * cell, height * cell), colour)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
