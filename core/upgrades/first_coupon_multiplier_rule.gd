class_name FirstCouponMultiplierRule
extends UpgradeRule
## Upgrade: the first coupon in the row (the lowest slot holding a coupon) pays x factor, after
## its own rules and a Repeat's copy. Coupon engine: x2. A first coupon that pays 0 has nothing
## to multiply, so the upgrade fizzles there. With no coupon in the row it does nothing.

@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	return factor if _is_first_coupon(state, slot) else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "the first coupon paid nothing"


static func _is_first_coupon(state: ScoreState, slot: int) -> bool:
	if not state.is_coupon(slot):
		return false
	for earlier: int in range(slot):
		if state.is_coupon(earlier):
			return false
	return true
