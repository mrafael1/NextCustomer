class_name ToyStreet
extends Control
## The street through the TOY MACHINES' glass doors, alive (v0.79, play feedback on #121): now
## and then a car passes outside, its headlights' glow crossing the street and the kerb behind
## the door frames in art px steps, and the street lamp flickers off for two frames on a long
## cycle (never while a car passes). Both are windows onto ToyExitArt.doors' variants laid over
## the backdrop's doors, so the frames and the glare lines stay put. `still` (the profile's
## reduced motion) holds both: no car, the lamp lit. Takes no clicks. Sizes in art px.

## A car's glow: its core and its fringe (each side) widths, crossing in SWEEP_TIME with a step
## every SWEEP_STEP; the first car SWEEP_FIRST seconds after the screen opens, then one every
## SWEEP_GAP (min, max) seconds, either way along the street.
const CORE_WIDTH := 16
const FRINGE_WIDTH := 14
const SWEEP_TIME := 1.6
const SWEEP_STEP := 0.05
const SWEEP_FIRST := 3.0
const SWEEP_GAP := Vector2(9.0, 16.0)
## The lamp's flicker: off in LAMP_FRAME frames 3 and 5 of every LAMP_CYCLE.
const LAMP_FRAME := 0.08
const LAMP_CYCLE := 113
const LAMP_OFF: Array[int] = [3, 5]

## Holds the car and the flicker (the profile's reduced motion).
var still: bool = false:
	set(value):
		still = value
		_update_live()

var _fringe: Control
var _core: Control
var _lamp_off: Control
var _clock: float = 0.0
var _car_at: float = -1.0
var _car_way: int = 1
var _next_car: float = SWEEP_FIRST
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(ToyExitArt.DOORS_LAYER.position) * ArtStyle.ART_SCALE
	size = Vector2(ToyExitArt.DOORS_LAYER.size) * ArtStyle.ART_SCALE
	_rng.randomize()
	_lamp_off = _window(ToyExitArt.doors("lamp_off"))
	_fringe = _window(ToyExitArt.doors("fringe"))
	_core = _window(ToyExitArt.doors("core"))
	var lamp: Rect2i = ToyExitArt.STREET_LAMP_RECT
	_lamp_off.position = (
		Vector2(lamp.position - ToyExitArt.DOORS_LAYER.position) * ArtStyle.ART_SCALE
	)
	_lamp_off.size = Vector2(lamp.size) * ArtStyle.ART_SCALE
	_place_view(_lamp_off)
	_update_live()


## Starts over: the first car SWEEP_FIRST seconds from now (the screen opens).
func restart() -> void:
	_clock = 0.0
	_car_at = -1.0
	_next_car = SWEEP_FIRST
	_update_live()


## Sends a car past now, `way` 1 left to right or -1 right to left (a car's own clock).
func pass_car(way: int) -> void:
	_car_way = way
	_car_at = _clock
	_next_car = _clock + SWEEP_TIME + _rng.randf_range(SWEEP_GAP.x, SWEEP_GAP.y)
	_update_live()


## The headlights' core and fringe windows, and the lamp's off window (for tests).
func core() -> Control:
	return _core


func fringe() -> Control:
	return _fringe


func lamp_lit() -> bool:
	return not _lamp_off.visible


func car_passing() -> bool:
	return _car_at >= 0.0 and _clock - _car_at < SWEEP_TIME


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if not still and _clock >= _next_car:
		pass_car(1 if _rng.randi() % 2 else -1)
	_update_live()


## Steps the car's glow along the street and the lamp to the clock.
func _update_live() -> void:
	if _core == null:
		return
	var passing: bool = car_passing() and not still
	_core.visible = passing
	_fringe.visible = passing
	_lamp_off.visible = not still and not passing and _lamp_flickers()
	if not passing:
		return
	var glass: Rect2i = ToyExitArt.DOORS_RECT
	var reach: int = CORE_WIDTH + 2 * FRINGE_WIDTH
	var steps: int = ceili(SWEEP_TIME / SWEEP_STEP)
	var step: int = mini(int((_clock - _car_at) / SWEEP_STEP), steps)
	var travel: int = glass.size.x + reach
	var lead: int = roundi(float(travel) * step / steps)
	if _car_way < 0:
		lead = travel - lead
	var left: int = glass.position.x - ToyExitArt.DOORS_LAYER.position.x - reach + lead
	_place(_fringe, left, reach)
	_place(_core, left + FRINGE_WIDTH, CORE_WIDTH)
	_place_view(_fringe)
	_place_view(_core)


func _lamp_flickers() -> bool:
	return int(_clock / LAMP_FRAME) % LAMP_CYCLE in LAMP_OFF


## A clipping window onto `texture` (laid over the whole doors), full height.
func _window(texture: Texture2D) -> Control:
	var window: Control = Control.new()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.clip_contents = true
	window.size = size
	window.visible = false
	add_child(window)
	var view: TextureRect = UiKit.sprite(texture)
	view.size = size
	window.add_child(view)
	return window


## Sets a window's left (art px from the doors layer's left) and width.
func _place(window: Control, left: int, width: int) -> void:
	window.position.x = left * ArtStyle.ART_SCALE
	window.size.x = width * ArtStyle.ART_SCALE


## Keeps a window's art where the doors are, wherever the window is.
func _place_view(window: Control) -> void:
	(window.get_child(0) as Control).position = -window.position
