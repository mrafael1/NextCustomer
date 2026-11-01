class_name BakedBatchBonusRule
extends Rule
## A flat bonus for each product of a baked batch just after this card (#128, Birthday candles:
## +3 to each product of a batch of 3 or more Bakery products that starts right after it). A
## batch is CardBatch's; it bakes from `min_size` products. With no such batch it fizzles (#45):
## a WASTED step that says why.

@export var tag: String = ""
@export var bonus: int = 0
## Products the batch needs to count as baked.
@export var min_size: int = 0


func on_scanned(state: ScoreState, slot: int) -> void:
	if bonus == 0:
		return
	var targets: PackedInt32Array = _targets(state, slot, true)
	if not targets.is_empty():
		var text: String = text_for(state.definition(slot))
		state.add_effect(SlotsBonusEffect.new(slot, text, targets, bonus))


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or bonus == 0 or not _targets(state, slot, false).is_empty():
		return ""
	return "no batch of %d %s just after it" % [maxi(min_size, 2), tag]


## The products of every batch of `min_size` or more that starts just after `slot`; with
## `record`, each such batch is recorded for the belt (CardBatch.record).
func _targets(state: ScoreState, slot: int, record: bool) -> PackedInt32Array:
	var targets: PackedInt32Array = PackedInt32Array()
	if tag.is_empty():
		return targets
	for after: int in CardBatch.products_after(state, slot):
		var batch: PackedInt32Array = CardBatch.members(state, after, tag)
		if batch.size() >= min_size and not batch.is_empty() and batch[0] == after:
			if record:
				CardBatch.record(state, batch)
			for member: int in batch:
				if not targets.has(member):
					targets.append(member)
	return targets
