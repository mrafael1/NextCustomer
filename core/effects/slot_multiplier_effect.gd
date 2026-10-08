class_name SlotMultiplierEffect
extends ScoreEffect
## A multiplier for one later slot, used once (2 for 1: the second product pays ×2). It stacks
## with every other multiplier, and a Repeat after that product copies the multiplied payout.

var target_slot: int = -1
var factor: int = 1
var _used: bool = false


func _init(
	effect_source_slot: int, effect_text: String, effect_target_slot: int, effect_factor: int
) -> void:
	super(effect_source_slot, effect_text)
	target_slot = effect_target_slot
	factor = effect_factor


func armed_value() -> int:
	return factor


func multiplier(_state: ScoreState, slot: int) -> int:
	if _used or slot != target_slot:
		return 1
	_used = true
	return factor


func is_spent() -> bool:
	return _used
