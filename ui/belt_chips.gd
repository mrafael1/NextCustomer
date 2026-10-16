class_name BeltChips
extends RefCounted
## The effect chips under the belt items (#75; style frame v2's spec section 4.4): one per step
## that EffectChip.qualifies (a WASTED step, or a FLAT or MULTIPLIER step another source caused),
## at most EffectChip.MAX_PER_CELL per item with the rest folded into "+N more", worded by
## EffectChip.chip_text and kept in step order.
##
## In planning (and on a run resumed after its checkout) every chip shows at once, rebuilt from
## the ScoreResult on each refresh, so they follow every place, remove and redraw. The count-up
## hands off as option B: the CHECKOUT click clears them (begin_count) and each pops in, bright,
## as CountUp.step_landed says its step has landed (land), after any of #60's markers for that
## landing has been absorbed. Nothing waits for a chip: the count-up's timing never changes.
## Every number and name comes from the result and the caller; nothing here scores.

## A landed chip pops in from this scale to 1 over POP_TIME (none under reduced motion).
const POP_SCALE := 1.3
const POP_TIME := 0.18

var _result: ScoreResult
var _views: Array[CardView] = []
var _names: PackedStringArray = PackedStringArray()
var _upgrade_names: PackedStringArray = PackedStringArray()
var _inspection_names: PackedStringArray = PackedStringArray()
## Between begin_count and the next show_all: chips come one by one as their steps land.
var _counting: bool = false
var _reduced_motion: bool = false
## The steps landed so far on each slot during the count-up, in step order.
var _landed: Dictionary[int, PackedInt32Array] = {}


## Shows every chip of `result` on the belt items `views` (planning, or a resumed checkout's).
func show_all(
	result: ScoreResult,
	views: Array[CardView],
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> void:
	_keep(result, views, names, upgrade_names, inspection_names)
	_counting = false
	for slot: int in range(mini(views.size(), result.payouts.size())):
		_show(slot, EffectChip.step_indices(result, slot))


## The CHECKOUT click: clears every chip on `views`; land() then brings them back one by one.
func begin_count(
	result: ScoreResult,
	views: Array[CardView],
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray,
	reduced_motion: bool
) -> void:
	_keep(result, views, names, upgrade_names, inspection_names)
	_counting = true
	_reduced_motion = reduced_motion
	_landed.clear()
	for slot: int in range(views.size()):
		var item: ItemView = _item(slot)
		if item != null:
			item.clear_chips()


## Step `index` landed (CountUp.step_landed): pops in its chip when it has one, in step order
## among its item's chips. Returns the chip showing it (a folded one reads "+N more"), or null.
func land(index: int) -> EffectChip:
	if not _counting or _result == null or index < 0 or index >= _result.steps.size():
		return null
	var step: ScoreStep = _result.steps[index]
	if not EffectChip.qualifies(step) or step.slot < 0 or step.slot >= _views.size():
		return null
	var landed: PackedInt32Array = _landed.get(step.slot, PackedInt32Array())
	if landed.has(index):
		return null
	landed.append(index)
	landed.sort()
	_landed[step.slot] = landed
	var chip: EffectChip = null
	if landed[landed.size() - 1] == index:
		chip = _add(_item(step.slot), index)
	else:
		chip = _show(step.slot, landed, index)
	if chip != null and not _reduced_motion:
		chip.pivot_offset = EffectChip.SIZE / 2.0
		chip.scale = Vector2(POP_SCALE, POP_SCALE)
		var pop: Tween = chip.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(chip, "scale", Vector2.ONE, POP_TIME)
	return chip


func _keep(
	result: ScoreResult,
	views: Array[CardView],
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> void:
	_result = result
	_views = views
	_names = names
	_upgrade_names = upgrade_names
	_inspection_names = inspection_names


## Rebuilds the chips of `slot`'s item from `indices` (in step order); returns the chip that
## shows step `marked`, or null.
func _show(slot: int, indices: PackedInt32Array, marked: int = -1) -> EffectChip:
	var item: ItemView = _item(slot)
	if item == null:
		return null
	item.clear_chips()
	var marked_chip: EffectChip = null
	for index: int in indices:
		var chip: EffectChip = _add(item, index)
		if index == marked:
			marked_chip = chip
	return marked_chip


## Adds step `index`'s chip to `item` (after its others); returns the chip showing it.
func _add(item: ItemView, index: int) -> EffectChip:
	if item == null:
		return null
	var step: ScoreStep = _result.steps[index]
	var text: String = EffectChip.chip_text(
		step, _names, _upgrade_names, _inspection_names, EffectChip.font(), EffectChip.FONT_SIZE
	)
	return item.add_chip(text, step.step_type == ScoreStep.StepType.WASTED)


## The belt item in `slot`, or null (not an item, or freed by a refresh).
func _item(slot: int) -> ItemView:
	if not is_instance_valid(_views[slot]):
		return null
	return _views[slot] as ItemView
