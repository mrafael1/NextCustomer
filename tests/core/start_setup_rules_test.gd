extends GdUnitTestSuite
## The opening-time rules (StartSetupRules, StartSetup, StartBoosterDraw, full build plan 7.2,
## v1.32 "boosters"): completed aisles, today's seeded aisles, the deal's sealed aisle boosters of
## 3 (2 COMMON + 1 hit card, RARE 50%, never GOLDEN) and their fair-deal check, opening, PICK 2 OF
## 3, the whole-booster RESTOCK, the sealed swap gate, the BADGE PINS gate, NEW PACKS, the stages
## and the cart lines. On the live data, with the named derived streams the game uses; nothing
## here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const RECIPE := Kit.RECIPE
const BALANCE := Kit.BALANCE
const SEED := 20261104
## Data order: cold_cases, pantry, household (base aisles), fruit_and_veg, bakery, snacks
## (machine aisles, listable at aisle_listable_min items).
const MACHINE_AISLE := 3
const REPEAT := preload("res://data/cards/repeat.tres")

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = load(BALANCE)
	_recipe = load(RECIPE)


func test_an_aisle_is_completed_only_when_every_item_is_collected() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_array(StartSetupRules.completed(_balance, profile)).is_empty()
	var cold: AisleDefinition = _balance.aisles[0]
	profile.unlocked_items[cold.capsule_cards[0].id] = 0
	assert_array(StartSetupRules.completed(_balance, profile)).is_empty()
	profile.unlocked_items[cold.capsule_cards[1].id] = 0
	assert_array(StartSetupRules.completed(_balance, profile)).is_equal([cold])


func test_a_machine_aisle_is_stocked_only_from_four_items() -> void:
	var aisle: AisleDefinition = _balance.aisles[MACHINE_AISLE]
	assert_int(_balance.aisle_listable_min).is_equal(4)
	var profile: ProfileState = ProfileState.new()
	for card: CardDefinition in aisle.capsule_cards.slice(0, 3):
		profile.unlocked_items[card.id] = 0
	for seed_value: int in range(SEED, SEED + 20):
		assert_bool(Kit.suggest(profile, seed_value).has(aisle.id)).is_false()
	profile.unlocked_items[aisle.capsule_cards[3].id] = 0
	assert_bool(RunStock.is_listable(aisle, _balance, profile.unlocked_items)).is_true()
	var seen: bool = false
	for seed_value: int in range(SEED, SEED + 20):
		seen = seen or Kit.suggest(profile, seed_value).has(aisle.id)
	assert_bool(seen).is_true()


## Run 1: two of the three base aisles (dealt_aisle_count, no third), seeded by the run seed
## (same seed, same suggestion), in data order.
func test_the_suggested_aisles_are_seeded() -> void:
	var profile: ProfileState = ProfileState.new()
	var drawn: Array[StringName] = Kit.suggest(profile, SEED)
	assert_int(drawn.size()).is_equal(_balance.dealt_aisle_count)
	assert_int(drawn.size()).is_equal(2)
	for id: StringName in drawn:
		assert_bool([&"cold_cases", &"pantry", &"household"].has(id)).is_true()
	assert_array(Kit.suggest(profile, SEED)).is_equal(drawn)
	assert_array(drawn).is_equal(StartSetupRules.ordered_pair(_balance, drawn))
	var orders: Dictionary = {}
	for seed_value: int in range(SEED, SEED + 30):
		orders[str(Kit.suggest(profile, seed_value))] = true
	assert_int(orders.size()).is_greater(1)


## A new run is in SELECT: the suggestion's stock, nothing dealt, no packs, nothing to pick, and
## the run's own RNG untouched.
func test_a_new_run_waits_in_select_with_nothing_dealt() -> void:
	var run: RunState = Kit.run(Kit.profile(0), SEED)
	var setup: StartSetup = run.start_setup
	assert_int(setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_int(run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(run.start_offer.packs).is_empty()
	assert_array(run.start_offer.shared).is_empty()
	assert_object(run.start_offer.default_pack()).is_null()
	assert_array(setup.boosters).is_empty()
	assert_array(setup.shared()).is_empty()
	assert_str(String(setup.picked)).is_empty()
	assert_array(run.starter.cards).is_equal(_recipe.core_cards)
	assert_array(run.stock.aisle_ids).contains_exactly_in_any_order(setup.stock_aisles)
	var plain: RunState = RunState.new(SEED, run.starter, _balance, run.stock, run.start_offer)
	assert_int(run.rng_state).is_equal(plain.rng_state)
	assert_bool(run.take_pack(_recipe.first_pick_pack)).is_false()


## The deal: one sealed booster per stocked aisle, each start_booster_size distinct products of its
## own aisle only (no staples draw), its last place the hit card
## (BIG at most there, never GOLDEN); the offer of 3 packs with the good first pick suggested and
## nothing picked; the cart keeps the recipe's random_count dealt cards; the same seed deals the
## same; the run's own RNG is never used.
func test_the_deal_gives_two_sealed_boosters_of_three_from_their_aisles() -> void:
	assert_int(_balance.start_booster_size * _balance.dealt_aisle_count).is_equal(
		_recipe.random_count
	)
	for completed: int in [0, 3]:
		for seed_value: int in range(SEED, SEED + 4):
			var profile: ProfileState = Kit.profile(completed)
			var run: RunState = Kit.dealt(profile, seed_value)
			var setup: StartSetup = run.start_setup
			assert_int(setup.stage).is_equal(StartSetup.Stage.DEALT)
			assert_bool(setup.picking()).is_false()
			assert_int(setup.boosters.size()).is_equal(_balance.dealt_aisle_count)
			for index: int in setup.boosters.size():
				var booster: StartBooster = setup.boosters[index]
				assert_str(String(booster.aisle)).is_equal(String(setup.stock_aisles[index]))
				_assert_booster(booster)
				assert_int(booster.cards.size()).is_equal(_balance.start_booster_size)
				assert_int(booster.hits).is_equal(_balance.start_booster_hit_slots)
				assert_bool(booster.opened).is_false()
			assert_array(run.start_offer.shared).is_equal(setup.shared())
			assert_int(run.start_offer.packs.size()).is_equal(_recipe.packs_offered)
			assert_str(String(setup.picked)).is_empty()
			if completed == 0:
				assert_object(run.start_offer.first_pick).is_equal(_recipe.first_pick_pack)
			assert_int(run.start_offer.deals).is_between(1, _recipe.fair_deal_redeals + 1)
			assert_int(run.starter.cards.size()).is_equal(
				_recipe.core_cards.size() + _recipe.random_count
			)
			for pack: StarterPackDefinition in run.start_offer.packs:
				(
					assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, setup.shared()))
					. is_true()
				)
			var again: RunState = Kit.dealt(Kit.profile(completed), seed_value)
			assert_dict(again.start_setup.to_dictionary()).is_equal(setup.to_dictionary())
			assert_array(again.start_offer.packs).is_equal(run.start_offer.packs)
			var plain: RunState = RunState.new(
				seed_value, run.starter, _balance, run.stock, run.start_offer
			)
			assert_int(run.rng_state).is_equal(plain.rng_state)


## Missing a dealt aisle's stream refuses the deal, changing nothing; a dealt setup can't be
## dealt again.
func test_the_deal_needs_every_stream_and_happens_once() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.run(profile, SEED)
	var none: Dictionary[StringName, RandomNumberGenerator] = {}
	var refused: StringName = StartSetupRules.deal(
		run, profile, Kit.deck_rng(run), none, Kit.extra_rng(run)
	)
	assert_str(String(refused)).is_equal("streams")
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_str(String(Kit.deal(run, profile))).is_empty()
	assert_str(String(Kit.deal(run, profile))).is_equal("stage")


## A profile that has won gets no good first pick and nothing picked.
func test_the_deal_without_the_first_pick_after_a_win() -> void:
	var profile: ProfileState = Kit.profile(0)
	profile.stats[ProfileState.RUNS_WON] = 1
	var run: RunState = Kit.dealt(profile, SEED)
	assert_object(run.start_offer.first_pick).is_null()
	assert_str(String(run.start_setup.picked)).is_empty()


## Opening only reveals: the cards stay; a booster opens once; nothing opens before the deal. Swaps
## wait until every booster is open ("sealed", N2: a sealed card must never count).
func test_opening_reveals_and_swaps_wait_for_every_booster() -> void:
	var profile: ProfileState = Kit.profile(3)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_str(String(StartSetupRules.open_block(waiting, 0))).is_equal("stage")
	var run: RunState = Kit.dealt(profile, SEED)
	var cards: Array[CardDefinition] = run.start_setup.shared()
	var stocked: StringName = StartSwapBoosters.swap_aisles(run)[0]
	var card: CardDefinition = StartSwapBoosters.swap_pool(run, profile, stocked)[0]
	assert_str(String(StartSetupRules.swap_block(run, profile, 3, card))).is_equal("sealed")
	assert_str(String(StartSwapBoosters.open_swap_block(run, profile, stocked))).is_equal("none")
	assert_str(String(StartSetupRules.open_block(run, 5))).is_equal("none")
	assert_str(String(StartSetupRules.open_booster(run, 0))).is_empty()
	assert_bool(run.start_setup.boosters[0].opened).is_true()
	assert_str(String(StartSetupRules.open_booster(run, 0))).is_equal("opened")
	assert_str(String(StartSetupRules.swap_block(run, profile, 3, card))).is_equal("sealed")
	assert_str(String(StartSetupRules.open_booster(run, 1))).is_empty()
	assert_bool(run.start_setup.all_open()).is_true()
	assert_array(run.start_setup.shared()).is_equal(cards)
	(
		assert_array(
			StartSwapBoosters.swap_offer(run, profile, stocked, Kit.regulars_rng(run, stocked))
		)
		. is_not_empty()
	)
	assert_object(Kit.option(run, profile, 3)).is_not_null()


## PICK 2 OF 3 (6 completed aisles): a third sealed booster of a completed aisle not stocked
## today; while picking, the seeded pair stands for today's stock and nothing opens, restocks,
## moves to page 2 or redraws packs. Any pair keeps the copy rule with every pack. Picking makes
## the other SOLD OUT, the stocked aisles the picked pair's, rebuilds the stock and fits the
## packs to it. The same seed picks the same.
func test_pick_two_of_three_keeps_a_pair_and_sells_out_the_other() -> void:
	var profile: ProfileState = Kit.profile(6)
	var run: RunState = Kit.dealt(profile, SEED)
	var setup: StartSetup = run.start_setup
	assert_int(setup.boosters.size()).is_equal(_balance.start_booster_choice_count)
	assert_bool(setup.picking()).is_true()
	var extra: StartBooster = setup.boosters[2]
	assert_bool(setup.stock_aisles.has(extra.aisle)).is_false()
	var extras: Array[StringName] = StartSetupRules.extra_aisles(
		_balance, profile, setup.stock_aisles
	)
	assert_bool(extras.has(extra.aisle)).is_true()
	_assert_booster(extra)
	assert_array(setup.shared()).is_equal(setup.boosters[0].cards + setup.boosters[1].cards)
	assert_array(run.start_offer.shared).is_equal(setup.shared())
	for pair: Array in [[0, 1], [0, 2], [1, 2]]:
		var cards: Array[CardDefinition] = []
		for index: int in pair:
			cards.append_array(setup.boosters[index].cards)
		for pack: StarterPackDefinition in run.start_offer.packs:
			assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, cards)).is_true()
	assert_str(String(StartSetupRules.open_block(run, 0))).is_equal("picking")
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("sealed")
	assert_str(String(StartSetupRules.new_packs_block(run, profile))).is_equal("picking")
	var pack: StarterPackDefinition = run.start_offer.packs[0]
	assert_str(String(StartSetupRules.pick_block(run, profile, pack))).is_equal("picking")
	assert_bool(StartSetupRules.mark_build(run)).is_false()
	var short: Array[int] = [0]
	var twice: Array[int] = [1, 1]
	var outside: Array[int] = [0, 3]
	for bad: Array[int] in [short, twice, outside]:
		assert_str(String(StartSetupRules.pick_boosters_block(run, bad))).is_equal("count")
	var picks: Array[int] = [0, 2]
	var kept: Array[StringName] = [setup.boosters[0].aisle, extra.aisle]
	var picked: StringName = StartSetupRules.pick_boosters(run, profile, picks, Kit.pick_rng(run))
	assert_str(String(picked)).is_empty()
	assert_bool(setup.picking()).is_false()
	assert_bool(setup.boosters[1].sold_out).is_true()
	assert_array(setup.stock_aisles).is_equal(StartSetupRules.ordered_pair(_balance, kept))
	assert_array(run.stock.aisle_ids).contains_exactly_in_any_order(setup.stock_aisles)
	assert_array(setup.shared()).is_equal(setup.boosters[0].cards + extra.cards)
	assert_array(run.start_offer.shared).is_equal(setup.shared())
	assert_array(run.starter.cards.slice(_recipe.core_cards.size())).is_equal(setup.shared())
	assert_int(run.start_offer.packs.size()).is_equal(_recipe.packs_offered)
	assert_str(String(StartSetupRules.pick_boosters_block(run, picks))).is_equal("none")
	assert_str(String(StartSetupRules.open_block(run, 1))).is_equal("sold_out")
	assert_str(String(StartSetupRules.open_booster(run, 2))).is_empty()
	var again: RunState = Kit.dealt(Kit.profile(6), SEED)
	StartSetupRules.pick_boosters(again, Kit.profile(6), picks, Kit.pick_rng(again))
	assert_array(again.start_offer.packs).is_equal(run.start_offer.packs)
	# Below 6 completed aisles: no third booster.
	assert_int(Kit.dealt(Kit.profile(5), SEED).start_setup.boosters.size()).is_equal(2)


## RESTOCK (3 completed): only an opened booster; a fresh booster of the same aisle (a new hit
## too) differing by at least one card, sealed again and stamped; the other booster, the packs and
## the pick unchanged; spent once; same seed, same restock.
func test_restock_deals_one_opened_booster_again_once() -> void:
	for index: int in 2:
		var profile: ProfileState = Kit.profile(3)
		var run: RunState = Kit.dealt(profile, SEED)
		var setup: StartSetup = run.start_setup
		assert_str(String(StartSetupRules.restock_block(run, profile, index))).is_equal("sealed")
		Kit.open_all(run)
		var kept: StartSetup = setup.copy()
		var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
		assert_str(String(StartSetupRules.restock_block(run, profile, index))).is_empty()
		(
			assert_str(
				String(StartSetupRules.restock(run, profile, index, Kit.restock_rng(run, index)))
			)
			. is_empty()
		)
		var booster: StartBooster = setup.boosters[index]
		assert_int(setup.restock_booster()).is_equal(index)
		assert_bool(booster.restocked).is_true()
		assert_bool(booster.opened).is_false()
		assert_str(String(booster.aisle)).is_equal(String(kept.boosters[index].aisle))
		_assert_booster(booster)
		assert_bool(Kit.all_in(booster.cards, kept.boosters[index].cards)).is_false()
		var other: int = 1 - index
		assert_array(setup.boosters[other].cards).is_equal(kept.boosters[other].cards)
		assert_array(run.start_offer.packs).is_equal(packs)
		assert_str(String(setup.picked)).is_equal(String(kept.picked))
		assert_array(run.start_offer.shared).is_equal(setup.shared())
		assert_array(run.starter.cards.slice(_recipe.core_cards.size())).is_equal(setup.shared())
		for each: int in 2:
			assert_str(String(StartSetupRules.restock_block(run, profile, each))).is_equal("used")
		var pool: Array[CardDefinition] = StartSwapBoosters.swap_pool(
			run, profile, setup.boosters[0].aisle
		)
		assert_str(String(StartSetupRules.swap_block(run, profile, 0, pool[0]))).is_equal("sealed")
		var again: RunState = Kit.locked(Kit.profile(3), SEED)
		StartSetupRules.restock(again, Kit.profile(3), index, Kit.restock_rng(again, index))
		assert_array(again.start_setup.boosters[index].cards).is_equal(booster.cards)


func test_restock_is_locked_before_the_deal_and_below_three_completed() -> void:
	var profile: ProfileState = Kit.profile(2)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_str(String(StartSetupRules.restock_block(waiting, profile, 0))).is_equal("stage")
	var run: RunState = Kit.locked(profile, SEED)
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("locked")
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_equal(
		"locked"
	)
	assert_int(run.start_setup.restock_booster()).is_equal(-1)
	var three: ProfileState = Kit.profile(3)
	assert_str(String(StartSetupRules.restock_block(Kit.locked(three, SEED), three, 5))).is_equal(
		"none"
	)


## With only the booster's own products in its aisle's pool and no hit tier that can change, no
## other booster is possible: RESTOCK is "none" and nothing is spent. With RARE odds between 0
## and 100 the hit card can change tier, so it is allowed again.
func test_restock_with_no_other_booster_spends_nothing() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var booster: StartBooster = run.start_setup.boosters[0]
	var held: Array[CardDefinition] = []
	for card: CardDefinition in booster.cards:
		held.append(card.product_card())
	var odds: BalanceDefinition = _balance.duplicate()
	var machine: MachineDefinition = _balance.machine.duplicate()
	var chains: Array[ItemUpgradeDefinition] = []
	for chain: ItemUpgradeDefinition in _balance.machine.item_upgrades:
		if held.has(chain.product):
			chains.append(chain)
	machine.item_upgrades = chains
	odds.machine = machine
	odds.start_booster_hit_rare_percent = 0
	run.balance = odds
	assert_array(StartBoosterDraw.pool(run, profile, booster.aisle)).contains_exactly_in_any_order(
		held
	)
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("none")
	var saved: Dictionary = run.start_setup.to_dictionary()
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_equal(
		"none"
	)
	assert_dict(run.start_setup.to_dictionary()).is_equal(saved)
	odds.start_booster_hit_rare_percent = 50
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_empty()


## The BADGE PINS step (F5): while the profile owns a pin, the packs wait (pick and NEW PACKS
## give "pins") until confirm_pins, with or without a pin worn; with none owned nothing waits.
func test_the_packs_wait_for_the_badge_pins_step() -> void:
	var profile: ProfileState = Kit.profile(1)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_bool(StartSetupRules.confirm_pins(waiting)).is_false()
	var run: RunState = Kit.locked(profile, SEED)
	var pack: StarterPackDefinition = run.start_offer.packs[0]
	assert_str(String(StartSetupRules.pick_block(run, profile, pack))).is_empty()
	assert_bool(StartSetupRules.pins_pending(run, 0)).is_false()
	assert_bool(StartSetupRules.pins_pending(run, 3)).is_true()
	assert_str(String(StartSetupRules.pick_block(run, profile, pack, 3))).is_equal("pins")
	assert_str(String(StartSetupRules.new_packs_block(run, profile, 3))).is_equal("pins")
	assert_str(String(StartSetupRules.new_packs(run, profile, Kit.new_packs_rng(run), 3))).is_equal(
		"pins"
	)
	assert_bool(StartSetupRules.confirm_pins(run)).is_true()
	assert_bool(run.start_setup.pins_confirmed).is_true()
	assert_bool(StartSetupRules.confirm_pins(run)).is_false()
	assert_str(String(StartSetupRules.pick_block(run, profile, pack, 3))).is_empty()
	assert_str(String(StartSetupRules.new_packs_block(run, profile, 3))).is_empty()


## The pick refuses a pack not offered ("offer") and one the cart no longer fits ("copies", N6:
## the same copy rule NEW PACKS keeps): two swapped regulars and the pack past copy_max.
func test_the_pick_keeps_the_copy_rule() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var unoffered: StarterPackDefinition = null
	for pack: StarterPackDefinition in run.starter.starter_packs:
		if unoffered == null and not run.start_offer.packs.has(pack):
			unoffered = pack
	assert_str(String(StartSetupRules.pick_block(run, profile, unoffered))).is_equal("offer")
	assert_str(String(StartSetupRules.pick_block(run, profile, null))).is_equal("offer")
	var pack: StarterPackDefinition = run.start_offer.packs[0]
	var card: CardDefinition = null
	for held: CardDefinition in pack.cards:
		if card == null and held.is_product() and not run.starter.core_cards.has(held):
			card = held
	assert_object(card).is_not_null()
	run.starter.core_cards[2] = card
	run.starter.core_cards[3] = card
	assert_str(String(StartSetupRules.pick_block(run, profile, pack))).is_equal("copies")


## NEW PACKS: refused before the deal; redraws the offer once, keeping the boosters and the
## regulars, at least one pack new; with nothing picked the good first pick stays in its place
## (and nothing is picked); after a pick the picked pack stays in its place, still picked (v1.32,
## mock-up start_boosters_v3 N5); then "used". Same seed, same new packs.
func test_new_packs_keep_the_deal_the_regulars_and_the_pick() -> void:
	var profile: ProfileState = Kit.profile(1)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_str(String(StartSetupRules.new_packs_block(waiting, profile))).is_equal("stage")
	var won: ProfileState = Kit.profile(1)
	won.stats[ProfileState.RUNS_WON] = 1
	for who: ProfileState in [profile, won]:
		for pick_first: bool in [false, true]:
			var run: RunState = Kit.locked(who, SEED)
			assert_bool(Kit.swap(run, who, 0)).is_true()
			var core: Array[CardDefinition] = run.starter.core_cards.duplicate()
			var dealt: Array[CardDefinition] = run.start_setup.shared()
			var old: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
			var forced: StarterPackDefinition = run.start_offer.first_pick
			run.start_setup.picked = old[2].id if pick_first else &""
			assert_str(String(StartSetupRules.new_packs_block(run, who))).is_empty()
			(
				assert_str(String(StartSetupRules.new_packs(run, who, Kit.new_packs_rng(run))))
				. is_empty()
			)
			var packs: Array[StarterPackDefinition] = run.start_offer.packs
			assert_int(packs.size()).is_equal(old.size())
			assert_bool(Kit.all_in(packs, old)).is_false()
			for pack: StarterPackDefinition in packs:
				assert_int(packs.count(pack)).is_equal(1)
				assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, dealt)).is_true()
			assert_array(run.start_setup.shared()).is_equal(dealt)
			assert_array(run.starter.core_cards).is_equal(core)
			if pick_first:
				assert_object(packs[2]).is_same(old[2])
				assert_str(String(run.start_setup.picked)).is_equal(String(old[2].id))
			else:
				if forced != null:
					assert_int(packs.find(forced)).is_equal(old.find(forced))
				assert_str(String(run.start_setup.picked)).is_empty()
			assert_bool(run.start_setup.packs_redrawn).is_true()
			assert_str(String(StartSetupRules.new_packs_block(run, who))).is_equal("used")
			var again: RunState = Kit.locked(who, SEED)
			assert_bool(Kit.swap(again, who, 0)).is_true()
			again.start_setup.picked = old[2].id if pick_first else &""
			StartSetupRules.new_packs(again, who, Kit.new_packs_rng(again))
			assert_array(again.start_offer.packs).is_equal(packs)


func test_new_packs_with_no_other_pack_is_disabled() -> void:
	var profile: ProfileState = Kit.profile(0)
	var run: RunState = Kit.locked(profile, SEED)
	run.starter.starter_packs = run.start_offer.packs.duplicate()
	assert_str(String(StartSetupRules.new_packs_block(run, profile))).is_equal("none")
	assert_str(String(StartSetupRules.new_packs(run, profile, Kit.new_packs_rng(run)))).is_equal(
		"none"
	)
	assert_bool(run.start_setup.packs_redrawn).is_false()


## A pack needing an aisle (v1.29: the Snack stand, Snacks) is in the run's packs, its offer and
## NEW PACKS only once that aisle is listable for the profile.
func test_the_snack_stand_waits_for_the_snacks_aisle() -> void:
	var stand: StarterPackDefinition = load("res://data/starter_packs/snack_stand.tres")
	var fresh: ProfileState = Kit.profile(0)
	for offset: int in 6:
		var run: RunState = Kit.locked(fresh, SEED + offset)
		assert_bool(run.starter.starter_packs.has(stand)).is_false()
		assert_bool(run.start_offer.packs.has(stand)).is_false()
		StartSetupRules.new_packs(run, fresh, Kit.new_packs_rng(run))
		assert_bool(run.start_offer.packs.has(stand)).is_false()
	var full: ProfileState = Kit.profile(_balance.aisles.size())
	var open: RunState = Kit.locked(full, SEED)
	assert_array(open.starter.starter_packs).is_equal(_recipe.starter_packs)


func test_the_stage_moves_to_build_once() -> void:
	var waiting: RunState = Kit.run(Kit.profile(0), SEED)
	assert_bool(StartSetupRules.mark_build(waiting)).is_false()
	var run: RunState = Kit.locked(Kit.profile(0), SEED)
	assert_bool(StartSetupRules.mark_build(run)).is_true()
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_bool(StartSetupRules.mark_build(run)).is_false()


func test_the_cart_lines_name_each_cards_source() -> void:
	var run: RunState = Kit.locked(Kit.profile(0), SEED)
	var pin: PinDefinition = PinDefinition.new()
	pin.id = &"test_pin"
	pin.display_name = "Test pin"
	pin.starting_cards = [REPEAT]
	var pins: Array[PinDefinition] = [pin]
	var waiting: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, _balance, pins, null
	)
	var core: int = _recipe.core_cards.size()
	var pack_size: int = run.start_offer.packs[0].cards.size()
	assert_int(waiting.size()).is_equal(core + pack_size + _recipe.random_count + 1)
	assert_int(StartSetupRules.cart_cards(waiting).size()).is_equal(waiting.size() - pack_size)
	var pack: StarterPackDefinition = run.start_offer.packs[1]
	var lines: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, _balance, pins, pack, true
	)
	assert_array(StartSetupRules.cart_cards(lines)).is_equal(
		_recipe.core_cards + pack.cards + run.start_setup.shared() + pins[0].starting_cards
	)
	for index: int in range(core + pack.cards.size(), lines.size() - 1):
		var line: StartCartLine = lines[index]
		assert_int(line.source).is_equal(StartCartLine.Source.DEALT)
		var aisle: AisleDefinition = _balance.aisle_of(line.card)
		assert_str(String(line.origin)).is_equal(String(aisle.id))
	# Nothing dealt yet: only the regulars (and the pins).
	var select: RunState = Kit.run(Kit.profile(0), SEED)
	(
		assert_int(
			(
				StartSetupRules
				. cart_lines(select.starter, select.start_offer, _balance, [], null)
				. size()
			)
		)
		. is_equal(core)
	)


## A booster's own checks: cards of its aisle, distinct products, at most the size, BIG only at a
## hit place, never GOLDEN.
func _assert_booster(booster: StartBooster) -> void:
	assert_int(booster.cards.size()).is_less_equal(_balance.start_booster_size)
	var products: Array[CardDefinition] = []
	for index: int in booster.cards.size():
		var card: CardDefinition = booster.cards[index]
		assert_bool(Kit.of_aisle(card, booster.aisle)).is_true()
		assert_bool(products.has(card.product_card())).is_false()
		products.append(card.product_card())
		assert_int(card.tier).is_not_equal(CardDefinition.Tier.GOLDEN)
		if card.tier == CardDefinition.Tier.BIG:
			assert_bool(booster.is_hit(index)).is_true()
