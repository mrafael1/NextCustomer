class_name CountUp
extends Node
## Plays a ScoreResult back step by step: the "counting points feels good" moment (plan
## sections 1 and 6, full build plan 6.2). Everything comes from the steps, never from rules.
##
## It plays a CountUpPlan (#60): the plan, built from the steps, the quota, a CountUpContext
## and the CountUpTuning in data/balance/count_up.tres, decides every beat's kind, note,
## length, hit-stop, roll and rattle; the count-up starts each beat's motion and sound and waits
## the beat's length (start to start), so the next beat starts on time while long fades
## overlap it. Inside a beat, the motion is fitted to the beat's length.
##
## The beats: a plain card's scan lift, beep, note, base pop and payout drop in one short beat;
## bonuses flying in from the card (or upgrade box) that caused them; multiplier stamps;
## copies; Soup's and the inspections' "denied"; sticker and Bundle moments; an armed effect's
## tokens flying from its card to every card it will land on, where they wait as dimmed
## EffectMarkers until their landing absorbs them (the arming card keeps a pip while any token
## waits, greyed for good when the effect fizzles); fizzle puffs; a receipt printer that runs
## faster as the run goes on, with three ticks per payout roll; a register rattle on big
## payouts; a PaperPile that grows with every line; the quota ding with a lasting "QUOTA" chip;
## then a held breath (longer and rattling for a large total) and the TOTAL line.
## Then the dessert (#61, CountUpDessert): the slam onto the TOTAL line, the margin, PAID, the
## tear and the next shift's notice; a passed shift's ends at the printer feed (`printer_feed`),
## where the reward print-out takes over.
##
## Sound (D1, #62): gain beats climb the plan's note ladder (Sfx.play_note), an armed beat
## replays the current note quietly over its shimmer (`armed`) and a stamp plays its sample (3
## takes in turn) with the note under it. Nothing follows the subtotal. A payout's register
## rattle sounds with its shake, its take and volume following the shake's pixels (rattle_s,
## rattle_m, rattle_l); a large total rattles through the pause, and a huge one rings the
## register bell too. The next-shift notice prints with the printer's feed, then the light
## clerk's stamp (stamp_notice). A fail holds the count-up until its fail sound has rung out and
## the receipt has torn. The music ducks (#62, Q6) as the pause before the total starts, so the
## slam lands in near-silence; the shift screen brings it back at the printer feed, or
## crossfades to the results.
##
## Time (D6): every beat length runs at _speed(), the fastest of the taps' skip, a hold's
## fast-forward and the plan's base_speed (the auto speed-up times the speed setting). Hit-stops
## freeze only the count-up's own tweens (_live) for real milliseconds, measured in _process
## (never a tween, never Engine.time_scale); they and the pause before the total are never sped
## up by base_speed, only by a tap or a hold. After the verdict, the dessert runs at the speed
## setting alone (Fast's x1.5, never the auto speed-up).
##
## Respecting the player (full build plan 6.2): a press of Space or the mouse (anywhere except on
## a button that can be pressed) released before HOLD_THRESHOLD_MS is a tap. The first tap speeds
## the count to the verdict (the final total shown) at TAP_SKIP; what follows it (the dessert)
## then plays at its own speed, unless a second tap (or a first one
## after the verdict) skips it at DESSERT_SKIP. A press held past the threshold fast-forwards at
## FAST_FORWARD while held. The fastest of these wins. Skips only speed tweens up, never kill
## them, so every line, sound and shake still happens and the receipt ends up the same. A
## PressReader child reads the presses from the input events (a press and release within one
## frame is still a tap). The checkout click is ignored (a press still held at the start is
## ignored up to its release), so is the second click of a double-click on it (CHECKOUT fires on
## the first click's release), and a tap after the count-up does nothing. Reduced motion (the
## context's) removes every shake and rattle and the pile's bounce, and markers fade in instead
## of flying; the dessert's slam fades in at full size, unshaken.
##
## Steps caused by an upgrade (source_kind UPGRADE) come from that upgrade's loyalty-card box:
## bonuses and multipliers fly in from it, and its fizzles puff out of it. Steps caused by an
## inspection (source_kind INSPECTION, plan section 3.9) come from its tag in the top bar: it is
## punched as its "0" lands. On a passed shift followed by an inspected one, the notice prints in
## red under the dessert's tear.

## The dessert of a passed shift reached the printer feed (#61): the reward print-out starts
## here. play() returns right after it.
signal printer_feed
signal finished

## A hold's speed, from HOLD_THRESHOLD_MS on.
const FAST_FORWARD := 5.0
## A press released before this (in ms of Time.get_ticks_msec()) is a tap; one held this long is
## a hold (PressReader's).
const HOLD_THRESHOLD_MS := PressReader.HOLD_THRESHOLD_MS
## The speed after the first tap, up to the verdict.
const TAP_SKIP := 12.0
## The speed of everything left after a tap that skips the dessert.
const DESSERT_SKIP := 30.0
## A double-click's second press this soon (in ms) after the count-up started is the end of the
## checkout click's double-click, not a tap. Later ones are real taps (the second of two quick
## taps is a double-click too, and still skips the dessert). PressReader's.
const CHECKOUT_DOUBLE_CLICK_MS := PressReader.CHECKOUT_DOUBLE_CLICK_MS
## The count-up's tuning, unless setup() is given another.
const TUNING_PATH := "res://data/balance/count_up.tres"
## The tick plays this many times per payout roll, evenly spaced from its start (D1).
const TICKS_PER_ROLL := 3
const TICK_DB := -8.0
## An armed beat replays the current note this quietly (D1).
const ARMED_NOTE_DB := -10.0
## The note under a stamp's sample (D1).
const STAMP_NOTE_DB := -6.0
## An echo's stamp sample, softer than a full stamp.
const ECHO_STAMP_DB := -8.0
## The register rattle's sound (#62): a rattle of RATTLE_MEDIUM_PX pixels or more plays
## rattle_m, RATTLE_LARGE_PX or more rattle_l, anything less rattle_s; its volume climbs from
## RATTLE_QUIET_DB to 0 dB at RATTLE_FULL_PX.
const RATTLE_MEDIUM_PX := 6.0
const RATTLE_LARGE_PX := 10.0
const RATTLE_FULL_PX := 12.0
const RATTLE_QUIET_DB := -10.0
## Motion lengths at speed 1, in seconds, each the longest it gets: a beat shorter than its
## motion shortens it (see _motion).
const SCAN_LIFT_TIME := 0.18
const MERGED_LIFT_MIN := 0.05
const MERGED_LIFT_MAX := 0.1
const DROP_MIN := 0.08
const DROP_MAX := 0.16
const LINE_FADE := 0.15
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
## The quota chip pops in from this scale (D5) over QUOTA_CHIP_SETTLE.
const QUOTA_CHIP_POP := 1.4
const QUOTA_CHIP_SETTLE := 0.2
## The subtotal's punch on the TOTAL line (D11).
const TOTAL_PUNCH := 1.5
## A payout's subtotal punch: SUBTOTAL_PUNCH plus up to SUBTOTAL_PUNCH_MAX for bigger payouts.
const SUBTOTAL_PUNCH := 1.1
const SUBTOTAL_PUNCH_MAX := 0.5
## The pile's settle bounce: squashed this tall, back over PILE_SETTLE_TIME (D4: 80 ms).
const PILE_SETTLE := 1.06
const PILE_SETTLE_TIME := 0.08
## The dessert ducks the music (#62, Q6, #61): this far, over DUCK_ATTACK_S, as the pause before
## the total starts, so the slam lands in near-silence. A tap that skips the dessert brings the
## music back over SKIP_UNDUCK_S.
const DESSERT_DUCK_DB := -24.0
const DUCK_ATTACK_S := 0.12
const SKIP_UNDUCK_S := 0.15

## A hold past HOLD_THRESHOLD_MS sped this count-up up (plan 8's fast-forward used).
var fast_forward_used: bool = false
## Time.get_ticks_msec() when the final total was shown (plan 8: count-up time ends there).
var total_shown_ms: int = 0
## Time.get_ticks_msec() of this count-up's first tap, or -1 for none (plan 8's skip_at_ms).
var first_tap_ms: int = -1
## A tap skipped the dessert: a second tap, or a first one after the verdict.
var dessert_skipped: bool = false
## The plan being played (or last played), built by play().
var plan: CountUpPlan
## The Music autoload the dessert ducks (#62), or null for none (the shift screen sets it).
var music: MusicService
## How big the ending was, for what follows the total (#61). Set when the total is shown; null
## before that.
var intensity: CountUpIntensity
## The shift's margin against its quota (#61), set when the dessert starts; null before that.
var margin: ShiftMargin
## Time.get_ticks_msec() of the printer feed (a passed shift's dessert ending), -1 before it or
## on a miss.
var printer_feed_ms: int = -1
var _tuning: CountUpTuning
var _overlay: Control
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
var _receipt: ReceiptView
## The register's LED: the running subtotal, then the total.
var _led: LedDisplay
## The quota is met (the ding beat, or the TOTAL line): the LED's subtotal shows green.
var _met: bool = false
var _sfx: Sfx
## Shaken on big payouts and before a large total (the register rattle).
var _rattle_target: Control
## Grows with the receipt's lines, or null.
var _pile: PaperPile
var _lines_printed: int = 0
var _shown_subtotal: int = 0
## The subtotal's running roll and where it ends.
var _roll: Tween
var _roll_to: int = 0
var _playing: bool = false
## Reads the taps and holds while the count-up plays.
var _presses: PressReader
## A tap has sped the count up (to the verdict, unless it skipped the dessert).
var _tapped: bool = false
## The final total is shown: what follows is the dessert.
var _verdict_shown: bool = false
## This count-up ducked the music and hasn't brought it back.
var _ducked: bool = false
## Running tweens: their speed follows fast-forward every frame, not only when they start.
var _live: Array[Tween] = []
## Real ms left of the running hit-stop (D6), counted down in _process.
var _hit_stop_left_ms: float = 0.0
## Time.get_ticks_usec() of the last hit-stop count.
var _hit_stop_us: int = 0
## Punches, shakes, lifts and flying labels, on this count-up's tweens.
var _fx: CountUpMotion
## What follows the verdict (#61), on this count-up's tweens.
var _dessert: CountUpDessert
## The armed effects' tokens, markers and pips of the row being played, or null.
var _tokens: EffectTokens
## The lasting "QUOTA" chip on the LED's quota line, or null.
var _quota_chip: QuotaChip


func _init() -> void:
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(_tap)


## `rattle_target` is shaken by the register rattle; `pile` (optional) grows with the receipt;
## `tuning` defaults to TUNING_PATH.
func setup(
	overlay: Control,
	receipt: ReceiptView,
	led: LedDisplay,
	sfx: Sfx,
	rattle_target: Control,
	pile: PaperPile = null,
	tuning: CountUpTuning = null
) -> void:
	_overlay = overlay
	_fx = CountUpMotion.new(overlay, _tween)
	_receipt = receipt
	_led = led
	_sfx = sfx
	_rattle_target = rattle_target
	_pile = pile
	_tuning = tuning if tuning != null else load(TUNING_PATH) as CountUpTuning
	_dessert = CountUpDessert.new(overlay, receipt, sfx, _fx, rattle_target, _tween)


## Plays `result` on the row's card views. `context` is the run around the row (shift, best so
## far, speed setting, reduced motion); `quota` only places the ding and the chip.
func play(
	result: ScoreResult,
	views: Array[CardView],
	names: PackedStringArray,
	quota: int,
	context: CountUpContext,
	upgrade_boxes: Array[Control] = [],
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_sources: Array[Control] = [],
	inspection_names: PackedStringArray = PackedStringArray(),
	notice: String = ""
) -> void:
	if _tuning == null:
		_tuning = load(TUNING_PATH) as CountUpTuning
	_views = views
	_names = names
	_steps = result.steps
	_upgrade_boxes = upgrade_boxes
	_upgrade_names = upgrade_names
	_inspection_sources = inspection_sources
	_inspection_names = inspection_names
	plan = CountUpPlan.build(result.steps, quota, context, _tuning)
	intensity = null
	margin = null
	printer_feed_ms = -1
	_fx.reset(plan.reduced_motion)
	_clear_row()
	_led.start_count(quota)
	_tokens = EffectTokens.new(_overlay, plan, _steps, _views, _names, _tween)
	_shown_subtotal = 0
	_roll = null
	_lines_printed = 0
	_hit_stop_left_ms = 0.0
	fast_forward_used = false
	first_tap_ms = -1
	dessert_skipped = false
	_tapped = false
	_verdict_shown = false
	_ducked = false
	_presses.begin()
	_playing = true
	_receipt.clear()
	_set_subtotal(0.0)
	_start_pile(plan.pile_start_px)
	for view: CardView in _views:
		view.reset_motion()
		view.hide_badge()
	await _wait_ms(plan.pre_roll_ms)
	for index: int in range(plan.beats.size()):
		_play_beat(index)
		await _wait_ms(plan.beats[index].duration_ms)
	_tokens.dissolve()
	_duck_for_dessert()
	await _pause()
	_finish_roll()
	_print_line(_receipt.add_total(result.total))
	_sfx.play("print", _print_pitch())
	_led.show_total()
	_fx.punch(_led.digits_label(), TOTAL_PUNCH)
	if plan.chip_at_total:
		_quota_met(false)
	total_shown_ms = Time.get_ticks_msec()
	intensity = CountUpIntensity.from_plan(plan)
	_verdict_shown = true
	margin = ShiftMargin.of(result.total, quota)
	# The dessert plays the count-up's own Sfx (a test may swap it after setup()).
	_dessert.sfx = _sfx
	_dessert.speed_setting = plan.speed_setting
	await _dessert.play(
		result.total, quota, notice, _tuning, intensity, plan.reduced_motion, _print_pitch()
	)
	if margin.passed():
		printer_feed_ms = Time.get_ticks_msec()
		printer_feed.emit()
	_playing = false
	_presses.end()
	finished.emit()


## Shows the paper pile of 1-based `shift` before its row prints (D4: the earlier shifts' paper),
## flat and tidy. Called when a shift or a run starts, so the checkout never shrinks the pile.
func show_pile_for_shift(shift: int) -> void:
	_start_pile(CountUpPlan.pile_start_for(shift, _tuning))


## A checkout's end state without playing it, for a run resumed after its checkout: the subtotal
## at the total, green with the lasting QuotaChip when the quota is met (D5), and the paper pile
## as the count-up leaves it, curled after a large total (D4). Sets `plan` and `intensity`; the
## receipt is the caller's (ReceiptView.show_result).
func show_end_state(result: ScoreResult, quota: int, context: CountUpContext) -> void:
	plan = CountUpPlan.build(result.steps, quota, context, _tuning)
	intensity = CountUpIntensity.from_plan(plan)
	_clear_row()
	_led.start_count(quota)
	_set_subtotal(result.total)
	_led.show_total()
	if plan.quota_reached:
		_show_chip(false)
	_start_pile(plan.pile_start_px)
	if _pile != null:
		var lines: int = _printed_lines(result.steps)
		_pile.set_height(plan.pile_start_px + _tuning.pile_px_per_line * lines)
		if plan.size != CountUpPlan.Size.NORMAL:
			_pile.curl(plan.size == CountUpPlan.Size.HUGE)


func _process(_delta: float) -> void:
	if _hit_stop_left_ms > 0.0:
		var now: int = Time.get_ticks_usec()
		_hit_stop_left_ms -= (now - _hit_stop_us) / 1000.0 * _press_speed()
		_hit_stop_us = now
	_apply_speed()
	if _playing and _presses.is_holding() and FAST_FORWARD > _skip_speed() and not _live.is_empty():
		fast_forward_used = true


## Sets every running tween's speed to _speed() and forgets the finished ones.
func _apply_speed() -> void:
	var speed: float = _speed()
	var live: Array[Tween] = []
	for tween: Tween in _live:
		if tween.is_valid() and tween.is_running():
			tween.set_speed_scale(speed)
			live.append(tween)
	_live = live


## The first tap speeds the count to the verdict; a second one, or one after the verdict, skips
## the dessert too.
func _tap(now: int) -> void:
	if first_tap_ms < 0:
		first_tap_ms = now
	if _tapped or _verdict_shown:
		dessert_skipped = true
		if _ducked:
			_ducked = false
			music.unduck(SKIP_UNDUCK_S)
	_tapped = true


## Starts beat `index`'s motion and sound; play() waits its length.
func _play_beat(index: int) -> void:
	var beat: CountUpBeat = plan.beats[index]
	var step: ScoreStep = _steps[beat.steps[0]]
	match beat.kind:
		CountUpBeat.Kind.MERGED_PLAIN:
			_merged(beat, step, _steps[beat.steps[1]])
		CountUpBeat.Kind.BASE:
			_base(beat, step)
		CountUpBeat.Kind.BONUS:
			_bonus(index, beat, step)
		CountUpBeat.Kind.STAMP:
			_stamp(index, beat, step)
		CountUpBeat.Kind.DENIED:
			_denied(beat, step)
		CountUpBeat.Kind.PAYOUT:
			_payout(beat, step)
		CountUpBeat.Kind.ARMED:
			_armed(index, beat, step)
		CountUpBeat.Kind.FIZZLE:
			_fizzle(index, beat, step)
		CountUpBeat.Kind.TAG:
			_tag_added(beat, step)
		CountUpBeat.Kind.LINK:
			_linked(beat, step)


## How long a beat's motion may take at speed 1, in seconds: its length without the shortest
## trailing gap.
func _motion(beat: CountUpBeat) -> float:
	return maxf(MERGED_LIFT_MIN, (beat.duration_ms - _tuning.fit_gap_ms) / 1000.0)


func _tag_added(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	if source == null:
		source = target
	_fx.punch(source.body, 1.1)
	var flight: float = minf(TAG_FLIGHT, _motion(beat) * 0.7)
	await _fx.fly_text(
		"+" + step.tag, source.center(), target.center(), Palette.LIGHT_TEXT, 24, flight
	)
	_sfx.play("tag")
	target.add_tag(step.tag)
	_fx.punch(target.body, 1.15)


func _linked(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var left: CardView = _views[step.slot]
	var right: CardView = _views[step.linked_slot]
	var line: Line2D = Line2D.new()
	line.width = 10.0
	line.default_color = Palette.TEAL
	line.add_point(left.center() - _overlay.global_position)
	line.add_point(right.center() - _overlay.global_position)
	_overlay.add_child(line)
	_sfx.play("link")
	var shrink: float = minf(LINK_SHRINK, _motion(beat) * 0.8)
	# A coupon's link punches the coupon. An upgrade's (Rule bender) comes out of its
	# loyalty-card box: its name flies to the link, so the player sees what joined the cards.
	var source: Control = _source_control(step)
	if source != null:
		_fx.punch(_moving_part(source), 1.15)
	var box: Control = _upgrade_box(step)
	if box != null:
		var middle: Vector2 = (left.center() + right.center()) / 2.0
		_fx.fly_text(step.text, _center(box), middle, Palette.TEAL, 20, shrink, true)
	_fx.punch(left.body, 1.12)
	_fx.punch(right.body, 1.12)
	var tween: Tween = _tween()
	tween.tween_property(line, "width", 3.0, shrink)
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)


## A fizzle: the card shudders, greys out for a moment, and lets out a little puff. An
## upgrade's fizzle comes out of its loyalty-card box instead (the card it had nothing to work
## on gives a small nudge). An armed effect's fizzle greys its pip for good.
func _fizzle(index: int, beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var view: CardView = _views[step.slot]
	var shaken: Control = view.body
	var puff_at: Vector2 = view.center() + Vector2(0, -30)
	var puff_to: Vector2 = puff_at + Vector2(0, -50)
	var upgrade_box: Control = _upgrade_box(step)
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
			"reset", resetter.center(), view.center(), Palette.LIGHT_TEXT, 20, flight
		)
	_sfx.play("fizzle")
	_tokens.spend(index, step)
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
	_fx.fly_text("pfff…", puff_at, puff_to, Palette.LIGHT_TEXT, 20, 0.55, true)


## The scanner on a card that is not plain: the card lifts and its base value pops up.
func _base(beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var view: CardView = _views[step.slot]
	_fx.lift(view, minf(SCAN_LIFT_TIME, _motion(beat)))
	_sfx.play("scan")
	view.show_badge(step.value_after, true)
	_fx.punch(view.badge, 1.3)


## A plain card in one short beat (D2): the scan lift with its beep and note, the base pop, its
## BASE and payout lines, then the drop with the payout's roll.
func _merged(beat: CountUpBeat, base: ScoreStep, payout: ScoreStep) -> void:
	_print_step(base)
	var line: Control = _print_step(payout)
	if line != null:
		line.modulate.a = 0.0
	var view: CardView = _views[base.slot]
	var lift: float = clampf(
		_motion(beat) - beat.roll_ms / 1000.0, MERGED_LIFT_MIN, MERGED_LIFT_MAX
	)
	_fx.lift(view, lift)
	_sfx.play("scan")
	if beat.note >= 0:
		_sfx.play_note(beat.note)
	view.show_badge(base.value_after, true)
	_fx.punch(view.badge, 1.3)
	await _wait(lift)
	_land_payout(beat, payout, line)


## A bonus flies in from the card that caused it, or from the upgrade's loyalty-card box (or
## rises from the card for its own rules). An armed effect's bonus flies from the arming card
## and absorbs its marker.
func _bonus(index: int, beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var text: String = "+%d" % step.value
	if beat.echo:
		_echo(index, beat, step, text, Palette.MUSTARD)
		return
	# A copy flies in from the copied card; any other bonus from the card or upgrade that
	# caused it, unless it is the target's own rule.
	var source: Control = null
	if step.step_type == ScoreStep.StepType.COPY:
		source = _views[step.linked_slot]
	elif step.source_kind == ScoreStep.SourceKind.UPGRADE or step.source_slot != step.slot:
		source = _source_control(step)
	if source != null:
		_fx.punch(_moving_part(source), 1.1)
		if step.step_type == ScoreStep.StepType.COPY:
			_sfx.play("copy")
		var flight: float = minf(BONUS_FLIGHT, _motion(beat) * 0.75)
		await _fx.fly_text(text, _center(source), target.center(), Palette.MUSTARD, 30, flight)
	else:
		var above: Vector2 = target.center() + Vector2(0, -20)
		_fx.fly_text(
			text, above, above + Vector2(0, -40), Palette.MUSTARD, 30, OWN_BONUS_RISE, true
		)
	if beat.note >= 0:
		_sfx.play_note(beat.note)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.3)
	_tokens.land(index)
	_land(beat)


## A multiplier lands like a stamp: big, rotated, slammed down, with a shake. An upgrade's
## factor first flies in from its loyalty-card box; an armed effect's stamp punches and lights
## up the arming card and absorbs its marker.
func _stamp(index: int, beat: CountUpBeat, step: ScoreStep) -> void:
	_print_step(step)
	var target: CardView = _views[step.slot]
	var factor: String = "×%d" % step.value
	if beat.echo:
		_echo(index, beat, step, factor, Palette.TOMATO)
		return
	var motion: float = _motion(beat)
	var slam_time: float = minf(STAMP_SLAM, motion * 0.6)
	var upgrade_box: Control = _upgrade_box(step)
	var source: CardView = _source_view(step)
	if upgrade_box != null:
		_fx.punch(upgrade_box, 1.3)
		var flight: float = minf(UPGRADE_FLIGHT, motion * 0.45)
		slam_time = minf(STAMP_SLAM, motion * 0.35)
		await _fx.fly_text(
			factor, _center(upgrade_box), target.center(), Palette.TOMATO, 26, flight
		)
	elif source != null and step.source_slot != step.slot:
		_fx.punch(source.body, 1.12)
		_fx.glow(source.body)
	var stamp: Label = CountUpMotion.text_label(factor, Palette.TOMATO, 54)
	_overlay.add_child(stamp)
	stamp.global_position = target.center() - stamp.size / 2.0
	stamp.pivot_offset = stamp.size / 2.0
	stamp.scale = Vector2(2.6, 2.6)
	stamp.rotation = deg_to_rad(-18.0)
	stamp.modulate.a = 0.0
	var slam: Tween = _tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(stamp, "scale", Vector2.ONE, slam_time)
	slam.tween_property(stamp, "rotation", deg_to_rad(-8.0), slam_time)
	slam.tween_property(stamp, "modulate:a", 1.0, slam_time * 0.6)
	await slam.finished
	_sfx.play("stamp")
	if beat.note >= 0:
		_sfx.play_note(beat.note, STAMP_NOTE_DB)
	_fx.shake(target.body, 7.0)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.4)
	_tokens.land(index)
	_land(beat)
	var fade: Tween = _tween()
	fade.tween_interval(0.2)
	fade.tween_property(stamp, "modulate:a", 0.0, 0.2)
	fade.tween_callback(stamp.queue_free)


## A repeat landing of an armed effect, played short (D7 stage 2): the arming card punches, the
## effect pops on the target and its marker is absorbed; no flight, no slam, no hit-stop.
func _echo(index: int, beat: CountUpBeat, step: ScoreStep, text: String, color: Color) -> void:
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	if source != null and step.source_slot != step.slot:
		_fx.punch(source.body, 1.08)
	_fx.pop_text(text, target.center(), color, 34, ECHO_POP)
	var stamped: bool = step.step_type == ScoreStep.StepType.MULTIPLIER
	if stamped:
		_sfx.play("stamp", 1.0, ECHO_STAMP_DB)
	if beat.note >= 0:
		_sfx.play_note(beat.note, STAMP_NOTE_DB if stamped else 0.0)
	target.show_badge(step.value_after, true)
	_fx.punch(target.badge, 1.25)
	_tokens.land(index)


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
	cross.global_position = view.center() - cross.size / 2.0
	cross.pivot_offset = cross.size / 2.0
	cross.scale = Vector2(3, 3)
	var tween: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross, "scale", Vector2.ONE, minf(DENIED_LANDING, _motion(beat) * 0.8))
	await tween.finished
	_sfx.play("denied")
	_fx.shake(view.body, 10.0)
	view.show_fizzle_badge(step.value_after)
	_land(beat)
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


## The payout drops onto the receipt and the subtotal rolls up over the beat's roll with three
## ticks, the printer sounding at its speed; a big payout rattles the register. The ding beat
## meets the quota as its roll ends.
func _land_payout(beat: CountUpBeat, step: ScoreStep, line: Control) -> void:
	var view: CardView = _views[step.slot]
	if line != null:
		_tween().tween_property(line, "modulate:a", 1.0, LINE_FADE)
	var roll: float = beat.roll_ms / 1000.0
	var fall: float = clampf(roll, DROP_MIN, DROP_MAX)
	_fx.drop(view, fall)
	_sfx.play("print", _print_pitch())
	if beat.payout > 0 and roll > 0.0:
		_ticks(roll)
		_fx.punch(
			_led.digits_label(),
			SUBTOTAL_PUNCH + minf(beat.payout / 25.0, SUBTOTAL_PUNCH_MAX) + beat.punch_boost
		)
		if beat.rattle_px > 0.0:
			_fx.shake(_rattle_target, beat.rattle_px)
			_play_rattle(beat.rattle_px)
	_roll_subtotal(step.subtotal, roll)
	if roll > 0.0:
		await _wait(roll)
	if beat.ding:
		_quota_met(true)
	_land(beat)


## An armed effect (Eggs' charges, Coffee, Multipack): the card glows and pulses, the current
## note replays quietly, and one token per landing flies to its target card, where it waits as
## a dimmed marker (D8, D9); the card keeps a pip while any token waits. An effect with no
## landing shows its name floating up. No receipt line.
func _armed(index: int, beat: CountUpBeat, step: ScoreStep) -> void:
	var view: CardView = _views[step.slot]
	_fx.punch(view.body, 1.08)
	_fx.glow(view.body)
	_sfx.play("armed")
	if beat.note >= 0:
		_sfx.play_note(beat.note, ARMED_NOTE_DB)
	if beat.targets.is_empty():
		var start: Vector2 = view.center() + Vector2(0, -40)
		_fx.fly_text(step.text, start, start + Vector2(0, -36), Palette.MUSTARD, 18, 0.45, true)
		return
	_tokens.arm(index)


## The quota is met (D5): the subtotal turns green and the lasting QuotaChip pops in on the
## LED's quota line. Mid-row (`with_ding`) the ding sounds; the beat's hit-stop follows.
func _quota_met(with_ding: bool) -> void:
	if with_ding:
		_sfx.play("ding")
	_show_chip(true)


## The subtotal turns green and the QuotaChip appears on the LED's quota line, popping in (1.4
## to 1) with `pop`.
func _show_chip(pop: bool) -> void:
	_met = true
	_led.show_subtotal(_shown_subtotal, true)
	_quota_chip = QuotaChip.new()
	_overlay.add_child(_quota_chip)
	_quota_chip.follow_anchor(_led.quota_anchor, _led.quota_text_width)
	if not pop:
		return
	_quota_chip.scale = Vector2(QUOTA_CHIP_POP, QUOTA_CHIP_POP)
	var settle: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(_quota_chip, "scale", Vector2.ONE, QUOTA_CHIP_SETTLE)


## Clears the last row's tokens, markers, pips and chip, and gives the subtotal its own colour.
func _clear_row() -> void:
	if _tokens != null:
		_tokens.clear()
		_tokens = null
	if _quota_chip != null and is_instance_valid(_quota_chip):
		_quota_chip.queue_free()
	_quota_chip = null
	_met = false
	_led.reset_colour()


## The pile starts a row at `start_px`, flat, tidy and unsquashed.
func _start_pile(start_px: float) -> void:
	if _pile == null:
		return
	_pile.scale = Vector2.ONE
	_pile.start(start_px, _tuning.pile_cap_px)


## The held breath before the TOTAL line (D4): pause_ms of real time, sped up only by a tap or
## a hold. The printer is silent; a large total rattles the register and curls the pile (a huge
## one also spills a strip and rings the register bell). The rattle and the bell sound under
## reduced motion too: only the shake goes.
func _pause() -> void:
	if plan.size != CountUpPlan.Size.NORMAL:
		var huge: bool = plan.size == CountUpPlan.Size.HUGE
		if huge:
			_sfx.play("register_bell")
		_play_rattle(_tuning.final_rattle_huge_px if huge else _tuning.final_rattle_large_px)
	if plan.final_rattle_px > 0.0:
		# The rattle fills the pause: the pause runs in real time (sped up only by a tap or a
		# hold), the shake's tween at _speed() (base_speed included), so it gets that many more
		# swings. A hit-stop freezes both alike.
		var tween_speed: float = maxf(_press_speed(), plan.base_speed)
		var seconds: float = plan.pause_ms / 1000.0 * tween_speed / _press_speed()
		var swings: int = maxi(
			4, ceili((seconds - CountUpMotion.SHAKE_SETTLE) / CountUpMotion.SHAKE_SWING)
		)
		_fx.shake(_rattle_target, plan.final_rattle_px, swings)
	if _pile != null and plan.size != CountUpPlan.Size.NORMAL:
		_pile.curl(plan.size == CountUpPlan.Size.HUGE)
	var left: float = plan.pause_ms
	var last: int = Time.get_ticks_usec()
	while left > 0.0:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		if _hit_stop_left_ms <= 0.0:
			left -= (now - last) / 1000.0 * _press_speed()
		last = now


## A beat lands: its hit-stop (D6) freezes the count-up's tweens for real milliseconds.
func _land(beat: CountUpBeat) -> void:
	if beat.hit_stop_ms <= 0:
		return
	_hit_stop_left_ms = maxf(_hit_stop_left_ms, beat.hit_stop_ms)
	_hit_stop_us = Time.get_ticks_usec()
	_apply_speed()


## The register rattle's sound for a rattle of `px` pixels: rattle_s, rattle_m or rattle_l,
## louder for a stronger rattle.
func _play_rattle(px: float) -> void:
	var take: String = "rattle_s"
	if px >= RATTLE_LARGE_PX:
		take = "rattle_l"
	elif px >= RATTLE_MEDIUM_PX:
		take = "rattle_m"
	_sfx.play(take, 1.0, lerpf(RATTLE_QUIET_DB, 0.0, clampf(px / RATTLE_FULL_PX, 0.0, 1.0)))


## The printer's three ticks, spread over the payout's roll (D1).
func _ticks(roll: float) -> void:
	var ticks: Tween = _tween()
	for tick: int in range(TICKS_PER_ROLL):
		if tick > 0:
			ticks.tween_interval(roll / TICKS_PER_ROLL)
		ticks.tween_callback(_sfx.play.bind("tick", 1.0, TICK_DB))


func _print_pitch() -> float:
	return minf(plan.printer_speed, _tuning.print_pitch_max)


## Prints a step's receipt line (null for a step without one) and grows the pile.
func _print_step(step: ScoreStep) -> Control:
	return _print_line(_receipt.add_step(step, _names, _upgrade_names, _inspection_names))


func _print_line(line: Control) -> Control:
	if line == null or _pile == null:
		return line
	_lines_printed += 1
	_pile.set_height(plan.pile_start_px + _tuning.pile_px_per_line * _lines_printed)
	if not plan.reduced_motion:
		_pile.scale = Vector2(1.0, PILE_SETTLE)
		_fx.scale_tween(_pile).tween_property(_pile, "scale", Vector2.ONE, PILE_SETTLE_TIME)
	return line


## The card that caused a step, or null when its source is not a card (an upgrade or an
## inspection, full build): source_slot is only read for CARD sources (plan section 4).
func _source_view(step: ScoreStep) -> CardView:
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return null
	return _views[step.source_slot]


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


## How many receipt lines the count-up prints for `steps`: one per step but EFFECT_ARMED (which
## prints none), and the TOTAL line.
static func _printed_lines(steps: Array[ScoreStep]) -> int:
	var lines: int = 1
	for step: ScoreStep in steps:
		if step.step_type != ScoreStep.StepType.EFFECT_ARMED:
			lines += 1
	return lines


## The part of a source that is punched: a card's body (its layout box stays still), or the
## whole loyalty-card box.
static func _moving_part(source: Control) -> Control:
	var view: CardView = source as CardView
	return view.body if view != null else source


static func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## The music ducks as the pause before the total starts (#62, Q6; #61), unless a tap has
## already skipped the dessert. It stays ducked: the shift screen brings it back at the printer
## feed, or crossfades to the results after a miss.
func _duck_for_dessert() -> void:
	if music != null and not dessert_skipped:
		music.duck(DESSERT_DUCK_DB, DUCK_ATTACK_S)
		_ducked = true


## Rolls the shown subtotal to `to` over `seconds` (at once for 0). A roll still running ends at
## once first.
func _roll_subtotal(to: int, seconds: float) -> void:
	_finish_roll()
	if seconds <= 0.0:
		_set_subtotal(to)
		return
	_roll_to = to
	_roll = _tween()
	_roll.tween_method(_set_subtotal, float(_shown_subtotal), float(to), seconds)


func _finish_roll() -> void:
	if _roll != null and _roll.is_valid():
		_roll.kill()
		_set_subtotal(_roll_to)
	_roll = null


func _set_subtotal(value: float) -> void:
	_shown_subtotal = roundi(value)
	_led.show_subtotal(_shown_subtotal, _met)


func _tween() -> Tween:
	var tween: Tween = create_tween().set_speed_scale(_speed())
	_live.append(tween)
	return tween


func _wait(seconds: float) -> void:
	var tween: Tween = _tween()
	tween.tween_interval(seconds)
	await tween.finished


func _wait_ms(ms: int) -> void:
	await _wait(ms / 1000.0)


## How fast the count-up's tweens run: 0 during a hit-stop, else the fastest of the taps' skip,
## a hold's fast-forward and the plan's base_speed (D6) up to the verdict, its speed setting
## alone after it (the dessert, #61).
func _speed() -> float:
	if _hit_stop_left_ms > 0.0:
		return 0.0
	var base: float = 1.0
	if plan != null:
		base = plan.speed_setting if _verdict_shown else plan.base_speed
	return maxf(_press_speed(), base)


## The taps' skip or a hold's fast-forward, whichever is faster (1 for neither): the only
## speeds that shorten hit-stops and the pause before the total.
func _press_speed() -> float:
	return maxf(_skip_speed(), FAST_FORWARD if _presses.is_holding() else 1.0)


func _skip_speed() -> float:
	if dessert_skipped:
		return DESSERT_SKIP
	return TAP_SKIP if _tapped and not _verdict_shown else 1.0
