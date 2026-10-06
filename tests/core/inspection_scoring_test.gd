extends GdUnitTestSuite
## Inspections in scoring (plan section 3.9): "the 3rd product pays 0" behaves like Soup beside
## Frozen. It counts products only, zeroes the payout after bonuses and multipliers (bonuses
## aimed at it are spent, it still uses an Egg charge), still arms the product's own effects,
## and a Repeat after it copies 0. Inspection steps carry their source. Uses the frozen
## fixture; inspection numbers are set here, not taken from data/.

const FIXTURE := "res://tests/fixtures/cards_v0_4/%s.tres"
const RECEIPT := "the 3rd product pays €0"


func test_the_third_product_pays_zero() -> void:
	var result: ScoreResult = _score(["banana", "bread", "cheese", "banana"], [_third()])
	assert_array(Array(result.payouts)).is_equal([2, 3, 0, 2])
	assert_int(result.total).is_equal(7)


func test_coupons_are_not_counted() -> void:
	# Banana, Bread and Milk are the products: Milk (3 + 2 for Bread) is the 3rd.
	var result: ScoreResult = _score(["banana", "repeat", "bread", "milk"], [_third()])
	assert_array(Array(result.payouts)).is_equal([2, 2, 3, 0])
	assert_int(_inspection_steps(result).size()).is_equal(1)
	assert_int(_inspection_steps(result)[0].slot).is_equal(3)


func test_fewer_than_three_products_change_nothing() -> void:
	for ids: Array in [["bread", "repeat", "repeat"], ["coffee", "final_markdown", "bread"], []]:
		var plain: Array = _as_data(_score(ids, []))
		assert_array(_as_data(_score(ids, [_third()]))).override_failure_message(str(ids)).is_equal(
			plain
		)


func test_the_step_is_a_payout_override_from_the_inspection() -> void:
	var inspections: Array = [_inspection("Empty", null), _third()]
	var result: ScoreResult = _score(["banana", "bread", "cheese"], inspections)
	var steps: Array = _inspection_steps(result)
	assert_int(steps.size()).is_equal(1)
	var step: ScoreStep = steps[0]
	assert_int(step.step_type).is_equal(ScoreStep.StepType.PAYOUT_OVERRIDE)
	assert_int(step.slot).is_equal(2)
	assert_int(step.source_slot).is_equal(2)
	assert_int(step.source_index).is_equal(1)
	assert_int(step.value).is_equal(0)
	assert_int(step.value_after).is_equal(0)
	assert_str(step.text).is_equal(RECEIPT)
	var data: Dictionary = step.to_dictionary()
	assert_str(data["source_kind"]).is_equal("INSPECTION")
	assert_int(data["source_index"]).is_equal(1)
	# Cheese after Bread: base, its own +4, the override, then its payout.
	assert_array(_types_at(result, 2)).is_equal(
		["BASE/CARD", "FLAT/CARD", "PAYOUT_OVERRIDE/INSPECTION", "PAYOUT/CARD"]
	)


func test_an_inspection_without_a_receipt_text_is_named() -> void:
	var rule: NthProductZeroPayoutRule = NthProductZeroPayoutRule.new()
	rule.product_number = 3
	var inspection: InspectionDefinition = _inspection("Spot check", rule)
	var result: ScoreResult = _score(["banana", "bread", "cheese"], [inspection])
	assert_str(_inspection_steps(result)[0].text).is_equal("Spot check")


func test_a_bonus_aimed_at_it_is_spent() -> void:
	# Coffee's +3 lands on Bread, the 3rd product, and is lost with its payout: no fizzle.
	var result: ScoreResult = _score(["banana", "coffee", "bread"], [_third()])
	assert_array(Array(result.payouts)).is_equal([2, 2, 0])
	assert_array(_types_at(result, 2)).contains(["FLAT/CARD", "PAYOUT_OVERRIDE/INSPECTION"])
	assert_array(_wasted(result)).is_empty()


func test_it_still_uses_an_egg_charge() -> void:
	# Eggs doubles the next 2 Food payouts: the 2nd and 3rd products. The 4th gets no charge.
	var result: ScoreResult = _score(["eggs", "bread", "bread", "bread"], [_third()])
	assert_array(Array(result.payouts)).is_equal([1, 6, 0, 3])
	assert_int(result.total).is_equal(10)
	assert_int(_score(["eggs", "bread", "bread", "bread"], []).total).is_equal(16)


func test_it_still_arms_its_own_effects() -> void:
	# Eggs is the 3rd product: it pays 0 but still doubles the next Bread.
	var result: ScoreResult = _score(["banana", "bread", "eggs", "bread"], [_third()])
	assert_array(Array(result.payouts)).is_equal([2, 3, 0, 6])
	assert_array(_types_at(result, 2)).contains(["EFFECT_ARMED/CARD"])
	# Coffee as the 3rd product still sends its +3 to the next Breakfast product.
	var coffee: ScoreResult = _score(["banana", "banana", "coffee", "bread"], [_third()])
	assert_array(Array(coffee.payouts)).is_equal([2, 4, 0, 6])


func test_a_repeat_after_it_copies_zero() -> void:
	var result: ScoreResult = _score(["banana", "bread", "milk", "repeat"], [_third()])
	assert_array(Array(result.payouts)).is_equal([2, 3, 0, 0])
	var copies: Array = result.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.COPY
	)
	assert_int(copies.size()).is_equal(1)
	assert_int(copies[0].value).is_equal(0)
	# The copy never re-triggers the inspection.
	assert_int(_inspection_steps(result).size()).is_equal(1)


func test_soup_already_at_zero_gets_no_inspection_step() -> void:
	var result: ScoreResult = _score(["bread", "banana", "soup", "frozen_peas"], [_third()])
	assert_array(Array(result.payouts)).is_equal([3, 2, 0, 3])
	assert_array(_inspection_steps(result)).is_empty()
	assert_array(_types_at(result, 2)).contains(["PAYOUT_OVERRIDE/CARD"])


func test_upgrade_steps_on_it_are_spent_too() -> void:
	# The Category engine pays on the last product, here the 3rd: its bonus is spent.
	var engine: UpgradeDefinition = UpgradeDefinition.new()
	engine.display_name = "Category engine"
	engine.type = UpgradeDefinition.Type.CATEGORY_ENGINE
	var rule: DistinctTagBonusRule = DistinctTagBonusRule.new()
	rule.bonus_per_tag = 3
	var engine_rules: Array[UpgradeRule] = [rule]
	engine.rules = engine_rules
	var upgrades: Array[UpgradeDefinition] = [engine]
	var inspections: Array[InspectionDefinition] = [_third()]
	var result: ScoreResult = Scoring.score(
		_row(["banana", "bread", "milk"]), upgrades, inspections
	)
	assert_array(Array(result.payouts)).is_equal([2, 3, 0])
	(
		assert_array(_types_at(result, 2))
		. is_equal(
			[
				"BASE/CARD",
				"FLAT/CARD",
				"FLAT/UPGRADE",
				"PAYOUT_OVERRIDE/INSPECTION",
				"PAYOUT/CARD",
			]
		)
	)


func test_scoring_with_inspections_is_pure() -> void:
	var ids: Array = ["eggs", "bread", "coffee", "milk", "repeat", "banana"]
	var first: Array = _as_data(_score(ids, [_third()]))
	assert_array(_as_data(_score(ids, [_third()]))).is_equal(first)


func test_inspected_steps_replay_to_each_payout() -> void:
	for ids: Array in [
		["eggs", "bread", "bread", "bread"],
		["banana", "coffee", "bread", "repeat"],
		["bread", "banana", "soup", "frozen_peas", "final_markdown"],
		["coffee", "multipack", "breakfast_sticker", "banana", "milk"],
	]:
		var result: ScoreResult = _score(ids, [_third()])
		var running: Dictionary = {}
		var subtotal: int = 0
		for step: ScoreStep in result.steps:
			match step.step_type:
				ScoreStep.StepType.BASE:
					running[step.slot] = step.value
				ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
					running[step.slot] += step.value
				ScoreStep.StepType.MULTIPLIER:
					running[step.slot] *= step.value
				ScoreStep.StepType.PAYOUT_OVERRIDE:
					running[step.slot] = step.value
				ScoreStep.StepType.PAYOUT:
					assert_int(step.value).is_equal(running[step.slot])
					subtotal += step.value
			if step.step_type in [ScoreStep.StepType.BASE, ScoreStep.StepType.FLAT]:
				assert_int(step.value_after).is_equal(running[step.slot])
			assert_int(step.subtotal).is_equal(subtotal)
		assert_int(subtotal).is_equal(result.total)


func _third() -> InspectionDefinition:
	var rule: NthProductZeroPayoutRule = NthProductZeroPayoutRule.new()
	rule.product_number = 3
	rule.receipt_text = RECEIPT
	return _inspection("Spot check", rule)


static func _inspection(display_name: String, rule: InspectionRule) -> InspectionDefinition:
	var inspection: InspectionDefinition = InspectionDefinition.new()
	inspection.display_name = display_name
	inspection.notice_text = "The 3rd product pays €0"
	if rule != null:
		var rules: Array[InspectionRule] = [rule]
		inspection.rules = rules
	return inspection


static func _score(ids: Array, inspections: Array) -> ScoreResult:
	var typed: Array[InspectionDefinition] = []
	typed.assign(inspections)
	var no_upgrades: Array[UpgradeDefinition] = []
	return Scoring.score(_row(ids), no_upgrades, typed)


static func _inspection_steps(result: ScoreResult) -> Array:
	return result.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.INSPECTION
	)


static func _wasted(result: ScoreResult) -> Array:
	return result.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.WASTED
	)


## "STEPTYPE/SOURCEKIND" of every step that lands on `slot`, in order.
static func _types_at(result: ScoreResult, slot: int) -> Array:
	var types: Array = []
	for step: ScoreStep in result.steps:
		if step.slot == slot:
			(
				types
				. append(
					(
						"%s/%s"
						% [
							ScoreStep.StepType.keys()[step.step_type],
							ScoreStep.SourceKind.keys()[step.source_kind],
						]
					)
				)
			)
	return types


static func _as_data(result: ScoreResult) -> Array:
	var data: Array = [result.total]
	for step: ScoreStep in result.steps:
		data.append(step.to_dictionary())
	return data


static func _row(ids: Array) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids:
		row.append(CardInstance.new(load(FIXTURE % id), row.size() + 1))
	return row
