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
## Data order: dairy, pantry, household (base aisles), fruit_and_veg, bakery, snacks
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
		assert_bool([&"dairy", &"pantry", &"household"].has(id)).is_true()
	assert_array(Kit.suggest(profile, SEED)).is_equal(drawn)
	assert_array(drawn).is_equal(StartSetupRules.ordered_pair(_balance, drawn))
	var orders: Dictionary = {}
	for seed_value: int in range(SEED, SEED + 30):
		orders[str(Kit.suggest(profile, seed_value))] = true
	assert_int(orders.size()).is_greater(1)


## A new run is in SELECT: the suggestion's stock, nothing dealt, and the run's own RNG untouched;
## the store can't open yet.
func test_a_new_run_waits_in_select_with_nothing_dealt() -> void:
	var run: RunState = Kit.run(Kit.profile(0), SEED)
	var setup: StartSetup = run.start_setup
	assert_int(setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_int(run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(run.start_offer.shared).is_empty()
	assert_array(setup.boosters).is_empty()
	assert_array(setup.shared()).is_empty()
	assert_array(run.starter.cards).is_equal(_recipe.core_cards)
	assert_array(run.stock.aisle_ids).contains_exactly_in_any_order(setup.stock_aisles)
	var plain: RunState = RunState.new(SEED, run.starter, _balance, run.stock, run.start_offer)
	assert_int(run.rng_state).is_equal(plain.rng_state)
	assert_bool(run.open_store()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(run.open_store()).is_false()


## The deal: one sealed booster per stocked aisle, each start_booster_size distinct products of its
## own aisle only (no staples draw), its last place the hit card
## (BIG at most there, never GOLDEN); the cart keeps the recipe's random_count dealt cards; the same
## seed deals the same; the run's own RNG is never used.
func test_the_deal_gives_two_sealed_boosters_from_their_aisles() -> void:
	assert_int(_balance.start_booster_size * _balance.dealt_aisle_count).is_equal(
		_recipe.random_count
	)
	for completed: int in [0, 3]:
		for seed_value: int in range(SEED, SEED + 4):
			var profile: ProfileState = Kit.profile(completed)
			var run: RunState = Kit.dealt(profile, seed_value)
			var setup: StartSetup = run.start_setup
			assert_int(setup.stage).is_equal(StartSetup.Stage.DEALT)
			assert_int(setup.boosters.size()).is_equal(_balance.dealt_aisle_count)
			for index: int in setup.boosters.size():
				var booster: StartBooster = setup.boosters[index]
				assert_str(String(booster.aisle)).is_equal(String(setup.stock_aisles[index]))
				_assert_booster(booster)
				assert_int(booster.cards.size()).is_between(2, _balance.start_booster_size)
				# A short booster (an aisle with fewer products) keeps its hits on its last places.
				assert_int(booster.hits).is_between(0, _balance.start_booster_hit_slots)
				assert_bool(booster.opened).is_false()
			assert_array(run.start_offer.shared).is_equal(setup.shared())
			assert_int(run.start_offer.deals).is_between(1, _recipe.fair_deal_redeals + 1)
			assert_int(run.starter.cards.size()).is_equal(
				_recipe.core_cards.size() + setup.shared().size()
			)
			assert_bool(StartingDeck.fits_copies(run.starter, setup.shared())).is_true()
			var again: RunState = Kit.dealt(Kit.profile(completed), seed_value)
			assert_dict(again.start_setup.to_dictionary()).is_equal(setup.to_dictionary())
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
	var refused: StringName = StartSetupRules.deal(run, profile, Kit.deck_rng(run), none)
	assert_str(String(refused)).is_equal("streams")
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_str(String(Kit.deal(run, profile))).is_empty()
	assert_str(String(Kit.deal(run, profile))).is_equal("stage")


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


## RESTOCK (3 completed): only an opened booster; a fresh booster of the same aisle (a new hit
## too) differing by at least one card, sealed again and stamped; the other booster unchanged; spent
## once; same seed, same restock.
func test_restock_deals_one_opened_booster_again_once() -> void:
	for index: int in 2:
		var profile: ProfileState = Kit.profile(3)
		var run: RunState = Kit.dealt(profile, SEED)
		var setup: StartSetup = run.start_setup
		assert_str(String(StartSetupRules.restock_block(run, profile, index))).is_equal("sealed")
		Kit.open_all(run)
		var kept: StartSetup = setup.copy()
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


## The BADGE PINS step (F5): while the profile owns a pin, OPEN STORE waits (pins_pending) until
## confirm_pins, with or without a pin worn; with none owned nothing waits.
func test_open_store_waits_for_the_badge_pins_step() -> void:
	var profile: ProfileState = Kit.profile(1)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_bool(StartSetupRules.confirm_pins(waiting)).is_false()
	var run: RunState = Kit.locked(profile, SEED)
	assert_bool(StartSetupRules.pins_pending(run, 0)).is_false()
	assert_bool(StartSetupRules.pins_pending(run, 3)).is_true()
	assert_bool(StartSetupRules.confirm_pins(run)).is_true()
	assert_bool(run.start_setup.pins_confirmed).is_true()
	assert_bool(StartSetupRules.confirm_pins(run)).is_false()
	assert_bool(StartSetupRules.pins_pending(run, 3)).is_false()


## OPEN STORE (v1.41, no starter pack): the cart becomes the regulars and the boosters' cards,
## in that order, and the run moves to planning.
func test_open_store_takes_the_cart_as_it_stands() -> void:
	var run: RunState = Kit.locked(Kit.profile(0), SEED)
	var shared: Array[CardDefinition] = run.start_setup.shared()
	assert_bool(run.open_store()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(run.starter.cards).is_equal(_recipe.core_cards + shared)
	assert_int(run.deck.size()).is_equal(_recipe.core_cards.size() + shared.size())
	assert_bool(run.open_store()).is_false()


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
	var core: int = _recipe.core_cards.size()
	var lines: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, _balance, pins
	)
	assert_int(lines.size()).is_equal(core + run.start_setup.shared().size() + 1)
	assert_array(StartSetupRules.cart_cards(lines)).is_equal(
		_recipe.core_cards + run.start_setup.shared() + pins[0].starting_cards
	)
	assert_int(lines[0].source).is_equal(StartCartLine.Source.REGULAR)
	assert_int(lines[lines.size() - 1].source).is_equal(StartCartLine.Source.PIN)
	for index: int in range(core, lines.size() - 1):
		var line: StartCartLine = lines[index]
		assert_int(line.source).is_equal(StartCartLine.Source.DEALT)
		var aisle: AisleDefinition = _balance.aisle_of(line.card)
		assert_str(String(line.origin)).is_equal(String(aisle.id))
	# Nothing dealt yet: only the regulars (and the pins).
	var select: RunState = Kit.run(Kit.profile(0), SEED)
	(
		assert_int(
			StartSetupRules.cart_lines(select.starter, select.start_offer, _balance, []).size()
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
