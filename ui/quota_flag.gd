class_name QuotaFlag
extends Control
## The flag that anchors the quota on the top bar's gauge (#86, TA's flag in mock-up
## count_up_86_v4_live.html): a paper pole with an ink edge, from POLE_ABOVE px above the gauge to
## its foot, and a green cloth with a drawn ✓ (the fonts lack it) at the pole's top. QuotaMeter
## plants it at the quota when the amount meets it and slides it back as the gauge re-scales. It is
## planted with a drop and a bounce, then the cloth flaps; reduced motion (`reduced_motion`) shows
## it standing still. Decor only: it takes no clicks.

const POLE_WIDTH := 4.0
const POLE_ABOVE := 14.0
const POLE_BELOW := 2.0
const CLOTH_SIZE := Vector2(18, 14)
const BORDER := 2.0
## The plant: from PLANT_DROP px up, turned PLANT_TURN degrees, to its place over PLANT_SECONDS
## with an overshoot.
const PLANT_DROP := 34.0
const PLANT_TURN := -18.0
const PLANT_SECONDS := 0.55
## The cloth flaps by FLAP_SKEW degrees every FLAP_SECONDS.
const FLAP_SKEW := 5.0
const FLAP_SECONDS := 0.9

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

## The pole's length below the flag's origin (the gauge's height).
var _pole: float = 0.0
## Seconds since the plant (PLANT_SECONDS and more: planted).
var _since_plant: float = PLANT_SECONDS
var _time: float = 0.0


func _init() -> void:
	name = "QuotaFlag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the flag, planting it (no animation under reduced motion).
func plant() -> void:
	visible = true
	_since_plant = PLANT_SECONDS if _reduced() else 0.0
	_time = 0.0
	queue_redraw()


## The pole reaches `height` px below the flag's origin, plus POLE_BELOW.
func set_pole(height: float) -> void:
	_pole = height


## Whether it is still being planted.
func is_planting() -> bool:
	return visible and _since_plant < PLANT_SECONDS


## The flag's rect as drawn at rest (local): the pole and the cloth.
func rest_rect() -> Rect2:
	var top: float = -POLE_ABOVE
	return Rect2(
		-POLE_WIDTH / 2.0, top, POLE_WIDTH / 2.0 + CLOTH_SIZE.x, _pole + POLE_ABOVE + POLE_BELOW
	)


func _process(delta: float) -> void:
	if not visible:
		return
	_since_plant += delta
	_time += delta
	queue_redraw()


func _draw() -> void:
	var reduced: bool = _reduced()
	var drop: float = 0.0
	var turn: float = 0.0
	if not reduced and _since_plant < PLANT_SECONDS:
		# Down past its place by 2 px at 55 %, then back up; turning upright as it lands.
		var t: float = _since_plant / PLANT_SECONDS
		if t < 0.55:
			var e: float = t / 0.55
			drop = lerpf(-PLANT_DROP, 2.0, e)
			turn = lerpf(PLANT_TURN, 3.0, e)
		else:
			var e: float = (t - 0.55) / 0.45
			drop = lerpf(2.0, 0.0, e)
			turn = lerpf(3.0, 0.0, e)
	var foot: float = _pole + POLE_BELOW
	draw_set_transform(Vector2(0.0, roundf(drop)), deg_to_rad(turn), Vector2.ONE)
	var pole: Rect2 = Rect2(-POLE_WIDTH / 2.0, -POLE_ABOVE, POLE_WIDTH, foot + POLE_ABOVE)
	draw_rect(pole.grow(1.0), Palette.INK)
	draw_rect(pole, Palette.PAPER)
	var skew: float = 0.0
	if not reduced and _since_plant >= PLANT_SECONDS:
		skew = -deg_to_rad(FLAP_SKEW) * (0.5 - 0.5 * cos(TAU * _time / FLAP_SECONDS))
	var cloth_origin: Vector2 = Vector2(POLE_WIDTH / 2.0, -POLE_ABOVE + roundf(drop))
	var transform: Transform2D = Transform2D(deg_to_rad(turn), Vector2.ONE, skew, cloth_origin)
	draw_set_transform_matrix(transform)
	var cloth: Rect2 = Rect2(Vector2.ZERO, CLOTH_SIZE)
	draw_rect(cloth, Palette.INK)
	draw_rect(cloth.grow(-BORDER), Palette.GOOD)
	var check: PackedVector2Array = PackedVector2Array(
		[Vector2(5, 7), Vector2(8, 10), Vector2(13, 4)]
	)
	draw_polyline(check, Palette.PAPER, 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
