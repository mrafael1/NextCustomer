extends GdUnitTestSuite
## Upgrade condition fizzles (#45, decided with the user: upgrades' conditions fizzle too): a
## register upgrade whose condition the checked-out row never meets (the Coupon engine with no
## coupon, the Slot engine with too few products, the Category engine with no product) records
## one WASTED step, the upgrade's, on the row's last slot, after every other step, naming what
## was missing. A met condition records none, and the total and payouts never change. Upgrade
## numbers are set here, on the frozen card fixture, except in the live-data test.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const UPGRADES_DIR := "res://data/upgrades"


## Each row's expected fizzles are [upgrade index, reason], in step order; `bonus` is what the
## upgrades add to the row's total without them (a fizzle adds nothing).
func test_upgrade_condition_fizzles(
	row: String,
	upgrade_ids: Array,
	expected: Array,
	bonus: int,
	_test_parameters := [
		["bread,cheese", ["coupon"], [[0, "no coupon in the row"]], 0],
		# Final markdown 6 x 2.
		["bread,final_markdown", ["coupon"], [], 6],
		["bread,bread,bread,bread,bread", ["slot"], [[0, "fewer than 6 products"]], 0],
		# The 6th Bread 3 x 2.
		["bread,bread,bread,bread,bread,bread", ["slot"], [], 3],
		# Coupons don't count as products.
		[
			"bread,bread,bread,repeat,bread,bread,final_markdown",
			["slot"],
			[[0, "fewer than 6 products"]],
			0
		],
		["final_markdown", ["category"], [[0, "no product in the row"]], 0],
		# Food, Produce: +3 each.
		["banana", ["category"], [], 6],
		# Several upgrades fizzle in pick order.
		[
			"repeat",
			["category", "slot"],
			[[0, "no product in the row"], [1, "fewer than 6 products"]],
			0
		],
		[
			"bread,milk",
			["coupon", "slot"],
			[[0, "no coupon in the row"], [1, "fewer than 6 products"]],
			0
		],
	]
) -> void:
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: String in upgrade_ids:
		upgrades.append(_test_upgrade(upgrade_id))
	var result: ScoreResult = Scoring.score(_row(row), upgrades)
	var plain: ScoreResult = Scoring.score(_row(row))
	var last: int = result.payouts.size() - 1
	var fizzles: Array = []
	var others: Array = []
	for step: ScoreStep in result.steps:
		var row_fizzle: bool = (
			step.step_type == ScoreStep.StepType.WASTED
			and step.source_kind == ScoreStep.SourceKind.UPGRADE
		)
		if not row_fizzle:
			assert_bool(step.row_wide).is_false()
			others.append(step)
			continue
		fizzles.append([step.source_index, step.reason])
		# Not the last item's own fizzle: its marks skip it.
		assert_bool(step.row_wide).is_true()
		assert_int(step.slot).override_failure_message(row).is_equal(last)
		assert_int(step.source_slot).is_equal(last)
		assert_int(step.value).is_equal(0)
		assert_int(step.value_after).is_equal(result.payouts[last])
		assert_int(step.subtotal).is_equal(result.total)
		assert_str(step.text).is_equal(upgrades[step.source_index].display_name)
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)
	# The fizzles come last, and the total and payouts are the row's without them.
	if not expected.is_empty():
		var tail: ScoreStep = result.steps[result.steps.size() - expected.size()]
		assert_int(tail.step_type).is_equal(ScoreStep.StepType.WASTED)
		assert_int(tail.source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_int(result.total).override_failure_message(row).is_equal(plain.total + bonus)
	if bonus == 0:
		# Upgrades that add nothing leave every other step as it was.
		assert_array(_data(others)).override_failure_message(row).is_equal(_data(plain.steps))


## A Slot engine target that follows the shift's product slots moves with them: with Big
## basket's extra slot the 7th product, so 6 products fizzle.
func test_slot_engine_follows_the_slot_change() -> void:
	var slot_engine: UpgradeDefinition = _test_upgrade("slot")
	(slot_engine.rules[0] as NthProductMultiplierRule).follows_slot_changes = true
	var basket: UpgradeDefinition = UpgradeDefinition.new()
	basket.display_name = "Big basket"
	basket.type = UpgradeDefinition.Type.RISKY
	basket.extra_slots = 1
	var row: String = "bread,bread,bread,bread,bread,bread"
	var result: ScoreResult = Scoring.score(_row(row), [slot_engine, basket])
	var reasons: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			reasons.append(step.reason)
	assert_array(reasons).is_equal(["fewer than 7 products"])
	assert_int(result.total).is_equal(18)


## A met condition whose target pays 0 keeps its one existing fizzle ("product 6 paid nothing"),
## never a second one for the row.
func test_a_target_that_pays_nothing_fizzles_once() -> void:
	var free: CardDefinition = CardDefinition.new()
	free.kind = CardDefinition.Kind.PRODUCT
	free.display_name = "Free sample"
	var row: Array[CardInstance] = _row("bread,bread,bread,bread,bread")
	row.append(CardInstance.new(free, row.size() + 1))
	var result: ScoreResult = Scoring.score(row, [_test_upgrade("slot")])
	var reasons: Array = []
	for step: ScoreStep in result.steps:
		if step.source_kind == ScoreStep.SourceKind.UPGRADE:
			reasons.append(step.reason)
			# The 6th product's own fizzle, not a row-wide one.
			assert_bool(step.row_wide).is_false()
	assert_array(reasons).is_equal(["product 6 paid nothing"])
	assert_int(result.total).is_equal(15)


## The Category engine with products but no tag among them fizzles too ("no tag on the
## products"); no live product is untagged.
func test_the_category_engine_fizzles_with_no_tag() -> void:
	var plain: CardDefinition = CardDefinition.new()
	plain.kind = CardDefinition.Kind.PRODUCT
	plain.display_name = "Plain box"
	plain.base = 2
	var row: Array[CardInstance] = [CardInstance.new(plain, 1)]
	var result: ScoreResult = Scoring.score(row, [_test_upgrade("category")])
	var waste: ScoreStep = result.steps[-1]
	assert_int(waste.step_type).is_equal(ScoreStep.StepType.WASTED)
	assert_int(waste.source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_str(waste.reason).is_equal("no tag on the products")
	assert_bool(waste.row_wide).is_true()
	assert_int(result.total).is_equal(2)


## Rules with neutral numbers do nothing, so they never fizzle; Rule bender and the upgrades
## without rules (slots, redraws) have no condition and never fizzle either.
func test_neutral_and_unconditional_upgrades_never_fizzle() -> void:
	var upgrades: Array[UpgradeDefinition] = [
		_upgrade("Neutral coupon", FirstCouponMultiplierRule.new()),
		_upgrade("Neutral slot", NthProductMultiplierRule.new()),
		_upgrade("Neutral category", DistinctTagBonusRule.new()),
		_upgrade("Bridge", CouponBridgeRule.new()),
	]
	for file_name: String in ["big_basket", "extra_redraw", "rule_bender"]:
		upgrades.append(load("%s/%s.tres" % [UPGRADES_DIR, file_name]) as UpgradeDefinition)
	for row: String in ["bread", "repeat", "bread,cheese,milk"]:
		for step: ScoreStep in Scoring.score(_row(row), upgrades).steps:
			# Repeat alone fizzles on its own; no upgrade does.
			if step.source_kind == ScoreStep.SourceKind.UPGRADE:
				assert_int(step.step_type).override_failure_message(row).is_not_equal(
					ScoreStep.StepType.WASTED
				)


## The live upgrades (data/upgrades) fizzle on a two-product row: the Coupon engine (no coupon)
## and the Slot engine (too few products), each named by its receipt text; the Category engine
## pays. Totals are the cards' own plus the Category engine's bonus.
func test_live_upgrades_fizzle_on_a_short_row() -> void:
	var upgrades: Array[UpgradeDefinition] = []
	for file_name: String in ["coupon_engine", "slot_engine", "category_engine"]:
		upgrades.append(load("%s/%s.tres" % [UPGRADES_DIR, file_name]) as UpgradeDefinition)
	var result: ScoreResult = Scoring.score(_row("bread,milk"), upgrades)
	var fizzles: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.source_index, step.text, step.reason])
	(
		assert_array(fizzles)
		. is_equal(
			[
				[0, "Coupon engine", "no coupon in the row"],
				[1, "Slot engine ×2", "fewer than 6 products"],
			]
		)
	)
	var without: ScoreResult = Scoring.score(_row("bread,milk"), [upgrades[2]])
	assert_int(result.total).is_equal(without.total)
	assert_array(Array(result.payouts)).is_equal(Array(without.payouts))


static func _data(steps: Array) -> Array:
	var data: Array = []
	for step: ScoreStep in steps:
		data.append(step.to_dictionary())
	return data


static func _test_upgrade(kind: String) -> UpgradeDefinition:
	match kind:
		"coupon":
			var coupon: FirstCouponMultiplierRule = FirstCouponMultiplierRule.new()
			coupon.factor = 2
			return _upgrade("Coupon engine", coupon)
		"slot":
			var slot: NthProductMultiplierRule = NthProductMultiplierRule.new()
			slot.product_number = 6
			slot.factor = 2
			return _upgrade("Slot engine", slot)
	var category: DistinctTagBonusRule = DistinctTagBonusRule.new()
	category.bonus_per_tag = 3
	return _upgrade("Category engine", category)


static func _upgrade(upgrade_name: String, rule: UpgradeRule) -> UpgradeDefinition:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.display_name = upgrade_name
	upgrade.type = UpgradeDefinition.Type.RULE_BENDER
	var rules: Array[UpgradeRule] = [rule]
	upgrade.rules = rules
	return upgrade


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
