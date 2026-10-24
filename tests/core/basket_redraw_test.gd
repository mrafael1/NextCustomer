extends GdUnitTestSuite
## RunState's basket redraw (plan section 3.8): hand places, baskets, what a redraw needs and
## what it swaps.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


## Plan section 3.8: a redraw swaps one basket's hand cards in their places, twice a shift.
func test_redraw_a_basket_twice() -> void:
	var run: RunState = _run(5)
	var cards: Array[CardInstance] = run.hand()
	assert_array(run.basket_places(0)).is_equal([0, 1])
	assert_array(run.basket_places(3)).is_equal([6, 7])
	assert_array(run.basket_places(4)).is_empty()
	assert_array(run.basket_places(-1)).is_empty()
	assert_bool(run.can_redraw_basket(4)).is_false()
	# A row card leaves its place empty; its basket redraws the card left in it.
	run.place(cards[3], 0)
	assert_array(run.basket_places(1)).is_equal([2])
	assert_object(run.hand_places()[3]).is_null()
	assert_array(run.redraw_basket(0)).is_equal([0, 1])
	var places: Array[CardInstance] = run.hand_places()
	assert_bool(run.hand().has(cards[0]) or run.hand().has(cards[1])).is_false()
	assert_bool(cards.has(places[0]) or cards.has(places[1])).is_false()
	assert_object(places[3]).is_null()
	for index: int in [2, 4, 5, 6, 7]:
		assert_object(places[index]).is_same(cards[index])
	assert_int(run.redraws_used).is_equal(1)
	# A one-item basket swaps its one card and still costs 1.
	assert_array(run.redraw_basket(1)).is_equal([2])
	assert_bool(run.hand().has(cards[2])).is_false()
	assert_int(run.redraws_used).is_equal(2)
	assert_bool(run.can_redraw_basket(2)).is_false()
	assert_array(run.redraw_basket(2)).is_empty()
	assert_bool(run.row.has(cards[3])).is_true()
	# Taken back, the row card returns to its own place.
	assert_bool(run.remove(cards[3])).is_true()
	assert_object(run.hand_places()[3]).is_same(cards[3])


## An empty basket can't be redrawn; nor can any basket once the draw pile is empty. A short
## pile swaps the left item and keeps the right one.
func test_redraw_needs_a_hand_card_and_a_card_to_draw() -> void:
	var run: RunState = _run(11)
	var cards: Array[CardInstance] = run.hand()
	run.place(cards[4], 0)
	run.place(cards[5], 1)
	assert_array(run.basket_places(2)).is_empty()
	assert_bool(run.can_redraw_basket(2)).is_false()
	assert_array(run.redraw_basket(2)).is_empty()
	assert_int(run.redraws_used).is_equal(0)
	run.redraws_allowed = 10
	# 13 cards, 8 drawn: 5 in the pile. Two baskets take 4, the third gets the last one.
	run.redraw_basket(0)
	run.redraw_basket(1)
	assert_int(run.deck.draw_pile().size()).is_equal(1)
	assert_array(run.redraw_basket(3)).is_equal([6])
	assert_object(run.hand_places()[7]).is_same(cards[7])
	assert_int(run.redraws_used).is_equal(3)
	assert_bool(run.can_redraw_basket(0)).is_false()


static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run
