extends GdUnitTestSuite
## Day event rules in scoring (v0.69, plan section 3.9): a flat bonus on a tag's products (Late
## delivery's −€2, never below €0), a multiplier on the nth product (Free samples' ×2, wasted on a
## €0 product or a row without it) and a flat bonus on the row's last card (Happy hour's +€3).
## Every change is a step of the event's (source_kind INSPECTION), so the count-up and the receipt
## show it. Uses the frozen fixture; the rules' numbers are set here, not taken from data/.

const FIXTURE := "res://tests/fixtures/cards_v0_4/%s.tres"


func test_a_tag_bonus_changes_that_tags_products_only() -> void:
	# Banana 2; Cheese 3 (Dairy) - 2 = 1.
	var result: ScoreResult = _score(["banana", "cheese"], [_late(-2)])
	assert_array(Array(result.payouts)).is_equal([2, 1])
	var steps: Array = _event_steps(result)
	assert_int(steps.size()).is_equal(1)
	var step: ScoreStep = steps[0]
	assert_int(step.step_type).is_equal(ScoreStep.StepType.FLAT)
	assert_int(step.slot).is_equal(1)
	assert_int(step.value).is_equal(-2)
	assert_int(step.value_after).is_equal(1)
	assert_int(step.source_index).is_equal(0)
	assert_str(step.text).is_equal("Dairy pays less")


func test_a_negative_tag_bonus_never_goes_below_zero() -> void:
	var result: ScoreResult = _score(["cheese"], [_late(-5)])
	assert_array(Array(result.payouts)).is_equal([0])
	assert_int((_event_steps(result)[0] as ScoreStep).value).is_equal(-3)
	var none: Array[UpgradeDefinition] = []
	assert_int(Scoring.total(_row(["cheese"]), none, _typed([_late(-5)]))).is_equal(0)


func test_the_first_product_is_multiplied_after_everything_else() -> void:
	# Banana 2 × 2 = 4; Cheese 3.
	var result: ScoreResult = _score(["banana", "cheese"], [_samples()])
	assert_array(Array(result.payouts)).is_equal([4, 3])
	var step: ScoreStep = _event_steps(result)[0]
	assert_int(step.step_type).is_equal(ScoreStep.StepType.MULTIPLIER)
	assert_int(step.slot).is_equal(0)
	assert_int(step.value).is_equal(2)
	# Coupons are skipped: the 1st product is Banana in slot 1.
	var skipped: ScoreResult = _score(["repeat", "banana"], [_samples()])
	assert_int((_event_steps(skipped)[0] as ScoreStep).slot).is_equal(1)


func test_a_multiplier_on_nothing_is_wasted() -> void:
	# Late delivery takes Cheese to 0 first: the ×2 has nothing to multiply.
	var result: ScoreResult = _score(["cheese", "banana"], [_late(-5), _samples()])
	assert_array(Array(result.payouts)).is_equal([0, 2])
	var wasted: Array = _event_steps(result).filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.WASTED
	)
	assert_int(wasted.size()).is_equal(1)
	var waste: ScoreStep = wasted[0]
	assert_int(waste.slot).is_equal(0)
	assert_int(waste.source_index).is_equal(1)
	assert_str(waste.reason).is_equal("nothing to multiply")
	# It comes after the slot's PAYOUT, as a card's own fizzle does.
	var payout_at: int = -1
	for index: int in range(result.steps.size()):
		var each: ScoreStep = result.steps[index]
		if each.slot == 0 and each.step_type == ScoreStep.StepType.PAYOUT:
			payout_at = index
	assert_int(result.steps.find(waste)).is_greater(payout_at)


func test_a_row_without_the_product_wastes_the_boon_on_its_last_slot() -> void:
	var result: ScoreResult = _score(["repeat", "repeat"], [_samples()])
	var steps: Array = _event_steps(result)
	assert_int(steps.size()).is_equal(1)
	var waste: ScoreStep = steps[0]
	assert_int(waste.step_type).is_equal(ScoreStep.StepType.WASTED)
	assert_int(waste.slot).is_equal(1)
	assert_bool(waste.row_wide).is_true()
	assert_str(waste.reason).is_equal("no product 1 in the row")
	# An empty row has no last slot: no step.
	assert_array(_score([], [_samples()]).steps).is_empty()


func test_the_last_card_gets_its_bonus() -> void:
	var plain: ScoreResult = _score(["banana", "cheese", "repeat"], [])
	var result: ScoreResult = _score(["banana", "cheese", "repeat"], [_happy()])
	assert_int(result.total).is_equal(plain.total + 3)
	var step: ScoreStep = _event_steps(result)[0]
	assert_int(step.step_type).is_equal(ScoreStep.StepType.FLAT)
	assert_int(step.slot).is_equal(2)
	assert_int(step.value).is_equal(3)
	assert_int(_score(["banana"], [_happy()]).total).is_equal(5)


## Scoring.total (the simulator's) gives score()'s total with every day event rule.
func test_total_matches_score_with_every_rule() -> void:
	var typed: Array[InspectionDefinition] = _typed([_late(-2), _samples(), _happy()])
	var none: Array[UpgradeDefinition] = []
	for ids: Array in [["cheese", "banana", "milk"], ["repeat", "cheese"], ["banana"], []]:
		var total: int = Scoring.total(_row(ids), none, typed)
		assert_int(total).override_failure_message(str(ids)).is_equal(
			Scoring.score(_row(ids), none, typed).total
		)


## The receipt and the monitor word a fall with its sign: "−€2 Late delivery: Dairy pays less".
func test_a_fall_reads_with_its_sign() -> void:
	var result: ScoreResult = _score(["cheese"], [_late(-2)])
	var step: ScoreStep = _event_steps(result)[0]
	var names: PackedStringArray = PackedStringArray(["Late delivery"])
	var line: String = ReceiptView.step_line(
		step, PackedStringArray(["Cheese"]), PackedStringArray(), names
	)
	assert_str(line).is_equal("−€2 Late delivery: Dairy pays less")
	assert_str(ReceiptView.money(-2, true)).is_equal("−€2.00")
	assert_str(EffectLinks.token_text(step)).is_equal("−2")


static func _late(bonus: int) -> InspectionDefinition:
	var rule: TagFlatBonusRule = TagFlatBonusRule.new()
	rule.tag = "Dairy"
	rule.bonus = bonus
	rule.receipt_text = "Dairy pays less"
	return _event("Late delivery", rule, InspectionDefinition.Tone.MALUS)


static func _samples() -> InspectionDefinition:
	var rule: NthProductMultiplierRule = NthProductMultiplierRule.new()
	rule.product_number = 1
	rule.factor = 2
	return _event("Free samples", rule, InspectionDefinition.Tone.BOON)


static func _happy() -> InspectionDefinition:
	var rule: LastCardBonusRule = LastCardBonusRule.new()
	rule.bonus = 3
	return _event("Happy hour", rule, InspectionDefinition.Tone.BOON)


static func _event(
	display_name: String, rule: InspectionRule, tone: InspectionDefinition.Tone
) -> InspectionDefinition:
	var event: InspectionDefinition = InspectionDefinition.new()
	event.display_name = display_name
	event.tone = tone
	var rules: Array[InspectionRule] = [rule]
	event.rules = rules
	return event


static func _typed(events: Array) -> Array[InspectionDefinition]:
	var typed: Array[InspectionDefinition] = []
	typed.assign(events)
	return typed


static func _score(ids: Array, events: Array) -> ScoreResult:
	var no_upgrades: Array[UpgradeDefinition] = []
	return Scoring.score(_row(ids), no_upgrades, _typed(events))


static func _event_steps(result: ScoreResult) -> Array:
	return result.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.INSPECTION
	)


static func _row(ids: Array) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids:
		row.append(CardInstance.new(load(FIXTURE % id), row.size() + 1))
	return row
