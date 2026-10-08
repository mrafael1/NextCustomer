extends GdUnitTestSuite
## 2 for 1 and Shelf swap (issue #37, plan v0.23): their fizzles, the steps the count-up plays
## (a LINKED step in the context pass, then 2 for 1's armed ×2 landing as a MULTIPLIER from
## the coupon), and "same product", where a variant counts as its base card everywhere.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_5"


## Each expected fizzle is [slot, receipt text, reason].
func test_fizzles(
	row: String,
	expected: Array,
	_test_parameters := [
		["banana,two_for_one,banana", []],
		["bread,two_for_one,cheese", [[1, "2 for 1 ×2", "not the same product on both sides"]]],
		["two_for_one,banana", [[0, "2 for 1 ×2", "no product on both sides"]]],
		["banana,two_for_one", [[1, "2 for 1 ×2", "no product on both sides"]]],
		[
			"banana,two_for_one,two_for_one,banana",
			[
				[1, "2 for 1 ×2", "no product on both sides"],
				[2, "2 for 1 ×2", "no product on both sides"],
			]
		],
		["bread,banana,shelf_swap,cheese", []],
		["bread,shelf_swap", [[1, "Shelf swap", "no product in the next slot"]]],
		[
			"bread,shelf_swap,repeat",
			[
				[1, "Shelf swap", "no product in the next slot"],
				[2, "Repeat", "no product just before it to copy"],
			]
		],
		["shelf_swap,bread", [[0, "Shelf swap", "no product before it"]]],
		[
			"repeat,shelf_swap,bread",
			[
				[0, "Repeat", "no product just before it to copy"],
				[1, "Shelf swap", "no product before it"],
			]
		],
	]
) -> void:
	var fizzles: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.slot, step.text, step.reason])
			assert_int(step.value).is_equal(0)
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)


## 2 for 1 links its neighbours in the context pass, arms ×2 after its own payout, and the ×2
## lands on the second product as a MULTIPLIER whose source is the coupon.
func test_two_for_one_steps() -> void:
	var steps: Array[ScoreStep] = Scoring.score(_row("banana,two_for_one,banana")).steps
	var linked: ScoreStep = steps[0]
	assert_int(linked.step_type).is_equal(ScoreStep.StepType.LINKED)
	assert_array([linked.slot, linked.linked_slot, linked.source_slot]).is_equal([0, 2, 1])
	var armed: Array = steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.EFFECT_ARMED
	)
	assert_int(armed.size()).is_equal(1)
	assert_array([armed[0].slot, armed[0].value]).is_equal([1, 2])
	var multipliers: Array = steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.MULTIPLIER
	)
	assert_int(multipliers.size()).is_equal(1)
	assert_array([multipliers[0].slot, multipliers[0].source_slot, multipliers[0].value]).is_equal(
		[2, 1, 2]
	)
	assert_int(steps.find(armed[0])).is_less(steps.find(multipliers[0]))


## Shelf swap's link is a LINKED step from the row's first product (coupons skipped) to the
## product after it.
func test_shelf_swap_links_the_first_product() -> void:
	var steps: Array[ScoreStep] = Scoring.score(_row("repeat,bread,banana,shelf_swap,cheese")).steps
	var linked: Array = steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type == ScoreStep.StepType.LINKED
	)
	assert_int(linked.size()).is_equal(1)
	assert_array([linked[0].slot, linked[0].linked_slot, linked[0].source_slot]).is_equal([1, 4, 3])


## A variant counts as its base card: 2 for 1 pairs Banana with Organic banana, Banana's pair
## bonus sees it, and Cheese counts Organic bread as Bread.
func test_a_variant_is_the_same_product_as_its_base() -> void:
	var banana: CardDefinition = load("%s/banana.tres" % FIXTURE_DIR)
	var bread: CardDefinition = load("%s/bread.tres" % FIXTURE_DIR)
	var cheese: CardDefinition = load("%s/cheese.tres" % FIXTURE_DIR)
	var two_for_one: CardDefinition = load("%s/two_for_one.tres" % FIXTURE_DIR)
	var organic_banana: CardDefinition = _variant(banana, &"organic_banana")
	var organic_bread: CardDefinition = _variant(bread, &"organic_bread")
	assert_bool(organic_banana.is_same_product(banana)).is_true()
	assert_bool(banana.is_same_product(organic_banana)).is_true()
	assert_bool(organic_bread.is_same_product(banana)).is_false()
	# Banana, 2 for 1, Organic banana: linked, the pair bonus applies, then ×2.
	var paired: ScoreResult = Scoring.score(_cards([banana, two_for_one, organic_banana]))
	assert_array(Array(paired.payouts)).is_equal([2, 0, 8])
	# Organic bread, Cheese: Cheese's "+4 if immediately after Bread" applies.
	assert_array(Array(Scoring.score(_cards([organic_bread, cheese])).payouts)).is_equal([3, 7])


static func _variant(base_card: CardDefinition, card_id: StringName) -> CardDefinition:
	var variant: CardDefinition = base_card.duplicate()
	variant.id = card_id
	variant.variant_of = base_card
	return variant


static func _row(ids: String) -> Array[CardInstance]:
	var cards: Array[CardDefinition] = []
	for card_id: String in ids.split(","):
		cards.append(load("%s/%s.tres" % [FIXTURE_DIR, card_id]) as CardDefinition)
	return _cards(cards)


static func _cards(definitions: Array[CardDefinition]) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for definition: CardDefinition in definitions:
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
