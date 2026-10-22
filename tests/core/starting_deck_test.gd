extends GdUnitTestSuite
## The random starting deck (v0.49, full build plan 5.2): the recipe's 5 core cards plus 8
## products drawn from the run's stock, only products with an item-tier chain, at most 2 copies
## of a product, on the run seed's own derived stream, so the run's RNG and a new profile's
## stock are unchanged.

const RECIPE := "res://data/decks/random_starter.tres"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const SEEDS := 40

var _balance: BalanceDefinition
var _recipe: DeckDefinition
var _stock: RunStock


func before_test() -> void:
	_balance = load(BALANCE)
	_recipe = load(RECIPE)
	_stock = RunStock.starting(_balance)


func test_the_recipe_is_five_fixed_cards_plus_eight_at_most_two_copies() -> void:
	assert_bool(_recipe.is_recipe()).is_true()
	assert_bool((load(STARTER) as DeckDefinition).is_recipe()).is_false()
	assert_array(_ids(_recipe.core_cards)).is_equal(
		["banana", "banana", "milk", "eggs", "final_markdown"]
	)
	assert_array(_recipe.cards).is_empty()
	assert_int(_recipe.random_count).is_equal(8)
	assert_int(_recipe.copy_max).is_equal(2)


func test_a_deal_is_the_core_cards_then_eight_products() -> void:
	for seed_value: int in SEEDS:
		var dealt: DeckDefinition = _deal(seed_value)
		var where: String = "seed %d" % seed_value
		assert_int(dealt.cards.size()).override_failure_message(where).is_equal(13)
		assert_array(dealt.cards.slice(0, 5)).override_failure_message(where).is_equal(
			_recipe.core_cards
		)
		assert_str(String(dealt.id)).is_equal("random_starter")
		assert_bool(dealt.is_recipe()).is_true()
	# The recipe itself is never changed.
	assert_array(_recipe.cards).is_empty()


func test_no_product_passes_two_copies() -> void:
	for seed_value: int in SEEDS:
		var counts: Dictionary[CardDefinition, int] = {}
		for card: CardDefinition in _deal(seed_value).cards:
			counts[card] = int(counts.get(card, 0)) + 1
		for card: CardDefinition in counts:
			(
				assert_int(counts[card])
				. override_failure_message("seed %d: %s" % [seed_value, card.id])
				. is_less_equal(2)
			)


## The drawn cards are stocked products that UPGRADES can step (a chain's plain card), never a
## coupon, a tier or a capsule product with no chain.
func test_only_stocked_products_with_a_chain_are_drawn() -> void:
	var chained: Array[CardDefinition] = []
	for chain: ItemUpgradeDefinition in _balance.machine.item_upgrades:
		chained.append(chain.product)
	var drawable: Array[CardDefinition] = StartingDeck.drawable(
		_stock, _balance.machine.item_upgrades
	)
	assert_int(drawable.size()).is_equal(20)
	var seen: Dictionary[CardDefinition, bool] = {}
	for seed_value: int in SEEDS:
		for card: CardDefinition in _deal(seed_value).cards.slice(5):
			seen[card] = true
			assert_bool(_stock.cards.has(card)).override_failure_message(String(card.id)).is_true()
			assert_bool(chained.has(card)).override_failure_message(String(card.id)).is_true()
			assert_bool(card.is_product()).is_true()
			assert_int(card.tier).is_equal(CardDefinition.Tier.PLAIN)
	# Over 40 deals the draw reaches well past the core's products.
	assert_int(seen.size()).is_greater(10)


## A stock with few chained products ends the deal short at the copy limit.
func test_a_small_pool_ends_the_deal_short() -> void:
	var milk: CardDefinition = load("res://data/cards/milk.tres")
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	var cheese_capsule: CardDefinition = _balance.aisles[0].capsule_cards[0]
	var cards: Array[CardDefinition] = [milk, bread, cheese_capsule]
	var none: Array[CardDefinition] = []
	var small: RunStock = RunStock.from_saved(cards, [], true, none)
	var dealt: DeckDefinition = StartingDeck.deal(_recipe, small, _balance, _stream(3))
	# Milk has 1 core copy, so 1 more; Bread 2; the capsule product has no chain.
	assert_array(_ids(dealt.cards)).is_equal(
		["banana", "banana", "milk", "eggs", "final_markdown", "milk", "bread", "bread"]
	)


func test_the_same_seed_deals_the_same_deck_and_seeds_differ() -> void:
	var decks: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: Array = _ids(_deal(seed_value).cards)
		assert_array(_ids(_deal(seed_value).cards)).is_equal(first)
		decks[",".join(first)] = true
	assert_int(decks.size()).is_greater(20)


## The deal draws on its own derived stream: the run's RNG starts where a fixed deck's run
## starts, so the run's own draws (hands, machine prizes, inspections) are as before.
func test_the_deal_leaves_the_run_rng_unchanged() -> void:
	for seed_value: int in [1, 7, 99]:
		var dealt: RunState = RunState.new(seed_value, _deal(seed_value), _balance, _stock)
		var fixed: RunState = RunState.new(seed_value, load(STARTER), _balance, _stock)
		var fresh: RandomNumberGenerator = RandomNumberGenerator.new()
		fresh.seed = seed_value
		assert_int(dealt.rng_state).is_equal(fresh.state)
		assert_int(dealt.rng_state).is_equal(fixed.rng_state)
	assert_str(EventLogService.STARTING_DECK_STREAM).is_equal("starting_deck")
	assert_str(EventLogService.STARTING_DECK_STREAM).is_not_equal(
		EventLogService.SURPRISE_LIST_STREAM
	)


func test_a_fixed_deck_is_dealt_as_it_is() -> void:
	var starter: DeckDefinition = load(STARTER)
	assert_object(StartingDeck.deal(starter, _stock, _balance, _stream(1))).is_same(starter)


func test_with_cards_copies_the_recipe() -> void:
	var cards: Array[CardDefinition] = [load("res://data/cards/soup.tres")]
	var dealt: DeckDefinition = StartingDeck.with_cards(_recipe, cards)
	assert_str(String(dealt.id)).is_equal(String(_recipe.id))
	assert_array(_ids(dealt.cards)).is_equal(["soup"])
	assert_array(dealt.core_cards).is_equal(_recipe.core_cards)
	assert_int(dealt.copy_max).is_equal(_recipe.copy_max)


## v0.49: the staples are the balance's own list, no longer the starting deck's products, and a
## new profile's stock is unchanged by it: the starter deck's products (the old staples, in deck
## order), every base aisle's products, then the coupon pool.
func test_a_new_profiles_live_stock_is_unchanged_by_the_staples_list() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var starter: DeckDefinition = load("res://data/decks/starter.tres")
	var expected: Array[CardDefinition] = []
	for card: CardDefinition in starter.cards:
		if card.is_product() and not expected.has(card):
			expected.append(card)
	assert_array(RunStock.staples(balance)).is_equal(expected)
	for aisle: AisleDefinition in balance.aisles:
		expected.append_array(aisle.base_cards)
	expected.append_array(balance.coupon_pool)
	assert_array(RunStock.starting(balance).cards).is_equal(expected)


## v0.49: a run dealt from the recipe deck saves its dealt cards and resumes with the same
## starting deck (the recipe's id, its dealt cards), deck and later draws.
func test_a_random_start_round_trips() -> void:
	var recipe: DeckDefinition = _recipe
	var stock: RunStock = RunStock.starting(_balance)
	var deck: DeckDefinition = StartingDeck.deal(
		recipe,
		stock,
		_balance,
		EventLogService.derived_stream(21, EventLogService.STARTING_DECK_STREAM)
	)
	var run: RunState = RunState.new(21, deck, _balance, stock)
	run.start_shift()
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 0)
	assert_array(data["starting_deck"]).is_equal(_ids(deck.cards))
	assert_str(data["starter"]).is_equal("random_starter")
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var save: RunSave = RunSave.from_dictionary(_json(data), lookup)
	assert_object(save).is_not_null()
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	var restored: RunState = save.run
	assert_array(_instance_ids(restored.deck.hand())).is_equal(_instance_ids(run.deck.hand()))
	assert_int(restored.rng_state).is_equal(run.rng_state)
	assert_bool(restored.starter.is_recipe()).is_true()
	assert_array(_ids(restored.starter.cards)).is_equal(_ids(deck.cards))
	assert_int(restored.deck.size()).is_equal(13)
	# A dealt deck's save that lost its dealt cards is refused.
	data.erase("starting_deck")
	assert_object(RunSave.from_dictionary(_json(data), lookup)).is_null()


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


static func _instance_ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


func _deal(seed_value: int) -> DeckDefinition:
	return StartingDeck.deal(_recipe, _stock, _balance, _stream(seed_value))


func _stream(seed_value: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, EventLogService.STARTING_DECK_STREAM)


static func _ids(cards: Array) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))
