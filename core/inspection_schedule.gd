class_name InspectionSchedule
extends RefCounted
## Which shifts are inspected, how many inspections each gets and which ones (plan section 3.9),
## using only the RNG passed in. Since v0.65 a Manager's review (BalanceDefinition.review_shifts)
## draws review_inspection_count different inspections at once.


## Whether the 1-based shift number is played under an inspection.
static func is_inspection_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return count_for(balance, shift_number) > 0


## Whether the 1-based shift number is a Manager's review (v0.65).
static func is_review_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return balance.review_shifts.has(shift_number) and balance.review_inspection_count > 0


## How many inspections the 1-based shift number is played under: a review's
## review_inspection_count, 1 for an inspected shift, else 0.
static func count_for(balance: BalanceDefinition, shift_number: int) -> int:
	if is_review_shift(balance, shift_number):
		return balance.review_inspection_count
	return 1 if balance.inspection_shifts.has(shift_number) else 0


## The inspections the 1-based shift number is played under (count_for of them), all different,
## drawn from inspection_pool with the run's RNG. The run's last inspections (`previous`) are
## left out while enough others remain, so no inspection comes twice in a row when it can be
## helped. Fewer when the pool is smaller; empty when the shift isn't inspected (then no RNG is
## used).
static func draw_for(
	rng: RandomNumberGenerator,
	balance: BalanceDefinition,
	shift_number: int,
	previous: Array[InspectionDefinition] = []
) -> Array[InspectionDefinition]:
	var drawn: Array[InspectionDefinition] = []
	var count: int = count_for(balance, shift_number)
	# One draw per inspection, every one of `previous` left out (after a review, both of its
	# inspections): for a single previous inspection this draws as draw() does.
	for index: int in range(count):
		var fresh: Array[InspectionDefinition] = []
		var others: Array[InspectionDefinition] = []
		for inspection: InspectionDefinition in balance.inspection_pool:
			if drawn.has(inspection):
				continue
			if previous.has(inspection):
				others.append(inspection)
			else:
				fresh.append(inspection)
		var candidates: Array[InspectionDefinition] = fresh if not fresh.is_empty() else others
		if candidates.is_empty():
			break
		drawn.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return drawn


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


## A run's last inspections: its current shift's (`current`), else the last inspected record's
## in `history` (no inspection twice in a row, draw_for).
static func last_of(
	current: Array[InspectionDefinition], history: Array[ShiftRecord]
) -> Array[InspectionDefinition]:
	if not current.is_empty():
		return current.duplicate()
	for index: int in range(history.size() - 1, -1, -1):
		if not history[index].inspections.is_empty():
			return history[index].inspections.duplicate()
	return []
