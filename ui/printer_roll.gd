class_name PrinterRoll
extends Control
## The receipt printer's moving parts (shift-scene polish v2, B "roll window"): while the receipt
## prints, it draws over the printer front's window, light and power key
## (art/src/scenery/printer_box.txt, rows 11..30) the paper roll turning (faint printed lines
## running up it) with a 1 art px shiver, the green light blinking and the tomato key glowing.
## Idle, it hides and the art's own idle look shows. It prints through a count (count_started to
## finished: the item lines, the total and the dessert's print-out) and for a short burst
## (print_burst) each time the planning receipt is printed again. Reduced motion keeps it hidden:
## the printer stays static. Decor only: it never scores.
##
## RegisterCabinet places it at front_rect(its printer rect), over the printer sprite.

## The front starts this many art rows down the printer art, which is drawn at SCALE.
const FRONT_ROW := 11
const SCALE := 2.0
## The front's size in art px (the art's width, rows 11..30).
const FRONT_SIZE := Vector2(132, 20)
## The parts it draws over, in front art px: the light's housing and lit cell, the power key's
## housing and face, and the roll's area inside the window (between the spool hubs).
const LIGHT_HOUSING := Rect2(5, 5, 5, 4)
const LIGHT := Rect2(6, 6, 3, 2)
const LIGHT_GLOW := Rect2(4, 4, 7, 6)
const KEY_HOUSING := Rect2(14, 4, 9, 9)
const KEY_GLOW := Rect2(13, 3, 11, 11)
const ROLL_AREA := Rect2(40, 3, 52, 10)
## The roll's left, width and top (art px); its rows down from the top: a lit cream row, paper,
## a cream row, then its shade and darkest underside.
const ROLL_X := 40
const ROLL_WIDTH := 52
const ROLL_TOP := 4
## The printed lines on the roll: LINE_COUNT dashes from LINE_X every LINE_STEP art px, two rows
## LINE_PERIOD / 2 apart running up the roll's face (rows LINE_FIRST_ROW to LINE_LAST_ROW, from
## the roll's underside) at LINE_SPEED art px a second, in ink light at LINE_ALPHA.
const LINE_COUNT := 6
const LINE_X := 43
const LINE_STEP := 8
const LINE_PERIOD := 7.0
const LINE_FIRST_ROW := 5
const LINE_LAST_ROW := 9
const LINE_BOTTOM := 11
const LINE_SPEED := 10.0
const LINE_ALPHA := 0.35
## The glass's two glints (start x, length: diagonal runs from the window's top row) at
## GLINT_ALPHA, drawn over the roll.
const GLINTS: Array[Vector2i] = [Vector2i(42, 5), Vector2i(49, 3)]
const GLINT_TOP := 3
const GLINT_ALPHA := 0.55
## The shiver: the roll drops 1 art px every other 1 / SHIVER_HZ s; the light blinks at BLINK_HZ
## (on, then off); the key's glow breathes at GLOW_ALPHA ± GLOW_SWING, KEY_GLOW_RATE radians a
## second, and the light's at LIGHT_GLOW_ALPHA.
const SHIVER_HZ := 20.0
const BLINK_HZ := 6.0
const GLOW_ALPHA := 0.18
const GLOW_SWING := 0.1
const KEY_GLOW_RATE := 8.0
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
	_draw_key()
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


## The key's face lit (tomato light) and its glow breathing.
func _draw_key() -> void:
	var face: Rect2 = KEY_HOUSING.grow(-1)
	_px(face, Palette.TOMATO_LIGHT)
	_px(Rect2(face.position, Vector2(face.size.x, 1)), Palette.TOMATO_PALE)
	_px(Rect2(face.end.x - 1, face.position.y + 1, 1, face.size.y - 1), Palette.TOMATO_DARK)
	_px(Rect2(face.position.x, face.end.y - 1, face.size.x, 1), Palette.TOMATO_DARK)
	_px(Rect2(face.get_center().x - 0.5, face.position.y + 2, 1, 3), Palette.PAPER)
	var glow: float = GLOW_ALPHA + GLOW_SWING * sin(_time * KEY_GLOW_RATE)
	_px(KEY_GLOW, Color(Palette.TOMATO_LIGHT, glow))


## The roll, dropped by the shiver, its lines running up, and the glints over it.
func _draw_roll() -> void:
	_px(ROLL_AREA, Palette.SLATE)
	var top: float = ROLL_TOP + shiver()
	var rows: Array[Color] = [
		Palette.CREAM,
		Palette.PAPER,
		Palette.PAPER,
		Palette.PAPER,
		Palette.PAPER,
		Palette.CREAM,
		Palette.CREAM_SHADE,
		Palette.CREAM_DARKEST,
	]
	for row: int in range(rows.size()):
		_px(Rect2(ROLL_X, top + row, ROLL_WIDTH, 1), rows[row])
	var phase_px: float = fmod(_time * LINE_SPEED, LINE_PERIOD)
	for k: int in range(2):
		var row_y: int = int(LINE_BOTTOM - fmod(k * LINE_PERIOD / 2.0 + phase_px, LINE_PERIOD))
		if row_y < LINE_FIRST_ROW or row_y > LINE_LAST_ROW:
			continue
		for i: int in range(LINE_COUNT):
			var dash: Rect2 = Rect2(LINE_X + i * LINE_STEP, row_y + shiver(), 3 + i % 3, 1)
			_px(dash, Color(Palette.INK_LIGHT, LINE_ALPHA))
	for glint: Vector2i in GLINTS:
		for i: int in range(glint.y):
			_px(Rect2(glint.x + i, GLINT_TOP + i, 1, 1), Color(Palette.GLASS_GLOW, GLINT_ALPHA))
