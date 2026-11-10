class_name ServiceBell
extends Control
## The service bell on the register's top, left of the desk calendar (left column v2, the user's
## pick of 2026-11-09: mock-up docs/art/mockups/left_column_v2.html, its bell()): a brass dome on a
## plunger and a dark base, drawn on the art grid. It dings at CHECKOUT and again as the next day's
## planning stub pops out of the printer ("next customer!"): the plunger presses one art px, the
## dome shakes one art px side to side, ding lines fly out either side, and the service bell's
## sound rings (Sfx "service_bell", the CC0 desk bell's tap and ring, DING_DB; play test
## 2026-11-09: it is CHECKOUT's sound, in place of the old key). Reduced motion: only the sound.
## Decoration only: it takes no clicks.

## The bell in art px (ShiftStage.BELL_RECT at ArtStyle.ART_SCALE).
const WIDTH := 36
const HEIGHT := 20
## The dome's rows' widths (art px), from its top under the plunger.
const DOME: Array[int] = [6, 12, 16, 20, 22, 24, 26, 26, 28, 28, 30]
const DOME_TOP := 5
## The ding: RING_SECONDS long; the plunger is down for PRESS_SECONDS, the dome shakes for
## SHAKE_SECONDS (a side every SHAKE_STEP); the lines show from LINES_FROM to LINES_TO, stepping
## out every LINE_STEP, paper then mustard light from LINES_FADE.
const RING_SECONDS := 0.52
const PRESS_SECONDS := 0.09
const SHAKE_SECONDS := 0.3
const SHAKE_STEP := 0.04
const LINES_FROM := 0.04
const LINES_TO := 0.46
const LINE_STEP := 0.07
const LINES_FADE := 0.25
const SOUND := "service_bell"
const DING_DB := 0.0
## The ding lines: [x, y, dx, dy] (art px from the bell's top left; their direction).
const LINES: Array[Vector4i] = [
	Vector4i(26, 2, 1, -1), Vector4i(29, 6, 1, 0), Vector4i(8, 2, -1, -1), Vector4i(5, 6, -1, 0)
]

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

## Seconds since the last ding (below 0: none rings).
var _age: float = -1.0


func _init() -> void:
	name = "ServiceBell"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	set_process(false)


## Dings: the sound always, the press, shake and lines unless motion is reduced.
func ding() -> void:
	Sfx.play_at(self, SOUND, DING_DB)
	if _reduced():
		return
	_age = 0.0
	set_process(true)
	queue_redraw()


## Whether a ding plays now.
func is_ringing() -> bool:
	return _age >= 0.0


## Moves the ding on by `seconds` (tests; _process moves it by the frame's).
func advance(seconds: float) -> void:
	if _age < 0.0:
		return
	_age += seconds
	if _age >= RING_SECONDS:
		_age = -1.0
		set_process(false)
	queue_redraw()


## The plunger's press (art px) and the dome's shake (art px, -1 .. 1) now.
func press() -> int:
	return 1 if _age >= 0.0 and _age < PRESS_SECONDS else 0


func shake() -> int:
	if _age < 0.0 or _age >= SHAKE_SECONDS:
		return 0
	return 1 if floori(_age / SHAKE_STEP) % 2 else -1


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var centre: int = floori(WIDTH / 2.0)
	# The base.
	_cell(0, 0, HEIGHT - 4, WIDTH, 4, Palette.INK)
	_cell(0, 1, HEIGHT - 4, WIDTH - 2, 1, Palette.MUSTARD_DARK)
	_cell(0, 1, HEIGHT - 3, WIDTH - 2, 2, Palette.BRASS_DARK)
	var dx: int = shake()
	var down: int = press()
	# The plunger (pressed one row on a ding) and the dome.
	_cell(dx, centre - 3, down, 6, 2, Palette.INK)
	_cell(dx, centre - 2, down, 4, 1, Palette.STEEL_LIGHT)
	_cell(dx, centre - 1, 2 + down, 2, 3 - down, Palette.INK)
	_cell(dx, centre - 1, 2 + down, 1, 3 - down, Palette.STEEL)
	for index: int in range(DOME.size()):
		var width: int = DOME[index]
		var y: int = DOME_TOP + index
		var x: int = centre - floori(width / 2.0)
		var shade: int = maxi(2, roundi(width / 5.0))
		_cell(dx, x - 1, y, width + 2, 1, Palette.INK)
		_cell(dx, x, y, width, 1, Palette.MUSTARD)
		_cell(dx, x + width - shade, y, shade, 1, Palette.MUSTARD_DARK)
		if index > 1 and index < 9:
			_cell(dx, x + roundi(width / 4.0), y, 2, 1, Palette.MUSTARD_LIGHT)
		if index == 3 or index == 4:
			_cell(dx, x + roundi(width / 4.0), y, 1, 1, Palette.PAPER)
	_cell(dx, centre - 16, HEIGHT - 5, 32, 1, Palette.INK)
	if _age < LINES_FROM or _age >= LINES_TO:
		return
	var out: int = floori((_age - LINES_FROM) / LINE_STEP) % 2
	var ink: Color = Palette.PAPER if _age < LINES_FADE else Palette.MUSTARD_LIGHT
	for line: Vector4i in LINES:
		for step: int in range(3):
			var reach: int = step + out
			_cell(0, line.x + line.z * reach, line.y + line.w * reach, 1, 1, ink)


## A cell `dx` art px shifted (the shake), at art px (`x`, `y`).
func _cell(dx: int, x: int, y: int, width: int, height: int, colour: Color) -> void:
	var cell: float = ArtStyle.ART_SCALE
	draw_rect(Rect2((x + dx) * cell, y * cell, width * cell, height * cell), colour)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
