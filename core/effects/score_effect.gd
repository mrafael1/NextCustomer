class_name ScoreEffect
extends RefCounted
## An effect a scanned card leaves for later products. It lives for one score() call only.
## The engine asks effects about products only: coupons never receive effects.

## Effects with the same non-empty group replace each other (a later Egg resets the charges).
var group: StringName = &""
## Slot of the card that created the effect.
var source_slot: int = -1
## Receipt text for the steps this effect causes.
var text: String = ""


func _init(effect_source_slot: int, effect_text: String, effect_group: StringName = &"") -> void:
	source_slot = effect_source_slot
	text = effect_text
	group = effect_group


## The number shown when the effect is armed (its EFFECT_ARMED step's value): the flat bonus
## or the factor it will give, from the rule's data. 0 when no single number fits.
func armed_value() -> int:
	return 0


func flat_bonus(_state: ScoreState, _slot: int) -> int:
	return 0


func multiplier(_state: ScoreState, _slot: int) -> int:
	return 1


## Why the effect was wasted, or "" if it was fully used. Asked when the effect is replaced
## or when the row ends.
func waste_reason() -> String:
	return ""


## Why the effect was wasted when a later card with the same group replaced it, or "" if
## nothing was lost. Defaults to waste_reason().
func reset_reason() -> String:
	return waste_reason()


## True once the effect has nothing left to give. The engine then drops it.
func is_spent() -> bool:
	return false
