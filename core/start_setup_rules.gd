class_name StartSetupRules
extends RefCounted
## The opening-time rules (start screen, full build plan section 7.2; v1.32 "boosters"), as pure
## static functions. The caller owns the named derived streams (EventLogService:
## STOCK_AISLES_STREAM, STARTING_DECK_STREAM, START_BOOSTER_STREAM, START_RESTOCK_STREAM,
## START_REGULARS_STREAM),
## passes them in and saves what changed; nothing here touches the run's own RNG. Saved setup data
## (StartSetup) never depends back on the run or the profile. Every query that can refuse returns
## a reason id (&"" when allowed) the UI shows.
##
## - An aisle is completed when all its items are collected (completed).
## - A run stocks only its boosters' aisles: dealt_aisle_count listable aisles (v1.32 feedback,
##   2026-11-13), the seeded suggestion (suggest_aisles). There is no aisle choice: PICK 2 OF 3
##   (a third booster from 6 completed aisles, keep two) was removed in v1.42 (2026-11-19, the
##   user: "2 aisles picked randomly create more adaptation").
## - The deal (deal, at once for a new run) draws one sealed booster per stocked aisle
##   (StartBoosterDraw.draw): start_booster_size distinct products of the aisle, the last
##   start_booster_hit_slots places hit cards, each RARE (its chain's BIG tier, never GOLDEN) on
##   start_booster_hit_rare_percent; the fair-deal check on the cart (the regulars and the
##   boosters) is met by drawing every booster again on its own stream.
## - Opening (open_booster) only reveals: the contents are fixed at the deal. Swaps wait until
##   every counted booster is open (&"sealed"), so a swap's copy rule never counts a sealed card.
## - RESTOCK (restock, from restock_min_completed completed, restocks_per_run a run) deals one
##   opened booster again from its aisle (a new hit too), differing by at least one card; it is
##   sealed again; the other boosters stay.
## - Each completed aisle unlocks one regular swap, at most one per regular slot: a 5th
##   completed aisle gives nothing (swaps_left). The swap window (v1.32, 2026-11-13) deals one
##   swap booster per stocked aisle, even an aisle not completed: up to
##   regular_offer_max plain-tier products of that aisle the profile owns (is_swap_option), those
##   the copy limit lets into some regular slot first, saved the first time the window
##   shows them (StartSwapBoosters); opening one is saved too and uses no swap. Any number of
##   the swaps may come from one aisle (v1.32: no per-aisle swap limit), and no card goes past the
##   recipe's copy_max in the cart with the boosters (swap_block). A card on
##   a swapped slot trades places with the one there (no extra swap); a swapped card moves to
##   another slot (`from`) the same way; restore and reset_swaps put originals back. Swaps never
##   re-deal. They belong to the run only (v1.08, the user:
##   "swap should reset at each new run"): the run save keeps its own regulars, so a resume keeps
##   them, and every new run starts with the recipe's regulars and its full swap allowance.
## - The starter packs (#107: the pack offer, its pick and NEW PACKS) were removed in v1.41
##   (2026-11-18): the cart is the regulars, the counted boosters and the worn pins' cards; OPEN
##   STORE (RunState.open_store) waits only for the BADGE PINS step (pins_pending).

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


## Today's suggested aisles, in data order: dealt_aisle_count listable aisles, each drawn on `rng`
## (one randi_range each over the listable aisles not yet taken). The pair is always seeded: the
## profile's saved pair (ProfileState.stock_pair) is no longer read.
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
## never carry over to a new run), an empty offer (no boosters dealt) and the stock of the
## suggestion. The caller deals it at once (deal), then the run waits for OPEN STORE.
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
	var offer: StartOffer = StartOffer.new()
	var run: RunState = RunState.new(
		seed_value, StartingDeck.before_pick(own, offer), balance, stock, offer
	)
	run.start_setup = setup
	refresh_deck(run)
	return run


## Why the setup can't be dealt, or &"" when it can: &"stage" (not in SELECT) or &"streams" (a
## stocked aisle without its stream in `booster_rngs`).
static func deal_block(
	run: RunState, booster_rngs: Dictionary[StringName, RandomNumberGenerator]
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.SELECT:
		return &"stage"
	for aisle_id: StringName in setup.stock_aisles:
		if not booster_rngs.has(aisle_id):
			return &"streams"
	return &""


## The deal (deal_block first; returns its reason, changing nothing, when refused): each
## stocked aisle's booster is drawn on its own stream, `booster_rngs[aisle]` (StartBoosterDraw),
## every booster after the first counting the ones before under the copy rule. The fair-deal
## check runs on the cart with the boosters (hands sampled on `deal_rng`, the run seed's
## starting-deck stream): if it fails, every booster is drawn again on its stream, up to
## fair_deal_redeals more times, and the first passing deal is kept (else the first). The
## boosters are sealed; the setup moves to DEALT.
static func deal(
	run: RunState,
	profile: ProfileState,
	deal_rng: RandomNumberGenerator,
	booster_rngs: Dictionary[StringName, RandomNumberGenerator]
) -> StringName:
	var block: StringName = deal_block(run, booster_rngs)
	if block != &"":
		return block
	var setup: StartSetup = run.start_setup
	var balance: BalanceDefinition = run.balance
	rebuild_stock(run, profile)
	var recipe: DeckDefinition = run.starter
	var check: StartingDeck.FairCheck = StartingDeck.fair_check(recipe, balance)
	var aisles: Array[StringName] = setup.stock_aisles.duplicate()
	var options: Array[Array] = []
	for aisle_id: StringName in aisles:
		options.append(StartBoosterDraw.pool(run, profile, aisle_id))
	var offer: StartOffer = run.start_offer
	var best: Array[StartBooster] = []
	for deal_index: int in range(maxi(recipe.fair_deal_redeals, 0) + 1):
		var copies: Dictionary[CardDefinition, int] = StartingDeck.core_copies(recipe)
		var dealt: Array[StartBooster] = []
		var shared: Array[CardDefinition] = []
		for index: int in aisles.size():
			var booster: StartBooster = StartBoosterDraw.draw(
				balance, recipe, aisles[index], options[index], copies, booster_rngs[aisles[index]]
			)
			StartBoosterDraw.count(copies, booster.cards)
			dealt.append(booster)
			shared.append_array(booster.cards)
		if deal_index == 0:
			best = dealt
		offer.deals = deal_index + 1
		if recipe.fair_deal_hands <= 0 or StartingDeck.cart_passes(recipe, shared, check, deal_rng):
			best = dealt
			break
	setup.boosters = best
	offer.shared = setup.shared()
	setup.stage = StartSetup.Stage.DEALT
	refresh_deck(run)
	return &""


## The guided first run's deal (the tutorial), in place of deal and with no stream: `guide`'s
## boosters, sealed with no hit, on its aisles (stocked in data order). Refused (&"stage", or
## `guide`'s block reason) with nothing changed.
static func deal_fixed(
	run: RunState, profile: ProfileState, guide: GuidedStartDefinition
) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.SELECT:
		return &"stage"
	var block: StringName = guide.block(run.balance)
	if block != &"":
		return block
	setup.stock_aisles = ordered_pair(run.balance, guide.aisle_ids())
	setup.boosters.clear()
	for aisle_id: StringName in setup.stock_aisles:
		setup.boosters.append(StartBooster.new(aisle_id, guide.booster_cards(aisle_id)))
	run.start_offer.shared = setup.shared()
	setup.stage = StartSetup.Stage.DEALT
	rebuild_stock(run, profile)
	return &""


## Moves the setup from DEALT to BUILD (page 2 opened). False when nothing changes.
static func mark_build(run: RunState) -> bool:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage != StartSetup.Stage.DEALT:
		return false
	setup.stage = StartSetup.Stage.BUILD
	return true


## Why booster `index` can't be opened, or &"" when it can: &"stage" (nothing dealt), &"none" (no
## such booster) or &"opened" (already open).
static func open_block(run: RunState, index: int) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if index < 0 or index >= setup.boosters.size():
		return &"none"
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


## Why booster `index` can't be restocked, or &"" when it can: &"stage" (nothing dealt yet),
## &"locked" (fewer than restock_min_completed completed aisles), &"used" (the run's RESTOCK is
## spent, or none allowed), &"none" (no such counted booster, or no other booster of its aisle
## keeps the copy rule) or &"sealed" (not opened yet).
static func restock_block(run: RunState, profile: ProfileState, index: int) -> StringName:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT:
		return &"stage"
	if completed(run.balance, profile).size() < run.balance.restock_min_completed:
		return &"locked"
	if setup.restock_booster() >= 0 or run.balance.restocks_per_run <= 0:
		return &"used"
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


## The copies a fresh booster `index` starts from: the regulars and the other counted boosters.
static func _copies_without(run: RunState, index: int) -> Dictionary[CardDefinition, int]:
	var setup: StartSetup = run.start_setup
	var copies: Dictionary[CardDefinition, int] = StartingDeck.core_copies(run.starter)
	for other: int in setup.boosters.size():
		if other != index and setup.is_active(other):
			StartBoosterDraw.count(copies, setup.boosters[other].cards)
	return copies


## RESTOCK booster `index` (restock_block first; returns its reason, changing nothing, when
## refused): a fresh booster of its aisle drawn on `rng` (StartBoosterDraw.draw, its hit rolled
## again), keeping only draws that differ from the old one by at least one card (at most
## RESTOCK_DRAWS_MAX draws in all); the fair-deal check runs on the cart with it (hands sampled
## on `rng`), up to fair_deal_redeals more differing draws, keeping the first whose cart passes,
## else the first. The booster is sealed again and stamped RESTOCKED; the other boosters stay;
## the RESTOCK is spent.
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
	var best: StartBooster = null
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
		if best == null:
			best = fresh
		if (
			run.starter.fair_deal_hands <= 0
			or StartingDeck.cart_passes(run.starter, shared, check, rng)
		):
			best = fresh
			break
		if differing > maxi(run.starter.fair_deal_redeals, 0):
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
## &"copies" (the copy rule: in SELECT the regulars alone; from DEALT with the counted
## boosters). Any number of the swaps may come from
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


## Whether OPEN STORE waits for the BADGE PINS step: `pins_owned` > 0 of the profile's pins
## hold it (ProfilePins.start_gate: earned, bought or worn) and the step isn't confirmed yet
## (confirm_pins).
static func pins_pending(run: RunState, pins_owned: int) -> bool:
	return run.start_setup != null and pins_owned > 0 and not run.start_setup.pins_confirmed


## Confirms the BADGE PINS step (with or without a pin worn). False when
## nothing is dealt yet or it was confirmed before.
static func confirm_pins(run: RunState) -> bool:
	var setup: StartSetup = run.start_setup
	if setup == null or setup.stage == StartSetup.Stage.SELECT or setup.pins_confirmed:
		return false
	setup.pins_confirmed = true
	return true


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


## The opening-time cart, in deck order: the regulars, today's counted boosters (the offer's
## shared products, each line naming its aisle), then the pins' cards.
static func cart_lines(
	starter: DeckDefinition,
	offer: StartOffer,
	balance: BalanceDefinition,
	pins: Array[PinDefinition]
) -> Array[StartCartLine]:
	return _lines(starter, offer.shared, balance, pins)


## The starting cart of a run in play, its start offer gone (the deck view's START marks, the
## cart and run info polish, 2026-11-12): the same lines as cart_lines gave at OPEN STORE, read
## from `starter` (StartingDeck.shared_of).
static func run_cart_lines(
	starter: DeckDefinition, balance: BalanceDefinition, pins: Array[PinDefinition]
) -> Array[StartCartLine]:
	return _lines(starter, StartingDeck.shared_of(starter), balance, pins)


## The cards of `lines`.
static func cart_cards(lines: Array[StartCartLine]) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for line: StartCartLine in lines:
		if line.card != null:
			cards.append(line.card)
	return cards


## Whether the regulars of `recipe` (one changed to `card`) keep the copy rule. In SELECT (nothing
## dealt): the regulars alone; from DEALT with the counted boosters (StartingDeck.fits_copies).
## For a swap (`swapped`), `card` never goes past copy_max.
static func _fits_all(
	run: RunState, recipe: DeckDefinition, card: CardDefinition, swapped: bool
) -> bool:
	var shared: Array[CardDefinition] = []
	if run.start_setup.stage != StartSetup.Stage.SELECT:
		shared = run.start_setup.shared()
	var count: int = StartingDeck.product_count(recipe.core_cards + shared, card)
	if swapped and count > recipe.copy_max:
		return false
	return StartingDeck.fits_copies(recipe, shared)


## The cart's lines: `starter`'s regulars, the `shared` dealt cards by aisle, then `pins`' cards.
static func _lines(
	starter: DeckDefinition,
	shared: Array[CardDefinition],
	balance: BalanceDefinition,
	pins: Array[PinDefinition]
) -> Array[StartCartLine]:
	var lines: Array[StartCartLine] = []
	for card: CardDefinition in starter.core_cards:
		lines.append(StartCartLine.new(card, StartCartLine.Source.REGULAR))
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
