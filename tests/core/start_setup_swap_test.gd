extends GdUnitTestSuite
## The opening-time regulars (StartSetupRules, full build plan 7.2, reworked 2026-11-05): the swap
## pool, a slot's stable offer from one aisle, the drag targets' reasons, the swap limits and the
## copy rule with the packs and the baskets, and the profile's saved swaps. On the live data.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104
const CHEESE := preload("res://data/cards/cheese.tres")
const DELI := preload("res://data/starter_packs/deli_counter.tres")

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


func test_the_swap_pool_is_plain_products_of_completed_aisles() -> void:
	var profile: ProfileState = Kit.profile(1)
	var cold: AisleDefinition = _balance.aisles[0]
	for card: CardDefinition in cold.base_cards + cold.capsule_cards:
		assert_bool(StartSetupRules.is_swap_option(_balance, profile, card)).is_equal(
			card.variant_of == null
		)
	var cereal: CardDefinition = _balance.aisles[1].base_cards[0]
	assert_bool(StartSetupRules.is_swap_option(_balance, profile, cereal)).is_false()
	var chain: ItemUpgradeDefinition = Kit.chain_of(cold)
	assert_bool(StartSetupRules.is_swap_option(_balance, profile, chain.big)).is_false()
	assert_bool(StartSetupRules.is_swap_option(_balance, profile, chain.golden)).is_false()
	var coupon: CardDefinition = load("res://data/cards/two_for_one.tres")
	assert_bool(StartSetupRules.is_swap_option(_balance, profile, coupon)).is_false()
	var run: RunState = Kit.locked(profile, SEED)
	assert_str(String(StartSetupRules.swap_block(run, profile, 0, chain.big))).is_equal("option")
	assert_str(String(StartSetupRules.swap_block(run, profile, 0, coupon))).is_equal("option")
	assert_str(String(StartSetupRules.swap_block(run, profile, 0, cereal))).is_equal("option")


## A slot's offer from one aisle: at most regular_offer_max plain products in data order, drawn
## once and kept (another stream gives the same), never the slot's current card (it can't be
## chosen); empty for an aisle not completed.
func test_a_regular_offer_is_stable_per_slot_and_aisle() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var cold: AisleDefinition = _balance.aisles[0]
	var offer: Array[CardDefinition] = StartSetupRules.regular_offer(
		run, profile, 0, cold.id, Kit.regulars_rng(run, 0, cold.id)
	)
	assert_int(offer.size()).is_equal(_balance.regular_offer_max)
	var order: Array[CardDefinition] = cold.base_cards + cold.capsule_cards
	var last: int = -1
	for card: CardDefinition in offer:
		assert_bool(StartSetupRules.is_swap_option(_balance, profile, card)).is_true()
		assert_int(order.find(card)).is_greater(last)
		last = order.find(card)
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	other.seed = 99
	assert_array(StartSetupRules.regular_offer(run, profile, 0, cold.id, other)).is_equal(offer)
	assert_array(run.start_setup.regular_offer(0, cold.id)).is_equal(offer)
	# Each slot has its own offer; different slots differ for some seed.
	var differs: bool = false
	for seed_value: int in range(SEED, SEED + 8):
		var each: RunState = Kit.locked(Kit.profile(1), seed_value)
		var first: Array[CardDefinition] = StartSetupRules.regular_offer(
			each, profile, 0, cold.id, Kit.regulars_rng(each, 0, cold.id)
		)
		var second: Array[CardDefinition] = StartSetupRules.regular_offer(
			each, profile, 1, cold.id, Kit.regulars_rng(each, 1, cold.id)
		)
		differs = differs or first != second
	assert_bool(differs).is_true()
	(
		assert_array(
			StartSetupRules.regular_offer(
				run, profile, 0, &"pantry", Kit.regulars_rng(run, 0, &"pantry")
			)
		)
		. is_empty()
	)
	# The slot's current card from this aisle is left out; the offer is still full.
	for seed_value: int in range(SEED, SEED + 8):
		var swapped: RunState = Kit.locked(Kit.profile(1), seed_value)
		var current: CardDefinition = cold.capsule_cards[1]
		swapped.starter.core_cards[2] = current
		var shown: Array[CardDefinition] = StartSetupRules.regular_offer(
			swapped, profile, 2, cold.id, Kit.regulars_rng(swapped, 2, cold.id)
		)
		assert_bool(shown.has(current)).is_false()
		assert_int(shown.size()).is_equal(_balance.regular_offer_max)
	# A card left out of a slot's saved offer can't be swapped into that slot.
	for card: CardDefinition in order:
		if StartSetupRules.is_swap_option(_balance, profile, card) and not offer.has(card):
			assert_str(String(StartSetupRules.swap_block(run, profile, 0, card))).is_equal("option")


## One swap per completed aisle, at most one per regular: the 5th completed aisle gives nothing.
func test_swaps_are_capped_by_completed_aisles_and_the_fifth_gives_nothing() -> void:
	var expected: Array[int] = [0, 1, 2, 3, 4, 4, 4]
	for completed: int in range(7):
		var capped: RunState = Kit.locked(Kit.profile(completed), SEED)
		assert_int(StartSetupRules.swaps_left(capped, Kit.profile(completed))).is_equal(
			expected[completed]
		)
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(1)
	assert_int(StartSetupRules.swaps_left(run, profile)).is_equal(0)
	for slot: int in range(1, run.starter.core_cards.size()):
		assert_object(Kit.option(run, profile, slot)).is_null()
	(
		assert_str(String(StartSetupRules.swap_block(run, profile, 0, run.starter.core_cards[0])))
		. is_equal("slot")
	)
	assert_object(Kit.option(run, profile, 0)).is_not_null()


## The drag target's reasons: an aisle not completed, no replacement left, the aisle cap, and an
## aisle whose offer holds nothing under the copy rule.
func test_target_block_reasons() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var cold: AisleDefinition = _balance.aisles[0]
	assert_str(String(StartSetupRules.target_block(run, profile, 0, cold.id))).is_empty()
	assert_str(String(StartSetupRules.target_block(run, profile, 0, &"snacks"))).is_equal(
		"incomplete"
	)
	assert_str(String(StartSetupRules.target_block(run, profile, 9, cold.id))).is_equal("slot")
	for slot: int in 2:
		var card: CardDefinition = Kit.option(run, profile, slot, cold)
		run.starter.core_cards[slot] = card
		StartSetupRules.refresh_deck(run)
	assert_str(String(StartSetupRules.target_block(run, profile, 2, cold.id))).is_equal("aisle")
	assert_str(String(StartSetupRules.target_block(run, profile, 2, &"pantry"))).is_empty()
	run.starter.core_cards[2] = Kit.option(run, profile, 2, _balance.aisles[1])
	StartSetupRules.refresh_deck(run)
	assert_str(String(StartSetupRules.target_block(run, profile, 3, &"pantry"))).is_equal("swaps")
	# Slot 0's offer is Cheese only, and a regular and a basket already hold Cheese: a third
	# copy, so nothing there fits.
	var three: ProfileState = Kit.profile(3)
	var full: RunState = Kit.locked(three, SEED)
	var only_cheese: Array[CardDefinition] = [CHEESE]
	full.start_setup.regular_offers[StartSetup.offer_key(0, cold.id)] = only_cheese
	full.starter.core_cards[1] = CHEESE
	full.start_setup.baskets[1].cards = only_cheese.duplicate()
	assert_str(String(StartSetupRules.target_block(full, three, 0, cold.id))).is_equal("copies")
	# Slot 0 already holds Cheese, its offer's only card: "current", not "copies".
	var held: RunState = Kit.locked(three, SEED)
	held.start_setup.regular_offers[StartSetup.offer_key(0, cold.id)] = only_cheese.duplicate()
	held.starter.core_cards[0] = CHEESE
	StartSetupRules.refresh_deck(held)
	assert_str(String(StartSetupRules.target_block(held, three, 0, cold.id))).is_equal("current")


## At most staple_swap_aisle_max swapped regulars come from one aisle.
func test_at_most_two_swapped_regulars_come_from_one_aisle() -> void:
	assert_int(_balance.staple_swap_aisle_max).is_equal(2)
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var cold: AisleDefinition = _balance.aisles[0]
	for slot: int in 2:
		var card: CardDefinition = Kit.option(run, profile, slot, cold)
		assert_object(card).is_not_null()
		run.starter.core_cards[slot] = card
		StartSetupRules.refresh_deck(run)
	assert_object(Kit.option(run, profile, 2, cold)).is_null()
	assert_object(Kit.option(run, profile, 2, _balance.aisles[1])).is_not_null()


## After LOCK IN a swap never makes a third copy of a card in the cart, whichever pack is taken,
## with the baskets; it never re-deals. Before it, a swap only changes what LOCK IN deals, and the
## deal still keeps the copy rule.
func test_swaps_keep_the_copy_rule_and_never_redeal() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var dealt: Array[CardDefinition] = run.start_setup.shared()
	for slot: int in run.starter.core_cards.size():
		for aisle: AisleDefinition in StartSetupRules.completed(_balance, profile):
			for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
				if not StartSetupRules.can_swap(run, profile, slot, card):
					continue
				var core: Array[CardDefinition] = run.starter.core_cards.duplicate()
				core[slot] = card
				for pack: StarterPackDefinition in run.start_offer.packs:
					var count: int = core.count(card) + pack.cards.count(card) + dealt.count(card)
					assert_int(count).is_less_equal(_recipe.copy_max)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	assert_array(run.start_setup.shared()).is_equal(dealt)
	run.starter.core_cards[1] = CHEESE
	run.starter.core_cards[2] = CHEESE
	assert_bool(StartSetupRules.can_swap(run, profile, 3, CHEESE)).is_false()
	# Before LOCK IN: two Cheese regulars, so no basket deals Cheese and Deli counter is not offered.
	var deli: StarterPackDefinition = DELI
	for seed_value: int in range(SEED, SEED + 4):
		var waiting: RunState = Kit.run(profile, seed_value)
		waiting.starter.core_cards[0] = CHEESE
		waiting.starter.core_cards[1] = CHEESE
		StartSetupRules.refresh_deck(waiting)
		assert_str(String(Kit.lock_suggestion(waiting, profile))).is_empty()
		assert_bool(waiting.start_setup.shared().has(CHEESE)).is_false()
		assert_bool(waiting.start_offer.packs.has(deli)).is_false()


## Two regulars saved as Cheese: the Deli counter pack (Bread, Cheese, Butter) is left out of the
## run's recipe, so it is never offered; a third saved Cheese is never applied.
func test_saved_swaps_leave_out_a_pack_that_would_hold_a_third_copy() -> void:
	var profile: ProfileState = Kit.profile(3)
	profile.staple_swaps = [&"cheese", &"cheese"]
	var own: DeckDefinition = StartSetupRules.recipe_for(_recipe, _balance, profile)
	assert_int(own.core_cards.count(CHEESE)).is_equal(2)
	var deli: StarterPackDefinition = DELI
	assert_bool(own.starter_packs.has(deli)).is_false()
	assert_bool(_recipe.starter_packs.has(deli)).is_true()
	for seed_value: int in range(SEED, SEED + 4):
		var run: RunState = Kit.locked(profile, seed_value)
		assert_bool(run.start_offer.packs.has(deli)).is_false()
		assert_bool(run.start_offer.shared.has(CHEESE)).is_false()
	profile.staple_swaps = [&"cheese", &"cheese", &"cheese"]
	own = StartSetupRules.recipe_for(_recipe, _balance, profile)
	assert_int(own.core_cards.count(CHEESE)).is_equal(2)


func test_saved_swaps_a_run_cannot_apply_are_pruned() -> void:
	var profile: ProfileState = Kit.profile(1)
	var cream: CardDefinition = _balance.aisles[0].capsule_cards[0]
	# Slot 1 names a pantry card (not completed), slot 2 a second swap past the one allowed.
	profile.staple_swaps = [cream.id, &"cereal", &"butter"]
	var run: RunState = Kit.run(profile, SEED)
	assert_object(run.starter.core_cards[0]).is_same(cream)
	assert_array(run.starter.core_cards.slice(1)).is_equal(_recipe.core_cards.slice(1))
	assert_bool(StartSetupRules.prune_swaps(profile, run)).is_true()
	assert_array(profile.staple_swaps).is_equal([cream.id, &"", &"", &""])
	assert_bool(StartSetupRules.prune_swaps(profile, run)).is_false()
	var fresh: ProfileState = ProfileState.new()
	assert_bool(StartSetupRules.prune_swaps(fresh, Kit.run(fresh, SEED))).is_false()
	assert_array(fresh.staple_swaps).is_empty()
