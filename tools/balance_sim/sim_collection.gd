class_name SimCollection
extends RefCounted
## A collection state for the balance simulator (full build plan sections 7.2 and 8): the
## unlocked capsule items, the run index and the shopping list a run's stock is built from
## (RunStock.build). Decided with the user (#40): a profile save file (--profile), the full
## collection (--collection=full) and the list (--list) give one; the list gate (--list-gate)
## makes every state it checks.
##
## The full collection and the gate's states unlock items at run index 0 and build the run at
## index end_cap_window_runs + 1, so their stocks have no new arrivals: the gate compares lists,
## and arrivals would only add noise.

## What the report calls this state, e.g. "fresh profile" or "full: cold_cases+pantry".
var label: String = ""
## Unlocked capsule item id -> the run index it came out at (RunStock's `unlocked`).
var unlocked: Dictionary[StringName, int] = {}
var run_index: int = 0
## The shopping list (aisle ids); used only when the stock needs one.
var listed: Array[StringName] = []
## The gate group this state belongs to ("" outside the gate): "full", "first list" or
## "new aisle <id>". Only "full" states get the key-card check (plan section 8).
var group: String = ""


## A new profile: nothing unlocked, run index 0.
static func fresh() -> SimCollection:
	var state: SimCollection = SimCollection.new()
	state.label = "fresh profile"
	return state


## Every capsule item unlocked, with this list.
static func full(balance: BalanceDefinition, list: Array[StringName]) -> SimCollection:
	var state: SimCollection = SimCollection.new()
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			state.unlocked[card.id] = 0
	state.run_index = balance.end_cap_window_runs + 1
	state.listed = list.duplicate()
	state.label = "full collection" + _list_text(state, balance)
	return state


## The collection of a profile save, with its last list unless `list` is given.
static func from_profile(
	profile: ProfileState, balance: BalanceDefinition, list: Array[StringName]
) -> SimCollection:
	var state: SimCollection = SimCollection.new()
	state.unlocked = profile.unlocked_items.duplicate()
	state.run_index = profile.run_count
	state.listed = list.duplicate() if not list.is_empty() else profile.last_list.duplicate()
	state.label = "profile (run %d)%s" % [state.run_index, _list_text(state, balance)]
	return state


## Whether this state's stock needs a list (more listable items than aisle_stock_budget).
func needs_list(balance: BalanceDefinition) -> bool:
	return RunStock.needs_list(balance, unlocked)


## Why this state can't build a stock ("" when it can): a list is needed but doesn't name
## run_aisle_picks listable aisles.
func problem(balance: BalanceDefinition) -> String:
	if not needs_list(balance):
		return ""
	var listable: Array[StringName] = []
	for aisle: AisleDefinition in RunStock.listable_aisles(balance, unlocked):
		listable.append(aisle.id)
	var named: Array[StringName] = []
	for id: StringName in listed:
		if listable.has(id) and not named.has(id):
			named.append(id)
	if named.size() != balance.run_aisle_picks or named.size() != listed.size():
		return (
			"the stock needs a list of %d listable aisles (%s), got %s"
			% [balance.run_aisle_picks, _joined(listable), _joined(listed)]
		)
	return ""


func stock(deck: DeckDefinition, balance: BalanceDefinition) -> RunStock:
	return RunStock.build(deck, balance, listed, unlocked, run_index)


## Every state the list gate checks (plan section 8), in this order: every legal list at full
## collection; every list of the first state that needs one, with base-aisle capsule items
## unlocked in turn (one per base aisle per round, aisle data order) until the listable items
## pass the budget; and, for each machine-opened aisle, the state where it has just become
## listable (its first aisle_listable_min capsule items, nothing else unlocked), with every list
## that holds it. A state whose stock needs no list is one state, labelled "list skipped".
static func gate_states(balance: BalanceDefinition) -> Array[SimCollection]:
	var states: Array[SimCollection] = []
	var everything: Dictionary[StringName, int] = {}
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			everything[card.id] = 0
	states.append_array(_with_lists(balance, everything, "full", ""))
	var first: Dictionary[StringName, int] = _first_list_unlocks(balance)
	if not first.is_empty():
		states.append_array(_with_lists(balance, first, "first list", ""))
	for aisle: AisleDefinition in balance.aisles:
		if not aisle.base_cards.is_empty():
			continue
		var opened: Dictionary[StringName, int] = {}
		for card: CardDefinition in aisle.capsule_cards.slice(0, balance.aisle_listable_min):
			opened[card.id] = 0
		states.append_array(_with_lists(balance, opened, "new aisle " + aisle.id, aisle.id))
	return states


## Every list of `picks` aisles out of `aisles`, in aisle data order.
static func lists(aisles: Array[StringName], picks: int) -> Array[Array]:
	var result: Array[Array] = []
	if picks <= 0 or picks > aisles.size():
		return result
	var chosen: Array[StringName] = []
	_combine(aisles, picks, 0, chosen, result)
	return result


## The states of one unlock set: one per legal list (only those holding `required`, when it is
## set), or a single state when the stock needs no list.
static func _with_lists(
	balance: BalanceDefinition,
	unlocked_items: Dictionary[StringName, int],
	group_name: String,
	required: StringName
) -> Array[SimCollection]:
	var states: Array[SimCollection] = []
	var listable: Array[StringName] = []
	for aisle: AisleDefinition in RunStock.listable_aisles(balance, unlocked_items):
		listable.append(aisle.id)
	var all_lists: Array[Array] = [[]]
	if RunStock.needs_list(balance, unlocked_items):
		all_lists = lists(listable, balance.run_aisle_picks)
	for list: Array in all_lists:
		if not required.is_empty() and not list.is_empty() and not list.has(required):
			continue
		var state: SimCollection = SimCollection.new()
		state.unlocked = unlocked_items.duplicate()
		state.run_index = balance.end_cap_window_runs + 1
		state.listed.assign(list)
		state.group = group_name
		state.label = group_name + _list_text(state, balance)
		states.append(state)
	return states


## The base-aisle unlocks of the first state that needs a list, or none when the base aisles'
## machines never pass the budget.
static func _first_list_unlocks(balance: BalanceDefinition) -> Dictionary[StringName, int]:
	var unlocked_items: Dictionary[StringName, int] = {}
	var round_index: int = 0
	while true:
		var added: bool = false
		for aisle: AisleDefinition in balance.aisles:
			if aisle.base_cards.is_empty() or round_index >= aisle.capsule_cards.size():
				continue
			unlocked_items[aisle.capsule_cards[round_index].id] = 0
			added = true
			if RunStock.needs_list(balance, unlocked_items):
				return unlocked_items
		if not added:
			break
		round_index += 1
	return {}


static func _combine(
	aisles: Array[StringName],
	picks: int,
	start: int,
	chosen: Array[StringName],
	result: Array[Array]
) -> void:
	if chosen.size() == picks:
		result.append(chosen.duplicate())
		return
	for index: int in range(start, aisles.size()):
		chosen.append(aisles[index])
		_combine(aisles, picks, index + 1, chosen, result)
		chosen.pop_back()


static func _list_text(state: SimCollection, balance: BalanceDefinition) -> String:
	if not state.needs_list(balance):
		return " (list skipped)"
	return ": " + "+".join(state.listed.map(func(id: StringName) -> String: return String(id)))


static func _joined(ids: Array[StringName]) -> String:
	if ids.is_empty():
		return "none"
	return "+".join(ids.map(func(id: StringName) -> String: return String(id)))
