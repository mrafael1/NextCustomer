extends GdUnitTestSuite
## CountUpPlan's landings (#105 piece 2, _set_landings and the landing floors): on every golden
## row and the full reference row scored with the real Scoring.score(), the shown total runs on
## from beat to beat (each beat's shown_from is the last one's shown_to), equals the subtotal at
## every PAYOUT and ends on ScoreResult.total; a landing's ticks are whole euros, at most
## ticks_per_landing, moving one way and ending on its shown_to; a fall lands DOWN with no lamp,
## a × lands MUL with its factor; the lamps count up from 0 over the gain landings; each landing
## flies landing_fly_ms, rolls its ticks tick_gap_ms apart and lasts at least the landing gap
## (fit_landing_gap_ms at the last fit stage). Pure data: no saves, no event log, no Node.

const CARDS := "res://data/cards"
const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const FULL_ROW := "eggs,bread,milk,multipack,milk,milk,milk"
## A long row that fits at the last stage.
const LONG_ROW := "eggs,multipack,milk,milk,milk,milk,milk,milk,milk,milk,milk,milk,milk"
const GOLDEN_ROWS := [
	"eggs,bread,cheese,banana,banana,repeat",
	"banana,repeat,bread,eggs,banana,cheese",
	"banana,bundle,banana",
	"eggs,bread,multipack,bread",
	"milk,multipack,cheese",
	"coffee,coffee,bread",
	"breakfast_sticker,banana,milk",
	"bread,final_markdown",
	"final_markdown,bread",
	"bread,multipack,bread,repeat",
	"soup,repeat,frozen_peas",
	"bread,multipack,bread,multipack,bread",
	"coffee,breakfast_sticker,soup,frozen_peas,bread",
	"bundle,banana,banana,bundle",
]


func test_every_golden_rows_landings_hold() -> void:
	var downs: int = 0
	var muls: int = 0
	for ids: String in GOLDEN_ROWS:
		var result: ScoreResult = Scoring.score(_row(ids, FIXTURE_DIR))
		var plan: CountUpPlan = _plan(result.steps)
		_assert_landings(plan, result, ids)
		downs += _count(plan, CountUpBeat.Land.DOWN)
		muls += _count(plan, CountUpBeat.Land.MUL)
	assert_int(muls).is_equal(0)
	prints("#105 golden rows' DOWN landings:", downs, "MUL landings:", muls)


## The full reference row with Coupon engine, Slot engine and a Spot check (its 3rd product's
## override lands DOWN, the fizzle on the item at the scanner WASTE).
func test_the_reference_rows_landings_hold() -> void:
	var result: ScoreResult = _data_result(FULL_ROW)
	var plan: CountUpPlan = _plan(result.steps)
	_assert_landings(plan, result, FULL_ROW)
	assert_int(_count(plan, CountUpBeat.Land.MUL)).is_equal(0)
	assert_int(_count(plan, CountUpBeat.Land.ADD)).is_greater(0)


## A long row fitted to the last stage keeps its landings fit_landing_gap_ms apart at least.
func test_a_fitted_rows_landings_keep_their_floor() -> void:
	var result: ScoreResult = _data_result(LONG_ROW)
	var plan: CountUpPlan = _plan(result.steps)
	_assert_landings(plan, result, LONG_ROW)
	prints("#105 long row's fit stage:", plan.fit_stage)


## Hand-built: a card worth 4 paying 4 then a ×3 then an override to €0: BASE +4 (3 ticks 1, 3,
## 4), MUL +8 with "×3" (ticks to 12), DOWN -12 with no lamp; the lamps 0 and 1.
func test_an_unpaid_price_can_rise_and_fall_without_changing_the_register() -> void:
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.BASE, 0, 4, 0),
		_step(ScoreStep.StepType.MULTIPLIER, 0, 3, 0),
		_step(ScoreStep.StepType.PAYOUT_OVERRIDE, 0, 0, 0),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 0),
	]
	steps[0].value_after = 4
	steps[1].value_after = 12
	var plan: CountUpPlan = _plan(steps)
	for beat: CountUpBeat in plan.beats:
		assert_bool(CountUpPlan.is_landing(beat)).is_false()
		assert_int(beat.shown_to).is_equal(0)
	assert_int(plan.landing_count).is_equal(0)


## `plan`'s landings against `result` (see the class comment).
func _assert_landings(plan: CountUpPlan, result: ScoreResult, where: String) -> void:
	var tuning: CountTotalTuning = _tuning()
	var shown: int = 0
	var lamp: int = 0
	var landings: int = 0
	for beat: CountUpBeat in plan.beats:
		var message: String = (
			"%s, beat on slot %d (%s)" % [where, beat.slot, CountUpBeat.Kind.keys()[beat.kind]]
		)
		assert_int(beat.shown_from).override_failure_message(message).is_equal(shown)
		assert_int(beat.gain).override_failure_message(message).is_equal(
			beat.shown_to - beat.shown_from
		)
		shown = beat.shown_to
		for index: int in beat.steps:
			var step: ScoreStep = result.steps[index]
			if step.step_type == ScoreStep.StepType.PAYOUT:
				assert_int(beat.shown_to).override_failure_message(message).is_equal(step.subtotal)
		if not CountUpPlan.is_landing(beat):
			assert_array(beat.ticks).override_failure_message(message).is_empty()
			assert_int(beat.lamp).override_failure_message(message).is_equal(-1)
			if beat.land != CountUpBeat.Land.WASTE:
				assert_int(beat.gain).override_failure_message(message).is_equal(0)
			continue
		landings += 1
		assert_int(beat.gain).override_failure_message(message).is_not_equal(0)
		assert_int(beat.fly_ms).override_failure_message(message).is_equal(
			(
				(load(CountUp.TUNING_PATH) as CountUpTuning).base_ms
				if beat.kind == CountUpBeat.Kind.MERGED_PLAIN
				else tuning.landing_fly_ms
			)
		)
		var ticks: PackedInt32Array = beat.ticks
		assert_int(ticks.size()).override_failure_message(message).is_between(
			1, tuning.ticks_per_landing
		)
		assert_int(ticks[-1]).override_failure_message(message).is_equal(beat.shown_to)
		var last: int = beat.shown_from
		for tick: int in ticks:
			var step_by: int = tick - last
			(
				assert_bool(step_by != 0 and signi(step_by) == signi(beat.gain))
				. override_failure_message("%s: ticks %s" % [message, ticks])
				. is_true()
			)
			last = tick
		assert_int(beat.roll_ms).override_failure_message(message).is_equal(
			(ticks.size() - 1) * tuning.tick_gap_ms
		)
		var floor_ms: int = tuning.landing_gap_ms
		if plan.fit_stage >= CountUpPlan.LAST_STAGE:
			floor_ms = tuning.fit_landing_gap_ms
		assert_int(beat.duration_ms).override_failure_message(message).is_greater_equal(floor_ms)
		assert_int(beat.duration_ms).override_failure_message(message).is_greater(beat.roll_ms)
		match beat.land:
			CountUpBeat.Land.DOWN:
				assert_int(beat.gain).override_failure_message(message).is_less(0)
				assert_int(beat.lamp).override_failure_message(message).is_equal(-1)
			CountUpBeat.Land.MUL:
				assert_str(beat.factor_text).override_failure_message(message).starts_with("×")
				assert_int(beat.lamp).override_failure_message(message).is_equal(lamp)
				lamp += 1
			_:
				assert_int(beat.gain).override_failure_message(message).is_greater(0)
				assert_int(beat.lamp).override_failure_message(message).is_equal(lamp)
				lamp += 1
	assert_int(shown).override_failure_message(where).is_equal(result.total)
	assert_int(plan.landing_count).override_failure_message(where).is_equal(landings)
	assert_int(plan.lamp_count).override_failure_message(where).is_equal(lamp)


static func _count(plan: CountUpPlan, land: CountUpBeat.Land) -> int:
	var found: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.land == land:
			found += 1
	return found


static func _plan(steps: Array[ScoreStep], quota: int = 40) -> CountUpPlan:
	return CountUpPlan.build(steps, quota, CountUpContext.new(), load(CountUp.TUNING_PATH))


static func _tuning() -> CountTotalTuning:
	return load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning


## A row of live cards with Coupon engine, Slot engine and a Spot check.
static func _data_result(ids: String) -> ScoreResult:
	var upgrades: Array[UpgradeDefinition] = [
		load("res://data/upgrades/coupon_engine.tres"),
		load("res://data/upgrades/slot_engine.tres"),
	]
	var inspections: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	return Scoring.score(_row(ids, CARDS), upgrades, inspections)


static func _row(ids: String, folder: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [folder, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _step(type: ScoreStep.StepType, slot: int, value: int, subtotal: int) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.source_slot = slot
	step.value = value
	step.value_after = value
	step.subtotal = subtotal
	step.text = "Card"
	return step
