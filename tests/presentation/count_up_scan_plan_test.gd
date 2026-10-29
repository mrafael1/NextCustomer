extends GdUnitTestSuite
## CountUpPlan's scan groups (#86 v6): the item at the scanner for every beat, each group's first
## and last beats, and the ride gaps before the first ones (counted in planned_ms, never shortened
## by the fit). Pure data like count_up_plan_test, whose rows and helpers it uses.

const TUNING := "res://data/balance/count_up.tres"
const PLAN := preload("res://tests/presentation/count_up_plan_test.gd")


## #86 v6: a scan group starts at each BASE or MERGED_PLAIN beat and runs to the beat before the
## next; every beat knows the item at the scanner; the first beat of each group but item 0's (in
## the first cell) has a ride gap. On the reference row: seven items, six rides.
func test_the_full_row_scans_its_items_in_turn() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var plan: CountUpPlan = PLAN._plan(PLAN._full_steps())
	var openings: Array[int] = []
	var closings: Array[int] = []
	var rides: int = 0
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		var at: String = "beat %d" % index
		# No context pass and no trailing beat on another item: the item is the beat's own.
		assert_int(beat.scan_slot).override_failure_message(at).is_equal(beat.slot)
		var scans: bool = beat.kind in [CountUpBeat.Kind.BASE, CountUpBeat.Kind.MERGED_PLAIN]
		assert_bool(beat.opens_slot).override_failure_message(at).is_equal(scans)
		if beat.opens_slot:
			openings.append(index)
			var expected: int = tuning.ride_ms if beat.slot > 0 else 0
			assert_int(beat.ride_ms).override_failure_message(at).is_equal(expected)
			rides += beat.ride_ms
		else:
			assert_int(beat.ride_ms).override_failure_message(at).is_equal(0)
		if beat.closes_slot:
			closings.append(index)
	assert_array(openings).is_equal([0, 2, 5, 9, 12, 16, 21])
	assert_array(closings).is_equal([1, 4, 8, 11, 15, 20, 24])
	assert_int(rides).is_equal(6 * tuning.ride_ms)


## #86 v6 on a hand-built row: the context pass (a tag and a link) plays before any scan, with no
## item at the scanner; the first item scanned stands in the second cell (the first is empty), so
## it rides in; an Egg-style reset of the bagged item and a trailing lost effect play while the
## last item is at the scanner, in its group, which they close. A row whose first item stands in
## the first cell has no ride before it.
func test_the_scan_groups_follow_the_scanner_not_the_step_slot() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var steps: Array[ScoreStep] = [
		PLAN._step(ScoreStep.StepType.TAG_ADDED, 2, 1, 0, 0, "Sticker"),
		PLAN._step(ScoreStep.StepType.LINKED, 1, 2, 0, 0, "Bundle"),
		PLAN._step(ScoreStep.StepType.BASE, 1, 1, 4, 0, "Eggs"),
		PLAN._step(ScoreStep.StepType.PAYOUT, 1, 1, 4, 4, "Eggs"),
		PLAN._step(ScoreStep.StepType.EFFECT_ARMED, 1, 1, 2, 4, "Eggs ×2"),
		PLAN._step(ScoreStep.StepType.BASE, 2, 2, 5, 4, "Bread"),
		PLAN._step(ScoreStep.StepType.FLAT, 2, 2, 1, 4, "Bread: own"),
		PLAN._step(ScoreStep.StepType.WASTED, 1, 2, 0, 4, "Eggs ×2"),
		PLAN._step(ScoreStep.StepType.PAYOUT, 2, 2, 6, 10, "Bread"),
		PLAN._step(ScoreStep.StepType.WASTED, 1, 1, 0, 10, "Eggs ×2"),
	]
	var plan: CountUpPlan = CountUpPlan.build(steps, 1000, CountUpContext.new(), tuning)
	var kinds: PackedStringArray = PackedStringArray()
	var scans: Array[int] = []
	var opens: Array[bool] = []
	var closes: Array[bool] = []
	var rides: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		kinds.append(CountUpBeat.Kind.keys()[beat.kind])
		scans.append(beat.scan_slot)
		opens.append(beat.opens_slot)
		closes.append(beat.closes_slot)
		rides.append(beat.ride_ms)
	assert_str(" ".join(kinds)).is_equal(
		"TAG LINK MERGED_PLAIN ARMED BASE BONUS FIZZLE PAYOUT FIZZLE"
	)
	assert_array(scans).is_equal([-1, -1, 1, 1, 2, 2, 2, 2, 2])
	assert_array(opens).is_equal([false, false, true, false, true, false, false, false, false])
	assert_array(closes).is_equal([false, false, false, true, false, false, false, false, true])
	var ride: int = tuning.ride_ms
	assert_array(rides).is_equal([0, 0, ride, 0, ride, 0, 0, 0, 0])
	# The reset fizzle is on the bagged item, the scanner on the item after it.
	assert_int(plan.beats[6].slot).is_equal(1)
	# Each ride comes before its beat's start.
	var link: CountUpBeat = plan.beats[1]
	assert_int(plan.beats[2].start_ms).is_equal(link.start_ms + link.duration_ms + ride)
	# Item 0 in the first cell: no ride; one item is one group.
	var single: CountUpPlan = PLAN._plan(PLAN._flat_steps(1))
	assert_int(single.beats.size()).is_equal(3)
	assert_int(single.beats[0].ride_ms).is_equal(0)
	for index: int in range(3):
		assert_int(single.beats[index].scan_slot).is_equal(0)
		assert_bool(single.beats[index].opens_slot).is_equal(index == 0)
		assert_bool(single.beats[index].closes_slot).is_equal(index == 2)


## #86 v6: ride gaps count in planned_ms at the count's speed like beats, and no fit stage ever
## shortens them: on the worst-case row fitted to stage 4 or 5, every item after the first rides
## for the whole ride_ms, at any speed; the last item's bag hop is never counted.
func test_ride_gaps_count_in_the_plan_and_survive_the_fit() -> void:
	var tuning: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	tuning.fit_target_ms = 2000
	for context: CountUpContext in [CountUpContext.new(1, 0), CountUpContext.new(8, 0, 1.5)]:
		var plan: CountUpPlan = CountUpPlan.build(PLAN._long_steps(), 30, context, tuning)
		assert_int(plan.fit_stage).is_greater_equal(4)
		var rides: int = 0
		var lengths: int = plan.pre_roll_ms
		var stops: int = 0
		for beat: CountUpBeat in plan.beats:
			if beat.opens_slot and beat.scan_slot > 0:
				assert_int(beat.ride_ms).is_equal(tuning.ride_ms)
			rides += beat.ride_ms
			lengths += beat.ride_ms + beat.duration_ms
			stops += beat.hit_stop_ms
		# Multipack in the first cell, then seven Milks.
		assert_int(rides).is_equal(7 * tuning.ride_ms)
		var expected: int = roundi(lengths / plan.count_speed) + stops + plan.pause_ms
		assert_int(plan.planned_ms).is_equal(expected)
