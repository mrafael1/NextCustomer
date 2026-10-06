class_name InspectionSchedule
extends RefCounted
## Which shifts are inspected and which inspection each one gets (plan section 3.9), using only
## the RNG passed in.


## Whether the 1-based shift number is played under an inspection.
static func is_inspection_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return balance.inspection_shifts.has(shift_number)


## One inspection drawn uniformly from inspection_pool with the run's RNG, or null when the pool
## is empty (then no RNG is used).
static func draw(rng: RandomNumberGenerator, balance: BalanceDefinition) -> InspectionDefinition:
	if balance.inspection_pool.is_empty():
		return null
	return balance.inspection_pool[rng.randi_range(0, balance.inspection_pool.size() - 1)]
