extends GdUnitTestSuite
## RunState: the shift flow from plan sections 2 and 3 (draw 8, redraw up to 2 once, place up
## to 6 products and 7 cards in a compacted row, checkout always allowed, one shift per quota
## with rising quotas).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"


func test_balance_matches_the_plan() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	# 8 shifts, placeholder quotas until the balance simulator (plan v0.12).
	assert_array(Array(balance.quotas)).is_equal([10, 13, 17, 22, 27, 33, 40, 48])
	assert_int(balance.hand_size).is_equal(8)
	assert_int(balance.redraw_limit).is_equal(2)
	assert_int(balance.slot_count).is_equal(6)
	assert_int(balance.coupon_slot_count).is_equal(1)
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


## Plan section 3.1: 6 shared slots + 1 coupon-only slot.
func test_six_products_then_only_a_coupon_fits() -> void:
	var run: RunState = _run(3)
	for index: int in range(6):
		assert_bool(run.place(_add(run, BREAD), index)).is_true()
	var product: CardInstance = _add(run, BREAD)
	assert_bool(RowCapacity.products_full(run.balance, run.row)).is_true()
	assert_bool(run.can_place(product)).is_false()
	assert_bool(run.place(product, 6)).is_false()
	var coupon: CardInstance = _add(run, REPEAT)
	assert_bool(run.can_place(coupon)).is_true()
	# The coupon slot is a capacity, not a position: the coupon can go anywhere in the row.
	assert_bool(run.place(coupon, 3)).is_true()
	assert_object(run.row[3]).is_same(coupon)
	assert_int(run.row.size()).is_equal(7)
	assert_int(RowCapacity.product_count(run.row)).is_equal(6)


func test_seven_cards_fill_the_row() -> void:
	var run: RunState = _run(3)
	for index: int in range(6):
		run.place(_add(run, BREAD), index)
	run.place(_add(run, REPEAT), 0)
	assert_int(run.row.size()).is_equal(RowCapacity.card_limit(run.balance))
	assert_bool(run.can_place(_add(run, BREAD))).is_false()
	var coupon: CardInstance = _add(run, REPEAT)
	assert_bool(run.can_place(coupon)).is_false()
	assert_bool(run.place(coupon, 2)).is_false()
	assert_int(run.row.size()).is_equal(7)


func test_two_coupons_and_five_products_fit() -> void:
	var run: RunState = _run(13)
	assert_bool(run.place(_add(run, REPEAT), 0)).is_true()
	for index: int in range(5):
		assert_bool(run.place(_add(run, BREAD), run.row.size())).is_true()
	assert_bool(run.place(_add(run, REPEAT), 3)).is_true()
	assert_int(run.row.size()).is_equal(7)
	assert_int(RowCapacity.product_count(run.row)).is_equal(5)
	assert_int(RowCapacity.coupon_slots_used(run.balance, run.row)).is_equal(1)


func test_a_coupon_in_the_row_does_not_let_a_seventh_product_in() -> void:
	var run: RunState = _run(14)
	run.place(_add(run, REPEAT), 0)
	for index: int in range(6):
		assert_bool(run.place(_add(run, BREAD), run.row.size())).is_true()
	assert_bool(run.can_place(_add(run, BREAD))).is_false()
	# Without the coupon: six products and one free slot, and that slot is the coupon slot.
	run.remove(run.row[0])
	assert_int(run.row.size()).is_equal(6)
	assert_int(RowCapacity.coupon_slots_used(run.balance, run.row)).is_equal(0)
	assert_bool(run.can_place(_add(run, BREAD))).is_false()
	assert_bool(run.can_place(_add(run, REPEAT))).is_true()


func test_remove_frees_capacity_again() -> void:
	var run: RunState = _run(16)
	for index: int in range(6):
		run.place(_add(run, BREAD), index)
	run.place(_add(run, REPEAT), 6)
	var product: CardInstance = _add(run, BREAD)
	assert_bool(run.can_place(product)).is_false()
	assert_bool(run.remove(run.row[0])).is_true()
	assert_bool(run.can_place(product)).is_true()
	assert_bool(run.place(product, 0)).is_true()
	assert_bool(run.remove(run.row[6])).is_true()
	assert_bool(run.can_place(_add(run, REPEAT))).is_true()
	assert_bool(run.can_place(_add(run, BREAD))).is_false()


## The first coupon takes the coupon slot wherever it sits; a second one uses a product slot.
func test_the_first_coupon_takes_the_coupon_slot() -> void:
	var run: RunState = _run(17)
	run.place(_add(run, BREAD), 0)
	assert_int(RowCapacity.coupon_slots_used(run.balance, run.row)).is_equal(0)
	run.place(_add(run, REPEAT), 0)
	assert_int(RowCapacity.coupon_slots_used(run.balance, run.row)).is_equal(1)
	run.place(_add(run, REPEAT), 1)
	assert_int(RowCapacity.coupon_slots_used(run.balance, run.row)).is_equal(1)


## The neutral script default: without coupon slots the row holds slot_count cards of any kind.
func test_without_coupon_slots_the_row_holds_slot_count_cards() -> void:
	var balance: BalanceDefinition = load(BALANCE).duplicate()
	balance.coupon_slot_count = 0
	var run: RunState = RunState.new(18, load(STARTER), balance)
	run.start_shift()
	for index: int in range(6):
		run.place(_add(run, REPEAT if index == 2 else BREAD), index)
	assert_int(RowCapacity.card_limit(run.balance)).is_equal(6)
	assert_bool(run.can_place(_add(run, REPEAT))).is_false()
	assert_bool(run.can_place(_add(run, BREAD))).is_false()


## Scoring has no row limit of its own: a 7-card row scores like any other (plan section 3.1).
func test_a_seven_card_row_scores_as_usual() -> void:
	var bread_six: Array = ["bread", "bread", "bread", "bread", "bread", "bread"]
	# Six Breads, then Final markdown in the last slot: 6 * 3 + 6 = 24.
	assert_int(_checkout_ids(19, bread_six + ["final_markdown"])).is_equal(24)
	# Final markdown in slot 6 of 7 isn't the last slot: 5 * 3 + 0 + 3 = 18.
	assert_int(_checkout_ids(20, bread_six.slice(1) + ["final_markdown", "bread"])).is_equal(18)
	# Repeat as the 7th card copies the Bread before it: 6 * 3 + 3 = 21.
	assert_int(_checkout_ids(21, bread_six + ["repeat"])).is_equal(21)


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
	assert_int(run.quota()).is_equal(13)
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


## Places the cards in this order in a fresh run's row and returns the checkout total.
func _checkout_ids(seed_value: int, ids: Array) -> int:
	var run: RunState = _run(seed_value)
	for id: String in ids:
		assert_bool(run.place(_add(run, "res://data/cards/%s.tres" % id), run.row.size())).is_true()
	assert_int(run.row.size()).is_equal(ids.size())
	return run.checkout().total


static func _add(run: RunState, path: String) -> CardInstance:
	return run.debug_add_to_hand(load(path))


static func _ids(cards: Array) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids
