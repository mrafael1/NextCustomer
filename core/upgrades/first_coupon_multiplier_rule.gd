class_name FirstCouponMultiplierRule
extends UpgradeRule
## Upgrade: the first coupon in the row (the lowest slot holding a coupon) pays x factor, after
## its own rules and a Repeat's copy. Coupon engine: x2. A first coupon that pays 0 has nothing
## to multiply, so the upgrade fizzles there. With no coupon in the row it does nothing.

@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	return factor if slot >= 0 and state.first_coupon == slot else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "the first coupon paid nothing"
