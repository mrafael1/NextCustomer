class_name PixelSunburst
extends ColorRect
## A gold pixel sunburst (#105 piece 2, mock-up readability_v3.html): an ellipse of `art_size` art
## pixels shown `pixel` px each, mustard light rays and mustard pale gaps (16 sectors) about its
## centre (presentation/pixel_sunburst.gdshader), turning `spin` degrees per second of real time
## while shown (none under `reduced_motion`). The checkout column's small one behind the number
## once the quota is met (50 x 34 at 2x), the climax's big one (110 x 70 at 4x). Decor only: it
## takes no clicks.

const SHADER := preload("res://presentation/pixel_sunburst.gdshader")
const RAY_COLOR := Palette.MUSTARD_LIGHT
const GAP_COLOR := Palette.MUSTARD_PALE

## Degrees per second.
var spin: float = 0.0
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
var _angle: float = 0.0
var _shader: ShaderMaterial


func _init(art_size: Vector2 = Vector2(50, 34), pixel: float = 2.0) -> void:
	name = "PixelSunburst"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(GAP_COLOR, 0.0)
	size = art_size * pixel
	pivot_offset = size / 2.0
	_shader = ShaderMaterial.new()
	_shader.shader = SHADER
	_shader.set_shader_parameter(&"art_size", art_size)
	_shader.set_shader_parameter(&"ray_colour", RAY_COLOR)
	_shader.set_shader_parameter(&"gap_colour", GAP_COLOR)
	material = _shader


func _process(delta: float) -> void:
	if not is_visible_in_tree() or spin == 0.0:
		return
	if reduced_motion.is_valid() and bool(reduced_motion.call()):
		return
	set_angle(_angle + deg_to_rad(spin) * delta)


## The disc's turn (radians).
func set_angle(radians: float) -> void:
	_angle = fposmod(radians, TAU)
	_shader.set_shader_parameter(&"angle", _angle)


func angle() -> float:
	return _angle
