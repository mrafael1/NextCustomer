class_name CardBatch
extends RefCounted
## A batch (#128, the Bakery's verb): 2 or more products with a tag in a row, after the context
## pass. Beside is ScoreState.products_beside (a neighbour, or a product a coupon links to it), so
## a batch is every tagged product reached through tagged products beside each other, in slot
## order. Where a product sits in its batch is its job: the first opens it, the last closes it.
## A big enough batch bakes (Birthday candles' party: its rule's `min_size`).
##
## Static helpers only (no state): the rules that read batches call them on each score's state.

## Products a batch needs at all.
const MIN_SIZE := 2


## The batch holding `slot` in slot order, or an empty array when the slot is no product with
## `tag` or has no product with `tag` beside it.
static func members(state: ScoreState, slot: int, tag: String) -> PackedInt32Array:
	if tag.is_empty() or not state.is_product(slot) or not state.has_tag(slot, tag):
		return PackedInt32Array()
	var found: PackedInt32Array = PackedInt32Array([slot])
	var at: int = 0
	while at < found.size():
		for other: int in state.products_beside(found[at]):
			if not found.has(other) and state.is_product(other) and state.has_tag(other, tag):
				found.append(other)
		at += 1
	if found.size() < MIN_SIZE:
		return PackedInt32Array()
	found.sort()
	return found


## Records `batch` on the score (ScoreState.batches) for the belt, once, when it explains.
static func record(state: ScoreState, batch: PackedInt32Array) -> void:
	if state.explain and batch.size() >= MIN_SIZE and not state.batches.has(batch):
		state.batches.append(batch)


## The products counted as just after `slot` (its real neighbour and any linked to it).
static func products_after(state: ScoreState, slot: int) -> PackedInt32Array:
	var after: PackedInt32Array = PackedInt32Array()
	for later: int in range(slot + 1, state.size()):
		if state.products_before(later).has(slot):
			after.append(later)
	return after
