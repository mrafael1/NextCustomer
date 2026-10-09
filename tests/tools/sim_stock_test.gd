extends GdUnitTestSuite
## The balance simulator's stock and build reports (issue #40, full build plan sections 7 and
## 8): collection states (SimCollection), main builds and key cards (SimBuilds), the build
## strategy, coins per run and the 40% bar (SimSummary), the list gate's verdicts (SimListGate)
## and the orphan check (SimOrphans). Aisles, builds and balance data are built here on the
## frozen fixture cards, so tuning data/ never changes these tests.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"


func test_lists_are_every_combination_in_aisle_order() -> void:
	var aisles: Array[StringName] = [&"a", &"b", &"c"]
	assert_array(SimCollection.lists(aisles, 2)).is_equal(
		[[&"a", &"b"], [&"a", &"c"], [&"b", &"c"]]
	)
	assert_array(SimCollection.lists(aisles, 3)).is_equal([[&"a", &"b", &"c"]])
	assert_array(SimCollection.lists(aisles, 4)).is_empty()


## The full collection unlocks every capsule item and has no new arrivals.
func test_full_collection_stocks_the_listed_aisles_without_arrivals() -> void:
	var balance: BalanceDefinition = _balance()
	var state: SimCollection = SimCollection.full(balance, [&"dairy", &"deli"])
	assert_str(state.label).is_equal("full collection: dairy+deli")
	assert_int(state.unlocked.size()).is_equal(8)
	assert_str(state.problem(balance)).is_empty()
	var stock: RunStock = state.stock(_deck(), balance)
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"deli"])
	assert_array(stock.new_arrivals).is_empty()
	assert_array(_ids(stock.cards)).is_equal(
		[
			"banana",
			"bread",
			"eggs",
			"cheese",
			"milk",
			"coffee",
			"d1",
			"d2",
			"d3",
			"d4",
			"d5",
			"repeat",
			"multipack"
		]
	)


## A profile's unlocked items, run count and last list build the stock the game would build.
func test_a_profile_builds_the_games_next_stock() -> void:
	var balance: BalanceDefinition = _balance()
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 2
	profile.unlocked_items = {&"milk": 0, &"d1": 1}
	var state: SimCollection = SimCollection.from_profile(profile, balance, [])
	assert_str(state.label).is_equal("profile (run 2) (list skipped)")
	var stock: RunStock = state.stock(_deck(), balance)
	assert_bool(stock.list_skipped).is_true()
	assert_array(_ids(stock.new_arrivals)).is_equal(["d1"])
	assert_bool(_ids(stock.cards).has("milk")).is_true()
	var expected: RunStock = RunStock.build(_deck(), balance, [], profile.unlocked_items, 2)
	assert_array(_ids(stock.cards)).is_equal(_ids(expected.cards))


## Over the budget the stock needs a list of run_aisle_picks listable aisles: the profile's last
## list, or the one given instead.
func test_a_stock_over_the_budget_needs_a_full_list() -> void:
	var balance: BalanceDefinition = _balance()
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_items = {&"milk": 0, &"frozen_peas": 0}
	profile.last_list = [&"dairy", &"pantry"]
	assert_str(SimCollection.from_profile(profile, balance, []).problem(balance)).is_empty()
	var none: SimCollection = SimCollection.from_profile(profile, balance, [])
	none.listed = []
	assert_str(none.problem(balance)).contains("needs a list of 2 listable aisles (dairy+pantry)")
	var short: SimCollection = SimCollection.from_profile(profile, balance, [&"dairy"])
	assert_str(short.problem(balance)).contains("got dairy")
	var unknown: SimCollection = SimCollection.from_profile(profile, balance, [&"dairy", &"deli"])
	assert_str(unknown.problem(balance)).is_not_empty()


## Every legal list at full collection, the first list after the budget is passed, and each
## machine-opened aisle just listable with every list that holds it.
func test_gate_states() -> void:
	var balance: BalanceDefinition = _balance()
	var states: Array[SimCollection] = SimCollection.gate_states(balance)
	var labels: Array = states.map(func(state: SimCollection) -> String: return state.label)
	(
		assert_array(labels)
		. is_equal(
			[
				"full: dairy+pantry",
				"full: dairy+deli",
				"full: pantry+deli",
				"first list: dairy+pantry",
				"new aisle deli: dairy+deli",
				"new aisle deli: pantry+deli",
			]
		)
	)
	var groups: Array = states.map(func(state: SimCollection) -> String: return state.group)
	assert_array(groups).is_equal(
		["full", "full", "full", "first list", "new aisle deli", "new aisle deli"]
	)
	# The first list: one capsule item per base aisle per round until the budget (3) is passed.
	assert_array(states[3].unlocked.keys()).is_equal([&"milk", &"frozen_peas"])
	# The new aisle holds exactly aisle_listable_min items.
	assert_array(states[4].unlocked.keys()).is_equal([&"d1", &"d2"])
	for state: SimCollection in states:
		assert_str(state.problem(balance)).override_failure_message(state.label).is_empty()
		assert_array(state.stock(_deck(), balance).new_arrivals).is_empty()


## Within the budget a gate state is one state, its list skipped.
func test_gate_states_within_the_budget_skip_the_list() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 50
	var labels: Array = SimCollection.gate_states(balance).map(
		func(state: SimCollection) -> String: return state.label
	)
	assert_array(labels).is_equal(["full (list skipped)", "new aisle deli (list skipped)"])


func test_main_build_is_the_strongest_fit() -> void:
	var builds: SimBuilds = _builds()
	assert_str(builds.main_build(_defs("cheese,milk,banana"))).is_equal("dairy")
	assert_str(builds.main_build(_defs("cheese,milk,repeat,multipack,repeat"))).is_equal("coupons")
	# A tie (both at their minimum) goes to the earlier build.
	assert_str(builds.main_build(_defs("cheese,milk,repeat,multipack"))).is_equal("dairy")
	assert_str(builds.main_build(_defs("banana,bread"))).is_equal(SimBuilds.NO_BUILD)


func test_key_cards_count_towards_the_measure_alone() -> void:
	var builds: SimBuilds = _builds()
	assert_bool(SimBuilds.is_key_card(builds.find("dairy"), _card("cheese"))).is_true()
	assert_bool(SimBuilds.is_key_card(builds.find("dairy"), _card("banana"))).is_false()
	assert_bool(SimBuilds.is_key_card(builds.find("coupons"), _card("repeat"))).is_true()
	assert_bool(SimBuilds.is_key_card(builds.find("copies"), _card("banana"))).is_true()
	assert_bool(SimBuilds.is_key_card(builds.find("copies"), _card("repeat"))).is_false()


## Every later offer shows a coupon; a build whose key cards aren't stocked never shows one.
func test_key_offer_chance() -> void:
	var balance: BalanceDefinition = _balance()
	var builds: SimBuilds = _builds()
	var stock: RunStock = SimCollection.fresh().stock(_deck(), balance)
	var chances: Dictionary[String, float] = builds.key_offer_chance(balance, stock, 200, 7)
	assert_float(chances["coupons"]).is_equal(1.0)
	assert_float(chances["copies"]).is_equal(1.0)
	assert_float(chances["dairy"]).is_between(0.01, 0.99)
	assert_dict(builds.key_offer_chance(balance, stock, 200, 7)).is_equal(chances)
	var bare: BalanceDefinition = _balance()
	bare.aisles.clear()
	var no_dairy: RunStock = SimCollection.fresh().stock(_deck(), bare)
	assert_float(builds.key_offer_chance(bare, no_dairy, 200, 7)["dairy"]).is_equal(0.0)


## The build strategy takes the offered cards that raise its measure most.
func test_raising_cards() -> void:
	var builds: SimBuilds = _builds()
	(
		assert_array(
			_ids(
				SimPlayer.raising_cards(
					builds.find("dairy"), _defs("banana"), _defs("cheese,bread,milk")
				)
			)
		)
		. is_equal(["cheese", "milk"])
	)
	(
		assert_array(
			_ids(
				SimPlayer.raising_cards(
					builds.find("copies"),
					_defs("banana,banana,bread"),
					_defs("bread,banana,cheese")
				)
			)
		)
		. is_equal(["banana"])
	)
	(
		assert_array(
			SimPlayer.raising_cards(builds.find("dairy"), _defs("banana"), _defs("bread,soup"))
		)
		. is_empty()
	)


## A build strategy plays whole runs; every run records its main build and its coins, which are
## the CoinPayout of its history.
func test_build_strategy_runs_record_builds_and_coins() -> void:
	assert_bool(SimPlayer.is_known_strategy("build:dairy")).is_true()
	assert_bool(SimPlayer.is_known_strategy("build:")).is_false()
	var balance: BalanceDefinition = _balance()
	var player: SimPlayer = _build_player(balance, "build:dairy")
	for seed_value: int in [1, 2, 3]:
		var record: SimRunRecord = player.play(seed_value)
		var final_deck: Array[CardDefinition] = []
		for id: String in record.final_deck:
			final_deck.append(_card(id))
		assert_str(record.main_build).is_equal(_builds().main_build(final_deck))
		var passed: int = 0
		var overtime: int = 0
		for shift: Dictionary in record.shifts:
			if shift["passed"]:
				passed += 1
				overtime += int(shift["total"]) - int(shift["quota"])
		var overtime_coins: int = mini(floori(overtime / 60.0), 1)
		assert_int(record.overtime_coins).is_equal(overtime_coins)
		assert_int(record.coins).is_equal(balance.coins_by_shifts_passed[passed] + overtime_coins)
		var copy: SimRunRecord = SimRunRecord.from_dictionary(
			JSON.parse_string(JSON.stringify(record.to_dictionary()))
		)
		assert_dict(copy.to_dictionary()).is_equal(record.to_dictionary())


## On the same seeds and stock, drafting towards Dairy ends with more Dairy cards than greedy.
func test_build_strategy_drafts_towards_its_build() -> void:
	var balance: BalanceDefinition = _balance()
	var dairy_cards: Dictionary[String, int] = {}
	var dairy_mains: int = 0
	for strategy: String in ["greedy", "build:dairy"]:
		var player: SimPlayer = _build_player(balance, strategy)
		dairy_cards[strategy] = 0
		for seed_value: int in range(1, 7):
			var record: SimRunRecord = player.play(seed_value)
			for id: String in record.final_deck:
				if _card(id).tags.has("Dairy"):
					dairy_cards[strategy] += 1
			if strategy == "build:dairy" and record.main_build == "dairy":
				dairy_mains += 1
	assert_int(dairy_cards["build:dairy"]).is_greater(dairy_cards["greedy"])
	assert_int(dairy_mains).is_greater(0)


## The build strategy's upgrade pick: the offered upgrades that list the build, by build id.
func test_upgrades_listing_a_build_match_by_id() -> void:
	var listed: BuildDefinition = _builds().find("dairy")
	var copy: BuildDefinition = listed.duplicate()
	var with_dairy: UpgradeDefinition = UpgradeDefinition.new()
	with_dairy.id = &"with_dairy"
	with_dairy.builds.append(listed)
	var without: UpgradeDefinition = UpgradeDefinition.new()
	without.id = &"without"
	var offer: Array[UpgradeDefinition] = [without, with_dairy]
	var found: Array = SimPlayer.upgrades_listing(copy, offer).map(
		func(upgrade: UpgradeDefinition) -> StringName: return upgrade.id
	)
	assert_array(found).is_equal([&"with_dairy"])


func test_summary_builds_bar_and_coins() -> void:
	var summary: SimSummary = SimSummary.new("greedy", PackedInt32Array([10, 10, 10]))
	summary.add(_record(true, 3, "a", 2, 0))
	summary.add(_record(true, 3, "a", 1, 0))
	summary.add(_record(true, 3, "b", 1, 0))
	summary.add(_record(false, 2, "b", 1, 1))
	summary.add(_record(false, 1, SimBuilds.NO_BUILD, 0, 0))
	assert_float(summary.win_share("a")).is_equal_approx(2.0 / 3.0, 0.0001)
	assert_array(summary.builds_over_bar()).is_equal(["a"])
	assert_array([summary.build_runs["a"], summary.build_runs["b"]]).is_equal([2, 2])
	assert_int(summary.build_runs[SimBuilds.NO_BUILD]).is_equal(1)
	assert_float(summary.coin_mean()).is_equal(1.0)
	assert_int(summary.coin_percentile(50)).is_equal(1)
	assert_int(summary.coin_percentile(90)).is_equal(2)
	assert_float(summary.runs_to_unlock_all()).is_equal(30.0)
	assert_array(Array(summary.coin_counts())).is_equal([1, 3, 1])
	assert_int(summary.lost_on_shift_2).is_equal(1)
	assert_int(summary.lost_on_shift_2_overtime).is_equal(1)
	assert_str(summary.format()).contains(
		"40% bar (no main build over 40% of the won runs): FAIL (a)"
	)
	assert_str(summary.format()).contains("Runs to 30 unlocks (30 ÷ mean coins): 30.0")
	# Only the greedy strategy is held to the bar.
	var other: SimSummary = SimSummary.new("random", PackedInt32Array([10, 10, 10]))
	other.add(_record(true, 3, "a", 2, 0))
	assert_str(other.format()).not_contains("40% bar")


## Runs that fit no build aren't a build: they never fail the bar, but count in the won runs.
func test_no_build_is_never_over_the_bar() -> void:
	var summary: SimSummary = SimSummary.new("greedy", PackedInt32Array([10]))
	for build: String in [SimBuilds.NO_BUILD, SimBuilds.NO_BUILD, SimBuilds.NO_BUILD, "a"]:
		summary.add(_record(true, 1, build, 0, 0))
	assert_float(summary.win_share(SimBuilds.NO_BUILD)).is_equal(0.75)
	assert_array(summary.builds_over_bar()).is_empty()
	assert_str(summary.format()).contains("40% bar (no main build over 40% of the won runs): pass")


func test_list_gate_verdicts() -> void:
	var fresh: Array[SimSummary] = [_summary_with(10, 8, "a")]
	var full: SimCollection = SimCollection.new()
	full.label = "full: x+y"
	full.group = "full"
	var fresh_chances: Dictionary[String, float] = {"a": 0.8, "b": 0.5}
	var good_chances: Dictionary[String, float] = {"a": 0.7, "b": 0.45}
	# Within 5 points (77/100 against 8/10), wins spread over 3 builds, key cards at 87% and 90%.
	var mixed: SimSummary = SimSummary.new("greedy", PackedInt32Array([10]))
	for index: int in range(100):
		mixed.add(_record(index < 77, 1, ["a", "b", "c"][index % 3], 0, 0))
	var passing: Dictionary = SimListGate.check(full, [mixed], fresh, good_chances, fresh_chances)
	assert_bool(passing["passed"]).override_failure_message(str(passing["failures"])).is_true()
	# 10 points off, a build over the bar and key cards short.
	var short_chances: Dictionary[String, float] = {"a": 0.4, "b": 0.5}
	var failing: Dictionary = SimListGate.check(
		full, [_summary_with(10, 7, "a")], [_summary_with(10, 8, "a")], short_chances, fresh_chances
	)
	assert_bool(failing["passed"]).is_false()
	assert_array(failing["failures"]).is_equal(
		["greedy win rate -10.0 points", "over the 40% bar: a", "key cards below 85%: a 50%"]
	)
	# The key-card check is for the full collection only.
	var first: SimCollection = SimCollection.new()
	first.group = "first list"
	var other: Dictionary = SimListGate.check(first, [mixed], fresh, short_chances, fresh_chances)
	assert_bool(other["passed"]).is_true()
	var report: String = SimListGate.format([passing, failing], fresh)
	assert_str(report).contains("Gate: FAIL (1 of 2 states pass)")
	assert_str(report).contains("full: x+y · greedy 77.0% (-3.0, 100 runs) · pass")


## ±5 points is inclusive both ways, counted exactly (150 and 170 of 200 against 160 of 200).
func test_list_gate_win_rate_bounds_are_inclusive() -> void:
	var full: SimCollection = SimCollection.new()
	var chances: Dictionary[String, float] = {}
	var fresh: Array[SimSummary] = [_spread_summary(200, 160)]
	for wins: int in [150, 170]:
		var verdict: Dictionary = SimListGate.check(
			full, [_spread_summary(200, wins)], fresh, chances, chances
		)
		assert_bool(verdict["passed"]).override_failure_message(str(verdict["failures"])).is_true()
	assert_float(SimListGate.win_rate_points(_spread_summary(200, 150), fresh[0])).is_equal(-5.0)
	var off: Dictionary = SimListGate.check(
		full, [_spread_summary(200, 149)], fresh, chances, chances
	)
	assert_bool(off["passed"]).is_false()


## A strategy the time limit left without runs can't pass: there is nothing to compare.
func test_list_gate_without_runs_is_not_a_pass() -> void:
	var full: SimCollection = SimCollection.new()
	var chances: Dictionary[String, float] = {}
	var empty: SimSummary = SimSummary.new("greedy", PackedInt32Array([10]))
	for pair: Array in [[empty, _spread_summary(10, 8)], [_spread_summary(10, 8), empty]]:
		var verdict: Dictionary = SimListGate.check(full, [pair[0]], [pair[1]], chances, chances)
		assert_bool(verdict["passed"]).is_false()
		assert_array(verdict["failures"]).is_equal(["greedy: no runs to compare (time limit)"])


## An item the staples and its aisle never put in a best row is an orphan.
func test_orphan_check() -> void:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.slot_count = 6
	balance.coupon_slot_count = 1
	balance.hand_size = 4
	var deli: AisleDefinition = AisleDefinition.new()
	deli.id = &"deli"
	deli.capsule_cards.append(_card("cheese"))
	deli.capsule_cards.append(_product(&"dud", 0, []))
	balance.aisles.append(deli)
	var deck: DeckDefinition = DeckDefinition.new()
	for id: String in ["bread", "banana", "repeat"]:
		deck.cards.append(_card(id))
	var orphans: SimOrphans = SimOrphans.new(deck, balance, 5, 1)
	assert_array(_ids(orphans.items)).is_equal(["cheese", "dud"])
	assert_int(orphans.sample_total()).is_equal(10)
	var search: SimRowSearch = SimRowSearch.new(balance)
	for index: int in range(orphans.sample_total()):
		orphans.run_sample(search, index)
	assert_array(Array(orphans.counts(0))).is_equal([5, 5, 5])
	assert_array(Array(orphans.counts(1))).is_equal([5, 0, 0])
	assert_array(orphans.orphans()).is_equal(["dud"])
	var copy: SimOrphans = SimOrphans.new(deck, balance, 5, 1)
	copy.add_samples(JSON.parse_string(JSON.stringify(orphans.samples_to_array())))
	assert_array(copy.orphans()).is_equal(["dud"])
	assert_str(orphans.format()).contains("Orphans: dud")
	assert_array(orphans.unsampled()).is_empty()
	# Samples take the items in turn: cut short after two samples, only item 0 has been played
	# twice and item 1 never, which the report says instead of calling it no orphan.
	var partial: SimOrphans = SimOrphans.new(deck, balance, 5, 1)
	for index: int in [0, 2]:
		partial.run_sample(search, index)
	assert_array(Array(partial.counts(0))).is_equal([2, 2, 2])
	assert_array(partial.unsampled()).is_equal(["dud"])
	assert_str(partial.format()).contains("Not sampled (time limit): dud")


## Staples banana, bread, eggs (and a Repeat). Aisles: Dairy (cheese; capsules milk, coffee),
## Pantry (soup; capsule frozen peas) and the machine-opened Deli (capsules d1 to d5). Budget 3,
## lists of 2, an aisle listable at 2 items.
static func _balance() -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.slot_count = 6
	balance.coupon_slot_count = 1
	balance.hand_size = 5
	balance.redraw_limit = 2
	balance.deck_limit = 10
	balance.offer_size = 3
	balance.quotas = PackedInt32Array([5, 8, 12])
	balance.coins_by_shifts_passed = PackedInt32Array([0, 1, 2, 3])
	balance.overtime_coin_euros = 60
	balance.overtime_coin_max = 1
	balance.aisle_stock_budget = 3
	balance.run_aisle_picks = 2
	balance.aisle_listable_min = 2
	balance.end_cap_max = 3
	balance.end_cap_window_runs = 3
	balance.aisles.append(_aisle(&"dairy", ["cheese"], [_card("milk"), _card("coffee")]))
	balance.aisles.append(_aisle(&"pantry", ["soup"], [_card("frozen_peas")]))
	var deli: Array[CardDefinition] = []
	for index: int in range(1, 6):
		deli.append(_product(StringName("d%d" % index), 2, ["Food"]))
	balance.aisles.append(_aisle(&"deli", [], deli))
	for id: String in ["repeat", "multipack"]:
		balance.coupon_pool.append(_card(id))
	balance.first_offer_pool.append(_card("multipack"))
	return balance


static func _aisle(
	id: StringName, base_ids: Array, capsules: Array[CardDefinition]
) -> AisleDefinition:
	var aisle: AisleDefinition = AisleDefinition.new()
	aisle.id = id
	for card_id: String in base_ids:
		aisle.base_cards.append(_card(card_id))
	aisle.capsule_cards = capsules
	return aisle


static func _deck() -> DeckDefinition:
	var deck: DeckDefinition = DeckDefinition.new()
	deck.id = &"test"
	for id: String in ["banana", "banana", "bread", "eggs", "repeat"]:
		deck.cards.append(_card(id))
	return deck


## Dairy (2 Dairy cards), Coupons (2 coupons) and Copies (3 copies of one product).
static func _builds() -> SimBuilds:
	var dairy: BuildDefinition = BuildDefinition.new()
	dairy.id = &"dairy"
	dairy.measure = BuildDefinition.Measure.TAG
	dairy.tag = "Dairy"
	dairy.min_count = 2
	var coupons: BuildDefinition = BuildDefinition.new()
	coupons.id = &"coupons"
	coupons.measure = BuildDefinition.Measure.COUPONS
	coupons.min_count = 2
	var copies: BuildDefinition = BuildDefinition.new()
	copies.id = &"copies"
	copies.measure = BuildDefinition.Measure.COPIES
	copies.min_count = 3
	return SimBuilds.new([dairy, coupons, copies])


## A run that played `shifts` shifts, passing all but a lost run's last one.
static func _record(
	won: bool, shifts: int, build: String, coins: int, overtime_coins: int
) -> SimRunRecord:
	var record: SimRunRecord = SimRunRecord.new()
	record.won = won
	record.main_build = build
	record.coins = coins
	record.overtime_coins = overtime_coins
	for shift: int in range(1, shifts + 1):
		(
			record
			. shifts
			. append(
				{
					"shift": shift,
					"quota": 10,
					"total": 10,
					"passed": won or shift < shifts,
					"card_picked": "",
					"reward_skipped": false,
					"upgrade_taken": "",
				}
			)
		)
	return record


## A greedy summary of `runs` runs, `wins` of them won, their main builds spread over 3 builds
## (none over the bar).
static func _spread_summary(runs: int, wins: int) -> SimSummary:
	var summary: SimSummary = SimSummary.new("greedy", PackedInt32Array([10]))
	for index: int in range(runs):
		summary.add(_record(index < wins, 1, ["a", "b", "c"][index % 3], 0, 0))
	return summary


## A player on the full collection's Dairy and Pantry stock, with the test builds.
static func _build_player(balance: BalanceDefinition, strategy: String) -> SimPlayer:
	return SimPlayer.new(
		_deck(),
		balance,
		SimRowSearch.new(balance),
		strategy,
		2,
		SimCollection.full(balance, [&"dairy", &"pantry"]).stock(_deck(), balance),
		_builds()
	)


## A greedy summary of `runs` runs, `wins` of them won, all with main build `build`.
static func _summary_with(runs: int, wins: int, build: String) -> SimSummary:
	var summary: SimSummary = SimSummary.new("greedy", PackedInt32Array([10]))
	for index: int in range(runs):
		summary.add(_record(index < wins, 1, build, 0, 0))
	return summary


static func _product(id: StringName, base: int, tags: Array) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = id
	card.display_name = String(id)
	card.kind = CardDefinition.Kind.PRODUCT
	card.base = base
	card.tags = PackedStringArray(tags)
	return card


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [FIXTURE_DIR, id])


static func _defs(ids: String) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for id: String in ids.split(","):
		cards.append(_card(id))
	return cards


static func _ids(cards: Array) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))
