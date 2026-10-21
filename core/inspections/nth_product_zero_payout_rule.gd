class_name NthProductZeroPayoutRule
extends InspectionRule
## Inspection: the product_number-th product in the row (counting products only, coupons
## skipped) pays 0, like Soup beside Frozen: after flat bonuses and multipliers, so bonuses
## aimed at it are spent and an Egg charge is used up. It still arms its own effects. With
## fewer products in the row it does nothing. 0 means no product.

@export var product_number: int = 0


func final_payout(state: ScoreState, slot: int, payout: int) -> int:
	if product_number <= 0 or state.product_numbers[slot] != product_number:
		return payout
	return 0
