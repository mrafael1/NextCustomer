class_name StartSwapBoosters
extends RefCounted
## The swap window's boosters (v1.32, 2026-11-13; StartSetupRules has the swaps themselves), as
## pure static functions: one swap booster per stocked aisle, even an aisle not completed, of up to
## regular_offer_max plain-tier products of that aisle the profile owns
## (StartSetupRules.is_swap_option), those the copy limit lets into some regular slot first
## (placeable). The caller passes the aisle's START_REGULARS_STREAM and saves the run: an offer is
## kept in the setup the first time the window shows it, so reopening the window (or a resume)
## never rerolls it, and opening a swap booster is saved too and uses no swap.


## The swap window's aisles: the active boosters' aisles, in board order (one swap booster each).
static func swap_aisles(run: RunState) -> Array[StringName]:
	var found: Array[StringName] = []
	for booster: StartBooster in run.start_setup.active_boosters():
		found.append(booster.aisle)
	return found


## Aisle `aisle_id`'s swap pool (is_swap_option), in data order; empty for an aisle not stocked.
static func swap_pool(
	run: RunState, profile: ProfileState, aisle_id: StringName
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for aisle: AisleDefinition in run.balance.aisles:
		if aisle.id != aisle_id:
			continue
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if StartSetupRules.is_swap_option(run, profile, card):
				found.append(card)
	return found


## Aisle `aisle_id`'s swap booster: the saved one when the window showed it before; else up to
## regular_offer_max of its swap pool (swap_pool), drawn on `rng` (one randi_range each) from the
## products that fit some regular slot under the copy limit (placeable) first and from the rest
## only when those are too few, the fitting ones first, each part in data order. Saved in the
## setup the first time (the caller saves the run). Empty, and not saved, for an aisle not stocked
## or while a counted booster is sealed (its cards must never count before they are shown).
static func swap_offer(
	run: RunState, profile: ProfileState, aisle_id: StringName, rng: RandomNumberGenerator
) -> Array[CardDefinition]:
	var setup: StartSetup = run.start_setup
	if setup.has_swap_offer(aisle_id):
		return setup.swap_offer(aisle_id)
	if not swap_aisles(run).has(aisle_id) or not setup.all_open():
		return []
	var fits: Array[CardDefinition] = []
	var rest: Array[CardDefinition] = []
	for card: CardDefinition in swap_pool(run, profile, aisle_id):
		if placeable(run, profile, card):
			fits.append(card)
		else:
			rest.append(card)
	var most: int = maxi(run.balance.regular_offer_max, 0)
	var offer: Array[CardDefinition] = _draw_some(fits, most, rng)
	offer.append_array(_draw_some(rest, most - offer.size(), rng))
	setup.swap_offers[String(aisle_id)] = offer
	return offer


## `count` of `cards` drawn on `rng` (one randi_range each), in the order of `cards`; all of
## them when there are no more than `count`.
static func _draw_some(
	cards: Array[CardDefinition], count: int, rng: RandomNumberGenerator
) -> Array[CardDefinition]:
	if count <= 0:
		return []
	if cards.size() <= count:
		return cards.duplicate()
	var drawn: Array[CardDefinition] = []
	var left: Array[CardDefinition] = cards.duplicate()
	while drawn.size() < count:
		var pick: CardDefinition = left[rng.randi_range(0, left.size() - 1)]
		drawn.append(pick)
		left.erase(pick)
	var ordered: Array[CardDefinition] = []
	for card: CardDefinition in cards:
		if drawn.has(card):
			ordered.append(card)
	return ordered


## Whether `card` fits some regular slot under the copy limit (not the slot's own current or
## original card), the swaps aside: a swap booster's card no slot can take shows
## dimmed (the mock-up's cardBlocked).
static func placeable(run: RunState, profile: ProfileState, card: CardDefinition) -> bool:
	if not StartSetupRules.is_swap_option(run, profile, card):
		return false
	var core: Array[CardDefinition] = run.starter.core_cards
	for slot: int in core.size():
		if card == core[slot] or card == run.start_setup.originals[slot]:
			continue
		if StartSetupRules.copies_fit(run, slot, card, -1):
			return true
	return false


## Why swap booster `aisle_id` can't be opened, or &"": &"locked" (no swap unlocked), &"none"
## (the window hasn't shown it: no offer saved) or &"opened".
static func open_swap_block(
	run: RunState, profile: ProfileState, aisle_id: StringName
) -> StringName:
	var setup: StartSetup = run.start_setup
	if StartSetupRules.swap_limit(run, profile) <= 0:
		return &"locked"
	if not setup.has_swap_offer(aisle_id):
		return &"none"
	if setup.swap_opened.has(aisle_id):
		return &"opened"
	return &""


## Opens swap booster `aisle_id` (open_swap_block): it only reveals and uses no swap. Returns the
## reason it was refused, &"" when opened (the caller saves the run).
static func open_swap_booster(
	run: RunState, profile: ProfileState, aisle_id: StringName
) -> StringName:
	var block: StringName = open_swap_block(run, profile, aisle_id)
	if block == &"":
		run.start_setup.swap_opened.append(aisle_id)
	return block
