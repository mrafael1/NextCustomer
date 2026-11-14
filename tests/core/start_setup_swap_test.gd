extends GdUnitTestSuite
## The opening-time regulars (StartSetupRules and StartSwapBoosters, full build plan 7.2; v1.32
## swap window, 2026-11-13): the swap pool of the stocked aisles, one swap booster per stocked
## aisle (saved, the copy limit's fitting cards first), opening one, the swaps' reasons, a trade,
## a move, the undo and RESET, the swap limits and the copy rule with the packs and the boosters,
## swaps that reset each run, and a run in play reading its starting cart, a swapped regular
## included. On the live data.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261104
const CHEESE := preload("res://data/cards/cheese.tres")
const DELI := preload("res://data/starter_packs/deli_counter.tres")
const REPEAT := preload("res://data/cards/repeat.tres")

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## The swap pool: the plain products the profile owns of a stocked aisle, completed or not; never
## a variant, a BIG or GOLDEN tier, a coupon or a product of an aisle not stocked.
func test_the_swap_pool_is_plain_products_of_stocked_aisles() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var stocked: Array[StringName] = StartSwapBoosters.swap_aisles(run)
	assert_int(stocked.size()).is_equal(_balance.dealt_aisle_count)
	for aisle: AisleDefinition in _balance.aisles:
		var pool: Array[CardDefinition] = StartSwapBoosters.swap_pool(run, profile, aisle.id)
		if not stocked.has(aisle.id):
			assert_array(pool).is_empty()
			for card: CardDefinition in aisle.base_cards:
				assert_bool(StartSetupRules.is_swap_option(run, profile, card)).is_false()
			continue
		assert_array(pool).is_not_empty()
		for card: CardDefinition in pool:
			assert_bool(card.variant_of == null).is_true()
			assert_int(card.tier).is_equal(CardDefinition.Tier.PLAIN)
			assert_bool(Kit.of_aisle(card, aisle.id)).is_true()
		var chain: ItemUpgradeDefinition = Kit.chain_of(aisle)
		if chain != null:
			assert_bool(StartSetupRules.is_swap_option(run, profile, chain.big)).is_false()
			assert_bool(StartSetupRules.is_swap_option(run, profile, chain.golden)).is_false()
			assert_str(String(StartSetupRules.swap_block(run, profile, 0, chain.big))).is_equal(
				"option"
			)
	var coupon: CardDefinition = load("res://data/cards/two_for_one.tres")
	assert_bool(StartSetupRules.is_swap_option(run, profile, coupon)).is_false()
	assert_str(String(StartSetupRules.swap_block(run, profile, 0, coupon))).is_equal("option")


## One swap booster per stocked aisle, even one not completed: at most regular_offer_max distinct
## cards of its pool, drawn once and saved (another stream gives the same); none while a counted
## booster is sealed, none for an aisle not stocked.
func test_one_swap_booster_per_stocked_aisle_saved_once_drawn() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var completed: Array[AisleDefinition] = StartSetupRules.completed(_balance, profile)
	var not_completed: int = 0
	for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
		var pool: Array[CardDefinition] = StartSwapBoosters.swap_pool(run, profile, aisle_id)
		var offer: Array[CardDefinition] = StartSwapBoosters.swap_offer(
			run, profile, aisle_id, Kit.regulars_rng(run, aisle_id)
		)
		assert_int(offer.size()).is_equal(mini(pool.size(), _balance.regular_offer_max))
		for card: CardDefinition in offer:
			assert_int(offer.count(card)).is_equal(1)
			assert_bool(pool.has(card)).is_true()
		assert_bool(run.start_setup.has_swap_offer(aisle_id)).is_true()
		assert_array(run.start_setup.swap_offer(aisle_id)).is_equal(offer)
		var other: RandomNumberGenerator = RandomNumberGenerator.new()
		other.seed = 99
		assert_array(StartSwapBoosters.swap_offer(run, profile, aisle_id, other)).is_equal(offer)
		var done: bool = false
		for aisle: AisleDefinition in completed:
			done = done or aisle.id == aisle_id
		if not done:
			not_completed += 1
			assert_array(offer).is_not_empty()
	assert_int(not_completed).is_greater(0)
	var elsewhere: StringName = &""
	for aisle: AisleDefinition in _balance.aisles:
		if not StartSwapBoosters.swap_aisles(run).has(aisle.id):
			elsewhere = aisle.id
	(
		assert_array(
			StartSwapBoosters.swap_offer(run, profile, elsewhere, Kit.regulars_rng(run, elsewhere))
		)
		. is_empty()
	)
	assert_bool(run.start_setup.has_swap_offer(elsewhere)).is_false()
	var sealed: RunState = Kit.dealt(profile, SEED)
	var first: StringName = StartSwapBoosters.swap_aisles(sealed)[0]
	(
		assert_array(
			StartSwapBoosters.swap_offer(sealed, profile, first, Kit.regulars_rng(sealed, first))
		)
		. is_empty()
	)
	assert_bool(sealed.start_setup.has_swap_offer(first)).is_false()


## A swap booster prefers the products the copy limit lets into some slot: every fitting card
## comes before any blocked one, and a blocked one only comes when the fitting ones can't fill it.
func test_a_swap_booster_prefers_cards_that_fit_the_copy_limit() -> void:
	var checked: int = 0
	for seed_value: int in range(SEED, SEED + 6):
		var profile: ProfileState = Kit.profile(3)
		var run: RunState = Kit.locked(profile, seed_value)
		var aisle_id: StringName = StartSwapBoosters.swap_aisles(run)[0]
		var pool: Array[CardDefinition] = StartSwapBoosters.swap_pool(run, profile, aisle_id)
		# Two regulars of one pool card: a third copy anywhere else, so it fits no slot.
		var blocked: CardDefinition = pool[0]
		run.starter.core_cards[0] = blocked
		run.starter.core_cards[1] = blocked
		StartSetupRules.refresh_deck(run)
		assert_bool(StartSwapBoosters.placeable(run, profile, blocked)).is_false()
		var fits: int = 0
		for card: CardDefinition in pool:
			if StartSwapBoosters.placeable(run, profile, card):
				fits += 1
		var offer: Array[CardDefinition] = StartSwapBoosters.swap_offer(
			run, profile, aisle_id, Kit.regulars_rng(run, aisle_id)
		)
		var seen_blocked: bool = false
		for card: CardDefinition in offer:
			var fit: bool = StartSwapBoosters.placeable(run, profile, card)
			assert_bool(fit and seen_blocked).is_false()
			seen_blocked = seen_blocked or not fit
		if fits >= _balance.regular_offer_max:
			assert_bool(offer.has(blocked)).is_false()
		else:
			assert_int(offer.size()).is_equal(mini(pool.size(), _balance.regular_offer_max))
		checked += 1
	assert_int(checked).is_equal(6)


## Opening a swap booster: refused with no swap unlocked or before the window showed it, once
## only; it uses no swap.
func test_opening_a_swap_booster() -> void:
	var profile: ProfileState = Kit.profile(1)
	var run: RunState = Kit.locked(profile, SEED)
	var aisle_id: StringName = StartSwapBoosters.swap_aisles(run)[0]
	assert_str(String(StartSwapBoosters.open_swap_block(run, profile, aisle_id))).is_equal("none")
	Kit.swap_offers(run, profile)
	assert_str(String(StartSwapBoosters.open_swap_booster(run, profile, aisle_id))).is_empty()
	assert_array(run.start_setup.swap_opened).contains_exactly([aisle_id])
	assert_str(String(StartSwapBoosters.open_swap_booster(run, profile, aisle_id))).is_equal(
		"opened"
	)
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(0)
	var none: ProfileState = Kit.profile(0)
	var locked: RunState = Kit.locked(none, SEED)
	var first: StringName = StartSwapBoosters.swap_aisles(locked)[0]
	assert_str(String(StartSwapBoosters.open_swap_block(locked, none, first))).is_equal("locked")


## A swap from a swap booster, a second card on the swapped slot (a trade: no extra swap), the
## card moved to another slot (`from`), the undo and RESET; and the reasons: a card not in its
## booster, the slot's own card, no swap unlocked, a sealed booster.
func test_swap_trade_move_undo_and_reset() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	Kit.swap_offers(run, profile)
	var cards: Array[CardDefinition] = _fitting(run, profile, 0)
	assert_int(cards.size()).is_equal(2)
	var originals: Array[CardDefinition] = run.start_setup.originals
	assert_str(String(StartSetupRules.swap(run, profile, 0, cards[0]))).is_empty()
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(1)
	assert_str(String(StartSetupRules.swap(run, profile, 0, cards[1]))).is_empty()
	assert_object(run.starter.core_cards[0]).is_same(cards[1])
	assert_bool(run.starter.core_cards.has(cards[0])).is_false()
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(1)
	assert_str(String(StartSetupRules.swap(run, profile, 2, cards[1], 0))).is_empty()
	assert_object(run.starter.core_cards[0]).is_same(originals[0])
	assert_object(run.starter.core_cards[2]).is_same(cards[1])
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(1)
	# `from` must hold the card as a swap; the slot's own card is "slot".
	assert_str(String(StartSetupRules.swap_block(run, profile, 1, cards[1], 3))).is_equal("option")
	assert_str(String(StartSetupRules.swap_block(run, profile, 2, cards[1], 2))).is_equal("slot")
	assert_str(String(StartSetupRules.swap_block(run, profile, 2, cards[1]))).is_equal("slot")
	# A pool card left out of its aisle's saved booster can't be swapped in.
	for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
		for card: CardDefinition in StartSwapBoosters.swap_pool(run, profile, aisle_id):
			if not run.start_setup.swap_offer(aisle_id).has(card):
				assert_str(String(StartSetupRules.swap_block(run, profile, 1, card))).is_equal(
					"option"
				)
	assert_bool(StartSetupRules.restore(run, 2)).is_true()
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(0)
	assert_bool(StartSetupRules.can_reset(run)).is_false()
	assert_str(String(StartSetupRules.swap(run, profile, 1, cards[0]))).is_empty()
	assert_str(String(StartSetupRules.swap(run, profile, 3, cards[1]))).is_empty()
	assert_bool(StartSetupRules.reset_swaps(run)).is_true()
	assert_array(run.starter.core_cards).is_equal(originals)
	assert_bool(StartSetupRules.reset_swaps(run)).is_false()
	var none: ProfileState = Kit.profile(0)
	var locked: RunState = Kit.locked(none, SEED)
	var aisle: StringName = StartSwapBoosters.swap_aisles(locked)[0]
	var pool_card: CardDefinition = StartSwapBoosters.swap_pool(locked, none, aisle)[0]
	var slot: int = 0 if originals[0] != pool_card else 1
	assert_str(String(StartSetupRules.swap_block(locked, none, slot, pool_card))).is_equal("locked")
	var sealed: RunState = Kit.dealt(none, SEED)
	assert_str(String(StartSetupRules.swap_block(sealed, none, slot, pool_card))).is_equal("sealed")


## Two cards of one swap booster that fit slot `slot` now (fewer when there are none).
func _fitting(run: RunState, profile: ProfileState, slot: int) -> Array[CardDefinition]:
	for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
		var found: Array[CardDefinition] = []
		for card: CardDefinition in run.start_setup.swap_offer(aisle_id):
			if StartSetupRules.can_swap(run, profile, slot, card):
				found.append(card)
		if found.size() >= 2:
			return found.slice(0, 2)
	return []


## One swap per completed aisle, at most one per regular: the 5th completed aisle gives nothing.
## With none left, a card on a swapped slot still trades.
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


## No per-aisle swap limit (v1.32): every swap may come from one aisle's saved swap booster, within
## swap_limit and the copy limit; past swap_limit no card fits and the refusal is &"swaps".
func test_all_swaps_may_come_from_one_aisle() -> void:
	var checked: int = 0
	for seed_value: int in range(SEED, SEED + 6):
		var profile: ProfileState = Kit.profile(3)
		var run: RunState = Kit.locked(profile, seed_value)
		var limit: int = StartSetupRules.swap_limit(run, profile)
		assert_int(limit).is_equal(3)
		assert_int(run.starter.core_cards.size()).is_greater(limit)
		Kit.swap_offers(run, profile)
		var first: AisleDefinition = _aisle(StartSwapBoosters.swap_aisles(run)[0])
		var offer: Array[CardDefinition] = run.start_setup.swap_offer(first.id)
		# Only a booster whose cards fill every swap (copy limit included) shows the rule.
		var picks: Array[CardDefinition] = []
		for slot: int in limit:
			var card: CardDefinition = Kit.option(run, profile, slot, first)
			if card == null:
				break
			assert_bool(offer.has(card)).is_true()
			assert_str(String(StartSetupRules.swap(run, profile, slot, card))).is_empty()
			picks.append(card)
		if picks.size() < limit:
			continue
		for slot: int in limit:
			assert_bool(Kit.of_aisle(run.starter.core_cards[slot], first.id)).is_true()
			assert_object(run.starter.core_cards[slot]).is_not_equal(
				run.start_setup.originals[slot]
			)
		assert_object(Kit.option(run, profile, limit)).is_null()
		var reasons: Array[StringName] = []
		for card: CardDefinition in offer:
			reasons.append(StartSetupRules.swap_block(run, profile, limit, card))
		assert_bool(reasons.has(&"swaps")).is_true()
		assert_bool(reasons.has(&"aisle")).is_false()
		checked += 1
	assert_int(checked).is_greater(0)


func _aisle(aisle_id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in _balance.aisles:
		if aisle.id == aisle_id:
			return aisle
	return null


## After the deal a swap never makes a third copy of a card in the cart, whichever pack is taken,
## with the boosters; it never re-deals. Before it, a swap only changes what the deal deals, and
## the deal still keeps the copy rule.
func test_swaps_keep_the_copy_rule_and_never_redeal() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	var dealt: Array[CardDefinition] = run.start_setup.shared()
	for slot: int in run.starter.core_cards.size():
		for aisle_id: StringName in StartSwapBoosters.swap_aisles(run):
			for card: CardDefinition in StartSwapBoosters.swap_pool(run, profile, aisle_id):
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
	# Before the deal: two Cheese regulars, so no booster deals Cheese and Deli counter is not
	# offered.
	var deli: StarterPackDefinition = DELI
	for seed_value: int in range(SEED, SEED + 4):
		var waiting: RunState = Kit.run(profile, seed_value)
		waiting.starter.core_cards[0] = CHEESE
		waiting.starter.core_cards[1] = CHEESE
		StartSetupRules.refresh_deck(waiting)
		assert_str(String(Kit.deal(waiting, profile))).is_empty()
		assert_bool(waiting.start_setup.shared().has(CHEESE)).is_false()
		assert_bool(waiting.start_offer.packs.has(deli)).is_false()


## Swaps reset each run (v1.08, the user: "swap should reset at each new run"): after a run spent
## every swap, the next run (from the same profile, or from a version 4 profile that saved swaps)
## starts with the recipe's own regulars, every pack and the full swap allowance.
func test_a_new_run_starts_with_the_recipes_regulars_and_every_swap() -> void:
	var profile: ProfileState = Kit.profile(3)
	var first: RunState = Kit.locked(profile, SEED)
	var allowance: int = StartSetupRules.swaps_left(first, profile)
	assert_int(allowance).is_greater(0)
	for slot: int in allowance:
		assert_bool(Kit.swap(first, profile, slot)).is_true()
	assert_int(StartSetupRules.swaps_left(first, profile)).is_equal(0)
	var v4: Dictionary = Kit.json(profile.to_dictionary())
	v4["format_version"] = 4
	v4["staple_swaps"] = ["cheese", "cheese", "", ""]
	for shown: ProfileState in [profile, ProfileState.from_dictionary(v4)]:
		var next: RunState = Kit.locked(shown, SEED + 1)
		assert_array(next.starter.core_cards).is_equal(_recipe.core_cards)
		assert_array(next.start_setup.originals).is_equal(_recipe.core_cards)
		# Every pack open to the profile (a pack needing a locked aisle, v1.29, is left out).
		assert_array(next.starter.starter_packs).is_equal(
			StartingDeck.open_packs(_recipe.starter_packs, next.balance, shown.unlocked_items)
		)
		assert_int(StartSetupRules.applied_swaps(next)).is_equal(0)
		assert_int(StartSetupRules.swaps_left(next, shown)).is_equal(allowance)


## A run in play (its start offer gone) reads the same starting cart from its dealt deck: the
## regulars (a swapped one in its slot), the picked pack's cards, the booster cards by aisle and
## the pins', with their sources.
func test_a_run_in_play_reads_its_starting_cart_from_its_deck() -> void:
	var profile: ProfileState = Kit.profile(3)
	var run: RunState = Kit.locked(profile, SEED)
	Kit.swap_offers(run, profile)
	assert_bool(Kit.swap(run, profile, 0)).is_true()
	var swapped: CardDefinition = run.starter.core_cards[0]
	assert_object(swapped).is_not_same(run.start_setup.originals[0])
	var pin: PinDefinition = PinDefinition.new()
	pin.id = &"test_pin"
	pin.display_name = "Test pin"
	pin.starting_cards = [REPEAT]
	var pins: Array[PinDefinition] = [pin]
	var pack: StarterPackDefinition = null
	for offered: StarterPackDefinition in run.start_offer.packs:
		if pack == null and StartSetupRules.pick_block(run, profile, offered) == &"":
			pack = offered
	assert_object(pack).is_not_null()
	var expected: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, _balance, pins, pack
	)
	assert_bool(run.take_pack(pack)).is_true()
	var lines: Array[StartCartLine] = StartSetupRules.run_cart_lines(run.starter, _balance, pins)
	assert_int(lines.size()).is_equal(expected.size())
	for index: int in lines.size():
		assert_object(lines[index].card).is_same(expected[index].card)
		assert_int(lines[index].source).is_equal(expected[index].source)
		assert_str(String(lines[index].origin)).is_equal(String(expected[index].origin))
		assert_str(lines[index].origin_name).is_equal(expected[index].origin_name)
	assert_object(lines[0].card).is_same(swapped)
	assert_int(lines[0].source).is_equal(StartCartLine.Source.REGULAR)
	assert_int(lines[run.starter.core_cards.size()].source).is_equal(StartCartLine.Source.PACK)
