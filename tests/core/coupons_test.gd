extends GdUnitTestSuite
## The phase 2 coupons of issue #36 (plan v0.26): Clearance tag (the next product gains
## Clearance) and Opening deal (in the first slot, the next product pays ×3). Their fizzles,
## the steps the count-up plays, and how they meet the upgrades (Coupon engine, Category
## engine). Rows use the frozen fixture cards_v0_6, upgrades built here from their rule scripts.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_6"


## Each expected fizzle is [slot, receipt text, reason].
func test_fizzles(
	row: String,
	expected: Array,
	_test_parameters := [
		["clearance_tag,bread,day_old_buns", []],
		["bread,clearance_tag", [[1, "Clearance tag", "no product in the next slot"]]],
		[
			"clearance_tag,day_old_buns,day_old_buns",
			[[0, "Clearance tag", "already Clearance"]],
		],
		[
			"clearance_tag,repeat,bread",
			[
				[0, "Clearance tag", "no product in the next slot"],
				[1, "Repeat", "no product just before it to copy"],
			]
		],
		["opening_deal,soup,bread", []],
		["opening_deal,breakfast_sticker,banana", []],
		["bread,opening_deal,soup", [[1, "Opening deal ×3", "not in the first slot"]]],
		[
			"opening_deal,repeat",
			[
				[0, "Opening deal ×3", "no product after it"],
				[1, "Repeat", "no product just before it to copy"],
			]
		],
		["opening_deal", [[0, "Opening deal ×3", "no product after it"]]],
		[
			"clearance_tag,opening_deal,bread",
			[
				[0, "Clearance tag", "no product in the next slot"],
				[1, "Opening deal ×3", "not in the first slot"],
			]
		],
		[
			"opening_deal,opening_deal,bread",
			[[1, "Opening deal ×3", "not in the first slot"]],
		],
	]
) -> void:
	var fizzles: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.slot, step.text, step.reason])
			assert_int(step.value).is_equal(0)
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)


## Clearance tag adds the tag in the context pass: a TAG_ADDED step on the next product, from
## the coupon, before the first slot is scanned.
func test_clearance_tag_steps() -> void:
	var result: ScoreResult = Scoring.score(_row("clearance_tag,bread,day_old_buns"))
	var added: ScoreStep = result.steps[0]
	assert_int(added.step_type).is_equal(ScoreStep.StepType.TAG_ADDED)
	assert_array([added.slot, added.source_slot, added.tag]).is_equal([1, 0, "Clearance"])
	assert_bool(result.tags[1].has("Clearance")).is_true()


## Opening deal arms ×3 after its own payout of 0, and the ×3 lands on the row's first product
## as a MULTIPLIER whose source is the coupon, after that product's flat bonuses.
func test_opening_deal_steps() -> void:
	var steps: Array[ScoreStep] = Scoring.score(_row("opening_deal,breakfast_sticker,banana")).steps
	var armed: Array = _of_type(steps, ScoreStep.StepType.EFFECT_ARMED)
	assert_int(armed.size()).is_equal(1)
	assert_array([armed[0].slot, armed[0].source_slot, armed[0].value]).is_equal([0, 0, 3])
	var multipliers: Array = _of_type(steps, ScoreStep.StepType.MULTIPLIER)
	assert_int(multipliers.size()).is_equal(1)
	(
		assert_array([multipliers[0].slot, multipliers[0].source_slot, multipliers[0].value_after])
		. is_equal([2, 0, 6])
	)
	assert_int(steps.find(armed[0])).is_less(steps.find(multipliers[0]))


## A ×3 aimed at a Soup beside Frozen is spent like an Egg charge: its MULTIPLIER step stays,
## the payout becomes 0, and there is no WASTED step.
func test_opening_deal_on_a_zeroed_soup_is_spent() -> void:
	var result: ScoreResult = Scoring.score(_row("opening_deal,soup,frozen_peas"))
	assert_array(Array(result.payouts)).is_equal([0, 0, 3])
	assert_int(_of_type(result.steps, ScoreStep.StepType.MULTIPLIER).size()).is_equal(1)
	assert_int(_of_type(result.steps, ScoreStep.StepType.WASTED).size()).is_equal(0)


## A working Opening deal is the row's first coupon and pays 0, so Coupon engine fizzles on it
## (decided with the user: Opening deal's cost) and a Repeat later isn't doubled.
func test_coupon_engine_fizzles_on_opening_deal() -> void:
	var engine: FirstCouponMultiplierRule = FirstCouponMultiplierRule.new()
	engine.factor = 2
	var upgrades: Array[UpgradeDefinition] = [_built_upgrade(engine)]
	var result: ScoreResult = Scoring.score(_row("opening_deal,soup,repeat"), upgrades)
	assert_array(Array(result.payouts)).is_equal([0, 15, 15])
	var fizzles: Array = _of_type(result.steps, ScoreStep.StepType.WASTED)
	assert_int(fizzles.size()).is_equal(1)
	assert_int(fizzles[0].source_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_str(fizzles[0].reason).is_equal("the first coupon paid nothing")


## Category engine counts the tag Clearance tag adds: Bread's 3 tags become 4.
func test_category_engine_counts_the_added_clearance_tag() -> void:
	var engine: DistinctTagBonusRule = DistinctTagBonusRule.new()
	engine.bonus_per_tag = 3
	var upgrades: Array[UpgradeDefinition] = [_built_upgrade(engine)]
	assert_int(Scoring.score(_row("bread"), upgrades).total).is_equal(12)
	assert_int(Scoring.score(_row("clearance_tag,bread"), upgrades).total).is_equal(15)


static func _of_type(steps: Array[ScoreStep], step_type: ScoreStep.StepType) -> Array:
	return steps.filter(func(step: ScoreStep) -> bool: return step.step_type == step_type)


static func _built_upgrade(rule: UpgradeRule) -> UpgradeDefinition:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.display_name = "Test upgrade"
	upgrade.type = UpgradeDefinition.Type.COUPON_ENGINE
	var rules: Array[UpgradeRule] = [rule]
	upgrade.rules = rules
	return upgrade


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
