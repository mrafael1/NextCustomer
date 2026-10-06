extends GdUnitTestSuite
## Reward offers and taking rewards (plan sections 2 and 5).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const BUNDLE := "res://data/cards/bundle.tres"
## Bundle is out of the pools until it returns as "2 for 1" (plan section 5).
const COMBINATION_COUPONS := [&"breakfast_sticker", &"multipack"]


func test_generally_useful_cards_are_the_decided_four() -> void:
	var useful: Array = []
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres"):
			var card: CardDefinition = load("res://data/cards/" + file)
			if card.generally_useful:
				useful.append(String(card.id))
	useful.sort()
	assert_array(useful).is_equal(["banana", "bread", "eggs", "milk"])


func test_reward_pool_is_every_card_but_bundle_and_first_pool_the_combination_coupons() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.reward_pool.size()).is_equal(12)
	assert_int(balance.offer_size).is_equal(3)
	var first: Array = balance.first_offer_pool.map(
		func(card: CardDefinition) -> StringName: return card.id
	)
	assert_array(first).contains_exactly_in_any_order(COMBINATION_COUPONS)


func test_no_offer_pool_contains_bundle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bundle: CardDefinition = load(BUNDLE)
	assert_bool(balance.reward_pool.has(bundle)).is_false()
	assert_bool(balance.first_offer_pool.has(bundle)).is_false()
	for card: CardDefinition in balance.reward_pool + balance.first_offer_pool:
		assert_str(String(card.id)).is_not_equal("bundle")


func test_first_offer_always_has_a_combination_coupon() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for seed_value: int in range(1, 300):
		var offer: Array[CardDefinition] = RewardOffer.make(_rng(seed_value), balance, true)
		_assert_well_formed(offer, balance)
		var has_combination: bool = offer.any(
			func(card: CardDefinition) -> bool: return COMBINATION_COUPONS.has(card.id)
		)
		assert_bool(has_combination).override_failure_message("seed %d" % seed_value).is_true()


func test_later_offers_have_a_coupon_and_a_generally_useful_card() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for seed_value: int in range(1, 300):
		var offer: Array[CardDefinition] = RewardOffer.make(_rng(seed_value), balance, false)
		_assert_well_formed(offer, balance)
		var where: String = "seed %d" % seed_value
		var has_coupon: bool = offer.any(
			func(card: CardDefinition) -> bool: return card.is_coupon()
		)
		var has_useful: bool = offer.any(
			func(card: CardDefinition) -> bool: return card.generally_useful
		)
		assert_bool(has_coupon).override_failure_message(where).is_true()
		assert_bool(has_useful).override_failure_message(where).is_true()


func test_offers_reach_every_card_and_every_position() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var seen: Dictionary = {}
	var guaranteed_positions: Dictionary = {}
	for seed_value: int in range(1, 400):
		var offer: Array[CardDefinition] = RewardOffer.make(_rng(seed_value), balance, false)
		for position: int in range(offer.size()):
			seen[offer[position].id] = true
			if offer[position].is_coupon():
				guaranteed_positions[position] = true
	assert_int(seen.size()).is_equal(12)
	assert_int(guaranteed_positions.size()).is_equal(3)


func test_same_seed_gives_same_offer() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var first: Array[CardDefinition] = RewardOffer.make(_rng(99), balance, false)
	var second: Array[CardDefinition] = RewardOffer.make(_rng(99), balance, false)
	assert_array(first).is_equal(second)


func test_a_passed_shift_offers_rewards_and_taking_one_grows_the_deck() -> void:
	var run: RunState = _passed_run(5)
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_int(run.offer.size()).is_equal(3)
	assert_bool(run.can_advance()).is_false()
	var card: CardDefinition = run.offer[0]
	assert_bool(run.take_reward(card)).is_true()
	assert_int(run.deck.size()).is_equal(14)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_array(run.offer).is_empty()
	assert_bool(run.take_reward(card)).is_false()


func test_cannot_take_a_card_that_was_not_offered() -> void:
	var run: RunState = _passed_run(6)
	var cheese: CardDefinition = load("res://data/cards/cheese.tres")
	if run.offer.has(cheese):
		cheese = load("res://data/cards/soup.tres")
	if run.offer.has(cheese):
		return
	assert_bool(run.take_reward(cheese)).is_false()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)


func test_at_the_deck_limit_a_card_must_be_replaced() -> void:
	var run: RunState = _passed_run(7)
	var bread: CardDefinition = load(BREAD)
	while run.deck.size() < run.balance.deck_limit:
		run.deck.add_card(bread)
	assert_bool(run.deck_is_full()).is_true()
	var card: CardDefinition = run.offer[1]
	assert_bool(run.take_reward(card)).is_false()
	var replaced: CardInstance = run.deck.cards[0]
	assert_bool(run.take_reward(card, replaced)).is_true()
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	assert_bool(run.deck.cards.has(replaced)).is_false()


func test_skip_keeps_the_deck() -> void:
	var run: RunState = _passed_run(8)
	assert_bool(run.skip_reward()).is_true()
	assert_int(run.deck.size()).is_equal(13)
	assert_bool(run.skip_reward()).is_false()


func test_only_the_first_offer_of_a_run_is_the_combination_offer() -> void:
	var run: RunState = _passed_run(9)
	assert_int(run.offers_made).is_equal(1)
	run.skip_reward()
	run.next_shift()
	_fill_and_pass(run)
	assert_int(run.offers_made).is_equal(2)


func test_the_last_shift_wins_without_an_offer() -> void:
	var run: RunState = RunState.new(10, load(STARTER), load(BALANCE))
	run.start_shift()
	run.debug_skip_to_shift(run.shift_count() - 1)
	assert_bool(run.is_last_shift()).is_true()
	# Bread, Multipack, then four Milks at x2: 3 + 0 + 2 * (5 + 7 + 9 + 11) = 67.
	for id: String in ["bread", "multipack", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(67)
	assert_int(result.total).is_greater_equal(run.quota())
	assert_array(run.offer).is_empty()
	assert_int(run.phase).is_equal(RunState.Phase.WON)


static func _passed_run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(seed_value, load(STARTER), load(BALANCE))
	run.start_shift()
	_fill_and_pass(run)
	return run


## Bread, Multipack, then four Breads: 3 + 0 + 4 * 6 = 27, enough for the first two quotas.
static func _fill_and_pass(run: RunState) -> void:
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _assert_well_formed(offer: Array[CardDefinition], balance: BalanceDefinition) -> void:
	assert_int(offer.size()).is_equal(3)
	var unique: Dictionary = {}
	for card: CardDefinition in offer:
		unique[card] = true
		assert_bool(balance.reward_pool.has(card)).is_true()
	assert_int(unique.size()).is_equal(3)
