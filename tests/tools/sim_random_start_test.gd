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


## --pack=<id> (v1.28) needs --random-start, and a player given that pack (forced_pack) takes it
## every run, even one the fresh stock's offer never holds (the Snack stand needs the Snacks
## aisle).
func test_the_pack_option_gives_every_run_that_pack() -> void:
	var options: Dictionary[String, String] = BalanceSim.SIMULATION_DEFAULTS.duplicate()
	options["pack"] = "snack_stand"
	assert_str(BalanceSim.random_start_problem(options)).is_equal(
		"--pack takes a starter pack: it needs --random-start"
	)
	options["random-start"] = "true"
	assert_str(BalanceSim.random_start_problem(options)).is_empty()
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([100000])
	var recipe: DeckDefinition = load(BalanceSim.RANDOM_START_DECK)
	var stand: StarterPackDefinition = load("res://data/starter_packs/snack_stand.tres")
	var player: SimPlayer = SimPlayer.new(recipe, balance, SimRowSearch.new(balance), "greedy", 1)
	player.forced_pack = stand
	for seed_value: int in [4, 8]:
		var record: SimRunRecord = player.play(seed_value)
		assert_str(record.start_pack).is_equal("snack_stand")
		for card: CardDefinition in stand.cards:
			assert_bool(Array(record.final_deck).has(String(card.id))).is_true()


## The measure-only builds (v1.28: Pair up, Snack lover, Household goods, Salvage) are measured
## (fitted) but never a run's main build, and the list gate's key-card check leaves them out.
func test_measure_only_builds_are_never_a_main_build() -> void:
	var builds: SimBuilds = SimBuilds.new(SimBuilds.load_folder("res://data/builds"))
	var measured: Array[String] = []
	for build: BuildDefinition in builds.builds:
		if build.measure_only:
			measured.append(String(build.id))
	measured.sort()
	assert_array(measured).is_equal(["household_goods", "pair_up", "salvage", "snack_lover"])
	var deck: Array[CardDefinition] = []
	for id: String in ["butter", "cheese", "cereal", "yogurt", "bread"]:
		deck.append(load("res://data/cards/%s.tres" % id))
	assert_bool(Array(builds.fitted(deck)).has("pair_up")).is_true()
	assert_str(builds.main_build(deck)).is_not_equal("pair_up")
	var chances: Dictionary[String, float] = {}
	for id: String in builds.ids():
		chances[id] = 0.5
	var kept: Dictionary[String, float] = builds.gate_chances(chances)
	assert_int(kept.size()).is_equal(builds.ids().size() - measured.size())
	for id: String in measured:
		assert_bool(kept.has(id)).is_false()


static func _ids(cards: Array[CardDefinition]) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))


## Each recorded shift holds the quota percent of its day and week events (v0.96), so
## tools/quota_fit.py can apply them: Rush hour +10, Holiday rush +15, Clearance week +15 with
## Rush hour +25, Bakery festival +10, none on shift 1; the JSON copy keeps them.
func test_records_hold_each_shift_quota_percent() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var rush: InspectionDefinition = load("res://data/inspections/rush_hour.tres")
	var cases: Array[Array] = [
		[1, [], 0], [1, [rush], 10], [9, [], 15], [13, [rush], 25], [6, [], 10]
	]
	for case: Array in cases:
		var record: ShiftRecord = ShiftRecord.new(case[0], 0, 0)
		record.inspections.assign(case[1])
		var got: int = SimPlayer.quota_percent(balance, record)
		assert_int(got).override_failure_message(str(case)).is_equal(case[2])
	var short: BalanceDefinition = balance.duplicate()
	short.quotas = PackedInt32Array([100000])
	var player: SimPlayer = SimPlayer.new(load(RECIPE), short, SimRowSearch.new(short), "skip", 1)
	var played: SimRunRecord = player.play(4)
	assert_int(played.shifts.size()).is_equal(1)
	assert_int(played.shifts[0]["quota_percent"]).is_equal(0)
	var copy: SimRunRecord = SimRunRecord.from_dictionary(
		JSON.parse_string(JSON.stringify(played.to_dictionary()))
	)
	assert_array(copy.shifts).is_equal(played.shifts)
