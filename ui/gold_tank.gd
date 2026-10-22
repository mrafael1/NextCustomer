class_name GoldTank
extends Control
## The count's gold tank on the monitor (the monitor juice, mock-up monitor_juice_v2.html, the
## user's picks of 2026-10-22: K1 "one tank", FILL A liquid gold, FONT C banded gold with a shine;
## presentation/gold_tank.gdshader draws it): the LED's digits and their € are one glass window
## onto the same gold. One waterline runs across the whole group at the shown total / the quota
## (level(): 0 at the bottom of the group's ink, 1 at its top), held at CountUpTuning.tank_hold
## until the payout that meets the quota lands (set_reading's `met`); that landing fills it over
## the brim (tank_overfill) in the same frame as the win. It follows each tick of the count on a
## stiff spring; the empty part is grey-beige glass with a glare per glyph. Each landing (land())
## kicks the surface's waves, sends a ripple both ways from the group's middle and gives the points
## its droplets jump from (surface_points, for TankBurst); bubbles rise in it. FONT C's shine
## (shine()) rises up the number and the € together, with twinkles on the group's top (drawn
## here, over the labels). The digits alone punch (punch(): about their bottom right corner, so they
## keep the €'s baseline and grow left, never past the room LedDisplay.punch_room gives, at most
## digits_punch_max); the € never moves or scales.
##
## LedDisplay owns it (a child over its labels, at the LED's origin, as big as the LED) and lays
## the group out for it (set_group, in the LED's own px, at rest); in the count layout the digits
## take fill_material and the € euro_material: the same gold, each mapped from its own label's
## place in the LED (so the monitor's shakes never move the gold against the glyphs), and the
## dessert's TOTAL slam takes a still copy mapped to its own glyphs (slam_material). Everything
## runs in real time (_process, advance()), so the count's hit-stops never freeze it; hidden (the
## compact layout), a punch still running ends at once. Reduced motion (`reduced_motion`): the
## level is its target at once and the surface flat, with no ripple, bubbles, shine, twinkles or
## punch. Display only: the amounts are the LED's.

const SHADER := preload("res://presentation/gold_tank.gdshader")
## The shader's arrays: glyph glares, bubbles and shines at most.
const GLARES := 6
const BUBBLES := 8
const SHINES := 2
## The spring's fixed step (s), so a slow frame never shakes it loose.
const STEP := 1.0 / 120.0
## The shader's fill pass test: the hue (the colour over its brightest channel) within this of
## the fill colour's (as gold_tank.gdshader's fill_tolerance), its brightest channel over
## FILL_DARKEST.
const FILL_TOLERANCE := 0.02
const FILL_DARKEST := 0.02
## The twinkles: a 7x7 glyph (w white, y mustard pale) shown up to TWINKLE_SCALE x at its peak,
## TWINKLE_INSET px in from the group's ends and up to TWINKLE_DROP px under its top.
const TWINKLE_GLYPH: Array[String] = [
	"...w...", "...w...", "..wyw..", "wwyyyww", "..wyw..", "...w...", "...w..."
]
const TWINKLE_SCALE := 2.0
const TWINKLE_INSET := 6.0
const TWINKLE_TOP := 2.0
const TWINKLE_DROP := 10.0
## Droplets leave from DROP_INSET px in from the group's ends, at least DROP_FLOOR px over its
## baseline.
const DROP_INSET := 4.0
const DROP_FLOOR := 2.0
## The punch's ease (back out, as the mock-up's) passes its target by at most this share.
const BACK := 1.70158
const BACK_PEAK := 1.0998
const RANDOM_SEED := 7

static var _twinkle: Texture2D

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The digits' fill material (the shader above) and the €'s: the same gold, each mapped from its
## own label.
var fill_material: ShaderMaterial:
	get:
		return _material
var euro_material: ShaderMaterial:
	get:
		return _euro_material

var _tuning: CountUpTuning
var _material: ShaderMaterial
var _euro_material: ShaderMaterial
var _led: LedDisplay
var _digits: Label
var _euro: Label
## The level now, its speed and its target; whether the quota is met.
var _level: float = 0.0
var _speed: float = 0.0
var _target: float = 0.0
var _met: bool = false
## Real seconds since the tank started, and what each effect started at.
var _time: float = 0.0
var _left_over: float = 0.0
var _kick: float = 0.0
var _ripple_at: float = -INF
var _shines: Array[float] = []
## Each twinkle: (start, across 0-1, down 0-1).
var _twinkles: Array[Vector3] = []
## Each bubble: (across 0-1, risen px, px per second).
var _bubbles: Array[Vector3] = []
## The punch: when it started, its target, the scale it started from.
var _punch_at: float = -INF
var _punch_to: float = 1.0
var _punch_from: float = 1.0
var _punching: bool = false
## The group at rest (LED px): the digits' ink top and baseline, the group's top, bottom, left and
## right, and each glyph's left.
var _ink_top: float = 0.0
var _base: float = 0.0
var _top: float = 0.0
var _bottom: float = 0.0
var _left: float = 0.0
var _right: float = 0.0
var _glares: PackedFloat32Array = PackedFloat32Array()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


## The tank of `led`, whose `digits` punch and whose `euro` stays.
func _init(led: LedDisplay = null, digits: Label = null, euro: Label = null) -> void:
	name = "GoldTank"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_led = led
	_digits = digits
	_euro = euro
	_random.seed = RANDOM_SEED
	_material = _new_material()
	_euro_material = _new_material()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance(delta)


func _notification(what: int) -> void:
	# Hidden (the compact layout), a punch still running ends: the digits back at 1.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_end_punch()


func _draw() -> void:
	if _reduced():
		return
	var span: float = _right - _left - 2.0 * TWINKLE_INSET
	for twinkle: Vector3 in _twinkles:
		var age: float = (_time - twinkle.x) / tuning().twinkle_s
		if age < 0.0 or age > 1.0:
			continue
		var grow: float = age * 2.0 if age < 0.5 else 2.0 - age * 2.0
		var side: float = roundf(_texture().get_width() * TWINKLE_SCALE * grow)
		if side <= 0.0:
			continue
		var centre: Vector2 = Vector2(
			_left + TWINKLE_INSET + twinkle.y * span,
			_ink_top + TWINKLE_TOP + twinkle.z * TWINKLE_DROP
		)
		draw_texture_rect(
			_texture(),
			Rect2((centre - Vector2(side, side) / 2.0).round(), Vector2(side, side)),
			false
		)


## The tuning (CountUp.TUNING_PATH unless set).
func tuning() -> CountUpTuning:
	if _tuning == null:
		_tuning = load(CountUp.TUNING_PATH) as CountUpTuning
	return _tuning


func set_tuning(value: CountUpTuning) -> void:
	_tuning = value


## The group at rest, in the LED's px: the digits' ink top and baseline (the gold's bands span
## them), the group's ink top and bottom (the € may reach past the digits), its left (the digits')
## and right (the €'s), and each glyph's left (its glare).
func set_group(
	ink_top: float,
	base: float,
	group_top: float,
	group_bottom: float,
	left: float,
	right: float,
	glares: PackedFloat32Array
) -> void:
	_ink_top = ink_top
	_base = base
	_top = group_top
	_bottom = group_bottom
	_left = left
	_right = right
	_glares = glares
	_push()


## A new count: empty, still, nothing running.
func reset() -> void:
	_level = 0.0
	_speed = 0.0
	_target = 0.0
	_met = false
	_kick = 0.0
	_ripple_at = -INF
	_shines.clear()
	_twinkles.clear()
	_bubbles.clear()
	_end_punch()
	_push()


## The shown `amount` against `quota`; `met` once the payout that meets it has landed (the win).
func set_reading(amount: int, quota: int, met: bool) -> void:
	_met = met
	var tune: CountUpTuning = tuning()
	if met:
		_target = tune.tank_overfill
	elif quota <= 0:
		_target = tune.tank_hold
	else:
		_target = minf(tune.tank_hold, float(maxi(amount, 0)) / quota)
	if _reduced():
		_settle()
	_push()


## The level at its target at once (a resumed checkout's end state).
func settle() -> void:
	_settle()
	_push()


## A payout lands: the surface sloshes and a ripple spreads both ways from the group's middle.
func land() -> void:
	if _reduced():
		return
	_kick = 1.0
	_ripple_at = _time


## FONT C's shine rises up the number and the € (`big`: the total's, a second shine after it),
## with twinkles on the group's top.
func shine(big: bool = false) -> void:
	if _reduced():
		return
	var tune: CountUpTuning = tuning()
	_shines.append(_time)
	if big:
		_shines.append(_time + tune.shine_second_s)
	for index: int in range(tune.twinkles_total if big else tune.twinkles):
		_twinkles.append(
			Vector3(_time + index * tune.twinkle_stagger_s, _random.randf(), _random.randf())
		)
	queue_redraw()


## The digits punch for a count punch of `strength` (CountUpTuning.digits_punch), with a
## subtotal `amount` about to show (-1: the one shown), within LedDisplay.punch_room; the €
## stays. A new punch starts from the scale shown.
func punch(strength: float, amount: int = -1) -> void:
	if _reduced() or _digits == null:
		return
	var tune: CountUpTuning = tuning()
	var room: float = _led.punch_room(amount) if _led != null else INF
	var cap: float = minf(room, tune.digits_punch_max if tune.digits_punch_max > 0.0 else INF)
	var from: float = punch_scale()
	var to: float = tune.digits_punch(strength)
	# The ease's overshoot never takes the peak past the cap.
	to = minf(to, from + (cap - from) / BACK_PEAK)
	_punch_from = from
	_punch_to = maxf(1.0, to)
	_punch_at = _time
	_punching = true


## A still copy of the gold for the dessert's TOTAL slam (`slam`: a label of the digits' text,
## font, font size, alignment and size, CountUpDessert's): mapped from the slam's own glyphs as
## the digits' at rest, so the gold follows them as the slam scales and moves; the level at its
## target (over the brim when met), flat, with no glares, ripple, bubbles or shine.
func slam_material(slam: Label = null) -> ShaderMaterial:
	var copy: ShaderMaterial = _new_material()
	_push_to(copy, true)
	var origin: Vector2 = _digits.position if _digits != null else Vector2.ZERO
	if slam != null and _digits != null:
		origin.y += _text_top(_digits) - _text_top(slam)
	copy.set_shader_parameter(&"label_origin", origin)
	copy.set_shader_parameter(&"label_scale", Vector2.ONE)
	copy.set_shader_parameter(&"level_y", _bottom - _target * (_bottom - _top))
	return copy


## Whether the shader repaints a pass drawn in `colour` (its vertex colour: the font colour times
## the ancestors' modulate) as the gold: its hue is the fill colour's, any grey dim or fade aside.
## The shader's own test, here for checks.
static func is_fill_colour(colour: Color) -> bool:
	var marker: Color = LedDisplay.COUNT_DIGITS_COLOR
	var bright: float = maxf(colour.r, maxf(colour.g, colour.b))
	if bright <= FILL_DARKEST:
		return false
	var marker_peak: float = maxf(marker.r, maxf(marker.g, marker.b))
	var hue: Vector3 = Vector3(colour.r, colour.g, colour.b) / bright
	return hue.distance_to(_raw(marker) / marker_peak) < FILL_TOLERANCE


## The digits' punch scale now (1 at rest).
func punch_scale() -> float:
	if not _punching:
		return 1.0
	var tune: CountUpTuning = tuning()
	var age: float = _time - _punch_at
	if age < 0.0 or age > tune.digits_punch_up_s + tune.digits_punch_down_s:
		return 1.0
	if age < tune.digits_punch_up_s:
		return _punch_from + (_punch_to - _punch_from) * _back_out(age / tune.digits_punch_up_s)
	var down: float = (age - tune.digits_punch_up_s) / tune.digits_punch_down_s
	return _punch_to + (1.0 - _punch_to) * _back_out(down)


## Moves everything on by `delta` real seconds (_process calls it; tests step it).
func advance(delta: float) -> void:
	var tune: CountUpTuning = tuning()
	_time += delta
	if _reduced():
		_settle()
	else:
		_left_over += delta
		while _left_over >= STEP:
			_left_over -= STEP
			_spring(STEP)
		_kick *= exp(-delta * tune.tank_kick_decay)
		_run_bubbles(delta)
	var shines: Array[float] = []
	for start: float in _shines:
		if _time - start < tune.shine_s:
			shines.append(start)
	_shines = shines
	var twinkles: Array[Vector3] = []
	for twinkle: Vector3 in _twinkles:
		if _time - twinkle.x < tune.twinkle_s:
			twinkles.append(twinkle)
	_twinkles = twinkles
	_apply_punch()
	_push()
	queue_redraw()


## The level now (0 empty to 1 full; past 1 over the brim) and its target.
func level() -> float:
	return _level


func target() -> float:
	return _target


## The waterline over `x` (the LED's px) now, as the shader draws it: at rest the group's ink
## bottom less the level's share of its height, plus the waves and a landing's ripple.
func waterline_at(x: float) -> float:
	var y: float = _rest_line()
	if _reduced():
		return y
	var tune: CountUpTuning = tuning()
	var amplitude: float = tune.tank_wave_px + _kick * tune.tank_kick_px
	y += sin(x * 0.16 + _time * 7.0) * amplitude * 0.6
	y += sin(x * 0.06 - _time * 4.3) * amplitude * 0.4
	var age: float = _time - _ripple_at
	if age >= 0.0 and age < tune.tank_ripple_s:
		var distance: float = absf(x - _ripple_middle()) - age * tune.tank_ripple_speed
		y -= (
			tune.tank_ripple_px
			* exp(-distance * distance / tune.tank_ripple_width)
			* (1.0 - age / tune.tank_ripple_s)
		)
	return y


## The group's ink at rest (global): from the digits' left to the €'s right, its top to its
## bottom.
func group_rect() -> Rect2:
	var local: Rect2 = Rect2(_left, _top, _right - _left, _bottom - _top)
	var transform: Transform2D = get_global_transform()
	return Rect2(transform * local.position, local.size * transform.get_scale())


## `count` points on the surface across the group (global), where a landing's droplets jump from.
func surface_points(count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var transform: Transform2D = get_global_transform()
	for _index: int in range(count):
		var x: float = _left + DROP_INSET + _random.randf() * (_right - _left - 2.0 * DROP_INSET)
		var y: float = clampf(waterline_at(x), _ink_top, _base - DROP_FLOOR)
		points.append(transform * Vector2(x, y))
	return points


## The shines' tops now (the LED's px), and how many bubbles show.
func shine_tops() -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	var tune: CountUpTuning = tuning()
	for start: float in _shines:
		var age: float = (_time - start) / tune.shine_s
		if age >= 0.0 and age <= 1.0:
			var rise: float = _bottom - _top + tune.shine_past_px
			tops.append(_q2(_bottom + tune.shine_below_px - age * rise))
	return tops


func bubble_count() -> int:
	return _bubbles.size()


func twinkle_count() -> int:
	return _twinkles.size()


func _settle() -> void:
	_level = _target
	_speed = 0.0


## One spring step: the level follows its target, never past the hold's slack before the win or
## tank_overfill_max after it.
func _spring(step: float) -> void:
	var tune: CountUpTuning = tuning()
	_speed += ((_target - _level) * tune.tank_stiffness - _speed * tune.tank_damping) * step
	var ceiling: float = tune.tank_overfill_max if _met else tune.tank_hold + tune.tank_hold_slack
	_level = clampf(_level + _speed * step, 0.0, ceiling)


func _run_bubbles(delta: float) -> void:
	var tune: CountUpTuning = tuning()
	if _level > tune.tank_bubble_from and _bubbles.size() < BUBBLES:
		var rate: float = tune.tank_bubble_rate + _level * tune.tank_bubble_rate_full
		if _random.randf() < delta * rate:
			var speed: float = _random.randf_range(
				tune.tank_bubble_speed.x, tune.tank_bubble_speed.y
			)
			_bubbles.append(Vector3(0.15 + _random.randf() * 0.7, 0.0, speed))
	var kept: Array[Vector3] = []
	for bubble: Vector3 in _bubbles:
		bubble.y += bubble.z * delta
		if bubble.y < tune.tank_bubble_rise:
			kept.append(bubble)
	_bubbles = kept


func _apply_punch() -> void:
	if not _punching or _digits == null:
		return
	var scale_now: float = punch_scale()
	if _time - _punch_at > tuning().digits_punch_up_s + tuning().digits_punch_down_s:
		_end_punch()
		return
	_digits.scale = Vector2(scale_now, scale_now)


func _end_punch() -> void:
	if _punching and _digits != null:
		_digits.scale = Vector2.ONE
	_punching = false


## The waterline at rest: the group's ink bottom less the level's share of its height.
func _rest_line() -> float:
	return _bottom - _level * (_bottom - _top)


func _ripple_middle() -> float:
	return (_left + _right) / 2.0


## Sends the state to the shader (both labels' materials): the group, the waterline, the waves,
## the ripple, the glares, the bubbles and the shines, and each label's place in the LED.
func _push() -> void:
	_push_to(_material, false)
	_push_to(_euro_material, false)
	_map(_material, _digits)
	_map(_euro_material, _euro)


## `into` gets the state; `still` (the slam's copy): flat, with no glares, ripple, bubbles or
## shines.
func _push_to(into: ShaderMaterial, still: bool) -> void:
	var tune: CountUpTuning = tuning()
	into.set_shader_parameter(&"ink_top", _ink_top)
	into.set_shader_parameter(&"ink_base", _base)
	into.set_shader_parameter(&"level_y", _rest_line())
	var reduced: bool = still or _reduced()
	var wave: float = 0.0 if reduced else tune.tank_wave_px + _kick * tune.tank_kick_px
	into.set_shader_parameter(&"wave_px", wave)
	into.set_shader_parameter(&"wave_time", _time)
	var age: float = _time - _ripple_at
	into.set_shader_parameter(&"ripple_age", -1.0 if reduced or is_inf(age) else age)
	into.set_shader_parameter(&"ripple_x", _ripple_middle())
	into.set_shader_parameter(&"ripple_px", tune.tank_ripple_px)
	into.set_shader_parameter(&"ripple_speed", tune.tank_ripple_speed)
	into.set_shader_parameter(&"ripple_width", maxf(1.0, tune.tank_ripple_width))
	into.set_shader_parameter(&"ripple_s", maxf(0.001, tune.tank_ripple_s))
	var glares: PackedFloat32Array = PackedFloat32Array() if still else _glares.slice(0, GLARES)
	into.set_shader_parameter(&"glare_count", glares.size())
	glares.resize(GLARES)
	into.set_shader_parameter(&"glare_x", glares)
	var bubbles: PackedVector2Array = PackedVector2Array()
	if not reduced:
		for bubble: Vector3 in _bubbles:
			var x: float = _q2(_left + bubble.x * (_right - _left))
			bubbles.append(Vector2(x, _q2(_base - 3.0 - bubble.y)))
	into.set_shader_parameter(&"bubble_count", bubbles.size())
	bubbles.resize(BUBBLES)
	into.set_shader_parameter(&"bubbles", bubbles)
	var tops: PackedFloat32Array = PackedFloat32Array() if reduced else shine_tops()
	tops = tops.slice(0, SHINES)
	into.set_shader_parameter(&"shine_count", tops.size())
	tops.resize(SHINES)
	into.set_shader_parameter(&"shines", tops)


## `label`'s place in the LED for `into` (its transform there, punch included; the tank sits at
## the LED's origin): the label's own points map to the LED's px with it.
func _map(into: ShaderMaterial, label: Label) -> void:
	var transform: Transform2D = Transform2D.IDENTITY
	if label != null:
		transform = get_transform().affine_inverse() * label.get_transform()
	into.set_shader_parameter(&"label_origin", transform.origin)
	into.set_shader_parameter(&"label_scale", transform.get_scale())


func _new_material() -> ShaderMaterial:
	var made: ShaderMaterial = ShaderMaterial.new()
	made.shader = SHADER
	made.set_shader_parameter(&"fill_marker", _raw(LedDisplay.COUNT_DIGITS_COLOR))
	made.set_shader_parameter(&"fill_tolerance", FILL_TOLERANCE)
	return made


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


## The mock-up's back-out ease (it passes 1 near the end and comes back).
static func _back_out(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0) - 1.0
	return p * p * ((BACK + 1.0) * p + BACK) + 1.0


## The top of `label`'s line box (local): centred on its height when vertically centred, else
## at 0.
static func _text_top(label: Label) -> float:
	if label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		return 0.0
	var font: Font = label.get_theme_font("font")
	return (label.size.y - font.get_height(label.get_theme_font_size("font_size"))) / 2.0


static func _q2(value: float) -> float:
	return roundf(value / 2.0) * 2.0


## A colour as the vertex colour carries it (no conversion), for the shader's fill marker.
static func _raw(colour: Color) -> Vector3:
	return Vector3(colour.r, colour.g, colour.b)


static func _texture() -> Texture2D:
	if _twinkle == null:
		var colours: Dictionary[String, Color] = {"w": Palette.PAPER, "y": Palette.MUSTARD_PALE}
		var rows: Array[String] = TWINKLE_GLYPH
		var image: Image = Image.create_empty(
			rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8
		)
		for y: int in range(rows.size()):
			for x: int in range(rows[y].length()):
				var key: String = rows[y][x]
				if colours.has(key):
					image.set_pixel(x, y, colours[key])
		_twinkle = ImageTexture.create_from_image(image)
	return _twinkle
