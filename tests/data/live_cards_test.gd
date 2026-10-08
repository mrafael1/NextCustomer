extends GdUnitTestSuite
## Tests on the live data/ files. Unlike the golden rows, these expected values are updated
## when card values are tuned between playtest rounds (plan section 3.7).

const CARDS_DIR := "res://data/cards"


func test_live_cards_score_the_design_examples() -> void:
	assert_int(Scoring.score(_row("eggs,bread,cheese,banana,banana,repeat")).total).is_equal(31)
	assert_int(Scoring.score(_row("banana,repeat,bread,eggs,banana,cheese")).total).is_equal(18)


func test_starter_deck_matches_the_plan() -> void:
	var deck: DeckDefinition = load("res://data/decks/starter.tres")
	var counts: Dictionary = {}
	for card: CardDefinition in deck.cards:
		counts[card.id] = int(counts.get(card.id, 0)) + 1
	(
		assert_dict(counts)
		. is_equal(
			{
				&"banana": 3,
				&"bread": 2,
				&"milk": 2,
				&"eggs": 2,
				&"coffee": 2,
				&"soup": 1,
				&"repeat": 1,
			}
		)
	)


## The base products' rows (issue #34), worked out by hand from the rules.
func test_base_products_score_the_design_examples(
	row: String,
	total: int,
	_test_parameters := [
		# Milk: (3 + 2 x 2 earlier Breakfast) x2 Eggs x2 Tea bags x2 Multipack = 56.
		["eggs,tea_bags,multipack,milk", 58],
		# Bulb 1; buns 2 + 3 after Clearance + 3 from the bulb; can 2 + 2 x 2 earlier Clearance.
		["flickering_bulb,day_old_buns,dented_can", 15],
		# Repeat copies Bread's 3; Scissors 1 + 2 for Repeat; Batteries 1 + 4 in the last slot.
		["bread,repeat,scissors,batteries", 14],
		# Butter 5, Bread 3, Crackers 5, Soup 5, Cereal 5, Milk 3 + 2 x 2 (Bread, Cereal) = 7.
		["butter,bread,crackers,soup,cereal,milk", 30],
		# Banana 2, Yogurt 5, Carrier bag 1 + 2 earlier Food, Reduced yogurt 5, Dented can 4.
		["banana,yogurt,carrier_bag,reduced_yogurt,dented_can", 19],
		# Tea bags isn't Food: Eggs skips it. Tea doubles Bread: 1 + 6.
		["tea_bags,bread", 7],
	]
) -> void:
	assert_int(Scoring.score(_row(row)).total).is_equal(total)


## The base products' fizzles: Scissors with no earlier coupon, an unused Tea bags charge, a
## Flickering bulb with no Clearance product after it, Batteries not in the last slot.
func test_base_products_fizzle(
	row: String,
	expected: Array,
	_test_parameters := [
		["scissors", [[0, "Scissors: earlier coupons", "no coupon before it"]]],
		["bread,scissors", [[1, "Scissors: earlier coupons", "no coupon before it"]]],
		["repeat,scissors", [[0, "Repeat", "no product just before it to copy"]]],
		["tea_bags,soup", [[0, "Tea bags ×2", "1 charge unused"]]],
		["flickering_bulb,bread", [[0, "Flickering bulb bonus", "no Clearance product after it"]]],
		["batteries,bread", [[0, "Batteries last", "not in the last slot"]]],
		["eggs,carrier_bag,bread,bread", []],
	]
) -> void:
	var fizzles: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.source_slot, step.text, step.reason])
	assert_array(fizzles).is_equal(expected)


func test_all_twenty_five_cards_exist() -> void:
	var ids: Array = []
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			ids.append((load("%s/%s" % [CARDS_DIR, file]) as CardDefinition).id)
	assert_int(ids.size()).is_equal(25)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
