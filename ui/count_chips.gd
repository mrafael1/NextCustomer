class_name CountChips
extends Control
## The count's flying amounts and landing sparks on the monitor (#105 piece 2, mock-up
## readability_v3.html, monitor b), on a layer over the whole paper that clips to it. Each landing
## beat's amount (a paper "+4€" for a base, a gold "+1€" or "×2", a grey "−3€" for a fall) hops from
## the item column (its price, or its step line's amount) to just short of the number's left edge
## over the beat's fly_ms: across first, then up, turned CHIP_TILT, dissolving from
## chip_dissolve_from of its flight so it never covers the digits; a ×'s chip (1.1x) flips into
## its gain ("+5€") halfway. WASTED's grey "€0" drops off its step line (waste_drop_s, falling and
## turning, fading at the end) and never lands. As a landing lands, `land` throws its sparks out of
## the number's sides (base none, +N 3, × 6) and a × also shoots gold corners round the number and
## two coins off it, down and out.
##
## Everything runs on `make_tween`'s tweens (the count's clock, so taps, holds and hit-stops move
## it). Under reduced motion nothing flies or sparks: the states are the number's and the ladder's.
## Decor only: every text is the beat's.

## A flying chip: its label's font (800, CHIP_FONT_SIZE), height and padding, turned CHIP_TILT.
const CHIP_FONT_SIZE := 16
const CHIP_HEIGHT := 26.0
const CHIP_PADDING := 16.0
const CHIP_TILT := -4.0
## A ×'s chip flies this much bigger.
const MUL_SCALE := 1.1
## Its chip's right edge (at full size) stops this far left of the number's left edge, so a chip
## never covers the digits (the mock-up's stop, 20 px short with its centre, let a wide chip's
## edge cross them).
const LAND_SHORT := 2.0
## The chip's label art: 2 px texels, its corners a stair of CORNER texels.
const TEXEL := 2.0
const CORNER: Array[int] = [3, 1, 1]
const LABEL_ROWS := 16
const LABEL_TOP := -3.0
## Sparks: their angles (degrees) per side and step, the ellipse's squash, the ring's start.
const SPARK_SIDE_RIGHT := -20.0
const SPARK_SIDE_LEFT := 200.0
const SPARK_STEP := 22.0
const SPARK_SQUASH := 0.6
const SPARK_START := 4.0
## A ×'s corners: CORNER_ARM long, CORNER_THICK thick, CORNER_HEIGHT tall round the number.
const CORNER_ARM := 8.0
const CORNER_THICK := 2.0
const CORNER_HEIGHT := 38.0
const CORNER_SIDE := 8.0
## A ×'s two coins: from COIN_OUT px either side of the number, out at COIN_SPEED px/s (the second
## COIN_SECOND as fast), up at COIN_RISE px/s, falling at COIN_GRAVITY px/s², flipping at
## COIN_FLIP radians per second; their top COIN_TOP under the paper's top.
const COIN_OUT := 50.0
const COIN_SPEED := 150.0
const COIN_SECOND := 0.8
const COIN_RISE := 60.0
const COIN_GRAVITY := 1120.0
const COIN_FLIP := 22.0
const COIN_TOP := 72.0
const COIN_SIZE := Vector2(24, 24)
const COIN := preload("res://art/icons/coin.png")

## Returns a new Tween on the count's clock; none: the layer's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _tuning: CountTotalTuning
## The live effects (sparks, corners, coins): each a Dictionary with its kind, its age `q` and its
## place.
var _effects: Array[Dictionary] = []
var _chips: Array[Chip] = []


## One flying label: its art and text drawn in its own rect, turned and scaled about its centre.
class Chip:
	extends Control

	enum Look { PAPER, GOLD, GREY }

	var look: Look = Look.PAPER
	var text: String = ""

	func _init(shown: String, chip_look: Look) -> void:
		name = "Chip"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		look = chip_look
		set_text(shown)

	## Its text, and its width for it (on the 2 px grid).
	func set_text(shown: String) -> void:
		text = shown
		size = Vector2(CountChips.chip_width(shown), CHIP_HEIGHT)
		pivot_offset = size / 2.0
		queue_redraw()

	func _draw() -> void:
		var colours: Array[Color] = _colours()
		var columns: int = roundi(size.x / TEXEL)
		var shadow: Color = Color(Palette.INK, 0.42)
		for row: int in range(LABEL_ROWS):
			var inset: int = _inset(row)
			var y: float = LABEL_TOP + row * TEXEL
			var left: float = inset * TEXEL
			var width: float = (columns - 2 * inset) * TEXEL
			draw_rect(Rect2(left + 2.0, y + 2.0, width, TEXEL), shadow)
		for row: int in range(LABEL_ROWS):
			var inset: int = _inset(row)
			var y: float = LABEL_TOP + row * TEXEL
			for column: int in range(inset, columns - inset):
				var colour: Color = _texel(row, column, columns, colours)
				draw_rect(Rect2(column * TEXEL, y, TEXEL, TEXEL), colour)
		var font: Font = ArtStyle.bold_font(800)
		var ascent: float = font.get_ascent(CHIP_FONT_SIZE)
		var line: float = ascent + font.get_descent(CHIP_FONT_SIZE)
		var baseline: float = -2.0 + (24.0 - line) / 2.0 + ascent
		var ink: Color = Palette.INK_LIGHT if look == Look.GREY else Palette.INK
		draw_string(
			font,
			Vector2(0.0, roundf(baseline)),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			CHIP_FONT_SIZE,
			ink
		)

	## The texel at `row`, `column` of the label (see the mock-up's labelURL).
	func _texel(row: int, column: int, columns: int, colours: Array[Color]) -> Color:
		var inset: int = _inset(row)
		var edge: bool = column == inset or column == columns - 1 - inset or row == 0
		if edge or row >= LABEL_ROWS - 2:
			return Palette.INK
		if row == LABEL_ROWS - 3:
			return colours[3]
		if row == LABEL_ROWS - 4:
			return colours[2]
		var above: int = _inset(row - 1)
		if row == 1 or column == inset + 1 or column <= above:
			return colours[0]
		if column == columns - 2 - inset:
			return colours[2]
		return colours[1]

	## Highlight, face, shade and lip.
	func _colours() -> Array[Color]:
		match look:
			Look.GOLD:
				return [Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD, Palette.MUSTARD_DARK]
			Look.GREY:
				return [
					Palette.STEEL_HIGHLIGHT, Palette.STEEL_LIGHT, Palette.STEEL_PALE, Palette.STEEL
				]
		return [Color.WHITE, Palette.PAPER, Palette.CREAM_SHADE, Palette.CREAM_SHADE.darkened(0.2)]

	static func _inset(row: int) -> int:
		var from_edge: int = mini(row, LABEL_ROWS - 1 - row)
		return CORNER[from_edge] if from_edge >= 0 and from_edge < CORNER.size() else 0


func _init(tuning: CountTotalTuning = null) -> void:
	name = "CountChips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning


## A chip's width for `shown`: its text plus CHIP_PADDING, on the 2 px grid.
static func chip_width(shown: String) -> float:
	var font: Font = ArtStyle.bold_font(800)
	var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE).x
	return ceilf((width + CHIP_PADDING) / 2.0) * 2.0


## `beat`'s amount takes off from `from` (global) toward `to` (global; the number's left edge at
## its middle, CheckoutColumn.landing_point) and arrives in its fly_ms, its right edge LAND_SHORT
## short of it; a WASTE drops its grey €0 from `from`. None under reduced motion or for a beat that
## does not land.
func launch(beat: CountUpBeat, from: Vector2, to: Vector2) -> void:
	if _reduced() or not is_inside_tree():
		return
	if beat.land == CountUpBeat.Land.WASTE:
		_drop_waste(from)
		return
	if not CountUpPlan.is_landing(beat):
		return
	var look: Chip.Look = Chip.Look.GOLD
	var text: String = MonitorText.gain(beat.gain)
	match beat.land:
		CountUpBeat.Land.BASE:
			look = Chip.Look.PAPER
		CountUpBeat.Land.DOWN:
			look = Chip.Look.GREY
		CountUpBeat.Land.MUL:
			text = beat.factor_text
	var chip: Chip = Chip.new(text, look)
	chip.rotation_degrees = CHIP_TILT
	add_child(chip)
	_chips.append(chip)
	var grow: float = MUL_SCALE if beat.land == CountUpBeat.Land.MUL else 1.0
	var widest: float = chip.size.x
	if beat.land == CountUpBeat.Land.MUL:
		widest = maxf(widest, chip_width(MonitorText.gain(beat.gain)))
	var local_from: Vector2 = _local(from)
	var local_to: Vector2 = _local(to) - Vector2(widest * grow / 2.0 + LAND_SHORT, 0.0)
	var flight: float = maxf(0.01, beat.fly_ms / 1000.0)
	_fly(0.0, chip, beat, local_from, local_to)
	var tween: Tween = _new_tween()
	tween.tween_method(_fly.bind(chip, beat, local_from, local_to), 0.0, 1.0, flight)
	tween.tween_callback(_drop_chip.bind(chip))


## `beat` lands on the number centred at `centre` (global), `width` wide: its sparks, and for a ×
## its corners and coins.
func land(beat: CountUpBeat, centre: Vector2, width: float) -> void:
	if _reduced() or not is_inside_tree():
		return
	var count: int = 0
	match beat.land:
		CountUpBeat.Land.BASE:
			count = _tuning.sparks_base
		CountUpBeat.Land.ADD:
			count = _tuning.sparks_add
		CountUpBeat.Land.MUL:
			count = _tuning.sparks_mul
	var at: Vector2 = _local(centre)
	if count > 0:
		_run({"kind": "sparks", "count": count, "at": at, "width": width}, _tuning.spark_s)
	if beat.land == CountUpBeat.Land.MUL:
		_run({"kind": "corners", "at": at, "width": width}, _tuning.corners_s)
		_run({"kind": "coins", "at": at}, _tuning.coin_s)


## The chips in flight now, for checks.
func chips() -> Array[Control]:
	var found: Array[Control] = []
	for chip: Chip in _chips:
		if is_instance_valid(chip):
			found.append(chip)
	return found


## The sparks shown now (their centres, local), for checks.
func spark_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for effect: Dictionary in _effects:
		if effect["kind"] == "sparks":
			points.append_array(_sparks_of(effect))
	return points


## Whether a ×'s corners or coins show now.
func has_corners() -> bool:
	return _effects.any(func(effect: Dictionary) -> bool: return effect["kind"] == "corners")


func has_coins() -> bool:
	return _effects.any(func(effect: Dictionary) -> bool: return effect["kind"] == "coins")


## Everything goes (a new count, the end state).
func clear() -> void:
	for chip: Chip in _chips:
		if is_instance_valid(chip):
			chip.queue_free()
	_chips.clear()
	_effects.clear()
	queue_redraw()


func _draw() -> void:
	for effect: Dictionary in _effects:
		match effect["kind"]:
			"sparks":
				_draw_sparks(effect)
			"corners":
				_draw_corners(effect)
			"coins":
				_draw_coins(effect)


## The chip at `progress` of its flight (see the class comment).
func _fly(progress: float, chip: Chip, beat: CountUpBeat, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(chip):
		return
	var across: float = 1.0 - (1.0 - progress) * (1.0 - progress)
	var centre: Vector2 = Vector2(
		lerpf(from.x, to.x, across), lerpf(from.y, to.y, progress * progress)
	)
	var dissolve: float = clampf(
		(progress - _tuning.chip_dissolve_from) / maxf(0.01, 1.0 - _tuning.chip_dissolve_from),
		0.0,
		1.0
	)
	var grow: float = MUL_SCALE if beat.land == CountUpBeat.Land.MUL else 1.0
	var flip_x: float = 1.0
	if beat.land == CountUpBeat.Land.MUL:
		var flip: float = (progress - _tuning.mul_flip_from) / maxf(0.01, _tuning.mul_flip_s)
		if flip >= 0.5 and chip.text != MonitorText.gain(beat.gain):
			chip.set_text(MonitorText.gain(beat.gain))
		if flip > 0.0 and flip < 1.0:
			flip_x = maxf(0.08, absf(cos(flip * PI)))
	var shrink: float = grow * (1.0 - 0.6 * dissolve)
	chip.scale = Vector2(shrink * flip_x, shrink)
	chip.modulate.a = 1.0 - dissolve
	chip.position = (centre - chip.size / 2.0).snapped(Vector2.ONE * TEXEL)


func _drop_chip(chip: Chip) -> void:
	_chips.erase(chip)
	if is_instance_valid(chip):
		chip.queue_free()


## WASTED's grey €0: it drops from `from` (global), falling and turning, fading at the end.
func _drop_waste(from: Vector2) -> void:
	var chip: Chip = Chip.new("€0", Chip.Look.GREY)
	add_child(chip)
	_chips.append(chip)
	var start: Vector2 = _local(from)
	_waste_at(0.0, chip, start)
	var tween: Tween = _new_tween()
	var seconds: float = _tuning.waste_drop_s
	tween.tween_method(_waste_at.bind(chip, start), 0.0, seconds, seconds)
	tween.tween_callback(_drop_chip.bind(chip))


func _waste_at(seconds: float, chip: Chip, start: Vector2) -> void:
	if not is_instance_valid(chip):
		return
	var centre: Vector2 = (
		start + Vector2(10.0 * seconds, 0.5 * _tuning.waste_gravity * seconds * seconds)
	)
	chip.position = (centre - chip.size / 2.0).snapped(Vector2.ONE * TEXEL)
	chip.rotation_degrees = _tuning.waste_spin * seconds
	var fade_s: float = maxf(0.01, _tuning.waste_drop_s - _tuning.waste_fade_from_s)
	chip.modulate.a = clampf(1.0 - (seconds - _tuning.waste_fade_from_s) / fade_s, 0.0, 1.0)


## Runs `effect` for `seconds` on the count's clock, its age in effect["q"].
func _run(effect: Dictionary, seconds: float) -> void:
	effect["q"] = 0.0
	_effects.append(effect)
	queue_redraw()
	var tween: Tween = _new_tween()
	tween.tween_method(_age.bind(effect), 0.0, seconds, seconds)
	tween.tween_callback(_end_effect.bind(effect))


func _age(seconds: float, effect: Dictionary) -> void:
	effect["q"] = seconds
	queue_redraw()


func _end_effect(effect: Dictionary) -> void:
	_effects.erase(effect)
	queue_redraw()


## A sparks effect's sparks now (local centres), alternating sides.
func _sparks_of(effect: Dictionary) -> Array[Vector2]:
	var q: float = effect["q"]
	var at: Vector2 = effect["at"]
	var width: float = effect["width"]
	var count: int = effect["count"]
	var out: float = clampf(q / maxf(0.01, _tuning.spark_out_s), 0.0, 1.0)
	var reach: float = width / 2.0 + SPARK_START + _tuning.spark_reach * (1.0 - pow(1.0 - out, 3.0))
	var points: Array[Vector2] = []
	for index: int in range(count):
		var right: bool = index % 2 == 1
		var step: int = floori(index / 2.0)
		var degrees: float = (
			SPARK_SIDE_RIGHT + SPARK_STEP * step if right else SPARK_SIDE_LEFT - SPARK_STEP * step
		)
		var angle: float = deg_to_rad(degrees)
		points.append(at + Vector2(cos(angle) * reach, sin(angle) * reach * SPARK_SQUASH))
	return points


## A spark: a plus of gold arms round a paper centre, or past spark_dot_from_s a dot.
func _draw_sparks(effect: Dictionary) -> void:
	var q: float = effect["q"]
	var points: Array[Vector2] = _sparks_of(effect)
	for index: int in range(points.size()):
		var at: Vector2 = points[index].snapped(Vector2.ONE * TEXEL)
		if q > _tuning.spark_dot_from_s:
			var dot: Color = Palette.MUSTARD_LIGHT if index % 2 == 1 else Palette.PAPER
			draw_rect(Rect2(at, Vector2.ONE * TEXEL), dot)
			continue
		for arm: Vector2 in [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)]:
			draw_rect(Rect2(at + arm, Vector2.ONE * TEXEL), Palette.GOLD)
		draw_rect(Rect2(at, Vector2.ONE * TEXEL), Palette.PAPER)


## A ×'s gold corners round the number, growing, white at first.
func _draw_corners(effect: Dictionary) -> void:
	var q: float = effect["q"]
	var at: Vector2 = effect["at"]
	var width: float = effect["width"]
	var grow_q: float = clampf(q / maxf(0.01, _tuning.corners_s * 0.94), 0.0, 1.0)
	var eased: float = grow_q * grow_q * (3.0 - 2.0 * grow_q)
	var grow: float = snappedf(_tuning.corners_grow * eased, TEXEL)
	var rect: Rect2 = Rect2(
		at.x - width / 2.0 - CORNER_SIDE - grow / 2.0,
		at.y - CORNER_HEIGHT / 2.0 + 1.0,
		width + 2.0 * CORNER_SIDE + grow,
		CORNER_HEIGHT
	)
	var colour: Color = Color.WHITE if q < _tuning.corners_white_s else Palette.GOLD
	for part: Rect2 in corner_rects(rect, CORNER_ARM, CORNER_THICK):
		draw_rect(part, colour)


## A ×'s two coins, out and down from the number's sides, flipping.
func _draw_coins(effect: Dictionary) -> void:
	var q: float = effect["q"]
	var at: Vector2 = effect["at"]
	for side: int in [-1, 1]:
		var speed: float = COIN_SPEED * (1.0 if side < 0 else COIN_SECOND)
		var x: float = at.x + side * (COIN_OUT + speed * q)
		var y: float = COIN_TOP - COIN_RISE * q + 0.5 * COIN_GRAVITY * q * q
		var flip: float = absf(cos(q * COIN_FLIP))
		var width: float = maxf(TEXEL, snappedf(COIN_SIZE.x * flip, TEXEL))
		var rect: Rect2 = Rect2(
			snappedf(x - width / 2.0, TEXEL),
			snappedf(y - COIN_SIZE.y / 2.0, TEXEL),
			width,
			COIN_SIZE.y
		)
		draw_texture_rect(COIN, rect, false)


## The eight bars of a rect's corners, each `arm` long and `thick` thick.
static func corner_rects(rect: Rect2, arm: float, thick: float) -> Array[Rect2]:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	return [
		Rect2(x, y, arm, thick),
		Rect2(x, y, thick, arm),
		Rect2(x + w - arm, y, arm, thick),
		Rect2(x + w - thick, y, thick, arm),
		Rect2(x, y + h - thick, arm, thick),
		Rect2(x, y + h - arm, thick, arm),
		Rect2(x + w - arm, y + h - thick, arm, thick),
		Rect2(x + w - thick, y + h - arm, thick, arm),
	]


func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _new_tween() -> Tween:
	if make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
