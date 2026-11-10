class_name QuotaMeter
extends Control
## The quota gauge (#86 gauge TA of mock-up count_up_86_v4_live.html; a tube since the shift scene
## polish, mock-up docs/art/mockups/shift_scene_polish_v2.html section 2, variant A2; the glass of
## a steel housing since v4's A1; laid `horizontal` in the top bar's GaugePanel since left column
## v2, mock-up docs/art/mockups/left_column_v2.html: its art turned a quarter, filling from the
## left toward the target line on the right): a liquid tube that fills up toward the shift's
## quota. Its top is the target: a tomato
## line across the glass's top row, red like the receipt's big TODAY'S TARGET number
## (ReceiptTarget). Tick marks at a quarter, half and three quarters of a lap and a highlight down
## the glass's left side sit over the liquid. It prints no number: the receipt says the target,
## the projected total and how far it is (its foot), and the monitor the count. In planning the
## level is the projected total, which the shift screen hands it from its preview
## (show_projected), as the monitor's checkout column shows it (#105 piece 2). During the count it
## mirrors the register's reading (LedDisplay, follow), as the monitor's number does: the running
## total, so the gauge never shows the final total early. Blank alone: an empty tube.
##
## The liquid is coloured by status (teal, orange, green: SHORT_RAMP, NEAR_RAMP, MET_RAMP), lit
## on its left columns and dark on its right ones (light from the top left), with a paper meniscus
## on its surface. The first lap is full exactly at the quota. Each gain sloshes the surface and
## sprays droplets; bubbles rise through the liquid; meeting the quota and each new lap flash it.
## The glass's rim glows from NEAR_SHARE of the quota while short.
##
## Laps (the user's feedback of 2026-11-03, replacing the flag and the re-scaling past the
## quota): once the quota is met (the count-up's ding, or a projected total reaching it) the tube
## never re-scales. The full green tube stays as the backdrop and lap 2 refills it from the
## foot in silver, from the quota to twice the quota; lap 3 (to three times) in gold over a full
## silver tube, and from lap 4 on a brighter gold over the gold, with twinkles (the week medals'
## metals, 2026-11-06; QuotaLaps). So the tube's top is always the lap's target: lap N is full at
## N times the quota, and a lap fills to the top before the next one pours (the eased level's
## lap is drawn). The lap badge is a round lamp over the housing (LapLamp, badge_rect): dark
## until the liquid reaches the quota, then lit in the newest full lap's colour, green with a
## check for the first, "×N" once N laps are made (the check alone without `names_laps`), glowing,
## and popping as a lap is made while counting or by a planning gain (and as it sends its token to
## a week medal, pop_lamp); inside the column's margin, clear of the
## receipt's well. While counting, reaching twice the quota and each later
## multiple emits lap_reached (the quota crossing rings it). Reduced motion (`reduced_motion`)
## keeps the levels, the colours, the lamp and the glows (steady) and drops the slosh, the spray,
## the bubbles and the lamp's pop.
##
## While an item is dragged over a landing slot (#71, decision 4A) it previews the stretch that
## drop would give (paler for a gain, a dark stretch for a loss; show_hypothetical) until the drag
## ends; the monitor prints the would-be total. A drop that leaves the lap previews in its own
## lap's terms (_preview_plan): a loss darkens the tube down to the would-be level, under it the
## would-be lap's colour (teal or orange back under the quota); a gain fills the lap to the top
## and pours the would-be lap's colour from the foot. A Double checkout's rows (#122) show as
## RowPips on the housing's plate (RegisterTower places them). Display only: the amounts are the
## screen's preview and the LED's.

## The count's amount reached `multiple` times the quota (2 or more): lap `multiple` + 1 starts.
signal lap_reached(multiple: int)
## The lamp's laps made changed (the drawn liquid's, 0 short of the quota), `popped` as a count or a
## planning gain made a new lap (the top bar's ×N readout follows it, LapReadout).
signal lamp_changed(laps: int, popped: bool)
## A planning projection rose (show_projected, never a drag's preview): to `amount_shown` against
## `quota`, from `laps_from` to `laps_to` whole multiples of it (the gauge's pour and lap notes,
## GaugePanel). A first projection after a blank tube rises nothing.
signal projection_rose(amount_shown: int, quota: int, laps_from: int, laps_to: int)

## The glow: the glass's rim (its ink edge) in mustard light, pulsing every GLOW_SECONDS, from
## this share of the quota while short.
const NEAR_SHARE := 0.8
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
## play test of 2026-10-19: teal while short (the PR #138 review: teal in place of red, so a
## shift under way never reads as a fault), orange from NEAR_SHARE of the quota, money green once
## it is met. The colour eases to a new status over about 1 / STATUS_EASE_RATE seconds
## (at once under reduced motion). The receipt's foot says the same, so the status never shows by
## colour alone.
const WELL_COLOR := Palette.CHARCOAL
const SHORT_RAMP: Array[Color] = [Palette.TEAL_LIGHT, Palette.TEAL, Palette.TEAL_SHADE]
const NEAR_RAMP: Array[Color] = [Palette.MUSTARD, Palette.BRASS, Palette.BRASS_DARK]
const MET_RAMP: Array[Color] = [Palette.GREEN_LIGHT, Palette.GOOD, Palette.GREEN_DARK]
const STATUS_EASE_RATE := 6.0
## The lap lamp (LapLamp): its top left LAMP_AT art px from the tube's (over the housing's top
## cap). A lit lamp's glow pulses LAMP_GLOW_PULSE round LAMP_GLOW alpha every LAMP_GLOW_SECONDS
## (steady at LAMP_GLOW under reduced motion); a new lap pops its lens and glyph LAMP_POP larger,
## settling over LAMP_POP_SECONDS.
const LAMP_AT := Vector2i(1, -18)
const LAMP_GLOW := 0.18
const LAMP_GLOW_PULSE := 0.08
const LAMP_GLOW_SECONDS := 1.05
const LAMP_POP := 0.45
const LAMP_POP_SECONDS := 0.3
## The lamp sending its token to a week medal flashes the tube this much (MedalFlight).
const LAMP_LAND_FLASH := 0.6
## From lap QuotaLaps.TWINKLE_LAP on, TWINKLES paper pixels twinkle in the liquid, each lit for a
## quarter of its own TWINKLE_SECONDS period.
const TWINKLES := 5
const TWINKLE_SECONDS := 0.9
## The glass's tick marks (paper at TICK_ALPHA on its right side, at these shares of a lap):
## TICK_LENGTH art px long, HALF_TICK_LENGTH at half a lap.
const TICKS: Array[float] = [0.25, 0.5, 0.75]
const TICK_LENGTH := 3
const HALF_TICK_LENGTH := 4
const TICK_ALPHA := 0.55
## The glass's highlight (paper at SHINE_ALPHA): a column SHINE_INSET art px inside its left
## edge down the glass, and one SHINE_SHORT art px long two columns right of it.
const SHINE_ALPHA := 0.2
const SHINE_INSET := 2
const SHINE_SHORT := 8
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
## The glass lies on its side (left column v2, 2026-11-09: the gauge in the top bar, GaugePanel):
## the tube is drawn turned a quarter clockwise, so its foot is at the left and its target line at
## the right end; the lap lamp is drawn unturned at `lamp_offset`.
var horizontal: bool = false:
	set(value):
		horizontal = value
		queue_redraw()
## The lap lamp's top left (local px) when `horizontal` (else LAMP_AT art px over the tube's top).
var lamp_offset: Vector2 = Vector2.ZERO
## The lamp names the laps ("×N"); off, a lit lamp shows the check alone in its lap's colour
## (the top bar's gauge, whose ×N readout grows beside the glass: LapReadout).
var names_laps: bool = true

var _amount: int = 0
var _quota: int = 0
## A drag's would-be total, -1 when no drag shows.
var _hypothetical: int = -1
var _blank: bool = true
## The quota is met: the count-up's ding while counting, the projected total reaching it in
## planning.
var _met: bool = false
## The amount is the count's reading (not the planning projection).
var _live: bool = false
## The last planning projection was a gain (show_projected): a lap it makes pops the lamp as a
## count's does; a drag's preview never does.
var _rising: bool = false
## The amount's lap (1 while short, 0 blank); the lap drawn follows the eased level (_drawn_lap).
var _lap: int = 0
var _led: LedDisplay
## The amount drawn, eased (EASE_RATE).
var _shown: float = 0.0
var _slosh: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
## The lamp's pop, from 1 at a new lap down to 0, and the lap it last showed.
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
	var rose: bool = not _blank and amount_shown > _amount
	var laps_from: int = QuotaLaps.lap_of(_amount, _quota)
	_rising = rose
	_show(amount_shown, quota, quota > 0 and amount_shown >= quota)
	if rose:
		projection_rose.emit(amount_shown, quota, laps_from, QuotaLaps.lap_of(amount_shown, quota))


## A lap run's roll (GaugePanel.run_laps on a long run): `amount_shown` against `quota` drawn at
## once, with no easing, slosh, spray, flash or lamp pop, so a run through many laps a second
## stays calm (lamp_changed still names the laps, unpopped). `landed` is the roll's end: the
## amount sloshes and sprays once and the lap it makes flashes the tube and pops the lamp, as a
## planning gain's does. It emits no projection_rose (the run plays its own sounds).
func show_rolled(amount_shown: int, quota: int, landed: bool = false) -> void:
	_hypothetical = -1
	_rising = landed
	if landed and not _reduced():
		_slosh = SLOSH_MAX
		_spray(SPRAY_MAX)
	_blank = false
	_live = false
	_amount = amount_shown
	_quota = quota
	_met = quota > 0 and amount_shown >= quota
	_lap = QuotaLaps.lap_for(amount_shown, quota, _met)
	_shown = float(amount_shown)
	_follow_badge()
	queue_redraw()


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


## The gauge's fill in its lap now, as a fraction of its inside (for tests).
func fill() -> float:
	return 0.0 if _blank else QuotaLaps.lap_fill(float(_amount), _quota, _lap)


## The amount's lap: 1 while short (or before the ding), QuotaLaps.FIRST_LAP from the quota on,
## 0 blank.
func shown_lap() -> int:
	return 0 if _blank else _lap


## The tube glows (short of the quota, from NEAR_SHARE of it).
func is_near() -> bool:
	return not _blank and not _met and _quota > 0 and _amount >= _quota * NEAR_SHARE


## The tube itself (the gauge's rect: the quota crossing's and the premium announce's anchor).
func bar() -> Control:
	return self


## Where the quota stands on the tube, in global coordinates: the middle of the target line on
## the glass's top row (every lap is full at its target).
func quota_mark() -> Vector2:
	var cell: float = ArtStyle.ART_SCALE
	if horizontal:
		return get_global_transform() * Vector2(size.x - cell * 1.5, size.y / 2.0)
	return get_global_transform() * Vector2(size.x / 2.0, cell * 1.5)


## The lap lamp's text: empty while it is dark (blank, or the liquid short of the quota), the
## check once the first lap is full, "×N" once N laps are (LapLamp.text_for).
func badge_text() -> String:
	return LapLamp.text_for(_laps_made())


## The whole multiples of the quota the amount shown has made (0 short of it), e.g. 3 at ×3: what
## the quota crossing's over-quota chip reads as a count's total lands (v1.03).
func multiples_made() -> int:
	return QuotaLaps.lap_of(_amount, _quota) if _met else 0


## The lap lamp's rect (local px): LAMP_AT, LapLamp.SIZE art px square.
func badge_rect() -> Rect2:
	var cell: float = ArtStyle.ART_SCALE
	return Rect2(_lamp_at(), Vector2.ONE * LapLamp.SIZE * cell)


## The lamp's top left (local px): `lamp_offset` when horizontal, else LAMP_AT art px.
func _lamp_at() -> Vector2:
	return lamp_offset if horizontal else Vector2(LAMP_AT) * ArtStyle.ART_SCALE


## The lap lamp's rect on the canvas (with its layer's transform): where the token to a week
## medal takes off (MedalFlight).
func lamp_canvas_rect() -> Rect2:
	return get_global_transform_with_canvas() * badge_rect() if is_inside_tree() else Rect2()


## The lamp sends its token to a week medal (MedalFlight): it pops and the tube flashes, as at a
## new lap (reduced motion: no pop).
func pop_lamp() -> void:
	_pop = 0.0 if _reduced() else 1.0
	_flash = maxf(_flash, LAMP_LAND_FLASH)
	queue_redraw()


## Whether the lamp's pop is under way (tests).
func lamp_popping() -> bool:
	return _pop > 0.0


## The first lap's ramp as drawn now (for tests).
func ramp() -> Array[Color]:
	return _ramp


## The ramp of the liquid drawn now (the first lap's eased one, or the lap's), for tests.
func liquid_ramp() -> Array[Color]:
	var lap: int = _drawn_lap()
	return QuotaLaps.lap_ramp(lap) if lap >= QuotaLaps.FIRST_LAP else _ramp


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SECONDS)
	_pop = maxf(0.0, _pop - delta / LAMP_POP_SECONDS)
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
## quota flashes (in planning at once; while `counting` as the liquid reaches the target line,
## _follow_badge), a lower amount (a new count) empties the gauge at once. While `counting`,
## twice the quota and each multiple past it emit lap_reached.
func _show(amount_shown: int, quota: int, met: bool, counting: bool = false) -> void:
	var gain: int = amount_shown - _amount
	if _blank or gain < 0:
		_shown = float(amount_shown)
		_drops.clear()
	elif gain > 0 and not _reduced():
		_slosh = minf(SLOSH_MAX, _slosh + SLOSH_KICK + gain / SLOSH_PER_EURO)
		_spray(mini(SPRAY_MAX, SPRAY_DROPS + roundi(gain / SPRAY_PER_EURO)))
	_blank = false
	_live = counting
	_amount = amount_shown
	_quota = quota
	if met and not _met and not counting:
		_flash = 1.0
	_met = met
	var lap: int = QuotaLaps.lap_for(amount_shown, quota, met)
	if lap > _lap and lap > QuotaLaps.FIRST_LAP and counting:
		lap_reached.emit(lap - 1)
	_lap = lap
	if _reduced():
		_shown = float(amount_shown)
	_follow_badge()
	queue_redraw()


func _on_reading(amount_shown: int, quota: int, met: bool) -> void:
	_hypothetical = -1
	_rising = false
	var counting: bool = _led != null and _counting(_led.mode())
	_show(amount_shown, quota, met and counting, counting)


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK:
		_blank = true
		_hypothetical = -1
		_met = false
		_live = false
		_rising = false
		_lap = 0
		_drops.clear()
		_follow_badge()
	queue_redraw()


## The first lap's ramp for the status now: SHORT_RAMP, NEAR_RAMP from NEAR_SHARE of the quota
## (and past it before the ding), MET_RAMP once met.
func _status_ramp() -> Array[Color]:
	if _met:
		return MET_RAMP
	if is_near() or (_quota > 0 and _amount >= _quota):
		return NEAR_RAMP
	return SHORT_RAMP


## The lap drawn: the eased level's (so the liquid fills its lap, the first one included, to the
## top before the next one pours), never past the amount's; 0 blank.
func _drawn_lap() -> int:
	if _blank:
		return 0
	return mini(_lap, QuotaLaps.lap_for(floori(_shown), _quota, _met))


## A new lap drawn while counting, or after a planning gain (the user's play test of
## 2026-11-09), flashes the tube and pops the lamp; a drag's preview never does (a drag back and
## forth over a multiple does not blink). Any change of the laps made emits lamp_changed.
func _follow_badge() -> void:
	var lap: int = _drawn_lap()
	if lap == _badge_lap:
		return
	var popped: bool = lap > _badge_lap and lap >= QuotaLaps.FIRST_LAP and (_live or _rising)
	if popped:
		_flash = 1.0
		_pop = 0.0 if _reduced() else 1.0
	var laps_before: int = maxi(_badge_lap - 1, 0)
	_badge_lap = lap
	var laps: int = maxi(lap - 1, 0)
	if laps != laps_before or popped:
		lamp_changed.emit(laps, popped)


## The laps the drawn liquid has filled: 0 short of the quota (or blank), then one per multiple.
func _laps_made() -> int:
	return maxi(_drawn_lap() - 1, 0)


## The tube's size in art pixels.
## Lying on its side (`horizontal`), the tube's across is the control's height and its length the
## control's width.
func _art_size() -> Vector2i:
	var art: Vector2i = Vector2i((size / ArtStyle.ART_SCALE).floor())
	return Vector2i(art.y, art.x) if horizontal else art


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
	return _inner() * QuotaLaps.lap_fill(_shown, _quota, _drawn_lap())


func _draw() -> void:
	var art: Vector2i = _art_size()
	if art.x < 3 or art.y < 3:
		return
	if horizontal:
		# The tube's space turned a quarter clockwise: its foot at the left, its top at the right.
		draw_set_transform(Vector2(size.x, 0.0), PI / 2.0)
	_cell(0, 0, art.x, art.y, Palette.INK)
	_cell(1, 1, art.x - 2, art.y - 2, WELL_COLOR)
	if not _blank:
		_draw_liquid(art)
	_draw_glass(art)
	# The target: a tomato line across the glass's top row.
	_cell(1, 1, art.x - 2, 1, TARGET_COLOR)
	if is_near():
		_draw_glow(art)
	draw_set_transform(Vector2.ZERO)
	_draw_lamp()


## The glass over the liquid: its tick marks on the right side and its highlight on the left.
func _draw_glass(art: Vector2i) -> void:
	var foot: int = art.y - 1
	for share: float in TICKS:
		var length: int = HALF_TICK_LENGTH if is_equal_approx(share, 0.5) else TICK_LENGTH
		var y: int = foot - roundi(_inner() * share)
		_cell(art.x - 1 - length, y, length, 1, Color(Palette.PAPER, TICK_ALPHA))
	var shine: Color = Color(Palette.PAPER, SHINE_ALPHA)
	var top: int = 1 + SHINE_INSET
	_cell(1 + SHINE_INSET, top, 1, art.y - 2 * (SHINE_INSET + 1), shine)
	_cell(3 + SHINE_INSET, top, 1, SHINE_SHORT, shine)


## The glass's rim in mustard light, pulsing (steady under reduced motion).
func _draw_glow(art: Vector2i) -> void:
	var alpha: float = 1.0
	if not _reduced():
		alpha = 0.5 - 0.5 * cos(TAU * fmod(_time, GLOW_SECONDS) / GLOW_SECONDS)
	var rim: Color = Color(Palette.MUSTARD_LIGHT, alpha)
	_cell(0, 0, art.x, 1, rim)
	_cell(0, art.y - 1, art.x, 1, rim)
	_cell(0, 1, 1, art.y - 2, rim)
	_cell(art.x - 1, 1, 1, art.y - 2, rim)


## The lap lamp: dark until the first lap is full, then in the newest full lap's colours with its
## glyph, glowing, its lens popped as a lap is made.
func _draw_lamp() -> void:
	var cell: float = ArtStyle.ART_SCALE
	var colours: Array[Color] = []
	var glow: float = 0.0
	if _laps_made() > 0:
		colours = QuotaLaps.backdrop_ramp(_drawn_lap())
		glow = LAMP_GLOW
		if not _reduced():
			glow += LAMP_GLOW_PULSE * sin(TAU * _time / LAMP_GLOW_SECONDS)
	var pop: float = 1.0 + LAMP_POP * pow(_pop, 3.0)
	var text: String = badge_text()
	if not names_laps and not text.is_empty():
		text = LapLamp.CHECK_TEXT
	LapLamp.draw(self, _lamp_at(), cell, colours, text, glow, pop)


func _draw_liquid(art: Vector2i) -> void:
	var reduced: bool = _reduced()
	var foot: int = art.y - 1
	var lap: int = _drawn_lap()
	var front: float = _front()
	var liquid: Array[Color] = liquid_ramp()
	var backdrop: Array[Color] = []
	if lap >= QuotaLaps.FIRST_LAP:
		backdrop = QuotaLaps.backdrop_ramp(lap)
	var plan: Dictionary = _preview_plan()
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
		if not plan.is_empty():
			_draw_preview(plan, Vector3i(x, column, top), foot, liquid, backdrop)
	if not reduced:
		_draw_motion(art, front, liquid)
		if lap >= QuotaLaps.TWINKLE_LAP:
			_draw_twinkles(art, front)
	if _flash > 0.0:
		_cell(1, 1, art.x - 2, art.y - 2, Color(Palette.PAPER, _flash * FLASH_ALPHA))


## A drag's preview (#71), empty when none shows: the would-be lap ("lap"), its level in art px
## over the inside's foot ("level") and its columns ("ramp": the first lap's by the would-be
## status, red or orange, back under the quota).
func _preview_plan() -> Dictionary:
	if _hypothetical < 0 or _blank:
		return {}
	var met: bool = _quota > 0 and _hypothetical >= _quota
	var lap: int = QuotaLaps.lap_for(_hypothetical, _quota, met)
	var colours: Array[Color] = SHORT_RAMP
	if lap >= QuotaLaps.FIRST_LAP:
		colours = QuotaLaps.lap_ramp(lap)
	elif _hypothetical >= _quota * NEAR_SHARE:
		colours = NEAR_RAMP
	return {
		"lap": lap,
		"level": _inner() * QuotaLaps.lap_fill(float(_hypothetical), _quota, lap),
		"ramp": colours,
	}


## One column's preview (`at`: its x, its column (lit, mid, dark) and its liquid's top): in the
## drawn lap the stretch gained (the lit colour, see-through) or lost (the dark one); a drop
## leaving the lap shows in its own lap's terms.
func _draw_preview(
	plan: Dictionary, at: Vector3i, foot: int, liquid: Array[Color], backdrop: Array[Color]
) -> void:
	var lap: int = plan["lap"]
	var level_top: int = foot - roundi(float(plan["level"]))
	var colours: Array[Color] = plan["ramp"]
	var x: int = at.x
	var top: int = at.z
	var drawn: int = _drawn_lap()
	if lap > drawn:
		# A gain past the lap's top: the lap fills up, the would-be lap pours from the foot.
		_cell(x, 1, 1, top - 1, Color(liquid[0], GAIN_PREVIEW_ALPHA))
		_cell(x, level_top, 1, foot - level_top, Color(colours[0], GAIN_PREVIEW_ALPHA))
	elif lap < drawn:
		# A loss under the lap's foot: all above the would-be level goes dark, under it the
		# would-be lap's colour.
		var dark: Color = backdrop[2] if not backdrop.is_empty() else liquid[2]
		_cell(x, 1, 1, mini(top, level_top) - 1, Color(dark, LOSS_PREVIEW_ALPHA))
		_cell(x, top, 1, level_top - top, Color(liquid[2], LOSS_PREVIEW_ALPHA))
		_cell(x, level_top, 1, foot - level_top, colours[at.y])
	elif level_top < top:
		_cell(x, level_top, 1, top - level_top, Color(liquid[0], GAIN_PREVIEW_ALPHA))
	elif level_top > top:
		_cell(x, top, 1, level_top - top, Color(liquid[2], LOSS_PREVIEW_ALPHA))


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


## The brighter gold laps' twinkles: TWINKLES paper pixels in the liquid under its surface, each
## lit a moment in its own period.
func _draw_twinkles(art: Vector2i, front: float) -> void:
	var foot: float = art.y - 1.0
	for index: int in range(TWINKLES):
		var bubble: Vector3 = _bubbles[index % _bubbles.size()]
		var phase: float = fmod(_time / TWINKLE_SECONDS + bubble.y * 3.0, 1.0)
		if phase > 0.25:
			continue
		var x: int = 2 + floori(fmod(bubble.x + index * 0.37, 1.0) * (art.x - 5.0))
		var y: int = floori(foot - 2.0 - fmod(bubble.z * 7.0, maxf(1.0, front - 3.0)))
		if y > 1:
			_cell(x, y, 1, 1, Palette.PAPER)


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
