extends GdUnitTestSuite
## The balance simulator (plan section 8, tools/balance_sim/): the exact row search against a
## brute-force search, the row limits, determinism, the saved cache, the player and the
## summary. Uses the frozen fixture cards, so tuning the live data never changes these tests.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const CACHE_FILE := "user://balance_sim_test.cache"


func after_test() -> void:
	if FileAccess.file_exists(CACHE_FILE):
		DirAccess.remove_absolute(CACHE_FILE)


func test_next_permutation_visits_each_distinct_order_once() -> void:
	var order: PackedInt32Array = PackedInt32Array([0, 0, 1, 2])
	var seen: Array[PackedInt32Array] = [order.duplicate()]
	while SimRowSearch.next_permutation(order):
		assert_bool(seen.has(order)).is_false()
		seen.append(order.duplicate())
	# 4! / 2! distinct orders, and the array is left at the last one.
	assert_int(seen.size()).is_equal(12)
	assert_array(Array(order)).is_equal([2, 1, 0, 0])


## Plan section 8: the best of every selection and order, shorter rows included. Soup beside
## Frozen peas pays 0 and Final markdown only pays last, so leaving cards out matters here.
func test_search_matches_brute_force() -> void:
	var balance: BalanceDefinition = _balance(7)
	var hand: Array[CardInstance] = _cards(
		"eggs,banana,banana,repeat,soup,frozen_peas,final_markdown"
	)
	var no_upgrades: Array[UpgradeDefinition] = []
	var best: SimHandBest = SimRowSearch.new(balance).search(hand, no_upgrades)
	var brute: Dictionary = {"best": -1, "without": {}}
	_brute_force(balance, hand, [], brute)
	assert_int(best.score).is_equal(brute["best"])
	assert_int(Scoring.score(best.row).total).is_equal(best.score)
	for card: CardInstance in hand:
		var without: Dictionary = brute["without"]
		assert_int(best.best_without[card.definition]).is_equal(without[card.definition])


func test_the_golden_31_row_is_found() -> void:
	var hand: Array[CardInstance] = _cards("banana,repeat,bread,eggs,banana,cheese")
	var no_upgrades: Array[UpgradeDefinition] = []
	var best: SimHandBest = SimRowSearch.new(_balance(7)).search(hand, no_upgrades)
	assert_int(best.score).is_greater_equal(31)
	assert_int(Scoring.score(best.row).total).is_equal(best.score)


## Plan section 3.1 (v0.46, #106): at most slot_count cards, any card in any slot.
func test_best_row_keeps_the_row_limits() -> void:
	var search: SimRowSearch = SimRowSearch.new(_balance(7))
	var no_upgrades: Array[UpgradeDefinition] = []
	var products: SimHandBest = search.search(
		_cards("bread,bread,bread,bread,bread,bread,bread,bread"), no_upgrades
	)
	assert_int(products.row.size()).is_equal(7)
	var with_coupons: SimHandBest = search.search(
		_cards("bread,bread,bread,bread,bread,bread,repeat,repeat"), no_upgrades
	)
	assert_int(with_coupons.row.size()).is_equal(7)
	var fewer: SimHandBest = SimRowSearch.new(_balance(6)).search(
		_cards("bread,bread,bread,bread,bread,bread,repeat,repeat"), no_upgrades
	)
	assert_int(fewer.row.size()).is_equal(6)


## Results never depend on draw order or on what the cache already holds.
func test_result_does_not_depend_on_hand_order_or_cache() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var fresh: SimRowSearch = SimRowSearch.new(_balance(7))
	var first: SimHandBest = fresh.search(_cards("milk,coffee,bread,eggs,banana"), no_upgrades)
	var warm: SimRowSearch = SimRowSearch.new(_balance(7))
	warm.search(_cards("milk,bread,eggs"), no_upgrades)
	var second: SimHandBest = warm.search(_cards("banana,eggs,bread,coffee,milk"), no_upgrades)
	assert_int(second.score).is_equal(first.score)
	assert_array(_ids(second.row)).is_equal(_ids(first.row))


func test_saved_cache_gives_the_same_result_without_scoring() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var search: SimRowSearch = SimRowSearch.new(_balance(7))
	var best: SimHandBest = search.search(_cards("eggs,bread,cheese,banana"), no_upgrades)
	assert_bool(search.save_cache(CACHE_FILE, true)).is_true()
	var loaded: SimRowSearch = SimRowSearch.new(_balance(7))
	assert_bool(loaded.load_cache(CACHE_FILE)).is_true()
	var again: SimHandBest = loaded.search(_cards("banana,cheese,bread,eggs"), no_upgrades)
	assert_int(loaded.rows_scored).is_equal(0)
	assert_int(again.score).is_equal(best.score)
	assert_array(_ids(again.row)).is_equal(_ids(best.row))


## Plan section 3.9: an inspected shift's best row is searched under its inspection, and a
## cached best row of an uninspected hand is never reused under one (or the other way round).
func test_search_respects_inspections_and_keeps_their_cache_apart() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var inspections: Array[InspectionDefinition] = [_third_product_pays_zero()]
	var search: SimRowSearch = SimRowSearch.new(_balance(7))
	var plain: SimHandBest = search.search(_cards("bread,bread,bread,bread"), no_upgrades)
	assert_int(plain.score).is_equal(12)
	var inspected: SimHandBest = search.search(
		_cards("bread,bread,bread,bread"), no_upgrades, inspections
	)
	# 3 + 3 + 0 + 3: the 3rd Bread pays 0, and a 4th still beats stopping at 2.
	assert_int(inspected.score).is_equal(9)
	assert_int(Scoring.score(inspected.row, no_upgrades, inspections).total).is_equal(9)
	var again: SimHandBest = search.search(_cards("bread,bread,bread,bread"), no_upgrades)
	assert_int(again.score).is_equal(12)


## A best order is never reused under another product slot change (#77 S1 fix): a rule may read
## the slot change (SlotChangeRule here: no live rule does since the Slot engine keeps to slot 6,
## 2026-10-24), and Big basket changes it, though Big basket has no rules of its own.
func test_cache_keeps_slot_changes_apart() -> void:
	var rule: SlotChangeRule = SlotChangeRule.new()
	var engine: UpgradeDefinition = UpgradeDefinition.new()
	engine.id = &"test_slot_engine"
	var rules: Array[UpgradeRule] = [rule]
	engine.rules = rules
	var basket: UpgradeDefinition = UpgradeDefinition.new()
	basket.id = &"test_big_basket"
	basket.extra_slots = 1
	var with_engine: Array[UpgradeDefinition] = [engine]
	var with_both: Array[UpgradeDefinition] = [engine, basket]
	var hand_ids: String = "banana,bread,milk,eggs,cheese,soup"
	var search: SimRowSearch = SimRowSearch.new(_balance(7))
	var engine_best: int = search.search(_cards(hand_ids), with_engine).score
	var both_best: int = search.search(_cards(hand_ids), with_both).score
	var fresh: SimRowSearch = SimRowSearch.new(_balance(7))
	assert_int(both_best).is_equal(fresh.search(_cards(hand_ids), with_both).score)
	assert_int(both_best).is_less(engine_best)


## The player plays inspected shifts under their inspection: its own check (the checkout total
## equals the searched best) would print an error otherwise, and tools/test.sh fails on it.
func test_the_player_plays_inspected_shifts() -> void:
	var player: SimPlayer = _player("greedy", [2, 3])
	var record: SimRunRecord = player.play(11)
	assert_str(record.shifts[0]["inspection"]).is_empty()
	if record.shifts.size() > 1:
		assert_str(record.shifts[1]["inspection"]).is_equal("third_product")


func test_same_seed_plays_the_same_run() -> void:
	var first: SimRunRecord = _player("greedy").play(5)
	var second: SimRunRecord = _player("greedy").play(5)
	assert_array(first.shifts).is_equal(second.shifts)
	assert_array(Array(first.final_deck)).is_equal(Array(second.final_deck))
	assert_int(first.shifts.size()).is_greater(0)


func test_skip_strategy_keeps_the_starting_deck() -> void:
	var record: SimRunRecord = _player("skip").play(3)
	var deck: Array = Array(record.final_deck)
	deck.sort()
	assert_array(deck).is_equal(["banana", "banana", "bread", "eggs", "milk", "repeat"])
	for shift: Dictionary in record.shifts:
		for visit: Dictionary in shift["visits"]:
			if visit["chute"] == "new_items" or visit["chute"] == "coupons":
				assert_bool(visit["binned"]).is_true()


func test_favour_strategy_takes_a_favoured_card_when_offered() -> void:
	var record: SimRunRecord = _player("favour:multipack").play(9)
	# The first COUPONS draw always holds the first-offer pool's only card, Multipack: the
	# favouring player chooses that chute from its odds card and takes it.
	var visit: Dictionary = record.shifts[0]["visits"][0]
	assert_str(visit["chute"]).is_equal("coupons")
	assert_str(visit["prizes"][int(visit["picked"])]["id"]).is_equal("multipack")


## #77: the simulator plays every machine visit the run gets, the ticket's, the inspected
## shift's BONUS and STAMP DAY's, through the real machine: each visit is picked or binned, the
## register cap holds, and the record lists every visit (surviving the JSON merge).
func test_the_player_plays_every_visit() -> void:
	var kinds: Dictionary = {}
	for strategy: String in ["greedy", "random", "skip"]:
		for seed_value: int in range(1, 6):
			var record: SimRunRecord = _player(strategy, [2]).play(seed_value)
			var registers: int = 0
			for index: int in range(record.shifts.size()):
				var shift: Dictionary = record.shifts[index]
				var visits: Array = shift["visits"]
				var last: bool = index == record.shifts.size() - 1
				if shift["passed"] and not last:
					assert_int(visits.size()).is_greater(0)
				for visit: Dictionary in visits:
					kinds[visit["kind"]] = true
					assert_bool(int(visit["picked"]) >= 0 or visit["binned"]).is_true()
					var picked: int = int(visit["picked"])
					if picked >= 0 and visit["prizes"][picked]["kind"] == "register":
						registers += 1
			assert_int(registers).is_less_equal(3)
			var copy: SimRunRecord = SimRunRecord.from_dictionary(
				JSON.parse_string(JSON.stringify(record.to_dictionary()))
			)
			assert_array(copy.shifts).is_equal(record.shifts)
	assert_bool(kinds.has("ticket")).is_true()
	assert_bool(kinds.has("bonus")).is_true()
	assert_bool(kinds.has("stamp_day")).is_true()
	var summary: SimSummary = SimSummary.new("test", PackedInt32Array([5, 8, 12]))
	summary.add(_player("skip").play(3))
	assert_int(summary.skips).is_greater(0)
	assert_str(summary.format()).contains("Machine chutes: new_items")


## The chute is chosen from the odds cards alone: the same run state chooses the same chute
## whatever the machine would drop (the drop depends on the run's RNG, the odds don't). Greedy
## chooses the lit chute whose draw is worth most (S1).
func test_the_chute_choice_never_reads_the_drops() -> void:
	var player: SimPlayer = _player("greedy")
	var run: RunState = RunState.new(4, player._starter, player._balance, player._stock)
	run.start_shift()
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var usage: Dictionary[CardDefinition, int] = {}
	var chosen: int = player._choose_chute(run, usage)
	player._values.clear()
	run.rng_state = 12345
	assert_int(player._choose_chute(run, usage)).is_equal(chosen)
	var best: int = -1
	var best_value: float = -INF
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = run.machine.chute_info(run, chute)
		if info.state != RewardMachine.ChuteState.OPEN:
			continue
		var value: float = player._chute_value(run, usage, chute, info.odds)
		if value > best_value:
			best_value = value
			best = chute
	assert_int(chosen).is_equal(best)
	assert_float(best_value).is_greater_equal(0.0)


## The expected best of a draw: the best prize drawn counts, each weighted by its chance and the
## chance that no better one is drawn.
func test_expected_best_weights_the_best_drawn_prize() -> void:
	var gains: Array[float] = [0.0, 10.0, 5.0]
	var chances: Array[float] = [1.0, 0.5, 0.5]
	# 10 half the time, else 5 half the time, else 0: 5 + 1.25.
	assert_float(SimPlayer.expected_best(gains, chances)).is_equal_approx(6.25, 0.0001)
	var none: Array[float] = []
	assert_float(SimPlayer.expected_best(none, none)).is_equal(0.0)
	var one: Array[float] = [4.0]
	var half: Array[float] = [0.5]
	assert_float(SimPlayer.expected_best(one, half)).is_equal_approx(4.0, 0.0001)


## The record and the summary report the machine (S1): registers, BIG / GOLDEN copies, visits by
## kind and by machine state (v0.47), and the bin rate. The simulator follows the lit chutes:
## REGISTER and UPGRADES only on BOOSTED visits (registers otherwise from STAMP DAY), NEW ITEMS
## and COUPONS only on Normal ones.
func test_records_and_summary_report_the_machine() -> void:
	var record: SimRunRecord = _player("greedy", [2]).play(2)
	var registers: int = 0
	var boosted: int = 0
	for shift: Dictionary in record.shifts:
		for visit: Dictionary in shift["visits"]:
			var picked: int = int(visit["picked"])
			if picked >= 0 and visit["prizes"][picked]["kind"] == "register":
				registers += 1
			var chute: String = visit["chute"]
			var boosted_chute: bool = chute == "register" or chute == "upgrades"
			if visit["kind"] == "stamp_day":
				assert_str(chute).is_equal("register")
			else:
				assert_bool(boosted_chute).is_equal(bool(visit["boosted"]))
			if visit["boosted"]:
				boosted += 1
				assert_bool([3, 5, 7].has(int(shift["shift"]))).is_true()
	assert_int(record.registers).is_equal(registers)
	var copy: SimRunRecord = SimRunRecord.from_dictionary(
		JSON.parse_string(JSON.stringify(record.to_dictionary()))
	)
	assert_dict(copy.to_dictionary()).is_equal(record.to_dictionary())
	record.tier_copies = {"milk_golden": 2, "banana_big": 1}
	var summary: SimSummary = SimSummary.new("test", PackedInt32Array([5, 8, 12]))
	summary.add(record)
	var text: String = summary.format()
	assert_str(text).contains("GOLDEN Milk per run: 2.00")
	assert_str(text).contains("BIG / GOLDEN copies per run: milk_golden 2.00, banana_big 1.00")
	assert_str(text).contains("Registers owned (runs): ")
	assert_str(text).contains("Machine visits per run by state: normal ")
	assert_str(text).not_contains("Regular levels")
	var states: Dictionary = summary.to_dictionary()["machine_visit_states"]
	assert_int(int(states.get(RewardMachine.STATE_BOOSTED, 0))).is_equal(boosted)
	assert_str(text).contains("Machine visits per run: ticket ")
	assert_str(text).contains("Binned: ")
	assert_int(summary.to_dictionary()["registers_owned"][record.registers]).is_equal(1)


func test_strategy_names() -> void:
	assert_bool(SimPlayer.is_known_strategy("greedy")).is_true()
	assert_bool(SimPlayer.is_known_strategy("favour:eggs+milk")).is_true()
	assert_bool(SimPlayer.is_known_strategy("favour:")).is_false()
	assert_bool(SimPlayer.is_known_strategy("best")).is_false()


func test_run_record_survives_json() -> void:
	var record: SimRunRecord = _player("random").play(2)
	var text: String = JSON.stringify(record.to_dictionary())
	var copy: SimRunRecord = SimRunRecord.from_dictionary(JSON.parse_string(text))
	assert_dict(copy.to_dictionary()).is_equal(record.to_dictionary())


func test_summary_percentiles_and_dominated_cards() -> void:
	var summary: SimSummary = SimSummary.new("test", PackedInt32Array([10]))
	for total: int in [5, 1, 4, 2, 3]:
		var record: SimRunRecord = SimRunRecord.new()
		(
			record
			. shifts
			. append(
				{
					"shift": 1,
					"quota": 10,
					"total": total,
					"passed": false,
					"visits": [],
				}
			)
		)
		record.drawn = {"soup": 10, "eggs": 10}
		record.needed = {"eggs": 3}
		summary.add(record)
	assert_int(summary.percentile(0, 10)).is_equal(1)
	assert_int(summary.percentile(0, 50)).is_equal(3)
	assert_int(summary.percentile(0, 100)).is_equal(5)
	assert_array(summary.dominated()).is_equal(["soup"])
	assert_float(summary.win_rate()).is_equal(0.0)


## Every ordered selection of distinct instances that fits the row: records the best total,
## and per definition the best total of rows without it.
func _brute_force(
	balance: BalanceDefinition, hand: Array[CardInstance], row: Array, result: Dictionary
) -> void:
	var typed_row: Array[CardInstance] = []
	typed_row.assign(row)
	var total: int = Scoring.score(typed_row).total
	result["best"] = maxi(result["best"], total)
	var without: Dictionary = result["without"]
	for card: CardInstance in hand:
		var used: bool = false
		for placed: CardInstance in typed_row:
			used = used or placed.definition == card.definition
		if not used:
			without[card.definition] = maxi(without.get(card.definition, -1), total)
	for card: CardInstance in hand:
		if not row.has(card) and RowCapacity.fits(_no_upgrade_limits(balance), typed_row):
			_brute_force(balance, hand, row + [card], result)


## A 3-shift test balance with the live machine (#77; STAMP DAY after shift 2) and the live
## register pool; `inspection_shifts` are inspected (a BONUS visit follows each).
func _player(strategy: String, inspection_shifts: Array = []) -> SimPlayer:
	var balance: BalanceDefinition = _balance(7)
	var live: BalanceDefinition = load("res://data/balance/balance.tres")
	balance.machine = live.machine
	balance.upgrade_pool = live.upgrade_pool.duplicate()
	balance.inspection_shifts = PackedInt32Array(inspection_shifts)
	if not inspection_shifts.is_empty():
		balance.inspection_pool.append(_third_product_pays_zero())
	balance.quotas = PackedInt32Array([5, 8, 12])
	balance.hand_size = 5
	balance.base_redraws = 1
	balance.basket_size = 2
	balance.deck_limit = 8
	# The stock: the staples (the deck's products), then this aisle, then the coupons.
	for id: String in ["banana", "bread", "eggs", "milk"]:
		balance.staples.append(_card(id))
	var aisle: AisleDefinition = AisleDefinition.new()
	aisle.id = &"test"
	aisle.base_cards.append(_card("cheese"))
	balance.aisles.append(aisle)
	balance.aisle_stock_budget = 16
	for id: String in ["repeat", "multipack"]:
		balance.coupon_pool.append(_card(id))
	balance.first_offer_pool.append(_card("multipack"))
	var deck: DeckDefinition = DeckDefinition.new()
	deck.id = &"test"
	for id: String in ["banana", "banana", "bread", "eggs", "milk", "repeat"]:
		deck.cards.append(_card(id))
	return SimPlayer.new(deck, balance, SimRowSearch.new(balance), strategy, 2)


static func _third_product_pays_zero() -> InspectionDefinition:
	var rule: NthProductZeroPayoutRule = NthProductZeroPayoutRule.new()
	rule.product_number = 3
	var rules: Array[InspectionRule] = [rule]
	var inspection: InspectionDefinition = InspectionDefinition.new()
	inspection.id = &"third_product"
	inspection.rules = rules
	return inspection


static func _balance(slots: int) -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.slot_count = slots
	return balance


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [FIXTURE_DIR, id])


static func _cards(ids: String) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for id: String in ids.split(","):
		cards.append(CardInstance.new(_card(id), cards.size() + 1))
	return cards


static func _ids(cards: Array[CardInstance]) -> Array:
	return cards.map(func(card: CardInstance) -> String: return String(card.definition.id))


static func _no_upgrade_limits(balance: BalanceDefinition) -> ShiftLimits:
	var none: Array[UpgradeDefinition] = []
	return ShiftLimits.for_shift(balance, none, 0)


## A test rule that reads ScoreState.product_slot_change: the 6th product, or the 7th with one
## slot more, pays x2 (the Slot engine's rule before 2026-10-24).
class SlotChangeRule:
	extends UpgradeRule

	func multiplier(state: ScoreState, slot: int) -> int:
		return 2 if state.product_numbers[slot] == 6 + state.product_slot_change else 1
