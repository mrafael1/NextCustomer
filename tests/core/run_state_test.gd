extends GdUnitTestSuite
## RunState: the shift flow from plan sections 2 and 3 (draw 8, place up to 7 cards of any kind
## in a compacted row, checkout always allowed, one shift per quota with rising quotas).
## The basket redraw's tests are in basket_redraw_test.gd.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"


func test_balance_matches_the_plan() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	# 12 shifts in 3 weeks of 4 since v0.65 (8 fitted with the balance simulator before, plan
	# v0.28, issue #41; shift 1 lowered to 29 in v0.54): placeholders until the refit.
	assert_array(Array(balance.quotas)).is_equal(
		[29, 35, 53, 61, 73, 85, 98, 111, 125, 140, 155, 175]
	)
	assert_array(Array(balance.inspection_shifts)).is_equal([3, 7, 11])
	assert_array(Array(balance.review_shifts)).is_equal([4, 8, 12])
	assert_int(balance.review_inspection_count).is_equal(2)
	assert_int(balance.write_up_limit).is_equal(2)
	assert_int(balance.write_up_last_shift).is_equal(4)
	assert_int(balance.hand_size).is_equal(8)
	assert_int(balance.basket_size).is_equal(2)
	assert_int(balance.slot_count).is_equal(7)
	assert_int(balance.deck_limit).is_equal(15)


func test_start_shift_draws_a_hand_and_empties_the_row() -> void:
	var run: RunState = _run(1)
	assert_int(run.hand().size()).is_equal(8)
	assert_array(run.row).is_empty()
	assert_int(run.quota()).is_equal(29)
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


## Plan section 3.1 (v0.46, #106): 7 general slots, any card in any slot. Seven products fill
## the row, and so do seven coupons.
func test_seven_cards_of_any_kind_fill_the_row() -> void:
	var run: RunState = _run(3)
	for index: int in range(7):
		assert_bool(run.place(_add(run, BREAD), index)).is_true()
	assert_int(run.row.size()).is_equal(RowCapacity.card_limit(run.limits))
	assert_bool(run.can_place(_add(run, BREAD))).is_false()
	var coupon: CardInstance = _add(run, REPEAT)
	assert_bool(run.can_place(coupon)).is_false()
	assert_bool(run.place(coupon, 2)).is_false()
	assert_int(run.row.size()).is_equal(7)
	var coupons: RunState = _run(13)
	for index: int in range(7):
		assert_bool(coupons.place(_add(coupons, REPEAT), index)).is_true()
	assert_bool(coupons.can_place(_add(coupons, BREAD))).is_false()


## A product takes the slot a coupon left, and a coupon the slot a product left.
func test_remove_frees_capacity_again() -> void:
	var run: RunState = _run(16)
	for index: int in range(6):
		run.place(_add(run, BREAD), index)
	run.place(_add(run, REPEAT), 3)
	var product: CardInstance = _add(run, BREAD)
	assert_bool(run.can_place(product)).is_false()
	assert_bool(run.remove(run.row[3])).is_true()
	assert_bool(run.can_place(product)).is_true()
	assert_bool(run.place(product, 0)).is_true()
	assert_bool(run.remove(run.row[6])).is_true()
	assert_bool(run.can_place(_add(run, REPEAT))).is_true()
	assert_bool(run.can_place(_add(run, BREAD))).is_true()


## Scoring has no row limit of its own: a 7-card row scores like any other (plan section 3.1).
func test_a_seven_card_row_scores_as_usual() -> void:
	var bread_six: Array = ["bread", "bread", "bread", "bread", "bread", "bread"]
	# Six Breads, then Final markdown in the last slot: 6 * 5 + 4 = 34.
	assert_int(_checkout_ids(19, bread_six + ["final_markdown"])).is_equal(34)
	# Final markdown in slot 6 of 7 isn't the last slot: 5 * 5 + 0 + 5 = 30.
	assert_int(_checkout_ids(20, bread_six.slice(1) + ["final_markdown", "bread"])).is_equal(30)
	# Repeat as the 7th card copies the Bread before it: 6 * 5 + 5 = 35.
	assert_int(_checkout_ids(21, bread_six + ["repeat"])).is_equal(35)


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


func test_preview_matches_checkout() -> void:
	var run: RunState = _run(6)
	var cards: Array[CardInstance] = run.hand()
	for index: int in range(4):
		run.place(cards[index], index)
	var preview: int = run.preview().total
	assert_int(run.checkout().total).is_equal(preview)


## An empty row scores 0 and misses the quota: in the training week (v0.68) a miss is a slip (no
## machine visit, the next shift starts), 2 are forgiven and the 3rd ends the run.
func test_empty_row_checkout_scores_zero_and_slips_twice_then_fired() -> void:
	var run: RunState = _run(7)
	# The training week (v0.68) forgives 2 slips: the 3rd miss ends the run.
	for slip: int in range(1, 3):
		assert_int(run.checkout().total).is_equal(0)
		assert_bool(run.passed()).is_false()
		assert_int(run.phase).is_equal(RunState.Phase.SCORED)
		assert_int(run.write_ups).is_equal(slip)
		assert_array(run.history[-1].visits).is_empty()
		assert_bool(run.next_shift()).is_true()
	assert_int(run.shift_index).is_equal(2)
	assert_int(run.checkout().total).is_equal(0)
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_int(run.write_ups).is_equal(3)
	assert_bool(run.next_shift()).is_false()


func test_no_changes_after_checkout() -> void:
	var run: RunState = _run(8)
	var cards: Array[CardInstance] = run.hand()
	run.place(cards[0], 0)
	run.checkout()
	assert_bool(run.place(cards[1], 1)).is_false()
	assert_bool(run.remove(cards[0])).is_false()
	assert_bool(run.can_redraw_basket(0)).is_false()


func test_passing_a_shift_moves_to_the_next_quota() -> void:
	var run: RunState = _run(9)
	# Milk, Multipack, then five Milks: 109, above the first quota of 34.
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	assert_int(run.checkout().total).is_equal(109)
	assert_bool(run.passed()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(run.next_shift()).is_false()
	assert_bool(MachineSteps.pass_visits(run)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_bool(run.next_shift()).is_true()
	assert_int(run.shift_index).is_equal(1)
	# Shift 2 is a boon day (v0.69): its quota is 35 changed by its boon's percent, its hand 8
	# with its boon's change.
	assert_int(run.inspections.size()).is_equal(1)
	var boon: InspectionDefinition = run.inspections[0]
	assert_bool(boon.is_boon()).is_true()
	assert_int(run.quota()).is_equal(ShiftLimits.with_percent(35, boon.quota_percent))
	assert_array(run.row).is_empty()
	assert_int(run.hand().size()).is_equal(8 + boon.hand_size_delta)
	assert_int(run.redraws_used).is_equal(0)


func test_win_on_the_last_shift() -> void:
	var balance: BalanceDefinition = load(BALANCE).duplicate()
	balance.quotas = PackedInt32Array([5, 5])
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(11, deck, balance, RunStock.starting(balance))
	run.start_shift()
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	run.place(run.debug_add_to_hand(bread), 0)
	run.place(run.debug_add_to_hand(bread), 1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	MachineSteps.pass_visits(run)
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
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
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
