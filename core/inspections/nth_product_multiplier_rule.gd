class_name NthProductMultiplierRule
extends InspectionRule
## Day event (Free samples): the product_number-th product in the row (counting products only,
## coupons skipped) is multiplied by `factor`, after every card, effect and upgrade multiplier. A
## product paying €0 there has nothing to multiply (WASTED), and a row with fewer products wastes
## the boon on its last slot. 0 means no product.

@export var product_number: int = 0
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	if product_number <= 0 or state.product_numbers[slot] != product_number:
		return 1
	return factor


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "nothing to multiply"


func row_wasted_reason(state: ScoreState) -> String:
	if product_number <= 0 or factor == 1:
		return ""
	for slot: int in range(state.size()):
		if state.product_numbers[slot] == product_number:
			return ""
	return "no product %d in the row" % product_number
