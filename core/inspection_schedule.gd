class_name InspectionSchedule
extends RefCounted
## Which shifts are inspected and which inspection each one gets (plan section 3.9), using only
## the RNG passed in.


## Whether the 1-based shift number is played under an inspection.
static func is_inspection_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return balance.inspection_shifts.has(shift_number)


## One inspection drawn uniformly from inspection_pool with the run's RNG, never the same as
## `previous` (the run's last inspection) unless it is the only one: no inspection twice in a
## row. Null when the pool is empty (then no RNG is used).
static func draw(
	rng: RandomNumberGenerator, balance: BalanceDefinition, previous: InspectionDefinition = null
) -> InspectionDefinition:
	var candidates: Array[InspectionDefinition] = []
	for inspection: InspectionDefinition in balance.inspection_pool:
		if inspection != previous:
			candidates.append(inspection)
	if candidates.is_empty():
		candidates.assign(balance.inspection_pool)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]
