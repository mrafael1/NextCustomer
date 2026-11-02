class_name QuotaMeter
extends Control
## The quota gauge (#86 gauge TA of mock-up count_up_86_v4_live.html; a tube since the shift scene
## polish, mock-up docs/art/mockups/shift_scene_polish_v2.html section 2, variant A2): a vertical
## liquid tube in the register's column, beside the receipt, that fills up toward the shift's
## quota. Its top is the target: a tomato line across it, red like the receipt's big TODAY'S
## TARGET number (ReceiptTarget). It prints no number: the receipt says the target, the projected
## total and how far it is (its foot), and the monitor the count. In planning the level is the
## projected total, which the shift screen hands it from its preview (show_projected), as the
## monitor's checkout column shows it (#105 piece 2). During the count it mirrors the register's
## reading (LedDisplay, follow), as the monitor's number does: the running total, so the gauge
## never shows the final total early. Blank alone: an empty tube.
##
## The liquid is coloured by status (red, orange, green, gold: SHORT_RAMP), lit on its left
## columns and dark on its right ones (light from the top left), with a paper meniscus on its
## surface. While short of the quota it is full exactly at the quota. Once the amount meets it (the
## count-up's ding, or a projected total reaching it) a flag (QuotaFlag, with a drawn ✓) is planted
## on the tube's top, the tube re-scales to the amount, and a paper line marks the quota: it sinks
## as the gold overflows above it. Each gain sloshes the surface and sprays droplets; bubbles rise
## through the liquid; meeting the quota flashes it.
##
## Laps (the quota crossing's E, docs/art/mockups/quota_crossing.html, approved by the user on
## 2026-10-31): only while counting, once the amount reaches twice the quota the tube stops
## re-scaling. It flashes, banks in gold (BANKED_RAMP) and a new lap pours in over it toward the
## next multiple (LAP_RAMP), and the flag names it ("×3"); each later multiple laps the same way.
## Every new lap emits lap_reached (the quota crossing stamps it). The tube glows from NEAR_SHARE
## of the quota while short. Reduced motion (`reduced_motion`) keeps the level, the flag and the
## glow (steady) and drops the slosh, the spray, the bubbles and the flag's planting and flapping.
##
## While an item is dragged over a landing slot (#71, decision 4A) it previews the stretch that
## drop would give (paler for a gain, a dark stretch for a loss; show_hypothetical) until the drag
## ends; the monitor prints the would-be total. A Double checkout's rows (#122) show as RowPips
## under the tube (RegisterTower places them). Display only: the amounts are the screen's preview
## and the LED's.

## The count's amount reached `lap` times the quota (2 or more): the gauge laps.
signal lap_reached(lap: int)

## The glow: a mustard-light ring GLOW_WIDTH px round the tube, pulsing every GLOW_SECONDS, from
## this share of the quota while short.
const NEAR_SHARE := 0.8
const GLOW_WIDTH := 3.0
const GLOW_SECONDS := 0.7
## The liquid's lit and dark columns (art px) at its left and right edges.
const LIT_COLUMNS := 2
const DARK_COLUMNS := 2
## The shown level eases to the amount at this rate (per second).
const EASE_RATE := 7.0
## The surface's slosh: a gain of N adds SLOSH_KICK + N / SLOSH_PER_EURO art pixels, up to
## SLOSH_MAX, settling at SLOSH_DECAY per second; a small ripple always runs (RIPPLE).
const SLOSH_KICK := 1.5
const SLOSH_PER_EURO := 10.0
const SLOSH_MAX := 4.0
const SLOSH_DECAY := 3.5
const RIPPLE := 0.6
## The spray: SPRAY_DROPS + N / SPRAY_PER_EURO droplets (up to SPRAY_MAX) up off the surface for a
## gain of N, each for SPRAY_LIFE seconds, falling at SPRAY_GRAVITY art pixels per second squared,
## drawn inside the tube.
const SPRAY_DROPS := 6
const SPRAY_PER_EURO := 4.0
const SPRAY_MAX := 24
const SPRAY_LIFE := 0.8
const SPRAY_GRAVITY := 90.0
const BUBBLES := 7
## The flash at the quota fades over FLASH_SECONDS, at most FLASH_ALPHA.
const FLASH_SECONDS := 0.5
const FLASH_ALPHA := 0.8
const RANDOM_SEED := 73
## The well, and the liquid's columns (lit, mid, dark) by status, the user's idea from their play
## test of 2026-10-19: red (tomato) while short, orange from NEAR_SHARE of the quota, money green
## once it is met, and gold past the quota line. The colour eases to a new status over about
## 1 / STATUS_EASE_RATE seconds (at once under reduced motion). The receipt's foot and the flag say
## the same, so the status never shows by colour alone.
const WELL_COLOR := Palette.CHARCOAL
const SHORT_RAMP: Array[Color] = [Palette.TOMATO_LIGHT, Palette.TOMATO, Palette.TOMATO_DARK]
const NEAR_RAMP: Array[Color] = [Palette.MUSTARD, Palette.BRASS, Palette.BRASS_DARK]
const MET_RAMP: Array[Color] = [Palette.GREEN_LIGHT, Palette.GOOD, Palette.GREEN_DARK]
const PAST_RAMP: Array[Color] = [Palette.MUSTARD_PALE, Palette.MUSTARD_LIGHT, Palette.MUSTARD]
const STATUS_EASE_RATE := 6.0
## Laps: the banked laps under the new one, and the new lap's liquid.
const BANKED_RAMP: Array[Color] = [Palette.MUSTARD, Palette.MUSTARD_DARK, Palette.MUSTARD_DARKEST]
const LAP_RAMP: Array[Color] = [Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD_LIGHT]
## The first lap: the amount at twice the quota.
const FIRST_LAP := 2
## The flag's cloth names the next multiple in laps ("×3").
const LAP_FLAG_TEXT := "×%d"
## The surface's meniscus, the bubbles, the quota line and the target line on the tube's top.
const MENISCUS_COLOR := Palette.PAPER
const BUBBLE_COLOR := Palette.PAPER
const QUOTA_LINE_COLOR := Palette.PAPER
const TARGET_COLOR := Palette.TOMATO
## A drag's preview: the stretch a drop would add (the lit colour, see-through) and the one it
## would lose (the dark one).
const GAIN_PREVIEW_ALPHA := 0.55
const LOSS_PREVIEW_ALPHA := 0.8
## The flag on the tube's top: its pole reaches FLAG_POLE_ABOVE px above it and FLAG_POLE_INTO px
## into the tube's cap.
const FLAG_POLE_ABOVE := 26.0
const FLAG_POLE_INTO := 2.0

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _flag: QuotaFlag
var _amount: int = 0
var _quota: int = 0
## A drag's would-be total, -1 when no drag shows.
var _hypothetical: int = -1
var _blank: bool = true
## The quota is met: the count-up's ding while counting, the projected total reaching it in
## planning.
var _met: bool = false
## The lap shown (FIRST_LAP or more), 0 outside laps.
var _lap: int = 0
var _led: LedDisplay
## The amount drawn, eased (EASE_RATE).
var _shown: float = 0.0
var _slosh: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _bubbles: Array[Vector3] = []
var _drops: Array[Dictionary] = []
## The liquid's columns as drawn: eased to the status's ramp (_status_ramp).
var _ramp: Array[Color] = SHORT_RAMP.duplicate()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "QuotaMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_flag = QuotaFlag.new()
	_flag.reduced_motion = _reduced
	_flag.pole_above = FLAG_POLE_ABOVE
	_flag.lap_cloth_left = false
	add_child(_flag)
	resized.connect(_place_flag)
	_random.seed = RANDOM_SEED
	for _index: int in range(BUBBLES):
		_bubbles.append(Vector3(_random.randf(), _random.randf(), _random.randf_range(5.0, 12.0)))


## Mirrors `led`: its readings and its blank mode.
func follow(led: LedDisplay) -> void:
	_led = led
	led.reading_changed.connect(_on_reading)
	led.mode_changed.connect(_on_mode)


## Planning: the preview's projected `amount_shown` against `quota`; the flag is planted once it
## reaches the quota.
func show_projected(amount_shown: int, quota: int) -> void:
	_hypothetical = -1
	_show(amount_shown, quota, quota > 0 and amount_shown >= quota)


## A drag's landing (#71): the total `total` the drop would give, `delta` more (or less) than the
## projected one, against `quota`; the tube previews the stretch. show_projected puts the
## projection back.
func show_hypothetical(total: int, delta: int, quota: int) -> void:
	_show(total - delta, quota, quota > 0 and total - delta >= quota)
	_hypothetical = total
	queue_redraw()


## The amount the tube shows (the projected total or the count's reading), -1 when blank.
func amount() -> int:
	return -1 if _blank else _amount


## A drag's would-be total the tube previews, -1 when none.
func hypothetical() -> int:
	return _hypothetical


## The gauge's fill for `amount_shown` against `quota`, from 0 to 1 (full for a quota of 0): full
## at the quota and past it, since past it the gauge re-scales to the amount. Display arithmetic
## only.
static func fill_fraction(amount_shown: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf(float(maxi(amount_shown, 0)) / quota, 0.0, 1.0)


## Where the quota line stands for `amount_shown` against `quota`, as a fraction of the tube's
## inside from its foot: at the top until the amount passes the quota, then at quota / amount.
## Display arithmetic only.
static func flag_fraction(amount_shown: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return float(quota) / maxi(quota, amount_shown)


## The gauge's fill, as a fraction of its inside (for tests).
func fill() -> float:
	return 0.0 if _blank else fill_fraction(_amount, _quota)


## The lap shown (FIRST_LAP or more while counting at twice the quota or past it), else 0.
func shown_lap() -> int:
	return _lap


## The laps `amount_shown` has made of `quota` (whole multiples), 0 for a quota of 0. Display
## arithmetic only.
static func lap_of(amount_shown: int, quota: int) -> int:
	if quota <= 0:
		return 0
	return floori(float(maxi(amount_shown, 0)) / quota)


## Whether the flag stands on the tube (the quota met).
func flag_shown() -> bool:
	return _flag.visible


## The tube glows (short of the quota, from NEAR_SHARE of it).
func is_near() -> bool:
	return not _blank and not _met and _quota > 0 and _amount >= _quota * NEAR_SHARE


## The tube itself (the gauge's rect: the quota crossing's and the premium announce's anchor).
func bar() -> Control:
	return self


func flag() -> QuotaFlag:
	return _flag


## Where the quota stands on the tube, in global coordinates: the middle of the quota line once
## the quota is met (it sinks as the tube re-scales), else of the target line on the tube's top.
func quota_mark() -> Vector2:
	var cell: float = ArtStyle.ART_SCALE
	var y: float = -cell
	if _met and _lap == 0:
		y = _quota_row() * cell
	return get_global_transform() * Vector2(size.x / 2.0, y + cell / 2.0)


## The liquid's ramp as drawn now (for tests).
func ramp() -> Array[Color]:
	return _ramp


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SECONDS)
	var target: Array[Color] = _status_ramp()
	for index: int in range(_ramp.size()):
		var weight: float = 1.0 if _reduced() else minf(1.0, delta * STATUS_EASE_RATE)
		_ramp[index] = _ramp[index].lerp(target[index], weight)
	if _reduced():
		_shown = float(_amount)
		_slosh = 0.0
		_drops.clear()
	else:
		_shown += (_amount - _shown) * minf(1.0, delta * EASE_RATE)
		if absf(_amount - _shown) < 0.3:
			_shown = float(_amount)
		_slosh *= exp(-delta * SLOSH_DECAY)
		_move_drops(delta)
	queue_redraw()


## Shows `amount_shown` against `quota`, `met` or not: a gain sloshes and sprays, meeting the
## quota plants the flag and flashes, a lower amount (a new count) empties the gauge at once.
## While `counting`, twice the quota and each multiple past it lap the gauge.
func _show(amount_shown: int, quota: int, met: bool, counting: bool = false) -> void:
	var gain: int = amount_shown - _amount
	if _blank or gain < 0:
		_shown = float(amount_shown)
		_drops.clear()
	elif gain > 0 and not _reduced():
		_slosh = minf(SLOSH_MAX, _slosh + SLOSH_KICK + gain / SLOSH_PER_EURO)
		_spray(mini(SPRAY_MAX, SPRAY_DROPS + roundi(gain / SPRAY_PER_EURO)))
	_blank = false
	_amount = amount_shown
	_quota = quota
	if met and not _met:
		_flash = 1.0
		_flag.plant()
	elif not met:
		_flag.visible = false
	_met = met
	_set_lap(lap_of(amount_shown, quota) if met and counting else 0)
	if _reduced():
		_shown = float(amount_shown)
	_place_flag()
	queue_redraw()


## Laps from `lap` (under FIRST_LAP: none): a new lap flashes, has the flag name the next multiple
## and emits lap_reached.
func _set_lap(lap: int) -> void:
	if lap < FIRST_LAP:
		lap = 0
	if lap > _lap:
		_flash = 1.0
		_flag.lap_text = LAP_FLAG_TEXT % (lap + 1)
		_flag.plant()
		_lap = lap
		lap_reached.emit(lap)
	elif lap == 0:
		_flag.lap_text = ""
	_lap = lap


func _on_reading(amount_shown: int, quota: int, met: bool) -> void:
	_hypothetical = -1
	var counting: bool = _led != null and _counting(_led.mode())
	_show(amount_shown, quota, met and counting, counting)


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK:
		_blank = true
		_hypothetical = -1
		_met = false
		_lap = 0
		_flag.lap_text = ""
		_flag.visible = false
		_drops.clear()
	queue_redraw()


## The liquid's ramp for the status now (up to the quota line): SHORT_RAMP, NEAR_RAMP from
## NEAR_SHARE of the quota, MET_RAMP once met (PAST_RAMP over the line is drawn apart).
func _status_ramp() -> Array[Color]:
	if _met:
		return MET_RAMP
	if is_near() or (_quota > 0 and _amount >= _quota):
		return NEAR_RAMP
	return SHORT_RAMP


## The gauge's scale now: the quota while short, the larger of it and what shows once met.
func _scale() -> float:
	var top: float = float(_quota)
	if _lap > 0:
		return maxf(top, 1.0)
	if _met:
		top = maxf(top, _shown)
		if _hypothetical >= 0:
			top = maxf(top, float(_hypothetical))
	return maxf(top, 1.0)


## The tube's size in art pixels.
func _art_size() -> Vector2i:
	return Vector2i((size / ArtStyle.ART_SCALE).floor())


## The inside's height in art pixels (inside the 1 art px ink border).
func _inner() -> float:
	return maxf(0.0, _art_size().y - 2.0)


## The flag stands on the tube's top, at its middle.
func _place_flag() -> void:
	_flag.position = Vector2(roundf(size.x / 2.0 / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE, 0.0)
	_flag.set_pole(FLAG_POLE_INTO)


## The art row the quota line is drawn on (met, outside laps).
func _quota_row() -> int:
	var foot: float = _art_size().y - 1.0
	return roundi(foot - _inner() * minf(1.0, _quota / _scale()))


func _spray(count: int) -> void:
	var width: float = _art_size().x
	for _index: int in range(count):
		(
			_drops
			. append(
				{
					"at": Vector2(_random.randf_range(1.5, width - 2.5), -1.0),
					"velocity":
					Vector2(_random.randf_range(-12.0, 12.0), _random.randf_range(-50.0, -20.0)),
					"life": SPRAY_LIFE,
				}
			)
		)


func _move_drops(delta: float) -> void:
	var kept: Array[Dictionary] = []
	var surface: float = _art_size().y - 1.0 - _front()
	for drop: Dictionary in _drops:
		var life: float = drop["life"]
		life -= delta
		if life <= 0.0:
			continue
		var at: Vector2 = drop["at"]
		if at.y < 0.0:
			at.y = surface
		var velocity: Vector2 = drop["velocity"]
		drop["at"] = at + velocity * delta
		drop["velocity"] = velocity + Vector2(0.0, SPRAY_GRAVITY * delta)
		drop["life"] = life
		kept.append(drop)
	_drops = kept


## The liquid's height, in art pixels over the inside's foot.
func _front() -> float:
	if _lap > 0:
		return _inner() * clampf((_shown - _lap * _quota) / _scale(), 0.0, 1.0)
	return _inner() * minf(_shown, _scale()) / _scale()


func _draw() -> void:
	var art: Vector2i = _art_size()
	if art.x < 3 or art.y < 3:
		return
	if is_near():
		_draw_glow()
	_cell(0, 0, art.x, art.y, Palette.INK)
	_cell(1, 1, art.x - 2, art.y - 2, WELL_COLOR)
	if not _blank:
		_draw_liquid(art)
	# The target on the tube's top: an ink cap with a tomato line, a pixel wider each side.
	_cell(-1, -1, art.x + 2, 2, Palette.INK)
	_cell(0, -1, art.x, 1, TARGET_COLOR)


func _draw_glow() -> void:
	var alpha: float = 1.0
	if not _reduced():
		alpha = 0.5 - 0.5 * cos(TAU * fmod(_time, GLOW_SECONDS) / GLOW_SECONDS)
	var cell: float = ArtStyle.ART_SCALE
	var rect: Rect2 = Rect2(Vector2(-cell, -cell), size + Vector2(cell, cell) * 2.0)
	var ring: Rect2 = rect.grow(GLOW_WIDTH / 2.0 + 1.0)
	draw_rect(ring, Color(Palette.MUSTARD_LIGHT, alpha), false, GLOW_WIDTH)


func _draw_liquid(art: Vector2i) -> void:
	var reduced: bool = _reduced()
	var foot: int = art.y - 1
	var front: float = _front()
	var quota_row: int = _quota_row() if _met and _lap == 0 else -1
	var preview: float = -1.0
	if _hypothetical >= 0:
		preview = _inner() * minf(float(_hypothetical), _scale()) / _scale()
	for x: int in range(1, art.x - 1):
		var wobble: float = 0.0
		if not reduced:
			wobble = _slosh * sin(x * 0.9 + _time * 14.0) + RIPPLE * sin(x * 0.5 - _time * 6.0)
		var height: int = roundi(clampf(front + wobble, 0.0, _inner()))
		var column: int = 0 if x <= LIT_COLUMNS else (2 if x >= art.x - 1 - DARK_COLUMNS else 1)
		var top: int = foot - height
		if _lap > 0:
			_cell(x, 1, 1, art.y - 2, BANKED_RAMP[column])
			_cell(x, top, 1, height, LAP_RAMP[column])
		elif quota_row >= 0 and top < quota_row:
			_cell(x, quota_row, 1, foot - quota_row, _ramp[column])
			_cell(x, top, 1, quota_row - top, PAST_RAMP[column])
		else:
			_cell(x, top, 1, height, _ramp[column])
		if height > 0 and height < _inner() and quota_row < 0:
			_cell(x, top, 1, 1, MENISCUS_COLOR)
		if preview > front:
			var gain_top: int = foot - roundi(preview)
			_cell(x, gain_top, 1, top - gain_top, Color(_ramp[0], GAIN_PREVIEW_ALPHA))
		elif preview >= 0.0 and preview < front:
			var loss_top: int = foot - roundi(preview)
			_cell(x, top, 1, loss_top - top, Color(_ramp[2], LOSS_PREVIEW_ALPHA))
	if quota_row >= 0:
		_cell(-1, quota_row, art.x + 2, 1, Palette.INK)
		_cell(0, quota_row, art.x, 1, QUOTA_LINE_COLOR)
	if not reduced:
		_draw_motion(art, front)
	if _flash > 0.0:
		_cell(1, 1, art.x - 2, art.y - 2, Color(Palette.PAPER, _flash * FLASH_ALPHA))


## The bubbles rising in the liquid and the spray flying up off its surface.
func _draw_motion(art: Vector2i, front: float) -> void:
	var foot: float = art.y - 1.0
	var room: float = maxf(1.0, front - 3.0)
	for bubble: Vector3 in _bubbles:
		var x: float = 2.0 + bubble.x * (art.x - 5.0)
		var rise: float = fmod(bubble.y * _inner() + _time * bubble.z, room)
		if rise < front - 3.0:
			_cell(floori(x), floori(foot - 1.0 - rise), 1, 1, BUBBLE_COLOR)
	for drop: Dictionary in _drops:
		var at: Vector2 = drop["at"]
		var life: float = drop["life"]
		if at.y < 0.0 or at.x < 1.0 or at.x >= art.x - 1 or at.y >= foot:
			continue
		var y: float = maxf(at.y, 1.0)
		_cell(floori(at.x), floori(y), 1, 1, _ramp[0] if life > SPRAY_LIFE / 2.0 else _ramp[1])


func _cell(x: int, y: int, width: int, height: int, colour: Color) -> void:
	if width <= 0 or height <= 0:
		return
	var cell: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(x * cell, y * cell, width * cell, height * cell), colour)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


## The LED shows the count-up's SUBTOTAL or TOTAL.
static func _counting(mode: LedDisplay.Mode) -> bool:
	return mode == LedDisplay.Mode.SUBTOTAL or mode == LedDisplay.Mode.TOTAL
