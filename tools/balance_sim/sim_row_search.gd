class_name SimRowSearch
extends RefCounted
## Exact best-row search for the balance simulator (plan section 8). It tries every selection
## and order of the hand's cards that fits the row (at most slot_count products and
## RowCapacity.card_limit cards), shorter rows and the empty row included, and scores each one
## with core's Scoring, so the simulator never has its own copy of a rule.
##
## Copies of a card are interchangeable, so each distinct order of a multiset is scored once.
## The best order of every multiset is cached, and so is each hand's best: a hand's best is the
## best over its sub-multisets, and hands share most of them. Keys and orders use card ids
## (sorted), and ties go to the first order by id, so a result never depends on which hand or
## process found it: caches can be saved, merged and loaded again (save_cache, load_cache).
## Not thread-safe: the simulator runs in several processes instead (threads sharing the card
## resources ran slower than one thread).

## Results kept in memory before the cache stops growing (the warm entries stay).
const CACHE_LIMIT := 1500000
## The time limit is checked once every this many rows scored.
const STOP_CHECK_ROWS := 2048

## Rows scored, and lookups answered from the cache, for the summary.
var rows_scored: int = 0
var cache_hits: int = 0
## The time limit (balance_sim's --max-minutes): past this Time.get_ticks_msec() a search stops
## where it is (0: never), and `stopped` stays true until reset. A stopped search's result is
## meaningless and never cached: the run or sample asking for it must be dropped.
var stop_at_msec: int = 0
var stopped: bool = false
var _balance: BalanceDefinition
## Key -> [best total, best order as card ids] for a multiset, or [best total, best order, best
## total without each card id (in sorted id order)] for a hand.
var _cache: Dictionary = {}
## Entries found by this search, not loaded (save_cache can write only these).
var _fresh: Dictionary = {}
var _definitions: Dictionary[String, CardDefinition] = {}
## Per card id, the card instances used to score candidate rows, one per copy.
var _instances: Dictionary[String, Array] = {}
var _next_instance_id: int = 1


func _init(balance: BalanceDefinition) -> void:
	_balance = balance


## `inspections` are the shift's inspections (plan section 3.9); a search without them scores
## like an uninspected shift.
func search(
	hand: Array[CardInstance],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition] = []
) -> SimHandBest:
	if _past_stop():
		return SimHandBest.new()
	var groups: Dictionary[String, Array] = {}
	for card: CardInstance in hand:
		var id: String = String(card.definition.id)
		_definitions[id] = card.definition
		if not groups.has(id):
			groups[id] = []
		groups[id].append(card)
	var ids: PackedStringArray = PackedStringArray(groups.keys())
	ids.sort()
	var limits: PackedInt32Array = PackedInt32Array()
	var everything: PackedStringArray = PackedStringArray()
	for id: String in ids:
		limits.append(groups[id].size())
		for _copy: int in range(groups[id].size()):
			everything.append(id)
	var upgrade_key: String = _upgrade_key(upgrades) + _inspection_key(inspections)
	# A hand's best also depends on the row limits, which upgrades can raise (ShiftLimits; the
	# quota doesn't matter here).
	var row_limits: ShiftLimits = ShiftLimits.for_shift(_balance, upgrades, 0, inspections)
	var limits_key: String = "%d/%d:" % [row_limits.slot_count, row_limits.card_limit()]
	var hand_key: String = "hand " + limits_key + ",".join(everything) + upgrade_key
	var entry: Array = _cache.get(hand_key, [])
	if entry.is_empty():
		entry = _search_hand(ids, limits, row_limits, upgrades, inspections, upgrade_key)
		if stopped:
			return SimHandBest.new()
		_store(hand_key, entry)
	else:
		cache_hits += 1

	var best: SimHandBest = SimHandBest.new()
	best.score = entry[0]
	var used: Dictionary[String, int] = {}
	for id: String in entry[1]:
		var copy: int = used.get(id, 0)
		used[id] = copy + 1
		best.row.append(groups[id][copy])
	var without: PackedInt32Array = entry[2]
	for index: int in range(ids.size()):
		best.best_without[_definitions[ids[index]]] = without[index]
	return best


func cache_size() -> int:
	return _cache.size()


## Adds saved entries (from save_cache) to the cache. False if the file can't be read.
func load_cache(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var saved: Variant = file.get_var()
	if not saved is Dictionary:
		return false
	_cache.merge(saved)
	return true


## Writes the entries found since this search was created (`only_fresh`), or the whole cache.
func save_cache(path: String, only_fresh: bool) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(_fresh if only_fresh else _cache)
	file.close()
	return true


## Rearranges `order` into the next distinct permutation in lexicographic order. False (and
## `order` unchanged) when it is already the last one.
static func next_permutation(order: PackedInt32Array) -> bool:
	var pivot: int = order.size() - 2
	while pivot >= 0 and order[pivot] >= order[pivot + 1]:
		pivot -= 1
	if pivot < 0:
		return false
	var successor: int = order.size() - 1
	while order[successor] <= order[pivot]:
		successor -= 1
	var swap: int = order[pivot]
	order[pivot] = order[successor]
	order[successor] = swap
	var low: int = pivot + 1
	var high: int = order.size() - 1
	while low < high:
		swap = order[low]
		order[low] = order[high]
		order[high] = swap
		low += 1
		high -= 1
	return true


## [best total, best order, best total without each id (in `ids` order)]. Of several best
## rows, the shortest wins, then the first found (selections in a fixed order by id).
func _search_hand(
	ids: PackedStringArray,
	limits: PackedInt32Array,
	row_limits: ShiftLimits,
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	upgrade_key: String
) -> Array:
	var card_limit: int = row_limits.card_limit()
	var coupons: Array[bool] = []
	for id: String in ids:
		coupons.append(_definitions[id].is_coupon())
	var best_total: int = 0
	var best_order: PackedStringArray = PackedStringArray()
	var found: bool = false
	var without: PackedInt32Array = PackedInt32Array()
	without.resize(ids.size())
	without.fill(-1)
	# Odometer over how many copies of each card the row uses.
	var choice: PackedInt32Array = PackedInt32Array()
	choice.resize(ids.size())
	while true:
		var products: int = 0
		var multiset: PackedStringArray = PackedStringArray()
		for index: int in range(ids.size()):
			if not coupons[index]:
				products += choice[index]
			for _copy: int in range(choice[index]):
				multiset.append(ids[index])
		if multiset.size() <= card_limit and products <= row_limits.slot_count:
			var entry: Array = _best_order(multiset, upgrades, inspections, upgrade_key)
			if stopped:
				break
			var total: int = entry[0]
			var shorter: bool = multiset.size() < best_order.size()
			if not found or total > best_total or (total == best_total and shorter):
				found = true
				best_total = total
				best_order = entry[1]
			for index: int in range(ids.size()):
				if choice[index] == 0 and total > without[index]:
					without[index] = total
		var position: int = 0
		while position < choice.size():
			choice[position] += 1
			if choice[position] <= limits[position]:
				break
			choice[position] = 0
			position += 1
		if position == choice.size():
			break
	return [best_total, best_order, without]


## The best order of exactly these cards (ids sorted ascending): [total, order as ids]. Of
## several best orders, the first in lexicographic order by id wins.
func _best_order(
	multiset: PackedStringArray,
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	upgrade_key: String
) -> Array:
	var key: String = ",".join(multiset) + upgrade_key
	var entry: Array = _cache.get(key, [])
	if not entry.is_empty():
		cache_hits += 1
		return entry
	# Permute ranks: rank i is the i-th distinct id, so rank order is id order.
	var distinct: PackedStringArray = PackedStringArray()
	var order: PackedInt32Array = PackedInt32Array()
	for id: String in multiset:
		if distinct.is_empty() or distinct[-1] != id:
			distinct.append(id)
		order.append(distinct.size() - 1)
	var best_total: int = 0
	var best: PackedInt32Array = PackedInt32Array()
	var first: bool = true
	while true:
		var total: int = Scoring.score(_row_of(order, distinct), upgrades, inspections).total
		rows_scored += 1
		if rows_scored % STOP_CHECK_ROWS == 0 and _past_stop():
			return [0, PackedStringArray()]
		if first or total > best_total:
			first = false
			best_total = total
			best = order.duplicate()
		if not next_permutation(order):
			break
	var best_ids: PackedStringArray = PackedStringArray()
	for rank: int in best:
		best_ids.append(distinct[rank])
	entry = [best_total, best_ids]
	_store(key, entry)
	return entry


## Whether the time limit has passed; once it has, the search counts as stopped.
func _past_stop() -> bool:
	if stop_at_msec > 0 and Time.get_ticks_msec() >= stop_at_msec:
		stopped = true
	return stopped


func _store(key: String, entry: Array) -> void:
	if _cache.size() < CACHE_LIMIT:
		_cache[key] = entry
		_fresh[key] = entry


func _row_of(order: PackedInt32Array, distinct: PackedStringArray) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	var copies: Dictionary[int, int] = {}
	for rank: int in order:
		var copy: int = copies.get(rank, 0)
		copies[rank] = copy + 1
		var id: String = distinct[rank]
		if not _instances.has(id):
			_instances[id] = []
		var instances: Array = _instances[id]
		while instances.size() <= copy:
			instances.append(CardInstance.new(_definitions[id], _next_instance_id))
			_next_instance_id += 1
		row.append(instances[copy])
	return row


## The upgrades that can change a score, in pick order (scoring steps name them by index).
## An upgrade without rules (Extra redraw) never changes a total, so it is left out.
static func _upgrade_key(upgrades: Array[UpgradeDefinition]) -> String:
	var key: String = "|"
	for upgrade: UpgradeDefinition in upgrades:
		if not upgrade.rules.is_empty():
			key += String(upgrade.id) + ","
	return key


## The inspections that can change a score, in order (scoring steps name them by index), so a
## cached best row of an uninspected shift is never reused under an inspection.
static func _inspection_key(inspections: Array[InspectionDefinition]) -> String:
	var key: String = "!"
	for inspection: InspectionDefinition in inspections:
		if not inspection.rules.is_empty():
			key += String(inspection.id) + ","
	return key
