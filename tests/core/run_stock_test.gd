extends GdUnitTestSuite
## The run's stock (full build plan 7.2), on fixture aisles built here so tuning data/ never
## changes these tests: data order, the unlocked filter, the budget rule, the listable minimum,
## no capsule item from an aisle the run doesn't stock (v1.32), and the same input giving the same
## stock.
##
## Fixture: staples s1, s2, s3 (the balance's list also holds coupon c1 and repeats); coupon_pool
## c1, c2. Aisles in data order: dairy (base d1, d2, d3; capsules dk, d5, d6), bakery (base b1,
## b2; capsules bk, b4) and frozen, opened by its machine (capsules fk, f2, f3, f4, f5).

## Fixture cards by id, created once per test so every lookup returns the same definition.
var _cards: Dictionary[String, CardDefinition] = {}


func test_staples_are_the_balance_products_once_each_in_data_order() -> void:
	assert_array(_ids(RunStock.staples(_balance()))).is_equal(["s1", "s2", "s3"])


func test_a_new_profile_stocks_staples_base_aisles_then_coupons() -> void:
	var stock: RunStock = RunStock.starting(_balance())
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "b1", "b2", "c1", "c2"]
	)
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])
	assert_bool(stock.list_skipped).is_true()


func test_stock_order_is_data_order_never_list_or_unlock_order() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 5
	# Unlocked in reverse data order, listed in reverse data order.
	var unlocked: Dictionary[StringName, int] = {&"b4": 0, &"bk": 0, &"d6": 0, &"dk": 0}
	var listed: Array[StringName] = [&"bakery", &"dairy"]
	var stock: RunStock = RunStock.build(balance, listed, unlocked)
	assert_bool(stock.list_skipped).is_false()
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "dk", "d6", "b1", "b2", "bk", "b4", "c1", "c2"]
	)
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])


func test_only_unlocked_capsule_items_are_stocked() -> void:
	# An id that names no capsule item (a base card, a staple, an unknown id) changes nothing.
	var unlocked: Dictionary[StringName, int] = {&"d5": 0, &"d1": 0, &"s1": 0, &"nope": 0}
	var stock: RunStock = RunStock.build(_balance(), [], unlocked)
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
	var stock: RunStock = RunStock.build(balance, listed, unlocked)
	assert_bool(stock.list_skipped).is_true()
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery"])


func test_over_the_budget_only_the_listed_aisles_are_stocked() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.needs_list(balance, unlocked)).is_true()
	var listed: Array[StringName] = [&"bakery"]
	var stock: RunStock = RunStock.build(balance, listed, unlocked)
	assert_bool(stock.list_skipped).is_false()
	assert_array(stock.aisle_ids).is_equal([&"bakery"])
	assert_array(stock.card_ids()).is_equal(["s1", "s2", "s3", "b1", "b2", "c1", "c2"])
	# Unknown ids are ignored, and with no list only the staples and coupons are stocked.
	var none: Array[StringName] = [&"nope"]
	var bare: RunStock = RunStock.build(balance, none, unlocked)
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
	# Listing it early stocks nothing of it, not even items unlocked just before (v1.32).
	var recent: Dictionary[StringName, int] = {&"fk": 47, &"f2": 48, &"f3": 49}
	var early: RunStock = RunStock.build(balance, listed, recent)
	assert_array(early.aisle_ids).is_empty()
	assert_array(early.card_ids()).is_equal(["s1", "s2", "s3", "c1", "c2"])
	var old: RunStock = RunStock.build(balance, listed, three)
	assert_array(old.card_ids()).is_equal(["s1", "s2", "s3", "c1", "c2"])
	var listable: RunStock = RunStock.build(balance, listed, four)
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
	var stock: RunStock = RunStock.build(balance, [], unlocked)
	assert_bool(stock.list_skipped).is_true()
	assert_array(stock.aisle_ids).is_equal([&"dairy", &"bakery", &"frozen"])
	assert_array(stock.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "b1", "b2", "fk", "f2", "f3", "f4", "c1", "c2"]
	)


func test_an_aisle_with_base_cards_is_always_listable() -> void:
	var balance: BalanceDefinition = _balance()
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.is_listable(_aisle(balance, &"bakery"), balance, unlocked)).is_true()
	balance.aisle_listable_min = 99
	assert_bool(RunStock.is_listable(_aisle(balance, &"bakery"), balance, unlocked)).is_true()
	assert_array(_aisle_ids(RunStock.listable_aisles(balance, unlocked))).is_equal(
		[&"dairy", &"bakery"]
	)


## v1.32 (the user, 2026-11-13): a capsule item is in a run only when the run stocks its aisle.
## No item of an unstocked aisle is stocked, however recently it was unlocked (the end-cap's new
## arrivals are gone), and every stocked aisle brings all its unlocked items, old or new.
func test_capsule_items_of_unstocked_aisles_are_never_stocked() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {
		&"dk": 6,
		&"bk": 7,
		&"fk": 9,  # frozen isn't listable yet
		&"d5": 9,  # unlocked after the run just before
	}
	var listed: Array[StringName] = [&"bakery"]
	var stock: RunStock = RunStock.build(balance, listed, unlocked)
	assert_array(stock.card_ids()).is_equal(["s1", "s2", "s3", "b1", "b2", "bk", "c1", "c2"])
	for id: String in ["dk", "d5", "fk"]:
		assert_bool(stock.cards.has(_fixture_card(id))).override_failure_message(id).is_false()
	# Listed, dairy brings both its items, the old and the new.
	var dairy: Array[StringName] = [&"dairy"]
	var with_dairy: RunStock = RunStock.build(balance, dairy, unlocked)
	assert_array(with_dairy.card_ids()).is_equal(
		["s1", "s2", "s3", "d1", "d2", "d3", "dk", "d5", "c1", "c2"]
	)


func test_the_same_input_gives_the_same_stock() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {&"fk": 8, &"dk": 9, &"bk": 9, &"f2": 9}
	var listed: Array[StringName] = [&"dairy", &"bakery"]
	var first: RunStock = RunStock.build(balance, listed, unlocked)
	var second: RunStock = RunStock.build(balance, listed, unlocked)
	assert_array(first.cards).is_equal(second.cards)
	assert_array(first.aisle_ids).is_equal(second.aisle_ids)
	assert_bool(first.list_skipped).is_equal(second.list_skipped)
	# Building reads its input and never changes it.
	assert_array(listed).is_equal([&"dairy", &"bakery"])
	assert_array(unlocked.keys()).is_equal([&"fk", &"dk", &"bk", &"f2"])


func test_a_card_is_stocked_once() -> void:
	var balance: BalanceDefinition = _balance()
	# A staple also in an aisle and in coupon_pool (a data test forbids both in data/).
	var s1: CardDefinition = _fixture_card("s1")
	_aisle(balance, &"dairy").base_cards.append(s1)
	balance.coupon_pool.append(s1)
	var stock: RunStock = RunStock.starting(balance)
	assert_int(stock.cards.count(s1)).is_equal(1)
	assert_int(stock.cards.find(s1)).is_equal(0)


## The random list until #65 (#63): run_aisle_picks distinct listable aisles in data order, the
## same for the same stream; all of them when there are fewer; none when no list is needed.
func test_the_surprise_list_picks_listable_aisles_from_its_stream() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var unlocked: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0, &"f4": 0}
	var order: Array[StringName] = [&"dairy", &"bakery", &"frozen"]
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in range(40):
		var listed: Array[StringName] = RunStock.surprise_list(balance, unlocked, _rng(seed_value))
		assert_int(listed.size()).is_equal(2)
		assert_bool(listed[0] != listed[1]).is_true()
		assert_bool(order.find(listed[0]) < order.find(listed[1])).is_true()
		assert_array(RunStock.surprise_list(balance, unlocked, _rng(seed_value))).is_equal(listed)
		seen["+".join(listed)] = true
	# Every list of two comes up.
	assert_int(seen.size()).is_equal(3)
	balance.run_aisle_picks = 5
	assert_array(RunStock.surprise_list(balance, unlocked, _rng(1))).is_equal(order)
	var none: Dictionary[StringName, int] = {}
	balance.aisle_stock_budget = 16
	assert_array(RunStock.surprise_list(balance, none, _rng(1))).is_empty()


## The list's default (ready for #65), as the simulator's chained player keeps it.
func test_the_prefill_list() -> void:
	var balance: BalanceDefinition = _balance()
	balance.aisle_stock_budget = 4
	var none: Array[StringName] = []
	var base: Dictionary[StringName, int] = {}
	# First list, nothing newly listable: the aisles with the most items.
	assert_array(RunStock.prefill_list(balance, base, none, none)).is_equal([&"dairy", &"bakery"])
	# A base aisle passed as newly listable doesn't join a first list.
	var dairy_new: Array[StringName] = [&"dairy"]
	balance.run_aisle_picks = 1
	var tied: Dictionary[StringName, int] = {&"bk": 0}
	assert_array(RunStock.prefill_list(balance, tied, none, none)).is_equal([&"dairy"])
	tied[&"b4"] = 0
	assert_array(RunStock.prefill_list(balance, tied, none, dairy_new)).is_equal([&"bakery"])
	balance.run_aisle_picks = 2
	# A machine-opened aisle that just became listable joins the first list.
	var opened: Dictionary[StringName, int] = {&"fk": 0, &"f2": 0, &"f3": 0, &"f4": 0}
	var frozen: Array[StringName] = RunStock.machine_opened_listable(balance, opened)
	assert_array(frozen).is_equal([&"frozen"])
	assert_array(RunStock.prefill_list(balance, opened, none, frozen)).is_equal(
		[&"dairy", &"frozen"]
	)
	# The last list is kept.
	var last: Array[StringName] = [&"bakery", &"frozen"]
	assert_array(RunStock.prefill_list(balance, opened, last, none)).is_equal(last)
	# A newly listable aisle replaces the listed one with the fewest items, the later on a tie.
	var listed: Array[StringName] = [&"dairy", &"bakery"]
	assert_array(RunStock.prefill_list(balance, opened, listed, frozen)).is_equal(
		[&"dairy", &"frozen"]
	)
	opened[&"bk"] = 0
	assert_array(RunStock.prefill_list(balance, opened, listed, frozen)).is_equal(
		[&"dairy", &"frozen"]
	)
	# No list needed: none.
	balance.aisle_stock_budget = 16
	assert_array(RunStock.prefill_list(balance, base, listed, none)).is_empty()
	assert_array(RunStock.machine_opened_listable(balance, base)).is_empty()


## A capsule drawn on the results or on the title (whatever its run index) is in every later
## stock that holds its aisle and in none that doesn't: a frozen item (frozen not listable yet)
## never, a dairy item only while dairy is stocked.
func test_a_drawn_capsule_is_stocked_only_with_its_aisle() -> void:
	var balance: BalanceDefinition = _balance()
	var frozen: AisleDefinition = _aisle(balance, &"frozen")
	var results: ProfileState = ProfileState.new()
	results.coins = 2
	results.run_count = 2
	results.draw_capsule(frozen, 1, results.capsule_run_index(false), _rng(0))
	results.draw_capsule(_aisle(balance, &"dairy"), 1, results.capsule_run_index(false), _rng(0))
	var title: ProfileState = ProfileState.new()
	title.coins = 1
	title.run_count = 2
	title.draw_capsule(frozen, 1, title.capsule_run_index(true), _rng(0))
	var fk: CardDefinition = _fixture_card("fk")
	var dk: CardDefinition = _fixture_card("dk")
	var stock: RunStock = RunStock.build(balance, [], results.unlocked_items)
	assert_bool(stock.cards.has(fk)).is_false()
	assert_bool(stock.cards.has(dk)).is_true()
	assert_bool(RunStock.build(balance, [], title.unlocked_items).cards.has(fk)).is_false()
	balance.aisle_stock_budget = 4
	var bakery: Array[StringName] = [&"bakery"]
	assert_bool(RunStock.build(balance, bakery, results.unlocked_items).cards.has(dk)).is_false()


## The live data: after the 3rd base-aisle capsule the stock needs a list, and the surprise list
## stocks 2 aisles.
func test_the_third_base_aisle_capsule_needs_a_list_of_two() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var unlocked: Dictionary[StringName, int] = {&"cream": 0, &"sugar_cubes": 1}
	assert_bool(RunStock.needs_list(balance, unlocked)).is_false()
	unlocked[&"egg_timer"] = 2
	assert_bool(RunStock.needs_list(balance, unlocked)).is_true()
	var listed: Array[StringName] = RunStock.surprise_list(balance, unlocked, _rng(3))
	assert_int(listed.size()).is_equal(2)
	var stock: RunStock = RunStock.build(balance, listed, unlocked)
	assert_bool(stock.list_skipped).is_false()
	assert_array(stock.aisle_ids).is_equal(listed)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, EventLogService.SURPRISE_LIST_STREAM)


func before_test() -> void:
	_cards.clear()


func _balance() -> BalanceDefinition:
	var balance: BalanceDefinition = BalanceDefinition.new()
	balance.aisles.append(_new_aisle(&"dairy", ["d1", "d2", "d3"], ["dk", "d5", "d6"]))
	balance.aisles.append(_new_aisle(&"bakery", ["b1", "b2"], ["bk", "b4"]))
	balance.aisles.append(_new_aisle(&"frozen", [], ["fk", "f2", "f3", "f4", "f5"]))
	for id: String in ["s1", "s1", "s2", "c1", "s3", "s2"]:
		balance.staples.append(_fixture_card(id))
	for id: String in ["c1", "c2"]:
		balance.coupon_pool.append(_fixture_card(id))
	balance.run_aisle_picks = 2
	balance.aisle_stock_budget = 16
	balance.aisle_listable_min = 4
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
