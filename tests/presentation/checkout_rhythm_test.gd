extends GdUnitTestSuite
## V3's paid subtotal and variable tempo use the real score; no score is recalculated in UI.

const CARDS := "res://data/cards/%s.tres"


func test_only_payouts_move_the_register_and_the_quota_dings_on_a_payment() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,bread,banana,banana,repeat"))
	var plan: CountUpPlan = _plan(result, 10)
	var paid: int = 0
	for beat: CountUpBeat in plan.beats:
		assert_int(beat.shown_from).is_equal(paid)
		if CountUpPlan.is_payout_beat(beat):
			paid = beat.subtotal
		else:
			assert_bool(CountUpPlan.is_landing(beat)).is_false()
			assert_bool(beat.ding).is_false()
		assert_int(beat.shown_to).is_equal(paid)
	assert_int(paid).is_equal(result.total)
	assert_bool(CountUpPlan.is_payout_beat(plan.beats[plan.ding_beat])).is_true()


func test_a_last_payment_reaching_the_quota_celebrates_at_that_payment() -> void:
	var result: ScoreResult = Scoring.score(_row("bread"))
	var plan: CountUpPlan = _plan(result, result.total)
	assert_int(plan.ding_beat).is_equal(0)
	assert_bool(plan.chip_at_total).is_false()
	assert_int(plan.beats[0].hit_stop_ms).is_equal(850)


func test_a_plain_item_scans_and_pays_in_less_than_a_second() -> void:
	var result: ScoreResult = Scoring.score(_row("bread,bread"))
	var plan: CountUpPlan = _plan(result)
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	assert_int(plan.beats[0].duration_ms).is_equal(tuning.base_ms + tuning.payout_small_ms)
	assert_int(plan.beats[1].duration_ms).is_equal(
		tuning.base_ms + tuning.payout_small_ms + tuning.last_payout_extra_ms
	)
	assert_int(plan.beats[0].duration_ms + tuning.ride_ms).is_less(1000)


func test_multiplier_beats_are_heavier_than_adds() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,banana,banana"))
	var plan: CountUpPlan = _plan(result)
	var adds: int = 0
	var multipliers: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.kind == CountUpBeat.Kind.BONUS:
			adds += 1
			assert_int(beat.duration_ms).is_less_equal(240)
		elif beat.kind == CountUpBeat.Kind.STAMP:
			multipliers += 1
			assert_int(beat.duration_ms).is_equal(460)
	assert_int(adds).is_greater(0)
	assert_int(multipliers).is_greater(0)


func test_adjacent_bonus_steps_identify_their_real_visual_giver_without_changing_scores() -> void:
	var row: Array[CardInstance] = _row("strawberries,banana,banana")
	var result: ScoreResult = Scoring.score(row)
	assert_int(Scoring.total(row)).is_equal(result.total)
	var found: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type != ScoreStep.StepType.FLAT:
			continue
		if step.slot == 0:
			assert_int(step.support_slot).is_equal(1)
			found += 1
		elif step.slot == 2:
			assert_int(step.support_slot).is_equal(1)
			found += 1
		assert_int(step.source_slot).is_equal(step.slot)
	assert_int(found).is_equal(2)


static func _plan(result: ScoreResult, quota: int = 10000) -> CountUpPlan:
	return CountUpPlan.build(result.steps, quota, CountUpContext.new(), load(CountUp.TUNING_PATH))


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id), row.size() + 1))
	return row
