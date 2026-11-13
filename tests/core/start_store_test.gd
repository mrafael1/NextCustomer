extends GdUnitTestSuite
## The opening board's page 1 YOUR STORE rules (full build plan 7.2, v1.32 "boosters"): what
## unlocks with completed aisles (RESTOCK at 3, PICK 2 OF 3 at 6, one swap per aisle), the deal at
## once (two sealed boosters of three, four regulars), RESTOCK once a run, and a regular swap and
## its undo. On the live data.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261105

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = Kit.balance()


## Below restock_min_completed completed aisles there's no RESTOCK; below
## pair_choice_min_completed no third booster; a new player has no swap. Each opens at its count.
func test_the_controls_unlock_with_completed_aisles() -> void:
	var restock_min: int = _balance.restock_min_completed
	var choice_min: int = _balance.pair_choice_min_completed
	assert_int(restock_min).is_equal(3)
	assert_int(choice_min).is_equal(6)
	assert_int(_balance.start_booster_choice_count).is_equal(3)
	for count: int in range(0, 7):
		var profile: ProfileState = Kit.profile(count)
		var dealt: RunState = Kit.dealt(profile, SEED)
		assert_object(dealt).override_failure_message("completed %d" % count).is_not_null()
		var boosters: int = 3 if count >= choice_min else 2
		assert_int(dealt.start_setup.boosters.size()).is_equal(boosters)
		assert_bool(dealt.start_setup.picking()).is_equal(count >= choice_min)
		var run: RunState = Kit.locked(profile, SEED)
		assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.DEALT)
		var restock: StringName = StartSetupRules.restock_block(run, profile, 1)
		if count < restock_min:
			assert_str(String(restock)).override_failure_message(str(count)).is_equal("locked")
		else:
			assert_str(String(restock)).override_failure_message(str(count)).is_empty()
		assert_bool(StartSetupRules.pick_mode(_balance, profile)).is_equal(count >= choice_min)
		assert_int(StartSetupRules.swaps_left(run, profile)).is_equal(
			mini(count, run.starter.core_cards.size())
		)


## A new player's board is dealt at once: two sealed boosters of three, four regulars, nothing
## spent.
func test_a_new_player_is_dealt_two_boosters_of_three_and_four_regulars() -> void:
	var profile: ProfileState = Kit.profile(0)
	var run: RunState = Kit.dealt(profile, SEED)
	assert_int(run.start_setup.boosters.size()).is_equal(2)
	for booster: StartBooster in run.start_setup.boosters:
		assert_int(booster.cards.size()).is_equal(_balance.start_booster_size)
		assert_bool(booster.opened).is_false()
		assert_bool(booster.restocked).is_false()
	assert_int(run.starter.core_cards.size()).is_equal(4)
	assert_int(run.start_setup.restock_booster()).is_equal(-1)
	assert_bool(run.start_setup.packs_redrawn).is_false()
	assert_bool(run.start_setup.pins_confirmed).is_false()


## RESTOCK deals one booster again once a run: a second one, on any booster, is refused; the
## RESTOCKED stamp stays on its booster.
func test_restock_is_spent_once() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	assert_str(String(StartSetupRules.restock(run, profile, 1, Kit.restock_rng(run, 1)))).is_empty()
	assert_bool(setup.boosters[1].restocked).is_true()
	assert_bool(setup.boosters[0].restocked).is_false()
	StartSetupRules.open_booster(run, 1)
	for index: int in 2:
		assert_str(String(StartSetupRules.restock_block(run, profile, index))).is_equal("used")


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
