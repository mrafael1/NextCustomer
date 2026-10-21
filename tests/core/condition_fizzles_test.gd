extends GdUnitTestSuite
## Condition fizzles (#45): a conditional card whose condition fails records one WASTED step
## that names what was missing, and the total is the same as before the step existed. On the
## frozen fixtures, so the totals are the rules' own.

const V0_4 := "res://tests/fixtures/cards_v0_4"
const V0_6 := "res://tests/fixtures/cards_v0_6"


## Each expected fizzle is [slot, receipt text, reason], in step order; `total` is the row's
## total, worked out by hand from the rules (a fizzle never changes it).
func test_condition_fizzles(
	fixture: String,
	row: String,
	expected: Array,
	total: int,
	_test_parameters := [
		[V0_4, "banana", [[0, "Banana pair", "no Banana just before it"]], 2],
		[V0_4, "banana,banana", [[0, "Banana pair", "no Banana just before it"]], 6],
		[
			V0_4,
			"banana,repeat,banana",
			[
				[0, "Banana pair", "no Banana just before it"],
				[2, "Banana pair", "no Banana just before it"],
			],
			6
		],
		[V0_4, "bread,cheese", [], 10],
		[V0_4, "cheese,bread", [[0, "Cheese after Bread", "no Bread just before it"]], 6],
		[V0_4, "milk", [[0, "Milk: earlier Breakfast", "no Breakfast product before it"]], 3],
		[V0_4, "bread,milk", [], 8],
		[V0_4, "frozen_peas", [[0, "Frozen pair", "no Frozen product beside it"]], 3],
		[V0_4, "frozen_peas,frozen_peas", [], 12],
		[
			V0_6,
			"day_old_buns",
			[[0, "Day-old buns after Clearance", "no Clearance product just before it"]],
			2
		],
		[
			V0_6,
			"dented_can",
			[[0, "Dented can: earlier Clearance", "no Clearance product before it"]],
			2
		],
		[
			V0_6,
			"reduced_yogurt",
			[[0, "Reduced yogurt beside Clearance", "no Clearance product beside it"]],
			2
		],
		[V0_6, "reduced_yogurt,dented_can", [], 9],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(fixture, row))
	var fizzles: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.slot, step.text, step.reason])
			assert_int(step.value).is_equal(0)
			assert_int(step.source_slot).is_equal(step.slot)
			assert_int(step.value_after).is_equal(result.payouts[step.slot])
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)
	assert_int(result.total).override_failure_message(row).is_equal(total)


## A condition fizzle follows the card's PAYOUT, like every own-rule fizzle.
func test_condition_fizzle_follows_the_payout() -> void:
	var actual: Array = []
	for step: ScoreStep in Scoring.score(_row(V0_4, "cheese,bread")).steps:
		actual.append("%s %d" % [ScoreStep.StepType.keys()[step.step_type], step.slot])
	assert_array(actual).is_equal(["BASE 0", "PAYOUT 0", "WASTED 0", "BASE 1", "PAYOUT 1"])


## A rule with neutral numbers does nothing, so it never fizzles.
func test_neutral_rules_never_fizzle() -> void:
	var card: CardDefinition = CardDefinition.new()
	card.kind = CardDefinition.Kind.PRODUCT
	card.display_name = "Plain"
	card.base = 2
	var adjacent: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	adjacent.match_by = AdjacentMatchBonusRule.Match.SAME_CARD
	adjacent.position = AdjacentMatchBonusRule.Position.BESIDE
	var earlier: CountEarlierTagBonusRule = CountEarlierTagBonusRule.new()
	earlier.tag = "Food"
	var rules: Array[Rule] = [adjacent, earlier, AdjacentMatchBonusRule.new()]
	card.rules = rules
	var row: Array[CardInstance] = [CardInstance.new(card, 1)]
	for step: ScoreStep in Scoring.score(row).steps:
		assert_int(step.step_type).is_not_equal(ScoreStep.StepType.WASTED)


static func _row(fixture: String, ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [fixture, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
