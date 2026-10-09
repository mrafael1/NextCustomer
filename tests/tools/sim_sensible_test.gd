extends GdUnitTestSuite
## The balance simulator's sensible row player (issue #41): SimHillClimb, the "@sensible"
## strategies, the exact-best table in the summary and the calibration against logged
## checkouts (SimCalibration). Uses the frozen fixture cards, except the calibration, which reads
## logs by id through the live data as the game's logs do.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const BALANCE := "res://data/balance/balance.tres"


## Without changes the row is the hand placed in hand order.
func test_no_change_keeps_the_hand_order() -> void:
	var hand: Array[CardInstance] = _cards("cheese,bread,banana")
	var climber: SimHillClimb = SimHillClimb.new()
	climber.max_changes = 0
	var row: SimHandBest = climber.climb(hand, _limits(6, 1), _no_upgrades(), _no_inspections())
	assert_array(_ids(row.row)).is_equal(["cheese", "bread", "banana"])
	assert_int(row.score).is_equal(Scoring.score(row.row).total)


## Banana, Cheese, Bread, Banana scores 10. The best single change moves Cheese after Bread
## (14); a second moves the first Banana to the end (16, the exact best).
func test_each_change_is_the_best_single_change_up_to_the_cap() -> void:
	var climber: SimHillClimb = SimHillClimb.new()
	var expected: Dictionary[int, int] = {0: 10, 1: 14, 2: 16, SimHillClimb.UNCAPPED: 16}
	for changes: int in expected:
		climber.max_changes = changes
		var row: SimHandBest = climber.climb(
			_cards("banana,cheese,bread,banana"), _limits(6, 1), _no_upgrades(), _no_inspections()
		)
		assert_int(row.score).is_equal(expected[changes])
		assert_int(Scoring.score(row.row).total).is_equal(row.score)
	assert_int(SimHillClimb.SENSIBLE_CHANGES).is_equal(3)


## Every row fits the shift's limits (one fewer product slot, as under Short belt), scores what
## checkout would, never beats the exact best and depends only on its input.
func test_rows_fit_the_limits_and_never_beat_the_best() -> void:
	var hands: Array[String] = [
		"eggs,banana,banana,repeat,soup,frozen_peas,final_markdown,bread",
		"bread,bread,bread,bread,bread,bread,bread,repeat",
		"multipack,repeat,final_markdown,breakfast_sticker,milk,coffee,bread,banana",
	]
	for slots: int in [6, 5]:
		var balance: BalanceDefinition = _balance(slots, 1)
		var search: SimRowSearch = SimRowSearch.new(balance)
		for ids: String in hands:
			var row: SimHandBest = SimHillClimb.new().climb(
				_cards(ids), _limits(slots, 1), _no_upgrades(), _no_inspections()
			)
			assert_bool(SimHillClimb.fits(_limits(slots, 1), row.row)).is_true()
			assert_int(Scoring.score(row.row).total).is_equal(row.score)
			assert_int(row.score).is_less_equal(search.search(_cards(ids), _no_upgrades()).score)
			var again: SimHandBest = SimHillClimb.new().climb(
				_cards(ids), _limits(slots, 1), _no_upgrades(), _no_inspections()
			)
			assert_array(_ids(again.row)).is_equal(_ids(row.row))


## A climb from a kept row (after a redraw) starts from that row, not from the hand.
func test_a_climb_can_start_from_a_kept_row() -> void:
	var hand: Array[CardInstance] = _cards("banana,cheese,banana,bread")
	var start: Array[CardInstance] = [hand[3], hand[1]]
	var climber: SimHillClimb = SimHillClimb.new()
	climber.max_changes = 0
	var row: SimHandBest = climber.climb(
		hand, _limits(6, 1), _no_upgrades(), _no_inspections(), start
	)
	assert_array(_ids(row.row)).is_equal(["bread", "cheese"])
	assert_int(row.score).is_equal(10)


func test_sensible_strategy_names() -> void:
	assert_bool(SimPlayer.is_known_strategy("greedy@sensible")).is_true()
	assert_bool(SimPlayer.is_known_strategy("random@sensible")).is_true()
	assert_bool(SimPlayer.is_known_strategy("favour:eggs@sensible")).is_true()
	assert_bool(SimPlayer.is_known_strategy("best@sensible")).is_false()
	assert_bool(SimPlayer.is_known_strategy("greedy@")).is_false()


## A sensible run records each shift's exact best beside the played total (checkout must score
## what the climb said, or the player prints an error and tools/test.sh fails), replays from its
## seed and survives the JSON merge.
func test_sensible_runs_record_the_exact_best() -> void:
	var record: SimRunRecord = _player("greedy@sensible").play(4)
	assert_int(record.shifts.size()).is_greater(0)
	for shift: Dictionary in record.shifts:
		assert_int(shift["best"]).is_greater_equal(shift["total"])
		# The hand at checkout, the cards checked out included.
		var hand: Array = shift["hand"].duplicate()
		assert_int(hand.size()).is_equal(5)
		for id: String in shift["played"]:
			assert_bool(hand.has(id)).is_true()
			hand.erase(id)
	var again: SimRunRecord = _player("greedy@sensible").play(4)
	assert_array(again.shifts).is_equal(record.shifts)
	var copy: SimRunRecord = SimRunRecord.from_dictionary(
		JSON.parse_string(JSON.stringify(record.to_dictionary()))
	)
	assert_array(copy.shifts).is_equal(record.shifts)
	# Best rows record their own total as the best.
	for shift: Dictionary in _player("greedy").play(4).shifts:
		assert_int(shift["best"]).is_equal(shift["total"])


## The summary of a sensible strategy adds the exact-best table and the share of it played.
func test_summary_shows_the_exact_best_for_sensible_rows() -> void:
	var summary: SimSummary = SimSummary.new("greedy@sensible", PackedInt32Array([10]))
	for totals: Array in [[8, 10], [10, 10], [0, 0]]:
		var record: SimRunRecord = SimRunRecord.new()
		(
			record
			. shifts
			. append(
				{
					"shift": 1,
					"quota": 10,
					"total": totals[0],
					"best": totals[1],
					"passed": totals[0] >= 10,
					"card_picked": "",
					"reward_skipped": false,
					"upgrade_taken": "",
				}
			)
		)
		summary.add(record)
	assert_array(Array(summary.best_shares[0])).is_equal([80, 100, 100])
	assert_str(summary.format()).contains("Exact best rows of the same hands")
	assert_int(summary.to_dictionary()["shifts"][0]["share_of_best_p50"]).is_equal(100)
	assert_str(SimSummary.new("greedy", PackedInt32Array([10])).format()).not_contains(
		"Exact best rows"
	)


## Logged checkouts are rebuilt from the shift's draw, its redraws and the run's upgrades;
## checkouts without placements or whose row isn't in the hand are left out.
func test_calibration_rebuilds_logged_checkouts() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for event: Dictionary in [
		_event(1, "shift_start", {"shift": 1, "cards_drawn": ["bread", "milk", "eggs"]}),
		_event(2, "checkout", {"shift": 1, "placements": 0, "final_order": ["bread"]}),
		_event(3, "upgrade", {"shift": 1, "picked": "extra_redraw"}),
		_event(
			4,
			"shift_start",
			{"shift": 2, "cards_drawn": ["soup", "bread", "banana"], "inspections": []}
		),
		# Replaced in click order, received in hand order: Banana takes Soup's place, Bread's
		# place gets the second card.
		_event(
			5,
			"redraw",
			{"cards_replaced": ["bread", "soup"], "cards_received": ["banana", "bread"]}
		),
		_event(
			6,
			"checkout",
			{"shift": 2, "placements": 3, "final_order": ["bread", "banana", "banana"], "score": 9}
		),
		_event(7, "shift_start", {"shift": 3, "cards_drawn": ["bread"]}),
		_event(8, "checkout", {"shift": 3, "placements": 1, "final_order": ["milk"]}),
	]:
		lines.append(JSON.stringify(event))
	var balance: BalanceDefinition = load(BALANCE)
	var calibration: SimCalibration = SimCalibration.new()
	calibration.read(lines, ContentLookup.new(balance))
	assert_int(calibration.checkouts.size()).is_equal(1)
	var checkout: SimCalibration.Checkout = calibration.checkouts[0]
	assert_array(checkout.hand.map(_id)).is_equal(["banana", "bread", "banana"])
	assert_array(checkout.row.map(_id)).is_equal(["bread", "banana", "banana"])
	assert_array(checkout.upgrades.map(_id)).is_equal(["extra_redraw"])
	assert_dict(calibration.skipped).is_equal({"no placements": 1, "row not in hand": 1})
	var results: Array[PackedInt32Array] = calibration.evaluate(balance, SimRowSearch.new(balance))
	var totals: PackedInt32Array = results[0]
	assert_int(totals.size()).is_equal(2 + SimCalibration.VARIANTS.size())
	for index: int in range(totals.size()):
		assert_int(totals[index]).is_less_equal(totals[1])
	assert_str(calibration.report(results)).contains("Row calibration: 1 logged checkouts")


## A chained profile spends each run's coins on capsules (key item first, never twice), lists
## an aisle once it is listable, and its summary counts unfinished profiles past the limit.
func test_chained_profiles_buy_capsules_and_list_new_aisles() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var starter: DeckDefinition = load("res://data/decks/starter.tres")
	var chain: SimChain = SimChain.new(starter, balance, Callable(), 7)
	for coin: int in range(SimChain.capsule_count(balance) + 3):
		chain._draw_capsule(coin)
	assert_int(chain._unlocked.size()).is_equal(SimChain.capsule_count(balance))
	for aisle: AisleDefinition in balance.aisles:
		var key: StringName = aisle.capsule_cards[0].id
		for card: CardDefinition in aisle.capsule_cards:
			assert_int(chain._unlocked[key]).is_less_equal(chain._unlocked[card.id])
	# A fresh profile needs no list; a machine-opened aisle at aisle_listable_min joins it.
	var fresh: SimChain = SimChain.new(starter, balance, Callable(), 7)
	assert_array(fresh._list()).is_empty()
	var opened: AisleDefinition = balance.aisles[balance.aisles.size() - 1]
	assert_bool(opened.base_cards.is_empty()).is_true()
	for index: int in range(balance.aisle_listable_min):
		fresh._unlocked[opened.capsule_cards[index].id] = 0
	var list: Array[StringName] = fresh._list()
	assert_int(list.size()).is_equal(balance.run_aisle_picks)
	assert_bool(list.has(opened.id)).is_true()
	assert_array(fresh._list()).is_equal(list)
	var done: SimChain = SimChain.from_dictionary(
		{"coins": [2, 1], "won": [true, false], "unlocked_after": [2, 3], "runs_to_all": -1}
	)
	var summary: Dictionary = SimChainSummary.summary([done])
	assert_int(summary["unfinished"]).is_equal(1)
	assert_int(summary["runs_to_all_median"]).is_equal(3)
	assert_float(summary["mean_coins"]).is_equal(1.5)


static func _event(seq: int, type: String, fields: Dictionary) -> Dictionary:
	var event: Dictionary = {
		"type": type,
		"run_id": "run",
		"seq": seq,
		"time": "2026-10-09T10:00:00Z",
		"build": "test",
	}
	event.merge(fields)
	return event


static func _id(resource: Resource) -> String:
	return String(resource.get("id"))


func _player(strategy: String) -> SimPlayer:
	var balance: BalanceDefinition = _balance(6, 1)
	balance.quotas = PackedInt32Array([5, 8, 12])
	balance.hand_size = 5
	balance.redraw_limit = 2
	balance.deck_limit = 8
	balance.offer_size = 3
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


static func _balance(slots: int, coupon_slots: int) -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.slot_count = slots
	balance.coupon_slot_count = coupon_slots
	return balance


static func _limits(slots: int, coupon_slots: int) -> ShiftLimits:
	return ShiftLimits.for_shift(_balance(slots, coupon_slots), _no_upgrades(), 0)


static func _no_upgrades() -> Array[UpgradeDefinition]:
	var none: Array[UpgradeDefinition] = []
	return none


static func _no_inspections() -> Array[InspectionDefinition]:
	var none: Array[InspectionDefinition] = []
	return none


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [FIXTURE_DIR, id])


static func _cards(ids: String) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for id: String in ids.split(","):
		cards.append(CardInstance.new(_card(id), cards.size() + 1))
	return cards


static func _ids(cards: Array[CardInstance]) -> Array:
	return cards.map(func(card: CardInstance) -> String: return String(card.definition.id))
