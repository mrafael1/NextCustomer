extends GdUnitTestSuite
## Dairy and Breakfast (#128, decided with the user on 2026-11-02): Dairy's PAIR (a product beside
## its partner: Butter and Bakery, Cheese and Bread, Yogurt and Banana, Reduced yogurt and
## Clearance, Scone and Dairy, Cereal and Milk, +4 (Cheese +5) for each partner beside it since
## v1.29; Cream +4 for each PAIR in the row) and
## Breakfast's MORNING (the MORNING ZONE since 2026-11-18: a Breakfast product in the row's first
## 3 slots, data/balance/morning_zone.tres; Coffee +1 for each MORNING item, Tea bags ×4 the last
## MORNING item after it). Live data: the numbers are placeholders for the end balance pass.

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
		# MORNING Coffee, Milk, Eggs (the zone's 3 slots; Bread in slot 5 is outside): Coffee
		# 2 + 3; Milk 4 + 1 earlier Breakfast; Crisps 2 x2 (Eggs).
		["coffee,milk,eggs,crisps,bread", [5, 5, 1, 4, 5]],
		# A Breakfast item past slot 3 is no MORNING item: Coffee 2 + 3, not + 4.
		["coffee,milk,bread,eggs", [5, 5, 5, 1]],
		# No first-slot condition and no run: Coffee and Bread behind Potatoes, Coffee 2 + 2;
		# Milk and Coffee round Potatoes, Coffee 2 + 2.
		["potatoes,coffee,bread", [3, 4, 5]],
		["milk,potatoes,coffee", [4, 3, 4]],
		# The zone is the row's first 3 slots wherever the Coffee stands: Coffee in slot 5, 2 + 2.
		["bread,potatoes,milk,crisps,coffee", [5, 3, 5, 2, 4]],
		# Tea bags ×4 the last MORNING item after it: Eggs (1 x 4), not Bread; Eggs x2 Crisps.
		["tea_bags,bread,eggs,crisps", [1, 5, 4, 4]],
		# Milk 4 + 2 earlier Breakfast, x4: Tea bags need not stand in slot 1.
		["bread,tea_bags,milk", [5, 1, 24]],
		# Tea bags' item must be in the zone: Bread (slot 2) takes the ×4, not Milk in slot 4.
		["tea_bags,bread,potatoes,milk", [1, 20, 3, 6]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)


## A coupon in the zone takes its slot (it is no MORNING item), and the Breakfast sticker's tag
## counts: Coffee 2 + 2 (Coffee, Crisps given Breakfast in slot 3; Bread in slot 4 is outside).
## Without the sticker Bread stands in slot 3: Coffee 2 + 2 too (Coffee, Bread).
func test_a_coupon_takes_a_zone_slot_and_the_sticker_tag_counts() -> void:
	var result: ScoreResult = Scoring.score(_row("coffee,breakfast_sticker,crisps,bread"))
	assert_int(result.payouts[0]).is_equal(4)
	assert_array(Array(result.mornings)).is_equal([0, 2])
	var plain: ScoreResult = Scoring.score(_row("coffee,crisps,bread"))
	assert_int(plain.payouts[0]).is_equal(4)
	assert_array(Array(plain.mornings)).is_equal([0, 2])


## The zone is the row's own first slots under any day event: Spot check's slot 3 pays 0€ but
## its Breakfast item is still a MORNING item (Coffee 2 + 3), and Short belt only shortens the
## row's end.
func test_the_zone_under_inspections() -> void:
	var spot: InspectionDefinition = load("res://data/inspections/spot_check.tres")
	var short: InspectionDefinition = load("res://data/inspections/short_belt.tres")
	var checked: ScoreResult = Scoring.score(_row("coffee,milk,bread"), [], [spot, short])
	assert_array(Array(checked.payouts)).is_equal([5, 5, 0])
	assert_array(Array(checked.mornings)).is_equal([0, 1, 2])


## The zone's size is the balance value every MORNING card points at, and the result lists the
## MORNING items only when a card in the row reads MORNING.
func test_the_zone_is_balance_data() -> void:
	var zone: MorningZone = load("res://data/balance/morning_zone.tres")
	assert_int(zone.slots).is_equal(3)
	for id: String in ["coffee", "coffee_big", "coffee_golden"]:
		var card: CardDefinition = load(CARDS % id)
		assert_object(CardMorning.zone_of([card])).is_same(zone)
	for id: String in ["tea_bags", "tea_bags_big", "tea_bags_golden"]:
		var card: CardDefinition = load(CARDS % id)
		assert_object(CardMorning.zone_of([card])).is_same(zone)
	assert_object(CardMorning.zone_of([load(CARDS % "milk") as CardDefinition])).is_null()
	assert_array(Array(Scoring.score(_row("milk,bread")).mornings)).is_empty()


func test_fizzles(
	row: String,
	wasted: Array,
	_test_parameters := [
		# Coffee past the zone with no Breakfast item in it.
		["potatoes,potatoes,potatoes,coffee", [[3, "no MORNING item in the row"]]],
		["bread,potatoes,tea_bags", [[2, "no MORNING item after it"]]],
		# The Breakfast item after the Tea bags stands past the zone.
		["potatoes,potatoes,tea_bags,bread", [[2, "no MORNING item after it"]]],
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
