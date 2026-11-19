class_name BatchSizeBonusRule
extends Rule
## The BATCH size bonus (#128 batch polish, approved by the user on 2026-11-19): every batch of
## `tag` products (CardBatch, 2 or more beside each other, with or without a job card) gives each
## of its products a flat bonus by its size. `bonuses` holds one bonus per size from 2 up, its
## last entry for every larger batch (Bakery: 2 = +1, 3 = +2, 4 or more = +3 each).
##
## A product carries it in CardDefinition.batch_bonus, never in its rules (a plain Bread stays a
## plain item): Scoring gives the bonus to every product of a batch that holds a carrier, as its
## own flat step before any multiplier, so an Iced bun's ×2 doubles its closer's size bonus too.
## The frozen fixtures' cards carry none, so their golden rows never change.

@export var tag: String = ""
## The bonus each product of a batch gets, by size: [size 2, size 3, ..., the largest and up].
@export var bonuses: PackedInt32Array = PackedInt32Array()


## The bonus each product of a batch of `size` gets (0 for no batch).
func bonus_for(size: int) -> int:
	if size < CardBatch.MIN_SIZE or bonuses.is_empty():
		return 0
	return bonuses[mini(size - CardBatch.MIN_SIZE, bonuses.size() - 1)]


## The receipt line for a batch of `size` (receipt_text with `{size}`, e.g. "Batch of 3").
func text_for_size(size: int) -> String:
	return receipt_text.format({"size": size})


## The batch of `slot` that earns this bonus (one of its products carries this rule's tag in
## CardDefinition.batch_bonus), or an empty array.
func earning_batch(state: ScoreState, slot: int) -> PackedInt32Array:
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	for member: int in batch:
		var carried: BatchSizeBonusRule = state.definition(member).batch_bonus
		if carried != null and carried.tag == tag:
			return batch
	return PackedInt32Array()
