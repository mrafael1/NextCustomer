class_name NthProductMultiplierRule
extends UpgradeRule
## Upgrade (Slot engine): the product_number-th product in the row (counting products only,
## coupons skipped, like Spot check) pays x factor, after its own rules, its effects and a
## copy, so a later Repeat copies the multiplied payout. With fewer products it fizzles (#45),
## once, on the row's last slot;
## a product there that pays 0 has nothing to multiply, so the upgrade fizzles. 0 means no
## product. With follows_slot_changes, the number moves with the shift's product slots
## (ScoreState.product_slot_change): the 5th on a Short belt shift, the 7th with Big basket
## (decided with the user in #42, when it was the last product slot; since plan v0.46 every slot is
## general and the row has one slot more).

@export var product_number: int = 0
@export var factor: int = 1
@export var follows_slot_changes: bool = false


func multiplier(state: ScoreState, slot: int) -> int:
	var target: int = _target_number(state)
	return factor if target > 0 and state.product_numbers[slot] == target else 1


func wasted_reason(state: ScoreState, _slot: int) -> String:
	return "product %d paid nothing" % _target_number(state)


func row_wasted_reason(state: ScoreState) -> String:
	var target: int = _target_number(state)
	if factor == 1 or target <= 0:
		return ""
	var last: int = state.last_product
	var products: int = state.product_numbers[last] if last >= 0 else 0
	return "fewer than %d products" % target if products < target else ""


func _target_number(state: ScoreState) -> int:
	if product_number <= 0:
		return 0
	return product_number + (state.product_slot_change if follows_slot_changes else 0)
