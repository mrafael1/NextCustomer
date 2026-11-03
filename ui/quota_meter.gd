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
## The liquid is coloured by status (red, orange, green: SHORT_RAMP, NEAR_RAMP, MET_RAMP), lit
## on its left columns and dark on its right ones (light from the top left), with a paper meniscus
## on its surface. The first lap is full exactly at the quota. Each gain sloshes the surface and
## sprays droplets; bubbles rise through the liquid; meeting the quota and each new lap flash it.
## The tube glows from NEAR_SHARE of the quota while short.
##
## Laps (the user's feedback of 2026-11-03, replacing the flag and the re-scaling past the
## quota): once the quota is met (the count-up's ding, or a projected total reaching it) the tube
## never re-scales. The full green tube stays as the backdrop and lap 2 refills it from the
## foot in gold, from the quota to twice the quota; lap 3 (to three times) in orange over a full
## gold tube, lap 4 in velvet, lap 5 in teal glass, then the colours cycle from gold again
## (LAP_RAMPS; lap_ramp, backdrop_ramp). So the tube's top is always the lap's target: lap N is
## full at N times the quota. From lap 2 a badge on the tube's top names the lap ("×2", in the
## number font's hard pixels on the lap's colour, popping as a lap starts), inside the column's
## margin and clear of the receipt (badge_rect). While counting, reaching twice the quota and
## each later multiple emits lap_reached (the quota crossing stamps it). Reduced motion
## (`reduced_motion`) keeps the levels, the colours, the badge and the glow (steady) and drops the
## slosh, the spray, the bubbles and the badge's pop.
##
## While an item is dragged over a landing slot (#71, decision 4A) it previews the stretch that
## drop would give (paler for a gain, a dark stretch for a loss; show_hypothetical) until the drag
## ends; the monitor prints the would-be total. A Double checkout's rows (#122) show as RowPips
## under the tube (RegisterTower places them). Display only: the amounts are the screen's preview
## and the LED's.

## The count's amount reached `multiple` times the quota (2 or more): lap `multiple` + 1 starts.
signal lap_reached(multiple: int)

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
## The flash at the quota and at each new lap fades over FLASH_SECONDS, at most FLASH_ALPHA.
const FLASH_SECONDS := 0.5
const FLASH_ALPHA := 0.8
const RANDOM_SEED := 73
## The well, and the first lap's columns (lit, mid, dark) by status, the user's idea from their
## play test of 2026-10-19: red (tomato) while short, orange from NEAR_SHARE of the quota, money
## green once it is met. The colour eases to a new status over about 1 / STATUS_EASE_RATE seconds
## (at once under reduced motion). The receipt's foot says the same, so the status never shows by
## colour alone.
const WELL_COLOR := Palette.CHARCOAL
const SHORT_RAMP: Array[Color] = [Palette.TOMATO_LIGHT, Palette.TOMATO, Palette.TOMATO_DARK]
const NEAR_RAMP: Array[Color] = [Palette.MUSTARD, Palette.BRASS, Palette.BRASS_DARK]
const MET_RAMP: Array[Color] = [Palette.GREEN_LIGHT, Palette.GOOD, Palette.GREEN_DARK]
const STATUS_EASE_RATE := 6.0
## The laps past the quota (lap 2 on), cycling: gold, orange (the palette's coral and caramel; it
## has no pure orange), velvet (its magenta) and teal glass (its violet stand-in: it has none).
const LAP_RAMPS: Array[Array] = [
	[Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD],
	[Palette.TOMATO_PALE, Palette.TOMATO_LIGHT, Palette.WOOD_LIGHT],
	[Palette.VELVET_SHEEN, Palette.VELVET, Palette.VELVET_DARK],
	[Palette.GLASS, Palette.TEAL_BRIGHT, Palette.TEAL_SHADE],
]
## The first lap past the quota.
const FIRST_LAP := 2
## The lap's badge on the tube's top: "×N" in the hard pixel number font on the lap's colour, an
## ink edge round it, BADGE_PAD art px round the text; a new lap pops it BADGE_POP art px larger,
## settling over BADGE_POP_SECONDS.
const BADGE_TEXT := "×%d"
const BADGE_PAD := 2
## At most this wide (art px, ink edge included; a wider text loses its pad, so "×12" still fits):
## centred on the tube (stage x 8 to 32), it stays between the stage's left edge and the
## receipt's (ShiftStage.RECEIPT_X, 42).
const BADGE_MAX_WIDTH := 20
const BADGE_POP := 2
const BADGE_POP_SECONDS := 0.35
## The surface's meniscus, the bubbles and the target line on the tube's top.
const MENISCUS_COLOR := Palette.PAPER
const BUBBLE_COLOR := Palette.PAPER
const TARGET_COLOR := Palette.TOMATO
## A drag's preview: the stretch a drop would add (the lit colour, see-through) and the one it
## would lose (the dark one).
const GAIN_PREVIEW_ALPHA := 0.55
const LOSS_PREVIEW_ALPHA := 0.8

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _amount: int = 0
var _quota: int = 0
## A drag's would-be total, -1 when no drag shows.
var _hypothetical: int = -1
var _blank: bool = true
## The quota is met: the count-up's ding while counting, the projected total reaching it in
## planning.
var _met: bool = false
## The amount's lap (1 while short, 0 blank); the lap drawn follows the eased level (_drawn_lap).
var _lap: int = 0
var _led: LedDisplay
## The amount drawn, eased (EASE_RATE).
var _shown: float = 0.0
var _slosh: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
## The badge's pop, from 1 at a new lap down to 0.
var _pop: float = 0.0
var _badge_lap: int = 0
var _bubbles: Array[Vector3] = []
var _drops: Array[Dictionary] = []
## The first lap's columns as drawn: eased to the status's ramp (_status_ramp).
var _ramp: Array[Color] = SHORT_RAMP.duplicate()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "QuotaMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_random.seed = RANDOM_SEED
	for _index: int in range(BUBBLES):
		_bubbles.append(Vector3(_random.randf(), _random.randf(), _random.randf_range(5.0, 12.0)))


## Mirrors `led`: its readings and its blank mode.
func follow(led: LedDisplay) -> void:
	_led = led
	led.reading_changed.connect(_on_reading)
	led.mode_changed.connect(_on_mode)


## Planning: the preview's projected `amount_shown` against `quota`; met once it reaches it.
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


## The first lap's fill for `amount_shown` against `quota`, from 0 to 1 (full for a quota of 0):
## full at the quota and past it (the conveyor's quota light, QuotaLight, fills the same way).
## Display arithmetic only.
static func fill_fraction(amount_shown: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf(float(maxi(amount_shown, 0)) / quota, 0.0, 1.0)


## The lap `amount_shown` is in against `quota`: 1 while short or not `met`, else the whole
## multiples made plus one (lap 2 from the quota, lap 3 from twice it). Display arithmetic only.
static func lap_for(amount_shown: int, quota: int, met: bool) -> int:
	if not met or quota <= 0:
		return 1
	return maxi(FIRST_LAP, lap_of(amount_shown, quota) + 1)


## Lap `lap`'s fill for `amount_shown` against `quota` (0 to 1): the first lap's is fill_fraction,
## lap N's runs from (N - 1) to N times the quota. Display arithmetic only.
static func lap_fill(amount_shown: float, quota: int, lap: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf((amount_shown - (maxi(lap, 1) - 1) * quota) / quota, 0.0, 1.0)


## The columns (lit, mid, dark) of lap `lap` (FIRST_LAP or more): LAP_RAMPS, cycling.
static func lap_ramp(lap: int) -> Array[Color]:
	var colours: Array[Color] = []
	colours.assign(LAP_RAMPS[posmod(lap - FIRST_LAP, LAP_RAMPS.size())])
	return colours


## The full tube behind lap `lap` (FIRST_LAP or more): the met first lap's green behind lap 2,
## the lap before's colour behind the others.
static func backdrop_ramp(lap: int) -> Array[Color]:
	return MET_RAMP if lap <= FIRST_LAP else lap_ramp(lap - 1)


## The gauge's fill in its lap now, as a fraction of its inside (for tests).
func fill() -> float:
	return 0.0 if _blank else lap_fill(float(_amount), _quota, _lap)


## The amount's lap: 1 while short (or before the ding), FIRST_LAP from the quota on, 0 blank.
func shown_lap() -> int:
	return 0 if _blank else _lap


## The laps `amount_shown` has made of `quota` (whole multiples), 0 for a quota of 0. Display
## arithmetic only.
static func lap_of(amount_shown: int, quota: int) -> int:
	if quota <= 0:
		return 0
	return floori(float(maxi(amount_shown, 0)) / quota)


## The tube glows (short of the quota, from NEAR_SHARE of it).
func is_near() -> bool:
	return not _blank and not _met and _quota > 0 and _amount >= _quota * NEAR_SHARE


## The tube itself (the gauge's rect: the quota crossing's and the premium announce's anchor).
func bar() -> Control:
	return self


## Where the quota stands on the tube, in global coordinates: the middle of the target line on
## the tube's top (every lap is full at its target).
func quota_mark() -> Vector2:
	var cell: float = ArtStyle.ART_SCALE
	return get_global_transform() * Vector2(size.x / 2.0, -cell / 2.0)


## The badge's text ("×2"), empty while it is hidden (blank or in the first lap).
func badge_text() -> String:
	var lap: int = _drawn_lap()
	return BADGE_TEXT % lap if lap >= FIRST_LAP else ""


## The badge's rect at rest (local px), for the badge's text `text`: centred over the tube, its
## ink edge's foot on the target line's top.
func badge_rect(text: String = "") -> Rect2:
	if text.is_empty():
		text = BADGE_TEXT % maxi(_drawn_lap(), FIRST_LAP)
	var font: Font = ArtStyle.pixel_number_font()
	var size_px: int = ArtStyle.PIXEL_NUMBER_SIZE
	var text_width: int = ceili(
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	)
	var text_height: int = ceili(font.get_ascent(size_px) - font.get_descent(size_px))
	var pad: int = clampi(floori((BADGE_MAX_WIDTH - 2 - text_width) / 2.0), 0, BADGE_PAD)
	var box: Vector2i = Vector2i(text_width + (pad + 1) * 2, text_height + (BADGE_PAD + 1) * 2)
	var art_left: int = floori((_art_size().x - box.x) / 2.0)
	var art_top: int = -1 - box.y
	var cell: float = ArtStyle.ART_SCALE
	return Rect2(Vector2(art_left, art_top) * cell, Vector2(box) * cell)


## The first lap's ramp as drawn now (for tests).
func ramp() -> Array[Color]:
	return _ramp


## The ramp of the liquid drawn now (the first lap's eased one, or the lap's), for tests.
func liquid_ramp() -> Array[Color]:
	var lap: int = _drawn_lap()
	return lap_ramp(lap) if lap >= FIRST_LAP else _ramp


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SECONDS)
	_pop = maxf(0.0, _pop - delta / BADGE_POP_SECONDS)
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
	_follow_badge()
	queue_redraw()


## Shows `amount_shown` against `quota`, `met` or not: a gain sloshes and sprays, meeting the
## quota flashes, a lower amount (a new count) empties the gauge at once. While `counting`, twice
## the quota and each multiple past it emit lap_reached.
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
	_met = met
	var lap: int = lap_for(amount_shown, quota, met)
	if lap > _lap and lap > FIRST_LAP and counting:
		lap_reached.emit(lap - 1)
	_lap = lap
	if _reduced():
		_shown = float(amount_shown)
	_follow_badge()
	queue_redraw()


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
		_badge_lap = 0
		_drops.clear()
	queue_redraw()


## The first lap's ramp for the status now: SHORT_RAMP, NEAR_RAMP from NEAR_SHARE of the quota
## (and past it before the ding), MET_RAMP once met.
func _status_ramp() -> Array[Color]:
	if _met:
		return MET_RAMP
	if is_near() or (_quota > 0 and _amount >= _quota):
		return NEAR_RAMP
	return SHORT_RAMP


## The lap drawn: the eased level's (so the liquid fills its lap to the top before the next one
## pours), never past the amount's; 0 blank.
func _drawn_lap() -> int:
	if _blank:
		return 0
	return mini(_lap, lap_for(floori(_shown), _quota, _met))


## A new lap drawn flashes the tube and pops the badge.
func _follow_badge() -> void:
	var lap: int = _drawn_lap()
	if lap > _badge_lap and lap >= FIRST_LAP:
		_flash = 1.0
		_pop = 0.0 if _reduced() else 1.0
	_badge_lap = lap


## The tube's size in art pixels.
func _art_size() -> Vector2i:
	return Vector2i((size / ArtStyle.ART_SCALE).floor())


## The inside's height in art pixels (inside the 1 art px ink border).
func _inner() -> float:
	return maxf(0.0, _art_size().y - 2.0)


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


## The liquid's height in its lap, in art pixels over the inside's foot.
func _front() -> float:
	return _inner() * lap_fill(_shown, _quota, _drawn_lap())


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
	if not badge_text().is_empty():
		_draw_badge()


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
	var lap: int = _drawn_lap()
	var front: float = _front()
	var liquid: Array[Color] = liquid_ramp()
	var backdrop: Array[Color] = []
	if lap >= FIRST_LAP:
		backdrop = backdrop_ramp(lap)
	var preview: float = -1.0
	if _hypothetical >= 0:
		preview = _inner() * lap_fill(float(_hypothetical), _quota, lap)
	for x: int in range(1, art.x - 1):
		var wobble: float = 0.0
		if not reduced:
			wobble = _slosh * sin(x * 0.9 + _time * 14.0) + RIPPLE * sin(x * 0.5 - _time * 6.0)
		var height: int = roundi(clampf(front + wobble, 0.0, _inner()))
		var column: int = 0 if x <= LIT_COLUMNS else (2 if x >= art.x - 1 - DARK_COLUMNS else 1)
		var top: int = foot - height
		if not backdrop.is_empty():
			_cell(x, 1, 1, art.y - 2, backdrop[column])
		_cell(x, top, 1, height, liquid[column])
		if height > 0 and height < _inner():
			_cell(x, top, 1, 1, MENISCUS_COLOR)
		if preview > front:
			var gain_top: int = foot - roundi(preview)
			_cell(x, gain_top, 1, top - gain_top, Color(liquid[0], GAIN_PREVIEW_ALPHA))
		elif preview >= 0.0 and preview < front:
			var loss_top: int = foot - roundi(preview)
			_cell(x, top, 1, loss_top - top, Color(liquid[2], LOSS_PREVIEW_ALPHA))
	if not reduced:
		_draw_motion(art, front, liquid)
	if _flash > 0.0:
		_cell(1, 1, art.x - 2, art.y - 2, Color(Palette.PAPER, _flash * FLASH_ALPHA))


## The bubbles rising in the liquid and the spray flying up off its surface.
func _draw_motion(art: Vector2i, front: float, liquid: Array[Color]) -> void:
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
		_cell(floori(at.x), floori(y), 1, 1, liquid[0] if life > SPRAY_LIFE / 2.0 else liquid[1])


## The lap's badge: an ink edge, the lap's colour with its lit band on top, "×N" in paper with an
## ink outline; popped larger as a lap starts.
func _draw_badge() -> void:
	var text: String = badge_text()
	var cell: float = ArtStyle.ART_SCALE
	var rect: Rect2 = badge_rect(text)
	var grow: int = ceili(_pop * BADGE_POP)
	if grow > 0:
		rect = rect.grow_individual(grow * cell, grow * 2.0 * cell, grow * cell, 0.0)
	var colours: Array[Color] = lap_ramp(_drawn_lap())
	draw_rect(rect, Palette.INK)
	var face: Rect2 = rect.grow(-cell)
	draw_rect(face, colours[1])
	draw_rect(Rect2(face.position, Vector2(face.size.x, cell)), colours[0])
	draw_rect(Rect2(face.position.x, face.end.y - cell, face.size.x, cell), colours[2])
	var font: Font = ArtStyle.pixel_number_font()
	var size_px: int = ArtStyle.PIXEL_NUMBER_SIZE
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var ascent: float = font.get_ascent(size_px)
	var descent: float = font.get_descent(size_px)
	var art_origin: Vector2 = (
		(rect.get_center() / cell - Vector2(text_width, ascent - descent) / 2.0).round()
	)
	draw_set_transform(art_origin * cell, 0.0, Vector2.ONE * cell)
	var baseline: Vector2 = Vector2(0.0, ascent)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_string(
			font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Palette.INK
		)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Palette.PAPER)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
