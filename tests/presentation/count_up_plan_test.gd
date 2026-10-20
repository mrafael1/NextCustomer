extends GdUnitTestSuite
## CountUpPlan (#60, D1 to D9): beats, notes, armed targets, intensity, the quota ding,
## hit-stops and the long-row fit, and (#86 v6) the scan groups and their ride gaps, on rows
## scored with the real Scoring.score() and on hand-built steps for the edge cases. The plan is
## pure data: no saves, no event log, no Node.

const TUNING := "res://data/balance/count_up.tres"
const CARDS := "res://data/cards"
const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
## The full reference row of the #60 decisions: Eggs and Multipack arm effects, the Spot check
## zeroes the 3rd product, Coupon engine fizzles on Multipack, Slot engine stamps the 6th
## product.
const FULL_ROW := "eggs,bread,milk,multipack,milk,milk,milk"
## The golden rows of plan section 3.7 (tests/core/golden_rows_test.gd), on the frozen fixture.
const GOLDEN_ROWS := [
	"eggs,bread,cheese,banana,banana,repeat",
	"banana,repeat,bread,eggs,banana,cheese",
	"eggs,banana,banana",
	"banana,bundle,banana",
	"banana,repeat,banana",
	"bread,bundle,cheese",
	"eggs,bread,multipack,bread",
	"milk,multipack,cheese",
	"coffee,coffee,bread",
	"breakfast_sticker,banana,milk",
	"eggs,eggs,bread,bread,bread",
	"repeat,repeat",
	"soup,frozen_peas",
	"bread,final_markdown",
	"final_markdown,bread",
	"eggs,bread,repeat,bread",
	"bread,multipack,bread,repeat",
	"multipack,bread,bread",
	"bread,repeat,multipack,bread",
	"breakfast_sticker,repeat,banana,milk",
	"frozen_peas,frozen_peas",
	"soup,bundle,frozen_peas",
	"soup,repeat,frozen_peas",
	"eggs,coffee,bread,bread",
	"coffee,banana,bread",
	"coffee,bread,milk",
	"coffee,repeat,bread",
	"coffee,multipack,banana,bread",
	"bread,multipack,bread,multipack,bread",
	"breakfast_sticker,banana,multipack,coffee,bread",
	"banana,bundle,bundle,banana",
	"bread,bundle,repeat",
	"coffee,breakfast_sticker,soup,frozen_peas,bread",
	"eggs,soup,frozen_peas,bread",
	"banana,bundle,multipack,banana",
	"bundle,banana,banana,bundle",
	"bread,coffee",
	"breakfast_sticker,bread,milk",
	"bread,repeat,repeat",
	"coffee,breakfast_sticker,banana",
	"coffee,multipack,breakfast_sticker,banana",
]


func test_tuning_loads_with_positive_ordered_floors() -> void:
	var tuning: Resource = load(TUNING)
	assert_object(tuning).is_instanceof(CountUpTuning)
	var count_up: CountUpTuning = tuning
	assert_int(count_up.first_best_floor).is_greater(0)
	assert_int(count_up.large_floor).is_greater_equal(count_up.first_best_floor)
	assert_int(count_up.note_count).is_equal(11)
	assert_int(count_up.fit_target_ms).is_greater(0)
	assert_int(count_up.fit_gap_ms).is_less(count_up.gap_ms)
	assert_int(count_up.pause_normal_ms).is_less(count_up.pause_large_ms)
	assert_int(count_up.pause_large_ms).is_less(count_up.pause_huge_ms)
	assert_float(count_up.fit_max_factor).is_greater_equal(1.0)
	# D3: the print pitch follows the printer speed up to +4 semitones.
	assert_float(count_up.print_pitch_max).is_equal_approx(1.26, 0.001)
	assert_float(count_up.print_pitch_max).is_less_equal(count_up.printer_speed_max)
	# #86 v6 (the user's decisions): a 0.2 s ride per item, the last item's 0.3 s hop into the bag,
	# a 0.5 s hold at the quota and a 4-7 s budget; then (2026-10-20) the whole count 1.25x
	# slower: tempo 0.8, a 5-8.75 s budget and its fit target scaled with it.
	assert_int(count_up.ride_ms).is_equal(200)
	assert_int(count_up.bag_ms).is_equal(300)
	assert_int(count_up.hit_stop_ding_ms).is_equal(500)
	assert_float(count_up.count_tempo).is_equal_approx(0.8, 0.0001)
	assert_int(count_up.fit_target_ms).is_equal(8125)


func test_every_step_is_in_one_beat_and_only_plain_cards_merge() -> void:
	var rows: Array[Array] = [_full_steps()]
	for row: String in GOLDEN_ROWS:
		rows.append(_golden_steps(row))
	for steps: Array in rows:
		var typed: Array[ScoreStep] = []
		typed.assign(steps)
		var plan: CountUpPlan = _plan(typed)
		assert_int(plan.step_count).is_equal(typed.size())
		var seen: PackedInt32Array = PackedInt32Array()
		for beat: CountUpBeat in plan.beats:
			seen.append_array(beat.steps)
			var first: ScoreStep = typed[beat.steps[0]]
			if beat.kind == CountUpBeat.Kind.MERGED_PLAIN:
				assert_int(beat.steps.size()).is_equal(2)
				var second: ScoreStep = typed[beat.steps[1]]
				assert_int(first.step_type).is_equal(ScoreStep.StepType.BASE)
				assert_int(second.step_type).is_equal(ScoreStep.StepType.PAYOUT)
				assert_int(second.slot).is_equal(first.slot)
				assert_int(beat.payout).is_equal(second.value)
				continue
			assert_int(beat.steps.size()).is_equal(1)
			if first.step_type == ScoreStep.StepType.BASE:
				# A BASE beat of its own is never followed at once by its slot's PAYOUT.
				var next: ScoreStep = typed[beat.steps[0] + 1]
				var plain: bool = (
					next.step_type == ScoreStep.StepType.PAYOUT and next.slot == first.slot
				)
				assert_bool(plain).is_false()
		# Every step once, in step order.
		assert_array(Array(seen)).is_equal(range(typed.size()))


func test_full_row_beats_follow_the_decided_shape() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var kinds: PackedStringArray = PackedStringArray()
	for beat: CountUpBeat in plan.beats:
		kinds.append(CountUpBeat.Kind.keys()[beat.kind])
	# One line per slot.
	var expected: String = (
		" "
		. join(
			[
				"MERGED_PLAIN ARMED",
				"BASE STAMP PAYOUT",
				"BASE BONUS DENIED PAYOUT",
				"MERGED_PLAIN ARMED FIZZLE",
				"BASE BONUS STAMP PAYOUT",
				"BASE BONUS STAMP PAYOUT",
				"BASE BONUS STAMP STAMP PAYOUT",
			]
		)
	)
	assert_str(" ".join(kinds)).is_equal(expected)
	assert_int(plan.step_count).is_equal(27)
	assert_int(plan.total).is_equal(110)
	# Multipack pays 0 before its armed beat: merged, but not a gain.
	assert_int(plan.beats[9].payout).is_equal(0)
	assert_int(plan.beats[9].note).is_equal(-1)


func test_gain_notes_climb_one_step_at_a_time_on_short_rows() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var gains: PackedInt32Array = _gain_notes(plan)
	assert_int(plan.gain_count).is_equal(gains.size())
	# Eggs, the Eggs stamp, Milk's flat, then three Milks with a flat and a stamp, and Slot
	# engine: 10 gains, so every gain is its own note.
	assert_int(gains.size()).is_equal(10)
	for index: int in range(gains.size()):
		assert_int(gains[index]).is_equal(index)
	for beat: CountUpBeat in plan.beats:
		if not CountUpPlan.is_gain_beat(beat) and beat.kind != CountUpBeat.Kind.ARMED:
			assert_int(beat.note).is_equal(-1)
			assert_bool(beat.note_quiet).is_false()


func test_long_rows_fit_the_ladder_and_never_drop() -> void:
	var tuning: CountUpTuning = load(TUNING)
	for gains: int in [11, 12, 20, 37]:
		var plan: CountUpPlan = _plan(_flat_steps(gains))
		var notes: PackedInt32Array = _gain_notes(plan)
		assert_int(notes.size()).is_equal(gains)
		assert_int(notes[0]).is_equal(0)
		assert_int(notes[notes.size() - 1]).is_equal(tuning.note_count - 1)
		for index: int in range(1, notes.size()):
			assert_int(notes[index]).is_greater_equal(notes[index - 1])
			assert_int(notes[index]).is_less_equal(notes[index - 1] + 1)
		for note: int in notes:
			assert_int(note).is_between(0, tuning.note_count - 1)
	# 21 gains: note(i) = floor(i x 10 / 20).
	var spread: PackedInt32Array = _gain_notes(_plan(_flat_steps(21)))
	for index: int in range(21):
		assert_int(spread[index]).is_equal(floori(index / 2.0))


func test_armed_beats_replay_the_current_note_quietly() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var eggs_armed: CountUpBeat = plan.beats[1]
	assert_int(eggs_armed.kind).is_equal(CountUpBeat.Kind.ARMED)
	assert_int(eggs_armed.note).is_equal(plan.beats[0].note)
	assert_bool(eggs_armed.note_quiet).is_true()
	var multipack_armed: CountUpBeat = plan.beats[10]
	assert_int(multipack_armed.kind).is_equal(CountUpBeat.Kind.ARMED)
	# The last gain before it is Milk's flat (beat 6), the 3rd gain.
	assert_int(multipack_armed.note).is_equal(plan.beats[6].note)
	assert_int(multipack_armed.note).is_equal(2)
	assert_bool(multipack_armed.note_quiet).is_true()
	# The next gain steps on from there: the armed beat did not step.
	assert_int(plan.beats[13].note).is_equal(3)
	# Two gains, then a zero payout (no note): the armed beat replays the 2nd note.
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.BASE, 0, 0, 0, 0, "Coupon"),
		_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"),
		_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 0, 0, "Coupon"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "X ×2"),
	]
	var early: CountUpPlan = _plan(steps)
	assert_int(early.beats[3].note).is_equal(-1)
	assert_int(early.beats[4].note).is_equal(1)
	assert_bool(early.beats[4].note_quiet).is_true()
	# An armed beat before any gain plays note 0.
	steps = [_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "X ×2")]
	assert_int(_plan(steps).beats[0].note).is_equal(0)
	assert_bool(_plan(steps).beats[0].note_quiet).is_true()


func test_each_armed_beat_targets_its_landings() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	assert_array(Array(plan.beats[1].targets)).is_equal([3])
	assert_array(Array(plan.beats[10].targets)).is_equal([14, 18, 22])
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		var expected_from: int = -1
		if index == 3:
			expected_from = 1
		elif index in [14, 18, 22]:
			expected_from = 10
		assert_int(beat.armed_from).override_failure_message(str(index)).is_equal(expected_from)
	# Slot engine's stamp (an upgrade) and Milk's own flats are no landings.
	assert_int(plan.beats[23].armed_from).is_equal(-1)
	assert_int(plan.beats[13].armed_from).is_equal(-1)
	# A later arming of the same effect takes over the landings after it.
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "Eggs ×2"),
		_step(ScoreStep.StepType.BASE, 1, 1, 5, 0, "Bread"),
		_step(ScoreStep.StepType.MULTIPLIER, 1, 0, 2, 0, "Eggs ×2"),
		_step(ScoreStep.StepType.PAYOUT, 1, 1, 10, 10, "Bread"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 2, 0, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.BASE, 3, 3, 5, 10, "Bread"),
		_step(ScoreStep.StepType.MULTIPLIER, 3, 0, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.FLAT, 3, 0, 3, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.COPY, 3, 0, 3, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.MULTIPLIER, 3, 2, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.PAYOUT, 3, 3, 26, 36, "Bread"),
	]
	var again: CountUpPlan = _plan(steps)
	assert_array(Array(again.beats[0].targets)).is_equal([2])
	# The COPY and the stamp from another slot are not this effect's landings.
	assert_array(Array(again.beats[4].targets)).is_equal([6, 7])
	assert_int(again.beats[6].armed_from).is_equal(4)
	assert_int(again.beats[8].armed_from).is_equal(-1)
	assert_int(again.beats[9].armed_from).is_equal(-1)


func test_the_quota_dings_on_the_first_crossing_unless_it_is_the_last() -> void:
	var plan: CountUpPlan = _plan(_full_steps(), 40)
	# Milk at S5 takes the subtotal from 32 to 56.
	assert_int(plan.ding_beat).is_equal(19)
	assert_bool(plan.beats[19].ding).is_true()
	assert_int(plan.beats[19].subtotal).is_equal(56)
	assert_bool(plan.quota_reached).is_true()
	assert_bool(plan.chip_at_total).is_false()
	assert_int(_ding_count(plan)).is_equal(1)
	assert_int(_hit_stop_at(plan, 19)).is_equal((load(TUNING) as CountUpTuning).hit_stop_ding_ms)
	# Reached exactly, on the first payout.
	var first: CountUpPlan = _plan(_full_steps(), 1)
	assert_int(first.ding_beat).is_equal(0)
	# Crossed on the last payout: no ding, the chip comes with the TOTAL line.
	var last: CountUpPlan = _plan(_full_steps(), 110)
	assert_bool(last.quota_reached).is_true()
	assert_bool(last.chip_at_total).is_true()
	assert_int(last.ding_beat).is_equal(-1)
	assert_int(_ding_count(last)).is_equal(0)
	# Never reached: no ding and no chip.
	var missed: CountUpPlan = _plan(_full_steps(), 111)
	assert_bool(missed.quota_reached).is_false()
	assert_bool(missed.chip_at_total).is_false()
	assert_int(missed.ding_beat).is_equal(-1)
	assert_int(_ding_count(missed)).is_equal(0)


func test_another_quota_never_changes_the_intensity() -> void:
	for shift: int in [1, 3, 8]:
		var context: CountUpContext = CountUpContext.new(shift, 47)
		var low: CountUpPlan = _plan(_full_steps(), 40, context)
		var high: CountUpPlan = _plan(_full_steps(), 500, context)
		assert_int(low.ding_beat).is_not_equal(high.ding_beat)
		assert_int(low.size).is_equal(high.size)
		assert_int(low.pause_ms).is_equal(high.pause_ms)
		assert_float(low.final_rattle_px).is_equal(high.final_rattle_px)
		assert_float(low.printer_speed).is_equal(high.printer_speed)
		assert_float(low.base_speed).is_equal(high.base_speed)
		assert_int(low.best).is_equal(high.best)
		assert_int(low.passes_best_beat).is_equal(high.passes_best_beat)
		_assert_same_but_the_ding(low, high, "shift %d" % shift)
	# The fit never looks at the quota: a row fitted down to stage 5 fits the same way whether
	# it dings early, on its last payout or never.
	var long_steps: Array[ScoreStep] = _long_steps()
	var fitted: Array[CountUpPlan] = []
	for quota: int in [1, 30, 1000, 100000]:
		fitted.append(_plan(long_steps, quota, CountUpContext.new(1, 0)))
	assert_int(fitted[0].ding_beat).is_not_equal(fitted[1].ding_beat)
	assert_int(fitted[2].ding_beat).is_equal(-1)
	for other: CountUpPlan in fitted:
		assert_int(other.fit_stage).is_equal(CountUpPlan.LAST_STAGE)
		_assert_same_but_the_ding(fitted[0], other, "long row")
		_assert_same_but_the_ding(fitted[1], other, "long row")
	# Without a fit, the hit-stops differ only by the ding's.
	var context_3: CountUpContext = CountUpContext.new(3, 47)
	var plan_low: CountUpPlan = _plan(_full_steps(), 40, context_3)
	var plan_high: CountUpPlan = _plan(_full_steps(), 500, context_3)
	assert_int(plan_low.fit_stage).is_equal(0)
	assert_int(plan_high.fit_stage).is_equal(0)
	for index: int in range(plan_low.beats.size()):
		if index != plan_low.ding_beat:
			assert_int(plan_low.beats[index].hit_stop_ms).is_equal(
				plan_high.beats[index].hit_stop_ms
			)
	assert_int(plan_low.planned_ms - plan_high.planned_ms).is_equal(
		(load(TUNING) as CountUpTuning).hit_stop_ding_ms
	)


func test_speeds_follow_the_shift_the_setting_and_the_steps() -> void:
	var shift_1: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 47))
	var shift_3: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(3, 47))
	assert_float(shift_1.base_speed).is_equal(1.0)
	assert_float(shift_3.base_speed).is_equal_approx(1.25, 0.0001)
	assert_int(shift_3.planned_ms).is_less(shift_1.planned_ms)
	var fast: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(3, 47, 1.5))
	assert_float(fast.base_speed).is_equal_approx(1.875, 0.0001)
	assert_float(_plan(_full_steps(), 40, CountUpContext.new(2, 0, 1.5)).base_speed).is_equal(1.5)
	# The printer speeds up with the shift and with the steps past 14 (27 here).
	var steps: Array[ScoreStep] = _full_steps()
	assert_float(_plan(steps, 40, CountUpContext.new(1)).printer_speed).is_equal_approx(
		1.13, 0.0001
	)
	assert_float(_plan(steps, 40, CountUpContext.new(3)).printer_speed).is_equal_approx(
		1.23, 0.0001
	)
	assert_float(_plan(steps, 40, CountUpContext.new(8)).printer_speed).is_equal_approx(1.4, 0.0001)
	assert_float(_plan(_flat_steps(3), 40, CountUpContext.new(1)).printer_speed).is_equal(1.0)


func test_payout_rolls_and_rattles_follow_the_best_so_far() -> void:
	# Shift 1, best 45 (the floor): printer speed 1.13. Unfitted, so no roll is cut.
	var unfitted: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	unfitted.fit_target_ms = 100000
	var plan: CountUpPlan = CountUpPlan.build(_full_steps(), 40, CountUpContext.new(1, 0), unfitted)
	assert_int(plan.fit_stage).is_equal(0)
	assert_int(plan.best).is_equal(45)
	var bread: CountUpBeat = plan.beats[4]
	assert_int(bread.payout).is_equal(10)
	# (110 + 50 x min(1, 10 / 11.25)) / 1.13 = 136.6.
	assert_int(bread.roll_ms).is_equal(137)
	# €10 is at least max(€10, 0.2 x 45 = €9), so it rattles: 3 + 6 x 10 / 45.
	assert_float(bread.rattle_px).is_equal_approx(3.0 + 60.0 / 45.0, 0.0001)
	var eggs: CountUpBeat = plan.beats[0]
	assert_float(eggs.rattle_px).is_equal(0.0)
	# The subtotal first passes 45 at S5 (56): +2 px and the punch from there on.
	assert_int(plan.passes_best_beat).is_equal(19)
	assert_float(plan.beats[15].punch_boost).is_equal(0.0)
	assert_float(plan.beats[19].punch_boost).is_equal_approx(0.1, 0.0001)
	assert_float(plan.beats[24].punch_boost).is_equal_approx(0.1, 0.0001)
	assert_float(plan.beats[19].rattle_px).is_equal_approx(3.0 + 6.0 * 24 / 45.0 + 2.0, 0.0001)
	# Milk's €54 at S6: 3 + 6 x 54 / 45, plus 2.
	assert_float(plan.beats[24].rattle_px).is_equal_approx(12.2, 0.0001)
	# The amplitude is capped at 12 before the +2.
	assert_float(_plan(_flat_steps(1, 100)).beats[2].rattle_px).is_equal_approx(14.0, 0.0001)
	# A higher best: no step-up, and smaller rattles.
	var rich: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 200))
	assert_int(rich.passes_best_beat).is_equal(-1)
	assert_float(rich.beats[4].rattle_px).is_equal(0.0)
	assert_float(rich.beats[24].rattle_px).is_equal_approx(3.0 + 6.0 * 54 / 200.0, 0.0001)


func test_reduced_motion_removes_every_rattle_but_keeps_the_hit_stops() -> void:
	var normal: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 0))
	var calm: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 0, 1.0, true))
	assert_bool(calm.reduced_motion).is_true()
	assert_float(normal.final_rattle_px).is_greater(0.0)
	assert_float(calm.final_rattle_px).is_equal(0.0)
	var rattled: int = 0
	for index: int in range(calm.beats.size()):
		assert_float(calm.beats[index].rattle_px).is_equal(0.0)
		if normal.beats[index].rattle_px > 0.0:
			rattled += 1
		assert_int(calm.beats[index].hit_stop_ms).is_equal(normal.beats[index].hit_stop_ms)
	assert_int(rattled).is_greater(0)
	assert_int(calm.planned_ms).is_equal(normal.planned_ms)


func test_the_total_size_sets_the_pause() -> void:
	# best 45: large from max(50, 56.25), huge from 90.
	assert_int(_plan(_flat_steps(1, 56)).size).is_equal(CountUpPlan.Size.NORMAL)
	assert_int(_plan(_flat_steps(1, 56)).pause_ms).is_equal(300)
	assert_float(_plan(_flat_steps(1, 56)).final_rattle_px).is_equal(0.0)
	assert_int(_plan(_flat_steps(1, 57)).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 57)).pause_ms).is_equal(500)
	assert_float(_plan(_flat_steps(1, 57)).final_rattle_px).is_equal(8.0)
	assert_int(_plan(_flat_steps(1, 89)).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 90)).size).is_equal(CountUpPlan.Size.HUGE)
	assert_int(_plan(_flat_steps(1, 90)).pause_ms).is_equal(700)
	assert_float(_plan(_flat_steps(1, 90)).final_rattle_px).is_equal(12.0)
	# A higher best raises both: large from 1.25 x 100, huge from 2 x 100.
	var context: CountUpContext = CountUpContext.new(4, 100)
	assert_int(_plan(_flat_steps(1, 124), 1, context).size).is_equal(CountUpPlan.Size.NORMAL)
	assert_int(_plan(_flat_steps(1, 125), 1, context).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 200), 1, context).size).is_equal(CountUpPlan.Size.HUGE)


func test_hit_stops_land_on_the_heavy_beats_and_merge_when_close() -> void:
	var plan: CountUpPlan = _plan(_full_steps(), 500, CountUpContext.new(3, 47))
	assert_int(plan.fit_stage).is_equal(0)
	var stops: Dictionary[int, int] = {}
	for index: int in range(plan.beats.size()):
		if plan.beats[index].hit_stop_ms > 0:
			stops[index] = plan.beats[index].hit_stop_ms
	# The Eggs stamp, the Spot check's red 0, three Multipack stamps, Slot engine.
	var expected: Dictionary[int, int] = {3: 50, 7: 70, 14: 50, 18: 50, 22: 50, 23: 70}
	assert_dict(stops).is_equal(expected)
	for index: int in stops:
		(
			assert_bool(plan.beats[index].kind in [CountUpBeat.Kind.STAMP, CountUpBeat.Kind.DENIED])
			. is_true()
		)
	assert_bool(plan.beats[3].first_stamp_on_card).is_true()
	assert_bool(plan.beats[23].first_stamp_on_card).is_false()
	# Unfitted, every beat has its D7 length; a paying PAYOUT is its roll and the gap.
	var live: CountUpTuning = load(TUNING)
	var roll: int = -1
	var lengths_by_beat: Array[int] = [
		live.merged_ms,
		live.armed_ms,
		live.base_ms,
		live.stamp_card_ms,
		roll,
		live.base_ms,
		live.bonus_own_ms,
		live.denied_ms,
		live.payout_zero_ms,
		live.merged_zero_ms,
		live.armed_ms,
		live.fizzle_ms,
		live.base_ms,
		live.bonus_own_ms,
		live.stamp_card_ms,
		roll,
		live.base_ms,
		live.bonus_own_ms,
		live.stamp_card_ms,
		roll,
		live.base_ms,
		live.bonus_own_ms,
		live.stamp_card_ms,
		live.stamp_upgrade_ms,
		roll,
	]
	assert_int(plan.beats.size()).is_equal(lengths_by_beat.size())
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		var expected_ms: int = lengths_by_beat[index]
		if expected_ms == roll:
			assert_int(beat.roll_ms).is_greater(0)
			expected_ms = beat.roll_ms + live.gap_ms
		assert_int(beat.duration_ms).override_failure_message(str(index)).is_equal(expected_ms)
	_assert_unfitted_kind_lengths(live)
	# Close together, they merge into the first with the longest. The live beats are all at
	# least 240 ms long, so short ones are tuned in here.
	var tuning: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	tuning.stamp_card_ms = 150
	tuning.stamp_upgrade_ms = 150
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.BASE, 0, 0, 5, 0, "Bread"),
		_step(ScoreStep.StepType.MULTIPLIER, 0, 0, 2, 0, "Bread ×2"),
		_step(
			ScoreStep.StepType.MULTIPLIER,
			0,
			0,
			2,
			0,
			"Slot engine ×2",
			ScoreStep.SourceKind.UPGRADE
		),
		_step(ScoreStep.StepType.PAYOUT_OVERRIDE, 0, 0, 0, 0, "the 1st product pays €0"),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 0, 0, "Bread"),
	]
	var short: CountUpPlan = CountUpPlan.build(steps, 1000, CountUpContext.new(), tuning)
	assert_int(short.fit_stage).is_equal(0)
	# The upgrade stamp starts 150 ms after the card stamp: one 70 ms stop on the first.
	assert_int(short.beats[2].start_ms - short.beats[1].start_ms).is_equal(150)
	assert_int(short.beats[1].hit_stop_ms).is_equal(70)
	assert_int(short.beats[2].hit_stop_ms).is_equal(0)
	# The override is 300 ms after the group's first beat: a stop of its own.
	assert_int(short.beats[3].hit_stop_ms).is_equal(70)
	var lengths: int = short.pre_roll_ms
	for beat: CountUpBeat in short.beats:
		lengths += beat.duration_ms
	assert_int(short.planned_ms).is_equal(
		roundi(lengths / short.count_speed) + 140 + short.pause_ms
	)


## D5 and D6: a ding close after another hit-stop merges with it, but the merged hit-stop plays
## on the ding beat, after the ding, never at the earlier beat's landing. On the long row fitted
## to stage 5, the upgrade stamp before the first Milk payout is shorter than the merge window.
func test_a_merged_hit_stop_plays_on_the_ding_beat() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var steps: Array[ScoreStep] = _long_steps()
	# The first Milk payout takes the subtotal from 1 to 31.
	var plan: CountUpPlan = _plan(steps, 30, CountUpContext.new(1, 0))
	var quota_free: CountUpPlan = _plan(steps, 100000, CountUpContext.new(1, 0))
	assert_int(plan.fit_stage).is_equal(5)
	var ding: int = plan.ding_beat
	assert_int(plan.beats[ding].kind).is_equal(CountUpBeat.Kind.PAYOUT)
	var stamp: CountUpBeat = plan.beats[ding - 1]
	assert_int(stamp.kind).is_equal(CountUpBeat.Kind.STAMP)
	assert_int(steps[stamp.steps[0]].source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_int(plan.beats[ding].start_ms - stamp.start_ms).is_less_equal(tuning.hit_stop_merge_ms)
	# Without the ding, the stamp keeps its own hit-stop.
	assert_int(quota_free.beats[ding - 1].hit_stop_ms).is_equal(tuning.hit_stop_upgrade_stamp_ms)
	# With it, the longest of the two plays once, on the ding beat.
	assert_int(plan.beats[ding].hit_stop_ms).is_equal(tuning.hit_stop_ding_ms)
	assert_int(stamp.hit_stop_ms).is_equal(0)
	# Every other beat's hit-stop is the same as without the ding.
	for index: int in range(plan.beats.size()):
		if index != ding and index != ding - 1:
			var at: String = "beat %d" % index
			assert_int(plan.beats[index].hit_stop_ms).override_failure_message(at).is_equal(
				quota_free.beats[index].hit_stop_ms
			)


## #86 v6: the budget was 4-7 s (fit_target_ms 6500), ride gaps included; at the 0.8 tempo
## (2026-10-20) it is 5-8.75 s (fit_target_ms 8125).
func test_the_full_row_plans_five_to_nine_seconds_from_its_parts() -> void:
	for context: CountUpContext in [
		CountUpContext.new(1, 0),
		CountUpContext.new(1, 0, 1.5),
		CountUpContext.new(8, 0),
		CountUpContext.new(8, 160),
		CountUpContext.new(8, 160, 1.5),
	]:
		for quota: int in [40, 110, 500]:
			var plan: CountUpPlan = _plan(_full_steps(), quota, context)
			var where: String = (
				"shift %d best %d speed %s quota %d: %d ms (stage %d)"
				% [
					context.shift,
					context.best_so_far,
					context.speed_setting,
					quota,
					plan.planned_ms,
					plan.fit_stage,
				]
			)
			if context.speed_setting == 1.0:
				assert_int(plan.planned_ms).override_failure_message(where).is_between(5000, 8750)
			else:
				assert_int(plan.planned_ms).override_failure_message(where).is_less_equal(8750)
	# Shift 1, best 45: the total (110) is huge, the row is fitted down to stage 4, which may
	# leave it a little over fit_target_ms: its six rides and the ding's hold are never shortened.
	var first: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 0))
	assert_int(first.size).is_equal(CountUpPlan.Size.HUGE)
	assert_int(first.fit_stage).is_equal(4)
	assert_int(first.planned_ms).is_less_equal(8750)
	# planned_ms adds up its parts.
	for parts_context: CountUpContext in [
		CountUpContext.new(1, 0),
		CountUpContext.new(3, 47),
		CountUpContext.new(8, 160, 1.5),
	]:
		var parts: CountUpPlan = _plan(_full_steps(), 40, parts_context)
		var lengths: int = parts.pre_roll_ms
		var stops: int = 0
		var start: int = parts.pre_roll_ms
		for beat: CountUpBeat in parts.beats:
			# A ride gap comes before its beat's start.
			start += beat.ride_ms
			assert_int(beat.start_ms).is_equal(start)
			start += beat.duration_ms
			lengths += beat.ride_ms + beat.duration_ms
			stops += beat.hit_stop_ms
		var expected: int = roundi(lengths / parts.count_speed) + stops + parts.pause_ms
		assert_int(parts.planned_ms).is_equal(expected)


func test_no_shorter_row_plans_over_eight_and_three_quarter_seconds() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var rows: Array[Array] = []
	for row: String in GOLDEN_ROWS:
		rows.append(_golden_steps(row))
	var full: Array[String] = []
	full.assign(FULL_ROW.split(","))
	for length: int in range(1, full.size()):
		rows.append(_data_steps(",".join(full.slice(0, length))))
	for steps: Array in rows:
		var typed: Array[ScoreStep] = []
		typed.assign(steps)
		for quota: int in [1, 1000]:
			for shift: int in [1, 8]:
				var plan: CountUpPlan = _plan(typed, quota, CountUpContext.new(shift, 0))
				assert_int(plan.planned_ms).is_less_equal(8750)
				if plan.fit_stage == 0:
					assert_int(plan.planned_ms).is_less_equal(tuning.fit_target_ms)


## The stages on #60's tuning (no rides, a 100 ms ding, a 5500 ms target, tempo 1), where the
## shift 1 row stops at stage 2; the live tuning takes it to stage 4 (above).
func test_the_fit_runs_its_stages_in_order_and_spares_the_climax() -> void:
	var tuning: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	tuning.count_tempo = 1.0
	tuning.ride_ms = 0
	tuning.hit_stop_ding_ms = 100
	tuning.fit_target_ms = 5500
	# Shift 1, best 45: 6,000-odd ms planned before the fit.
	var plan: CountUpPlan = CountUpPlan.build(_full_steps(), 40, CountUpContext.new(1, 0), tuning)
	assert_int(plan.fit_stage).is_equal(2)
	# Stage 1: every gap is 40 ms.
	assert_int(plan.beats[2].duration_ms).is_equal(tuning.base_ms - 20)
	# Stage 2: the 2nd and 3rd Multipack landings are echoes without a hit-stop.
	assert_bool(plan.beats[14].echo).is_false()
	assert_int(plan.beats[14].duration_ms).is_equal(tuning.stamp_card_ms - 20)
	assert_int(plan.beats[14].hit_stop_ms).is_equal(50)
	for index: int in [18, 22]:
		assert_bool(plan.beats[index].echo).is_true()
		assert_int(plan.beats[index].duration_ms).is_equal(tuning.echo_ms)
		assert_int(plan.beats[index].hit_stop_ms).is_equal(0)
	# Merged plain beats and the ding keep their (gap-trimmed) length.
	assert_int(plan.beats[0].duration_ms).is_equal(tuning.merged_ms - 20)
	assert_int(plan.ding_beat).is_equal(19)
	assert_int(plan.beats[19].hit_stop_ms).is_equal(100)


func test_a_very_long_row_runs_every_stage_but_keeps_its_floors() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var steps: Array[ScoreStep] = _long_steps()
	var plan: CountUpPlan = _plan(steps, 30, CountUpContext.new(1, 0))
	assert_int(plan.fit_stage).is_equal(5)
	for beat: CountUpBeat in plan.beats:
		match beat.kind:
			CountUpBeat.Kind.MERGED_PLAIN:
				assert_int(beat.duration_ms).is_equal(tuning.merged_ms - 20)
			CountUpBeat.Kind.FIZZLE:
				assert_int(beat.duration_ms).is_greater_equal(tuning.fizzle_hold_min_ms)
			CountUpBeat.Kind.STAMP:
				if beat.first_stamp_on_card and not beat.echo:
					assert_int(beat.duration_ms).is_equal(tuning.stamp_card_ms - 20)
		if beat.echo:
			assert_int(beat.duration_ms).is_equal(tuning.echo_ms)
		if beat.ding:
			assert_int(beat.hit_stop_ms).is_equal(tuning.hit_stop_ding_ms)
		assert_int(beat.duration_ms).is_greater(0)
	# The uniform factor is at most 1.3: no shortenable beat runs faster.
	var base: CountUpBeat = plan.beats[4]
	assert_int(base.kind).is_equal(CountUpBeat.Kind.BASE)
	assert_int(base.duration_ms).is_greater_equal(floori((tuning.base_ms - 20) / 1.3))
	assert_int(base.duration_ms).is_less(tuning.base_ms - 20)
	assert_int(plan.pause_ms).is_equal(tuning.pause_huge_ms)
	# Every shortenable beat runs at the BASE beat's factor, on its length after stages 1-4.
	var factor: float = base.duration_ms / float(tuning.base_ms - 20)
	var checked: Dictionary[CountUpBeat.Kind, int] = {}
	for beat: CountUpBeat in plan.beats:
		var unscaled: int = _fitted_length_before_factor(steps, beat, tuning)
		if unscaled <= 0:
			continue
		checked[beat.kind] = checked.get(beat.kind, 0) + 1
		if beat.kind == CountUpBeat.Kind.PAYOUT:
			assert_int(beat.roll_ms).is_equal(tuning.fit_roll_max_ms)
		var where: String = "%s at %d ms" % [CountUpBeat.Kind.keys()[beat.kind], beat.start_ms]
		var ratio: float = beat.duration_ms / float(unscaled)
		assert_float(ratio).override_failure_message(where).is_equal_approx(factor, 0.01)
	# Stage 3 cut every roll but the ding's, which keeps its full one.
	assert_int(checked.get(CountUpBeat.Kind.PAYOUT, 0)).is_equal(6)
	assert_int(plan.beats[plan.ding_beat].kind).is_equal(CountUpBeat.Kind.PAYOUT)
	assert_int(plan.beats[plan.ding_beat].roll_ms).is_greater(tuning.fit_roll_max_ms)
	# Both bonus lengths, both stamp lengths (upgrades and Milk's later own stamp), tag, link.
	assert_int(checked.get(CountUpBeat.Kind.BONUS, 0)).is_equal(14)
	assert_int(checked.get(CountUpBeat.Kind.STAMP, 0)).is_equal(8)
	assert_int(checked.get(CountUpBeat.Kind.TAG, 0)).is_equal(1)
	assert_int(checked.get(CountUpBeat.Kind.LINK, 0)).is_equal(1)
	# With a far smaller target and a looser factor, the fizzle stops at its grey hold.
	var tight: CountUpTuning = tuning.duplicate()
	tight.fit_target_ms = 1000
	tight.fit_max_factor = 2.0
	var squeezed: CountUpPlan = CountUpPlan.build(steps, 30, CountUpContext.new(1, 0), tight)
	assert_int(squeezed.fit_stage).is_equal(5)
	assert_int(squeezed.beats[4].duration_ms).is_equal(roundi((tuning.base_ms - 20) / 2.0))
	var fizzle: CountUpBeat = squeezed.beats[squeezed.beats.size() - 1]
	assert_int(fizzle.kind).is_equal(CountUpBeat.Kind.FIZZLE)
	assert_int(fizzle.duration_ms).is_equal(tuning.fizzle_hold_min_ms)


func test_an_empty_row_plans_only_the_pre_roll_and_the_pause() -> void:
	var plan: CountUpPlan = _plan([], 10)
	assert_int(plan.beats.size()).is_equal(0)
	assert_int(plan.total).is_equal(0)
	assert_bool(plan.quota_reached).is_false()
	# At the 0.8 tempo, the pre-roll's 120 ms run 1.25x slower; the pause stays real time.
	assert_int(plan.planned_ms).is_equal(150 + 300)
	assert_int(plan.bag_ms).is_equal(300)


## Two plans of one row for different quotas: the same intensity, fit stage, lengths and rolls
## on every beat but either plan's ding beat (spared by the fit, so it may be longer).
func _assert_same_but_the_ding(a: CountUpPlan, b: CountUpPlan, where: String) -> void:
	assert_int(a.fit_stage).override_failure_message(where).is_equal(b.fit_stage)
	assert_int(a.beats.size()).is_equal(b.beats.size())
	for index: int in range(a.beats.size()):
		var x: CountUpBeat = a.beats[index]
		var y: CountUpBeat = b.beats[index]
		assert_float(x.rattle_px).is_equal(y.rattle_px)
		assert_float(x.punch_boost).is_equal(y.punch_boost)
		assert_int(x.note).is_equal(y.note)
		assert_bool(x.echo).is_equal(y.echo)
		if index == a.ding_beat or index == b.ding_beat:
			var spared: CountUpBeat = x if index == a.ding_beat else y
			var other: CountUpBeat = y if index == a.ding_beat else x
			assert_int(spared.duration_ms).is_greater_equal(other.duration_ms)
			continue
		var at: String = "%s, beat %d" % [where, index]
		assert_int(x.duration_ms).override_failure_message(at).is_equal(y.duration_ms)
		assert_int(x.roll_ms).override_failure_message(at).is_equal(y.roll_ms)


## The D7 lengths the live row does not show: bonuses from another source, a reset fizzle and
## the context-pass tag and link, on a hand-built row that needs no fit.
func _assert_unfitted_kind_lengths(live: CountUpTuning) -> void:
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.TAG_ADDED, 1, 0, 0, 0, "Sticker"),
		_step(ScoreStep.StepType.LINKED, 1, 0, 0, 0, "Bundle"),
		_step(ScoreStep.StepType.BASE, 1, 1, 4, 0, "Milk"),
		_step(ScoreStep.StepType.FLAT, 1, 1, 1, 0, "Milk: earlier Breakfast"),
		_step(ScoreStep.StepType.FLAT, 1, 0, 2, 0, "Coffee +2"),
		_step(ScoreStep.StepType.FLAT, 1, 1, 1, 0, "Upgrade +1", ScoreStep.SourceKind.UPGRADE),
		_step(ScoreStep.StepType.COPY, 1, 1, 4, 0, "Repeat"),
		_step(
			ScoreStep.StepType.MULTIPLIER, 1, 1, 2, 0, "Spot ×2", ScoreStep.SourceKind.INSPECTION
		),
		_step(ScoreStep.StepType.PAYOUT, 1, 1, 24, 24, "Milk"),
		_step(ScoreStep.StepType.WASTED, 2, 0, 0, 24, "Eggs ×2"),
		_step(ScoreStep.StepType.WASTED, 2, 2, 0, 24, "Coffee +2"),
		_step(ScoreStep.StepType.WASTED, 2, 2, 0, 24, "Slot engine", ScoreStep.SourceKind.UPGRADE),
	]
	var plan: CountUpPlan = CountUpPlan.build(steps, 1000, CountUpContext.new(), live)
	assert_int(plan.fit_stage).is_equal(0)
	var expected: Array[int] = [
		live.tag_ms,
		live.link_ms,
		live.base_ms,
		live.bonus_own_ms,
		live.bonus_other_ms,
		live.bonus_other_ms,
		live.bonus_other_ms,
		live.stamp_upgrade_ms,
		plan.beats[8].roll_ms + live.gap_ms,
		live.fizzle_reset_ms,
		live.fizzle_ms,
		live.fizzle_ms,
	]
	assert_int(plan.beats.size()).is_equal(expected.size())
	for index: int in range(expected.size()):
		var beat: CountUpBeat = plan.beats[index]
		assert_int(beat.duration_ms).override_failure_message(str(index)).is_equal(expected[index])
	# An inspection stamp is no card stamp: the upgrade hit-stop.
	assert_int(plan.beats[7].hit_stop_ms).is_equal(live.hit_stop_upgrade_stamp_ms)


static func _plan(
	steps: Array[ScoreStep], quota: int = 40, context: CountUpContext = null
) -> CountUpPlan:
	var used: CountUpContext = context if context != null else CountUpContext.new()
	return CountUpPlan.build(steps, quota, used, load(TUNING))


## The full reference row on the live data, with Coupon engine, Slot engine and a Spot check.
static func _full_steps() -> Array[ScoreStep]:
	return _data_steps(FULL_ROW)


## A row of live cards with Coupon engine, Slot engine and a Spot check.
static func _data_steps(ids: String) -> Array[ScoreStep]:
	var upgrades: Array[UpgradeDefinition] = [
		load("res://data/upgrades/coupon_engine.tres"),
		load("res://data/upgrades/slot_engine.tres"),
	]
	var inspections: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	return Scoring.score(_row(ids, CARDS), upgrades, inspections).steps


static func _golden_steps(ids: String) -> Array[ScoreStep]:
	return Scoring.score(_row(ids, FIXTURE_DIR)).steps


static func _row(ids: String, folder: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [folder, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _step(
	type: ScoreStep.StepType,
	slot: int,
	source_slot: int,
	value: int,
	subtotal: int,
	text: String,
	source_kind: ScoreStep.SourceKind = ScoreStep.SourceKind.CARD
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.source_slot = source_slot
	step.value = value
	step.subtotal = subtotal
	step.text = text
	step.source_kind = source_kind
	return step


## One card with `gains` own flat bonuses, paying `payout` (default: one per bonus).
static func _flat_steps(gains: int, payout: int = -1) -> Array[ScoreStep]:
	var paid: int = payout if payout >= 0 else gains
	var steps: Array[ScoreStep] = [_step(ScoreStep.StepType.BASE, 0, 0, 0, 0, "Card")]
	for _index: int in range(gains):
		steps.append(_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 0, 0, paid, paid, "Card"))
	return steps


## A worst-case row: a context-pass tag and link, an armed ×3 landing on seven products that
## each have an own flat, a bonus from another card and an upgrade stamp (the 2nd product also
## a later stamp of its own), and a reset fizzle.
static func _long_steps() -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.TAG_ADDED, 1, 0, 0, 0, "Sticker"),
		_step(ScoreStep.StepType.LINKED, 1, 0, 0, 0, "Bundle"),
		_step(ScoreStep.StepType.BASE, 0, 0, 1, 0, "Multipack"),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 1, 1, "Multipack"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 3, 1, "Multipack ×3"),
	]
	var subtotal: int = 1
	for slot: int in range(1, 8):
		subtotal += 30
		steps.append(_step(ScoreStep.StepType.BASE, slot, slot, 4, subtotal - 30, "Milk"))
		steps.append(
			_step(ScoreStep.StepType.FLAT, slot, slot, 1, subtotal - 30, "Milk: earlier Breakfast")
		)
		steps.append(_step(ScoreStep.StepType.FLAT, slot, 0, 2, subtotal - 30, "Coffee +2"))
		steps.append(
			_step(ScoreStep.StepType.MULTIPLIER, slot, 0, 3, subtotal - 30, "Multipack ×3")
		)
		if slot == 2:
			# A later stamp of the card's own: a card stamp that is not its first.
			steps.append(
				_step(ScoreStep.StepType.MULTIPLIER, slot, slot, 2, subtotal - 30, "Milk ×2")
			)
		steps.append(
			_step(
				ScoreStep.StepType.MULTIPLIER,
				slot,
				slot,
				2,
				subtotal - 30,
				"Slot engine ×2",
				ScoreStep.SourceKind.UPGRADE
			)
		)
		steps.append(_step(ScoreStep.StepType.PAYOUT, slot, slot, 30, subtotal, "Milk"))
	steps.append(_step(ScoreStep.StepType.WASTED, 7, 3, 0, subtotal, "Eggs ×2"))
	return steps


## A shortenable beat's length after fit stages 1 to 4 on _long_steps(), worked out from the
## D7 table and the beat's first step; 0 for the beats stage 5 never shortens (merged, ding,
## first card stamp, echo) and for the armed and fizzle beats, which this does not check.
static func _fitted_length_before_factor(
	steps: Array[ScoreStep], beat: CountUpBeat, tuning: CountUpTuning
) -> int:
	if beat.ding or beat.echo or beat.first_stamp_on_card:
		return 0
	var step: ScoreStep = steps[beat.steps[0]]
	var from_card: bool = step.source_kind == ScoreStep.SourceKind.CARD
	var cut: int = tuning.gap_ms - tuning.fit_gap_ms
	match beat.kind:
		CountUpBeat.Kind.BASE:
			return tuning.base_ms - cut
		CountUpBeat.Kind.PAYOUT:
			# Stage 3 cut the roll to fit_roll_max_ms (asserted by the caller).
			return tuning.fit_roll_max_ms + tuning.fit_gap_ms
		CountUpBeat.Kind.TAG:
			return _fly_in(tuning.tag_ms - cut, tuning)
		CountUpBeat.Kind.LINK:
			return _fly_in(tuning.link_ms - cut, tuning)
		CountUpBeat.Kind.BONUS:
			var own: bool = (
				from_card
				and step.source_slot == step.slot
				and step.step_type == ScoreStep.StepType.FLAT
			)
			if own:
				return tuning.bonus_own_ms - cut
			return _fly_in(tuning.bonus_other_ms - cut, tuning)
		CountUpBeat.Kind.STAMP:
			if from_card:
				# A card's later stamp: no fly-in.
				return tuning.stamp_card_ms - cut
			return _fly_in(tuning.stamp_upgrade_ms - cut, tuning)
	return 0


## Stage 4 on a fly-in, tag or link of `length` ms.
static func _fly_in(length: int, tuning: CountUpTuning) -> int:
	return mini(length, maxi(tuning.fly_in_min_ms, roundi(length * tuning.fly_in_factor)))


static func _gain_notes(plan: CountUpPlan) -> PackedInt32Array:
	var notes: PackedInt32Array = PackedInt32Array()
	for beat: CountUpBeat in plan.beats:
		if CountUpPlan.is_gain_beat(beat):
			notes.append(beat.note)
	return notes


static func _ding_count(plan: CountUpPlan) -> int:
	var count: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.ding:
			count += 1
	return count


## The hit-stop that plays for beat `index`: its own, or the one of the earlier beat it merged
## into (the latest beat with a hit-stop at or before it).
static func _hit_stop_at(plan: CountUpPlan, index: int) -> int:
	for earlier: int in range(index, -1, -1):
		if plan.beats[earlier].hit_stop_ms > 0:
			return plan.beats[earlier].hit_stop_ms
	return 0
