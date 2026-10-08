extends GdUnitTestSuite
## Reward offers from the run's stock and taking rewards (plan sections 2 and 5, full build
## plan 7.2).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const BUNDLE := "res://data/cards/bundle.tres"
const CHEESE := "res://data/cards/cheese.tres"
## Bundle returned as 2 for 1, which took its place in both pools (plan v0.23).
const COMBINATION_COUPONS := [&"breakfast_sticker", &"multipack", &"two_for_one"]
## The starter's stock with the 3 base aisles: the staples, the aisles' products and every
## coupon but Bundle, in stock order.
const STARTING_STOCK := [
	"banana",
	"bread",
	"milk",
	"eggs",
	"coffee",
	"soup",
	"cheese",
	"frozen_peas",
	"butter",
	"yogurt",
	"reduced_yogurt",
	"cereal",
	"tea_bags",
	"crackers",
	"dented_can",
	"day_old_buns",
	"carrier_bag",
	"scissors",
	"batteries",
	"flickering_bulb",
	"repeat",
	"final_markdown",
	"breakfast_sticker",
	"multipack",
	"two_for_one",
	"shelf_swap",
]


## The prototype's four (Banana, Bread, Eggs, Milk) and one per base aisle (Butter, Cereal,
## Carrier bag), all decided with the user.
func test_generally_useful_cards_are_the_decided_ones() -> void:
	var useful: Array = []
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres"):
			var card: CardDefinition = load("res://data/cards/" + file)
			if card.generally_useful:
				useful.append(String(card.id))
	useful.sort()
	assert_array(useful).is_equal(
		["banana", "bread", "butter", "carrier_bag", "cereal", "eggs", "milk"]
	)


func test_coupon_pool_and_first_pool_hold_the_agreed_coupons() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var coupons: Array = balance.coupon_pool.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	(
		assert_array(coupons)
		. is_equal(
			[
				"repeat",
				"final_markdown",
				"breakfast_sticker",
				"multipack",
				"two_for_one",
				"shelf_swap",
			]
		)
	)
	assert_int(balance.offer_size).is_equal(3)
	var first: Array = balance.first_offer_pool.map(
		func(card: CardDefinition) -> StringName: return card.id
	)
	assert_array(first).contains_exactly_in_any_order(COMBINATION_COUPONS)


## A new profile stocks the staples and every base aisle (they fit the budget), plus the coupons.
func test_the_starting_stock_is_the_base_aisles_and_the_coupon_pool() -> void:
	(
		assert_array(_stock().map(func(card: CardDefinition) -> String: return String(card.id)))
		. is_equal(STARTING_STOCK)
	)


func test_no_offer_pool_contains_bundle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bundle: CardDefinition = load(BUNDLE)
	assert_bool(balance.coupon_pool.has(bundle)).is_false()
	assert_bool(balance.first_offer_pool.has(bundle)).is_false()
	assert_bool(_stock().has(bundle)).is_false()
	for card: CardDefinition in balance.coupon_pool + balance.first_offer_pool:
		assert_str(String(card.id)).is_not_equal("bundle")


func test_first_offer_always_has_a_combination_coupon() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for seed_value: int in range(1, 300):
		var offer: Array[CardDefinition] = RewardOffer.make(
			_rng(seed_value), balance, _stock(), true
		)
		_assert_well_formed(offer)
		var has_combination: bool = offer.any(
			func(card: CardDefinition) -> bool: return COMBINATION_COUPONS.has(card.id)
		)
		assert_bool(has_combination).override_failure_message("seed %d" % seed_value).is_true()


func test_later_offers_have_a_coupon_and_a_generally_useful_card() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for seed_value: int in range(1, 300):
		var offer: Array[CardDefinition] = RewardOffer.make(
			_rng(seed_value), balance, _stock(), false
		)
		_assert_well_formed(offer)
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
		var offer: Array[CardDefinition] = RewardOffer.make(
			_rng(seed_value), balance, _stock(), false
		)
		for position: int in range(offer.size()):
			seen[offer[position].id] = true
			if offer[position].is_coupon():
				guaranteed_positions[position] = true
	assert_int(seen.size()).is_equal(STARTING_STOCK.size())
	assert_int(guaranteed_positions.size()).is_equal(3)


## Offers draw only from the stock: a card outside it is never offered, and the first offer's
## combination coupon is a stocked one.
func test_offers_draw_only_from_the_stock() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: Array[CardDefinition] = _stock()
	var cheese: CardDefinition = load(CHEESE)
	var sticker: CardDefinition = load("res://data/cards/breakfast_sticker.tres")
	var two_for_one: CardDefinition = load("res://data/cards/two_for_one.tres")
	stock.erase(cheese)
	stock.erase(sticker)
	# Multipack is then the only stocked combination coupon.
	stock.erase(two_for_one)
	for seed_value: int in range(1, 300):
		var where: String = "seed %d" % seed_value
		var first: Array[CardDefinition] = RewardOffer.make(_rng(seed_value), balance, stock, true)
		var later: Array[CardDefinition] = RewardOffer.make(_rng(seed_value), balance, stock, false)
		(
			assert_bool(first.has(load("res://data/cards/multipack.tres")))
			. override_failure_message(where)
			. is_true()
		)
		for card: CardDefinition in first + later:
			assert_bool(stock.has(card)).override_failure_message(where).is_true()


func test_the_run_offers_from_its_own_stock() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var stock: RunStock = RunStock.starting(deck, balance)
	stock.cards.erase(load(CHEESE))
	for seed_value: int in range(1, 40):
		var run: RunState = RunState.new(seed_value, deck, balance, stock)
		run.start_shift()
		_fill_and_pass(run)
		assert_array(run.offer).has_size(3)
		for card: CardDefinition in run.offer:
			assert_str(String(card.id)).is_not_equal("cheese")
			assert_bool(stock.cards.has(card)).is_true()


func test_same_seed_gives_same_offer() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var first: Array[CardDefinition] = RewardOffer.make(_rng(99), balance, _stock(), false)
	var second: Array[CardDefinition] = RewardOffer.make(_rng(99), balance, _stock(), false)
	assert_array(first).is_equal(second)


func test_a_passed_shift_offers_rewards_and_taking_one_grows_the_deck() -> void:
	var run: RunState = _passed_run(5)
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_int(run.offer.size()).is_equal(3)
	assert_bool(run.next_shift()).is_false()
	var card: CardDefinition = run.offer[0]
	assert_bool(run.take_reward(card)).is_true()
	assert_int(run.deck.size()).is_equal(14)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_array(run.offer).is_empty()
	assert_bool(run.take_reward(card)).is_false()


func test_cannot_take_a_card_that_was_not_offered() -> void:
	var run: RunState = _passed_run(6)
	var cheese: CardDefinition = load(CHEESE)
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
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(10, deck, balance, RunStock.starting(deck, balance))
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
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	_fill_and_pass(run)
	return run


## Bread, Multipack, then four Breads: 3 + 0 + 4 * 6 = 27, enough for the first two quotas.
static func _fill_and_pass(run: RunState) -> void:
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()


static func _stock() -> Array[CardDefinition]:
	return RunStock.starting(load(STARTER), load(BALANCE)).cards


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _assert_well_formed(offer: Array[CardDefinition]) -> void:
	assert_int(offer.size()).is_equal(3)
	var unique: Dictionary = {}
	for card: CardDefinition in offer:
		unique[card] = true
		assert_bool(_stock().has(card)).is_true()
	assert_int(unique.size()).is_equal(3)
