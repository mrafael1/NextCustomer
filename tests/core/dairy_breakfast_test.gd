extends GdUnitTestSuite
## Dairy and Breakfast (#128, decided with the user on 2026-11-02): Dairy's PAIR (a product beside
## its partner: Butter and Bakery, Cheese and Bread, Yogurt and Banana, Reduced yogurt and
## Clearance, Scone and Dairy, Cereal and Milk, +4 (Cheese +5) for each partner beside it since
## v1.28; Cream +4 for each PAIR in the row) and
## Breakfast's MORNING (the row's opening run of Breakfast products, coupons skipped; Coffee +1
## for each MORNING product, Tea bags ×4 the last MORNING product after it). Live data: the
## numbers are placeholders for the end balance pass.

const CARDS := "res://data/cards/%s.tres"


func test_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# A PAIR is beside, either side: Cheese 3 + 5 before Bread too.
		["cheese,bread", [8, 5]],
		["bread,cheese", [5, 8]],
		["yogurt,banana", [6, 2]],
		# A PAIR pays for each partner beside it (v1.28): Butter beside Bread and Scone (both
		# Bakery) 2 + 4 × 2, Scone beside Butter and Cream (both Dairy) 2 + 4 × 2. Cream 2 + 4 for
		# each PAIR (Butter, Scone).
		["bread,butter,scone,cream", [5, 10, 10, 10]],
		["bread,cheese,cream", [5, 8, 6]],
		# MORNING Coffee, Milk, Eggs (Crisps ends it): Coffee 2 + 3; Milk 4 + 1 earlier Breakfast;
		# Crisps 2 x2 (Eggs).
		["coffee,milk,eggs,crisps,bread", [5, 5, 1, 4, 5]],
		# Tea bags ×4 the last MORNING product after it: Eggs (1 x 4), not Bread; Eggs x2 Crisps.
		["tea_bags,bread,eggs,crisps", [1, 5, 4, 4]],
		# Milk 4 + 2 earlier Breakfast, x4: Tea bags need not open the MORNING.
		["bread,tea_bags,milk", [5, 1, 24]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)


## Coupons neither join nor end the MORNING, and the Breakfast sticker's tag joins it: Coffee
## 2 + 3 (Coffee, Crisps given Breakfast, Bread).
func test_the_breakfast_sticker_extends_the_morning() -> void:
	var result: ScoreResult = Scoring.score(_row("coffee,breakfast_sticker,crisps,bread"))
	assert_int(result.payouts[0]).is_equal(5)
	var plain: ScoreResult = Scoring.score(_row("coffee,crisps,bread"))
	assert_int(plain.payouts[0]).is_equal(3)


func test_fizzles(
	row: String,
	wasted: Array,
	_test_parameters := [
		["potatoes,coffee", [[1, "no MORNING item in the row"]]],
		["bread,potatoes,tea_bags", [[2, "no MORNING item after it"]]],
		["cream,bread", [[0, "no PAIR in the row"]]],
		["cheese,potatoes", [[0, "no Bread beside it"]]],
	]
) -> void:
	assert_array(_wasted(Scoring.score(_row(row)))).is_equal(wasted)


## CardMorning and CardPairs read the row the same for every rule.
func test_morning_and_pairs() -> void:
	var state: ScoreResult = Scoring.score(_row("coffee,milk,crisps,eggs"))
	assert_int(state.payouts[0]).is_equal(4)
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
