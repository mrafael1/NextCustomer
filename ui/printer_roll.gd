class_name PrinterRoll
extends Control
## The receipt printer's moving parts (shift-scene polish v1, B "roll window"): while the receipt
## prints, it draws over the printer front's window and light (art/src/scenery/printer_box.txt,
## rows 11..30) the wide paper roll turning (its cream ribs stepping across it at LINE_HZ) with a
## 1 art px shiver, and the green light blinking. Idle, it hides and the art's own idle look shows.
## It prints through a count (count_started to finished: the item lines, the total and the
## dessert's print-out) and for a short burst (print_burst) each time the planning receipt is
## printed again. Reduced motion keeps it hidden: the printer stays static. Decor only: it never
## scores.
##
## RegisterCabinet places it at front_rect(its printer rect), over the printer sprite.

## The front starts this many art rows down the printer art, which is drawn at SCALE.
const FRONT_ROW := 11
const SCALE := 2.0
## The front's size in art px (the art's width, rows 11..30).
const FRONT_SIZE := Vector2(132, 20)
## The parts it draws over, in front art px: the light's housing, its lit cell and glow, and the
## roll's area inside the window (between its smoked sides, one row taller for the shiver).
const LIGHT_HOUSING := Rect2(6, 5, 5, 4)
const LIGHT := Rect2(7, 6, 3, 2)
const LIGHT_GLOW := Rect2(5, 4, 7, 6)
const ROLL_AREA := Rect2(37, 4, 58, 9)
## The roll (front art px, undropped): a cream lit top row, PAPER_ROWS of paper, then
## UNDER_ROWS of its cream-darkest underside.
const ROLL := Rect2(37, 4, 58, 8)
const PAPER_ROWS := 5
const UNDER_ROWS := 2
## The roll's cream ribs: LINE_COUNT rows LINE_GAP apart on the paper (wrapping every
## LINE_CYCLE rows, only those on the paper shown), stepping LINE_HZ times a second through
## LINE_STEPS offsets (mock-up v1's turning speed).
const LINE_COUNT := 3
const LINE_GAP := 2
const LINE_CYCLE := 6
const LINE_HZ := 12.0
const LINE_STEPS := 4
## The shiver: the roll drops 1 art px every other 1 / SHIVER_HZ s; the light blinks at BLINK_HZ
## (on, then off) with its glow at LIGHT_GLOW_ALPHA.
const SHIVER_HZ := 20.0
const BLINK_HZ := 6.0
const LIGHT_GLOW_ALPHA := 0.25
## A planning reprint turns the roll this long (s).
const PLANNING_PRINT_S := 0.45

## Returns true under reduced motion (the shift screen sets it); unset, the count's plan says.
var reduced_motion: Callable = Callable()
## Seconds the roll has turned, its phase (the lines, the shiver, the blink).
var _time: float = 0.0
## The planning burst's seconds left.
var _burst_left: float = 0.0
## A count is printing (count_started to finished).
var _counting: bool = false
var _count: CountUp


func _init() -> void:
	name = "PrinterRoll"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## The printer front's rect for a printer drawn at `printer_rect` (same coordinates).
static func front_rect(printer_rect: Rect2) -> Rect2:
	return Rect2(
		printer_rect.position + Vector2(0, FRONT_ROW * SCALE),
		Vector2(printer_rect.size.x, FRONT_SIZE.y * SCALE)
	)


## The roll turns through each count of `count_up`, from count_started to finished.
func follow(count_up: CountUp) -> void:
	_count = count_up
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _set_counting(true))
	count_up.finished.connect(_set_counting.bind(false))


## The planning receipt printed again: the roll turns for `seconds`.
func print_burst(seconds: float = PLANNING_PRINT_S) -> void:
	_burst_left = maxf(_burst_left, seconds)
	_refresh()


## The roll is turning now (never under reduced motion).
func is_printing() -> bool:
	return (_counting or _burst_left > 0.0) and not _still()


## Seconds the roll has turned (its animation phase).
func phase() -> float:
	return _time


## The roll's drop this frame (art px: 0 or 1, the shiver).
func shiver() -> int:
	return int(floorf(_time * SHIVER_HZ)) % 2


## The light is lit this frame (it blinks while printing).
func light_on() -> bool:
	return int(floorf(_time * BLINK_HZ)) % 2 == 0


## The ribs' rows this frame, counted down from the roll's top (on its paper rows only).
func rib_rows() -> Array[int]:
	var rows: Array[int] = []
	for k: int in range(LINE_COUNT):
		var rib: int = 1 + (k * LINE_GAP + line_step()) % LINE_CYCLE
		if rib <= PAPER_ROWS:
			rows.append(rib)
	return rows


## The ribs' step this frame (0 .. LINE_STEPS - 1): the roll's turn.
func line_step() -> int:
	return int(floorf(_time * LINE_HZ)) % LINE_STEPS


func _set_counting(counting: bool) -> void:
	_counting = counting
	_refresh()


func _still() -> bool:
	if reduced_motion.is_valid():
		return reduced_motion.call() as bool
	return _count != null and _count.plan != null and _count.plan.reduced_motion


## Shows and runs while printing; hides (the art's idle look) and stops otherwise.
func _refresh() -> void:
	var printing: bool = is_printing()
	if not printing:
		_burst_left = 0.0
	visible = printing
	set_process(printing)
	queue_redraw()


func _process(delta: float) -> void:
	_burst_left = maxf(_burst_left - delta, 0.0)
	if not is_printing():  # The burst ran out, or reduced motion was turned on meanwhile.
		_refresh()
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_light()
	_draw_roll()


## Fills front art px `rect` with `color`.
func _px(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position * SCALE, rect.size * SCALE), color)


func _draw_light() -> void:
	_px(LIGHT_HOUSING, Palette.INK)
	if not light_on():
		_px(LIGHT, Palette.GREEN_DARK)
		return
	_px(LIGHT, Palette.GOOD)
	_px(Rect2(LIGHT.position, Vector2.ONE), Palette.GREEN_LIGHT)
	_px(LIGHT_GLOW, Color(Palette.GREEN_LIGHT, LIGHT_GLOW_ALPHA))


## The roll, dropped by the shiver, with its ribs at this step.
func _draw_roll() -> void:
	_px(ROLL_AREA, Palette.SLATE)
	var roll: Rect2 = ROLL
	roll.position.y += shiver()
	var row: Rect2 = Rect2(roll.position, Vector2(roll.size.x, 1))
	_px(row, Palette.CREAM)
	_px(Rect2(row.position + Vector2(0, 1), Vector2(row.size.x, PAPER_ROWS)), Palette.PAPER)
	var under: Vector2 = row.position + Vector2(0, 1 + PAPER_ROWS)
	_px(Rect2(under, Vector2(row.size.x, UNDER_ROWS)), Palette.CREAM_DARKEST)
	for rib: int in rib_rows():
		_px(Rect2(row.position + Vector2(0, rib), row.size), Palette.CREAM)
