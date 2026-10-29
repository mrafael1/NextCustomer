extends GdUnitTestSuite
## PaymentEquation (Checkout Rhythm v3): "€X × N → €Y" read from an item's real ScoreSteps, only
## when its multipliers take the value before the first one exactly to its payout; every other
## shape has none. The plan carries it on the PAYOUT beat without changing any beat's length.

const CARDS := "res://data/cards/%s.tres"
const ARROW := "→"
## "eggs,banana,banana"'s beat lengths at v0.66 (HEAD before Checkout Rhythm v3.1).
const V066_DURATIONS: Array[int] = [420, 360, 180, 460, 240, 180, 240, 540]

var _folder: String = ""


func before_test() -> void:
	# Nothing here saves or logs, but the event log and saves still point at a temporary folder.
	_folder = "user://test_payment_equation_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_plain_item_has_no_equation() -> void:
	var steps: Array[ScoreStep] = [_base(0, 3), _payout(0, 3)]
	assert_object(PaymentEquation.of(steps, 0)).is_null()


func test_a_flat_only_item_has_no_equation() -> void:
	var steps: Array[ScoreStep] = [_base(0, 3), _flat(0, 2, 5), _payout(0, 5)]
	assert_object(PaymentEquation.of(steps, 0)).is_null()


func test_flats_fold_into_the_start_and_stacked_factors_multiply() -> void:
	var steps: Array[ScoreStep] = [
		_base(0, 2), _flat(0, 2, 4), _mul(0, 3, 12), _mul(0, 2, 24), _payout(0, 24)
	]
	var equation: PaymentEquation = PaymentEquation.of(steps, 0)
	assert_object(equation).is_not_null()
	assert_int(equation.start).is_equal(4)
	assert_int(equation.factor).is_equal(6)
	assert_int(equation.payout).is_equal(24)
	assert_str(equation.text(ARROW)).is_equal("€4 × 6 → €24")
	assert_str(equation.factor_text()).is_equal("× 6")


func test_four_digit_amounts_read_in_full() -> void:
	var steps: Array[ScoreStep] = [
		_base(0, 125), _mul(0, 10, 1250), _mul(0, 2, 2500), _payout(0, 2500)
	]
	assert_str(PaymentEquation.of(steps, 0).text(ARROW)).is_equal("€125 × 20 → €2500")


func test_a_zero_payout_coupon_has_no_equation() -> void:
	var steps: Array[ScoreStep] = [_base(0, 0), _mul(0, 3, 0), _payout(0, 0)]
	assert_object(PaymentEquation.of(steps, 0)).is_null()


func test_a_copy_or_an_override_has_no_equation() -> void:
	var copy: ScoreStep = _flat(0, 4, 6)
	copy.step_type = ScoreStep.StepType.COPY
	var copied: Array[ScoreStep] = [_base(0, 2), copy, _mul(0, 2, 12), _payout(0, 12)]
	assert_object(PaymentEquation.of(copied, 0)).is_null()
	var override: ScoreStep = _payout(0, 0)
	override.step_type = ScoreStep.StepType.PAYOUT_OVERRIDE
	var overridden: Array[ScoreStep] = [_base(0, 4), _mul(0, 2, 8), override, _payout(0, 0)]
	assert_object(PaymentEquation.of(overridden, 0)).is_null()


func test_a_flat_after_a_factor_or_numbers_that_do_not_multiply_out_have_none() -> void:
	var late: Array[ScoreStep] = [_base(0, 2), _mul(0, 2, 4), _flat(0, 1, 5), _payout(0, 5)]
	assert_object(PaymentEquation.of(late, 0)).is_null()
	var odd: Array[ScoreStep] = [_base(0, 2), _mul(0, 2, 4), _payout(0, 5)]
	assert_object(PaymentEquation.of(odd, 0)).is_null()


func test_other_slots_and_steps_after_the_payout_are_left_out() -> void:
	var armed: ScoreStep = _mul(0, 3, 6)
	armed.step_type = ScoreStep.StepType.EFFECT_ARMED
	var wasted: ScoreStep = _flat(0, 0, 2)
	wasted.step_type = ScoreStep.StepType.WASTED
	var steps: Array[ScoreStep] = [
		_base(0, 2), wasted, _base(1, 5), _mul(1, 4, 20), _mul(0, 3, 6), _payout(0, 6), armed
	]
	assert_str(PaymentEquation.of(steps, 0).text(ARROW)).is_equal("€2 × 3 → €6")
	assert_object(PaymentEquation.of(steps, 1)).is_null()


## Real rows: every equation the plan carries multiplies out to that item's real payout, only on
## its PAYOUT beat; Repeat's copy and a payout override never get one.
func test_the_plan_puts_real_equations_on_payout_beats_only() -> void:
	for ids: String in ["eggs,banana,banana", "multipack,milk,milk", "milk,repeat", "soup,eggs"]:
		var result: ScoreResult = Scoring.score(_row(ids))
		var plan: CountUpPlan = _plan(result)
		for beat: CountUpBeat in plan.beats:
			if beat.equation == null:
				continue
			assert_int(beat.kind).is_equal(CountUpBeat.Kind.PAYOUT)
			assert_int(beat.equation.payout).is_equal(result.payouts[beat.slot])
			assert_int(beat.equation.start * beat.equation.factor).is_equal(beat.equation.payout)
			for step: ScoreStep in result.steps:
				if step.slot == beat.slot:
					(
						assert_bool(
							(
								step.step_type
								in [ScoreStep.StepType.COPY, ScoreStep.StepType.PAYOUT_OVERRIDE]
							)
						)
						. is_false()
					)
	var stacked: CountUpPlan = _plan(Scoring.score(_row("eggs,banana,banana")))
	var shown: int = 0
	for beat: CountUpBeat in stacked.beats:
		shown += 1 if beat.equation != null else 0
	assert_int(shown).is_greater(0)


## The equation is display only: "eggs,banana,banana" plans the same beats with the same
## lengths as v0.66 did before the equation (recorded then; count_up_plan.gd only sets the field
## since), one step each at most, and its PAYOUT beats carry equations.
func test_the_equation_adds_no_beat_and_keeps_the_payout_hold() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,banana,banana"))
	var plan: CountUpPlan = _plan(result)
	var durations: Array[int] = []
	var steps: int = 0
	for beat: CountUpBeat in plan.beats:
		durations.append(beat.duration_ms)
		steps += beat.steps.size()
		if beat.kind != CountUpBeat.Kind.PAYOUT:
			assert_object(beat.equation).is_null()
	assert_array(durations).is_equal(V066_DURATIONS)
	assert_int(steps).is_equal(result.steps.size())


static func _base(slot: int, value: int) -> ScoreStep:
	return _step(ScoreStep.StepType.BASE, slot, value, value)


static func _flat(slot: int, value: int, value_after: int) -> ScoreStep:
	return _step(ScoreStep.StepType.FLAT, slot, value, value_after)


static func _mul(slot: int, value: int, value_after: int) -> ScoreStep:
	return _step(ScoreStep.StepType.MULTIPLIER, slot, value, value_after)


static func _payout(slot: int, value: int) -> ScoreStep:
	return _step(ScoreStep.StepType.PAYOUT, slot, value, value)


static func _step(type: ScoreStep.StepType, slot: int, value: int, value_after: int) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.value = value
	step.value_after = value_after
	return step


static func _plan(result: ScoreResult) -> CountUpPlan:
	return CountUpPlan.build(result.steps, 10000, CountUpContext.new(), load(CountUp.TUNING_PATH))


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id), row.size() + 1))
	return row


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
