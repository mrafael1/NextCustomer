extends GdUnitTestSuite
## Bakery batches (#128, family identities v3, approved by the user on 2026-11-01): a batch is 2
## or more Bakery products beside each other, and each Bakery item's job works only at its place
## in it. "Each item in its batch" counts every item of the batch, the card itself included (the
## user's round 2 of 2026-11-19). Croissant opens (first: +2 to each item of the batch, itself
## included), Baguette fills (+4 per item of its batch, itself included, wherever it sits, no
## cap), Stale doughnut closes (last: +3 per item of the batch), Iced bun glazes (×2 the batch's
## last item) and Birthday candles party (+3 to each item of any batch just after them).
## Anywhere else each fizzles with a reason.
## Every batch also pays its size bonus (#128 batch polish, approved 2026-11-19): +1 each for 2,
## +2 each for 3, +3 each for 4 or more, before any multiplier.
## Live data: the numbers are placeholders for the end balance pass, so a tuning change updates
## these rows.

const CARDS := "res://data/cards/%s.tres"


func test_batch_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# The v3 page's belt, each + 3 for its batch of 4 and + 2 from the Croissant: opener 2 + 2
		# (itself included); bodies 2 + 4 × 4; closer 1 + 3 × 4.
		["croissant,baguette,baguette,stale_doughnut", [7, 23, 23, 18]],
		# Baguette counts every item of its batch, itself included, wherever it sits, with no cap:
		# 2 + 4 × 4 + 3 each (Bread opens: Bread is Bakery).
		["bread,baguette,baguette,baguette", [8, 21, 21, 21]],
		# First in its batch, a Baguette still works (round 2): 2 + 4 × 2 + 1; Bread 5 + 1.
		["baguette,bread", [11, 6]],
		# Bread is Bakery, so it fills a batch: the doughnut closes a batch of 3 (+2 each).
		["bread,bread,stale_doughnut", [7, 7, 12]],
		# Iced bun doubles the closer wherever it sits, its size bonus too: (1 + 3 × 3 + 2) × 2.
		["iced_bun,bread,stale_doughnut", [3, 7, 24]],
		["bread,iced_bun,stale_doughnut", [7, 3, 24]],
		# Two glazes stack on the one closer: (1 + 3 × 3 + 2) × 2 × 2.
		["iced_bun,iced_bun,stale_doughnut", [3, 3, 48]],
		# Birthday candles: +3 to each product of the batch just after them (+2 each: 3).
		["birthday_candles,bread,bread,bread", [2, 10, 10, 10]],
		# Any batch counts, 2 items too (no least size since round 2): 5 + 3 + 1 each.
		["birthday_candles,bread,bread", [2, 9, 9]],
		# Golden tiers (+1 each: a batch of 2): opener 4 + 4 itself; body 4 + 8 × 2 + 4.
		["croissant_golden,baguette_golden", [9, 25]],
		["iced_bun_golden,bread,stale_doughnut", [5, 7, 36]],
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
		["bread,croissant,bread", [7, 4, 7], [[1, "not first in its Bakery batch"]]],
		[
			"croissant,banana,baguette",
			[2, 2, 2],
			[
				[0, "no Bakery item beside it"],
				[1, "no Banana beside it"],
				[2, "no Bakery item beside it"],
			]
		],
		["stale_doughnut,bread", [2, 6], [[0, "not last in its Bakery batch"]]],
		["bread,iced_bun", [6, 2], [[1, "it closes its batch: nothing to glaze"]]],
		# The candles must open the batch: one after a batch of 3 has none after it.
		[
			"bread,bread,bread,birthday_candles",
			[7, 7, 7, 2],
			[
				[3, "no Bakery batch right after it"],
			]
		],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_array(_wasted(result)).is_equal(wasted)


## The BATCH size bonus (#128 batch polish): each product of a Bakery batch gets +1 for a batch
## of 2, +2 for 3 and +3 for 4 or more (the data's last entry), with or without a job card, as a
## "Batch of N" FLAT step of its own; a lone Bakery product gets none. `batches` and `bonuses` are
## the belt's batches and each one's size bonus.
func test_batch_size_bonus(
	row: String,
	payouts: Array,
	batches: Array,
	bonuses: Array,
	_test_parameters := [
		# Size 1: no batch, no bonus.
		["bread,banana", [5, 2], [], []],
		["bread,bread", [6, 6], [[0, 1]], [1]],
		["bread,bread,bread", [7, 7, 7], [[0, 1, 2]], [2]],
		["bread,bread,bread,bread", [8, 8, 8, 8], [[0, 1, 2, 3]], [3]],
		["bread,bread,bread,bread,bread", [8, 8, 8, 8, 8], [[0, 1, 2, 3, 4]], [3]],
		# A coupon's link joins a batch: 2 for 1 makes the Breads beside each other (+1 each),
		# then doubles the second: (5 + 1) × 2.
		["bread,two_for_one,bread", [6, 0, 12], [[0, 2]], [1]],
		# Two separate batches each get their own size's bonus.
		["bread,bread,banana,bread,bread,bread", [6, 6, 2, 7, 7, 7], [[0, 1], [3, 4, 5]], [1, 2]],
		# Croissant's +2 to each item, itself included, stacks with the size bonus: 2 + 2 + 2;
		# 5 + 2 + 2.
		["croissant,bread,bread", [6, 9, 9], [[0, 1, 2]], [2]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)
	var found: Array = []
	for batch: PackedInt32Array in result.batches:
		found.append(Array(batch))
	assert_array(found).is_equal(batches)
	assert_array(Array(result.batch_bonuses)).is_equal(bonuses)
	var size_steps: int = 0
	for step: ScoreStep in result.steps:
		if step.text.begins_with("Batch of "):
			size_steps += 1
			assert_int(step.step_type).is_equal(ScoreStep.StepType.FLAT)
			assert_int(step.batch_size).is_greater(1)
	var members: int = 0
	for batch: Array in batches:
		members += batch.size()
	assert_int(size_steps).is_equal(members)


## The size bonus is a flat step before Iced bun's ×2, named for its batch's size.
func test_size_bonus_comes_before_the_glaze() -> void:
	var result: ScoreResult = Scoring.score(_row("iced_bun,bread,stale_doughnut"))
	var last: Array = []
	for step: ScoreStep in result.steps:
		if (
			step.slot == 2
			and step.step_type in [ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER]
		):
			last.append([step.step_type, step.text, step.value])
	(
		assert_array(last)
		. contains_exactly(
			[
				[ScoreStep.StepType.FLAT, "Stale doughnut closes batch", 9],
				[ScoreStep.StepType.FLAT, "Batch of 3", 2],
				[ScoreStep.StepType.MULTIPLIER, "Iced bun glaze", 2],
			]
		)
	)


## Every Bakery product carries the shared size bonus; no other card does.
func test_every_bakery_product_carries_the_size_bonus() -> void:
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if not file.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file) as CardDefinition
		var bakery: bool = card.is_product() and card.tags.has("Bakery")
		assert_bool(card.batch_bonus != null).override_failure_message(file).is_equal(bakery)
		if bakery:
			assert_str(card.batch_bonus.tag).is_equal("Bakery")


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
