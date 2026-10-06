extends GdUnitTestSuite
## The score step contract (plan v0.11): every step names its source kind, and a card that
## arms an effect for later cards gets one EFFECT_ARMED step right after its PAYOUT. Neither
## changes a value, a subtotal or a total.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"


## Each arming card gets exactly one EFFECT_ARMED step, right after its own PAYOUT, carrying
## its effect's number from the rule's data and its receipt text, with values unchanged.
func test_arming_card_gets_one_armed_step(
	row: String,
	arming_slot: int,
	number_field: String,
	_test_parameters := [
		["eggs,bread", 0, "factor"],
		["coffee,bread", 0, "bonus"],
		["bread,multipack,bread", 1, "factor"],
	]
) -> void:
	var cards: Array[CardInstance] = _row(row)
	var result: ScoreResult = Scoring.score(cards)
	var armed: Array[int] = _armed_indices(result)
	assert_array(armed).override_failure_message(row).has_size(1)
	var index: int = armed[0]
	var step: ScoreStep = result.steps[index]
	var payout: ScoreStep = result.steps[index - 1]
	assert_int(payout.step_type).is_equal(ScoreStep.StepType.PAYOUT)
	assert_int(payout.slot).is_equal(arming_slot)
	var definition: CardDefinition = cards[arming_slot].definition
	var rule: Rule = definition.rules[0]
	assert_int(step.slot).is_equal(arming_slot)
	assert_int(step.source_slot).is_equal(arming_slot)
	assert_int(step.source_kind).is_equal(ScoreStep.SourceKind.CARD)
	assert_int(step.value).is_equal(int(rule.get(number_field)))
	assert_int(step.value_after).is_equal(payout.value_after)
	assert_int(step.subtotal).is_equal(payout.subtotal)
	assert_str(step.text).is_equal(rule.text_for(definition))
	assert_str(step.tag).is_empty()
	assert_int(step.linked_slot).is_equal(-1)
	assert_str(step.reason).is_empty()


## The armed step's text matches the steps the effect later causes, so a count-up can follow
## the effect from the card that armed it to the card it lands on.
func test_armed_text_matches_the_effect_steps() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,coffee,bread"))
	var armed_text: Dictionary = {}
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.EFFECT_ARMED:
			armed_text[step.source_slot] = step.text
	assert_int(armed_text.size()).is_equal(2)
	var effect_steps: int = 0
	for step: ScoreStep in result.steps:
		var is_effect: bool = (
			step.slot == 2
			and step.source_slot != step.slot
			and [ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER].has(step.step_type)
		)
		if is_effect:
			assert_str(step.text).is_equal(str(armed_text[step.source_slot]))
			effect_steps += 1
	assert_int(effect_steps).is_equal(2)


## A Multipack with no product before it arms nothing: it fizzles instead.
func test_nothing_armed_when_the_rule_does_nothing() -> void:
	for ids: String in ["multipack,bread", "bread,repeat,multipack,bread", "banana,cheese"]:
		var result: ScoreResult = Scoring.score(_row(ids))
		assert_array(_armed_indices(result)).override_failure_message(ids).is_empty()


## A Repeat that copies an arming card copies its payout only (plan 5.1: a copy triggers
## nothing): the effect is armed once, by the original, and the Repeat neither arms nor resets.
func test_repeat_of_an_arming_card_arms_nothing() -> void:
	for ids: String in ["eggs,repeat,bread", "coffee,repeat,banana"]:
		var result: ScoreResult = Scoring.score(_row(ids))
		var armed: Array[int] = _armed_indices(result)
		assert_array(armed).override_failure_message(ids).has_size(1)
		assert_int(result.steps[armed[0]].slot).override_failure_message(ids).is_equal(0)
		for step: ScoreStep in result.steps:
			var from_repeat: bool = (
				step.source_slot == 1
				and (
					step.step_type == ScoreStep.StepType.EFFECT_ARMED
					or step.step_type == ScoreStep.StepType.WASTED
				)
			)
			assert_bool(from_repeat).override_failure_message(ids).is_false()


## An effect that never finds a target still shows as armed, before its fizzle.
func test_armed_effect_that_fizzles_keeps_its_armed_step(
	row: String,
	slot: int,
	_test_parameters := [
		["bread,coffee", 1],
		["eggs", 0],
		["coffee,multipack,banana", 1],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	var armed_at: int = -1
	var wasted_at: int = -1
	for index: int in range(result.steps.size()):
		var step: ScoreStep = result.steps[index]
		if step.slot != slot:
			continue
		if step.step_type == ScoreStep.StepType.EFFECT_ARMED:
			armed_at = index
		elif step.step_type == ScoreStep.StepType.WASTED:
			wasted_at = index
	assert_int(armed_at).override_failure_message(row).is_greater_equal(0)
	assert_int(wasted_at).override_failure_message(row).is_greater(armed_at)


## An Egg reset arms the new Egg's charges, then wipes the old ones (caused by the new Egg).
func test_egg_reset_arms_then_wastes() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,eggs,bread"))
	var armed: Array[int] = _armed_indices(result)
	assert_array(armed).has_size(2)
	assert_int(result.steps[armed[0]].slot).is_equal(0)
	var second: ScoreStep = result.steps[armed[1]]
	assert_int(second.slot).is_equal(1)
	var wipe: ScoreStep = result.steps[armed[1] + 1]
	assert_int(wipe.step_type).is_equal(ScoreStep.StepType.WASTED)
	assert_int(wipe.slot).is_equal(0)
	assert_int(wipe.source_slot).is_equal(1)


## Every armed step in the golden rows keeps the totals: the same rows, the same totals.
func test_armed_steps_never_change_values() -> void:
	var rows: Array = [
		["eggs,bread,cheese,banana,banana,repeat", 31],
		["banana,repeat,bread,eggs,banana,cheese", 18],
		["eggs,eggs,bread,bread,bread", 18],
		["bread,multipack,bread,multipack,bread", 21],
		["coffee,coffee,bread", 13],
	]
	for case: Array in rows:
		var result: ScoreResult = Scoring.score(_row(case[0]))
		assert_int(result.total).override_failure_message(case[0]).is_equal(case[1])
		for index: int in _armed_indices(result):
			var step: ScoreStep = result.steps[index]
			assert_int(step.value_after).is_equal(result.payouts[step.slot])
			assert_int(step.subtotal).is_equal(result.steps[index - 1].subtotal)


## Without upgrades every source is a card (upgrade sources: upgrade_scoring_test.gd).
func test_every_step_has_a_card_source() -> void:
	var rows: PackedStringArray = [
		"eggs,bread,cheese,banana,banana,repeat",
		"breakfast_sticker,banana,multipack,coffee,bread",
		"banana,bundle,bundle,banana",
		"eggs,eggs,bread,coffee",
		"soup,frozen_peas",
	]
	for ids: String in rows:
		for step: ScoreStep in Scoring.score(_row(ids)).steps:
			assert_int(step.source_kind).is_equal(ScoreStep.SourceKind.CARD)
			assert_int(step.source_index).is_equal(0)
			(
				assert_bool(step.source_slot >= 0 and step.source_slot < ids.split(",").size())
				. is_true()
			)


func test_to_dictionary_carries_the_source_fields() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,bread"))
	var armed: ScoreStep = result.steps[_armed_indices(result)[0]]
	var data: Dictionary = armed.to_dictionary()
	assert_str(str(data["step_type"])).is_equal("EFFECT_ARMED")
	assert_str(str(data["source_kind"])).is_equal("CARD")
	assert_int(int(data["source_index"])).is_equal(0)
	assert_int(int(data["source_slot"])).is_equal(0)
	assert_int(int(data["value"])).is_equal(armed.value)
	var upgrade_step: ScoreStep = ScoreStep.new()
	upgrade_step.source_kind = ScoreStep.SourceKind.UPGRADE
	upgrade_step.source_index = 2
	var upgrade_data: Dictionary = upgrade_step.to_dictionary()
	assert_str(str(upgrade_data["source_kind"])).is_equal("UPGRADE")
	assert_int(int(upgrade_data["source_index"])).is_equal(2)


## The receipt prints no line for an armed effect: it stays a list of payouts and
## explanations.
func test_receipt_prints_no_line_for_armed_steps() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	var names: PackedStringArray = ["Coffee", "Eggs", "Multipack", "Bread"]
	var result: ScoreResult = Scoring.score(_row("coffee,eggs,multipack,bread"))
	var armed: Array[int] = _armed_indices(result)
	assert_array(armed).has_size(3)
	for index: int in armed:
		assert_object(receipt.add_step(result.steps[index], names)).is_null()


static func _armed_indices(result: ScoreResult) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(result.steps.size()):
		if result.steps[index].step_type == ScoreStep.StepType.EFFECT_ARMED:
			indices.append(index)
	return indices


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
