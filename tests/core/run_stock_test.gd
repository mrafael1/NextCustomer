extends GdUnitTestSuite
## The run's stock (full build plan 7.2), on fixture aisles built here so tuning data/ never
## changes these tests: data order, the unlocked filter, the budget rule, the listable minimum,
## new arrivals, and the same input giving the same stock.
##
## Fixture: staples s1, s2, s3 (the deck also holds coupon c1); coupon_pool c1, c2. Aisles in
## data order: dairy (base d1, d2, d3; capsules dk, d5, d6), bakery (base b1, b2; capsules bk,
## b4) and frozen, opened by its machine (capsules fk, f2, f3, f4, f5).

## Fixture cards by id, created once per test so every lookup returns the same definition.
var _cards: Dictionary[String, CardDefinition] = {}


func test_staples_are_the_deck_products_once_each_in_deck_order() -> void:
	assert_array(_ids(RunStock.staples(_deck()))).is_equal(["s1", "s2", "s3"])


func test_a_new_profile_stocks_staples_base_aisles_then_coupons() -> void:
	var stock: RunStock = RunStock.starting(_deck(), _balance())
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "b1", "b2", "c1", "c2"]
	)
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])
	assert_bool(stock.list_skipped).is_true()
	assert_array(stock.new_arrivals).is_empty()


func test_stock_order_is_data_order_never_list_or_unlock_order() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 5
	# Unlocked in reverse data order, listed in reverse data order.
	var unlocked: Dictionary[StringName, int] = {&"b4": 0, &"bk": 0, &"d6": 0, &"dk": 0}
	var listed: Array[StringName] = [&"bakery", &"dairy"]
	var stock: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 1)
	assert_bool(stock.list_skipped).is_false()
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "dk", "d6", "b1", "b2", "bk", "b4", "c1", "c2"]
	)
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])


func test_only_unlocked_capsule_items_are_stocked() -> void:
	# An id that names no capsule item (a base card, a staple, an unknown id) changes nothing.
	var unlocked: Dictionary[StringName, int] = {&"d5": 0, &"d1": 0, &"s1": 0, &"nope": 0}
	var stock: RunStock = RunStock.build(_deck(), _balance(), [], unlocked, 9)
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "d5", "b1", "b2", "c1", "c2"]
	)
	assert_array(_ids(RunStock.items(_aisle(_balance(), &"dairy"), unlocked))).is_equal(
		["d1", "d2", "d3", "d5"]
	)


func test_listable_aisles_within_the_budget_are_all_stocked_and_the_list_is_skipped() -> void:
	var balance: BalanceDefinition = _balance()
	# dairy 3 + bakery 2 = 5 listable items; frozen isn't listable and doesn't count.
	balance.aisle_stock_budget = 5
	var unlocked: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0}
	var listed: Array[StringName] = [&"bakery"]
	assert_bool(RunStock.needs_list(balance, unlocked)).is_false()
	var stock: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 10)
	assert_bool(stock.list_skipped).is_true()
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])


func test_over_the_budget_only_the_listed_aisles_are_stocked() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.needs_list(balance, unlocked)).is_true()
	var listed: Array[StringName] = [&"bakery"]
	var stock: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 0)
	assert_bool(stock.list_skipped).is_false()
	assert_array(stock.aisle_ids).is_equal([&"bakery"])
	assert_array(stock.card_ids()).is_equal(["s1", "s2", "s3", "b1", "b2", "c1", "c2"])
	# Unknown ids are ignored, and with no list only the staples and coupons are stocked.
	var none: Array[StringName] = [&"nope"]
	var bare: RunStock = RunStock.build(_deck(), balance, none, unlocked, 0)
	assert_array(bare.card_ids()).is_equal(["s1", "s2", "s3", "c1", "c2"])
	assert_array(bare.aisle_ids).is_empty()


func test_a_machine_opened_aisle_is_listable_once_it_holds_the_minimum() -> void:
	var balance: BalanceDefinition = _balance()
	var frozen: AisleDefinition = _aisle(balance, &"frozen")
	var three: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0}
	var four: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0, &"f4": 0}
	assert_bool(RunStock.is_listable(frozen, balance, three)).is_false()
	assert_bool(RunStock.is_listable(frozen, balance, four)).is_true()
	# Over the budget, a listed frozen aisle is stocked only once it is listable.
	balance.aisle_stock_budget = 4
	var listed: Array[StringName] = [&"frozen"]
	# Listing it early stocks nothing of it: its recent items still come as new arrivals.
	var recent: Dictionary[StringName, int] = {&"fk": 47, &"f2": 48, &"f3": 49}
	var early: RunStock = RunStock.build(_deck(), balance, listed, recent, 50)
	assert_array(early.aisle_ids).is_empty()
	assert_array(_ids(early.new_arrivals)).is_equal(["f3", "f2", "fk"])
	assert_array(early.card_ids()).is_equal(["s1", "s2", "s3", "fk", "f2", "f3", "c1", "c2"])
	var old: RunStock = RunStock.build(_deck(), balance, listed, three, 50)
	assert_array(old.card_ids()).is_equal(["s1", "s2", "s3", "c1", "c2"])
	var listable: RunStock = RunStock.build(_deck(), balance, listed, four, 50)
	assert_array(listable.aisle_ids).is_equal([&"frozen"])
	assert_array(listable.card_ids()).is_equal(
		["s1", "s2", "s3", "fk", "f2", "f3", "f4", "c1", "c2"]
	)


## A machine aisle reaching the minimum counts toward the budget: it can force the list, and
## when the list is skipped it is stocked whole like a base aisle.
func test_a_listable_machine_opened_aisle_counts_toward_the_budget() -> void:
	var balance: BalanceDefinition = _balance()
	# dairy 3 + bakery 2 + frozen 4 = 9.
	var unlocked: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0, &"f4": 0}
	balance.aisle_stock_budget = 8
	assert_bool(RunStock.needs_list(balance, unlocked)).is_true()
	balance.aisle_stock_budget = 9
	assert_bool(RunStock.needs_list(balance, unlocked)).is_false()
	var stock: RunStock = RunStock.build(_deck(), balance, [], unlocked, 1)
	assert_bool(stock.list_skipped).is_true()
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery", &"frozen"])
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "b1", "b2", "fk", "f2", "f3", "f4", "c1", "c2"]
	)
	# Stocked whole, its items are never new arrivals.
	assert_array(stock.new_arrivals).is_empty()


func test_an_aisle_with_base_cards_is_always_listable() -> void:
	var balance: BalanceDefinition = _balance()
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.is_listable(_aisle(balance, &"bakery"), balance, unlocked)).is_true()
	balance.aisle_listable_min = 99
	assert_bool(RunStock.is_listable(_aisle(balance, &"bakery"), balance, unlocked)).is_true()
	assert_array(_aisle_ids(RunStock.listable_aisles(balance, unlocked))).is_equal(
		[&"dairy", &"bakery"]
	)


func test_new_arrivals_come_from_the_last_runs_of_unstocked_aisles() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	# Run 10 is being built: runs 7, 8 and 9 are the window.
	var unlocked: Dictionary[StringName, int] = {
		&"dk": 6,  # too old
		&"bk": 7,  # bakery is listed: never a new arrival
		&"fk": 9,  # frozen isn't listable yet: rides the end-cap
		&"d5": 7,
	}
	var listed: Array[StringName] = [&"bakery"]
	var stock: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 10)
	assert_array(_ids(stock.new_arrivals)).is_equal(["fk", "d5"])
	# Stocked after the listed aisles in data order (dairy before frozen), not newest first.
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "b1", "b2", "bk", "d5", "fk", "c1", "c2"]
	)


func test_new_arrivals_are_capped_newest_first_and_later_draws_win_ties() -> void:
	var balance: BalanceDefinition = _balance()
	# Drawn in this order: fk and f2 after run 8, then d5, d6 and f3 after run 9.
	var unlocked: Dictionary[StringName, int] = {&"fk": 8, &"f2": 8, &"d5": 9, &"d6": 9, &"f3": 9}
	# Within the budget, dairy and bakery are stocked whole; frozen holds 3, not listable.
	var stock: RunStock = RunStock.build(_deck(), balance, [], unlocked, 10)
	assert_array(_ids(stock.new_arrivals)).is_equal(["f3", "f2", "fk"])
	balance.end_cap_max = 2
	stock = RunStock.build(_deck(), balance, [], unlocked, 10)
	assert_array(_ids(stock.new_arrivals)).is_equal(["f3", "f2"])
	assert_array(stock.card_ids().slice(-4)).is_equal(["f2", "f3", "c1", "c2"])


func test_a_capsule_is_playable_in_the_next_run_and_leaves_after_the_window() -> void:
	var balance: BalanceDefinition = _balance()
	var unlocked: Dictionary[StringName, int] = {&"fk": 4}
	for run_index: int in range(0, 10):
		var stock: RunStock = RunStock.build(_deck(), balance, [], unlocked, run_index)
		var expected: bool = run_index >= 5 and run_index <= 7
		(
			assert_bool(stock.cards.has(_fixture_card("fk")))
			. override_failure_message("run %d" % run_index)
			. is_equal(expected)
		)


func test_the_same_input_gives_the_same_stock() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {&"fk": 8, &"dk": 9, &"bk": 9, &"f2": 9}
	var listed: Array[StringName] = [&"dairy", &"bakery"]
	var first: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 10)
	var second: RunStock = RunStock.build(_deck(), balance, listed, unlocked, 10)
	assert_array(first.cards).is_equal(second.cards)
	assert_array(first.aisle_ids).is_equal(second.aisle_ids)
	assert_array(first.new_arrivals).is_equal(second.new_arrivals)
	assert_bool(first.list_skipped).is_equal(second.list_skipped)
	# Building reads its input and never changes it.
	assert_array(listed).is_equal([&"dairy", &"bakery"])
	assert_array(unlocked.keys()).is_equal([&"fk", &"dk", &"bk", &"f2"])


func test_a_card_is_stocked_once() -> void:
	var balance: BalanceDefinition = _balance()
	# A staple also in an aisle and in coupon_pool (a data test forbids both in data/).
	var s1: CardDefinition = _deck().cards[0]
	_aisle(balance, &"dairy").base_cards.append(s1)
	balance.coupon_pool.append(s1)
	var stock: RunStock = RunStock.starting(_deck(), balance)
	assert_int(stock.cards.count(s1)).is_equal(1)
	assert_int(stock.cards.find(s1)).is_equal(0)


func before_test() -> void:
	_cards.clear()


func _deck() -> DeckDefinition:
	var deck: DeckDefinition = DeckDefinition.new()
	deck.id = &"fixture"
	for id: String in ["s1", "s1", "s2", "c1", "s3", "s2"]:
		deck.cards.append(_fixture_card(id))
	return deck


func _balance() -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.aisles.append(_new_aisle(&"dairy", ["d1", "d2", "d3"], ["dk", "d5", "d6"]))
	balance.aisles.append(_new_aisle(&"bakery", ["b1", "b2"], ["bk", "b4"]))
	balance.aisles.append(_new_aisle(&"frozen", [], ["fk", "f2", "f3", "f4", "f5"]))
	for id: String in ["c1", "c2"]:
		balance.coupon_pool.append(_fixture_card(id))
	balance.run_aisle_picks = 2
	balance.aisle_stock_budget = 16
	balance.aisle_listable_min = 4
	balance.end_cap_max = 3
	balance.end_cap_window_runs = 3
	return balance


func _new_aisle(id: StringName, base: Array, capsules: Array) -> AisleDefinition:
	var aisle: AisleDefinition = AisleDefinition.new()
	aisle.id = id
	aisle.display_name = String(id)
	for card_id: String in base:
		aisle.base_cards.append(_fixture_card(card_id))
	for card_id: String in capsules:
		aisle.capsule_cards.append(_fixture_card(card_id))
	return aisle


func _fixture_card(id: String) -> CardDefinition:
	if not _cards.has(id):
		var card: CardDefinition = CardDefinition.new()
		card.id = StringName(id)
		card.kind = (
			CardDefinition.Kind.COUPON if id.begins_with("c") else CardDefinition.Kind.PRODUCT
		)
		_cards[id] = card
	return _cards[id]


static func _aisle(balance: BalanceDefinition, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in balance.aisles:
		if aisle.id == id:
			return aisle
	return null


static func _aisle_ids(aisles: Array[AisleDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for aisle: AisleDefinition in aisles:
		ids.append(aisle.id)
	return ids


static func _ids(cards: Array[CardDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return ids
