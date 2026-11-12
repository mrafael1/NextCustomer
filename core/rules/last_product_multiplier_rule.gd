class_name LastProductMultiplierRule
extends Rule
## Final markdown (v1.28, a Position coupon): the row's last product (ScoreState.last_product,
## coupons skipped) pays ×factor, an armed multiplier for that one slot like Opening deal's, so it
## stacks with every other multiplier and a Repeat after that product copies the multiplied
## payout. With no product after it (it sits after the last product, or in the last slot) it
## fizzles.

@export var factor: int = 1


func on_scanned(state: ScoreState, slot: int) -> void:
	if factor == 1 or not _problem(state, slot).is_empty():
		return
	var text: String = text_for(state.definition(slot))
	state.add_effect(SlotMultiplierEffect.new(slot, text, state.last_product, factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	return "" if factor == 1 else _problem(state, slot)


static func _problem(state: ScoreState, slot: int) -> String:
	if state.last_product <= slot:
		return "no item after it"
	return ""
