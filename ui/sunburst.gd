class_name Sunburst
extends ColorRect
## A turning sunburst of cream and paper rays fanning out from a centre (it stood behind the
## monitor's count view in #86; since #105 piece 2 the monitor has PixelSunburst, and this one
## shines behind the toy reveal and the upgrade swap); once met (set_met) the rays turn mustard
## light and pale and reach further (met_radius: MET_RADIUS unless set).
## boost() (the quota met, with its pop) spins them BOOST times faster, easing back over
## BOOST_SECONDS, and grows them out to met_radius over grow_seconds (a back-out ease, as the
## mock-up's; at once when 0). Drawn by a canvas shader
## (presentation/sunburst.gdshader) on the art's 2 px grid. It turns in real time, so the count-up's
## hit-stops never freeze it; under reduced motion (`reduced_motion`) it stands still. Decor only:
## it takes no clicks.

const SHADER := preload("res://presentation/sunburst.gdshader")
## Half the number of rays (RAYS rays and RAYS gaps), the radius (MET_RADIUS once met, unless
## met_radius is set), the ellipse's vertical squash and the sampling grid (px).
const RAYS := 10
const RADIUS := 144.0
const MET_RADIUS := 168.0
const GROW_BACK := 1.70158
const SQUASH := 1.15
const PIXEL := 2.0
## Radians per second, and the boost: BOOST times as fast, easing back over BOOST_SECONDS.
const TURN := 0.22
const BOOST := 18.0
const BOOST_SECONDS := 1.2
const RAY_COLOR := Palette.CREAM
const GAP_COLOR := Palette.PAPER
const MET_RAY_COLOR := Palette.MUSTARD_LIGHT
const MET_GAP_COLOR := Palette.MUSTARD_PALE

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()
## The radius once met, and how long a boost grows the rays out to it (0: at once).
var met_radius: float = MET_RADIUS:
	set(value):
		met_radius = value
		if _shader != null:
			_apply()
var grow_seconds: float = 0.0

var _met: bool = false
var _angle: float = 0.0
var _boost_left: float = 0.0
var _grow_left: float = 0.0
var _shader: ShaderMaterial


## The sunburst over `rect`'s size, its rays about `centre` (in the rect's coordinates).
func _init(rect_size: Vector2 = Vector2.ZERO, centre: Vector2 = Vector2.ZERO) -> void:
	name = "Sunburst"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(GAP_COLOR, 0.0)
	size = rect_size
	_shader = ShaderMaterial.new()
	_shader.shader = SHADER
	_shader.set_shader_parameter(&"rect_size", rect_size)
	_shader.set_shader_parameter(&"centre", centre)
	_shader.set_shader_parameter(&"squash", SQUASH)
	_shader.set_shader_parameter(&"rays", float(RAYS))
	_shader.set_shader_parameter(&"pixel", PIXEL)
	material = _shader
	_apply()


## Met (gold rays, a little further) or not (cream rays).
func set_met(met: bool) -> void:
	_met = met
	if not met:
		_boost_left = 0.0
		_grow_left = 0.0
	_apply()


## The quota met with its pop: the rays spin BOOST times faster for a moment. Nothing under
## reduced motion.
func boost() -> void:
	if not _reduced():
		_boost_left = BOOST_SECONDS
		_grow_left = grow_seconds
		_apply()


func is_met() -> bool:
	return _met


## The rays' turn now (radians).
func angle() -> float:
	return _angle


## How fast the rays turn now (radians per second): TURN, up to BOOST times that just after a
## boost; 0 under reduced motion.
func turn_speed() -> float:
	if _reduced():
		return 0.0
	var left: float = _boost_left / BOOST_SECONDS
	return TURN * (1.0 + (BOOST - 1.0) * left * left)


## The radius now: RADIUS, met_radius once met (growing out to it just after a boost).
func radius() -> float:
	if not _met:
		return RADIUS
	if _grow_left <= 0.0 or grow_seconds <= 0.0:
		return met_radius
	var p: float = 1.0 - _grow_left / grow_seconds - 1.0
	var eased: float = p * p * ((GROW_BACK + 1.0) * p + GROW_BACK) + 1.0
	return RADIUS + (met_radius - RADIUS) * eased


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + turn_speed() * delta, TAU)
	_boost_left = maxf(0.0, _boost_left - delta)
	if _grow_left > 0.0:
		_grow_left = maxf(0.0, _grow_left - delta)
		_shader.set_shader_parameter(&"radius", radius())
	_shader.set_shader_parameter(&"angle", _angle)


func _apply() -> void:
	_shader.set_shader_parameter(&"ray_colour", MET_RAY_COLOR if _met else RAY_COLOR)
	_shader.set_shader_parameter(&"gap_colour", MET_GAP_COLOR if _met else GAP_COLOR)
	_shader.set_shader_parameter(&"radius", radius())


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
