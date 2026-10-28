class_name CountUpBeats
extends RefCounted
## CountUp's beat handlers (#60, #86 v6): how each kind of beat moves and sounds, kept out of
## CountUp so it stays under gdlint's file length (like CountUpDessert). CountUp starts each beat
## with play() and waits the beat's length; the motion here is fitted to that length and runs on
## the count-up's tweens (`make_tween`), so taps, holds and hit-stops apply. What the count owns
## stays CountUp's and is called back through the hooks CountUp.setup sets: step_landed
## (landed), the hit-stops (land), the total shown (set_total), a landing on it (landing) and the
## quota met.
##
## Where things fly from (#86 v6): an item's flights and puffs start where the item is now, the
## rect CountUp.source_rect gives for its slot (the belt ride's: the scanner, or the bag's mouth
## once bagged), else the item view's centre. Items are never lifted or dropped in place: the
## belt ride moves them. A payout's line, printed hidden at the beat's start, fades in.
##
## The total (#105 piece 2, mock-up readability_v3.html): each landing beat (CountUpPlan's
## landings: a base, a +N, a ×'s gain, a denial's fall) adds into the shown total fly_ms after the
## beat starts, in at most ticks_per_landing whole-euro ticks tick_gap_ms apart. Each tick is one
## callback on the count's tweens that sets the total and plays the tick sound, so the digits and
## the sound never part, and taps, holds and hit-stops move both. The beat's note (and a ×'s stamp
## sample) sounds on its first tick, `landing` tells the monitor and the beat's hit-stop freezes
## that impact; the ding beat meets the quota on its crossing tick (the first at or over it), its
## hold there. Under reduced motion the total jumps to the landing's value at its first tick; the
## ticks still sound.
##
## The beats: a plain card's scan beep, note, base pop and payout in one short beat; bonuses
## flying in from the card (or upgrade box) that caused them; multiplier stamps; copies; Soup's
## and the inspections' "denied"; sticker and Bundle moments; an armed effect's glow (the belt
## ride sends its sparks); fizzle puffs; the total's ticks at each landing; a register rattle on
## big payouts; the quota ding as the ding beat's last tick lands.

## Motion lengths at speed 1 (s), the longest each gets: a shorter beat shortens it (_motion).
## A plain card's scan before its payout lands, between these.
const SCAN_MIN := 0.05
const SCAN_MAX := 0.1
const BONUS_FLIGHT := 0.32
const OWN_BONUS_RISE := 0.3
const STAMP_SLAM := 0.16
const UPGRADE_FLIGHT := 0.3
const DENIED_LANDING := 0.2
const TAG_FLIGHT := 0.35
const LINK_SHRINK := 0.45
const RESET_FLIGHT := 0.3
const FIZZLE_SHUDDER := 0.2
const FIZZLE_RECOVER := 0.15
const ECHO_POP := 0.12

## The sounds: the count-up's own Sfx (CountUp keeps it in step with its own).
var sfx: Sfx
## The plan being played, set by begin().
var plan: CountUpPlan
## CountUp's hooks for what the count owns (CountUp.setup sets them): step_landed for a beat's
## steps (beat), the beat's hit-stop (beat), the total shown (amount), a landing on it (beat), a
## payout's landing (payout, subtotal) and the quota met (with_ding).
var landed: Callable
var land: Callable
var set_total: Callable
var landing: Callable
var payout_landed: Callable
var meet_quota: Callable
## The monitor total's tuning (CountUp sets it).
var total_tuning: CountTotalTuning
var _count: CountUp
var _tuning: CountUpTuning
var _overlay: Control
var _receipt: ReceiptView
var _fx: CountUpMotion
## Shaken on big payouts (the register rattle).
var _rattle_target: Control
## Returns a new Tween that follows the count-up's speed.
var _make_tween: Callable
var _views: Array[CardView] = []
var _names: PackedStringArray = PackedStringArray()
var _steps: Array[ScoreStep] = []
## The loyalty-card boxes and names of the run's upgrades, indexed like the run's upgrades
## (a step's source_index). Never mixed up with _views, which is indexed by slot.
var _upgrade_boxes: Array[Control] = []
var _upgrade_names: PackedStringArray = PackedStringArray()
## Where the shift's inspections are shown and their names, indexed like the shift's
## inspections (a step's source_index).
var _inspection_sources: Array[Control] = []
var _inspection_names: PackedStringArray = PackedStringArray()
## Each slot's last receipt line printed so far (_print_step): where a payout that prints no
## line sends its chip.
var _last_lines: Dictionary[int, Control] = {}


func _init(
	count_up: CountUp,
	overlay: Control,
	receipt: ReceiptView,
	fx: CountUpMotion,
	rattle_target: Control,
	make_tween: Callable
) -> void:
	_count = count_up
	_overlay = overlay
	_receipt = receipt
	_fx = fx
	_rattle_target = rattle_target
	_make_tween = make_tween


## Starts a row: `plan` over `steps` on the row's card `views`, with the receipt's names of the
## items, upgrades and inspections and where the upgrades and inspections are shown.
func begin(
	count_plan: CountUpPlan,
	tuning: CountUpTuning,
	steps: Array[ScoreStep],
	views: Array[CardView],
	names: PackedStringArray,
	upgrade_boxes: Array[Control],
	upgrade_names: PackedStringArray,
	inspection_sources: Array[Control],
	inspection_names: PackedStringArray
) -> void:
	plan = count_plan
	_tuning = tuning
	_steps = steps
	_views = views
	_names = names
	_upgrade_boxes = upgrade_boxes
	_upgrade_names = upgrade_names
	_inspection_sources = inspection_sources
	_inspection_names = inspection_names
	_last_lines.clear()


## Starts beat `index`'s motion and sound; the count-up waits its length.
func play(index: int) -> void:
	var beat: CountUpBeat = plan.beats[index]
	var step: ScoreStep = _steps[beat.steps[0]]
	match beat.kind:
		CountUpBeat.Kind.MERGED_PLAIN:
			_merged(beat, step, _steps[beat.steps[1]])
		CountUpBeat.Kind.BASE:
			_base(step)
		CountUpBeat.Kind.BONUS:
			_bonus(beat, step)
		CountUpBeat.Kind.STAMP:
			_stamp(beat, step)
		CountUpBeat.Kind.DENIED:
			_denied(beat, step)
		CountUpBeat.Kind.PAYOUT:
			_payout(beat, step)
		CountUpBeat.Kind.ARMED:
			_armed(beat, step)
		CountUpBeat.Kind.FIZZLE:
			_fizzle(beat, step)
		CountUpBeat.Kind.TAG:
			_tag_added(beat, step)
		CountUpBeat.Kind.LINK:
			_linked(beat, step)
		CountUpBeat.Kind.CREDIT:
			_credit(beat, step)
	if beat.kind not in [CountUpBeat.Kind.BONUS, CountUpBeat.Kind.STAMP, CountUpBeat.Kind.FIZZLE]:
		landed.call(beat)
	_land_total(beat)


## A step's receipt line (ReceiptView.step_line, "" for none), with the row's names.
func line_of(step: ScoreStep) -> String:
	return ReceiptView.step_line(step, _names, _upgrade_names, _inspection_names)


## The print sound's pitch: the printer's speed, capped (D3).
func print_pitch() -> float:
	return minf(plan.printer_speed, _tuning.print_pitch_max)


## The register rattle's sound for a rattle of `px` pixels: rattle_s, rattle_m or rattle_l,
## louder for a stronger rattle.
func play_rattle(px: float) -> void:
	var take: String = "rattle_s"
	if px >= CountUp.RATTLE_LARGE_PX:
		take = "rattle_l"
	elif px >= CountUp.RATTLE_MEDIUM_PX:
		take = "rattle_m"
	var volume: float = lerpf(
		CountUp.RATTLE_QUIET_DB, 0.0, clampf(px / CountUp.RATTLE_FULL_PX, 0.0, 1.0)
	)
	sfx.play(take, 1.0, volume)


## How long a beat's motion may take at speed 1, in seconds: its length without the shortest
## trailing gap.
func _motion(beat: CountUpBeat) -> float:
	return maxf(SCAN_MIN, (beat.duration_ms - _tuning.fit_gap_ms) / 1000.0)


func _tag_added(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	var from: Vector2 = _at(step.source_slot) if source != null else _at(step.slot)
	if source == null:
		source = target
	_fx.punch(source.body, 1.1)
	var flight: float = minf(TAG_FLIGHT, _motion(beat) * 0.7)
	await _fx.fly_text("+" + step.tag, from, _at(step.slot), Palette.LIGHT_TEXT, 24, flight)
	sfx.play("tag")
	target.add_tag(step.tag)
	_fx.punch(target.body, 1.15)


func _linked(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var left: Vector2 = _at(step.slot)
	var right: Vector2 = _at(step.linked_slot)
	var line: Line2D = Line2D.new()
	line.width = 10.0
	line.default_color = Palette.TEAL
	line.add_point(left - _overlay.global_position)
	line.add_point(right - _overlay.global_position)
	_overlay.add_child(line)
	sfx.play("link")
	var shrink: float = minf(LINK_SHRINK, _motion(beat) * 0.8)
	# A coupon's link punches the coupon. An upgrade's (Rule bender) comes out of its
	# loyalty-card box: its name flies to the link, so the player sees what joined the cards.
	var source: Control = _source_control(step)
	if source != null:
		_fx.punch(_moving_part(source), 1.15)
	var box: Control = _upgrade_box(step)
	if box != null:
		_fx.fly_text(step.text, _center(box), (left + right) / 2.0, Palette.TEAL, 20, shrink, true)
	_fx.punch(_views[step.slot].body, 1.12)
	_fx.punch(_views[step.linked_slot].body, 1.12)
	var tween: Tween = _tween()
	tween.tween_property(line, "width", 3.0, shrink)
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)


## A perk's credit (#108 piece 2): its loyalty-card box punches and what it earned ("€17") flies
## from the box to the item, in teal; the total doesn't move (the payout is already in it).
func _credit(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var box: Control = _upgrade_box(step)
	if box == null:
		return
	_fx.punch(_moving_part(box), 1.15)
	var flight: float = minf(TAG_FLIGHT, _motion(beat) * 0.7)
	_fx.fly_text("€%d" % step.value, _center(box), _at(step.slot), Palette.TEAL, 20, flight, true)


## A fizzle: the card shudders, greys out for a moment, and lets out a little WASTED puff where
## it is now (the bag's mouth for a bagged item). An upgrade's fizzle comes out of its
## loyalty-card box instead, a day event's from its chip (v0.69; the card it had nothing to work
## on gives a small nudge).
func _fizzle(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var view: CardView = _views[step.slot]
	var shaken: Control = view.body
	var puff_at: Vector2 = _at(step.slot) + Vector2(0, -30)
	var puff_to: Vector2 = puff_at + Vector2(0, -50)
	var upgrade_box: Control = _upgrade_box(step)
	if upgrade_box == null:
		upgrade_box = _inspection_source(step)
	var resetter: CardView = _source_view(step)
	var motion: float = _motion(beat)
	if upgrade_box != null:
		shaken = upgrade_box
		# The box sits in the top bar: the puff drifts down from it, onto the screen.
		puff_at = _center(upgrade_box) + Vector2(0, 26)
		puff_to = puff_at + Vector2(0, 50)
		_fx.punch(view.body, 1.06)
	elif resetter != null and step.source_slot != step.slot:
		# A reset: show the card that wiped this one's effect.
		_fx.punch(resetter.body, 1.15)
		var flight: float = minf(RESET_FLIGHT, motion * 0.35)
		motion -= flight
		await _fx.fly_text(
			"reset", _at(step.source_slot), _at(step.slot), Palette.LIGHT_TEXT, 20, flight
		)
	sfx.play("fizzle")
	landed.call(beat)
	shaken.pivot_offset = shaken.size / 2.0
	# An upgrade's box keeps its stamp tilt: the shudder ends where it started.
	var rest: float = shaken.rotation if upgrade_box != null else 0.0
	var shudder: float = minf(FIZZLE_SHUDDER, motion * 0.4)
	var recover: float = minf(FIZZLE_RECOVER, motion * 0.3)
	var tween: Tween = _tween()
	tween.tween_property(shaken, "modulate", Color(0.6, 0.6, 0.6), 0.06)
	if plan.reduced_motion:
		tween.tween_interval(shudder)
	else:
		tween.tween_property(shaken, "rotation", rest + deg_to_rad(-5.0), shudder * 0.3)
		tween.tween_property(shaken, "rotation", rest + deg_to_rad(5.0), shudder * 0.4)
		tween.tween_property(shaken, "rotation", rest, shudder * 0.3)
	# The grey holds for the rest of the beat.
	tween.tween_interval(maxf(0.0, motion - 0.06 - shudder - recover))
	tween.tween_property(shaken, "modulate", Color.WHITE, recover)
	_fx.fly_text(EffectLink.WASTED_WORD, puff_at, puff_to, Palette.LIGHT_TEXT, 20, 0.55, true)


## The scanner reads a card that is not plain: its beep, and its base value pops up.
func _base(step: ScoreStep) -> void:
	_print_step(step)
	var view: CardView = _views[step.slot]
	sfx.play("scan")
	view.show_badge(step.value_after, true)
	_fx.punch(view.badge, 1.3)


## A plain card in one short beat (D2): the scan beep and note, the base pop, its BASE and
## payout lines, then, a moment later, the payout with its roll.
func _merged(beat: CountUpBeat, base: ScoreStep, payout: ScoreStep) -> void:
	_print_step(base)
	var line: Control = _print_step(payout)
	if line != null:
		line.modulate.a = 0.0
	var view: CardView = _views[base.slot]
	var scan: float = clampf(_motion(beat) - beat.fly_ms / 1000.0, SCAN_MIN, SCAN_MAX)
	sfx.play("scan")
	if beat.note >= 0 and not CountUpPlan.is_landing(beat):
		sfx.play_note(beat.note)
	view.show_badge(base.value_after, true)
	_fx.punch(view.badge, 1.3)
	await _wait(scan)
	_land_payout(beat, payout, line)


## A bonus flies in from the card that caused it, from the upgrade's loyalty-card box or from the
## day event's chip in the top bar (v0.69: Happy hour's +3, Late delivery's −2 in tomato), or
## rises from the card for its own rules.
func _bonus(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var text: String = EffectLinks.token_text(step)
	var color: Color = Palette.MUSTARD if step.value >= 0 else Palette.TOMATO
	if beat.echo:
		_echo(beat, step, text, color)
		return
	# A copy flies in from the copied card; any other bonus from the card or upgrade that
	# caused it, unless it is the target's own rule.
	var source: Control = null
	var from: Vector2 = Vector2.ZERO
	var waited: float = 0.0
	if step.step_type == ScoreStep.StepType.COPY:
		source = _views[step.linked_slot]
		from = _at(step.linked_slot)
	elif step.source_kind != ScoreStep.SourceKind.CARD or step.card_giver_slot() != step.slot:
		source = _source_control(step)
		if source != null:
			from = _source_point(step)
	if source != null:
		_pulse_giver(source)
		if step.step_type == ScoreStep.StepType.COPY:
			sfx.play("copy")
		var flight: float = minf(BONUS_FLIGHT, _motion(beat) * 0.75)
		await _fx.fly_text(text, from, _at(step.slot), color, 30, flight)
		waited = flight
	else:
		var above: Vector2 = _at(step.slot) + Vector2(0, -20)
		_fx.fly_text(text, above, above + Vector2(0, -40), color, 30, OWN_BONUS_RISE, true)
	await _hold_value(beat, waited)
	if beat.note >= 0 and not CountUpPlan.is_landing(beat):
		sfx.play_note(beat.note)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.3)
	landed.call(beat)
	_land_unless_total(beat)


## A multiplier lands like a stamp: big, rotated, slammed down, with a shake. An upgrade's
## factor first flies in from its loyalty-card box, a day event's (v0.69: Free samples' ×2) from
## its chip; an armed effect's stamp punches and lights up the arming card.
func _stamp(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var factor: String = "×%d" % step.value
	if beat.echo:
		_echo(beat, step, factor, Palette.TOMATO)
		return
	var motion: float = _motion(beat)
	var slam_time: float = minf(STAMP_SLAM, motion * 0.6)
	var waited: float = 0.0
	# The upgrade's box, or the day event's chip.
	var upgrade_box: Control = _upgrade_box(step)
	if upgrade_box == null:
		upgrade_box = _inspection_source(step)
	var source: CardView = _source_view(step)
	if upgrade_box != null:
		_pulse_giver(upgrade_box)
		var flight: float = minf(UPGRADE_FLIGHT, motion * 0.45)
		slam_time = minf(STAMP_SLAM, motion * 0.35)
		await _fx.fly_text(factor, _center(upgrade_box), _at(step.slot), Palette.TOMATO, 26, flight)
		waited = flight
	elif source != null and step.source_slot != step.slot:
		_pulse_giver(source)
		_fx.glow(source.body)
	# The slam ends at the value's moment (its start waits for it).
	await _hold_value(beat, waited + slam_time)
	var stamp: Label = CountUpMotion.text_label(factor, Palette.TOMATO, 54)
	_overlay.add_child(stamp)
	stamp.global_position = _at(step.slot) - stamp.size / 2.0
	stamp.pivot_offset = stamp.size / 2.0
	stamp.scale = Vector2(2.6, 2.6)
	stamp.rotation = deg_to_rad(-18.0)
	stamp.modulate.a = 0.0
	var slam: Tween = _tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(stamp, "scale", Vector2.ONE, slam_time)
	slam.tween_property(stamp, "rotation", deg_to_rad(-8.0), slam_time)
	slam.tween_property(stamp, "modulate:a", 1.0, slam_time * 0.6)
	await slam.finished
	if not CountUpPlan.is_landing(beat):
		sfx.play("stamp")
		if beat.note >= 0:
			sfx.play_note(beat.note, CountUp.STAMP_NOTE_DB)
	_fx.shake(target.body, 7.0)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.4)
	landed.call(beat)
	_land_unless_total(beat)
	var fade: Tween = _tween()
	fade.tween_interval(0.2)
	fade.tween_property(stamp, "modulate:a", 0.0, 0.2)
	fade.tween_callback(stamp.queue_free)


## A bonus or stamp's value lands on its item no earlier than the tuning's step_value_at of the
## beat's motion (v3.1: after its monitor line, CountTotalTuning.step_line_at), `waited` seconds
## of it already gone; reduced motion lands it at once.
func _hold_value(beat: CountUpBeat, waited: float) -> void:
	if total_tuning == null or plan.reduced_motion:
		return
	var left: float = total_tuning.step_value_at * _motion(beat) - waited
	if left > 0.0:
		await _wait(left)


## A repeat landing of an armed effect, played short (D7 stage 2): the arming card punches and
## the effect pops on the target; no flight, no slam, no hit-stop.
func _echo(beat: CountUpBeat, step: ScoreStep, text: String, color: Color) -> void:
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	if source != null and step.source_slot != step.slot:
		_fx.punch(source.body, 1.08)
	_fx.pop_text(text, _at(step.slot), color, 34, ECHO_POP)
	var stamped: bool = step.step_type == ScoreStep.StepType.MULTIPLIER
	if stamped:
		sfx.play("stamp", 1.0, CountUp.ECHO_STAMP_DB)
	if beat.note >= 0:
		sfx.play_note(beat.note, CountUp.STAMP_NOTE_DB if stamped else 0.0)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.25)
	landed.call(beat)


## Soup beside Frozen, or an inspection: a hard "denied" as its value is wiped to 0. An
## inspection's tag is punched first, so the 0 visibly comes from it.
func _denied(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var view: CardView = _views[step.slot]
	var inspection: Control = _inspection_source(step)
	if inspection != null:
		_fx.punch(inspection, 1.25)
	var cross: Label = CountUpMotion.text_label("0", Palette.TOMATO, 64)
	_overlay.add_child(cross)
	cross.global_position = _at(step.slot) - cross.size / 2.0
	cross.pivot_offset = cross.size / 2.0
	cross.scale = Vector2(3, 3)
	var tween: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross, "scale", Vector2.ONE, minf(DENIED_LANDING, _motion(beat) * 0.8))
	await tween.finished
	sfx.play("denied")
	_fx.shake(view.body, 10.0)
	view.show_fizzle_badge(step.value_after)
	_land_unless_total(beat)
	var fade: Tween = _tween()
	fade.tween_interval(0.25)
	fade.tween_property(cross, "modulate:a", 0.0, 0.2)
	fade.tween_callback(cross.queue_free)


## A PAYOUT beat (a card that is not plain).
func _payout(beat: CountUpBeat, step: ScoreStep) -> void:
	var line: Control = _print_step(step)
	if line != null:
		line.modulate.a = 0.0
	_land_payout(beat, step, line)


## The payout lands: its receipt line fades in (a payout that prints no line leaves its item's
## lines as they are), the printer sounds at its speed and a big payout rattles the register;
## payout_landed tells the monitor. The total no longer rolls here (#105 piece 2): it counted in
## at the item's landings, and a PAYOUT that moves it lands like one (_land_total).
func _land_payout(beat: CountUpBeat, _step: ScoreStep, line: Control) -> void:
	if line != null:
		if plan.reduced_motion:
			line.modulate.a = 1.0
		else:
			_tween().tween_property(line, "modulate:a", 1.0, CountUp.LINE_FADE)
	sfx.play("print", print_pitch())
	if beat.payout > 0 and beat.rattle_px > 0.0:
		_fx.shake(_rattle_target, beat.rattle_px)
		play_rattle(beat.rattle_px)
	if beat.payout > 0:
		sfx.play("coin", 1.0, -8.0)
	if beat.payout > 0 and payout_landed.is_valid():
		payout_landed.call(beat.payout, beat.shown_to)
	_land_unless_total(beat)


## A beat's hit-stop, now, unless it lands on the total (_land_total plays it after its ticks).
func _land_unless_total(beat: CountUpBeat) -> void:
	if not CountUpPlan.is_landing(beat):
		land.call(beat)


## A landing beat's ticks on the total (see the class comment), fly_ms after the beat starts, on
## the count's tweens.
func _land_total(beat: CountUpBeat) -> void:
	if not CountUpPlan.is_landing(beat) or beat.ticks.is_empty():
		return
	var gap: float = total_tuning.tick_gap_ms / 1000.0 if total_tuning != null else 0.0
	var ticks: Tween = _tween()
	ticks.tween_interval(beat.fly_ms / 1000.0)
	for tick: int in range(beat.ticks.size()):
		if tick > 0:
			ticks.tween_interval(gap)
		ticks.tween_callback(_tick.bind(beat, tick))


## Tick `tick` of `beat`'s landing: the total and the tick sound in one callback; the first also
## sounds the note (a ×'s stamp too), tells the monitor and plays the beat's hit-stop; on the ding
## beat the crossing tick (ding_tick: the first at or over the quota, the first one under reduced
## motion, where the total jumps) meets the quota, as the mock-up's climax starts on it, and plays
## the hit-stop (the ding's hold) instead.
func _tick(beat: CountUpBeat, tick: int) -> void:
	if not plan.reduced_motion:
		set_total.call(beat.ticks[tick])
	elif tick == 0:
		set_total.call(beat.shown_to)
	sfx.play("tick", 1.0, total_tuning.tick_db if total_tuning != null else CountUp.TICK_DB)
	if tick == 0:
		if not beat.echo:
			var stamped: bool = beat.land == CountUpBeat.Land.MUL
			if stamped:
				sfx.play("stamp")
			if beat.note >= 0:
				sfx.play_note(beat.note, CountUp.STAMP_NOTE_DB if stamped else 0.0)
		if landing.is_valid():
			landing.call(beat)
	var crossing: int = 0 if plan.reduced_motion else maxi(0, beat.ding_tick)
	if beat.ding and tick == crossing:
		meet_quota.call(true)
	# The hit-stop freezes the landing on its impact (the number punched): the first tick, the
	# ding beat's crossing tick (the ding's hold).
	if tick == (crossing if beat.ding else 0):
		land.call(beat)


## An armed effect (Eggs' charges, Coffee, Multipack): the card glows and pulses and the current
## note replays quietly (D8, D9; the belt ride sends its sparks to the targets). An effect with no
## landing shows its name floating up. Its receipt line ("arms ×3 …") prints.
func _armed(beat: CountUpBeat, step: ScoreStep) -> void:
	var view: CardView = _views[step.slot]
	_print_step(step)
	_fx.punch(view.body, 1.08)
	_fx.glow(view.body)
	sfx.play("armed")
	if beat.note >= 0:
		sfx.play_note(beat.note, CountUp.ARMED_NOTE_DB)
	if beat.targets.is_empty():
		var start: Vector2 = _at(step.slot) + Vector2(0, -40)
		_fx.fly_text(step.text, start, start + Vector2(0, -36), Palette.MUSTARD, 18, 0.45, true)


## Prints a step's receipt line (or null: add_step), for every step, and keeps it as its slot's
## last line.
func _print_step(step: ScoreStep) -> Control:
	var line: Control = _receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	if line != null:
		_last_lines[step.slot] = line
	return line


## Where item `slot` is now (global): CountUp.source_rect's rect for it (the scanner, or the
## bag's mouth once bagged), else a point at its view's centre.
func _rect_of(slot: int) -> Rect2:
	if _count.source_rect.is_valid():
		return _count.source_rect.call(slot) as Rect2
	return Rect2(_views[slot].center(), Vector2.ZERO)


func _at(slot: int) -> Vector2:
	return _rect_of(slot).get_center()


## Where a step's source is on screen: its upgrade's box, its inspection's tag, or its card
## where it is now.
func _source_point(step: ScoreStep) -> Vector2:
	if _upgrade_box(step) == null and _inspection_source(step) == null:
		return _at(step.card_giver_slot())
	return _center(_source_control(step))


## The card that caused a step, or null when its source is not a card (an upgrade or an
## inspection, full build): source_slot is only read for CARD sources (plan section 4).
func _source_view(step: ScoreStep) -> CardView:
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return null
	return _views[step.card_giver_slot()]


## The loyalty-card box of the upgrade that caused a step, or null when the step's source is
## not an upgrade (or its box is missing): source_index is only read for UPGRADE sources.
func _upgrade_box(step: ScoreStep) -> Control:
	if step.source_kind != ScoreStep.SourceKind.UPGRADE:
		return null
	if step.source_index < 0 or step.source_index >= _upgrade_boxes.size():
		return null
	return _upgrade_boxes[step.source_index]


## Where the inspection that caused a step is shown, or null when the step's source is not an
## inspection (or nothing shows it): source_index is only read for INSPECTION sources.
func _inspection_source(step: ScoreStep) -> Control:
	if step.source_kind != ScoreStep.SourceKind.INSPECTION:
		return null
	if step.source_index < 0 or step.source_index >= _inspection_sources.size():
		return null
	return _inspection_sources[step.source_index]


## Where a step comes from on screen: its card, its upgrade's loyalty-card box, or its
## inspection's tag.
func _source_control(step: ScoreStep) -> Control:
	var upgrade_box: Control = _upgrade_box(step)
	if upgrade_box != null:
		return upgrade_box
	var inspection: Control = _inspection_source(step)
	return inspection if inspection != null else _source_view(step)


func _wait(seconds: float) -> void:
	var tween: Tween = _tween()
	tween.tween_interval(seconds)
	await tween.finished


func _tween() -> Tween:
	return _make_tween.call() as Tween


## The part of a source that is punched: a card's body (its layout box stays still), or the
## whole loyalty-card box.
static func _moving_part(source: Control) -> Control:
	var view: CardView = source as CardView
	return view.body if view != null else source


static func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## Live belt givers hop; loyalty boxes flip. Bagged givers are represented on the monitor.
func _pulse_giver(source: Control) -> void:
	if plan.reduced_motion or not source.is_visible_in_tree():
		return
	var moving: Control = _moving_part(source)
	var tween: Tween = _tween()
	if source is CardView:
		var rest: Vector2 = moving.position
		tween.tween_property(moving, "position", rest - Vector2(0, 8), 0.08)
		tween.tween_property(moving, "position", rest, 0.12)
	else:
		var rest: Vector2 = moving.scale
		moving.pivot_offset = moving.size / 2.0
		tween.tween_property(moving, "scale:x", 0.0, 0.08)
		tween.tween_property(moving, "scale", rest, 0.16)
