class_name CheerConfetti
extends Control
## The checkout cheering's confetti (#120 play feedback, 2026-10-31): when a passed checkout's
## crowd does its final yay (CheckoutCrowd.cheer_and_fold), each standee throws a burst of pixel
## confetti from its head. Pieces fly up and out, fall under GRAVITY with some DRAG, flutter (their
## width flips between FLUTTER_WIDTHS) and fade out over their last FADE_SECONDS. Seeded per burst
## (never the global RNG). Its own clock: it outlives the crowd's fold and the printer feed, and is
## not clipped to the crowd's band. Stage coordinates (in the world, over the crowd, under the
## monitor and the fore). Decor only: it takes no clicks.

const COLOURS: Array[Color] = [
	Palette.GOLD,
	Palette.TOMATO,
	Palette.TEAL_BRIGHT,
	Palette.MUSTARD_LIGHT,
	Palette.GREEN_LIGHT,
	Palette.PAPER,
]
## A piece: PIECE_HEIGHT px tall, its width flipping between FLUTTER_WIDTHS every FLUTTER_SECONDS.
const PIECE_HEIGHT := 4.0
const FLUTTER_WIDTHS: Array[float] = [4.0, 2.0]
const FLUTTER_SECONDS := 0.09
## Launch: up at SPEED_UP px/s (x: min, y: max), out at up to SPEED_OUT px/s either way.
const SPEED_UP := Vector2(170, 300)
const SPEED_OUT := 110.0
const GRAVITY := 520.0
## The share of its speed a piece keeps each second (air drag).
const DRAG := 0.45
const LIFE_SECONDS := Vector2(1.1, 1.6)
const FADE_SECONDS := 0.35
const GRID := 2.0
## dust(): grey puffs, low and slow, short-lived, square (no flutter).
const DUST_COLOURS: Array[Color] = [Palette.GREY_LIGHT, Palette.CREAM_SHADE, Palette.GREY]
const DUST_SPEED := Vector2(70, 60)
const DUST_LIFE_SECONDS := Vector2(0.35, 0.6)

## Every live piece: {at, velocity, life, age, colour, phase}.
var _pieces: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "CheerConfetti"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Throws `count` pieces from `from` (this layer's coordinates), seeded by `seed_value`.
func burst(from: Vector2, count: int, seed_value: int) -> void:
	_rng.seed = seed_value
	for _index: int in range(count):
		var velocity := Vector2(
			_rng.randf_range(-SPEED_OUT, SPEED_OUT), -_rng.randf_range(SPEED_UP.x, SPEED_UP.y)
		)
		(
			_pieces
			. append(
				{
					"at": from + Vector2(_rng.randf_range(-6.0, 6.0), 0.0),
					"velocity": velocity,
					"life": _rng.randf_range(LIFE_SECONDS.x, LIFE_SECONDS.y),
					"age": 0.0,
					"colour": COLOURS[_rng.randi_range(0, COLOURS.size() - 1)],
					"phase": _rng.randf(),
				}
			)
		)
	set_process(true)
	queue_redraw()


## A puff of `count` dust pieces from `from` (a toppled standee hitting the counter), seeded by
## `seed_value`.
func dust(from: Vector2, count: int, seed_value: int) -> void:
	_rng.seed = seed_value
	for _index: int in range(count):
		var velocity := Vector2(
			_rng.randf_range(-DUST_SPEED.x, DUST_SPEED.x), -_rng.randf_range(10.0, DUST_SPEED.y)
		)
		(
			_pieces
			. append(
				{
					"at": from + Vector2(_rng.randf_range(-10.0, 10.0), 0.0),
					"velocity": velocity,
					"life": _rng.randf_range(DUST_LIFE_SECONDS.x, DUST_LIFE_SECONDS.y),
					"age": 0.0,
					"colour": DUST_COLOURS[_rng.randi_range(0, DUST_COLOURS.size() - 1)],
					"phase": -1.0,
				}
			)
		)
	set_process(true)
	queue_redraw()


## How many pieces fly now.
func pieces() -> int:
	return _pieces.size()


func clear() -> void:
	_pieces.clear()
	queue_redraw()


func _process(delta: float) -> void:
	# Godot turns processing on when the node is ready: off while no piece flies.
	if _pieces.is_empty():
		set_process(false)
		return
	var kept: Array[Dictionary] = []
	var keep: float = pow(DRAG, delta)
	for piece: Dictionary in _pieces:
		var age: float = float(piece["age"]) + delta
		if age >= float(piece["life"]):
			continue
		var velocity: Vector2 = piece["velocity"]
		velocity = velocity * keep + Vector2(0.0, GRAVITY * delta)
		piece["velocity"] = velocity
		piece["at"] = (piece["at"] as Vector2) + velocity * delta
		piece["age"] = age
		kept.append(piece)
	_pieces = kept
	queue_redraw()


func _draw() -> void:
	for piece: Dictionary in _pieces:
		var age: float = piece["age"]
		var left: float = float(piece["life"]) - age
		var colour: Color = piece["colour"]
		colour.a = clampf(left / FADE_SECONDS, 0.0, 1.0)
		var width: float = PIECE_HEIGHT
		if float(piece["phase"]) >= 0.0:  # Dust (phase -1) stays square.
			var flip: int = floori(age / FLUTTER_SECONDS + float(piece["phase"]) * 2.0) % 2
			width = FLUTTER_WIDTHS[flip]
		var at: Vector2 = ((piece["at"] as Vector2) / GRID).round() * GRID
		draw_rect(
			Rect2(at - Vector2(width, PIECE_HEIGHT) / 2.0, Vector2(width, PIECE_HEIGHT)), colour
		)
