class_name ShiftMargin
extends RefCounted
## A shift's margin against its quota (#61, the dessert): over it, exactly on it, or short of
## it, and by how many euros. The dessert's receipt line counts it up ("+€N OVER QUOTA",
## "SHORT €N", "ON QUOTA"). Exactly on the quota is a pass (plan section 2: a total of at least
## the quota passes). CoinPayout keeps its own overtime sum. Pure.

enum Kind { OVER, ON, SHORT }

## The total minus the quota: positive over it, 0 on it, negative short of it.
var margin: int = 0


static func of(total: int, quota: int) -> ShiftMargin:
	var result: ShiftMargin = ShiftMargin.new()
	result.margin = total - quota
	return result


func kind() -> Kind:
	if margin > 0:
		return Kind.OVER
	return Kind.ON if margin == 0 else Kind.SHORT


## The euros over or short (never negative); 0 on the quota.
func amount() -> int:
	return absi(margin)


## The total reaches the quota (on it or over it).
func passed() -> bool:
	return margin >= 0
