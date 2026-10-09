extends GdUnitTestSuite
## The impulse rack before shift 1 (full build plan sections 3 and 7.2): its offer from the
## run's stock and its derived stream, and the pick or skip in RunState.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
## The starter's stocked products with the 3 base aisles, in stock order.
const STOCKED_PRODUCTS := [
	&"banana",
	&"bread",
	&"milk",
	&"eggs",
	&"coffee",
	&"soup",
	&"cheese",
	&"frozen_peas",
	&"butter",
	&"yogurt",
	&"reduced_yogurt",
	&"cereal",
	&"tea_bags",
	&"crackers",
	&"dented_can",
	&"day_old_buns",
	&"carrier_bag",
	&"scissors",
	&"batteries",
	&"flickering_bulb",
]


func test_the_rack_shows_three_products() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.impulse_rack_size).is_equal(3)


func test_the_rack_offers_distinct_stocked_products() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: RunStock = _stock()
	for seed_value: int in range(1, 300):
		var where: String = "seed %d" % seed_value
		var offer: Array[CardDefinition] = RewardOffer.make_impulse(
			_stream(seed_value), balance, stock
		)
		assert_int(offer.size()).override_failure_message(where).is_equal(3)
		for card: CardDefinition in offer:
			assert_bool(card.is_product()).override_failure_message(where).is_true()
			assert_bool(stock.cards.has(card)).override_failure_message(where).is_true()
			assert_int(offer.count(card)).override_failure_message(where).is_equal(1)


func test_the_rack_reaches_every_stocked_product_in_every_position() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var seen: Dictionary = {}
	var positions: Dictionary = {}
	for seed_value: int in range(1, 400):
		var offer: Array[CardDefinition] = RewardOffer.make_impulse(
			_stream(seed_value), balance, _stock()
		)
		for position: int in range(offer.size()):
			seen[offer[position].id] = true
			positions["%s@%d" % [offer[position].id, position]] = true
	assert_array(seen.keys()).contains_exactly_in_any_order(STOCKED_PRODUCTS)
	assert_int(positions.size()).is_equal(STOCKED_PRODUCTS.size() * 3)


## Full build plan 7.2: the newest new arrival always takes a rack slot; the others are drawn
## like any stocked product.
func test_the_newest_new_arrival_takes_a_slot() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: RunStock = _stock()
	var newest: CardDefinition = _product(&"newest")
	var older: CardDefinition = _product(&"older")
	stock.cards.append_array([newest, older])
	stock.new_arrivals = [newest, older]
	var older_seen: bool = false
	var newest_positions: Dictionary = {}
	for seed_value: int in range(1, 200):
		var offer: Array[CardDefinition] = RewardOffer.make_impulse(
			_stream(seed_value), balance, stock
		)
		assert_int(offer.size()).is_equal(3)
		assert_bool(offer.has(newest)).override_failure_message("seed %d" % seed_value).is_true()
		assert_int(offer.count(newest)).is_equal(1)
		newest_positions[offer.find(newest)] = true
		older_seen = older_seen or offer.has(older)
	assert_bool(older_seen).is_true()
	assert_int(newest_positions.size()).is_equal(3)


func test_a_small_stock_gives_a_shorter_rack_and_size_zero_none() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: RunStock = RunStock.new()
	stock.cards = [load(BREAD), load(REPEAT)]
	var offer: Array[CardDefinition] = RewardOffer.make_impulse(_stream(1), balance, stock)
	assert_array(offer).is_equal([load(BREAD)])
	var no_rack: BalanceDefinition = balance.duplicate()
	no_rack.impulse_rack_size = 0
	assert_array(RewardOffer.make_impulse(_stream(1), no_rack, _stock())).is_empty()
	var run: RunState = RunState.new(1, load(STARTER), no_rack, _stock(), _stream(1))
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(run.impulse_offer).is_empty()


## Full build plan section 4: the stream is seeded from the run seed and its name, so the same
## seed always gives the same rack, and the rack is not the run's RNG.
func test_the_derived_stream_depends_on_the_seed_and_the_name() -> void:
	var first: RandomNumberGenerator = _stream(42)
	var second: RandomNumberGenerator = _stream(42)
	var other_name: RandomNumberGenerator = EventLogService.derived_stream(42, "surprise_me")
	var other_seed: RandomNumberGenerator = _stream(43)
	var run_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	run_rng.seed = 42
	var values: Array = [[], [], [], [], []]
	for _draw: int in range(6):
		values[0].append(first.randi())
		values[1].append(second.randi())
		values[2].append(other_name.randi())
		values[3].append(other_seed.randi())
		values[4].append(run_rng.randi())
	assert_array(values[0]).is_equal(values[1])
	for index: int in range(2, 5):
		assert_array(values[0]).is_not_equal(values[index])
	assert_int(_stream(42).seed).is_equal(hash([42, EventLogService.IMPULSE_RACK_STREAM]))


func test_the_same_seed_gives_the_same_rack() -> void:
	var first: RunState = _run(17)
	var second: RunState = _run(17)
	assert_array(first.impulse_offer).is_equal(second.impulse_offer)
	assert_array(first.offer).is_equal(first.impulse_offer)


## The rack uses its own stream: skipping it leaves shift 1's hand as in a run without a rack.
func test_the_rack_leaves_the_run_rng_untouched() -> void:
	for seed_value: int in range(1, 20):
		var with_rack: RunState = _run(seed_value)
		assert_bool(with_rack.skip_reward()).is_true()
		with_rack.start_shift()
		var without: RunState = _run_without_rack(seed_value)
		without.start_shift()
		assert_array(_hand_ids(with_rack)).is_equal(_hand_ids(without))


func test_a_run_opens_on_the_rack_and_waits_for_it() -> void:
	var run: RunState = _run(3)
	assert_int(run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_int(run.impulse_offer.size()).is_equal(3)
	run.start_shift()
	assert_array(run.hand()).is_empty()
	run.debug_skip_to_shift(2)
	assert_int(run.shift_index).is_equal(0)
	assert_object(run.checkout()).is_null()
	assert_int(run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_bool(run.next_shift()).is_false()
	assert_bool(run.pick_upgrade(load("res://data/upgrades/extra_redraw.tres"))).is_false()
	assert_bool(run.place(run.debug_add_to_hand(load(BREAD)), 0)).is_false()


## The pick joins the deck before shift 1's draw, so shift 1 can draw it. It is no reward: no
## history entry, and the run's first reward offer is still the combination offer.
func test_a_pick_joins_the_deck_before_the_first_draw() -> void:
	var run: RunState = _run(4)
	var card: CardDefinition = run.impulse_offer[1]
	var offered: Array[CardDefinition] = run.impulse_offer.duplicate()
	assert_bool(run.take_reward(card)).is_true()
	assert_int(run.deck.size()).is_equal(14)
	assert_object(run.deck.cards[-1].definition).is_same(card)
	assert_object(run.impulse_pick).is_same(card)
	assert_object(run.impulse_replaced).is_null()
	assert_array(run.impulse_offer).is_equal(offered)
	assert_array(run.offer).is_empty()
	assert_array(run.history).is_empty()
	assert_int(run.offers_made).is_equal(0)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(run.take_reward(card)).is_false()
	assert_bool(run.skip_reward()).is_false()
	run.start_shift()
	assert_int(run.hand().size()).is_equal(8)


func test_a_skip_keeps_the_starting_deck() -> void:
	var run: RunState = _run(5)
	assert_bool(run.skip_reward()).is_true()
	assert_int(run.deck.size()).is_equal(13)
	assert_object(run.impulse_pick).is_null()
	assert_int(run.impulse_offer.size()).is_equal(3)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(run.skip_reward()).is_false()
	assert_array(run.history).is_empty()


func test_only_an_offered_product_can_be_taken() -> void:
	var run: RunState = _run(6)
	var outside: CardDefinition = load(REPEAT)
	assert_bool(run.take_reward(outside)).is_false()
	assert_int(run.phase).is_equal(RunState.Phase.IMPULSE)


## Decided with the user (phase 1): at the deck limit a rack pick removes a deck card, as a
## reward pick does.
func test_at_the_deck_limit_a_pick_replaces_a_deck_card() -> void:
	var run: RunState = _run(7)
	while run.deck.size() < run.balance.deck_limit:
		run.deck.add_card(load(BREAD))
	var card: CardDefinition = run.impulse_offer[0]
	assert_bool(run.take_reward(card)).is_false()
	var replaced: CardInstance = run.deck.cards[0]
	assert_bool(run.take_reward(card, replaced)).is_true()
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	assert_bool(run.deck.cards.has(replaced)).is_false()
	assert_object(run.impulse_replaced).is_same(replaced.definition)


## A deck card passed below the deck limit stays in the deck and isn't recorded as replaced.
func test_below_the_deck_limit_nothing_is_replaced() -> void:
	var run: RunState = _run(9)
	var kept: CardInstance = run.deck.cards[0]
	assert_bool(run.take_reward(run.impulse_offer[0], kept)).is_true()
	assert_bool(run.deck.cards.has(kept)).is_true()
	assert_int(run.deck.size()).is_equal(14)
	assert_object(run.impulse_replaced).is_null()


func test_the_first_reward_after_a_pick_is_still_the_combination_offer() -> void:
	var run: RunState = _run(8)
	run.take_reward(run.impulse_offer[0])
	run.start_shift()
	for id: String in ["eggs", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_int(run.offers_made).is_equal(1)
	var combination: bool = run.offer.any(
		func(card: CardDefinition) -> bool: return run.balance.first_offer_pool.has(card)
	)
	assert_bool(combination).is_true()
	assert_bool(run.take_reward(run.offer[0])).is_true()
	assert_object(run.history[0].card_picked).is_same(run.deck.cards[-1].definition)


static func _stream(seed_value: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, EventLogService.IMPULSE_RACK_STREAM)


static func _stock() -> RunStock:
	return RunStock.starting(load(STARTER), load(BALANCE))


static func _run(seed_value: int) -> RunState:
	return RunState.new(seed_value, load(STARTER), load(BALANCE), _stock(), _stream(seed_value))


static func _run_without_rack(seed_value: int) -> RunState:
	return RunState.new(seed_value, load(STARTER), load(BALANCE), _stock())


static func _product(id: StringName) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = id
	card.kind = CardDefinition.Kind.PRODUCT
	return card


static func _hand_ids(run: RunState) -> Array:
	var ids: Array = []
	for card: CardInstance in run.hand():
		ids.append("%s#%d" % [card.definition.id, card.instance_id])
	return ids
