class_name TwoForOneRule
extends Rule
## 2 for 1 (an Amplifier coupon): when the same product (plan section 3, a variant counts as
## its base card) is on both sides of it, the two count as adjacent (context pass) and the
## second pays ×factor (an armed multiplier for that one slot). Otherwise it fizzles, so two
## in a row both fizzle: each has a coupon beside it.

@export var factor: int = 1


func modify_context(state: ScoreState, slot: int) -> void:
	if _problem(state, slot).is_empty():
		state.link_products(slot - 1, slot + 1, slot, text_for(state.definition(slot)))


func on_scanned(state: ScoreState, slot: int) -> void:
	if factor == 1 or not _problem(state, slot).is_empty():
		return
	var text: String = text_for(state.definition(slot))
	state.add_effect(SlotMultiplierEffect.new(slot, text, slot + 1, factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	return _problem(state, slot)


static func _problem(state: ScoreState, slot: int) -> String:
	if not state.is_product(slot - 1) or not state.is_product(slot + 1):
		return "no product on both sides"
	if not state.definition(slot - 1).is_same_product(state.definition(slot + 1)):
		return "not the same product on both sides"
	return ""
