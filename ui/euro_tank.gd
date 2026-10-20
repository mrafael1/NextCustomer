class_name EuroTank
extends Control
## The big € tank (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html): the right column of
## the monitor's count view (MonitorView.TANK_RECT). A bold euro sign (art/effects/euro_tank.png,
## 60x75 art px at 2x) fills with gold as the shown amount climbs: full exactly at the quota, it
## never shows a share of a larger total. Its empty inside takes the top gauge's status colour
## (QuotaMeter's ramps: tomato while short, brass from QuotaMeter.NEAR_SHARE of the quota; the
## LIT_COLUMNS columns along each row's left edge in the ramp's light shade), eased like the top
## gauge. The gold is mustard with a mustard-light lip (paper once met) and a mustard-dark band
## at the bottom; each gain sloshes the surface and kicks the sign (a squash and stretch about its
## bottom centre); bubbles rise and a shine sweeps through the gold. Once met it is full, its lip
## wobbling. burst() (the quota met, with its pop) blinks the outline paper and kicks it hard.
## A 35 % ink shadow sits at SHADOW_OFFSET. Reduced motion (`reduced_motion`) keeps the level, the
## colours and the states and drops the wave, the bubbles, the shine, the blink and the kicks.
##
## It draws in art pixels (ArtStyle.ART_SCALE screen pixels each) by column runs, reading the
## sprite's inside (its cream shade pixels) once. All its motion runs in real time (_process), so
## the count-up's hit-stops never freeze it. Display only: the amount and the quota are the LED's
## (MonitorView connects LedDisplay.reading_changed to set_reading). The level follows each gain
## LAG_S later (#86 round 7, count_up_86_v7_bay.html: as the gold poured from the number lands in
## it), while the met state and the inside's status colour follow the reading at once. While a
## payout's chip flies into the number (hold, then release as it lands) its gains wait, so the
## level rises LAG_S after the landing, as the pour reaches the tank.

const TANK := preload("res://art/effects/euro_tank.png")
## The sprite's inside, filled in code.
const INSIDE_COLOR := Palette.CREAM_SHADE
const LIQUID_COLOR := Palette.MUSTARD
## The surface's LIP_ROWS rows, and the shine.
const LIP_COLOR := Palette.MUSTARD_LIGHT
const MET_LIP_COLOR := Palette.PAPER
## The gold's bottom DEEP_ROWS rows of the sign.
const DEEP_COLOR := Palette.MUSTARD_DARK
const BUBBLE_COLOR := Palette.MUSTARD_PALE
const BLINK_COLOR := Palette.PAPER
const SHADOW_COLOR := Palette.INK
const SHADOW_ALPHA := 0.35
## In art pixels.
const SHADOW_OFFSET := Vector2i(2, 2)
const LIT_COLUMNS := 2
const LIP_ROWS := 2
const DEEP_ROWS := 6
## The status colour lands on its ramp once its channels are within SNAP of it in all (under one
## step of 8-bit colour).
const SNAP := 0.003
## The shown level eases to the amount at this rate (per second), so a jump still pours.
const EASE_RATE := 10.0
## A gain reaches the level this long after the reading (real time; TankBurst's pour takes as
## long). None under reduced motion.
const LAG_S := 0.2
## The wave: a gain of N adds WAVE_KICK + N / WAVE_PER_EURO art pixels of amplitude, up to
## WAVE_MAX; it settles at WAVE_DECAY per second. A small ripple always runs (RIPPLE).
const WAVE_KICK := 1.6
const WAVE_PER_EURO := 9.0
const WAVE_MAX := 5.0
const WAVE_DECAY := 3.0
const RIPPLE := 0.8
## Once met the lip wobbles MET_WOBBLE art pixels (MET_WOBBLE_BURST more while the burst lasts).
const MET_WOBBLE := 1.0
const MET_WOBBLE_BURST := 2.0
## The shine sweeps across at SHINE_SPEED art pixels per second, leaning SHINE_LEAN per row.
const SHINE_SPEED := 40.0
const SHINE_LEAN := 0.5
const BUBBLES := 9
const BUBBLE_SPEED := Vector2(6.0, 16.0)
## Bubbles sway sideways up to this many art pixels per second.
const BUBBLE_SWAY := 18.0
## The burst: the outline blinks paper at BLINK_HZ (BLINK_REACH art pixels round the sign) for
## BURST_SECONDS.
const BLINK_HZ := 16.0
const BLINK_REACH := 2
const BURST_SECONDS := 0.6
## The kick: a squash (KICK_SQUASH across) and stretch (KICK_STRETCH up) per unit, swinging at
## KICK_RATE radians per second and fading over KICK_SECONDS; a gain kicks KICK_GAIN (KICK_GAIN_MET
## once met), the burst KICK_BURST.
const KICK_SQUASH := 0.08
const KICK_STRETCH := 0.12
const KICK_RATE := 28.0
const KICK_SECONDS := 0.5
const KICK_GAIN := 0.45
const KICK_GAIN_MET := 1.0
const KICK_BURST := 2.2
const RANDOM_SEED := 86
const HALO_STEPS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _amount: int = 0
## The last reading's amount (the status colour's), and the gains on their way to the level:
## (when, in _time; amount).
var _reading: int = 0
var _pending: Array[Vector2] = []
## The chips in flight (hold) and the gains read meanwhile: (when read, in _time; amount).
var _holds: int = 0
var _held: Array[Vector2] = []
var _quota: int = 0
var _met: bool = false
## The level drawn: the amount eased (EASE_RATE).
var _shown: float = 0.0
var _wave: float = 0.0
var _time: float = 0.0
## The burst's time left (seconds), and the kick's amplitude and age.
var _burst_left: float = 0.0
var _kick: float = 0.0
var _kick_age: float = 0.0
## The empty inside's colours as drawn ([light, body, dark]), eased to the status's ramp.
var _ramp: Array[Color] = QuotaMeter.SHORT_RAMP.duplicate()
## Per column of the sprite, its inside's runs of rows (x: first row, y: last row), the runs of its
## lit cells (the LIT_COLUMNS inside cells along each row's left edge) and its opaque runs.
var _runs: Array[Array] = []
var _lit_runs: Array[Array] = []
var _solid_runs: Array[Array] = []
var _top_row: int = 0
var _bottom_row: int = 0
var _solid_top: int = 0
var _bubbles: Array[Vector3] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "EuroTank"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TANK.get_size() * ArtStyle.ART_SCALE
	custom_minimum_size = size
	pivot_offset = Vector2(size.x / 2.0, size.y)
	ArtStyle.use_pixel_material(self)
	_random.seed = RANDOM_SEED
	_read_sprite()
	for _index: int in range(BUBBLES):
		_bubbles.append(_new_bubble(float(_random.randi_range(_top_row, _bottom_row))))


## The LED's reading: `amount` against `quota`, `met` once the count meets it. The met state and
## the status colour follow at once; a gain reaches the level LAG_S later (at once under reduced
## motion), sloshing the surface and kicking the sign; a lower amount (a new count) empties it at
## once.
func set_reading(amount: int, quota: int, met: bool) -> void:
	_quota = quota
	_met = met
	if amount < _reading:
		_drop_pending()
		_amount = amount
		_shown = float(amount)
		_burst_left = 0.0
	elif amount > _reading:
		if _reduced():
			_take(amount)
		elif _holds > 0:
			_held.append(Vector2(_time, amount))
		else:
			_pending.append(Vector2(_time + LAG_S, amount))
	_reading = amount
	if _reduced():
		_drop_pending()
		_amount = amount
		_shown = float(amount)
		_ramp = _status_ramp().duplicate()
	queue_redraw()


## A payout's chip starts flying into the number: gains wait for its release (MonitorView).
func hold() -> void:
	_holds += 1


## That chip lands: once none is flying, the gains read meanwhile reach the level LAG_S from now,
## each as far apart as they were read.
func release() -> void:
	if _holds == 0:
		return
	_holds -= 1
	if _holds > 0 or _held.is_empty():
		return
	var shift: float = _time - _held[0].x + LAG_S
	for gain: Vector2 in _held:
		_pending.append(Vector2(gain.x + shift, gain.y))
	_held.clear()


## The quota is met with its pop: the outline blinks paper for BURST_SECONDS and the sign kicks
## hard. Nothing under reduced motion.
func burst() -> void:
	if _reduced():
		return
	_burst_left = BURST_SECONDS
	_kick_at(KICK_BURST)
	queue_redraw()


## Everything at rest at once (a resumed checkout's end state): the level on the amount, the
## inside on its status colour, no wave, kick or blink.
func settle() -> void:
	_drop_pending()
	_amount = _reading
	_shown = float(_amount)
	_ramp = _status_ramp().duplicate()
	_wave = 0.0
	_burst_left = 0.0
	_kick = 0.0
	scale = Vector2.ONE
	queue_redraw()


## The tank's fill from 0 to 1 for `amount` against `quota` (full for a quota of 0). Display
## arithmetic only, as QuotaMeter.fill_fraction.
static func level_for(amount: int, quota: int) -> float:
	return QuotaMeter.fill_fraction(amount, quota)


## The level drawn now, from 0 to 1 (for tests).
func level() -> float:
	if _met:
		return 1.0
	return level_for(roundi(_shown), _quota)


## How many gains are on their way to the level (for tests).
func pending() -> int:
	return _pending.size() + _held.size()


## Whether the gold is overflowing (the quota met).
func is_overflowing() -> bool:
	return _met


## Whether the burst's blink is running.
func is_bursting() -> bool:
	return _burst_left > 0.0


## The empty inside's colours as drawn now: the ramp's light shade (the lit columns) and its body.
func inside_colours() -> Array[Color]:
	return [_ramp[0], _ramp[1]]


## The sign's top centre (global), where the gold jets out once met.
func top_point() -> Vector2:
	return get_global_transform() * Vector2(size.x / 2.0, _solid_top * ArtStyle.ART_SCALE)


## The gold's surface centre now (global), where a pour lands.
func surface_point() -> Vector2:
	return get_global_transform() * Vector2(size.x / 2.0, _surface_row() * ArtStyle.ART_SCALE)


## The sign as drawn at rest (global): the bounds of its opaque pixels (outline and inside), its
## shadow aside. Its rect's clear margins (the shadow's room among them) are not in it.
func sign_rect() -> Rect2:
	var bounds: Rect2i = Rect2i()
	for x: int in range(_solid_runs.size()):
		for run: Vector2i in _solid_runs[x]:
			var column: Rect2i = Rect2i(x, run.x, 1, run.y - run.x + 1)
			bounds = column if bounds.size == Vector2i.ZERO else bounds.merge(column)
	var cell: float = ArtStyle.ART_SCALE
	var local: Rect2 = Rect2(Vector2(bounds.position) * cell, Vector2(bounds.size) * cell)
	var to_global: Transform2D = get_global_transform()
	return Rect2(to_global * local.position, local.size * to_global.get_scale())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	while not _pending.is_empty() and _pending[0].x <= _time:
		var due: Vector2 = _pending.pop_front()
		_take(int(due.y))
	var target: Array[Color] = _status_ramp()
	var reduced: bool = _reduced()
	var weight: float = 1.0 if reduced else minf(1.0, delta * QuotaMeter.STATUS_EASE_RATE)
	for index: int in range(_ramp.size()):
		_ramp[index] = _ease_colour(_ramp[index], target[index], weight)
	if reduced:
		_shown = float(_amount)
		_wave = 0.0
		_burst_left = 0.0
		_kick = 0.0
		scale = Vector2.ONE
		queue_redraw()
		return
	_shown += (_amount - _shown) * minf(1.0, delta * EASE_RATE)
	if absf(_amount - _shown) < 0.3:
		_shown = float(_amount)
	_wave *= exp(-delta * WAVE_DECAY)
	_burst_left = maxf(0.0, _burst_left - delta)
	_kick_age += delta
	var fade: float = 1.0 - _kick_age / KICK_SECONDS
	var swing: float = 0.0
	if fade > 0.0:
		swing = sin(_kick_age * KICK_RATE) * _kick * fade * fade
	scale = Vector2(1.0 - swing * KICK_SQUASH, 1.0 + swing * KICK_STRETCH)
	_move_bubbles(delta)
	queue_redraw()


func _draw() -> void:
	var shadow: Color = Color(SHADOW_COLOR, SHADOW_ALPHA)
	_draw_solid(SHADOW_OFFSET, shadow)
	if _burst_left > 0.0 and int(_time * BLINK_HZ * 2.0) % 2 == 1:
		for step: Vector2i in HALO_STEPS:
			_draw_solid(step * BLINK_REACH, BLINK_COLOR)
	draw_texture_rect(TANK, Rect2(Vector2.ZERO, size), false)
	var reduced: bool = _reduced()
	var surface: float = _surface_row()
	var lip: Color = MET_LIP_COLOR if _met else LIP_COLOR
	var deep_top: int = _bottom_row - DEEP_ROWS + 1
	var burst_share: float = _burst_left / BURST_SECONDS
	for x: int in range(_runs.size()):
		var top: int = ceili(surface + _wave_at(x, burst_share, reduced))
		for run: Vector2i in _runs[x]:
			_span(x, run.x, mini(run.y, top - 1), _ramp[1])
		for run: Vector2i in _lit_runs[x]:
			_span(x, run.x, mini(run.y, top - 1), _ramp[0])
		for run: Vector2i in _runs[x]:
			var start: int = maxi(run.x, top)
			_span(x, start, run.y, LIQUID_COLOR)
			_span(x, maxi(start, deep_top), run.y, DEEP_COLOR)
			if top >= run.x:
				_span(x, start, mini(run.y, top + LIP_ROWS - 1), lip)
	if reduced:
		return
	_draw_shine(surface, lip)
	for bubble: Vector3 in _bubbles:
		var cell: Vector2i = Vector2i(roundi(bubble.x), roundi(bubble.y))
		if cell.y > ceili(surface) + LIP_ROWS and _inside(cell):
			_span(cell.x, cell.y, cell.y, BUBBLE_COLOR)


## The surface's offset in column `x` (art pixels): the wave and ripple while short, the lip's
## wobble once met (more while the burst lasts), none under reduced motion.
func _wave_at(x: int, burst_share: float, reduced: bool) -> float:
	if reduced:
		return 0.0
	if _met:
		return sin(x * 0.5 + _time * 10.0) * (MET_WOBBLE + MET_WOBBLE_BURST * burst_share)
	return _wave * sin(x * 0.45 + _time * 9.0) + RIPPLE * sin(x * 1.1 - _time * 5.0)


## The shine: a leaning stripe two art pixels wide through the gold, below its lip.
func _draw_shine(surface: float, colour: Color) -> void:
	var shine_x: float = fmod(_time * SHINE_SPEED, TANK.get_width() + 30.0) - 15.0
	var first: int = maxi(_top_row, ceili(surface) + LIP_ROWS + 1)
	for y: int in range(first, _bottom_row + 1):
		var x: int = floori(shine_x + y * SHINE_LEAN)
		for column: int in [x, x + 1]:
			if _inside(Vector2i(column, y)):
				_span(column, y, y, colour)


## The sign's opaque runs (outline and inside), offset by `offset` art pixels, in `colour`.
func _draw_solid(offset: Vector2i, colour: Color) -> void:
	for x: int in range(_solid_runs.size()):
		for run: Vector2i in _solid_runs[x]:
			_span(x + offset.x, run.x + offset.y, run.y + offset.y, colour)


## Rows `first` to `last` of column `x` (art pixels) in `colour`; nothing when empty.
func _span(x: int, first: int, last: int, colour: Color) -> void:
	if last < first:
		return
	var cell: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(x * cell, first * cell, cell, (last - first + 1) * cell), colour)


## The surface's row (fractional) for the level drawn: the inside's bottom when empty, its top
## when full.
func _surface_row() -> float:
	var full: float = level()
	return _bottom_row + 1 - (_bottom_row + 1 - _top_row) * full


## The empty inside's ramp for the status now: QuotaMeter's MET_RAMP once met, NEAR_RAMP from
## NEAR_SHARE of the quota (the reading's amount, at once), SHORT_RAMP below.
func _status_ramp() -> Array[Color]:
	if _met:
		return QuotaMeter.MET_RAMP
	if _quota > 0 and _reading >= _quota * QuotaMeter.NEAR_SHARE:
		return QuotaMeter.NEAR_RAMP
	return QuotaMeter.SHORT_RAMP


## `from` eased toward `to` by `weight`, landing on it once its channels are within SNAP of it
## in all.
static func _ease_colour(from: Color, to: Color, weight: float) -> Color:
	var eased: Color = from.lerp(to, weight)
	var gap: float = absf(eased.r - to.r) + absf(eased.g - to.g) + absf(eased.b - to.b)
	return to if gap < SNAP else eased


## A gain reaches the level: the surface sloshes and the sign kicks (without reduced motion).
func _take(amount: int) -> void:
	if amount > _amount and not _reduced():
		_wave = minf(WAVE_MAX, _wave + WAVE_KICK + (amount - _amount) / WAVE_PER_EURO)
		_kick_at(KICK_GAIN_MET if _met else KICK_GAIN)
	_amount = amount


## No gain on its way and no chip held (a new count, reduced motion, a settled end state).
func _drop_pending() -> void:
	_pending.clear()
	_held.clear()
	_holds = 0


func _kick_at(amount: float) -> void:
	_kick = amount
	_kick_age = 0.0


func _move_bubbles(delta: float) -> void:
	var surface: float = _surface_row()
	var rise: float = 2.0 if _met else 1.0
	for index: int in range(_bubbles.size()):
		var bubble: Vector3 = _bubbles[index]
		bubble.y -= bubble.z * delta * rise
		bubble.x += sin(_time * 4.0 + bubble.z) * BUBBLE_SWAY * delta
		if bubble.y < surface + LIP_ROWS:
			bubble = _new_bubble(float(_bottom_row))
		_bubbles[index] = bubble


## A bubble at row `row`, at a random column inside, rising at a random speed (z).
func _new_bubble(row: float) -> Vector3:
	return Vector3(
		_random.randf_range(0.0, TANK.get_width() - 1.0),
		row,
		_random.randf_range(BUBBLE_SPEED.x, BUBBLE_SPEED.y)
	)


func _inside(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _runs.size():
		return false
	for run: Vector2i in _runs[cell.x]:
		if cell.y >= run.x and cell.y <= run.y:
			return true
	return false


## Reads the sprite once: each column's runs of inside, lit and opaque pixels, and the rows the
## inside and the sign span.
func _read_sprite() -> void:
	var image: Image = TANK.get_image()
	if image.is_compressed():
		image.decompress()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var inside: Array[PackedByteArray] = []
	var solid: Array[PackedByteArray] = []
	for x: int in range(width):
		var column: PackedByteArray = PackedByteArray()
		var opaque: PackedByteArray = PackedByteArray()
		column.resize(height)
		opaque.resize(height)
		for y: int in range(height):
			var pixel: Color = image.get_pixel(x, y)
			opaque[y] = 1 if pixel.a > 0.5 else 0
			column[y] = 1 if pixel.a > 0.5 and pixel.is_equal_approx(INSIDE_COLOR) else 0
		inside.append(column)
		solid.append(opaque)
	_top_row = height
	_bottom_row = -1
	_solid_top = height
	for x: int in range(width):
		var lit: PackedByteArray = PackedByteArray()
		lit.resize(height)
		for y: int in range(height):
			var edge: bool = false
			for back: int in range(1, LIT_COLUMNS + 1):
				edge = edge or x - back < 0 or inside[x - back][y] == 0
			lit[y] = 1 if inside[x][y] == 1 and edge else 0
		var runs: Array[Vector2i] = _runs_of(inside[x])
		for run: Vector2i in runs:
			_top_row = mini(_top_row, run.x)
			_bottom_row = maxi(_bottom_row, run.y)
		var solid_runs: Array[Vector2i] = _runs_of(solid[x])
		for run: Vector2i in solid_runs:
			_solid_top = mini(_solid_top, run.x)
		_runs.append(runs)
		_lit_runs.append(_runs_of(lit))
		_solid_runs.append(solid_runs)


## The runs of set cells in `column` (x: first row, y: last row).
static func _runs_of(column: PackedByteArray) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var start: int = -1
	for y: int in range(column.size() + 1):
		var on: bool = y < column.size() and column[y] == 1
		if on and start < 0:
			start = y
		elif not on and start >= 0:
			runs.append(Vector2i(start, y - 1))
			start = -1
	return runs


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
