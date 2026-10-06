extends GdUnitTestSuite
## WASTED steps: the "fizzle" moments for the receipt and count-up (plan v0.5). Each one names
## the card whose effect did nothing and why, is worth 0, and never changes a payout.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"


## Each expected fizzle is [slot, source_slot, receipt text, reason], in step order.
func test_fizzles(
	row: String,
	expected: Array,
	_test_parameters := [
		["eggs,bread,cheese,banana,banana,repeat", []],
		["bread,coffee", [[1, 1, "Coffee bonus", "no Breakfast product after it"]]],
		["eggs,bread", [[0, 0, "Eggs ×2", "1 charge unused"]]],
		["eggs", [[0, 0, "Eggs ×2", "2 charges unused"]]],
		[
			"eggs,eggs,bread",
			[
				[0, 1, "Eggs ×2", "1 charge wiped by a reset"],
				[1, 1, "Eggs ×2", "1 charge unused"],
			]
		],
		[
			"breakfast_sticker,repeat,banana",
			[
				[0, 0, "Breakfast sticker", "no product in the next slot"],
				[1, 1, "Repeat", "no product just before it to copy"],
			]
		],
		["breakfast_sticker", [[0, 0, "Breakfast sticker", "no product in the next slot"]]],
		["breakfast_sticker,bread", [[0, 0, "Breakfast sticker", "already Breakfast"]]],
		[
			"bundle,banana,banana,bundle",
			[
				[0, 0, "Bundle", "no product on both sides"],
				[3, 3, "Bundle", "no product on both sides"],
			]
		],
		[
			"banana,bundle,bundle",
			[
				[1, 1, "Bundle", "no product on both sides"],
				[2, 2, "Bundle", "no product on both sides"],
			]
		],
		["banana,bundle,banana", []],
		["multipack,bread", [[0, 0, "Multipack ×2", "no product just before it"]]],
		[
			"coffee,multipack,banana",
			[
				[0, 0, "Coffee bonus", "no Breakfast product after it"],
				[1, 1, "Multipack ×2", "no later product shared a tag"],
			]
		],
		["bread,multipack,bread", []],
		["final_markdown,bread", [[0, 0, "Final markdown", "not in the last slot"]]],
		["bread,final_markdown", []],
		["repeat", [[0, 0, "Repeat", "no product just before it to copy"]]],
		["frozen_peas,soup,repeat", []],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	var fizzles: Array = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.slot, step.source_slot, step.text, step.reason])
			assert_int(step.value).is_equal(0)
	assert_array(fizzles).override_failure_message("%s: %s" % [row, fizzles]).is_equal(expected)


## The count-up plays steps in order, so fizzles must sit where core/score_step.gd says:
## context-pass fizzles first, own-rule fizzles right after the card's PAYOUT (and any
## EFFECT_ARMED), a reset fizzle right after the resetting card's EFFECT_ARMED, and leftover
## effects at the very end.
func test_fizzle_order(
	row: String,
	sequence: Array,
	_test_parameters := [
		[
			"eggs,eggs,bread",
			[
				"BASE 0",
				"PAYOUT 0",
				"EFFECT_ARMED 0",
				"BASE 1",
				"MULTIPLIER 1",
				"PAYOUT 1",
				"EFFECT_ARMED 1",
				"WASTED 0",
				"BASE 2",
				"MULTIPLIER 2",
				"PAYOUT 2",
				"WASTED 1",
			]
		],
		[
			"breakfast_sticker,repeat,banana",
			[
				"WASTED 0",
				"BASE 0",
				"PAYOUT 0",
				"BASE 1",
				"PAYOUT 1",
				"WASTED 1",
				"BASE 2",
				"PAYOUT 2",
			]
		],
		[
			"bread,coffee",
			["BASE 0", "PAYOUT 0", "BASE 1", "PAYOUT 1", "EFFECT_ARMED 1", "WASTED 1"]
		],
		["multipack,bread", ["BASE 0", "PAYOUT 0", "WASTED 0", "BASE 1", "PAYOUT 1"]],
		[
			"coffee,multipack,banana",
			[
				"BASE 0",
				"PAYOUT 0",
				"EFFECT_ARMED 0",
				"BASE 1",
				"PAYOUT 1",
				"EFFECT_ARMED 1",
				"BASE 2",
				"PAYOUT 2",
				"WASTED 0",
				"WASTED 1",
			]
		],
	]
) -> void:
	var actual: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		actual.append("%s %d" % [ScoreStep.StepType.keys()[step.step_type], step.slot])
	assert_array(actual).override_failure_message("%s: %s" % [row, actual]).is_equal(sequence)


## A fizzle keeps the card's running value (its payout once scanned), so a count-up that
## labels cards from value_after never drops a card to 0.
func test_fizzles_keep_the_running_value() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,eggs,bread,coffee"))
	var checked: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			assert_int(step.value_after).is_equal(result.payouts[step.slot])
			assert_int(step.value_after).is_greater(0)
			checked += 1
	assert_int(checked).is_equal(3)


## Repeat always gets a COPY step naming the copied slot when there is a product to copy,
## even a 0 payout. With nothing to copy it gets a fizzle instead, never a COPY step.
func test_copy_steps() -> void:
	var cases: Array = [
		["bread,repeat", [[1, 3, 0]]],
		["frozen_peas,soup,repeat", [[2, 0, 1]]],
		["repeat,repeat", []],
		["bread,bundle,repeat", []],
	]
	for case: Array in cases:
		var copies: Array = []
		for step: ScoreStep in Scoring.score(_row(case[0])).steps:
			if step.step_type == ScoreStep.StepType.COPY:
				copies.append([step.slot, step.value, step.linked_slot])
		assert_array(copies).override_failure_message(case[0]).is_equal(case[1])


func test_fizzles_never_change_payouts() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,eggs,bread,coffee,multipack"))
	var payout_total: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.PAYOUT:
			payout_total += step.value
	assert_int(payout_total).is_equal(result.total)
	assert_int(result.steps[-1].subtotal).is_equal(result.total)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
