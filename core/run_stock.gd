class_name RunStock
extends RefCounted
## The run's stock (full build plan 7.2): every card reward offers and the impulse rack can
## draw from. Built before RunState and passed in. Building it is pure and uses no RNG (only
## "Surprise me" will, to pick the list: a derived stream passed in by the caller, phase 3), so
## the same input gives the same stock.
##
## The stock holds, in this order and each in data order: the staples (the starting deck's own
## products), the listed aisles' products (aisle data order), the new arrivals, then all of
## coupon_pool. A card is stocked once.
##
## `run_index` is the 0-based index of the run being built: the number of runs played before
## it. `unlocked` maps each unlocked capsule item id to the run_index of the run whose exit it
## came out at (not the run count after that run ended), in the order the capsules were drawn.
## So an item from run K is a new arrival in runs K + 1 to K + end_cap_window_runs.

## Every stocked card once, in stock order.
var cards: Array[CardDefinition] = []
## The aisles stocked whole, in aisle data order: the listed ones, or every listable aisle when
## the list is skipped.
var aisle_ids: Array[StringName] = []
## True when every listable aisle together fits aisle_stock_budget, so the list is skipped.
var list_skipped: bool = false
## The new arrivals in the stock, newest first (the newest takes an impulse-rack slot).
var new_arrivals: Array[CardDefinition] = []


## Builds the stock. `listed` (aisle ids) is used only when the list isn't skipped; ids of
## aisles that are unknown or not listable are ignored.
static func build(
	deck: DeckDefinition,
	balance: BalanceDefinition,
	listed: Array[StringName],
	unlocked: Dictionary[StringName, int],
	run_index: int
) -> RunStock:
	var stock: RunStock = RunStock.new()
	stock._add_all(staples(deck))
	var listable: Array[AisleDefinition] = listable_aisles(balance, unlocked)
	stock.list_skipped = not needs_list(balance, unlocked)
	var stocked_aisles: Array[AisleDefinition] = []
	for aisle: AisleDefinition in listable:
		if stock.list_skipped or listed.has(aisle.id):
			stocked_aisles.append(aisle)
			stock.aisle_ids.append(aisle.id)
			stock._add_all(items(aisle, unlocked))
	stock.new_arrivals = _new_arrivals(balance, stocked_aisles, unlocked, run_index)
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			if stock.new_arrivals.has(card):
				stock._add(card)
	stock._add_all(balance.coupon_pool)
	return stock


## The stock of a new profile: no unlocks, no list, run index 0. The game builds each run's
## stock from its ProfileState; tests and the balance simulator use this one.
static func starting(deck: DeckDefinition, balance: BalanceDefinition) -> RunStock:
	var unlocked: Dictionary[StringName, int] = {}
	return build(deck, balance, [], unlocked, 0)


## The starting deck's own products, each once, in deck order.
static func staples(deck: DeckDefinition) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in deck.cards:
		if card.is_product() and not found.has(card):
			found.append(card)
	return found


## The products an aisle holds: its base cards, then its unlocked capsule cards, in data order.
static func items(
	aisle: AisleDefinition, unlocked: Dictionary[StringName, int]
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = aisle.base_cards.duplicate()
	for card: CardDefinition in aisle.capsule_cards:
		if unlocked.has(card.id):
			found.append(card)
	return found


## An aisle with base cards is always listable; a machine-opened aisle once it holds
## aisle_listable_min items.
static func is_listable(
	aisle: AisleDefinition, balance: BalanceDefinition, unlocked: Dictionary[StringName, int]
) -> bool:
	if not aisle.base_cards.is_empty():
		return true
	return items(aisle, unlocked).size() >= balance.aisle_listable_min


## The listable aisles, in data order.
static func listable_aisles(
	balance: BalanceDefinition, unlocked: Dictionary[StringName, int]
) -> Array[AisleDefinition]:
	var found: Array[AisleDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		if is_listable(aisle, balance, unlocked):
			found.append(aisle)
	return found


## Whether the player lists aisles: false when every listable aisle together holds at most
## aisle_stock_budget products, so all of them are stocked.
static func needs_list(balance: BalanceDefinition, unlocked: Dictionary[StringName, int]) -> bool:
	var held: int = 0
	for aisle: AisleDefinition in listable_aisles(balance, unlocked):
		held += items(aisle, unlocked).size()
	return held > balance.aisle_stock_budget


## Card ids in stock order, for the event log and the run save.
func card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return ids


## The fields run_start logs (full build plan section 4): the aisles stocked whole and the card
## ids in stock order, enough to rebuild the stock without the profile.
func to_dictionary() -> Dictionary:
	var aisles: Array[String] = []
	for id: StringName in aisle_ids:
		aisles.append(String(id))
	return {"listed_aisles": aisles, "stock": card_ids()}


## Up to end_cap_max capsule items from aisles that aren't stocked whole, that came out in the
## last end_cap_window_runs runs, newest first: the later run first, then the later draw.
static func _new_arrivals(
	balance: BalanceDefinition,
	stocked_aisles: Array[AisleDefinition],
	unlocked: Dictionary[StringName, int],
	run_index: int
) -> Array[CardDefinition]:
	var by_id: Dictionary[StringName, CardDefinition] = {}
	for aisle: AisleDefinition in balance.aisles:
		if stocked_aisles.has(aisle):
			continue
		for card: CardDefinition in aisle.capsule_cards:
			by_id[card.id] = card
	# Draw order reversed, then a stable pass by run index: the later draw wins a tie.
	var recent: Array[CardDefinition] = []
	var ids: Array = unlocked.keys()
	ids.reverse()
	for newest_run: int in range(run_index - 1, run_index - 1 - balance.end_cap_window_runs, -1):
		for id: StringName in ids:
			if unlocked[id] == newest_run and by_id.has(id) and not recent.has(by_id[id]):
				recent.append(by_id[id])
	return recent.slice(0, balance.end_cap_max)


func _add_all(more: Array[CardDefinition]) -> void:
	for card: CardDefinition in more:
		_add(card)


func _add(card: CardDefinition) -> void:
	if not cards.has(card):
		cards.append(card)
