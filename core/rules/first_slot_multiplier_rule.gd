class_name FirstSlotMultiplierRule
extends Rule
## Opening deal (a Position coupon): in the row's first slot (the first filled slot, whatever
## its kind), the next product pays ×factor: the row's first product, coupons skipped. It is an
## armed multiplier for that one slot, so it stacks with every other multiplier and a Repeat
## after that product copies the multiplied payout. Outside the first slot, or with no product
## after it, it fizzles.

@export var factor: int = 1


func on_scanned(state: ScoreState, slot: int) -> void:
	if factor == 1 or not _problem(state, slot).is_empty():
		return
	var text: String = text_for(state.definition(slot))
	state.add_effect(SlotMultiplierEffect.new(slot, text, state.first_product(), factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	return "" if factor == 1 else _problem(state, slot)


static func _problem(state: ScoreState, slot: int) -> String:
	if slot != 0:
		return "not in the first slot"
	if state.first_product() < 0:
		return "no product after it"
	return ""
