extends GdUnitTestSuite
## Bakery batches (#128, family identities v3, approved by the user on 2026-11-01): a batch is 2
## or more Bakery products beside each other, and each Bakery item's job works only at its place
## in it. Croissant opens (first: +2 to every later product of the batch), Baguette fills (+4 per
## earlier product of the batch, up to 2), Stale doughnut closes (last: +3 per product of the
## batch), Iced bun glazes (×2 the batch's last product) and Birthday candles party (+3 to each
## product of a batch of 3 or more just after it). Anywhere else each fizzles with a reason.
## Live data: the numbers are placeholders for the end balance pass, so a tuning change updates
## these rows.

const CARDS := "res://data/cards/%s.tres"


func test_batch_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# The v3 page's belt: opener 2; bodies 2 + 4 + 2 and 2 + 8 + 2; closer 1 + 3 × 4 + 2.
		["croissant,baguette,baguette,stale_doughnut", [2, 8, 12, 15]],
		# Baguette counts up to 2 earlier batch products (Bread opens: Bread is Bakery).
		["bread,baguette,baguette,baguette", [5, 6, 10, 10]],
		# Bread is Bakery, so it fills a batch: the doughnut closes a batch of 3.
		["bread,bread,stale_doughnut", [5, 5, 10]],
		# Iced bun doubles the closer wherever it sits: (1 + 3 × 3) × 2.
		["iced_bun,bread,stale_doughnut", [1, 5, 20]],
		["bread,iced_bun,stale_doughnut", [5, 1, 20]],
		# Two glazes stack on the one closer: (1 + 3 × 3) × 2 × 2.
		["iced_bun,iced_bun,stale_doughnut", [1, 1, 40]],
		# Birthday candles: +3 to each product of the baked batch just after them.
		["birthday_candles,bread,bread,bread", [2, 8, 8, 8]],
		# Golden tiers: opener +4, body +8 per earlier.
		["croissant_golden,baguette_golden", [4, 16]],
		["iced_bun_golden,bread,stale_doughnut", [3, 5, 30]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)
	assert_array(_wasted(result)).is_empty()


## Out of place, a role fizzles: a WASTED step that says why, the total unchanged.
func test_misplaced_roles_fizzle(
	row: String,
	payouts: Array,
	wasted: Array,
	_test_parameters := [
		["bread,croissant,bread", [5, 2, 5], [[1, "not first in its Bakery batch"]]],
		[
			"croissant,banana,baguette",
			[2, 2, 2],
			[
				[0, "no Bakery item beside it"],
				[1, "no Banana beside it"],
				[2, "no Bakery item beside it"],
			]
		],
		["baguette,bread", [2, 5], [[0, "first in its batch: nothing before it"]]],
		["stale_doughnut,bread", [1, 5], [[0, "not last in its Bakery batch"]]],
		["bread,iced_bun", [5, 1], [[1, "it closes its batch: nothing to glaze"]]],
		["birthday_candles,bread,bread", [2, 5, 5], [[0, "no batch of 3 Bakery right after it"]]],
		# The candles must open the batch: one after a batch of 3 has none after it.
		[
			"bread,bread,bread,birthday_candles",
			[5, 5, 5, 2],
			[
				[3, "no batch of 3 Bakery right after it"],
			]
		],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_array(_wasted(result)).is_equal(wasted)


## A batch is every Bakery product reached through Bakery products beside each other, in slot
## order; a lone Bakery product or a non-product is in none.
func test_batch_members() -> void:
	var state := ScoreState.new(_row("bread,croissant,banana,baguette,bread,bread"))
	assert_array(Array(CardBatch.members(state, 1, "Bakery"))).is_equal([0, 1])
	assert_array(Array(CardBatch.members(state, 4, "Bakery"))).is_equal([3, 4, 5])
	assert_array(Array(CardBatch.members(state, 2, "Bakery"))).is_empty()
	var lone := ScoreState.new(_row("banana,bread,banana"))
	assert_array(Array(CardBatch.members(lone, 1, "Bakery"))).is_empty()


static func _wasted(result: ScoreResult) -> Array:
	var found: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			found.append([step.slot, step.reason])
	return found


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id) as CardDefinition, row.size() + 1))
	return row
