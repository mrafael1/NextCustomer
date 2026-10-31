extends GdUnitTestSuite
## The checkout cheering's plan data (#120, CountUpPlan's _set_cheer and _set_cheer_lines): every
## paid item has a tier, bigger for a bigger payout or a combo; each bonus line pops one standee
## at its item's tier, up to cheer_line_cap per item, and a payout pops none of its own, all from
## the tuning in data/balance/count_up.tres. Pure data: hand-built steps and rows scored with
## Scoring.score().

const TUNING := "res://data/balance/count_up.tres"
const CARDS := "res://data/cards/%s.tres"


func test_every_paid_item_has_a_tier_and_a_plain_one_pops_nothing() -> void:
	var tuning: CountUpTuning = load(TUNING)
	# The best so far is the tuning's floor (45): big from max(10, 0.2 x 45) = 10, huge from 22.5.
	var plan: CountUpPlan = _plan(_plain([3, 10, 30, 0]))
	var tiers: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		tiers.append(beat.cheer_tier)
		assert_int(beat.cheer_count).is_equal(0)
		assert_bool(beat.cheer_combo).is_false()
	assert_array(tiers).is_equal([1, 2, 3, 0])
	assert_int(tuning.cheer_scales[2]).is_greater(tuning.cheer_scales[0])


## Each bonus line (a +N above 0, a x above 1, a copy) pops one standee at its item's tier; a
## penalty or a x1 pops none; an item pops at most cheer_line_cap.
func test_each_bonus_line_pops_one_standee_up_to_the_cap() -> void:
	var tuning: CountUpTuning = load(TUNING)
	var steps: Array[ScoreStep] = []
	# Slot 0: +2, -1, x1, x2: two lines, paying 30 (huge).
	steps.append(_step(ScoreStep.StepType.BASE, 0, 14, 14))
	steps.append(_step(ScoreStep.StepType.FLAT, 0, 2, 16))
	steps.append(_step(ScoreStep.StepType.FLAT, 0, -1, 15))
	steps.append(_step(ScoreStep.StepType.MULTIPLIER, 0, 1, 15))
	steps.append(_step(ScoreStep.StepType.MULTIPLIER, 0, 2, 30))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 0, 30, 30))
	# Slot 1: cap + 2 lines of +1, paying small.
	var subtotal: int = 31
	steps.append(_step(ScoreStep.StepType.BASE, 1, 1, subtotal))
	for _line: int in range(tuning.cheer_line_cap + 2):
		subtotal += 1
		steps.append(_step(ScoreStep.StepType.FLAT, 1, 1, subtotal))
	var paid: int = subtotal - 30
	steps.append(_step(ScoreStep.StepType.PAYOUT, 1, paid, subtotal))
	var plan: CountUpPlan = _plan(steps)
	var popped: Dictionary[int, int] = {}
	for beat: CountUpBeat in plan.beats:
		if CountUpPlan.is_payout_beat(beat):
			assert_int(beat.cheer_count).is_equal(0)
			continue
		if beat.cheer_count == 0:
			continue
		assert_int(beat.cheer_count).is_equal(1)
		var payout: CountUpBeat = _payouts(plan)[beat.slot]
		assert_int(beat.cheer_tier).is_equal(payout.cheer_tier)
		popped[beat.slot] = popped.get(beat.slot, 0) + 1
	assert_int(popped.get(0, 0)).is_equal(2)
	assert_int(popped.get(1, 0)).is_equal(tuning.cheer_line_cap)
	assert_int(tuning.cheer_line_cap).is_equal(6)


func test_the_tiers_follow_the_best_so_far() -> void:
	var context: CountUpContext = CountUpContext.new()
	context.best_so_far = 200
	# big from max(10, 0.2 x 200) = 40, huge from 0.5 x 200 = 100.
	var plan: CountUpPlan = _plan(_plain([30, 40, 99, 100]), context)
	var tiers: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		tiers.append(beat.cheer_tier)
	assert_array(tiers).is_equal([1, 2, 2, 3])


func test_a_combo_cheers_one_tier_more_up_to_huge() -> void:
	var steps: Array[ScoreStep] = []
	# Slot 0: its own +2 (not a combo) pays 5, small.
	steps.append(_step(ScoreStep.StepType.BASE, 0, 3, 3))
	steps.append(_step(ScoreStep.StepType.FLAT, 0, 2, 5))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 0, 5, 5))
	# Slot 1: +2 from slot 0 (a combo) pays 5: small, one tier more.
	steps.append(_step(ScoreStep.StepType.BASE, 1, 3, 8))
	steps.append(_step(ScoreStep.StepType.FLAT, 1, 2, 10, 0))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 1, 5, 10))
	# Slot 2: an upgrade's x2 (a combo) on a huge payout stays huge.
	steps.append(_step(ScoreStep.StepType.BASE, 2, 20, 30))
	var stamp: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, 2, 2, 50, -1)
	stamp.source_kind = ScoreStep.SourceKind.UPGRADE
	steps.append(stamp)
	steps.append(_step(ScoreStep.StepType.PAYOUT, 2, 40, 50))
	var plan: CountUpPlan = _plan(steps)
	var paid: Array[CountUpBeat] = _payouts(plan)
	assert_int(paid.size()).is_equal(3)
	assert_bool(paid[0].cheer_combo).is_false()
	assert_int(paid[0].cheer_tier).is_equal(1)
	assert_bool(paid[1].cheer_combo).is_true()
	assert_int(paid[1].cheer_tier).is_equal(2)
	assert_bool(paid[2].cheer_combo).is_true()
	assert_int(paid[2].cheer_tier).is_equal(CountUpPlan.CHEER_TOP_TIER)


func test_a_penalty_from_another_source_is_no_combo() -> void:
	var steps: Array[ScoreStep] = []
	# Slot 0: Late delivery's -2 (an inspection FLAT) pays 3, small, no combo.
	steps.append(_step(ScoreStep.StepType.BASE, 0, 5, 5))
	var late: ScoreStep = _step(ScoreStep.StepType.FLAT, 0, -2, 3)
	late.source_kind = ScoreStep.SourceKind.INSPECTION
	steps.append(late)
	steps.append(_step(ScoreStep.StepType.PAYOUT, 0, 3, 3))
	# Slot 1: a x1 from another item lifts nothing either.
	steps.append(_step(ScoreStep.StepType.BASE, 1, 3, 6))
	steps.append(_step(ScoreStep.StepType.MULTIPLIER, 1, 1, 6, 0))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 1, 3, 6))
	var paid: Array[CountUpBeat] = _payouts(_plan(steps))
	assert_int(paid.size()).is_equal(2)
	for beat: CountUpBeat in paid:
		assert_bool(beat.cheer_combo).is_false()
		assert_int(beat.cheer_tier).is_equal(1)
	assert_bool(CountUpPlan.is_cheer_combo(late)).is_false()


func test_reduced_motion_keeps_the_cheers() -> void:
	var context: CountUpContext = CountUpContext.new()
	context.reduced_motion = true
	var plan: CountUpPlan = _plan(_plain([3, 30]), context)
	assert_int(plan.beats[0].cheer_tier).is_equal(1)
	assert_int(plan.beats[1].cheer_tier).is_equal(3)
	assert_float(plan.beats[1].rattle_px).is_equal(0.0)


func test_a_scored_row_cheers_on_its_lines_and_a_copy_is_a_combo() -> void:
	var result: ScoreResult = Scoring.score(_row("bread,repeat,eggs,banana,banana"))
	var plan: CountUpPlan = _plan(result.steps)
	var copies: int = 0
	var lines: int = 0
	for beat: CountUpBeat in plan.beats:
		if not CountUpPlan.is_payout_beat(beat):
			var line: bool = CountUpPlan.is_cheer_line(result.steps[beat.steps[0]])
			var lifts: bool = (
				beat.kind == CountUpBeat.Kind.BONUS or beat.kind == CountUpBeat.Kind.STAMP
			)
			assert_int(beat.cheer_count).is_equal(1 if line and lifts else 0)
			lines += beat.cheer_count
			continue
		assert_int(beat.cheer_count).is_equal(0)
		assert_bool(beat.cheer_tier > 0).is_equal(beat.payout > 0)
		for index: int in range(beat.steps[-1]):
			var step: ScoreStep = result.steps[index]
			if step.slot == beat.slot and step.step_type == ScoreStep.StepType.COPY:
				copies += 1
				assert_bool(beat.cheer_combo).is_true()
	assert_int(copies).is_greater(0)
	assert_int(lines).is_greater(0)


static func _plan(steps: Array[ScoreStep], context: CountUpContext = null) -> CountUpPlan:
	var around: CountUpContext = context if context != null else CountUpContext.new()
	return CountUpPlan.build(steps, 10000, around, load(TUNING))


## Plain items paying `payouts`, one per slot.
static func _plain(payouts: Array[int]) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	var subtotal: int = 0
	for slot: int in range(payouts.size()):
		subtotal += payouts[slot]
		steps.append(_step(ScoreStep.StepType.BASE, slot, payouts[slot], subtotal))
		steps.append(_step(ScoreStep.StepType.PAYOUT, slot, payouts[slot], subtotal))
	return steps


static func _step(
	type: ScoreStep.StepType, slot: int, value: int, subtotal: int, source_slot: int = -2
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.value = value
	step.subtotal = subtotal
	step.source_slot = slot if source_slot == -2 else source_slot
	return step


static func _payouts(plan: CountUpPlan) -> Array[CountUpBeat]:
	var paid: Array[CountUpBeat] = []
	for beat: CountUpBeat in plan.beats:
		if CountUpPlan.is_payout_beat(beat):
			paid.append(beat)
	return paid


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id), row.size() + 1))
	return row
