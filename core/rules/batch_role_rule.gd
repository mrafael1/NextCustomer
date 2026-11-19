class_name BatchRoleRule
extends Rule
## A product's job in its batch (#128, the Bakery's verb: open the batch, fill it, finish it).
## A batch is CardBatch's: 2 or more products with `tag` beside each other. "Each item in its
## batch" always counts every product of the batch, the card itself included (the user's call of
## 2026-11-19). A role works only at its place in the batch, and fizzles (#45) anywhere else: a
## WASTED step that says why.
## - OPENER (Croissant): first of its batch, +bonus to each product of the batch, itself included
##   (its own as a flat bonus, the later ones' as an armed effect).
## - BODY (Baguette): +bonus for each product of its batch, itself included, wherever it sits.
## - CLOSER (Stale doughnut): last of its batch, +bonus for each product of the batch.
## - GLAZE (Iced bun): ×factor the batch's closer (its last product), wherever the glaze sits.

enum Role { NONE, OPENER, BODY, CLOSER, GLAZE }

@export var tag: String = ""
@export var role: Role = Role.NONE
@export var bonus: int = 0
@export var factor: int = 1


func flat_bonus(state: ScoreState, slot: int) -> int:
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	if batch.is_empty():
		return 0
	match role:
		Role.OPENER:
			return bonus if batch[0] == slot else 0
		Role.BODY:
			return batch.size() * bonus
		Role.CLOSER:
			return batch.size() * bonus if batch[-1] == slot else 0
	return 0


func flat_support(state: ScoreState, slot: int) -> int:
	if role != Role.CLOSER:
		return -1
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	var at: int = batch.find(slot)
	return batch[at - 1] if at > 0 else -1


func on_scanned(state: ScoreState, slot: int) -> void:
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	if batch.is_empty():
		return
	CardBatch.record(state, batch)
	var text: String = text_for(state.definition(slot))
	if role == Role.OPENER and bonus != 0 and batch[0] == slot:
		state.add_effect(SlotsBonusEffect.new(slot, text, batch.slice(1), bonus))
	elif role == Role.GLAZE and factor > 1 and batch[-1] != slot:
		state.add_effect(SlotMultiplierEffect.new(slot, text, batch[-1], factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or role == Role.NONE:
		return ""
	if role == Role.GLAZE and factor <= 1 or role != Role.GLAZE and bonus == 0:
		return ""
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	if batch.is_empty():
		return "no %s item beside it" % tag
	return _misplaced_reason(batch, slot)


## Why this role does nothing at its place in `batch`, or "" when it works there.
func _misplaced_reason(batch: PackedInt32Array, slot: int) -> String:
	var first: bool = batch[0] == slot
	var last: bool = batch[-1] == slot
	match role:
		Role.OPENER when not first:
			return "not first in its %s batch" % tag
		Role.CLOSER when not last:
			return "not last in its %s batch" % tag
		Role.GLAZE when last:
			return "it closes its batch: nothing to glaze"
	return ""
