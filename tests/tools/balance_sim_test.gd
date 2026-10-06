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
	var balance: BalanceDefinition = _balance(6, 1)
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
	var best: SimHandBest = SimRowSearch.new(_balance(6, 1)).search(hand, no_upgrades)
	assert_int(best.score).is_greater_equal(31)
	assert_int(Scoring.score(best.row).total).is_equal(best.score)


## Plan section 3.1: at most slot_count products, and the coupon slot holds only a coupon.
func test_best_row_keeps_the_row_limits() -> void:
	var search: SimRowSearch = SimRowSearch.new(_balance(6, 1))
	var no_upgrades: Array[UpgradeDefinition] = []
	var products: SimHandBest = search.search(
		_cards("bread,bread,bread,bread,bread,bread,bread,bread"), no_upgrades
	)
	assert_int(products.row.size()).is_equal(6)
	var with_coupons: SimHandBest = search.search(
		_cards("bread,bread,bread,bread,bread,bread,repeat,repeat"), no_upgrades
	)
	assert_int(with_coupons.row.size()).is_equal(7)
	assert_int(RowCapacity.product_count(with_coupons.row)).is_equal(6)
	var no_coupon_slot: SimHandBest = SimRowSearch.new(_balance(6, 0)).search(
		_cards("bread,bread,bread,bread,bread,bread,repeat,repeat"), no_upgrades
	)
	assert_int(no_coupon_slot.row.size()).is_equal(6)


## Results never depend on draw order or on what the cache already holds.
func test_result_does_not_depend_on_hand_order_or_cache() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var fresh: SimRowSearch = SimRowSearch.new(_balance(6, 1))
	var first: SimHandBest = fresh.search(_cards("milk,coffee,bread,eggs,banana"), no_upgrades)
	var warm: SimRowSearch = SimRowSearch.new(_balance(6, 1))
	warm.search(_cards("milk,bread,eggs"), no_upgrades)
	var second: SimHandBest = warm.search(_cards("banana,eggs,bread,coffee,milk"), no_upgrades)
	assert_int(second.score).is_equal(first.score)
	assert_array(_ids(second.row)).is_equal(_ids(first.row))


func test_saved_cache_gives_the_same_result_without_scoring() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var search: SimRowSearch = SimRowSearch.new(_balance(6, 1))
	var best: SimHandBest = search.search(_cards("eggs,bread,cheese,banana"), no_upgrades)
	assert_bool(search.save_cache(CACHE_FILE, true)).is_true()
	var loaded: SimRowSearch = SimRowSearch.new(_balance(6, 1))
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
	var search: SimRowSearch = SimRowSearch.new(_balance(6, 1))
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
		assert_str(shift["card_picked"]).is_empty()


func test_favour_strategy_takes_a_favoured_card_when_offered() -> void:
	var record: SimRunRecord = _player("favour:multipack").play(9)
	# The first offer always holds the first-offer pool's only card, Multipack.
	assert_str(record.shifts[0]["card_picked"]).is_equal("multipack")


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
					"card_picked": "",
					"reward_skipped": false,
					"upgrade_taken": "",
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
		if not row.has(card) and RowCapacity.fits(balance, typed_row, card.definition):
			_brute_force(balance, hand, row + [card], result)


func _player(strategy: String, inspection_shifts: Array = []) -> SimPlayer:
	var balance: BalanceDefinition = _balance(6, 1)
	balance.inspection_shifts = PackedInt32Array(inspection_shifts)
	if not inspection_shifts.is_empty():
		balance.inspection_pool.append(_third_product_pays_zero())
	balance.quotas = PackedInt32Array([5, 8, 12])
	balance.hand_size = 5
	balance.redraw_limit = 2
	balance.deck_limit = 8
	balance.offer_size = 3
	# The stock: the deck's products, then this aisle, then the coupons.
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


static func _balance(slots: int, coupon_slots: int) -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.slot_count = slots
	balance.coupon_slot_count = coupon_slots
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
