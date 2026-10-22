class_name RunStock
extends RefCounted
## The run's stock (full build plan 7.2): every card the RECEIPT REWARDS machine's NEW ITEMS
## and COUPONS chutes can draw from (#77). Built before RunState and passed in. Building it is
## pure and uses no RNG, so the same input gives the same stock. It uses no RNG anywhere except
## surprise_list's passed-in stream (a derived stream the caller makes outside core/, #63).
##
## The list (full build plan 7.2): until #65's shopping list, a run that needs one stocks
## surprise_list's aisles. prefill_list is the list's default (the balance simulator's chained
## player keeps it), ready for #65.
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
## The new arrivals in the stock, newest first (the run's first NEW ITEMS draw holds the newest,
## MachineDraw).
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


## A stock restored from a run save (RunSave), so a resumed run never depends on a profile
## that changed after it started. The cards are kept in the order given.
static func from_saved(
	stock_cards: Array[CardDefinition],
	stocked_aisle_ids: Array[StringName],
	skipped: bool,
	arrivals: Array[CardDefinition]
) -> RunStock:
	var stock: RunStock = RunStock.new()
	stock.cards = stock_cards.duplicate()
	stock.aisle_ids = stocked_aisle_ids.duplicate()
	stock.list_skipped = skipped
	stock.new_arrivals = arrivals.duplicate()
	return stock


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


## A random list (#63, until #65's shopping list): run_aisle_picks distinct listable aisles drawn
## with `rng` (a partial Fisher-Yates, one randi_range per pick), in data order. All the
## listable aisles when there are no more than run_aisle_picks; [] when no list is needed.
static func surprise_list(
	balance: BalanceDefinition, unlocked: Dictionary[StringName, int], rng: RandomNumberGenerator
) -> Array[StringName]:
	var listed: Array[StringName] = []
	if not needs_list(balance, unlocked):
		return listed
	var listable: Array[AisleDefinition] = listable_aisles(balance, unlocked)
	var pool: Array[AisleDefinition] = listable.duplicate()
	var picks: int = mini(balance.run_aisle_picks, pool.size())
	for index: int in range(picks):
		var other: int = rng.randi_range(index, pool.size() - 1)
		var held: AisleDefinition = pool[index]
		pool[index] = pool[other]
		pool[other] = held
	var chosen: Array[AisleDefinition] = pool.slice(0, picks)
	for aisle: AisleDefinition in listable:
		if chosen.has(aisle):
			listed.append(aisle.id)
	return listed


## The list's default (full build plan 7.2), as the balance simulator's chained player keeps
## it: the listable aisles of `last_list`; each newly listable aisle (`newly_listable`, ids)
## joins, in place of the listed aisle with the fewest items (ties: the later in data order);
## then, while the list is short of run_aisle_picks, the listable aisle with the most items
## (ties: data order). With no last list only machine-opened aisles join as newly listable (the
## first list's pre-fill). In data order; [] when no list is needed. A caller that doesn't track
## which aisles just became listable passes machine_opened_listable.
static func prefill_list(
	balance: BalanceDefinition,
	unlocked: Dictionary[StringName, int],
	last_list: Array[StringName],
	newly_listable: Array[StringName]
) -> Array[StringName]:
	var listed: Array[StringName] = []
	if not needs_list(balance, unlocked):
		return listed
	var listable: Array[AisleDefinition] = listable_aisles(balance, unlocked)
	var list: Array[AisleDefinition] = []
	var newly: Array[AisleDefinition] = []
	for aisle: AisleDefinition in listable:
		if last_list.has(aisle.id):
			list.append(aisle)
		# The first list's pre-fill: base aisles only fill in after a newly listable one.
		var base_on_first: bool = last_list.is_empty() and not aisle.base_cards.is_empty()
		if newly_listable.has(aisle.id) and not base_on_first:
			newly.append(aisle)
	for aisle: AisleDefinition in newly:
		if list.has(aisle):
			continue
		if list.size() >= balance.run_aisle_picks:
			list.erase(_fewest_items(balance, list, unlocked))
		list.append(aisle)
	while list.size() < balance.run_aisle_picks:
		var best: AisleDefinition = null
		for aisle: AisleDefinition in listable:
			var more: bool = best == null or _held(aisle, unlocked) > _held(best, unlocked)
			if not list.has(aisle) and more:
				best = aisle
		if best == null:
			break
		list.append(best)
	for aisle: AisleDefinition in listable:
		if list.has(aisle):
			listed.append(aisle.id)
	return listed


## The listable machine-opened aisles (no base cards), ids in data order: prefill_list's newly
## listable aisles for a caller that doesn't track them.
static func machine_opened_listable(
	balance: BalanceDefinition, unlocked: Dictionary[StringName, int]
) -> Array[StringName]:
	var found: Array[StringName] = []
	for aisle: AisleDefinition in listable_aisles(balance, unlocked):
		if aisle.base_cards.is_empty():
			found.append(aisle.id)
	return found


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


## The listed aisle with the fewest items; ties go to the later one in data order.
static func _fewest_items(
	balance: BalanceDefinition, list: Array[AisleDefinition], unlocked: Dictionary[StringName, int]
) -> AisleDefinition:
	var fewest: AisleDefinition = null
	for aisle: AisleDefinition in balance.aisles:
		var fewer: bool = fewest == null or _held(aisle, unlocked) <= _held(fewest, unlocked)
		if list.has(aisle) and fewer:
			fewest = aisle
	return fewest


static func _held(aisle: AisleDefinition, unlocked: Dictionary[StringName, int]) -> int:
	return items(aisle, unlocked).size()


func _add_all(more: Array[CardDefinition]) -> void:
	for card: CardDefinition in more:
		_add(card)


func _add(card: CardDefinition) -> void:
	if not cards.has(card):
		cards.append(card)
