extends GdUnitTestSuite
## The opening-time rules (StartSetupRules, StartSetup, full build plan 7.2, reworked 2026-11-05):
## completed aisles, today's suggested and chosen aisles, LOCK IN's three source baskets of 2 and
## its fair-deal check, the one-basket RESTOCK, the regular swaps with their per-slot offers,
## targets and limits, NEW PACKS, the stages and the saved forms (the old form restarting). On
## the live data, with the named derived streams the game uses; nothing here touches a save file.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const RECIPE := Kit.RECIPE
const BALANCE := Kit.BALANCE
const SEED := 20261104
## Data order: cold_cases, pantry, household (base aisles), fruit_and_veg, bakery, snacks
## (machine aisles, listable at aisle_listable_min items).
const MACHINE_AISLE := 3
const CHEESE := preload("res://data/cards/cheese.tres")
const DELI := preload("res://data/starter_packs/deli_counter.tres")

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


## Run 1: the three base aisles; which two are green is seeded by the run seed (same seed, same
## suggestion), the green ones in data order.
func test_the_suggested_aisles_are_seeded() -> void:
	var profile: ProfileState = ProfileState.new()
	var drawn: Array[StringName] = Kit.suggest(profile, SEED)
	assert_array(drawn).contains_exactly_in_any_order([&"cold_cases", &"pantry", &"household"])
	assert_array(Kit.suggest(profile, SEED)).is_equal(drawn)
	assert_array(drawn.slice(0, 2)).is_equal(
		StartSetupRules.ordered_pair(_balance, drawn.slice(0, 2))
	)
	var orders: Dictionary = {}
	for seed_value: int in range(SEED, SEED + 30):
		orders[str(Kit.suggest(profile, seed_value))] = true
	assert_int(orders.size()).is_greater(1)


## From 6 completed aisles the board opens on the profile's last choice; below 6 it never does.
func test_the_profiles_choice_is_suggested_only_with_every_aisle_complete() -> void:
	var profile: ProfileState = Kit.profile(6)
	profile.stock_pair = [&"snacks", &"bakery"]
	profile.stock_run_only = &"pantry"
	for seed_value: int in range(SEED, SEED + 5):
		assert_array(Kit.suggest(profile, seed_value)).is_equal([&"bakery", &"snacks", &"pantry"])
	# A saved aisle that is also green, or missing, leaves its place to the seeded draw.
	profile.stock_run_only = &"snacks"
	var drawn: Array[StringName] = Kit.suggest(profile, SEED)
	assert_array(drawn.slice(0, 2)).is_equal([&"bakery", &"snacks"])
	assert_bool(drawn[2] in [&"bakery", &"snacks"]).is_false()
	var five: ProfileState = Kit.profile(5)
	five.stock_pair = [&"snacks", &"bakery"]
	var other: bool = false
	for seed_value: int in range(SEED, SEED + 10):
		other = other or Kit.suggest(five, seed_value).slice(0, 2) != [&"bakery", &"snacks"]
	assert_bool(other).is_true()


## A new run is in SELECT: the suggestion's stock and baskets' sources, nothing dealt, no packs,
## nothing to pick, and the run's own RNG untouched.
func test_a_new_run_waits_in_select_with_nothing_dealt() -> void:
	var run: RunState = Kit.run(Kit.profile(0), SEED)
	var setup: StartSetup = run.start_setup
	assert_int(setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_int(run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(run.start_offer.packs).is_empty()
	assert_array(run.start_offer.shared).is_empty()
	assert_object(run.start_offer.default_pack()).is_null()
	assert_array(setup.basket_sources()).is_equal(
		[StartSetup.STAPLES, setup.stock_aisles[0], setup.stock_aisles[1]]
	)
	assert_array(setup.shared()).is_empty()
	assert_str(String(setup.picked)).is_empty()
	assert_array(run.starter.cards).is_equal(_recipe.core_cards)
	assert_array(run.stock.aisle_ids).contains_exactly_in_any_order(setup.stock_aisles)
	var plain: RunState = RunState.new(SEED, run.starter, _balance, run.stock, run.start_offer)
	assert_int(run.rng_state).is_equal(plain.rng_state)
	assert_bool(run.take_pack(_recipe.first_pick_pack)).is_false()


## LOCK IN & DEAL: exactly 2 distinct cards per basket, each from its own source only (the
## staples shelf, each green aisle), none from the RUN ONLY aisle; the offer of 3 packs with the
## good first pick picked; the same seed deals the same; the run's own RNG is never used.
func test_lock_in_deals_three_baskets_of_two_from_their_own_sources() -> void:
	for completed: int in [0, 3, 6]:
		for seed_value: int in range(SEED, SEED + 4):
			var profile: ProfileState = Kit.profile(completed)
			var run: RunState = Kit.locked(profile, seed_value)
			var setup: StartSetup = run.start_setup
			assert_int(setup.stage).is_equal(StartSetup.Stage.REVEALED)
			assert_int(setup.baskets.size()).is_equal(3)
			for basket: StartBasket in setup.baskets:
				assert_int(basket.cards.size()).is_equal(_balance.start_basket_size)
				for card: CardDefinition in basket.cards:
					assert_int(basket.cards.count(card)).is_equal(1)
					assert_bool(Kit.of_source(card, basket.source)).is_true()
			for card: CardDefinition in setup.shared():
				assert_bool(Kit.of_source(card, setup.run_only_ids(_balance)[0])).is_false()
			assert_array(run.start_offer.shared).is_equal(setup.shared())
			assert_int(run.start_offer.packs.size()).is_equal(_recipe.packs_offered)
			assert_str(String(setup.picked)).is_equal(String(_recipe.first_pick_pack.id))
			assert_int(run.start_offer.deals).is_between(1, _recipe.fair_deal_redeals + 1)
			assert_int(run.starter.cards.size()).is_equal(
				_recipe.core_cards.size() + _recipe.random_count
			)
			for pack: StarterPackDefinition in run.start_offer.packs:
				(
					assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, setup.shared()))
					. is_true()
				)
			var again: RunState = Kit.locked(Kit.profile(completed), seed_value)
			assert_dict(again.start_setup.to_dictionary()).is_equal(setup.to_dictionary())
			assert_array(again.start_offer.packs).is_equal(run.start_offer.packs)
			var plain: RunState = RunState.new(
				seed_value, run.starter, _balance, run.stock, run.start_offer
			)
			assert_int(run.rng_state).is_equal(plain.rng_state)


## A profile that has won gets no good first pick and nothing picked.
func test_lock_in_without_the_first_pick_after_a_win() -> void:
	var profile: ProfileState = Kit.profile(0)
	profile.stats[ProfileState.RUNS_WON] = 1
	var run: RunState = Kit.locked(profile, SEED)
	assert_object(run.start_offer.first_pick).is_null()
	assert_str(String(run.start_setup.picked)).is_empty()


## Below 6 completed aisles only the suggestion locks in; from 6 any 2 + 1 listable aisles do,
## and the profile keeps the choice. The reasons are data for the board.
func test_lock_block_reasons_and_the_chosen_aisles() -> void:
	var run: RunState = Kit.run(Kit.profile(0), SEED)
	var green: Array[StringName] = run.start_setup.green_ids(_balance)
	var orange: Array[StringName] = run.start_setup.run_only_ids(_balance)
	var profile: ProfileState = Kit.profile(0)
	assert_str(String(StartSetupRules.lock_block(run, profile, green, orange))).is_empty()
	var flipped: Array[StringName] = [green[0], orange[0]]
	assert_str(String(StartSetupRules.lock_block(run, profile, flipped, [green[1]]))).is_equal(
		"locked"
	)
	assert_str(String(StartSetupRules.lock_block(run, profile, [green[0]], orange))).is_equal(
		"count"
	)
	var twice: Array[StringName] = [green[0], green[0]]
	assert_str(String(StartSetupRules.lock_block(run, profile, twice, orange))).is_equal("count")
	assert_str(String(StartSetupRules.lock_block(run, profile, green, [&"snacks"]))).is_equal(
		"listable"
	)
	var all: ProfileState = Kit.profile(6)
	var chosen: RunState = Kit.run(all, SEED)
	var pair: Array[StringName] = [&"snacks", &"bakery"]
	var run_only: Array[StringName] = [&"pantry"]
	assert_str(String(StartSetupRules.lock_block(chosen, all, pair, run_only))).is_empty()
	var streams: Dictionary[StringName, RandomNumberGenerator] = Kit.basket_streams(chosen, pair)
	(
		assert_str(
			String(
				StartSetupRules.lock_in(chosen, all, pair, run_only, Kit.deck_rng(chosen), streams)
			)
		)
		. is_empty()
	)
	assert_array(chosen.start_setup.stock_aisles).is_equal([&"bakery", &"snacks", &"pantry"])
	assert_array(chosen.start_setup.basket_sources()).is_equal(
		[StartSetup.STAPLES, &"bakery", &"snacks"]
	)
	assert_array(chosen.stock.aisle_ids).contains_exactly_in_any_order(
		chosen.start_setup.stock_aisles
	)
	assert_array(all.stock_pair).is_equal([&"bakery", &"snacks"])
	assert_str(String(all.stock_run_only)).is_equal("pantry")
	assert_str(String(StartSetupRules.lock_block(chosen, all, pair, run_only))).is_equal("stage")
	# Missing a basket's stream: refused, nothing changed.
	var missing: RunState = Kit.run(all, SEED)
	var none: Dictionary[StringName, RandomNumberGenerator] = {}
	(
		assert_str(
			String(
				StartSetupRules.lock_in(missing, all, pair, run_only, Kit.deck_rng(missing), none)
			)
		)
		. is_equal("streams")
	)
	assert_int(missing.start_setup.stage).is_equal(StartSetup.Stage.SELECT)


## RESTOCK one basket at 3 completed: both its cards replaced from the same source by a set
## sharing no card with the old one, the other baskets, the packs and the pick unchanged, spent
## once; same seed, same restock.
func test_restock_redraws_one_basket_from_its_source_once() -> void:
	for basket: int in 3:
		var profile: ProfileState = Kit.profile(3)
		var run: RunState = Kit.locked(profile, SEED)
		var setup: StartSetup = run.start_setup
		var kept: StartSetup = setup.copy()
		var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
		assert_str(String(StartSetupRules.restock_block(run, profile, basket))).is_empty()
		(
			assert_str(
				String(StartSetupRules.restock(run, profile, basket, Kit.restock_rng(run, basket)))
			)
			. is_empty()
		)
		assert_int(setup.restock_basket).is_equal(basket)
		for index: int in 3:
			if index != basket:
				assert_array(setup.baskets[index].cards).is_equal(kept.baskets[index].cards)
		var cards: Array[CardDefinition] = setup.baskets[basket].cards
		assert_int(cards.size()).is_equal(_balance.start_basket_size)
		for card: CardDefinition in cards:
			assert_bool(kept.baskets[basket].cards.has(card)).is_false()
		for card: CardDefinition in cards:
			assert_bool(Kit.of_source(card, setup.baskets[basket].source)).is_true()
		assert_array(run.start_offer.packs).is_equal(packs)
		assert_str(String(setup.picked)).is_equal(String(kept.picked))
		assert_array(run.start_offer.shared).is_equal(setup.shared())
		assert_array(run.starter.cards.slice(_recipe.core_cards.size())).is_equal(setup.shared())
		for other: int in 3:
			assert_str(String(StartSetupRules.restock_block(run, profile, other))).is_equal("used")
		var again: RunState = Kit.locked(Kit.profile(3), SEED)
		StartSetupRules.restock(again, Kit.profile(3), basket, Kit.restock_rng(again, basket))
		assert_array(again.start_setup.baskets[basket].cards).is_equal(cards)


func test_restock_is_locked_in_select_and_below_three_completed() -> void:
	var profile: ProfileState = Kit.profile(2)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_str(String(StartSetupRules.restock_block(waiting, profile, 0))).is_equal("stage")
	var run: RunState = Kit.locked(profile, SEED)
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("locked")
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_equal(
		"locked"
	)
	assert_int(run.start_setup.restock_basket).is_equal(-1)


## With no other card set of its source under the copy rule, a basket's RESTOCK is disabled
## ("none") and nothing is spent; the other baskets can still be restocked.
func test_restock_with_no_alternative_spends_nothing() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var staples: Array[CardDefinition] = run.start_setup.baskets[0].cards
	var kept: Array[CardDefinition] = []
	for card: CardDefinition in run.stock.cards:
		if not _balance.staples.has(card) or staples.has(card):
			kept.append(card)
	run.stock = RunStock.from_saved(kept, run.stock.aisle_ids, false, [])
	assert_array(StartSetupRules.restock_options(run, 0)).is_empty()
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("none")
	var saved: Dictionary = run.start_setup.to_dictionary()
	assert_str(String(StartSetupRules.restock(run, profile, 0, Kit.restock_rng(run, 0)))).is_equal(
		"none"
	)
	assert_dict(run.start_setup.to_dictionary()).is_equal(saved)
	assert_str(String(StartSetupRules.restock_block(run, profile, 1))).is_empty()
	assert_str(String(StartSetupRules.restock_block(run, profile, 3))).is_equal("none")


## A source with fewer than start_basket_size open cards (under copy_max) gives a short basket:
## basket_sets has only the one smaller set (a single card), and none when nothing is open.
func test_a_short_source_gives_a_short_basket() -> void:
	var staples: Array[CardDefinition] = _balance.staples
	var copies: Dictionary[CardDefinition, int] = {}
	for card: CardDefinition in staples:
		copies[card] = 2
	copies.erase(staples[1])
	var sets: Array[Array] = StartingDeck.basket_sets(staples, 2, copies, 2)
	assert_int(sets.size()).is_equal(1)
	assert_array(sets[0]).is_equal([staples[1]])
	copies[staples[1]] = 2
	assert_int(StartingDeck.basket_sets(staples, 2, copies, 2)[0].size()).is_equal(0)


## A RESTOCK replaces both items: with only one other card of its source open, every other set
## keeps an old card, so the basket's RESTOCK is "none" and nothing is spent.
func test_restock_needs_a_pair_sharing_no_card() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var staples: Array[CardDefinition] = run.start_setup.baskets[0].cards
	var copies: Dictionary[CardDefinition, int] = StartingDeck.copies_for_offer(
		run.starter, run.start_offer.packs
	)
	var extra: CardDefinition = null
	for card: CardDefinition in _balance.staples:
		if (
			extra == null
			and not staples.has(card)
			and int(copies.get(card, 0)) < run.starter.copy_max
		):
			extra = card
	assert_object(extra).is_not_null()
	var kept: Array[CardDefinition] = []
	for card: CardDefinition in run.stock.cards:
		if not _balance.staples.has(card) or staples.has(card) or card == extra:
			kept.append(card)
	run.stock = RunStock.from_saved(kept, run.stock.aisle_ids, false, [])
	assert_array(StartSetupRules.restock_options(run, 0)).is_empty()
	assert_str(String(StartSetupRules.restock_block(run, profile, 0))).is_equal("none")
	assert_int(run.start_setup.restock_basket).is_equal(-1)


## NEW PACKS: refused in SELECT; redraws the offer once, keeping the baskets, the regulars and the
## good first pick in its place, at least one pack new; the pick is cleared (even on a new
## profile: a crate has to be chosen again); then "used". Same seed, same new packs.
func test_new_packs_keep_the_deal_and_regulars_and_clear_the_pick() -> void:
	var profile: ProfileState = Kit.profile(1)
	var waiting: RunState = Kit.run(profile, SEED)
	assert_str(String(StartSetupRules.new_packs_block(waiting, profile))).is_equal("stage")
	var won: ProfileState = Kit.profile(1)
	won.stats[ProfileState.RUNS_WON] = 1
	for who: ProfileState in [profile, won]:
		var run: RunState = Kit.locked(who, SEED)
		assert_bool(Kit.swap(run, who, 0)).is_true()
		var core: Array[CardDefinition] = run.starter.core_cards.duplicate()
		var dealt: Array[CardDefinition] = run.start_setup.shared()
		var old: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
		var forced: StarterPackDefinition = run.start_offer.first_pick
		run.start_setup.picked = old[0].id
		assert_str(String(StartSetupRules.new_packs_block(run, who))).is_empty()
		assert_str(String(StartSetupRules.new_packs(run, who, Kit.new_packs_rng(run)))).is_empty()
		var packs: Array[StarterPackDefinition] = run.start_offer.packs
		assert_int(packs.size()).is_equal(old.size())
		assert_bool(Kit.all_in(packs, old)).is_false()
		for pack: StarterPackDefinition in packs:
			assert_int(packs.count(pack)).is_equal(1)
			assert_bool(StartingDeck.fits_copies(run.starter, pack.cards, dealt)).is_true()
		assert_array(run.start_setup.shared()).is_equal(dealt)
		assert_array(run.starter.core_cards).is_equal(core)
		if forced != null:
			assert_int(packs.find(forced)).is_equal(old.find(forced))
		assert_str(String(run.start_setup.picked)).is_empty()
		assert_bool(run.start_setup.packs_redrawn).is_true()
		assert_str(String(StartSetupRules.new_packs_block(run, who))).is_equal("used")
		var again: RunState = Kit.locked(who, SEED)
		assert_bool(Kit.swap(again, who, 0)).is_true()
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
	pin.starting_cards = [load("res://data/cards/repeat.tres")]
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
		assert_str(String(line.origin)).is_equal(String(aisle.id) if aisle != null else "")
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
