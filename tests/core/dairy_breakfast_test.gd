extends GdUnitTestSuite
## Dairy and Breakfast (#128, decided with the user on 2026-11-02): Dairy's PAIR (a product beside
## its partner: Butter and Bakery, Cheese and Bread, Yogurt and Banana, Reduced yogurt and
## Clearance, Scone and Dairy, Cereal and Milk, +4 (Cheese +5) for each partner beside it since
## v1.29; Cream +4 for each PAIR in the row) and
## Breakfast (the MORNING keyword and zone were removed on 2026-11-18: Coffee +1 for each
## Breakfast item in the row, itself included; Tea bags ×4 the last Breakfast item after it).
## Live data: the numbers are placeholders for the end balance pass.

const CARDS := "res://data/cards/%s.tres"


func test_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# A PAIR is beside, either side: Cheese 3 + 5 before Bread too.
		["cheese,bread", [8, 5]],
		["bread,cheese", [5, 8]],
		["yogurt,banana", [6, 2]],
		# A PAIR pays for each partner beside it (v1.29): Butter beside Bread and Scone (both
		# Bakery) 2 + 4 × 2, Scone beside Butter and Cream (both Dairy) 2 + 4 × 2. Cream 2 + 4 for
		# each PAIR (Butter, Scone).
		["bread,butter,scone,cream", [5, 10, 10, 10]],
		["bread,cheese,cream", [5, 8, 6]],
		# Coffee counts every Breakfast item in the row, itself included: Coffee, Milk, Eggs and
		# Bread, Coffee 2 + 4; Milk 4 + 1 earlier Breakfast; Crisps 2 x2 (Eggs).
		["coffee,milk,eggs,crisps,bread", [6, 5, 1, 4, 5]],
		["coffee,milk,bread,eggs", [6, 5, 5, 1]],
		# Wherever the Coffee stands: Coffee and Bread behind Potatoes, Coffee 2 + 2; Milk and
		# Coffee round Potatoes, Coffee 2 + 2; Bread, Milk and Coffee 2 + 3.
		["potatoes,coffee,bread", [3, 4, 5]],
		["milk,potatoes,coffee", [4, 3, 4]],
		["bread,potatoes,milk,crisps,coffee", [5, 3, 5, 2, 5]],
		# Tea bags ×4 the last Breakfast item after it: Eggs (1 x 4), not Bread; Eggs x2 Crisps.
		["tea_bags,bread,eggs,crisps", [1, 5, 4, 4]],
		# Milk 4 + 2 earlier Breakfast, x4: Tea bags need not stand in slot 1.
		["bread,tea_bags,milk", [5, 1, 24]],
		# Anywhere after it: Milk in slot 4 (4 + 2 earlier Breakfast) takes the ×4, not Bread.
		["tea_bags,bread,potatoes,milk", [1, 5, 3, 24]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)


## The Breakfast sticker's tag counts: Coffee 2 + 3 (Coffee, Crisps given Breakfast, Bread); without
## the sticker Coffee 2 + 2 (Coffee, Bread).
func test_the_sticker_tag_counts() -> void:
	var result: ScoreResult = Scoring.score(_row("coffee,breakfast_sticker,crisps,bread"))
	assert_int(result.payouts[0]).is_equal(5)
	var plain: ScoreResult = Scoring.score(_row("coffee,crisps,bread"))
	assert_int(plain.payouts[0]).is_equal(4)


## Spot check's slot 3 pays 0€ but its Breakfast item still counts (Coffee 2 + 3).
func test_coffee_counts_under_inspections() -> void:
	var spot: InspectionDefinition = load("res://data/inspections/spot_check.tres")
	var short: InspectionDefinition = load("res://data/inspections/short_belt.tres")
	var checked: ScoreResult = Scoring.score(_row("coffee,milk,bread"), [], [spot, short])
	assert_array(Array(checked.payouts)).is_equal([5, 5, 0])


## Coffee and Tea bags (every tier) read the Breakfast tag from their data; no zone.
func test_the_breakfast_rules_are_data() -> void:
	for id: String in ["coffee", "coffee_big", "coffee_golden"]:
		var rule: TagCountRule = (load(CARDS % id) as CardDefinition).rules[0] as TagCountRule
		assert_str(rule.tag).is_equal("Breakfast")
		assert_int(rule.bonus_each).is_greater(0)
	for id: String in ["tea_bags", "tea_bags_big", "tea_bags_golden"]:
		var tea: GrantChargedMultiplierRule = (
			(load(CARDS % id) as CardDefinition).rules[0] as GrantChargedMultiplierRule
		)
		assert_str(tea.tag).is_equal("Breakfast")
		assert_bool(tea.last_only).is_true()


func test_fizzles(
	row: String,
	wasted: Array,
	_test_parameters := [
		["bread,potatoes,tea_bags", [[2, "no Breakfast item after it"]]],
		["potatoes,potatoes,tea_bags,potatoes", [[2, "no Breakfast item after it"]]],
		["cream,bread", [[0, "no PAIR in the row"]]],
		["cheese,potatoes", [[0, "no Bread beside it"]]],
	]
) -> void:
	assert_array(_wasted(Scoring.score(_row(row)))).is_equal(wasted)


## CardPairs reads the row the same for every rule.
func test_coffee_and_pairs() -> void:
	var state: ScoreResult = Scoring.score(_row("coffee,milk,crisps,eggs"))
	assert_int(state.payouts[0]).is_equal(5)
	var paired: ScoreResult = Scoring.score(_row("cereal,milk,bread,cheese,cream"))
	# Cereal beside Milk and Cheese beside Bread: Cream 2 + 4 x 2.
	assert_int(paired.payouts[4]).is_equal(10)


static func _wasted(result: ScoreResult) -> Array:
	var found: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and not step.row_wide:
			found.append([step.slot, step.reason])
	return found


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id) as CardDefinition, row.size() + 1))
	return row
