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
## The beats (CountUpBeats, which plays each kind): a plain card's scan beep, note, base pop and
## payout in one short beat; bonuses flying in from the card (or upgrade box) that caused them;
## multiplier stamps; copies; Soup's and the inspections' "denied"; sticker and Bundle moments;
## an armed effect's glow; fizzle puffs; a payout's "+€N" flying to its receipt line
## (ReceiptFly); a receipt printer that runs faster as the run goes on, with three ticks per
## payout roll; a register rattle on big payouts; the quota ding (quota_met, held by its
## hit-stop); then a held breath (longer and rattling for a large total) and the TOTAL line.
##
## The scan (#86 v6): the items come to the scanner one by one. Before the first beat of each
## item's scan group (CountUpPlan), the count emits `ride` and waits the plan's ride gap while the
## belt ride slides the item in and hops the one before into the bag; after the last beat the last
## item bags during the pause before the total. The count-up never moves an item itself: the belt
## ride (connected to `ride`, `beat_started` and `step_landed`, its motion on tween_maker()) does,
## and gives back where each item is now (`source_rect`) for flights and puffs.
## Then the dessert (#61, CountUpDessert): the slam onto the monitor's total, the margin, PAID, the
## tear and the next shift's notice; a passed shift's ends at the printer feed (`printer_feed`),
## where the RECEIPT REWARDS machine takes over (#77).
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
## fast-forward and the plan's count_speed (the auto speed-up times the speed setting times the
## tuning's count_tempo, so it may be under 1: a tap or a hold only ever speeds it up). Hit-stops
## freeze only the count-up's own tweens (_live) for real milliseconds, measured in _process
## (never a tween, never Engine.time_scale); they and the pause before the total never follow
## count_speed, only a tap or a hold. After the verdict, the dessert runs at the speed
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
## context's) removes every shake and rattle, and the payouts' chips: their lines show at once;
## the dessert's slam fades in at full size, unshaken.
##
## Steps caused by an upgrade (source_kind UPGRADE) come from that upgrade's loyalty-card box:
## bonuses and multipliers fly in from it, and its fizzles puff out of it. Steps caused by an
## inspection (source_kind INSPECTION, plan section 3.9) come from its tag in the top bar: it is
## punched as its "0" lands. On a passed shift followed by an inspected one, the notice prints in
## red under the dessert's tear.

## The dessert of a passed shift reached the printer feed (#61): the RECEIPT REWARDS machine
## opens here (#77). play() returns right after it.
signal printer_feed
signal finished
## A count of `views` (the row's items, in slot order) starts (#86 round 7: the bay's queue), as
## the LED starts its count, before the pre-roll and the first ride.
signal count_started(views: Array[CardView])
## Step `index` landed on its item (#75, B; #86 v6: its sticker fires): a bonus or stamp as it
## lands, a fizzle as it puffs, other steps at the beat's start.
signal step_landed(index: int)
## A beat starts on `view`, one of `items` (#80, the monitor): its first `step` and that step's
## receipt line (ReceiptView.step_line, "" for none). Nothing waits for it: the timing never moves.
signal beat_started(beat: CountUpBeat, step: ScoreStep, line: String, view: CardView, items: int)
## A ride gap starts (#86 v6): item `scan_slot` slides into the scanner over `ride_ms` (at speed
## 1, on tween_maker()'s tweens) while item `bag_slot` (-1 for none) hops into the bag. Emitted
## before each scan group's first beat (with 0 ms for item 0 already in the scanner's cell; the
## count then waits ride_ms), and once after the last beat as ride(last item, -1, bag_ms), when
## the last item bags during the pause before the total (no wait).
signal ride(bag_slot: int, scan_slot: int, ride_ms: int)
## The quota is met (D5, #86 v6): at the ding (`pop`), at the TOTAL line when the last payout
## crosses it (`pop`), or at once in a resumed end state (not `pop`). The LED's reading turns
## met at the same moment.
signal quota_met(pop: bool)

## A hold's speed, from HOLD_THRESHOLD_MS on.
const FAST_FORWARD := 5.0
## A press released before this (in ms) is a tap; one held this long a hold (PressReader's).
const HOLD_THRESHOLD_MS := PressReader.HOLD_THRESHOLD_MS
## The speed after the first tap, up to the verdict.
const TAP_SKIP := 12.0
## The speed of everything left after a tap that skips the dessert.
const DESSERT_SKIP := 30.0
## A second press this soon (ms) after the start ends the checkout click's double-click, not a tap.
## Later ones are taps (the second of two quick taps still skips the dessert). PressReader's.
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
## The register rattle's sound (#62, CountUpBeats.play_rattle): rattle_s, from RATTLE_MEDIUM_PX px
## rattle_m, from RATTLE_LARGE_PX rattle_l; its volume climbs from RATTLE_QUIET_DB to 0 dB at
## RATTLE_FULL_PX.
const RATTLE_MEDIUM_PX := 6.0
const RATTLE_LARGE_PX := 10.0
const RATTLE_FULL_PX := 12.0
const RATTLE_QUIET_DB := -10.0
## A line printed when a payout lands fades in over this (s; ReceiptFly, the dessert).
const LINE_FADE := 0.15
## The subtotal's punch on the TOTAL line (D11).
const TOTAL_PUNCH := 1.5
## A payout's subtotal punch: SUBTOTAL_PUNCH plus up to SUBTOTAL_PUNCH_MAX for bigger payouts.
const SUBTOTAL_PUNCH := 1.1
const SUBTOTAL_PUNCH_MAX := 0.5
## The dessert ducks the music (#62, Q6, #61) this far over DUCK_ATTACK_S as the pause before the
## total starts (the slam lands in near-silence); a dessert skip unducks it over SKIP_UNDUCK_S.
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
## Where item `slot` is now, a global Rect2 (#86 v6: the belt ride's source_rect, the scanner or
## the bag's mouth once bagged), for the flights and puffs that start from an item; unset, they
## start at the item view's centre.
var source_rect: Callable
## How big the ending was, for what follows the total (#61); null until the total shows.
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
var _receipt: ReceiptView
## The register's LED: the running subtotal, then the total.
var _led: LedDisplay
## The quota is met (the ding beat, or the TOTAL line): the LED's subtotal shows green.
var _met: bool = false
## The sounds; the beats play the same Sfx (a test may swap it after setup()).
var _sfx: Sfx:
	set(value):
		_sfx = value
		if _beats != null:
			_beats.sfx = value
## Shaken on big payouts and before a large total (the register rattle).
var _rattle_target: Control
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
## Punches, shakes and flying labels, on this count-up's tweens.
var _fx: CountUpMotion
## What follows the verdict (#61), on this count-up's tweens.
var _dessert: CountUpDessert
## Each beat's motion and sound (#86 v6: split out for the file length), on this count-up's
## tweens.
var _beats: CountUpBeats


func _init() -> void:
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(_tap)


## `rattle_target` is shaken by the register rattle; `tuning` defaults to TUNING_PATH. The LED's
## beat (its gain chip) pops on the count-up's tweens.
func setup(
	overlay: Control,
	receipt: ReceiptView,
	led: LedDisplay,
	sfx: Sfx,
	rattle_target: Control,
	tuning: CountUpTuning = null
) -> void:
	_overlay = overlay
	_fx = CountUpMotion.new(overlay, _tween)
	_receipt = receipt
	_led = led
	_led.beat().make_tween = _tween
	_sfx = sfx
	_rattle_target = rattle_target
	_tuning = tuning if tuning != null else load(TUNING_PATH) as CountUpTuning
	_dessert = CountUpDessert.new(overlay, receipt, led, sfx, _fx, rattle_target, _tween)
	_beats = CountUpBeats.new(self, overlay, receipt, led, _fx, rattle_target, _tween)
	_beats.sfx = sfx
	_beats.landed = _landed
	_beats.land = _land
	_beats.roll_subtotal = _roll_subtotal
	_beats.meet_quota = _quota_met


## Plays `result` on the row's card views. `context` is the run around the row (shift, best so
## far, speed setting, reduced motion, and the receipt's header, printed at once as the count-up
## starts); `quota` only places the ding (quota_met).
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
	plan = CountUpPlan.build(result.steps, quota, context, _tuning)
	_beats.begin(
		plan,
		_tuning,
		_steps,
		views,
		names,
		upgrade_boxes,
		upgrade_names,
		inspection_sources,
		inspection_names
	)
	intensity = null
	margin = null
	printer_feed_ms = -1
	_fx.reset(plan.reduced_motion)
	_clear_row()
	_led.start_count(quota)
	count_started.emit(_views)
	_shown_subtotal = 0
	_roll = null
	_hit_stop_left_ms = 0.0
	fast_forward_used = false
	first_tap_ms = -1
	dessert_skipped = false
	_tapped = false
	_verdict_shown = false
	_ducked = false
	_presses.begin()
	_playing = true
	# The receipt starts over: the shift's header and every item's line waiting (#80).
	_receipt.begin_count(context.receipt_header, _names)
	_set_subtotal(0.0)
	for view: CardView in _views:
		view.reset_motion()
		view.hide_badge()
	await _wait_ms(plan.pre_roll_ms)
	var scanned: int = -1
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		if beat.opens_slot:
			ride.emit(scanned, beat.scan_slot, beat.ride_ms)
			scanned = beat.scan_slot
			if beat.ride_ms > 0:
				await _wait_ms(beat.ride_ms)
		_play_beat(index)
		await _wait_ms(beat.duration_ms)
	# The last item bags as the held breath starts: it adds nothing.
	if scanned >= 0:
		ride.emit(scanned, -1, plan.bag_ms)
	_duck_for_dessert()
	await _pause()
	_finish_roll()
	_receipt.add_total(result.total)
	_sfx.play("print", _beats.print_pitch())
	_led.show_total()
	_fx.punch(_led.digits_label(), TOTAL_PUNCH)
	if plan.chip_at_total:
		_meet(true)
	total_shown_ms = Time.get_ticks_msec()
	intensity = CountUpIntensity.from_plan(plan)
	_verdict_shown = true
	margin = ShiftMargin.of(result.total, quota)
	# The dessert plays the count-up's own Sfx (a test may swap it after setup()).
	_dessert.sfx = _sfx
	_dessert.speed_setting = plan.speed_setting
	_dessert.inspection = ", ".join(inspection_names)
	await _dessert.play(
		result.total, quota, notice, _tuning, intensity, plan.reduced_motion, _beats.print_pitch()
	)
	if margin.passed():
		printer_feed_ms = Time.get_ticks_msec()
		printer_feed.emit()
	_playing = false
	_presses.end()
	finished.emit()


## A checkout's end state without playing it, for a run resumed after its checkout: the subtotal
## at the total, met (quota_met without a pop) when the quota is met (D5). Sets `plan` and
## `intensity`; the receipt is the caller's (ReceiptView.show_result).
func show_end_state(result: ScoreResult, quota: int, context: CountUpContext) -> void:
	plan = CountUpPlan.build(result.steps, quota, context, _tuning)
	intensity = CountUpIntensity.from_plan(plan)
	_clear_row()
	_led.start_count(quota)
	_set_subtotal(result.total)
	_led.show_total()
	if plan.quota_reached:
		_meet(false)


## The Callable that makes this count-up's tweens (#86 v6): collaborators' motion on them follows
## the hit-stops, taps and holds, like the count's own.
func tween_maker() -> Callable:
	return _tween


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


## Starts beat `index`'s motion and sound (CountUpBeats); play() waits its length.
func _play_beat(index: int) -> void:
	var beat: CountUpBeat = plan.beats[index]
	var step: ScoreStep = _steps[beat.steps[0]]
	beat_started.emit(beat, step, _beats.line_of(step), _views[step.slot], _views.size())
	_beats.play(index)


## Emits step_landed for each of the beat's steps (CountUpBeats, as they land).
func _landed(beat: CountUpBeat) -> void:
	for index: int in beat.steps:
		step_landed.emit(index)


## The ding beat's roll has ended (D5, CountUpBeats): the ding sounds and the quota is met; the
## beat's hit-stop (the burst's hold) follows.
func _quota_met(with_ding: bool) -> void:
	if with_ding:
		_sfx.play("ding")
	_meet(true)


## The quota is met: the LED's reading turns met (its subtotal green; reading_changed tells the
## top gauge) and quota_met tells the rest, with `pop` or at once.
func _meet(pop: bool) -> void:
	_met = true
	_led.show_subtotal(_shown_subtotal, true)
	quota_met.emit(pop)


## Forgets the last row's met state: the subtotal gets its own colour back.
func _clear_row() -> void:
	_met = false
	_led.reset_colour()


## The held breath before the TOTAL line (D4): pause_ms of real time, sped up only by a tap or
## a hold. The printer is silent; a large total rattles the register (a huge one also rings the
## register bell). The rattle and the bell sound under reduced motion too: only the shake goes.
func _pause() -> void:
	if plan.size != CountUpPlan.Size.NORMAL:
		var huge: bool = plan.size == CountUpPlan.Size.HUGE
		if huge:
			_sfx.play("register_bell")
		_beats.play_rattle(_tuning.final_rattle_huge_px if huge else _tuning.final_rattle_large_px)
	if plan.final_rattle_px > 0.0:
		# The rattle fills the pause: the pause runs in real time (sped up only by a tap or a
		# hold), the shake's tween at _speed() (count_speed included), so it gets that many more
		# swings, or fewer under 1. A hit-stop freezes both alike.
		var tween_speed: float = _paced(plan.count_speed)
		var seconds: float = plan.pause_ms / 1000.0 * tween_speed / _press_speed()
		var swings: int = maxi(
			4, ceili((seconds - CountUpMotion.SHAKE_SETTLE) / CountUpMotion.SHAKE_SWING)
		)
		_fx.shake(_rattle_target, plan.final_rattle_px, swings)
	var left: float = plan.pause_ms
	var last: int = Time.get_ticks_usec()
	while left > 0.0:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		if _hit_stop_left_ms <= 0.0:
			left -= (now - last) / 1000.0 * _press_speed()
		last = now


## A beat lands (CountUpBeats): its hit-stop (D6) freezes the count-up's tweens for real
## milliseconds.
func _land(beat: CountUpBeat) -> void:
	if beat.hit_stop_ms <= 0:
		return
	_hit_stop_left_ms = maxf(_hit_stop_left_ms, beat.hit_stop_ms)
	_hit_stop_us = Time.get_ticks_usec()
	_apply_speed()


## The music ducks as the pause before the total starts (#62, Q6; #61), unless a tap has
## already skipped the dessert. It stays ducked: the shift screen brings it back at the printer
## feed, or crossfades to the results after a miss.
func _duck_for_dessert() -> void:
	if music != null and not dessert_skipped:
		music.duck(DESSERT_DUCK_DB, DUCK_ATTACK_S)
		_ducked = true


## Rolls the shown subtotal to `to` over `seconds` (at once for 0; CountUpBeats on a payout). A
## roll still running ends at once first.
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
## a hold's fast-forward and the plan's count_speed (D6) up to the verdict, its speed setting
## alone after it (the dessert, #61).
func _speed() -> float:
	if _hit_stop_left_ms > 0.0:
		return 0.0
	var base: float = 1.0
	if plan != null:
		base = plan.speed_setting if _verdict_shown else plan.count_speed
	return _paced(base)


## `base` (a count_speed under 1 included) unless a tap or a hold runs faster.
func _paced(base: float) -> float:
	var press: float = _press_speed()
	return base if press <= 1.0 else maxf(press, base)


## The taps' skip or a hold's fast-forward, whichever is faster (1 for neither): the only
## speeds that shorten hit-stops and the pause before the total.
func _press_speed() -> float:
	return maxf(_skip_speed(), FAST_FORWARD if _presses.is_holding() else 1.0)


func _skip_speed() -> float:
	if dessert_skipped:
		return DESSERT_SKIP
	return TAP_SKIP if _tapped and not _verdict_shown else 1.0
