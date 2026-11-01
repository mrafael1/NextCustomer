class_name BatchRoleRule
extends Rule
## A product's job in its batch (#128, the Bakery's verb: open the batch, fill it, finish it).
## A batch is CardBatch's: 2 or more products with `tag` beside each other. Each role works only
## at its place in the batch, and fizzles (#45) anywhere else: a WASTED step that says why.
## - OPENER (Croissant): first of its batch, +bonus to every later product of the batch.
## - BODY (Baguette): +bonus for each earlier product of its batch, counting up to `max_count`
##   (0: all of them).
## - CLOSER (Stale doughnut): last of its batch, +bonus for each product of the batch.
## - GLAZE (Iced bun): ×factor the batch's closer (its last product), wherever the glaze sits.

enum Role { NONE, OPENER, BODY, CLOSER, GLAZE }

@export var tag: String = ""
@export var role: Role = Role.NONE
@export var bonus: int = 0
## BODY: the most earlier products counted, 0 for no limit.
@export var max_count: int = 0
@export var factor: int = 1


func flat_bonus(state: ScoreState, slot: int) -> int:
	var batch: PackedInt32Array = CardBatch.members(state, slot, tag)
	if batch.is_empty():
		return 0
	match role:
		Role.BODY:
			return _earlier(batch, slot) * bonus
		Role.CLOSER:
			return batch.size() * bonus if batch[-1] == slot else 0
	return 0


func flat_support(state: ScoreState, slot: int) -> int:
	if role != Role.BODY and role != Role.CLOSER:
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
		return "no %s product beside it" % tag
	return _misplaced_reason(batch, slot)


## Why this role does nothing at its place in `batch`, or "" when it works there.
func _misplaced_reason(batch: PackedInt32Array, slot: int) -> String:
	var first: bool = batch[0] == slot
	var last: bool = batch[-1] == slot
	match role:
		Role.OPENER when not first:
			return "not first in its %s batch" % tag
		Role.BODY when first:
			return "first in its batch: nothing before it"
		Role.CLOSER when not last:
			return "not last in its %s batch" % tag
		Role.GLAZE when last:
			return "it closes its batch: nothing to glaze"
	return ""


## How many products of `batch` come before `slot`, up to max_count.
func _earlier(batch: PackedInt32Array, slot: int) -> int:
	var count: int = batch.find(slot)
	return mini(count, max_count) if max_count > 0 else count
