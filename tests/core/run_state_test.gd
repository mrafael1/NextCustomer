extends GdUnitTestSuite
## RunState: the shift flow from plan sections 2 and 3 (draw 8, redraw up to 2 once, place up
## to 6 cards in a compacted row, checkout always allowed, 5 shifts with rising quotas).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


func test_balance_matches_the_plan() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_array(Array(balance.quotas)).is_equal([10, 15, 22, 32, 48])
	assert_int(balance.hand_size).is_equal(8)
	assert_int(balance.redraw_limit).is_equal(2)
	assert_int(balance.slot_count).is_equal(6)
	assert_int(balance.deck_limit).is_equal(15)


func test_start_shift_draws_a_hand_and_empties_the_row() -> void:
	var run: RunState = _run(1)
	assert_int(run.hand().size()).is_equal(8)
	assert_array(run.row).is_empty()
	assert_int(run.quota()).is_equal(10)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)


func test_same_seed_gives_same_hands() -> void:
	assert_array(_ids(_run(77).hand())).is_equal(_ids(_run(77).hand()))


func test_place_keeps_the_row_compacted() -> void:
	var run: RunState = _run(2)
	var cards: Array[CardInstance] = run.hand()
	assert_bool(run.place(cards[0], 5)).is_true()
	assert_bool(run.place(cards[1], 5)).is_true()
	assert_bool(run.place(cards[2], 0)).is_true()
	assert_array(_ids(run.row)).is_equal(_ids([cards[2], cards[0], cards[1]]))
	assert_int(run.hand().size()).is_equal(5)
	assert_bool(run.remove(cards[0])).is_true()
	assert_array(_ids(run.row)).is_equal(_ids([cards[2], cards[1]]))
	assert_bool(run.hand().has(cards[0])).is_true()


func test_row_holds_at_most_six_cards() -> void:
	var run: RunState = _run(3)
	var cards: Array[CardInstance] = run.hand()
	for index: int in range(6):
		assert_bool(run.place(cards[index], index)).is_true()
	assert_bool(run.can_place(cards[6])).is_false()
	assert_bool(run.place(cards[6], 6)).is_false()
	assert_int(run.row.size()).is_equal(6)


func test_cannot_place_a_card_twice_or_from_outside_the_hand() -> void:
	var run: RunState = _run(4)
	var card: CardInstance = run.hand()[0]
	assert_bool(run.place(card, 0)).is_true()
	assert_bool(run.place(card, 1)).is_false()
	var outside: CardInstance = null
	for deck_card: CardInstance in run.deck.cards:
		if not run.deck.hand().has(deck_card):
			outside = deck_card
	assert_bool(run.place(outside, 0)).is_false()


func test_redraw_up_to_two_hand_cards_once() -> void:
	var run: RunState = _run(5)
	var cards: Array[CardInstance] = run.hand()
	assert_bool(run.can_redraw([cards[0], cards[1], cards[2]])).is_false()
	assert_bool(run.can_redraw([])).is_false()
	assert_bool(run.can_redraw([cards[0], cards[0]])).is_false()
	run.place(cards[3], 0)
	assert_bool(run.can_redraw([cards[3]])).is_false()
	var received: Array[CardInstance] = run.redraw([cards[0], cards[1]])
	assert_int(received.size()).is_equal(2)
	assert_bool(run.hand().has(cards[0])).is_false()
	assert_bool(run.hand().has(received[0])).is_true()
	assert_bool(run.redraw_used).is_true()
	assert_bool(run.can_redraw([cards[2]])).is_false()
	assert_array(run.redraw([cards[2]])).is_empty()
	assert_bool(run.row.has(cards[3])).is_true()


func test_preview_matches_checkout() -> void:
	var run: RunState = _run(6)
	var cards: Array[CardInstance] = run.hand()
	for index: int in range(4):
		run.place(cards[index], index)
	var preview: int = run.preview().total
	assert_int(run.checkout().total).is_equal(preview)


func test_empty_row_checkout_scores_zero_and_loses() -> void:
	var run: RunState = _run(7)
	assert_int(run.checkout().total).is_equal(0)
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_bool(run.passed()).is_false()
	assert_bool(run.next_shift()).is_false()


func test_no_changes_after_checkout() -> void:
	var run: RunState = _run(8)
	var cards: Array[CardInstance] = run.hand()
	run.place(cards[0], 0)
	run.checkout()
	assert_bool(run.place(cards[1], 1)).is_false()
	assert_bool(run.remove(cards[0])).is_false()
	assert_bool(run.can_redraw([cards[1]])).is_false()


func test_passing_a_shift_moves_to_the_next_quota() -> void:
	var run: RunState = _run(9)
	# Bread, Multipack, then four Breads at x2: 3 + 0 + 4 * 6 = 27, above the first quota of 10.
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	assert_int(run.checkout().total).is_equal(27)
	assert_bool(run.passed()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_bool(run.next_shift()).is_false()
	assert_bool(run.skip_reward()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_bool(run.next_shift()).is_true()
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.quota()).is_equal(15)
	assert_array(run.row).is_empty()
	assert_int(run.hand().size()).is_equal(8)
	assert_bool(run.redraw_used).is_false()


func test_win_on_the_last_shift() -> void:
	var balance: BalanceDefinition = load(BALANCE).duplicate()
	balance.quotas = PackedInt32Array([5, 5])
	var run: RunState = RunState.new(11, load(STARTER), balance)
	run.start_shift()
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	run.place(run.debug_add_to_hand(bread), 0)
	run.place(run.debug_add_to_hand(bread), 1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	run.skip_reward()
	assert_bool(run.next_shift()).is_true()
	run.place(run.debug_add_to_hand(bread), 0)
	run.place(run.debug_add_to_hand(bread), 1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_bool(run.next_shift()).is_false()


func test_debug_add_to_hand_does_not_grow_the_deck() -> void:
	var run: RunState = _run(12)
	var size_before: int = run.deck.size()
	var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/cheese.tres"))
	assert_bool(run.hand().has(card)).is_true()
	assert_int(run.deck.size()).is_equal(size_before)


static func _run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(seed_value, load(STARTER), load(BALANCE))
	run.start_shift()
	return run


static func _ids(cards: Array) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids
