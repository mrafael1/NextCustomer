class_name StartSetupRules
extends RefCounted
## The opening-time rules (start screen, full build plan section 7.2, reworked 2026-11-05), as
## pure static functions. The caller owns the named derived streams (EventLogService:
## STOCK_AISLES_STREAM, STARTING_DECK_STREAM, START_BASKET_STREAM, START_RESTOCK_STREAM,
## START_REGULARS_STREAM, START_NEW_PACKS_STREAM), passes them in and saves what changed; nothing
## here touches the run's own RNG. Saved setup data (StartSetup) never depends back on the run or
## the profile. Every query that can refuse returns a reason id (&"" when allowed) the UI shows.
##
## - An aisle is completed when all its items are collected (completed).
## - Today's stock is stock_aisle_count listable aisles: dealt_aisle_count STARTER CART (green)
##   aisles and the RUN ONLY (orange) rest, the seeded suggestion (suggest_aisles). From
##   pair_choice_min_completed completed aisles (choice_mode) the green ones start as the
##   profile's last choice (stock_pair) and each green basket can change its aisle
##   (change_aisle); the RUN ONLY aisle is always drawn and never a green one's option.
## - The deal (lock_in, at once for a new run since v1.07: no covered baskets) draws the pack
##   offer and deals three baskets of start_basket_size distinct cards, each from its own source
##   only (the staples shelf, each green aisle), with the fair-deal check met by swapping unseen
##   packs or redrawing the baskets. Each source's pair is kept (StartSetup.dealt_sets): a basket
##   switched to another aisle and back gets the same pair.
## - RESTOCK (restock, from restock_min_completed completed, restocks_per_run a run) redraws one
##   basket from the same source, a different set, the other baskets and the packs unchanged.
## - Each completed aisle unlocks one regular swap, at most one per regular slot: a 5th
##   completed aisle gives nothing (swaps_left). A slot's offer from an aisle (regular_offer) is
##   up to regular_offer_max plain-tier products of a completed aisle (is_swap_option), saved the
##   first time it is shown; at most staple_swap_aisle_max swapped regulars come from one aisle,
##   and no card goes past the recipe's copy_max in the cart with every offered pack and the
##   baskets (swap_block). Swaps never re-deal. They belong to the run only (v1.08, the user:
##   "swap should reset at each new run"): the run save keeps its own regulars, so a resume keeps
##   them, and every new run starts with the recipe's regulars and its full swap allowance.
## - NEW PACKS (new_packs, packs_redraws_per_run a run) redraws the offered packs, keeping the
##   baskets, the regulars and the good first pick; the pick is cleared.


## The completed aisles: every item collected, in data order.
static func completed(balance: BalanceDefinition, profile: ProfileState) -> Array[AisleDefinition]:
	var found: Array[AisleDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		if RunStock.items(aisle, profile.unlocked_items).size() == total_items(aisle):
			found.append(aisle)
	return found


static func total_items(aisle: AisleDefinition) -> int:
	return aisle.base_cards.size() + aisle.capsule_cards.size()


## Whether the player sets today's aisles (pair_choice_min_completed completed aisles).
static func choice_mode(balance: BalanceDefinition, profile: ProfileState) -> bool:
	return (
		balance.pair_choice_min_completed > 0
		and completed(balance, profile).size() >= balance.pair_choice_min_completed
	)


## Today's suggested aisles: the green ones in data order, then the orange ones. In choice mode the
## profile's saved green pair (stock_pair) comes first, each place kept only while its aisle is
## listable and distinct; the other places, the RUN ONLY one always (v1.07: today's extra aisle
## stays random), are drawn on `rng` (one randi_range each over the listable aisles not yet taken;
## the first drawn fill the green places).
static func suggest_aisles(
	balance: BalanceDefinition, profile: ProfileState, rng: RandomNumberGenerator
) -> Array[StringName]:
	var listable: Array[StringName] = listable_ids(balance, profile)
	var size: int = mini(balance.stock_aisle_count, listable.size())
	var green_count: int = mini(balance.dealt_aisle_count, size)
	var green: Array[StringName] = []
	var orange: Array[StringName] = []
	if choice_mode(balance, profile):
		for id: StringName in profile.stock_pair:
			if listable.has(id) and not green.has(id) and green.size() < green_count:
				green.append(id)
	while green.size() + orange.size() < size:
		var remaining: Array[StringName] = []
		for id: StringName in listable:
			if not green.has(id) and not orange.has(id):
				remaining.append(id)
		var pick: StringName = remaining[rng.randi_range(0, remaining.size() - 1)]
		if green.size() < green_count:
			green.append(pick)
		else:
			orange.append(pick)
	return ordered_pair(balance, green) + ordered_pair(balance, orange)


## The listable aisles' ids, in data order.
static func listable_ids(balance: BalanceDefinition, profile: ProfileState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for aisle: AisleDefinition in RunStock.listable_aisles(balance, profile.unlocked_items):
		ids.append(aisle.id)
	return ids


## The three baskets' sources for the green aisles `green`: the Staples shelf, then each green
## aisle in data order.
static func basket_sources(
	balance: BalanceDefinition, green: Array[StringName]
) -> Array[StringName]:
	var sources: Array[StringName] = [StartSetup.STAPLES]
	sources.append_array(ordered_pair(balance, green))
	return sources


## Whether `card` is in the swap pool: a plain-tier product of a completed aisle.
static func is_swap_option(
	balance: BalanceDefinition, profile: ProfileState, card: CardDefinition
) -> bool:
	if card == null or not card.is_product() or card.variant_of != null:
		return false
	if card.tier != CardDefinition.Tier.PLAIN:
		return false
	for aisle: AisleDefinition in completed(balance, profile):
		if aisle.base_cards.has(card) or aisle.capsule_cards.has(card):
			return true
	return false


## A new run with the opening-time setup in SELECT: today's suggested aisles drawn on
## `aisle_rng` (suggest_aisles), a run copy of the recipe with its own regulars (no swap: swaps
## never carry over to a new run), an empty offer (no packs, no baskets dealt) and the stock of the
## suggestion. The caller deals it at once (lock_in with the suggestion), then the run waits for
## its pick.
static func setup_run(
	seed_value: int,
	balance: BalanceDefinition,
	recipe: DeckDefinition,
	profile: ProfileState,
	aisle_rng: RandomNumberGenerator
) -> RunState:
	var setup: StartSetup = StartSetup.new()
	setup.originals = recipe.core_cards.duplicate()
	setup.completed_count = completed(balance, profile).size()
	var suggested: Array[StringName] = suggest_aisles(balance, profile, aisle_rng)
	var green_count: int = mini(balance.dealt_aisle_count, suggested.size())
	_set_aisles(setup, balance, suggested.slice(0, green_count), suggested.slice(green_count))
	var stock: RunStock = RunStock.build(
		balance, setup.stock_aisles, profile.unlocked_items, profile.run_count, true
	)
	var own: DeckDefinition = StartingDeck.with_cards(recipe, recipe.cards)
	var offer: StartOffer = StartOffer.new()
	var run: RunState = RunState.new(
		seed_value, StartingDeck.before_pick(own, offer), balance, stock, offer
	)
	run.start_setup = setup
	refresh_deck(run)
	return run


## Why `green` and `run_only` can't be locked in, or &"" when they can: &"stage" (not in
## SELECT), &"count" (not exactly the green and orange places, or an aisle twice), &"listable" (an
## aisle that isn't listable) or &"locked" (below pair_choice_min_completed, aisles other than
## the suggestion).
static func lock_block(
	run: RunState, profile: ProfileState, green: Array[StringName], run_only: Array[StringName]
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.SELECT:
		return &"stage"
	var listable: Array[StringName] = listable_ids(run.balance, profile)
	var size: int = mini(run.balance.stock_aisle_count, listable.size())
	var green_count: int = mini(run.balance.dealt_aisle_count, size)
	var all: Array[StringName] = green + run_only
	if green.size() != green_count or run_only.size() != size - green_count:
		return &"count"
	for id: StringName in all:
		if all.count(id) != 1:
			return &"count"
		if not listable.has(id):
			return &"listable"
	if not choice_mode(run.balance, profile):
		var same_green: bool = ordered_pair(run.balance, green) == setup.green_ids(run.balance)
		var same_orange: bool = (
			ordered_pair(run.balance, run_only) == setup.run_only_ids(run.balance)
		)
		if not same_green or not same_orange:
			return &"locked"
	return &""


## The deal (lock_block first; returns its reason, changing nothing, when refused): today's
## aisles become `green` and `run_only`, the stock is rebuilt, the pack offer is drawn on
## `pack_rng` (the run seed's starting-deck stream: the good first pick in its middle place while
## the profile has never won, the others from the run recipe's packs that fit the current
## regulars), and each basket draws one of its source's card sets (StartingDeck.basket_sets, one
## randi_range) on its own stream, `basket_rngs[source]` (missing: &"streams"), the Staples basket
## first. The fair-deal check runs on each pack's cart (hands sampled on `pack_rng`): a failing
## pack is swapped for an unoffered passing one; if a cart still fails, all baskets are drawn
## again on their streams, up to fair_deal_redeals more times, and the deal with the most passing
## carts is kept. Each basket's pair is kept as its source's (StartSetup.dealt_sets). The setup
## moves to REVEALED with the first pick picked; in choice mode the profile keeps the green pair.
static func lock_in(
	run: RunState,
	profile: ProfileState,
	green: Array[StringName],
	run_only: Array[StringName],
	pack_rng: RandomNumberGenerator,
	basket_rngs: Dictionary[StringName, RandomNumberGenerator]
) -> StringName:
	var block: StringName = lock_block(run, profile, green, run_only)
	if block != &"":
		return block
	for source: StringName in basket_sources(run.balance, green):
		if not basket_rngs.has(source):
			return &"streams"
	var setup: StartSetup = run.start_setup
	_set_aisles(setup, run.balance, green, run_only)
	run.stock = RunStock.build(
		run.balance, setup.stock_aisles, profile.unlocked_items, profile.run_count, true
	)
	var recipe: DeckDefinition = run.starter
	var pool: Array[StarterPackDefinition] = _packs_fitting(
		recipe.starter_packs, recipe.core_cards, setup.originals, recipe.copy_max
	)
	var draw: StartingDeck.PackDraw = StartingDeck.draw_packs(
		recipe, pool, pack_rng, not profile.has_won()
	)
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(recipe, run.balance)
	var options: Array[Array] = []
	for basket: StartBasket in setup.baskets:
		options.append(source_cards(run, basket.source))
	var offer: StartOffer = run.start_offer
	var best: Array[Array] = []
	var best_passing: int = -1
	for deal_index: int in range(maxi(recipe.fair_deal_redeals, 0) + 1):
		var copies: Dictionary[CardDefinition, int] = StartingDeck.copies_for_offer(
			recipe, draw.packs
		)
		var dealt: Array[Array] = []
		var shared: Array[CardDefinition] = []
		for index: int in setup.baskets.size():
			var sets: Array[Array] = StartingDeck.basket_sets(
				options[index], run.balance.start_basket_size, copies, recipe.copy_max
			)
			var rng: RandomNumberGenerator = basket_rngs[setup.baskets[index].source]
			var cards: Array[CardDefinition] = []
			cards.assign(sets[rng.randi_range(0, sets.size() - 1)])
			for card: CardDefinition in cards:
				copies[card.product_card()] = int(copies.get(card.product_card(), 0)) + 1
			dealt.append(cards)
			shared.append_array(cards)
		var fit: StartingDeck.PackFit = StartingDeck.fit_packs(
			recipe, draw.packs, draw.forced, shared, pool, check, pack_rng
		)
		if fit.passing > best_passing:
			best_passing = fit.passing
			best = dealt
			offer.packs = fit.packs
			offer.swaps = fit.swaps
		offer.deals = deal_index + 1
		if fit.passing >= fit.packs.size():
			break
	for index: int in setup.baskets.size():
		setup.baskets[index].cards.assign(best[index])
		setup.dealt_sets[setup.baskets[index].source] = setup.baskets[index].cards.duplicate()
	offer.shared = setup.shared()
	offer.first_pick = draw.forced
	setup.picked = draw.forced.id if draw.forced != null else &""
	setup.stage = StartSetup.Stage.REVEALED
	if choice_mode(run.balance, profile):
		profile.stock_pair = ordered_pair(run.balance, green)
	refresh_deck(run)
	return &""


## The cards basket source `source` deals from in `run`'s stock: the stocked products with an
## item-tier chain (StartingDeck.drawable, capsules with the recipe's random_capsules) that are
## staples (StartSetup.STAPLES) or of that aisle, in stock order.
static func source_cards(run: RunState, source: StringName) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	var chains: Array[ItemUpgradeDefinition] = StartingDeck.chains_for(run.starter, run.balance)
	for card: CardDefinition in StartingDeck.drawable(run.stock, chains):
		if source == StartSetup.STAPLES:
			if run.balance.staples.has(card):
				found.append(card)
			continue
		var aisle: AisleDefinition = run.balance.aisle_of(card)
		if aisle != null and aisle.id == source:
			found.append(card)
	return found


## Moves the setup from REVEALED to BUILD (page 2 opened). False when nothing changes.
static func mark_build(run: RunState) -> bool:
	if run.start_setup == null or run.start_setup.stage != StartSetup.Stage.REVEALED:
		return false
	run.start_setup.stage = StartSetup.Stage.BUILD
	return true


## Why basket `basket` can't be restocked, or &"" when it can: &"stage" (nothing dealt yet),
## &"locked" (fewer than restock_min_completed completed aisles), &"used" (the run's RESTOCK is
## spent, or none allowed) or &"none" (no such basket, or no set of its source sharing no card
## with the current one keeps the copy rule).
static func restock_block(run: RunState, profile: ProfileState, basket: int) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if completed(run.balance, profile).size() < run.balance.restock_min_completed:
		return &"locked"
	if setup.restock_basket >= 0 or run.balance.restocks_per_run <= 0:
		return &"used"
	if basket < 0 or basket >= setup.baskets.size() or restock_options(run, basket).is_empty():
		return &"none"
	return &""


## The card sets basket `basket` could be restocked to: its source's sets (basket_sets) with the
## regulars, the most copies any offered pack holds and the other baskets counted, sharing no card
## with the basket's current set (a RESTOCK replaces both items).
static func restock_options(run: RunState, basket: int) -> Array[Array]:
	var current: Array[CardDefinition] = run.start_setup.baskets[basket].cards
	var found: Array[Array] = []
	for cards: Array in basket_options(run, basket):
		if not cards.any(func(card: CardDefinition) -> bool: return current.has(card)):
			found.append(cards)
	return found


## RESTOCK basket `basket` (restock_block first; returns its reason, changing nothing, when
## refused): one of restock_options drawn on `rng` (one randi_range), the fair-deal check run on
## every offered pack's cart with it (hands sampled on `rng`); up to fair_deal_redeals more draws,
## keeping the first whose carts all pass, else the one with the most passing carts. The other
## baskets and the packs stay; the RESTOCK is spent.
static func restock(
	run: RunState, profile: ProfileState, basket: int, rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = restock_block(run, profile, basket)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var cards: Array[CardDefinition] = _draw_basket(run, basket, restock_options(run, basket), rng)
	_fill_basket(run, basket, cards)
	setup.restock_basket = basket
	setup.restock_source = setup.baskets[basket].source
	return &""


## Basket `basket`'s new pair from `options` (each a card set): one drawn on `rng` (one
## randi_range), the fair-deal check run on every offered pack's cart with it (hands sampled on
## `rng`); up to fair_deal_redeals more draws, keeping the first whose carts all pass, else the
## one with the most passing carts.
static func _draw_basket(
	run: RunState, basket: int, options: Array[Array], rng: RandomNumberGenerator
) -> Array[CardDefinition]:
	var setup: StartSetup = run.start_setup
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(run.starter, run.balance)
	var packs: Array[StarterPackDefinition] = run.start_offer.packs
	var best: Array[CardDefinition] = []
	var best_passing: int = -1
	for _draw: int in range(maxi(run.starter.fair_deal_redeals, 0) + 1):
		var cards: Array[CardDefinition] = []
		cards.assign(options[rng.randi_range(0, options.size() - 1)])
		var shared: Array[CardDefinition] = []
		for index: int in setup.baskets.size():
			shared.append_array(cards if index == basket else setup.baskets[index].cards)
		var passing: int = StartingDeck.passing_carts(run.starter, packs, shared, check, rng)
		if passing > best_passing:
			best_passing = passing
			best = cards
		if passing >= packs.size():
			break
	return best


## Puts `cards` in basket `basket` (kept as its source's pair) and refreshes the offer and deck.
static func _fill_basket(run: RunState, basket: int, cards: Array[CardDefinition]) -> void:
	var setup: StartSetup = run.start_setup
	setup.baskets[basket].cards = cards.duplicate()
	setup.dealt_sets[setup.baskets[basket].source] = cards.duplicate()
	run.start_offer.shared = setup.shared()
	refresh_deck(run)


## The aisles green basket `basket` (1 to dealt_aisle_count) can change to (choice_mode only):
## the completed aisles not stocked today (neither green basket's nor the RUN ONLY one), data
## order. Empty for the Staples basket, outside choice mode or with nothing dealt.
static func aisle_options(run: RunState, profile: ProfileState, basket: int) -> Array[StringName]:
	var found: Array[StringName] = []
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return found
	if basket < 1 or basket >= setup.baskets.size() or not choice_mode(run.balance, profile):
		return found
	var listable: Array[StringName] = listable_ids(run.balance, profile)
	for aisle: AisleDefinition in completed(run.balance, profile):
		if listable.has(aisle.id) and not setup.stock_aisles.has(aisle.id):
			found.append(aisle.id)
	return found


## Why green basket `basket` can't change to aisle `aisle_id`, or &"" when it can: &"stage"
## (nothing dealt), &"locked" (below pair_choice_min_completed completed aisles), &"basket" (the
## Staples basket or no such basket) or &"option" (not one of aisle_options).
static func aisle_block(
	run: RunState, profile: ProfileState, basket: int, aisle_id: StringName
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if not choice_mode(run.balance, profile):
		return &"locked"
	if basket < 1 or basket >= setup.baskets.size():
		return &"basket"
	if not aisle_options(run, profile, basket).has(aisle_id):
		return &"option"
	return &""


## Changes green basket `basket`'s aisle to `aisle_id` (aisle_block first; returns its reason,
## changing nothing, when refused): the aisle takes the basket's place in today's stock (the
## basket stays where it is), the stock is rebuilt and the basket is dealt from the new aisle: its
## pair kept this run (StartSetup.dealt_sets) while it still keeps the copy rule, else one of its
## sets (basket_sets, the regulars, the offered packs and the other baskets counted) drawn as a
## restock is (_draw_basket) on `rng`, the aisle's own basket stream, so the same seed deals the
## same pair. The packs, the pick and the RESTOCK (spent or not) stay; the profile keeps the green
## pair.
static func change_aisle(
	run: RunState,
	profile: ProfileState,
	basket: int,
	aisle_id: StringName,
	rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = aisle_block(run, profile, basket, aisle_id)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	setup.stock_aisles[basket - 1] = aisle_id
	setup.baskets[basket].source = aisle_id
	run.stock = RunStock.build(
		run.balance, setup.stock_aisles, profile.unlocked_items, profile.run_count, true
	)
	var options: Array[Array] = basket_options(run, basket)
	var kept: Array[CardDefinition] = setup.dealt_set(aisle_id)
	var cards: Array[CardDefinition] = []
	for option: Array in options:
		if option.size() == kept.size() and all_in(option, kept):
			cards = kept
	if cards.is_empty() and not options.is_empty():
		cards = _draw_basket(run, basket, options, rng)
	_fill_basket(run, basket, cards)
	profile.stock_pair = ordered_pair(run.balance, setup.green_ids(run.balance))
	return &""


## The card sets basket `basket` could hold: its source's sets (basket_sets) with the regulars,
## the most copies any offered pack holds and the other baskets counted.
static func basket_options(run: RunState, basket: int) -> Array[Array]:
	var setup: StartSetup = run.start_setup
	var copies: Dictionary[CardDefinition, int] = StartingDeck.copies_for_offer(
		run.starter, run.start_offer.packs
	)
	for index: int in setup.baskets.size():
		if index != basket:
			for card: CardDefinition in setup.baskets[index].cards:
				copies[card.product_card()] = int(copies.get(card.product_card(), 0)) + 1
	return StartingDeck.basket_sets(
		source_cards(run, setup.baskets[basket].source),
		run.balance.start_basket_size,
		copies,
		run.starter.copy_max
	)


## Whether every item of `items` is in `others`.
static func all_in(items: Array, others: Array) -> bool:
	for item: Variant in items:
		if not others.has(item):
			return false
	return true


## Regular `slot`'s offer from aisle `aisle_id`: the saved one when shown before; else up to
## regular_offer_max of the aisle's plain-tier products other than the slot's current card
## (is_swap_option, data order; with more, that many drawn on `rng`, one randi_range each), saved
## in the setup (the caller saves the run). Empty for an aisle not completed, a slot out of range
## or an aisle whose only product is the slot's current card.
static func regular_offer(
	run: RunState,
	profile: ProfileState,
	slot: int,
	aisle_id: StringName,
	rng: RandomNumberGenerator
) -> Array[CardDefinition]:
	var setup: StartSetup = run.start_setup
	var saved: Array[CardDefinition] = setup.regular_offer(slot, aisle_id)
	if not saved.is_empty() or slot < 0 or slot >= run.starter.core_cards.size():
		return saved
	var eligible: Array[CardDefinition] = _eligible(run, profile, aisle_id)
	eligible.erase(run.starter.core_cards[slot])
	var offer: Array[CardDefinition] = eligible
	var most: int = run.balance.regular_offer_max
	if eligible.size() > most:
		var drawn: Array[CardDefinition] = []
		var left: Array[CardDefinition] = eligible.duplicate()
		while drawn.size() < most:
			var pick: CardDefinition = left[rng.randi_range(0, left.size() - 1)]
			drawn.append(pick)
			left.erase(pick)
		offer = []
		for card: CardDefinition in eligible:
			if drawn.has(card):
				offer.append(card)
	if not offer.is_empty():
		setup.regular_offers[StartSetup.offer_key(slot, aisle_id)] = offer
	return offer


## Why aisle `aisle_id` can't take a card for regular `slot` (a drag target), or &"" when it can:
## &"slot" (no such slot), &"incomplete" (the aisle isn't completed), &"swaps" (no replacement
## left), &"aisle" (staple_swap_aisle_max other regulars already come from it), &"current" (the
## slot's current card is the only one it offers) or &"copies" (no card of its offer, or of its
## products before the offer is shown, can be swapped in).
static func target_block(
	run: RunState, profile: ProfileState, slot: int, aisle_id: StringName
) -> StringName:
	if slot < 0 or slot >= run.starter.core_cards.size():
		return &"slot"
	var cards: Array[CardDefinition] = _eligible(run, profile, aisle_id)
	if cards.is_empty():
		return &"incomplete"
	var saved: Array[CardDefinition] = run.start_setup.regular_offer(slot, aisle_id)
	if not saved.is_empty():
		cards = saved.duplicate()
	cards.erase(run.starter.core_cards[slot])
	if cards.is_empty():
		return &"current"
	var reason: StringName = &"copies"
	for card: CardDefinition in cards:
		var block: StringName = swap_block(run, profile, slot, card)
		if block == &"":
			return &""
		if block in [&"swaps", &"aisle"]:
			reason = block
	return reason


## A completed aisle's plain-tier products (is_swap_option), in data order; empty otherwise.
static func _eligible(
	run: RunState, profile: ProfileState, aisle_id: StringName
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for aisle: AisleDefinition in completed(run.balance, profile):
		if aisle.id != aisle_id:
			continue
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if is_swap_option(run.balance, profile, card):
				found.append(card)
	return found


## Rebuilds the run's stock from its setup's stocked aisles, and its deck (refresh_deck).
static func rebuild_stock(run: RunState, profile: ProfileState) -> void:
	run.stock = RunStock.build(
		run.balance, run.start_setup.stock_aisles, profile.unlocked_items, profile.run_count, true
	)
	refresh_deck(run)


## Rebuilds the waiting run's deck (its regulars and the dealt baskets) with no RNG step.
static func refresh_deck(run: RunState) -> void:
	var state: int = run.rng_state
	run.starter = StartingDeck.before_pick(run.starter, run.start_offer)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = state
	run.deck = Deck.from_definition(run.starter, rng)


## How many regulars differ from their originals (the swaps the run applied).
static func applied_swaps(run: RunState) -> int:
	var count: int = 0
	for index: int in run.starter.core_cards.size():
		if run.starter.core_cards[index] != run.start_setup.originals[index]:
			count += 1
	return count


## How many regulars the run may swap: one per completed aisle, at most one per regular.
static func swap_limit(run: RunState, profile: ProfileState) -> int:
	return _swap_cap(completed(run.balance, profile).size(), run.starter.core_cards.size())


static func _swap_cap(completed_count: int, regulars: int) -> int:
	return mini(completed_count, regulars)


## The swaps still open: one per completed aisle, at most one per regular, minus those applied.
static func swaps_left(run: RunState, profile: ProfileState) -> int:
	return maxi(0, swap_limit(run, profile) - applied_swaps(run))


## Whether regular `slot` can become `card` (swap_block).
static func can_swap(run: RunState, profile: ProfileState, slot: int, card: CardDefinition) -> bool:
	return swap_block(run, profile, slot, card) == &""


## Why regular `slot` can't become `card`, or &"" when it can: &"option" (not in the swap pool,
## no such slot, or not in the slot's saved offer from its aisle), &"slot" (the slot's current or
## original card), &"swaps" (no swap left once the slot's own is set aside), &"aisle"
## (staple_swap_aisle_max other regulars already come from its aisle) or &"copies" (the copy rule:
## in SELECT the regulars alone, keeping enough packs to offer; from REVEALED with every offered
## pack and the baskets).
static func swap_block(
	run: RunState, profile: ProfileState, slot: int, card: CardDefinition
) -> StringName:
	if slot < 0 or slot >= run.starter.core_cards.size():
		return &"option"
	if not is_swap_option(run.balance, profile, card):
		return &"option"
	var source: AisleDefinition = run.balance.aisle_of(card)
	var saved: Array[CardDefinition] = run.start_setup.regular_offer(slot, source.id)
	if not saved.is_empty() and not saved.has(card):
		return &"option"
	var core: Array[CardDefinition] = run.starter.core_cards
	if card == core[slot] or card == run.start_setup.originals[slot]:
		return &"slot"
	var changed: int = 0
	var in_aisle: int = 0
	for index: int in core.size():
		if index == slot or core[index] == run.start_setup.originals[index]:
			continue
		changed += 1
		if run.balance.aisle_of(core[index]) == source:
			in_aisle += 1
	if changed >= swap_limit(run, profile):
		return &"swaps"
	if in_aisle >= run.balance.staple_swap_aisle_max:
		return &"aisle"
	var recipe: DeckDefinition = StartingDeck.with_cards(run.starter, [])
	recipe.core_cards[slot] = card
	return &"" if _fits_all(run, recipe, card, true) else &"copies"


## Whether regular `slot` (swapped) can go back to its original under the copy rule.
static func can_restore(run: RunState, slot: int) -> bool:
	if slot < 0 or slot >= run.start_setup.originals.size():
		return false
	var original: CardDefinition = run.start_setup.originals[slot]
	if run.starter.core_cards[slot] == original:
		return false
	var recipe: DeckDefinition = StartingDeck.with_cards(run.starter, [])
	recipe.core_cards[slot] = original
	return _fits_all(run, recipe, original, false)


## Puts swapped regular `slot` back to its original (can_restore), so its swap is free again.
## False (nothing changed) when refused.
static func restore(run: RunState, slot: int) -> bool:
	if not can_restore(run, slot):
		return false
	run.starter.core_cards[slot] = run.start_setup.originals[slot]
	refresh_deck(run)
	return true


## Why NEW PACKS can't be used, or &"" when it can: &"stage" (nothing dealt yet), &"used" (the
## run's NEW PACKS is spent, or none allowed) or &"none" (no pack outside the offer fits the cart).
static func new_packs_block(run: RunState, _profile: ProfileState) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if setup.packs_redrawn or run.balance.packs_redraws_per_run <= 0:
		return &"used"
	var fresh: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in _packs_for_cart(run):
		if not run.start_offer.packs.has(pack):
			fresh.append(pack)
	return &"none" if fresh.is_empty() else &""


## NEW PACKS (new_packs_block first; returns its reason, changing nothing, when refused): the good
## first pick (the offer's first_pick) stays in its place; the other places are drawn on `rng`
## (one randi_range each) from the run recipe's packs outside the offer that fit the cart, topped
## up from the offer's other packs when too few; each new cart takes the fair-deal check (hands on
## `rng`), a failing pack swapped for the first passing fitting pack outside the new offer. The
## baskets and the regulars stay; the pick is cleared, the first pick's too (pick a crate again).
static func new_packs(
	run: RunState, profile: ProfileState, rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = new_packs_block(run, profile)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var offer: StartOffer = run.start_offer
	var forced: StarterPackDefinition = offer.first_pick
	var fitting: Array[StarterPackDefinition] = _packs_for_cart(run)
	var fresh: Array[StarterPackDefinition] = []
	var others: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in fitting:
		if not offer.packs.has(pack):
			fresh.append(pack)
	for pack: StarterPackDefinition in offer.packs:
		if pack != forced:
			others.append(pack)
	var wanted: int = offer.packs.size() - (1 if forced != null else 0)
	var drawn: Array[StarterPackDefinition] = []
	_draw_packs_into(drawn, fresh, wanted, rng)
	_draw_packs_into(drawn, others, wanted, rng)
	if forced != null:
		drawn.insert(mini(offer.packs.find(forced), drawn.size()), forced)
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(run.starter, run.balance)
	var fit: StartingDeck.PackFit = StartingDeck.fit_packs(
		run.starter, drawn, forced, setup.shared(), fitting, check, rng
	)
	offer.packs = fit.packs
	setup.packs_redrawn = true
	setup.picked = &""
	refresh_deck(run)
	return &""


## Draws packs of `pool` (in order, one randi_range each, each taken out) into `drawn` until it
## holds `wanted` or `pool` is empty.
static func _draw_packs_into(
	drawn: Array[StarterPackDefinition],
	pool: Array[StarterPackDefinition],
	wanted: int,
	rng: RandomNumberGenerator
) -> void:
	while drawn.size() < wanted and not pool.is_empty():
		var pick: StarterPackDefinition = pool[rng.randi_range(0, pool.size() - 1)]
		drawn.append(pick)
		pool.erase(pick)


## The run recipe's packs that fit the cart: no swapped regular past copy_max with the pack
## (_packs_fitting) and the copy rule kept with the baskets (StartingDeck.fits_copies).
static func _packs_for_cart(run: RunState) -> Array[StarterPackDefinition]:
	var shared: Array[CardDefinition] = run.start_setup.shared()
	var found: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in _packs_fitting(
		run.starter.starter_packs,
		run.starter.core_cards,
		run.start_setup.originals,
		run.starter.copy_max
	):
		if StartingDeck.fits_copies(run.starter, pack.cards, shared):
			found.append(pack)
	return found


## `pair` in data order (balance.aisles), so a choice is a set: the same aisles picked in any
## order key, deal and save the same way. Ids not in the data keep their order at the end.
static func ordered_pair(balance: BalanceDefinition, pair: Array[StringName]) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for aisle: AisleDefinition in balance.aisles:
		if pair.has(aisle.id) and not ordered.has(aisle.id):
			ordered.append(aisle.id)
	for id: StringName in pair:
		if not ordered.has(id):
			ordered.append(id)
	return ordered


## The opening-time cart, in deck order: the regulars, the pack's cards (`pack`; null: one
## waiting line per card of the offer's first pack), today's baskets, then the pins' cards.
## `preview`: the pack is only hovered.
static func cart_lines(
	starter: DeckDefinition,
	offer: StartOffer,
	balance: BalanceDefinition,
	pins: Array[PinDefinition],
	pack: StarterPackDefinition,
	preview: bool = false
) -> Array[StartCartLine]:
	var lines: Array[StartCartLine] = []
	for card: CardDefinition in starter.core_cards:
		lines.append(StartCartLine.new(card, StartCartLine.Source.REGULAR))
	if pack != null:
		for card: CardDefinition in pack.cards:
			lines.append(
				StartCartLine.new(
					card, StartCartLine.Source.PACK, pack.id, pack.display_name, preview
				)
			)
	elif not offer.packs.is_empty():
		for _card: CardDefinition in offer.packs[0].cards:
			lines.append(StartCartLine.new(null, StartCartLine.Source.PACK))
	for card: CardDefinition in offer.shared:
		var aisle: AisleDefinition = balance.aisle_of(card)
		lines.append(
			StartCartLine.new(
				card,
				StartCartLine.Source.DEALT,
				aisle.id if aisle != null else &"",
				aisle.display_name if aisle != null else ""
			)
		)
	for pin: PinDefinition in pins:
		for card: CardDefinition in pin.starting_cards:
			lines.append(
				StartCartLine.new(card, StartCartLine.Source.PIN, pin.id, pin.display_name)
			)
	return lines


## The cards of `lines` (the waiting pack lines left out).
static func cart_cards(lines: Array[StartCartLine]) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for line: StartCartLine in lines:
		if line.card != null:
			cards.append(line.card)
	return cards


## Sets the setup's stocked aisles (`green` in data order, then `run_only`) and its baskets'
## sources, the baskets empty.
static func _set_aisles(
	setup: StartSetup,
	balance: BalanceDefinition,
	green: Array[StringName],
	run_only: Array[StringName]
) -> void:
	setup.stock_aisles = ordered_pair(balance, green) + ordered_pair(balance, run_only)
	setup.baskets.clear()
	for source: StringName in basket_sources(balance, green):
		setup.baskets.append(StartBasket.new(source))


## `packs` without those holding a swapped card (a regular other than its original) past
## copy_max together with the regulars `core`.
static func _packs_fitting(
	packs: Array[StarterPackDefinition],
	core: Array[CardDefinition],
	originals: Array[CardDefinition],
	copy_max: int
) -> Array[StarterPackDefinition]:
	var kept: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in packs:
		var fits: bool = true
		for index: int in core.size():
			var card: CardDefinition = core[index]
			if (
				card != originals[index]
				and StartingDeck.product_count(core + pack.cards, card) > copy_max
			):
				fits = false
		if fits:
			kept.append(pack)
	return kept


## Whether the regulars of `recipe` (one changed to `card`) keep the copy rule. In SELECT (nothing
## dealt): the regulars alone, and enough of the run recipe's packs still fit to fill the offer.
## From REVEALED: with every offered pack and the baskets (StartingDeck.fits_copies) and, for a
## swap (`swapped`), `card` never past copy_max, even where the packs' own copies may go past it.
static func _fits_all(
	run: RunState, recipe: DeckDefinition, card: CardDefinition, swapped: bool
) -> bool:
	var setup: StartSetup = run.start_setup
	if setup.stage == StartSetup.Stage.SELECT:
		if swapped and StartingDeck.product_count(recipe.core_cards, card) > recipe.copy_max:
			return false
		var needed: int = mini(recipe.packs_offered, run.starter.starter_packs.size())
		var packs: Array[StarterPackDefinition] = _packs_fitting(
			recipe.starter_packs, recipe.core_cards, setup.originals, recipe.copy_max
		)
		return packs.size() >= needed
	var shared: Array[CardDefinition] = setup.shared()
	for pack: StarterPackDefinition in run.start_offer.packs:
		var count: int = StartingDeck.product_count(recipe.core_cards + pack.cards + shared, card)
		if swapped and count > recipe.copy_max:
			return false
		if not StartingDeck.fits_copies(recipe, pack.cards, shared):
			return false
	return true
