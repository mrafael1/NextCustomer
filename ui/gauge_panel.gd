class_name GaugePanel
extends Control
## The quota gauge in the top bar (left column v2, the user's pick of 2026-11-09: mock-up
## docs/art/mockups/left_column_v2.html; relooked after the user's play test of the same day): one
## instrument on the bar's band, no chip around it: the lap lamp at its left, mounted on the end of
## the glass's steel bezel (a 1 art px ink edge, a 1 art px steel ring lit top left), the gauge's
## glass lying on its side inside it (QuotaMeter.horizontal: the liquid from the left, the target's
## red line at the right end, the quarter ticks), then the ×N readout (LapReadout, from ×2, chunky
## pixel digits, growing at ×3 and at ×5; the lamp keeps its lap colour and the check) and, on
## a Double checkout (#122), the row pips at the right end (the glass gives them its room).
##
## Sound (the same play test): a planning projection that rises (QuotaMeter.projection_rose, never
## a drag's preview, never a loss) pours ("pour", POUR_DELAY after the card's own sound, its pitch
## rising with the glass's fill); one that makes a lap also plays a ladder note (LAP_NOTES: the
## quota, ×2 silver, ×3 and up gold rising) as the lamp and the readout pop. run_laps runs the laps
## from 0 to a total with the same sounds and ramp (CHECKOUT's medal prelude), emitting
## lap_run_step per lap, never the meter's lap_reached (the quota crossing's); a long run (×6 and
## up) steps the medals' laps, rolls through the rest and lands on its final ×N.
##
## At CHECKOUT (after the medal prelude, MedalPrelude, when the checkout earned a medal) it
## slides up out of the top bar (hide_gauge: the receipt's TOTAL carries the count) and comes back
## down with the next day's planning stub (show_gauge), in whole art px, eased; at once under
## reduced motion. It names neither TopBar nor ShiftStage (they name it: no cyclic script
## references). Its parent clips it (TopBar's gauge room), so it never shows above the bar. The
## meter keeps following the register's reading while hidden, so its laps still reach the quota
## crossing. A hidden gauge makes no sound. Display only: it takes
## no clicks.

## run_laps made `laps` whole multiples of the quota (1 at the quota).
signal lap_run_step(laps: int)

## The lamp's top left and the glass's top left (px), the glass's height; the bezel round the
## glass (its ink edge and its steel ring, BEZEL art px together); the gap kept at the right end,
## the readout's room and its gap after the bezel, and the pips' gap after the readout's room.
const LAMP_AT := Vector2(2, 6)
const GLASS_AT := Vector2(30, 6)
const GLASS_HEIGHT := 26.0
const BEZEL := 2
const END_GAP := 4.0
const READOUT_ROOM := 88.0
const READOUT_GAP := 6.0
const PIPS_GAP := 8.0
## The bezel's colours: its edge, its lit ring (top, left) and its shaded ring (foot, right).
const BEZEL_EDGE := Palette.INK
const BEZEL_LIT := Palette.STEEL_LIGHT
const BEZEL_SHADE := Palette.STEEL_SHADE
## The slide: SLIDE_SECONDS, eased in and out, whole art px; hidden, the gauge's foot is
## HIDE_CLEAR px above its rest top (out of the clipping room).
const SLIDE_SECONDS := 0.3
const HIDE_CLEAR := 4.0
## The pour: POUR_DELAY s after the rise (the card's place sound first), its pitch
## POUR_PITCH_LOW in an empty lap up to POUR_PITCH_LOW + POUR_PITCH_RISE at its top.
const POUR_SOUND := "pour"
const POUR_DELAY := 0.06
const POUR_PITCH_LOW := 0.85
const POUR_PITCH_RISE := 0.45
## A lap made in planning: the ladder note (Sfx.play_note) by laps made, from the quota (1) on,
## the last one from there up; LAP_NOTE_DELAY s after the rise, LAP_NOTE_DB quieter.
const LAP_NOTES: Array[int] = [5, 7, 8, 9, 10]
const LAP_NOTE_DELAY := 0.18
const LAP_NOTE_DB := -6.0
## run_laps: RUN_STEP_SECONDS per step. A run of more than RUN_PLAIN_STEPS steps steps only its
## lead laps, then rolls to the last lap in RUN_ROLL_SECONDS (eased out by RUN_ROLL_EASE, a pour
## at most every RUN_ROLL_POUR_SECONDS), lands on the total and holds it RUN_LAND_SECONDS.
const RUN_STEP_SECONDS := 0.45
const RUN_PLAIN_STEPS := 6
const RUN_ROLL_SECONDS := 0.7
const RUN_ROLL_EASE := 3.0
const RUN_ROLL_POUR_SECONDS := 0.07
const RUN_LAND_SECONDS := 0.3

var quota_meter: QuotaMeter
var row_pips: RowPips
var readout: LapReadout

## The rest top (the parent's px), and how far up it is: 0 shown .. 1 hidden.
var _rest_y: float = 0.0
var _up: float = 0.0
var _hidden: bool = false
var _tween: Tween
## The planning pours and lap notes still waiting to sound (_hush kills them).
var _sounds: Array[Tween] = []
## run_laps is told to jump to its end (finish_laps); a projection that rises pours nothing.
var _run_skipped: bool = false
var _quiet: bool = false


func _init() -> void:
	name = "GaugePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	quota_meter = QuotaMeter.new()
	quota_meter.horizontal = true
	quota_meter.names_laps = false
	quota_meter.lamp_offset = LAMP_AT - GLASS_AT
	add_child(quota_meter)
	readout = LapReadout.new()
	readout.reduced_motion = _reduced
	readout.room = READOUT_ROOM
	add_child(readout)
	row_pips = RowPips.new()
	row_pips.reduced_motion = _reduced
	add_child(row_pips)
	quota_meter.lamp_changed.connect(readout.show_laps)
	quota_meter.projection_rose.connect(_on_projection_rose)
	readout.resized.connect(_place_readout)
	row_pips.visibility_changed.connect(_lay_out)
	row_pips.minimum_size_changed.connect(_lay_out)
	resized.connect(_lay_out)


## Puts the gauge at `rest` (its parent's px), `room` px large, shown or hidden as it is now.
func place(rest: Vector2, room: Vector2) -> void:
	_rest_y = rest.y
	position = rest
	size = room
	_lay_out()
	_set_up(_up)


## Slides the gauge up out of the bar (CHECKOUT), unless `animate` is false or motion is reduced.
func hide_gauge(animate: bool = true) -> void:
	_slide(true, animate)


## Brings the gauge back down (the next day's stub), unless `animate` is false or motion is reduced.
func show_gauge(animate: bool = true) -> void:
	_slide(false, animate)


## Whether the gauge is (going) up out of the bar.
func is_hidden() -> bool:
	return _hidden


## How far up it is now: 0 shown .. 1 hidden.
func up_amount() -> float:
	return _up


## The glass's rect in the gauge (px): the room left of the readout's (and the pips' while they
## show), in whole art px pairs.
func glass_rect() -> Rect2:
	var right: float = size.x - END_GAP - READOUT_ROOM - READOUT_GAP - BEZEL * ArtStyle.ART_SCALE
	if row_pips.visible:
		right -= row_pips.get_combined_minimum_size().x + PIPS_GAP
	var pair: float = ArtStyle.ART_SCALE * 2.0
	var width: float = floorf(maxf(right - GLASS_AT.x, 0.0) / pair) * pair
	return Rect2(GLASS_AT, Vector2(width, GLASS_HEIGHT))


## The bezel's outer rect (px): the glass grown by BEZEL art px.
func bezel_rect() -> Rect2:
	return glass_rect().grow(BEZEL * ArtStyle.ART_SCALE)


## Runs the laps from 0 to `total` against `quota` (CHECKOUT's medal prelude): the glass empties,
## then rises to each multiple of the quota and to `total`, one step every RUN_STEP_SECONDS, each
## step pouring and each lap ringing its note, the lamp and the readout popping, as in planning,
## and lap_run_step(laps) as each lap is made.
##
## A run of more than RUN_PLAIN_STEPS steps (the user's play test of 2026-11-10: ×50 and up felt
## long) steps only laps 1 .. `lead_laps` that way (the laps a medal waits for, MedalPrelude), then
## rolls: for RUN_ROLL_SECONDS the amount runs, eased out so the last laps tick one by one, up to
## the last lap, drawn at once (QuotaMeter.show_rolled: no flash, spray, pop or lap note; one pour
## at most every RUN_ROLL_POUR_SECONDS, its pitch rising), then lands: the exact `total` with one
## pop, flash, pour and note, held RUN_LAND_SECONDS. The roll follows the time passed, not the
## frames or the laps, so the run lasts the same at any lap count and frame rate.
##
## Under reduced motion, or once finish_laps() is called, it goes to `total` at once (quietly),
## still emitting every lap left. It ends on `total` (the projection the planning showed), the
## readout reading its final ×N on a long run; the meter's lap_reached stays quiet (that is the
## count's).
func run_laps(total: int, quota: int, lead_laps: int = 0) -> void:
	_run_skipped = false
	_hush()
	quota_meter.show_projected(0, quota)
	if total <= 0:
		return
	var steps: Array[int] = []
	var made: int = QuotaLaps.lap_of(total, quota)
	for multiple: int in range(1, made + 1):
		steps.append(multiple * quota)
	if steps.is_empty() or steps[-1] != total:
		steps.append(total)
	var laps_before: int = 0
	var long: bool = steps.size() > RUN_PLAIN_STEPS
	if long:
		laps_before = await _run_long(total, quota, clampi(lead_laps, 0, made - 1))
	else:
		laps_before = await _run_steps(steps, quota)
	if not is_inside_tree():
		return
	if quota_meter.amount() != total:
		_quiet = true
		if long:
			quota_meter.show_rolled(total, quota)  # Drawn at once: the readout reads its ×N.
		else:
			quota_meter.show_projected(total, quota)
		_quiet = false
	for laps: int in range(laps_before + 1, made + 1):
		lap_run_step.emit(laps)


## run_laps' plain run: each of `steps` (amounts) shown RUN_STEP_SECONDS; returns the laps made
## (and emitted) so far.
func _run_steps(steps: Array[int], quota: int) -> int:
	var laps_before: int = 0
	for amount: int in steps:
		if _run_stopped():
			break
		quota_meter.show_projected(amount, quota)
		var laps: int = QuotaLaps.lap_of(amount, quota)
		if laps > laps_before:
			lap_run_step.emit(laps)
		laps_before = laps
		var waited: float = 0.0
		while waited < RUN_STEP_SECONDS and not _run_skipped:
			await get_tree().process_frame
			if not is_inside_tree():
				return laps_before
			waited += get_process_delta_time()
	return laps_before


## run_laps' long run to `total`: laps 1 .. `lead` stepped on the beat, the roll to the last lap,
## the landing and its hold, all placed on one clock (the time passed since the run's start, so
## whole frames never add up); returns the laps made (and emitted) so far.
func _run_long(total: int, quota: int, lead: int) -> int:
	var made: int = QuotaLaps.lap_of(total, quota)
	var roll_at: float = lead * RUN_STEP_SECONDS
	var land_at: float = roll_at + RUN_ROLL_SECONDS
	var roll_from: int = lead * quota
	var roll_to: int = made * quota - 1
	var elapsed: float = 0.0
	var laps_before: int = 0
	var next_pour: float = roll_at
	var landed: bool = false
	while not _run_stopped():
		if elapsed < roll_at:
			var lap: int = mini(floori(elapsed / RUN_STEP_SECONDS) + 1, lead)
			if lap > laps_before:
				quota_meter.show_projected(lap * quota, quota)
		elif elapsed < land_at:
			var along: float = (elapsed - roll_at) / RUN_ROLL_SECONDS
			var eased: float = 1.0 - pow(1.0 - along, RUN_ROLL_EASE)
			quota_meter.show_rolled(roundi(lerpf(roll_from, roll_to, eased)), quota)
			if elapsed >= next_pour:
				next_pour = elapsed + RUN_ROLL_POUR_SECONDS
				_play(POUR_SOUND, POUR_PITCH_LOW + POUR_PITCH_RISE * along)
		elif not landed:
			landed = true
			quota_meter.show_rolled(total, quota, true)
			_play(POUR_SOUND, pour_pitch(total, quota))
			_play_note(lap_note(made))
		elif elapsed >= land_at + RUN_LAND_SECONDS:
			break
		var laps: int = QuotaLaps.lap_of(quota_meter.amount(), quota)
		for step: int in range(laps_before + 1, laps + 1):
			lap_run_step.emit(step)
		laps_before = maxi(laps_before, laps)
		await get_tree().process_frame
		if not is_inside_tree():
			return laps_before
		elapsed += get_process_delta_time()
	return laps_before


## Whether a run under way stops now: skipped, reduced motion, or out of the tree.
func _run_stopped() -> bool:
	return _run_skipped or _reduced() or not is_inside_tree()


## run_laps jumps to its end now (a tap skipping the prelude).
func finish_laps() -> void:
	_run_skipped = true
	_hush()


## The note played for `laps` made in planning (LAP_NOTES).
static func lap_note(laps: int) -> int:
	return LAP_NOTES[clampi(laps - 1, 0, LAP_NOTES.size() - 1)]


## The pour's pitch for `amount_shown` against `quota`: by the glass's fill in its lap, full on a
## multiple of the quota.
static func pour_pitch(amount_shown: int, quota: int) -> float:
	var fill: float = 1.0
	if quota > 0:
		var lap: int = maxi(ceili(float(amount_shown) / quota), 1)
		fill = QuotaLaps.lap_fill(float(amount_shown), quota, lap)
	return POUR_PITCH_LOW + POUR_PITCH_RISE * fill


func _on_projection_rose(amount_shown: int, quota: int, laps_from: int, laps_to: int) -> void:
	if _hidden or _quiet or not is_visible_in_tree():
		return
	var sounds: Tween = create_tween()
	_sounds = _sounds.filter(func(queued: Tween) -> bool: return queued.is_valid())
	_sounds.append(sounds)
	sounds.tween_interval(POUR_DELAY)
	sounds.tween_callback(_play.bind(POUR_SOUND, pour_pitch(amount_shown, quota)))
	if laps_to > laps_from:
		sounds.tween_interval(maxf(LAP_NOTE_DELAY - POUR_DELAY, 0.0))
		sounds.tween_callback(_play_note.bind(lap_note(laps_to)))


## Kills the pours and lap notes still waiting (the gauge going up, a skip, a run's start).
func _hush() -> void:
	for queued: Tween in _sounds:
		if queued.is_valid():
			queued.kill()
	_sounds.clear()


func _play(sound: String, pitch: float) -> void:
	if _hidden:
		return
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play(sound, pitch)


func _play_note(index: int) -> void:
	if _hidden:
		return
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play_note(index, LAP_NOTE_DB)


func _slide(up: bool, animate: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_hidden = up
	if up:
		_hush()
	var to: float = 1.0 if up else 0.0
	if not animate or _reduced() or not is_inside_tree():
		_set_up(to)
		return
	_tween = create_tween()
	_tween.tween_method(_set_up, _up, to, SLIDE_SECONDS * absf(to - _up))


## `k` of the way up (0 .. 1), eased, in whole art px.
func _set_up(k: float) -> void:
	_up = k
	var e: float = k * k * (3.0 - 2.0 * k)
	var reach: float = _rest_y + size.y + HIDE_CLEAR
	var cell: float = ArtStyle.ART_SCALE
	position.y = _rest_y - roundf(e * reach / cell) * cell


func _lay_out() -> void:
	var glass: Rect2 = glass_rect()
	quota_meter.position = glass.position
	quota_meter.size = glass.size
	var pips: Vector2 = row_pips.get_combined_minimum_size()
	row_pips.size = pips
	row_pips.position = Vector2(
		size.x - END_GAP - pips.x, snappedf((size.y - pips.y) / 2.0, ArtStyle.ART_SCALE)
	)
	_place_readout()
	queue_redraw()


## The readout just right of the bezel, its resting digits on the glass's middle, on the art grid
## (its box's top LapReadout.LIFT px above them, never above the gauge's top).
func _place_readout() -> void:
	var cell: float = ArtStyle.ART_SCALE
	var digits_top: float = glass_rect().get_center().y - readout.digits_height() / 2.0
	var top: float = maxf(floorf(digits_top / cell) * cell - LapReadout.LIFT, 0.0)
	readout.position = Vector2(ceilf((bezel_rect().end.x + READOUT_GAP) / cell) * cell, top)


## The glass's bezel: an ink edge with its corners cut, a steel ring inside it, lit top left.
func _draw() -> void:
	var cell: float = ArtStyle.ART_SCALE
	var outer: Rect2 = bezel_rect()
	if outer.size.x <= 2.0 * BEZEL * cell:
		return
	draw_rect(outer.grow_individual(-cell, 0.0, -cell, 0.0), BEZEL_EDGE)
	draw_rect(outer.grow_individual(0.0, -cell, 0.0, -cell), BEZEL_EDGE)
	var ring: Rect2 = outer.grow(-cell)
	draw_rect(ring, BEZEL_SHADE)
	draw_rect(Rect2(ring.position, Vector2(ring.size.x - cell, cell)), BEZEL_LIT)
	draw_rect(Rect2(ring.position, Vector2(cell, ring.size.y - cell)), BEZEL_LIT)


## The gauge's reduced motion setting (the screen sets the meter's), for the slide and the pips.
func _reduced() -> bool:
	var reduced: Callable = quota_meter.reduced_motion
	return reduced.is_valid() and bool(reduced.call())
