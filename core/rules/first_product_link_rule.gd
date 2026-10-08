class_name FirstProductLinkRule
extends Rule
## Shelf swap (a Connector coupon), context pass: the product in the next slot also counts as
## just after the row's first product (coupons skipped). The link works both ways, so the
## first product also counts as beside it. It fizzles when the next slot holds no product, or
## when that product is the row's first.


func modify_context(state: ScoreState, slot: int) -> void:
	if _problem(state, slot).is_empty():
		state.link_products(state.first_product(), slot + 1, slot, text_for(state.definition(slot)))


func wasted_reason(state: ScoreState, slot: int) -> String:
	return _problem(state, slot)


static func _problem(state: ScoreState, slot: int) -> String:
	if not state.is_product(slot + 1):
		return "no product in the next slot"
	if state.first_product() == slot + 1:
		return "no product before it"
	return ""
