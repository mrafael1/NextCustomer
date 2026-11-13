extends GdUnitTestSuite
## The opening-time rules across picks and stages (StartSetupRules, v1.32 "boosters"): PICK 2 OF 3
## over many seeds (any kept pair leaves only packs that keep the copy rule and can be picked) and
## RESTOCK after page 2 and a pack pick. On the live data, with the named derived streams the game
## uses; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## PICK 2 OF 3 over many seeds: whichever pair is kept, every pack still on offer keeps the copy
## rule with the kept boosters and can be picked (no "copies" refusal), the good first pick stays
## offered, and every offered pack is one the profile may be offered.
func test_any_kept_pair_leaves_only_packs_that_can_be_picked() -> void:
	var profile: ProfileState = Kit.profile(6)
	var open: Array[StarterPackDefinition] = StartingDeck.open_packs(
		_recipe.starter_packs, _balance, profile.unlocked_items
	)
	var picked_runs: int = 0
	for seed_index: int in 40:
		var seed_value: int = SEED + seed_index * 7919
		for pair: Array in [[0, 1], [0, 2], [1, 2]]:
			var run: RunState = Kit.dealt(profile, seed_value)
			if run == null or not run.start_setup.picking():
				continue
			var first: StarterPackDefinition = run.start_offer.first_pick
			var picks: Array[int] = []
			picks.assign(pair)
			(
				assert_str(
					String(StartSetupRules.pick_boosters(run, profile, picks, Kit.pick_rng(run)))
				)
				. is_empty()
			)
			picked_runs += 1
			var shared: Array[CardDefinition] = run.start_setup.shared()
			if first != null:
				assert_bool(run.start_offer.packs.has(first)).is_true()
			for pack: StarterPackDefinition in run.start_offer.packs:
				var where: String = "seed %d pair %s pack %s" % [seed_value, pair, pack.id]
				assert_bool(open.has(pack)).override_failure_message(where).is_true()
				(
					assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, shared))
					. override_failure_message(where)
					. is_true()
				)
				(
					assert_str(String(StartSetupRules.pick_block(run, profile, pack)))
					. override_failure_message(where)
					. is_empty()
				)
	assert_int(picked_runs).is_greater(0)


## RESTOCK after page 2 opened (stage BUILD) and after a pack pick: allowed, the pick and the
## packs kept, the setup still in BUILD.
func test_restock_after_page_two_and_a_pick_keeps_the_pick() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var setup: StartSetup = run.start_setup
	assert_bool(StartSetupRules.mark_build(run)).is_true()
	var pack: StarterPackDefinition = run.start_offer.packs[1]
	assert_str(String(StartSetupRules.pick_block(run, profile, pack))).is_empty()
	setup.picked = pack.id
	var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	var old_cards: Array[CardDefinition] = setup.boosters[0].cards.duplicate()
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_empty()
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_empty()
	assert_int(setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_str(String(setup.picked)).is_equal(String(pack.id))
	assert_array(run.start_offer.packs).is_equal(packs)
	assert_bool(Kit.all_in(setup.boosters[0].cards, old_cards)).is_false()
	assert_bool(setup.boosters[0].opened).is_false()
	assert_array(run.start_offer.shared).is_equal(setup.shared())


## An extra booster that would come up empty (every product already at copy_max, here forced by
## a copy_max of 0 on the run's own recipe copy) is left out of the deal: two boosters, no PICK 2
## OF 3 offered with an empty booster.
func test_an_empty_extra_booster_is_left_out() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.run(profile, SEED)
	run.starter.copy_max = 0
	assert_str(String(Kit.deal(run, profile))).is_empty()
	var setup: StartSetup = run.start_setup
	assert_int(setup.boosters.size()).is_equal(_balance.dealt_aisle_count)
	assert_bool(setup.picking()).is_false()
	for booster: StartBooster in setup.boosters:
		assert_bool(setup.stock_aisles.has(booster.aisle)).is_true()
