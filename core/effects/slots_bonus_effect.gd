class_name SlotsBonusEffect
extends ScoreEffect
## A flat bonus given once to each of some later slots (Croissant: +2 to every later product of
## its batch; Birthday candles: +3 to each product of the baked batch after it, #128).

var bonus: int = 0
var _targets: PackedInt32Array = PackedInt32Array()
var _left: int = 0


func _init(
	effect_source_slot: int, effect_text: String, targets: PackedInt32Array, bonus_amount: int
) -> void:
	super(effect_source_slot, effect_text)
	_targets = targets
	_left = targets.size()
	bonus = bonus_amount


func armed_value() -> int:
	return bonus


func flat_bonus(_state: ScoreState, slot: int) -> int:
	if _left == 0 or not _targets.has(slot):
		return 0
	_left -= 1
	return bonus


func waste_reason() -> String:
	return "" if _left == 0 else "its batch ended early"


func is_spent() -> bool:
	return _left == 0
