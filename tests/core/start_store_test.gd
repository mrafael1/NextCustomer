extends GdUnitTestSuite
## The opening board's page 1 "Counter" rules (full build plan 7.2, v1.07): what unlocks with
## completed aisles, the deal at once, the seed-fixed basket of each aisle (switching back deals
## the same pair), RESTOCK once a run, a regular swap and its undo, and that only the two starter
## aisles can change (never Staples, never to today's extra aisle). On the live data.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261105

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = Kit.balance()


## Below restock_min_completed completed aisles there's no RESTOCK; below
## pair_choice_min_completed no aisle choice; a new player has no swap. Each opens at its count.
func test_the_controls_unlock_with_completed_aisles() -> void:
	var restock_min: int = _balance.restock_min_completed
	var choice_min: int = _balance.pair_choice_min_completed
	assert_int(restock_min).is_equal(3)
	assert_int(choice_min).is_equal(6)
	for count: int in range(0, 7):
		var profile: ProfileState = Kit.profile(count)
		var run: RunState = Kit.locked(profile, SEED)
		assert_object(run).override_failure_message("completed %d" % count).is_not_null()
		assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.REVEALED)
		var restock: StringName = StartSetupRules.restock_block(run, profile, 1)
		if count < restock_min:
			assert_str(String(restock)).override_failure_message(str(count)).is_equal("locked")
		else:
			assert_str(String(restock)).override_failure_message(str(count)).is_empty()
		var options: Array[StringName] = StartSetupRules.aisle_options(run, profile, 1)
		if count < choice_min:
			assert_array(options).override_failure_message(str(count)).is_empty()
			assert_str(String(StartSetupRules.aisle_block(run, profile, 1, &"bakery"))).is_equal(
				"locked"
			)
		else:
			assert_array(options).override_failure_message(str(count)).is_not_empty()
		assert_int(StartSetupRules.swaps_left(run, profile)).is_equal(
			mini(count, run.starter.core_cards.size())
		)


## A new player's board is dealt at once: three baskets of two, nothing spent.
func test_a_new_player_is_dealt_six_basket_items_and_four_regulars() -> void:
	var profile: ProfileState = Kit.profile(0)
	var run: RunState = Kit.locked(profile, SEED)
	assert_int(run.start_setup.baskets.size()).is_equal(3)
	for basket: StartBasket in run.start_setup.baskets:
		assert_int(basket.cards.size()).is_equal(_balance.start_basket_size)
	assert_int(run.starter.core_cards.size()).is_equal(4)
	assert_int(run.start_setup.restock_basket).is_equal(-1)
	assert_str(String(run.start_setup.restock_source)).is_empty()


## Only the two starter (green) baskets change aisle, only to a completed aisle not stocked
## today: never Staples, never today's extra aisle, never the other basket's aisle.
func test_only_the_starter_aisles_can_change() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	var extra: StringName = setup.stock_aisles[2]
	assert_array(StartSetupRules.aisle_options(run, profile, 0)).is_empty()
	assert_str(String(StartSetupRules.aisle_block(run, profile, 0, extra))).is_equal("basket")
	assert_str(String(StartSetupRules.aisle_block(run, profile, 3, extra))).is_equal("basket")
	for basket: int in [1, 2]:
		var options: Array[StringName] = StartSetupRules.aisle_options(run, profile, basket)
		assert_int(options.size()).is_equal(_balance.aisles.size() - 3)
		for taken: StringName in setup.stock_aisles:
			assert_bool(options.has(taken)).is_false()
		assert_str(String(StartSetupRules.aisle_block(run, profile, basket, extra))).is_equal(
			"option"
		)
	# Today's extra aisle is never one the starter pair could hold, and never saved.
	assert_bool(setup.green_ids(_balance).has(extra)).is_false()


## Changing a basket's aisle deals the new aisle's seed-fixed pair; switching back deals the
## basket's first pair again (no free reroll), and the same seed deals the same pairs.
func test_switching_back_deals_the_same_pair() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	var first: StringName = setup.baskets[1].source
	var first_pair: Array[CardDefinition] = setup.baskets[1].cards.duplicate()
	var other: StringName = StartSetupRules.aisle_options(run, profile, 1)[0]
	assert_str(String(_change(run, profile, 1, other))).is_empty()
	assert_str(String(setup.baskets[1].source)).is_equal(String(other))
	assert_bool(setup.stock_aisles.has(other)).is_true()
	assert_bool(setup.stock_aisles.has(first)).is_false()
	assert_array(run.stock.aisle_ids).contains_exactly_in_any_order(setup.stock_aisles)
	var other_pair: Array[CardDefinition] = setup.baskets[1].cards.duplicate()
	assert_int(other_pair.size()).is_equal(_balance.start_basket_size)
	for card: CardDefinition in other_pair:
		assert_bool(Kit.of_source(card, other)).is_true()
	assert_array(profile.stock_pair).contains_exactly_in_any_order(setup.green_ids(_balance))
	assert_str(String(_change(run, profile, 1, first))).is_empty()
	assert_array(setup.baskets[1].cards).is_equal(first_pair)
	assert_str(String(_change(run, profile, 1, other))).is_empty()
	assert_array(setup.baskets[1].cards).is_equal(other_pair)
	# Another run on the same seed deals the same pair for that aisle.
	var again: RunState = Kit.locked(Kit.profile(6), SEED)
	assert_str(String(_change(again, Kit.profile(6), 1, other))).is_empty()
	assert_array(again.start_setup.baskets[1].cards).is_equal(other_pair)


## RESTOCK redraws one basket once a run: a second one, on any basket, is refused. The RESTOCKED
## mark follows the restocked aisle, and an aisle switched back keeps its restocked pair.
func test_restock_is_spent_once_and_follows_its_aisle() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	var first: Array[CardDefinition] = setup.baskets[1].cards.duplicate()
	assert_str(String(StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1)))).is_empty()
	var restocked: Array[CardDefinition] = setup.baskets[1].cards.duplicate()
	(
		assert_bool(restocked.any(func(card: CardDefinition) -> bool: return first.has(card)))
		. is_false()
	)
	assert_bool(setup.restocked(1)).is_true()
	assert_bool(setup.restocked(2)).is_false()
	for basket: int in 3:
		assert_str(String(StartSetupRules.restock_block(run, profile, basket))).is_equal("used")
	var source: StringName = setup.baskets[1].source
	var other: StringName = StartSetupRules.aisle_options(run, profile, 1)[0]
	assert_str(String(_change(run, profile, 1, other))).is_empty()
	assert_bool(setup.restocked(1)).is_false()
	assert_str(String(StartSetupRules.restock_block(run, profile, 1))).is_equal("used")
	assert_str(String(_change(run, profile, 1, source))).is_empty()
	assert_bool(setup.restocked(1)).is_true()
	assert_array(setup.baskets[1].cards).is_equal(restocked)


## A regular swap uses one of the run's swaps; the real undo (StartSetupRules.restore) puts the
## original back and gives the swap back, and a second undo is refused.
func test_a_swap_and_its_undo() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var left: int = StartSetupRules.swaps_left(run, profile)
	var original: CardDefinition = run.starter.core_cards[2]
	assert_bool(StartSetupRules.can_restore(run, 2)).is_false()
	assert_bool(StartSetupRules.restore(run, 2)).is_false()
	assert_bool(Kit.swap(run, profile, 2)).is_true()
	var swapped: CardDefinition = run.starter.core_cards[2]
	assert_object(swapped).is_not_equal(original)
	assert_int(StartSetupRules.swaps_left(run, profile)).is_equal(left - 1)
	assert_bool(StartSetupRules.can_restore(run, 2)).is_true()
	assert_bool(StartSetupRules.restore(run, 2)).is_true()
	assert_object(run.starter.core_cards[2]).is_equal(original)
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(0)
	assert_int(StartSetupRules.swaps_left(run, profile)).is_equal(left)
	assert_bool(StartSetupRules.can_restore(run, 2)).is_false()
	assert_bool(StartSetupRules.restore(run, 2)).is_false()


func _change(run: RunState, profile: ProfileState, basket: int, aisle_id: StringName) -> StringName:
	return StartSetupRules.change_aisle(
		run,
		profile,
		basket,
		aisle_id,
		EventLogService.derived_stream(run.run_seed, EventLogService.START_BASKET_STREAM % aisle_id)
	)
