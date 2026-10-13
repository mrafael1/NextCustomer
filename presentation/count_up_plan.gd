class_name CountUpPlan
extends RefCounted
## The count-up's beat plan (#60, decisions D1 to D9): what each ScoreStep plays as, which note
## it sounds, how long it lasts, how hard it rattles, where the quota dings and how a long row
## is fitted to the budget. It is a pure function of the steps, the quota, the context and the
## tuning: it never scores, never reads a rule, and has no Node, so it is unit-tested whole and
## the count-up only plays it back.
##
## Beats: every step belongs to exactly one beat, in step order. A BASE followed at once by the
## PAYOUT of the same slot is a plain card and merges into one MERGED_PLAIN beat; every other
## step is a beat of its own.
##
## Intensity comes from the shift, the best checkout of earlier shifts and the step count,
## never from the quota (D3), so another quota changes only the ding: its beat, its hit-stop
## and the length of that one beat, which the fit spares.
##
## Fit (D7): when the row is planned over the tuning's fit_target_ms, stages run in order, each
## in full, until the row fits: (1) shorter trailing gaps, (2) repeat landings of one armed
## effect become echoes, (3) shorter payout rolls, (4) faster fly-ins, tags and links, (5) a
## uniform factor on every shortenable beat. Past stage 1's shorter gap, merged plain beats, the
## ding beat and its hit-stop, the first card stamp on each card, echoes, the pause and a
## fizzle's grey hold are never shortened. A repeat landing still becomes an echo in stage 2
## even when it is the first card stamp on its card, as in the decisions' budget for the
## reference row. The fit is decided without the quota: its budget always counts a ding's
## hit-stop (hit_stop_ding_ms) on top of the other hit-stops, ding or not, and no beat is
## spared for the ding while it is decided. The ding beat is spared afterwards, so every other
## beat is the same for any quota.

enum Size { NORMAL, LARGE, HUGE }

const LAST_STAGE := 5

var beats: Array[CountUpBeat] = []
## The auto speed-up times the speed setting (D6); divides every beat length, never hit-stops
## or the pause.
var base_speed: float = 1.0
## The player's speed setting alone: the dessert after the verdict runs at it (#61), without the
## auto speed-up.
var speed_setting: float = 1.0
## How fast the receipt printer runs (D3): divides the payout rolls.
var printer_speed: float = 1.0
## The best so far the intensity is measured against: at least the tuning's first_best_floor.
var best: int = 0
## The row's final subtotal.
var total: int = 0
var size: Size = Size.NORMAL
## The held breath before the TOTAL line (D4), real ms.
var pause_ms: int = 0
## The register rattle during the pause (D4); 0 under reduced motion.
var final_rattle_px: float = 0.0
## Before the first beat, at speed 1.
var pre_roll_ms: int = 0
## Click to TOTAL shown without taps: (pre_roll_ms + every duration_ms) / base_speed + every
## hit_stop_ms + pause_ms.
var planned_ms: int = 0
## The number of ScoreSteps.
var step_count: int = 0
## Beats that step the note ladder (D1): MERGED_PLAIN with a payout, BONUS and STAMP.
var gain_count: int = 0
var reduced_motion: bool = false
## The last fit stage applied (D7): 0 when the row fitted as planned, up to LAST_STAGE.
var fit_stage: int = 0
## The beat that dings the quota mid-row (D5), or -1.
var ding_beat: int = -1
## Some payout reaches the quota.
var quota_reached: bool = false
## The quota is first reached on the last payout: the colour and chip come with the TOTAL line,
## with no ding (D5).
var chip_at_total: bool = false
## The payout beat where the subtotal first passes best (D3), or -1.
var passes_best_beat: int = -1
## The paper pile's height before this row prints (D4).
var pile_start_px: float = 0.0
var _tuning: CountUpTuning
## Per beat, before fitting: the length with the full gap (PAYOUT: its roll is added later).
var _raw_ms: PackedInt32Array = PackedInt32Array()
## Per beat, before fitting: the payout roll.
var _raw_roll: PackedInt32Array = PackedInt32Array()
## Per beat: a fly-in, tag or link that stage 4 speeds up.
var _fly: Array[bool] = []
## Per beat: the 2nd or later landing of one armed beat (stage 2 echoes it).
var _repeat: Array[bool] = []
## Per beat: a card stamp (CARD source), as opposed to an upgrade or inspection one.
var _card_stamp: Array[bool] = []


func _init(
	steps: Array[ScoreStep] = [],
	quota: int = 0,
	context: CountUpContext = null,
	tuning: CountUpTuning = null
) -> void:
	if context == null or tuning == null:
		return
	_tuning = tuning
	step_count = steps.size()
	reduced_motion = context.reduced_motion
	best = maxi(tuning.first_best_floor, context.best_so_far)
	var auto: float = tuning.auto_speed if context.shift >= tuning.auto_speed_from_shift else 1.0
	base_speed = auto * context.speed_setting
	speed_setting = context.speed_setting
	var extra_steps: int = maxi(0, step_count - tuning.printer_free_steps)
	printer_speed = minf(
		tuning.printer_speed_max,
		(
			1.0
			+ tuning.printer_speed_per_shift * (context.shift - 1)
			+ tuning.printer_speed_per_step * extra_steps
		)
	)
	pile_start_px = pile_start_for(context.shift, tuning)
	pre_roll_ms = tuning.pre_roll_ms
	total = steps[steps.size() - 1].subtotal if not steps.is_empty() else 0
	_make_beats(steps)
	_link_armed(steps)
	_set_payouts(steps)
	_set_notes()
	_set_quota(quota)
	_set_size()
	_set_raw_lengths(steps)
	_fit()


## The plan for one checkout. `steps` are ScoreResult.steps, `quota` the shift's quota (it only
## places the ding), `context` the run around the row.
static func build(
	steps: Array[ScoreStep], quota: int, context: CountUpContext, tuning: CountUpTuning
) -> CountUpPlan:
	return CountUpPlan.new(steps, quota, context, tuning)


## The paper pile's height before a row of 1-based `shift` prints (D4): the paper of the
## earlier shifts.
static func pile_start_for(shift: int, tuning: CountUpTuning) -> float:
	return minf(tuning.pile_start_max_px, tuning.pile_start_px_per_shift * (shift - 1))


## Payout beats: PAYOUT and MERGED_PLAIN.
static func is_payout_beat(beat: CountUpBeat) -> bool:
	return beat.kind == CountUpBeat.Kind.PAYOUT or beat.kind == CountUpBeat.Kind.MERGED_PLAIN


## Gain beats step the note ladder (D1).
static func is_gain_beat(beat: CountUpBeat) -> bool:
	match beat.kind:
		CountUpBeat.Kind.MERGED_PLAIN:
			return beat.payout > 0
		CountUpBeat.Kind.BONUS, CountUpBeat.Kind.STAMP:
			return true
	return false


func _make_beats(steps: Array[ScoreStep]) -> void:
	var index: int = 0
	while index < steps.size():
		var step: ScoreStep = steps[index]
		var beat: CountUpBeat = CountUpBeat.new()
		beat.slot = step.slot
		beat.subtotal = step.subtotal
		beat.steps.append(index)
		if _starts_plain_card(steps, index):
			beat.kind = CountUpBeat.Kind.MERGED_PLAIN
			beat.steps.append(index + 1)
			beat.subtotal = steps[index + 1].subtotal
			index += 1
		else:
			beat.kind = _kind_of(step.step_type)
		beats.append(beat)
		index += 1


## D2: a BASE followed at once by the PAYOUT of the same slot.
static func _starts_plain_card(steps: Array[ScoreStep], index: int) -> bool:
	if index + 1 >= steps.size():
		return false
	var step: ScoreStep = steps[index]
	var next: ScoreStep = steps[index + 1]
	return (
		step.step_type == ScoreStep.StepType.BASE
		and next.step_type == ScoreStep.StepType.PAYOUT
		and next.slot == step.slot
	)


static func _kind_of(step_type: ScoreStep.StepType) -> CountUpBeat.Kind:
	match step_type:
		ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			return CountUpBeat.Kind.BONUS
		ScoreStep.StepType.MULTIPLIER:
			return CountUpBeat.Kind.STAMP
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			return CountUpBeat.Kind.DENIED
		ScoreStep.StepType.PAYOUT:
			return CountUpBeat.Kind.PAYOUT
		ScoreStep.StepType.EFFECT_ARMED:
			return CountUpBeat.Kind.ARMED
		ScoreStep.StepType.WASTED:
			return CountUpBeat.Kind.FIZZLE
		ScoreStep.StepType.TAG_ADDED:
			return CountUpBeat.Kind.TAG
		ScoreStep.StepType.LINKED:
			return CountUpBeat.Kind.LINK
	return CountUpBeat.Kind.BASE


## D8: an armed beat's landings are the later FLAT or MULTIPLIER steps from a card with the
## same source_slot and text. Each landing goes to the latest such armed beat before it.
func _link_armed(steps: Array[ScoreStep]) -> void:
	var armed_by_key: Dictionary[String, int] = {}
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		var step: ScoreStep = steps[beat.steps[0]]
		var key: String = "%d|%s" % [step.source_slot, step.text]
		if beat.kind == CountUpBeat.Kind.ARMED:
			armed_by_key[key] = index
			continue
		var lands: bool = (
			step.source_kind == ScoreStep.SourceKind.CARD
			and (
				step.step_type == ScoreStep.StepType.FLAT
				or step.step_type == ScoreStep.StepType.MULTIPLIER
			)
			and armed_by_key.has(key)
		)
		if lands:
			var armed: CountUpBeat = beats[armed_by_key[key]]
			beat.armed_from = armed_by_key[key]
			armed.targets.append(index)


## Payouts, rolls and the payout rattle (D3).
func _set_payouts(steps: Array[ScoreStep]) -> void:
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		_raw_roll.append(0)
		if not is_payout_beat(beat):
			continue
		beat.payout = steps[beat.steps[beat.steps.size() - 1]].value
		if beat.payout > 0:
			var share: float = minf(1.0, beat.payout / (_tuning.roll_full_share * best))
			var roll: float = _tuning.roll_min_ms + _tuning.roll_extra_ms * share
			_raw_roll[index] = roundi(roll / printer_speed)
			beat.roll_ms = _raw_roll[index]
		if passes_best_beat == -1 and beat.subtotal > best:
			passes_best_beat = index
		var rattle: float = 0.0
		var threshold: float = maxf(_tuning.rattle_min_payout, _tuning.rattle_min_share * best)
		if beat.payout > 0 and beat.payout >= threshold:
			rattle = minf(
				_tuning.rattle_max_px,
				_tuning.rattle_base_px + _tuning.rattle_per_best_px * beat.payout / best
			)
		if passes_best_beat != -1:
			beat.punch_boost = _tuning.passes_best_punch
			if beat.payout > 0:
				rattle += _tuning.passes_best_rattle_px
		beat.rattle_px = 0.0 if reduced_motion else rattle


## D1: gain beats climb the ladder, fitted to the row so the last gain lands on the top note
## when there are at least as many gains as notes. ARMED replays the current note quietly.
func _set_notes() -> void:
	for beat: CountUpBeat in beats:
		if is_gain_beat(beat):
			gain_count += 1
	var top: int = _tuning.note_count - 1
	var gain_index: int = 0
	var current: int = 0
	for beat: CountUpBeat in beats:
		if is_gain_beat(beat):
			current = gain_index
			if gain_count > _tuning.note_count:
				current = floori(float(gain_index * top) / float(gain_count - 1))
			beat.note = current
			gain_index += 1
		elif beat.kind == CountUpBeat.Kind.ARMED:
			beat.note = current
			beat.note_quiet = true


## D5: the first payout reaching the quota dings, unless it is the row's last payout.
func _set_quota(quota: int) -> void:
	var last_payout: int = -1
	for index: int in range(beats.size()):
		if is_payout_beat(beats[index]):
			last_payout = index
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		if not is_payout_beat(beat) or beat.subtotal < quota:
			continue
		quota_reached = true
		if index == last_payout:
			chip_at_total = true
		else:
			ding_beat = index
			beat.ding = true
		return


## D4: the size of the total against the best so far, the pause and its rattle.
func _set_size() -> void:
	if total >= _tuning.huge_factor * best:
		size = Size.HUGE
		pause_ms = _tuning.pause_huge_ms
		final_rattle_px = _tuning.final_rattle_huge_px
	elif total >= maxf(_tuning.large_floor, _tuning.large_factor * best):
		size = Size.LARGE
		pause_ms = _tuning.pause_large_ms
		final_rattle_px = _tuning.final_rattle_large_px
	else:
		size = Size.NORMAL
		pause_ms = _tuning.pause_normal_ms
		final_rattle_px = 0.0
	if reduced_motion:
		final_rattle_px = 0.0


## D7's beat lengths before fitting, and which beats each fit stage may touch.
func _set_raw_lengths(steps: Array[ScoreStep]) -> void:
	var stamped: Dictionary[int, bool] = {}
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		var step: ScoreStep = steps[beat.steps[0]]
		var from_card: bool = step.source_kind == ScoreStep.SourceKind.CARD
		var own: bool = from_card and step.source_slot == step.slot
		var fly: bool = false
		var length: int = 0
		match beat.kind:
			CountUpBeat.Kind.MERGED_PLAIN:
				length = _tuning.merged_ms if beat.payout > 0 else _tuning.merged_zero_ms
			CountUpBeat.Kind.BASE:
				length = _tuning.base_ms
			CountUpBeat.Kind.BONUS:
				fly = not (own and step.step_type == ScoreStep.StepType.FLAT)
				length = _tuning.bonus_other_ms if fly else _tuning.bonus_own_ms
			CountUpBeat.Kind.STAMP:
				fly = not from_card
				length = _tuning.stamp_card_ms if from_card else _tuning.stamp_upgrade_ms
				if from_card and not stamped.has(beat.slot):
					stamped[beat.slot] = true
					beat.first_stamp_on_card = true
			CountUpBeat.Kind.DENIED:
				length = _tuning.denied_ms
			CountUpBeat.Kind.PAYOUT:
				length = _tuning.gap_ms if beat.payout > 0 else _tuning.payout_zero_ms
			CountUpBeat.Kind.ARMED:
				length = _tuning.armed_ms
			CountUpBeat.Kind.FIZZLE:
				var reset: bool = from_card and step.source_slot != step.slot
				length = _tuning.fizzle_reset_ms if reset else _tuning.fizzle_ms
			CountUpBeat.Kind.TAG:
				fly = true
				length = _tuning.tag_ms
			CountUpBeat.Kind.LINK:
				fly = true
				length = _tuning.link_ms
		_raw_ms.append(length)
		_fly.append(fly)
		_card_stamp.append(beat.kind == CountUpBeat.Kind.STAMP and from_card)
		_repeat.append(beat.armed_from != -1 and beats[beat.armed_from].targets[0] != index)


func _fit() -> void:
	var factor: float = 1.0
	fit_stage = LAST_STAGE
	for stage: int in range(LAST_STAGE):
		if _fit_ms(stage, 1.0) <= _tuning.fit_target_ms:
			fit_stage = stage
			break
	if fit_stage == LAST_STAGE:
		# Stage 5: the gentlest uniform factor that fits, at most fit_max_factor.
		var fastest: float = 1.0 / _tuning.fit_max_factor
		factor = fastest
		if _fit_ms(LAST_STAGE, fastest) <= _tuning.fit_target_ms:
			var low: float = fastest
			var high: float = 1.0
			for _i: int in range(24):
				var middle: float = (low + high) / 2.0
				if _fit_ms(LAST_STAGE, middle) <= _tuning.fit_target_ms:
					low = middle
				else:
					high = middle
			factor = low
	_apply(fit_stage, factor, true)


## The row's length for the fit at `stage` and `factor`, the same for any quota: no beat is
## spared for the ding, and a ding's hit-stop is always counted.
func _fit_ms(stage: int, factor: float) -> int:
	var length_sum: int = _apply(stage, factor, false)
	var stops: int = _set_hit_stops(false)
	return (
		roundi((pre_roll_ms + length_sum) / base_speed)
		+ stops
		+ _tuning.hit_stop_ding_ms
		+ pause_ms
	)


## Sets every beat's length, roll, echo and start for fit `stage` (all earlier stages
## included) and uniform `factor` (stage 5 only), and returns the lengths' sum. With
## `spares_ding`, the ding beat keeps its length and roll from before stage 3 and the
## hit-stops and planned_ms are set too: the final pass.
func _apply(stage: int, factor: float, spares_ding: bool) -> int:
	var gap_cut: int = _tuning.gap_ms - _tuning.fit_gap_ms if stage >= 1 else 0
	var length_sum: int = 0
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		var spared: bool = spares_ding and beat.ding
		beat.echo = stage >= 2 and _repeat[index]
		var protected: bool = (
			beat.kind == CountUpBeat.Kind.MERGED_PLAIN
			or spared
			or beat.echo
			or beat.first_stamp_on_card
		)
		beat.roll_ms = _raw_roll[index]
		if stage >= 3 and beat.kind == CountUpBeat.Kind.PAYOUT and not spared:
			beat.roll_ms = mini(beat.roll_ms, _tuning.fit_roll_max_ms)
		var length: int = _raw_ms[index] - gap_cut
		if beat.kind == CountUpBeat.Kind.PAYOUT and beat.payout > 0:
			length += beat.roll_ms
		if beat.echo:
			length = _tuning.echo_ms
		elif stage >= 4 and _fly[index] and not protected:
			length = mini(
				length, maxi(_tuning.fly_in_min_ms, roundi(length * _tuning.fly_in_factor))
			)
		if stage >= LAST_STAGE and not protected:
			var scaled: int = roundi(length * factor)
			if beat.kind == CountUpBeat.Kind.FIZZLE:
				scaled = maxi(scaled, mini(length, _tuning.fizzle_hold_min_ms))
			length = scaled
		beat.duration_ms = length
		beat.start_ms = pre_roll_ms + length_sum
		length_sum += length
	if spares_ding:
		var stops: int = _set_hit_stops(true)
		planned_ms = roundi((pre_roll_ms + length_sum) / base_speed) + stops + pause_ms
	return length_sum


## D6: each beat's own hit-stop, then those starting within hit_stop_merge_ms of a group's
## first beat merge into one with the longest length. The merged hit-stop plays on the group's
## first beat, except when the ding is in the group: it then plays on the ding beat (D5: the
## freeze follows the ding), and the earlier beats in the group keep none. Returns their sum.
## Without `with_ding`, the ding beat has no hit-stop of its own (the fit's quota-free pass).
func _set_hit_stops(with_ding: bool) -> int:
	var group_first: int = -1
	## The beat that plays the group's merged hit-stop.
	var holder: int = -1
	var sum: int = 0
	for index: int in range(beats.size()):
		var beat: CountUpBeat = beats[index]
		beat.hit_stop_ms = 0
		var own: int = _own_hit_stop(index, with_ding)
		if own == 0:
			continue
		var first: CountUpBeat = beats[group_first] if group_first != -1 else null
		if first != null and beat.start_ms - first.start_ms <= _tuning.hit_stop_merge_ms:
			var kept: int = maxi(own, beats[holder].hit_stop_ms)
			sum += kept - beats[holder].hit_stop_ms
			if beat.ding:
				beats[holder].hit_stop_ms = 0
				holder = index
			beats[holder].hit_stop_ms = kept
			continue
		group_first = index
		holder = index
		beat.hit_stop_ms = own
		sum += own
	return sum


func _own_hit_stop(index: int, with_ding: bool) -> int:
	var beat: CountUpBeat = beats[index]
	if beat.ding:
		return _tuning.hit_stop_ding_ms if with_ding else 0
	match beat.kind:
		CountUpBeat.Kind.DENIED:
			return _tuning.hit_stop_denied_ms
		CountUpBeat.Kind.STAMP:
			if beat.echo:
				return 0
			if not _card_stamp[index]:
				return _tuning.hit_stop_upgrade_stamp_ms
			return _tuning.hit_stop_card_stamp_ms if beat.first_stamp_on_card else 0
	return 0
