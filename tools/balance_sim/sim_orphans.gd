class_name SimOrphans
extends RefCounted
## The orphan check (full build plan section 7.2): every key item and capsule item reaches the
## best row with a staple or its own aisle, so nothing is an orphan while it rides the end-cap.
##
## For each capsule item (aisle data order, key item first), each sample draws hand_size - 1
## cards from the staples and the rest of its own aisle at full collection, one copy of each,
## adds the item and searches the hand's best row with no upgrades. An item whose best rows
## never use it is an orphan.

## The capsule items checked, in aisle data order.
var items: Array[CardDefinition] = []
var samples_per_item: int = 0
## Per played sample index: [1 if the best row used the item, 1 if it was needed there].
var _results: Dictionary[int, PackedInt32Array] = {}
## Per item: the cards its hands are drawn from.
var _pools: Array[Array] = []
var _balance: BalanceDefinition
var _seed: int = 0


func _init(
	deck: DeckDefinition, balance: BalanceDefinition, per_item: int, orphan_seed: int
) -> void:
	_balance = balance
	_seed = orphan_seed
	samples_per_item = per_item
	var staples: Array[CardDefinition] = RunStock.staples(deck)
	for aisle: AisleDefinition in balance.aisles:
		var aisle_items: Array[CardDefinition] = aisle.base_cards + aisle.capsule_cards
		for card: CardDefinition in aisle.capsule_cards:
			items.append(card)
			var pool: Array[CardDefinition] = []
			for other: CardDefinition in staples + aisle_items:
				if other != card and not pool.has(other):
					pool.append(other)
			_pools.append(pool)


## Samples to play in all: one index per (item, sample).
func sample_total() -> int:
	return items.size() * samples_per_item


func sample_count() -> int:
	return _results.size()


func samples_to_array() -> Array:
	var result: Array = []
	for index: int in _results:
		result.append([index, _results[index]])
	return result


func add_samples(samples: Array) -> void:
	for sample: Array in samples:
		_results[int(sample[0])] = PackedInt32Array(sample[1])


## Plays sample `index` with `search`. Samples take the items in turn (item index % items), so
## a time limit thins every item's samples instead of leaving the last items unsampled.
func run_sample(search: SimRowSearch, index: int) -> void:
	var item_index: int = _item_of(index)
	var item: CardDefinition = items[item_index]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("orphans:%d:%d" % [_seed, index])
	var pile: Array[CardInstance] = []
	var pool: Array = _pools[item_index]
	for card_index: int in range(pool.size()):
		pile.append(CardInstance.new(pool[card_index], card_index + 1))
	SimPlayer.shuffle(rng, pile)
	var hand: Array[CardInstance] = pile.slice(0, _balance.hand_size - 1)
	hand.append(CardInstance.new(item, pool.size() + 1))
	var no_upgrades: Array[UpgradeDefinition] = []
	var best: SimHandBest = search.search(hand, no_upgrades)
	if search.stopped:
		return
	_results[index] = PackedInt32Array(
		[1 if best.uses(item) else 0, 1 if best.is_needed(item) else 0]
	)


## Per item: [samples played, best rows that used it, best rows that needed it].
func counts(item_index: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for index: int in _results:
		if _item_of(index) == item_index:
			result[0] += 1
			result[1] += _results[index][0]
			result[2] += _results[index][1]
	return result


## Items that were never sampled (the time limit stopped the check first).
func unsampled() -> Array[String]:
	var result: Array[String] = []
	for item_index: int in range(items.size()):
		if counts(item_index)[0] == 0:
			result.append(String(items[item_index].id))
	return result


## Items that were sampled and never in a best row.
func orphans() -> Array[String]:
	var result: Array[String] = []
	for item_index: int in range(items.size()):
		var item_counts: PackedInt32Array = counts(item_index)
		if item_counts[0] > 0 and item_counts[1] == 0:
			result.append(String(items[item_index].id))
	return result


func format() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Orphan check: capsule items with the staples and their own aisle ==")
	if items.is_empty():
		lines.append("No capsule items in the aisles yet.")
		return "\n".join(lines)
	lines.append(
		(
			"%d hands per item of %d cards: the item plus staples and its own aisle"
			% [samples_per_item, _balance.hand_size]
		)
	)
	lines.append("Item               Hands  In best row  Needed")
	for item_index: int in range(items.size()):
		var item_counts: PackedInt32Array = counts(item_index)
		lines.append(
			(
				"%-17s %6d  %11s  %6s"
				% [
					items[item_index].id,
					item_counts[0],
					SimSummary.percent_text(item_counts[1], item_counts[0]),
					SimSummary.percent_text(item_counts[2], item_counts[0])
				]
			)
		)
	var found: Array[String] = orphans()
	lines.append("Orphans: " + (", ".join(found) if not found.is_empty() else "none"))
	var missed: Array[String] = unsampled()
	if not missed.is_empty():
		lines.append("Not sampled (time limit): " + ", ".join(missed))
	return "\n".join(lines)


func to_dictionary() -> Dictionary:
	var result: Dictionary[String, Dictionary] = {}
	for item_index: int in range(items.size()):
		var item_counts: PackedInt32Array = counts(item_index)
		result[String(items[item_index].id)] = {
			"hands": item_counts[0], "in_best_row": item_counts[1], "needed": item_counts[2]
		}
	return {
		"samples_per_item": samples_per_item,
		"items": result,
		"orphans": orphans(),
		"unsampled": unsampled(),
	}


func _item_of(index: int) -> int:
	return index % maxi(items.size(), 1)
