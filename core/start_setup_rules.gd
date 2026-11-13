class_name StartSetupRules
extends RefCounted
## The opening-time rules (start screen, full build plan section 7.2; v1.32 "boosters"), as pure
## static functions. The caller owns the named derived streams (EventLogService:
## STOCK_AISLES_STREAM, STARTING_DECK_STREAM, START_BOOSTER_STREAM, START_BOOSTER_EXTRA_STREAM,
## START_BOOSTER_PICK_STREAM, START_RESTOCK_STREAM, START_REGULARS_STREAM, START_NEW_PACKS_STREAM),
## passes them in and saves what changed; nothing here touches the run's own RNG. Saved setup data
## (StartSetup) never depends back on the run or the profile. Every query that can refuse returns
## a reason id (&"" when allowed) the UI shows.
##
## - An aisle is completed when all its items are collected (completed).
## - A run stocks only its boosters' aisles: dealt_aisle_count listable aisles (v1.32 feedback,
##   2026-11-13), the seeded suggestion (suggest_aisles) or the PICK 2 OF 3 pair.
## - The deal (deal, at once for a new run) draws the pack offer and one sealed booster per stocked
##   aisle (StartBoosterDraw.draw): start_booster_size distinct products of the aisle, the last
##   start_booster_hit_slots places hit cards, each RARE (its chain's BIG tier, never GOLDEN) on
##   start_booster_hit_rare_percent; the fair-deal check is met by swapping unseen packs or drawing
##   every booster again on its own stream. From pair_choice_min_completed completed aisles
##   (pick_mode) one more booster of a completed aisle not stocked today is dealt (PICK 2 OF 3):
##   the player picks dealt_aisle_count of them (pick_boosters), the other is SOLD OUT and the
##   unseen pack offer is fitted to the picked pair.
## - Opening (open_booster) only reveals: the contents are fixed at the deal. Swaps wait until
##   every counted booster is open (&"sealed"), so a swap's copy rule never counts a sealed card.
## - RESTOCK (restock, from restock_min_completed completed, restocks_per_run a run) deals one
##   opened booster again from its aisle (a new hit too), differing by at least one card; it is
##   sealed again; the other boosters and the packs stay.
## - Each completed aisle unlocks one regular swap, at most one per regular slot: a 5th
##   completed aisle gives nothing (swaps_left). The swap window (v1.32, 2026-11-13) deals one
##   swap booster per stocked aisle, even an aisle not completed: up to
##   regular_offer_max plain-tier products of that aisle the profile owns (is_swap_option), those
##   the copy limit lets into some regular slot first, saved the first time the window
##   shows them (StartSwapBoosters); opening one is saved too and uses no swap. Any number of
##   the swaps may come from one aisle (v1.32: no per-aisle swap limit), and no card goes past the
##   recipe's copy_max in the cart with every offered pack and the boosters (swap_block). A card on
##   a swapped slot trades places with the one there (no extra swap); a swapped card moves to
##   another slot (`from`) the same way; restore and reset_swaps put originals back. Swaps never
##   re-deal. They belong to the run only (v1.08, the user:
##   "swap should reset at each new run"): the run save keeps its own regulars, so a resume keeps
##   them, and every new run starts with the recipe's regulars and its full swap allowance.
## - NEW PACKS (new_packs, packs_redraws_per_run a run) redraws the offered packs, keeping the
##   boosters, the regulars and the good first pick; the pick is cleared.
## - While the profile owns an earned (or worn) badge pin, the packs wait for the BADGE PINS step
##   (pins_pending: pick_block and new_packs_block give &"pins" until confirm_pins).
## - A pack that needs an aisle (StarterPackDefinition.needs_aisle, v1.29: the Snack stand) is
##   offered, dealt or redrawn only once that aisle is unlocked for the profile
##   (StartingDeck.open_packs).

## Draws made at most for one RESTOCK while looking for a booster that differs from the old one.
const RESTOCK_DRAWS_MAX := 64


## The completed aisles: every item collected, in data order.
static func completed(balance: BalanceDefinition, profile: ProfileState) -> Array[AisleDefinition]:
	var found: Array[AisleDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		if RunStock.items(aisle, profile.unlocked_items).size() == total_items(aisle):
			found.append(aisle)
	return found


static func total_items(aisle: AisleDefinition) -> int:
	return aisle.base_cards.size() + aisle.capsule_cards.size()


## Whether the deal adds PICK 2 OF 3's extra booster (pair_choice_min_completed completed aisles).
static func pick_mode(balance: BalanceDefinition, profile: ProfileState) -> bool:
	return (
		balance.pair_choice_min_completed > 0
		and completed(balance, profile).size() >= balance.pair_choice_min_completed
	)


## Today's suggested aisles, in data order: dealt_aisle_count listable aisles, each drawn on `rng`
## (one randi_range each over the listable aisles not yet taken). The pair is always seeded: from
## pair_choice_min_completed the choice happens at PICK 2 OF 3 (v1.32), so the profile's saved
## pair (ProfileState.stock_pair) is no longer read.
static func suggest_aisles(
	balance: BalanceDefinition, profile: ProfileState, rng: RandomNumberGenerator
) -> Array[StringName]:
	var listable: Array[StringName] = listable_ids(balance, profile)
	var size: int = mini(balance.dealt_aisle_count, listable.size())
	var drawn: Array[StringName] = []
	while drawn.size() < size:
		var remaining: Array[StringName] = []
		for id: StringName in listable:
			if not drawn.has(id):
				remaining.append(id)
		drawn.append(remaining[rng.randi_range(0, remaining.size() - 1)])
	return ordered_pair(balance, drawn)


## The listable aisles' ids, in data order.
static func listable_ids(balance: BalanceDefinition, profile: ProfileState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for aisle: AisleDefinition in RunStock.listable_aisles(balance, profile.unlocked_items):
		ids.append(aisle.id)
	return ids


## The aisles PICK 2 OF 3's extra booster can come from (pick_mode only): the completed listable
## aisles not in `stock_aisles`, data order. Empty below pair_choice_min_completed.
static func extra_aisles(
	balance: BalanceDefinition, profile: ProfileState, stock_aisles: Array[StringName]
) -> Array[StringName]:
	var found: Array[StringName] = []
	if not pick_mode(balance, profile):
		return found
	var listable: Array[StringName] = listable_ids(balance, profile)
	for aisle: AisleDefinition in completed(balance, profile):
		if listable.has(aisle.id) and not stock_aisles.has(aisle.id):
			found.append(aisle.id)
	return found


## Whether `card` is in the run's swap pool: a plain-tier product of one of its stocked aisles
## that the profile owns (RunStock.items: the aisle's base cards and its unlocked capsules).
static func is_swap_option(run: RunState, profile: ProfileState, card: CardDefinition) -> bool:
	if card == null or not card.is_product() or card.variant_of != null:
		return false
	if card.tier != CardDefinition.Tier.PLAIN:
		return false
	var aisle: AisleDefinition = run.balance.aisle_of(card)
	if aisle == null or not run.start_setup.stock_aisles.has(aisle.id):
		return false
	return RunStock.items(aisle, profile.unlocked_items).has(card)


## A new run with the opening-time setup in SELECT: today's suggested aisles drawn on
## `aisle_rng` (suggest_aisles), a run copy of the recipe with its own regulars (no swap: swaps
## never carry over to a new run), an empty offer (no packs, no boosters dealt) and the stock of
## the suggestion. The caller deals it at once (deal), then the run waits for its pick.
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
	setup.stock_aisles = suggest_aisles(balance, profile, aisle_rng)
	var stock: RunStock = RunStock.build(balance, setup.stock_aisles, profile.unlocked_items, true)
	var own: DeckDefinition = StartingDeck.with_cards(recipe, recipe.cards)
	own.starter_packs = StartingDeck.open_packs(
		recipe.starter_packs, balance, profile.unlocked_items
	)
	var offer: StartOffer = StartOffer.new()
	var run: RunState = RunState.new(
		seed_value, StartingDeck.before_pick(own, offer), balance, stock, offer
	)
	run.start_setup = setup
	refresh_deck(run)
	return run


## Why the setup can't be dealt, or &"" when it can: &"stage" (not in SELECT) or &"streams" (a
## dealt aisle, green or a possible PICK 2 OF 3 extra, without its stream in `booster_rngs`).
static func deal_block(
	run: RunState,
	profile: ProfileState,
	booster_rngs: Dictionary[StringName, RandomNumberGenerator]
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.SELECT:
		return &"stage"
	var aisles: Array[StringName] = setup.stock_aisles.duplicate()
	aisles.append_array(extra_aisles(run.balance, profile, setup.stock_aisles))
	for aisle_id: StringName in aisles:
		if not booster_rngs.has(aisle_id):
			return &"streams"
	return &""


## The deal (deal_block first; returns its reason, changing nothing, when refused): the pack offer
## is drawn on `pack_rng` (the run seed's starting-deck stream: the good first pick in its middle
## place while the profile has never won, the others from the run recipe's packs that fit the
## current regulars); in pick_mode PICK 2 OF 3's extra aisle is drawn on `extra_rng` (one
## randi_range over extra_aisles with a product to draw, start_booster_choice_count -
## dealt_aisle_count of them; an extra booster that comes up empty is left out); then each
## booster is drawn on its aisle's own stream, `booster_rngs[aisle]` (StartBoosterDraw), the green
## ones first, every booster after the first counting the ones before under the copy rule (so any
## pair of PICK 2 OF 3 keeps it). The fair-deal check runs on each pack's cart with the counted
## boosters (the green ones; hands sampled on `pack_rng`): a failing pack is swapped for an
## unoffered passing one; if a cart still fails, every booster is drawn again on its stream, up to
## fair_deal_redeals more times, and the deal with the most passing carts is kept. The boosters are
## sealed; the setup moves to DEALT with nothing picked (the good first pick is only suggested:
## the player takes it on page 2).
static func deal(
	run: RunState,
	profile: ProfileState,
	pack_rng: RandomNumberGenerator,
	booster_rngs: Dictionary[StringName, RandomNumberGenerator],
	extra_rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = deal_block(run, profile, booster_rngs)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var balance: BalanceDefinition = run.balance
	rebuild_stock(run, profile)
	var recipe: DeckDefinition = run.starter
	var pool: Array[StarterPackDefinition] = _packs_fitting(
		StartingDeck.open_packs(recipe.starter_packs, balance, profile.unlocked_items),
		recipe.core_cards,
		setup.originals,
		recipe.copy_max
	)
	var draw: StartingDeck.PackDraw = StartingDeck.draw_packs(
		recipe, pool, pack_rng, not profile.has_won()
	)
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(recipe, balance)
	var aisles: Array[StringName] = setup.stock_aisles.duplicate()
	var green_count: int = aisles.size()
	var extras: Array[StringName] = extra_aisles(balance, profile, setup.stock_aisles)
	var extra_count: int = maxi(balance.start_booster_choice_count - balance.dealt_aisle_count, 0)
	var options: Array[Array] = []
	for aisle_id: StringName in aisles:
		options.append(StartBoosterDraw.pool(run, profile, aisle_id))
	# An extra aisle with no product to draw is never offered for PICK 2 OF 3.
	for aisle_id: StringName in extras.duplicate():
		if StartBoosterDraw.pool(run, profile, aisle_id).is_empty():
			extras.erase(aisle_id)
	while extras.size() > 0 and aisles.size() < green_count + extra_count:
		var pick: StringName = extras[extra_rng.randi_range(0, extras.size() - 1)]
		aisles.append(pick)
		options.append(StartBoosterDraw.pool(run, profile, pick))
		extras.erase(pick)
	var offer: StartOffer = run.start_offer
	var best: Array[StartBooster] = []
	var best_passing: int = -1
	for deal_index: int in range(maxi(recipe.fair_deal_redeals, 0) + 1):
		var copies: Dictionary[CardDefinition, int] = StartingDeck.copies_for_offer(
			recipe, draw.packs
		)
		var dealt: Array[StartBooster] = []
		var shared: Array[CardDefinition] = []
		for index: int in aisles.size():
			var booster: StartBooster = StartBoosterDraw.draw(
				balance, recipe, aisles[index], options[index], copies, booster_rngs[aisles[index]]
			)
			# An extra booster that comes up empty (every product at copy_max) is left out: no
			# empty booster is offered for PICK 2 OF 3 (with none left, there is no pick).
			if index >= green_count and booster.cards.is_empty():
				continue
			StartBoosterDraw.count(copies, booster.cards)
			dealt.append(booster)
			if index < green_count:
				shared.append_array(booster.cards)
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
	setup.boosters = best
	offer.shared = setup.shared()
	offer.first_pick = draw.forced
	setup.picked = &""
	setup.stage = StartSetup.Stage.DEALT
	refresh_deck(run)
	return &""


## Moves the setup from DEALT to BUILD (page 2 opened). False when nothing changes, or while
## PICK 2 OF 3 is pending.
static func mark_build(run: RunState) -> bool:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.DEALT or setup.picking():
		return false
	setup.stage = StartSetup.Stage.BUILD
	return true


## Why booster `index` can't be opened, or &"" when it can: &"stage" (nothing dealt), &"none" (no
## such booster), &"picking" (PICK 2 OF 3 pending), &"sold_out" or &"opened" (already open).
static func open_block(run: RunState, index: int) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if index < 0 or index >= setup.boosters.size():
		return &"none"
	if setup.picking():
		return &"picking"
	if setup.boosters[index].sold_out:
		return &"sold_out"
	if setup.boosters[index].opened:
		return &"opened"
	return &""


## Opens booster `index` (open_block first; returns its reason, changing nothing, when refused).
## Opening only reveals: its cards were fixed at the deal.
static func open_booster(run: RunState, index: int) -> StringName:
	var block: StringName = open_block(run, index)
	if block != &"":
		return block
	run.start_setup.boosters[index].opened = true
	return &""


## Why PICK 2 OF 3 can't keep boosters `picks` (indices), or &"" when it can: &"stage" (nothing
## dealt), &"none" (no pick pending) or &"count" (not dealt_aisle_count distinct boosters).
static func pick_boosters_block(run: RunState, picks: Array[int]) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if not setup.picking():
		return &"none"
	if picks.size() != setup.stock_aisles.size():
		return &"count"
	for index: int in picks:
		if index < 0 or index >= setup.boosters.size() or picks.count(index) != 1:
			return &"count"
	return &""


## PICK 2 OF 3 (pick_boosters_block first; returns its reason, changing nothing, when refused):
## the boosters not in `picks` are SOLD OUT (their cards never count), the stocked aisles become
## the picked boosters' (data order: the run stocks only them), the stock is rebuilt, and the unseen
## pack offer is fitted to the picked pair on `rng`: a pack past the copy rule with the pair is
## replaced first (_refit_copies), then StartingDeck.fit_packs swaps a failing pack other than the
## good first pick for a passing fitting one. A picked pack no longer offered is
## cleared (nothing picked).
static func pick_boosters(
	run: RunState, profile: ProfileState, picks: Array[int], rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = pick_boosters_block(run, picks)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var green: Array[StringName] = []
	for index: int in setup.boosters.size():
		if picks.has(index):
			green.append(setup.boosters[index].aisle)
		else:
			setup.boosters[index].sold_out = true
	setup.stock_aisles = ordered_pair(run.balance, green)
	rebuild_stock(run, profile)
	var offer: StartOffer = run.start_offer
	var pool: Array[StarterPackDefinition] = _packs_fitting(
		StartingDeck.open_packs(run.starter.starter_packs, run.balance, profile.unlocked_items),
		run.starter.core_cards,
		setup.originals,
		run.starter.copy_max
	)
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(run.starter, run.balance)
	var shared: Array[CardDefinition] = setup.shared()
	offer.swaps += _refit_copies(run, offer, shared, pool, check, rng)
	var fit: StartingDeck.PackFit = StartingDeck.fit_packs(
		run.starter, offer.packs, offer.first_pick, shared, pool, check, rng
	)
	offer.packs = fit.packs
	offer.swaps += fit.swaps
	offer.shared = setup.shared()
	if setup.picked != &"" and offer.pack(setup.picked) == null:
		setup.picked = &""
	refresh_deck(run)
	return &""


## PICK 2 OF 3's copy rule on the offer: a pack the deal swapped in for the fair-deal check was
## only checked against the seeded pair, so with the extra booster kept it may go past copy_max.
## Each offered pack (the good first pick aside: the boosters were drawn against it) that no
## longer fits the copy rule with `shared` is replaced by a pack of `pool` not offered that fits,
## drawn on `rng` among those whose cart passes the fair-deal check (else among every fitting
## one). Returns how many packs were replaced.
static func _refit_copies(
	run: RunState,
	offer: StartOffer,
	shared: Array[CardDefinition],
	pool: Array[StarterPackDefinition],
	check: StartingDeck.FairCheck,
	rng: RandomNumberGenerator
) -> int:
	var recipe: DeckDefinition = run.starter
	var replaced: int = 0
	for index: int in offer.packs.size():
		var pack: StarterPackDefinition = offer.packs[index]
		if pack == offer.first_pick or StartingDeck.fits_copies(recipe, pack.cards, shared):
			continue
		var fitting: Array[StarterPackDefinition] = []
		var passing: Array[StarterPackDefinition] = []
		for candidate: StarterPackDefinition in pool:
			if offer.packs.has(candidate):
				continue
			if not StartingDeck.fits_copies(recipe, candidate.cards, shared):
				continue
			fitting.append(candidate)
			if (
				recipe.fair_deal_hands <= 0
				or StartingDeck.cart_passes(recipe, candidate, shared, check, rng)
			):
				passing.append(candidate)
		var choices: Array[StarterPackDefinition] = passing if not passing.is_empty() else fitting
		if choices.is_empty():
			continue
		offer.packs[index] = choices[rng.randi_range(0, choices.size() - 1)]
		replaced += 1
	return replaced


## Why booster `index` can't be restocked, or &"" when it can: &"stage" (nothing dealt yet),
## &"locked" (fewer than restock_min_completed completed aisles), &"used" (the run's RESTOCK is
## spent, or none allowed), &"none" (no such counted booster, or no other booster of its aisle
## keeps the copy rule) or &"sealed" (not opened yet; PICK 2 OF 3 pending too).
static func restock_block(run: RunState, profile: ProfileState, index: int) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if completed(run.balance, profile).size() < run.balance.restock_min_completed:
		return &"locked"
	if setup.restock_booster() >= 0 or run.balance.restocks_per_run <= 0:
		return &"used"
	if setup.picking() and index >= 0 and index < setup.boosters.size():
		return &"sealed"
	if not setup.is_active(index):
		return &"none"
	if not setup.boosters[index].opened:
		return &"sealed"
	if not _can_differ(run, profile, index):
		return &"none"
	return &""


## Whether a fresh booster of booster `index`'s aisle could differ from it by at least one card
## under the copy rule without coming up shorter: an open product it doesn't hold; else, with
## exactly its products open, a hit card's tier that can change (a RARE odds strictly between 0
## and 100 with a product that has a BIG tier, or at 100 two such products to trade places).
static func _can_differ(run: RunState, profile: ProfileState, index: int) -> bool:
	var booster: StartBooster = run.start_setup.boosters[index]
	var copies: Dictionary[CardDefinition, int] = _copies_without(run, index)
	var held: Array[CardDefinition] = []
	for card: CardDefinition in booster.cards:
		held.append(card.product_card())
	var open: Array[CardDefinition] = []
	for card: CardDefinition in StartBoosterDraw.pool(run, profile, booster.aisle):
		if card.draw_weight > 0 and int(copies.get(card, 0)) < run.starter.copy_max:
			open.append(card)
	if open.any(func(card: CardDefinition) -> bool: return not held.has(card)):
		return true
	if open.size() < held.size() or run.balance.start_booster_hit_slots <= 0:
		return false
	var table: Array[ItemUpgradeDefinition] = []
	if run.balance.machine != null:
		table = run.balance.machine.item_upgrades
	var bigs: int = 0
	for card: CardDefinition in open:
		if StartBoosterDraw.big_of(table, card) != null:
			bigs += 1
	var percent: int = run.balance.start_booster_hit_rare_percent
	return (percent > 0 and percent < 100 and bigs > 0) or (percent >= 100 and bigs > 1)


## The copies a fresh booster `index` starts from: the regulars, the most copies any offered pack
## holds and the other counted boosters.
static func _copies_without(run: RunState, index: int) -> Dictionary[CardDefinition, int]:
	var setup: StartSetup = run.start_setup
	var copies: Dictionary[CardDefinition, int] = StartingDeck.copies_for_offer(
		run.starter, run.start_offer.packs
	)
	for other: int in setup.boosters.size():
		if other != index and setup.is_active(other):
			StartBoosterDraw.count(copies, setup.boosters[other].cards)
	return copies


## RESTOCK booster `index` (restock_block first; returns its reason, changing nothing, when
## refused): a fresh booster of its aisle drawn on `rng` (StartBoosterDraw.draw, its hit rolled
## again), keeping only draws that differ from the old one by at least one card (at most
## RESTOCK_DRAWS_MAX draws in all); the fair-deal check runs on every offered pack's cart with it
## (hands sampled on `rng`), up to fair_deal_redeals more differing draws, keeping the first whose
## carts all pass, else the one with the most passing carts. The booster is sealed again and
## stamped RESTOCKED; the other boosters and the packs stay; the RESTOCK is spent.
static func restock(
	run: RunState, profile: ProfileState, index: int, rng: RandomNumberGenerator
) -> StringName:
	var block: StringName = restock_block(run, profile, index)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var old: StartBooster = setup.boosters[index]
	var options: Array[CardDefinition] = StartBoosterDraw.pool(run, profile, old.aisle)
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(run.starter, run.balance)
	var packs: Array[StarterPackDefinition] = run.start_offer.packs
	var best: StartBooster = null
	var best_passing: int = -1
	var differing: int = 0
	for _draw: int in RESTOCK_DRAWS_MAX:
		var fresh: StartBooster = StartBoosterDraw.draw(
			run.balance, run.starter, old.aisle, options, _copies_without(run, index), rng
		)
		if not _differs(fresh.cards, old.cards):
			continue
		differing += 1
		var shared: Array[CardDefinition] = []
		for other: int in setup.boosters.size():
			if other == index:
				shared.append_array(fresh.cards)
			elif setup.is_active(other):
				shared.append_array(setup.boosters[other].cards)
		var passing: int = StartingDeck.passing_carts(run.starter, packs, shared, check, rng)
		if passing > best_passing:
			best_passing = passing
			best = fresh
		if passing >= packs.size() or differing > maxi(run.starter.fair_deal_redeals, 0):
			break
	if best == null:
		return &"none"
	best.restocked = true
	setup.boosters[index] = best
	run.start_offer.shared = setup.shared()
	refresh_deck(run)
	return &""


## Whether `cards` and `others` differ by at least one card (as sets of cards).
static func _differs(cards: Array[CardDefinition], others: Array[CardDefinition]) -> bool:
	if cards.size() != others.size():
		return true
	for card: CardDefinition in cards:
		if not others.has(card):
			return true
	return false


## Rebuilds the run's stock from its setup's stocked aisles, and its deck (refresh_deck).
static func rebuild_stock(run: RunState, profile: ProfileState) -> void:
	run.stock = RunStock.build(
		run.balance, run.start_setup.stock_aisles, profile.unlocked_items, true
	)
	refresh_deck(run)


## Rebuilds the waiting run's deck (its regulars and the counted boosters) with no RNG step.
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
static func can_swap(
	run: RunState, profile: ProfileState, slot: int, card: CardDefinition, from: int = -1
) -> bool:
	return swap_block(run, profile, slot, card, from) == &""


## Why regular `slot` can't become `card`, or &"" when it can. `from` (>= 0) is another slot that
## holds `card` as a swap: the card moves from there and that slot gets its original back. The
## reasons: &"option" (not in the swap pool, no such slot, not in its aisle's saved swap booster,
## or `from` doesn't hold it as a swap), &"sealed" (a counted booster is still sealed: its cards
## must never count before they are shown), &"slot" (the slot's current or original card),
## &"locked" (no swap unlocked: no completed aisle), &"swaps" (no swap left once the slot's own,
## and `from`'s, is set aside: a card on a swapped slot trades places and uses none) or
## &"copies" (the copy rule: in SELECT the regulars alone, keeping enough packs to offer; from
## DEALT with every offered pack and the counted boosters). Any number of the swaps may come from
## one aisle.
static func swap_block(
	run: RunState, profile: ProfileState, slot: int, card: CardDefinition, from: int = -1
) -> StringName:
	var core: Array[CardDefinition] = run.starter.core_cards
	var originals: Array[CardDefinition] = run.start_setup.originals
	if slot < 0 or slot >= core.size():
		return &"option"
	if not run.start_setup.all_open():
		return &"sealed"
	if not is_swap_option(run, profile, card):
		return &"option"
	var source: AisleDefinition = run.balance.aisle_of(card)
	if (
		run.start_setup.has_swap_offer(source.id)
		and not run.start_setup.swap_offer(source.id).has(card)
	):
		return &"option"
	if from >= 0 and (from >= core.size() or core[from] != card or card == originals[from]):
		return &"option"
	if from == slot or card == core[slot] or card == originals[slot]:
		return &"slot"
	if swap_limit(run, profile) <= 0:
		return &"locked"
	var changed: int = 0
	for index: int in core.size():
		if index == slot or index == from or core[index] == originals[index]:
			continue
		changed += 1
	if changed >= swap_limit(run, profile):
		return &"swaps"
	return &"" if copies_fit(run, slot, card, from) else &"copies"


## Whether the regulars with `card` in `slot` (and `from`, when >= 0, back to its original) keep
## the copy rule (_fits_all).
static func copies_fit(run: RunState, slot: int, card: CardDefinition, from: int) -> bool:
	var recipe: DeckDefinition = StartingDeck.with_cards(run.starter, [])
	if from >= 0:
		recipe.core_cards[from] = run.start_setup.originals[from]
	recipe.core_cards[slot] = card
	return _fits_all(run, recipe, card, true)


## Swaps regular `slot` to `card` (swap_block; `from`: the slot it moves from, which gets its
## original back) and rebuilds the deck. Returns the reason it was refused, &"" when done (the
## caller saves the run).
static func swap(
	run: RunState, profile: ProfileState, slot: int, card: CardDefinition, from: int = -1
) -> StringName:
	var block: StringName = swap_block(run, profile, slot, card, from)
	if block != &"":
		return block
	if from >= 0:
		run.starter.core_cards[from] = run.start_setup.originals[from]
	run.starter.core_cards[slot] = card
	refresh_deck(run)
	return &""


## Whether regular `slot` (swapped) can go back to its original under the copy rule (never
## while a counted booster is sealed, as swaps).
static func can_restore(run: RunState, slot: int) -> bool:
	if slot < 0 or slot >= run.start_setup.originals.size() or not run.start_setup.all_open():
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


## Whether every swapped regular can go back to its original at once (the swap window's RESET):
## some regular is swapped, no counted booster is sealed, and the originals keep the copy rule.
static func can_reset(run: RunState) -> bool:
	if applied_swaps(run) == 0 or not run.start_setup.all_open():
		return false
	var recipe: DeckDefinition = StartingDeck.with_cards(run.starter, [])
	recipe.core_cards = run.start_setup.originals.duplicate()
	return _fits_all(run, recipe, recipe.core_cards[0], false)


## RESET: every regular back to its original (can_reset), every swap free again. False (nothing
## changed) when refused.
static func reset_swaps(run: RunState) -> bool:
	if not can_reset(run):
		return false
	run.starter.core_cards = run.start_setup.originals.duplicate()
	refresh_deck(run)
	return true


## Whether the packs wait for the BADGE PINS step: `pins_owned` > 0 of the profile's pins hold
## the packs (ProfilePins.start_gate: earned, bought or worn) and the step isn't confirmed yet
## (confirm_pins).
static func pins_pending(run: RunState, pins_owned: int) -> bool:
	return run.start_setup != null and pins_owned > 0 and not run.start_setup.pins_confirmed


## Confirms the BADGE PINS step (with or without a pin worn), so the packs deal. False when
## nothing is dealt yet or it was confirmed before.
static func confirm_pins(run: RunState) -> bool:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT or setup.pins_confirmed:
		return false
	setup.pins_confirmed = true
	return true


## Why pack `pack` can't be picked, or &"" when it can: &"stage" (nothing dealt yet), &"picking"
## (PICK 2 OF 3 pending), &"pins" (the BADGE PINS step first, pins_pending with `pins_owned`),
## &"offer" (not offered) or &"copies" (it no longer fits the cart: a swapped regular or a
## booster card past copy_max with it, as NEW PACKS' fitting packs).
static func pick_block(
	run: RunState, profile: ProfileState, pack: StarterPackDefinition, pins_owned: int = 0
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if setup.picking():
		return &"picking"
	if pins_pending(run, pins_owned):
		return &"pins"
	if pack == null or not run.start_offer.packs.has(pack):
		return &"offer"
	return &"" if _packs_for_cart(run, profile).has(pack) else &"copies"


## Why NEW PACKS can't be used, or &"" when it can: &"stage" (nothing dealt yet), &"picking"
## (PICK 2 OF 3 pending), &"pins" (the BADGE PINS step first, pins_pending with `pins_owned`),
## &"used" (the run's NEW PACKS is spent, or none allowed) or &"none" (no pack outside the offer
## fits the cart).
static func new_packs_block(
	run: RunState, profile: ProfileState, pins_owned: int = 0
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if setup.picking():
		return &"picking"
	if pins_pending(run, pins_owned):
		return &"pins"
	if setup.packs_redrawn or run.balance.packs_redraws_per_run <= 0:
		return &"used"
	var fresh: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in _packs_for_cart(run, profile):
		if not run.start_offer.packs.has(pack):
			fresh.append(pack)
	return &"none" if fresh.is_empty() else &""


## NEW PACKS (new_packs_block first; returns its reason, changing nothing, when refused): the
## picked pack stays in its place and stays picked (v1.32, mock-up start_boosters_v3 N5: after a
## pick it re-deals the other two); with nothing picked the good first pick (the offer's
## first_pick) stays in its place. The other places are drawn on `rng` (one randi_range each) from
## the run recipe's packs outside the offer that fit the cart, topped up from the offer's other
## packs when too few; each new cart takes the fair-deal check (hands on `rng`), a failing pack
## swapped for the first passing fitting pack outside the new offer. The boosters and the regulars
## stay. A first pick that leaves the offer is no longer the offer's first_pick.
static func new_packs(
	run: RunState, profile: ProfileState, rng: RandomNumberGenerator, pins_owned: int = 0
) -> StringName:
	var block: StringName = new_packs_block(run, profile, pins_owned)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var offer: StartOffer = run.start_offer
	var kept: StarterPackDefinition = offer.pack(setup.picked) if setup.picked != &"" else null
	var forced: StarterPackDefinition = kept if kept != null else offer.first_pick
	var fitting: Array[StarterPackDefinition] = _packs_for_cart(run, profile)
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
	if not offer.packs.has(offer.first_pick):
		offer.first_pick = null
	setup.packs_redrawn = true
	setup.picked = kept.id if kept != null and offer.packs.has(kept) else &""
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


## The run recipe's packs that fit the cart: open to `profile` (StartingDeck.open_packs, v1.29),
## no swapped regular past copy_max with the pack (_packs_fitting) and the copy rule kept with the
## counted boosters (StartingDeck.fits_copies).
static func _packs_for_cart(run: RunState, profile: ProfileState) -> Array[StarterPackDefinition]:
	var shared: Array[CardDefinition] = run.start_setup.shared()
	var found: Array[StarterPackDefinition] = []
	for pack: StarterPackDefinition in _packs_fitting(
		StartingDeck.open_packs(run.starter.starter_packs, run.balance, profile.unlocked_items),
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
## waiting line per card of the offer's first pack), today's counted boosters (the offer's
## shared products, each line naming its aisle), then the pins' cards.
## `preview`: the pack is only hovered.
static func cart_lines(
	starter: DeckDefinition,
	offer: StartOffer,
	balance: BalanceDefinition,
	pins: Array[PinDefinition],
	pack: StarterPackDefinition,
	preview: bool = false
) -> Array[StartCartLine]:
	var waiting: int = 0
	if pack == null and not offer.packs.is_empty():
		waiting = offer.packs[0].cards.size()
	return _lines(starter, pack, waiting, offer.shared, balance, pins, preview)


## The starting cart of a run in play, its start offer gone (the deck view's START marks, the
## cart and run info polish, 2026-11-12): the same lines as cart_lines gave once the pack was
## picked, read from `starter` (StartingDeck.with_pack: its pack and its dealt cards,
## StartingDeck.shared_of).
static func run_cart_lines(
	starter: DeckDefinition, balance: BalanceDefinition, pins: Array[PinDefinition]
) -> Array[StartCartLine]:
	var shared: Array[CardDefinition] = StartingDeck.shared_of(starter)
	return _lines(starter, starter.starter_pack, 0, shared, balance, pins, false)


## The cards of `lines` (the waiting pack lines left out).
static func cart_cards(lines: Array[StartCartLine]) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for line: StartCartLine in lines:
		if line.card != null:
			cards.append(line.card)
	return cards


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
## From DEALT: with every offered pack and the counted boosters (StartingDeck.fits_copies) and,
## for a swap (`swapped`), `card` never past copy_max, even where the packs' own copies may go past
## it.
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


## The cart's lines: `starter`'s regulars, `pack`'s cards (or `waiting` waiting lines), the
## `shared` dealt cards by aisle, then `pins`' cards.
static func _lines(
	starter: DeckDefinition,
	pack: StarterPackDefinition,
	waiting: int,
	shared: Array[CardDefinition],
	balance: BalanceDefinition,
	pins: Array[PinDefinition],
	preview: bool
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
	for _waiting: int in waiting:
		lines.append(StartCartLine.new(null, StartCartLine.Source.PACK))
	for card: CardDefinition in shared:
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
