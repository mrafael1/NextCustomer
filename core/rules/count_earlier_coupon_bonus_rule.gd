class_name CountEarlierCouponBonusRule
extends Rule
## A flat bonus for each earlier coupon in the row, whether or not that coupon did anything
## (decided with the user). Scissors: +2 for each earlier coupon. With no earlier coupon it
## fizzles.

@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	return _earlier_coupons(state, slot) * bonus_each


func wasted_reason(state: ScoreState, slot: int) -> String:
	if bonus_each == 0 or _earlier_coupons(state, slot) > 0:
		return ""
	return "no coupon before it"


static func _earlier_coupons(state: ScoreState, slot: int) -> int:
	var count: int = 0
	for earlier: int in range(slot):
		if state.is_coupon(earlier):
			count += 1
	return count
