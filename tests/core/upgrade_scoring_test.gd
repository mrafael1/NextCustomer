extends GdUnitTestSuite
## Register upgrades in scoring (plan section 3.8): the Coupon engine and the Category engine
## on the frozen card fixture, with upgrade numbers set here (x2, +3 per tag) so tuning
## data/upgrades/ never breaks these rows. Stacking: flats are the card's own, then effects,
## then upgrades; multipliers the card's own, then effects, then upgrades (after a copy).
## Upgrade steps carry source_kind UPGRADE and their index in the run's upgrades.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const SAMPLE_ROWS := [
	"eggs,bread,cheese,banana,banana,repeat",
	"breakfast_sticker,banana,multipack,coffee,bread",
	"coffee,breakfast_sticker,soup,frozen_peas",
	"eggs,coffee,bread,repeat",
	"bread,multipack,bread,final_markdown",
	"repeat,final_markdown",
	"frozen_peas,soup,repeat",
]
const FIRST_COUPON_REASON := "the first coupon paid nothing"


## A test-only upgrade rule: every product pays x factor. No placeholder multiplies products,
## so this checks where upgrade multipliers go among the card's and effects' multipliers.
class EveryProductRule:
	extends UpgradeRule
	var factor: int = 1

	func multiplier(state: ScoreState, slot: int) -> int:
		return factor if state.is_product(slot) else 1


# --- Coupon engine -------------------------------------------------------------------------


func test_coupon_engine_doubles_final_markdown() -> void:
	var result: ScoreResult = _score("bread,final_markdown", [_coupon_engine()])
	assert_array(Array(result.payouts)).is_equal([3, 12])
	assert_int(result.total).is_equal(15)
	assert_array(_types_at(result, 1)).is_equal(["BASE", "FLAT", "MULTIPLIER", "PAYOUT"])
	var step: ScoreStep = _upgrade_steps(result)[0]
	assert_int(step.step_type).is_equal(ScoreStep.StepType.MULTIPLIER)
	assert_int(step.slot).is_equal(1)
	assert_int(step.source_slot).is_equal(1)
	assert_int(step.source_index).is_equal(0)
	assert_int(step.value).is_equal(2)
	assert_int(step.value_after).is_equal(12)
	assert_str(step.text).is_equal("Coupon engine")


## The upgrade multiplier comes after the copy, so a Repeat's copied payout is doubled.
func test_coupon_engine_doubles_a_repeat_copy(
	row: String,
	payouts: Array,
	repeat_slot: int,
	_test_parameters := [
		["bread,repeat", [3, 6], 1],
		["eggs,bread,repeat,bread", [1, 6, 12, 6], 2],
		["eggs,bread,cheese,banana,banana,repeat", [1, 6, 14, 2, 4, 8], 5],
	]
) -> void:
	var result: ScoreResult = _score(row, [_coupon_engine()])
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	assert_array(_types_at(result, repeat_slot)).override_failure_message(row).is_equal(
		["BASE", "COPY", "MULTIPLIER", "PAYOUT"]
	)
	assert_array(_upgrade_steps(result)).override_failure_message(row).has_size(1)


## A first coupon that pays 0 has nothing to double: the upgrade fizzles there instead, after
## the card's own fizzles, and the total doesn't change.
func test_coupon_engine_fizzles_on_a_first_coupon_that_pays_nothing(
	row: String,
	slot: int,
	_test_parameters := [
		["breakfast_sticker,banana,milk", 0],
		["bread,multipack,bread", 1],
		["repeat,bread", 0],
		["final_markdown,bread", 0],
		["bread,multipack,bread,final_markdown", 1],
	]
) -> void:
	var result: ScoreResult = _score(row, [_coupon_engine()])
	assert_int(result.total).override_failure_message(row).is_equal(_score(row, []).total)
	var upgrade_steps: Array[ScoreStep] = _upgrade_steps(result)
	assert_array(upgrade_steps).override_failure_message(row).has_size(1)
	var fizzle: ScoreStep = upgrade_steps[0]
	assert_int(fizzle.step_type).is_equal(ScoreStep.StepType.WASTED)
	assert_int(fizzle.slot).is_equal(slot)
	assert_int(fizzle.source_slot).is_equal(slot)
	assert_int(fizzle.source_index).is_equal(0)
	assert_int(fizzle.value).is_equal(0)
	assert_int(fizzle.value_after).is_equal(0)
	assert_str(fizzle.reason).is_equal(FIRST_COUPON_REASON)
	assert_str(fizzle.text).is_equal("Coupon engine")
	# It is the last step of its slot's block: after the PAYOUT, the armed effects and the
	# card's own fizzles, before the next card is scanned.
	var block: Array[ScoreStep] = _after_payout(result, slot)
	assert_object(block[-1]).override_failure_message(row).is_same(fizzle)


## With no coupon in the row there is nothing to fizzle on: no step, the same result.
func test_coupon_engine_without_a_coupon_has_no_step() -> void:
	for ids: String in ["bread,cheese", "eggs,bread,milk", "soup,frozen_peas"]:
		var result: ScoreResult = _score(ids, [_coupon_engine()])
		assert_array(_upgrade_steps(result)).override_failure_message(ids).is_empty()
		assert_array(_as_data(result)).override_failure_message(ids).is_equal(
			_as_data(_score(ids, []))
		)


## Only the first coupon pays x2; a later Final markdown keeps its +6.
func test_coupon_engine_only_doubles_the_first_coupon() -> void:
	var result: ScoreResult = _score("bread,repeat,bread,final_markdown", [_coupon_engine()])
	assert_array(Array(result.payouts)).is_equal([3, 6, 3, 6])
	var steps: Array[ScoreStep] = _upgrade_steps(result)
	assert_array(steps).has_size(1)
	assert_int(steps[0].slot).is_equal(1)


# --- Category engine -----------------------------------------------------------------------


## +3 per different tag among the products, after the context pass, on the last product.
func test_category_engine_counts_distinct_tags(
	row: String,
	payouts: Array,
	bonus: int,
	_test_parameters := [
		# Food, Breakfast, Bakery, Produce.
		["bread,banana", [3, 14], 12],
		# Food, Produce.
		["banana", [8], 6],
		# The sticker's Breakfast counts: Food, Produce, Breakfast.
		["breakfast_sticker,banana", [0, 11], 9],
		# Duplicates count once: Food, Produce. Banana's own +2 comes first.
		["banana,banana", [2, 10], 6],
	]
) -> void:
	var result: ScoreResult = _score(row, [_category_engine()])
	assert_array(Array(result.payouts)).override_failure_message(row).is_equal(payouts)
	var steps: Array[ScoreStep] = _upgrade_steps(result)
	assert_array(steps).override_failure_message(row).has_size(1)
	assert_int(steps[0].step_type).is_equal(ScoreStep.StepType.FLAT)
	assert_int(steps[0].value).override_failure_message(row).is_equal(bonus)
	assert_int(steps[0].slot).is_equal(payouts.size() - 1)
	assert_str(steps[0].text).is_equal("Category engine")


## The bonus goes on the last product, not the last slot; a Repeat after it copies it.
func test_category_engine_pays_on_the_last_product() -> void:
	var repeat: ScoreResult = _score("bread,banana,repeat", [_category_engine()])
	assert_array(Array(repeat.payouts)).is_equal([3, 14, 14])
	assert_int(_upgrade_steps(repeat)[0].slot).is_equal(1)
	var markdown: ScoreResult = _score("bread,banana,final_markdown", [_category_engine()])
	assert_array(Array(markdown.payouts)).is_equal([3, 14, 6])
	assert_array(_upgrade_steps(markdown)).has_size(1)


## Soup last: the bonus is spent like any bonus aimed at Soup (plan section 3.5), no fizzle.
func test_category_engine_bonus_on_soup_is_spent() -> void:
	var result: ScoreResult = _score("frozen_peas,soup", [_category_engine()])
	assert_array(Array(result.payouts)).is_equal([3, 0])
	assert_array(_types_at(result, 1)).is_equal(["BASE", "FLAT", "PAYOUT_OVERRIDE", "PAYOUT"])
	var steps: Array[ScoreStep] = _upgrade_steps(result)
	assert_array(steps).has_size(1)
	# Food, Frozen, Produce.
	assert_int(steps[0].value).is_equal(9)


func test_category_engine_without_products_has_no_step() -> void:
	for ids: String in ["repeat,final_markdown", "breakfast_sticker", "multipack,repeat"]:
		var result: ScoreResult = _score(ids, [_category_engine()])
		assert_array(_upgrade_steps(result)).override_failure_message(ids).is_empty()
		assert_array(_as_data(result)).override_failure_message(ids).is_equal(
			_as_data(_score(ids, []))
		)


# --- Stacking and sources ------------------------------------------------------------------


## Upgrade flats come after the card's own and effect flats, before every multiplier, so an
## Egg charge doubles the Category engine's bonus: Bread (3 + 3 + 9) x 2 = 30.
func test_upgrade_flats_come_after_effects_and_before_multipliers() -> void:
	var result: ScoreResult = _score("eggs,coffee,bread", [_category_engine()])
	assert_array(Array(result.payouts)).is_equal([1, 2, 30])
	var steps: Array[ScoreStep] = _steps_at(result, 2)
	var kinds: Array = []
	var values_after: Array = []
	for step: ScoreStep in steps:
		kinds.append(
			(
				"%s/%s"
				% [
					ScoreStep.StepType.keys()[step.step_type],
					ScoreStep.SourceKind.keys()[step.source_kind]
				]
			)
		)
		values_after.append(step.value_after)
	assert_array(kinds).is_equal(
		["BASE/CARD", "FLAT/CARD", "FLAT/UPGRADE", "MULTIPLIER/CARD", "PAYOUT/CARD"]
	)
	assert_array(values_after).is_equal([3, 6, 15, 30, 30])


## Upgrade multipliers come after the card's own and effect multipliers, in pick order, and
## each step names its upgrade by index.
func test_upgrade_multipliers_come_after_effects_in_pick_order() -> void:
	var upgrades: Array[UpgradeDefinition] = [_redraw_only(), _every_product(3), _coupon_engine()]
	var result: ScoreResult = _score("eggs,bread,final_markdown", upgrades)
	# Eggs 1 x 3, Bread 3 x 2 (Egg) x 3, Final markdown (0 + 6) x 2.
	assert_array(Array(result.payouts)).is_equal([3, 18, 12])
	var bread: Array[ScoreStep] = _steps_at(result, 1)
	assert_int(bread[1].source_kind).is_equal(ScoreStep.SourceKind.CARD)
	assert_int(bread[1].source_slot).is_equal(0)
	assert_int(bread[2].source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_int(bread[2].source_index).is_equal(1)
	assert_int(bread[2].value_after).is_equal(18)
	var markdown: Array[ScoreStep] = _steps_at(result, 2)
	assert_int(markdown[2].source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_int(markdown[2].source_index).is_equal(2)


## A copy never re-triggers upgrades: Repeat copies the boosted payout, and only the Coupon
## engine's own rule multiplies the Repeat.
func test_copies_never_retrigger_upgrades() -> void:
	var tripled: ScoreResult = _score("bread,repeat", [_every_product(3)])
	assert_array(Array(tripled.payouts)).is_equal([9, 9])
	var both: ScoreResult = _score("bread,repeat", [_every_product(3), _coupon_engine()])
	assert_array(Array(both.payouts)).is_equal([9, 18])
	# Cheese 3 + 4 + 12 (Food, Breakfast, Bakery, Dairy); the Repeat copies it.
	var category: ScoreResult = _score("bread,cheese,repeat", [_category_engine()])
	assert_array(Array(category.payouts)).is_equal([3, 19, 19])
	var engines: ScoreResult = _score("bread,cheese,repeat", [_category_engine(), _coupon_engine()])
	assert_array(Array(engines.payouts)).is_equal([3, 19, 38])
	assert_int(_upgrade_steps(engines).size()).is_equal(2)


## Upgrades never receive or arm card effects: the armed effects and their fizzles are the
## same with or without upgrades.
func test_upgrades_never_receive_or_arm_effects() -> void:
	var upgrades: Array[UpgradeDefinition] = [_coupon_engine(), _category_engine()]
	for ids: String in ["eggs,final_markdown", "coffee,multipack,repeat", "eggs,eggs,bread"]:
		var plain: Array = _effect_steps(_score(ids, []))
		assert_array(_effect_steps(_score(ids, upgrades))).override_failure_message(ids).is_equal(
			plain
		)


func test_upgrade_steps_carry_their_source_in_to_dictionary() -> void:
	var result: ScoreResult = _score("bread,final_markdown", [_redraw_only(), _coupon_engine()])
	var step: ScoreStep = _upgrade_steps(result)[0]
	var data: Dictionary = step.to_dictionary()
	assert_str(str(data["source_kind"])).is_equal("UPGRADE")
	assert_int(int(data["source_index"])).is_equal(1)
	assert_int(int(data["source_slot"])).is_equal(1)
	assert_int(int(data["slot"])).is_equal(1)
	assert_str(str(data["step_type"])).is_equal("MULTIPLIER")
	# Card steps keep their card source.
	for card_step: ScoreStep in result.steps:
		if card_step != step:
			assert_int(card_step.source_kind).is_equal(ScoreStep.SourceKind.CARD)


# --- Invariants with upgrades --------------------------------------------------------------


func test_scoring_with_upgrades_is_pure() -> void:
	var upgrades: Array[UpgradeDefinition] = [_coupon_engine(), _category_engine()]
	var factor_before: int = (upgrades[0].rules[0] as FirstCouponMultiplierRule).factor
	for ids: String in SAMPLE_ROWS:
		var first: Array = _as_data(_score(ids, upgrades))
		var second: Array = _as_data(_score(ids, upgrades))
		assert_array(second).override_failure_message(ids).is_equal(first)
	assert_int((upgrades[0].rules[0] as FirstCouponMultiplierRule).factor).is_equal(factor_before)
	assert_int(upgrades[0].rules.size()).is_equal(1)


## The steps alone replay to every payout and the total, with upgrades too.
func test_upgraded_steps_replay_to_each_payout() -> void:
	var upgrades: Array[UpgradeDefinition] = [
		_coupon_engine(), _category_engine(), _every_product(2)
	]
	for ids: String in SAMPLE_ROWS:
		var result: ScoreResult = _score(ids, upgrades)
		var running: Dictionary = {}
		var sum: int = 0
		var previous_subtotal: int = 0
		for step: ScoreStep in result.steps:
			match step.step_type:
				ScoreStep.StepType.BASE:
					running[step.slot] = step.value
				ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
					running[step.slot] = int(running[step.slot]) + step.value
				ScoreStep.StepType.MULTIPLIER:
					running[step.slot] = int(running[step.slot]) * step.value
				ScoreStep.StepType.PAYOUT_OVERRIDE:
					running[step.slot] = step.value
				ScoreStep.StepType.PAYOUT:
					assert_int(step.value).is_equal(result.payouts[step.slot])
					sum += step.value
			var context_only: Array = [ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED]
			if not context_only.has(step.step_type):
				(
					assert_int(step.value_after)
					. override_failure_message("%s slot %d" % [ids, step.slot])
					. is_equal(int(running.get(step.slot, 0)))
				)
			if step.step_type != ScoreStep.StepType.PAYOUT:
				assert_int(step.subtotal).is_equal(previous_subtotal)
			previous_subtotal = step.subtotal
		assert_int(sum).override_failure_message(ids).is_equal(result.total)


# --- Helpers -------------------------------------------------------------------------------


static func _coupon_engine() -> UpgradeDefinition:
	var rule: FirstCouponMultiplierRule = FirstCouponMultiplierRule.new()
	rule.factor = 2
	return _upgrade("Coupon engine", UpgradeDefinition.Type.COUPON_ENGINE, rule)


static func _category_engine() -> UpgradeDefinition:
	var rule: DistinctTagBonusRule = DistinctTagBonusRule.new()
	rule.bonus_per_tag = 3
	return _upgrade("Category engine", UpgradeDefinition.Type.CATEGORY_ENGINE, rule)


static func _every_product(factor: int) -> UpgradeDefinition:
	var rule: EveryProductRule = EveryProductRule.new()
	rule.factor = factor
	return _upgrade("Every product", UpgradeDefinition.Type.RULE_BENDER, rule)


static func _redraw_only() -> UpgradeDefinition:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.display_name = "Extra redraw"
	upgrade.type = UpgradeDefinition.Type.ECONOMY
	upgrade.extra_redraws = 1
	return upgrade


static func _upgrade(
	upgrade_name: String, type: UpgradeDefinition.Type, rule: UpgradeRule
) -> UpgradeDefinition:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.display_name = upgrade_name
	upgrade.type = type
	var rules: Array[UpgradeRule] = [rule]
	upgrade.rules = rules
	return upgrade


static func _score(ids: String, upgrades: Array) -> ScoreResult:
	var typed: Array[UpgradeDefinition] = []
	typed.assign(upgrades)
	return Scoring.score(_row(ids), typed)


static func _upgrade_steps(result: ScoreResult) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.source_kind == ScoreStep.SourceKind.UPGRADE:
			steps.append(step)
	return steps


## The value-pass steps of one slot, from its BASE to its PAYOUT.
static func _steps_at(result: ScoreResult, slot: int) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	var inside: bool = false
	for step: ScoreStep in result.steps:
		if step.slot == slot and step.step_type == ScoreStep.StepType.BASE:
			inside = true
		if inside:
			steps.append(step)
			if step.step_type == ScoreStep.StepType.PAYOUT:
				break
	return steps


static func _types_at(result: ScoreResult, slot: int) -> Array:
	var types: Array = []
	for step: ScoreStep in _steps_at(result, slot):
		types.append(ScoreStep.StepType.keys()[step.step_type])
	return types


## The steps of one slot after its PAYOUT, up to the next card's BASE.
static func _after_payout(result: ScoreResult, slot: int) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	var inside: bool = false
	for step: ScoreStep in result.steps:
		if inside and step.step_type == ScoreStep.StepType.BASE:
			break
		if inside:
			steps.append(step)
		if step.slot == slot and step.step_type == ScoreStep.StepType.PAYOUT:
			inside = true
	return steps


static func _effect_steps(result: ScoreResult) -> Array:
	var data: Array = []
	for step: ScoreStep in result.steps:
		var armed: bool = step.step_type == ScoreStep.StepType.EFFECT_ARMED
		var card_waste: bool = (
			step.step_type == ScoreStep.StepType.WASTED
			and step.source_kind == ScoreStep.SourceKind.CARD
		)
		if armed or card_waste:
			data.append([step.step_type, step.slot, step.source_slot, step.value, step.reason])
	return data


static func _as_data(result: ScoreResult) -> Array:
	var data: Array = []
	for step: ScoreStep in result.steps:
		data.append(step.to_dictionary())
	data.append(result.total)
	return data


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
