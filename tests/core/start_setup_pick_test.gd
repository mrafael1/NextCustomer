extends GdUnitTestSuite
## The opening-time rules across profiles and stages (StartSetupRules, v1.32 "boosters"): no
## third booster for a veteran (PICK 2 OF 3 was removed in v1.42) and RESTOCK after page 2. On the
## live data, with the named derived streams the game uses; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## RESTOCK after page 2 opened (stage BUILD): allowed, the setup still in BUILD.
func test_restock_after_page_two_stays_in_build() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	assert_bool(StartSetupRules.mark_build(run)).is_true()
	var old_cards: Array[CardDefinition] = setup.boosters[0].cards.duplicate()
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_empty()
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_empty()
	assert_int(setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_bool(Kit.all_in(setup.boosters[0].cards, old_cards)).is_false()
	assert_bool(setup.boosters[0].opened).is_false()
	assert_array(run.start_offer.shared).is_equal(setup.shared())


## Every aisle completed (PICK 2 OF 3 once opened at 6, removed in v1.42): over many seeds the
## deal holds exactly dealt_aisle_count boosters, one per stocked aisle, in the stocked order.
func test_a_veteran_gets_only_the_stocked_aisles() -> void:
	var profile: ProfileState = Kit.profile(_balance.aisles.size())
	for seed_index: int in 20:
		var run: RunState = Kit.dealt(profile, SEED + seed_index * 7919)
		var setup: StartSetup = run.start_setup
		assert_int(setup.stock_aisles.size()).is_equal(_balance.dealt_aisle_count)
		assert_int(setup.boosters.size()).is_equal(setup.stock_aisles.size())
		for index: int in setup.boosters.size():
			assert_str(String(setup.boosters[index].aisle)).is_equal(
				String(setup.stock_aisles[index])
			)
			assert_bool(setup.is_active(index)).is_true()
