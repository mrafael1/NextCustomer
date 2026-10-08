class_name NthProductMultiplierRule
extends UpgradeRule
## Upgrade (Slot engine): the product_number-th product in the row (counting products only,
## coupons skipped, like Spot check) pays x factor, after its own rules, its effects and a
## copy, so a later Repeat copies the multiplied payout. With fewer products it does nothing;
## a product there that pays 0 has nothing to multiply, so the upgrade fizzles. 0 means no
## product.

@export var product_number: int = 0
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	return factor if _is_target(state, slot) else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "product %d paid nothing" % product_number


func _is_target(state: ScoreState, slot: int) -> bool:
	if product_number <= 0 or not state.is_product(slot):
		return false
	var products: int = 0
	for earlier: int in range(slot + 1):
		if state.is_product(earlier):
			products += 1
	return products == product_number
