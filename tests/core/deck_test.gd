extends GdUnitTestSuite
## Deck behaviour from plan sections 2, 3 and 3.7: separate instances for duplicates, seeded
## draws, a full reshuffle every shift, and a redraw that can't bring back a replaced card.

const STARTER := "res://data/decks/starter.tres"


func test_duplicates_are_separate_instances() -> void:
	var deck: Deck = _deck(1)
	var ids: Dictionary = {}
	var bananas: Array[CardInstance] = []
	for card: CardInstance in deck.cards:
		ids[card.instance_id] = true
		if card.definition.id == &"banana":
			bananas.append(card)
	assert_int(ids.size()).is_equal(deck.size())
	assert_int(bananas.size()).is_equal(3)
	assert_bool(bananas[0] == bananas[1]).is_false()
	assert_object(bananas[0].definition).is_same(bananas[1].definition)


func test_same_seed_gives_same_draws() -> void:
	var first: Deck = _deck(12345)
	var second: Deck = _deck(12345)
	assert_array(_ids(first.draw_hand(8))).is_equal(_ids(second.draw_hand(8)))
	var first_redraw: Array[CardInstance] = first.redraw(first.hand().slice(0, 2))
	var second_redraw: Array[CardInstance] = second.redraw(second.hand().slice(0, 2))
	assert_array(_ids(first_redraw)).is_equal(_ids(second_redraw))
	assert_array(_ids(first.draw_hand(8))).is_equal(_ids(second.draw_hand(8)))


func test_different_seeds_give_different_draws() -> void:
	var orders: Dictionary = {}
	for seed_value: int in range(1, 6):
		orders[str(_ids(_deck(seed_value).draw_hand(13)))] = true
	assert_int(orders.size()).is_greater(1)


func test_every_shift_draws_from_the_whole_deck() -> void:
	var deck: Deck = _deck(7)
	for shift: int in range(3):
		var hand: Array[CardInstance] = deck.draw_hand(deck.size())
		assert_int(hand.size()).is_equal(deck.size())
		for card: CardInstance in deck.cards:
			assert_bool(hand.has(card)).override_failure_message("shift %d" % shift).is_true()


## Plan 3.5: every shift draws from the whole deck, not from what the last shift left.
## Drawing only from the leftover pile would always put its 5 cards in the next hand and
## never repeat a card from the last hand.
func test_each_shift_reshuffles_the_whole_deck() -> void:
	var repeated_a_card: bool = false
	var skipped_a_leftover: bool = false
	for seed_value: int in range(1, 40):
		var deck: Deck = _deck(seed_value)
		var first: Array[CardInstance] = deck.draw_hand(8)
		var leftovers: Array[CardInstance] = []
		for card: CardInstance in deck.cards:
			if not first.has(card):
				leftovers.append(card)
		var second: Array[CardInstance] = deck.draw_hand(8)
		for card: CardInstance in first:
			repeated_a_card = repeated_a_card or second.has(card)
		for card: CardInstance in leftovers:
			skipped_a_leftover = skipped_a_leftover or not second.has(card)
	assert_bool(repeated_a_card).is_true()
	assert_bool(skipped_a_leftover).is_true()


func test_next_shift_draws_a_full_hand_again() -> void:
	var deck: Deck = _deck(4)
	deck.draw_hand(8)
	deck.redraw(deck.hand().slice(0, 2))
	assert_int(deck.draw_hand(8).size()).is_equal(8)


## With every card in the hand replaced, only the 5 cards left in the pile can come in; the
## other 3 places keep their cards. No replaced card comes back and no place is left empty.
func test_redraw_with_a_short_pile() -> void:
	for seed_value: int in range(1, 20):
		var deck: Deck = _deck(seed_value)
		var hand: Array[CardInstance] = deck.draw_hand(8)
		var new_hand: Array[CardInstance] = deck.redraw(hand)
		assert_int(new_hand.size()).is_equal(8)
		var changed: int = 0
		var unique: Dictionary = {}
		for index: int in range(8):
			assert_object(new_hand[index]).is_not_null()
			unique[new_hand[index].instance_id] = true
			if new_hand[index] != hand[index]:
				changed += 1
				assert_bool(hand.has(new_hand[index])).is_false()
		assert_int(changed).is_equal(5)
		assert_int(unique.size()).is_equal(8)


## Every card can land in every position: catches a biased shuffle.
func test_shuffle_reaches_every_position() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(1, 1001):
		var deck: Deck = _deck(seed_value)
		var hand: Array[CardInstance] = deck.draw_hand(deck.size())
		for position: int in range(hand.size()):
			seen[Vector2i(deck.cards.find(hand[position]), position)] = true
	assert_int(seen.size()).is_equal(13 * 13)


func test_draw_hand_draws_distinct_cards() -> void:
	var hand: Array[CardInstance] = _deck(3).draw_hand(8)
	assert_int(hand.size()).is_equal(8)
	var unique: Dictionary = {}
	for card: CardInstance in hand:
		unique[card.instance_id] = true
	assert_int(unique.size()).is_equal(8)


func test_redraw_cannot_bring_back_a_replaced_card() -> void:
	for seed_value: int in range(1, 30):
		var deck: Deck = _deck(seed_value)
		var hand: Array[CardInstance] = deck.draw_hand(8)
		var replaced: Array[CardInstance] = [hand[2], hand[5]]
		var new_hand: Array[CardInstance] = deck.redraw(replaced)
		assert_int(new_hand.size()).is_equal(8)
		for card: CardInstance in replaced:
			assert_bool(new_hand.has(card)).is_false()
		# Kept cards stay in place; each new card takes the place of the card it replaced.
		for index: int in [0, 1, 3, 4, 6, 7]:
			assert_object(new_hand[index]).is_same(hand[index])
		for index: int in [2, 5]:
			assert_bool(hand.has(new_hand[index])).is_false()


func test_redraw_ignores_cards_not_in_hand() -> void:
	var deck: Deck = _deck(9)
	var hand: Array[CardInstance] = deck.draw_hand(8)
	var outside: Array[CardInstance] = []
	for card: CardInstance in deck.cards:
		if not hand.has(card):
			outside.append(card)
	var new_hand: Array[CardInstance] = deck.redraw([outside[0]])
	assert_array(_ids(new_hand)).is_equal(_ids(hand))


func test_add_and_remove_cards() -> void:
	var deck: Deck = _deck(1)
	var cheese: CardDefinition = load("res://data/cards/cheese.tres")
	var added: CardInstance = deck.add_card(cheese)
	assert_int(deck.size()).is_equal(14)
	for card: CardInstance in deck.cards:
		if card != added:
			assert_int(card.instance_id).is_not_equal(added.instance_id)
	deck.remove_card(added)
	assert_int(deck.size()).is_equal(13)


static func _deck(seed_value: int) -> Deck:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return Deck.from_definition(load(STARTER), rng)


static func _ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids
