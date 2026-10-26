extends GdUnitTestSuite
## The balance simulator's --random-start (v0.49): SimPlayer deals a recipe deck for each run
## from its stock and seed, as the game deals it (StartingDeck), on the live data. A quota no row
## reaches ends each run at shift 1, before any machine visit, so its final deck is the deal.

const RECIPE := "res://data/decks/random_starter.tres"
const BALANCE := "res://data/balance/balance.tres"


func test_a_recipe_deck_is_dealt_for_each_run() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([100000])
	var recipe: DeckDefinition = load(RECIPE)
	var player: SimPlayer = SimPlayer.new(recipe, balance, SimRowSearch.new(balance), "skip", 1)
	var stock: RunStock = RunStock.starting(balance)
	var deals: Dictionary[String, bool] = {}
	for seed_value: int in [4, 8, 15]:
		var stream: RandomNumberGenerator = EventLogService.derived_stream(
			seed_value, EventLogService.STARTING_DECK_STREAM
		)
		var expected: Array = _ids(StartingDeck.deal(recipe, stock, balance, stream).cards)
		assert_int(expected.size()).is_equal(13)
		var final_deck: Array = Array(player.play(seed_value).final_deck)
		final_deck.sort()
		expected.sort()
		assert_array(final_deck).is_equal(expected)
		deals[",".join(expected)] = true
	assert_int(deals.size()).is_greater(1)


## The game's recipe since v0.63 (#107) has starter packs: each run deals its offer (no first
## pick) and the strategy takes a pack, kept in the run's record. "skip" takes the first offered,
## greedy the best one for shift 1 (one of the three). A quota no row reaches ends each run at
## shift 1, so its final deck is the staples, the pack and the shared products.
func test_a_pack_recipe_deals_an_offer_and_picks_a_pack() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([100000])
	var recipe: DeckDefinition = load(BalanceSim.RANDOM_START_DECK)
	assert_bool(recipe.starter_packs.is_empty()).is_false()
	var stock: RunStock = RunStock.starting(balance)
	for strategy: String in ["skip", "greedy"]:
		var search: SimRowSearch = SimRowSearch.new(balance)
		var player: SimPlayer = SimPlayer.new(recipe, balance, search, strategy, 1)
		for seed_value: int in [4, 8]:
			var stream: RandomNumberGenerator = EventLogService.derived_stream(
				seed_value, EventLogService.STARTING_DECK_STREAM
			)
			var offer: StartOffer = StartingDeck.deal_offer(recipe, stock, balance, stream, false)
			var record: SimRunRecord = player.play(seed_value)
			var pack: StarterPackDefinition = offer.pack(StringName(record.start_pack))
			assert_object(pack).override_failure_message(strategy).is_not_null()
			if strategy == "skip":
				assert_object(pack).is_same(offer.packs[0])
			var expected: Array = _ids(StartingDeck.with_pack(recipe, pack, offer.shared).cards)
			var final_deck: Array = Array(record.final_deck)
			final_deck.sort()
			expected.sort()
			assert_array(final_deck).override_failure_message(strategy).is_equal(expected)
			var restored: SimRunRecord = SimRunRecord.from_dictionary(
				JSON.parse_string(JSON.stringify(record.to_dictionary()))
			)
			assert_str(restored.start_pack).is_equal(record.start_pack)


## The option names a deck and a flag the simulator knows.
func test_the_random_start_option_is_known() -> void:
	assert_bool(BalanceSim.SIMULATION_DEFAULTS.has("random-start")).is_true()
	assert_bool(BalanceSim.FLAG_OPTIONS.has("random-start")).is_true()
	assert_bool((load(BalanceSim.RANDOM_START_DECK) as DeckDefinition).is_recipe()).is_true()


## The option's refusals (no error reaches Godot's output: the check returns the problem that
## _load_data reports): --random-start with a value, and --random-start with a --deck.
func test_the_random_start_option_refuses_a_value_and_a_deck() -> void:
	var options: Dictionary[String, String] = BalanceSim.SIMULATION_DEFAULTS.duplicate()
	assert_str(BalanceSim.random_start_problem(options)).is_empty()
	options["random-start"] = "true"
	assert_str(BalanceSim.random_start_problem(options)).is_empty()
	options["deck"] = "res://data/decks/random_starter.tres"
	assert_str(BalanceSim.random_start_problem(options)).is_equal(
		"--random-start plays the game's recipe deck: no --deck"
	)
	# A --deck alone is fine.
	options["random-start"] = "false"
	assert_str(BalanceSim.random_start_problem(options)).is_empty()
	options = BalanceSim.SIMULATION_DEFAULTS.duplicate()
	options["random-start"] = "x"
	assert_str(BalanceSim.random_start_problem(options)).is_equal("--random-start takes no value")


static func _ids(cards: Array[CardDefinition]) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))
