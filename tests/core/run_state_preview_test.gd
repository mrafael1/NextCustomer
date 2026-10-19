extends GdUnitTestSuite
## RunState.preview(card, slot), #71's drag preview: a hypothetical placement scores what place()
## then preview() would, never changes the run, and a card that can't be placed gives the plain
## preview. (Its own suite: run_state_test is at gdlint's 20 public methods.)

const RunStateTest := preload("res://tests/core/run_state_test.gd")


func test_a_placed_preview_matches_a_real_place_and_changes_nothing() -> void:
	var run: RunState = RunStateTest._run(6)
	var cards: Array[CardInstance] = run.hand()
	for index: int in range(3):
		run.place(cards[index], index)
	var card: CardInstance = cards[3]
	for slot: int in [-1, 0, 1, 3, 9]:
		var row_before: Array = RunStateTest._ids(run.row)
		var hand_before: Array = RunStateTest._ids(run.hand())
		var placed: ScoreResult = run.preview(card, slot)
		assert_array(RunStateTest._ids(run.row)).is_equal(row_before)
		assert_array(RunStateTest._ids(run.hand())).is_equal(hand_before)
		var real: RunState = RunStateTest._run(6)
		var real_cards: Array[CardInstance] = real.hand()
		for index: int in range(3):
			real.place(real_cards[index], index)
		assert_bool(real.place(real_cards[3], slot)).is_true()
		var expected: ScoreResult = real.preview()
		var at: String = "slot %d" % slot
		assert_int(placed.total).override_failure_message(at).is_equal(expected.total)
		assert_array(Array(placed.payouts)).override_failure_message(at).is_equal(
			Array(expected.payouts)
		)
		assert_array(_lines(placed)).override_failure_message(at).is_equal(_lines(expected))


func test_a_card_that_cannot_be_placed_gives_the_plain_preview() -> void:
	var run: RunState = RunStateTest._run(4)
	var cards: Array[CardInstance] = run.hand()
	run.place(cards[0], 0)
	run.place(cards[1], 1)
	var preview: ScoreResult = run.preview()
	# Already in the row, or no card at all.
	for card: CardInstance in [cards[0], null]:
		var result: ScoreResult = run.preview(card, 1)
		assert_int(result.total).is_equal(preview.total)
		assert_array(_lines(result)).is_equal(_lines(preview))
	# After checkout nothing can be placed.
	run.checkout()
	var scored: ScoreResult = run.preview(cards[2], 0)
	assert_array(_lines(scored)).is_equal(_lines(preview))
	assert_int(run.row.size()).is_equal(2)


## Every step of `result` as a dictionary, to compare two results step by step.
static func _lines(result: ScoreResult) -> Array:
	var lines: Array = []
	for step: ScoreStep in result.steps:
		lines.append(step.to_dictionary())
	return lines
