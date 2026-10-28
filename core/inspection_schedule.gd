class_name InspectionSchedule
extends RefCounted
## Which shifts get day events and which ones (plan section 3.9), using only the RNG passed in:
## the inspected shifts draw one inspection (a MALUS) from inspection_pool, and since v0.65 a
## Manager's review (BalanceDefinition.review_shifts) draws review_inspection_count different
## ones at once. Since v0.69 a boon day (boon_shifts) draws one BOON from boon_pool. A shift's list
## holds its inspections first, then its boon.


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


## Whether the 1-based shift number is a boon day (v0.69): it draws one boon.
static func is_boon_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return boon_count_for(balance, shift_number) > 0


## How many boons the 1-based shift number draws: 1 on a boon day with a boon to draw, else 0.
static func boon_count_for(balance: BalanceDefinition, shift_number: int) -> int:
	if balance.boon_pool.is_empty() or shift_number <= 1:
		return 0
	return 1 if balance.boon_shifts.has(shift_number) else 0


## The day events the 1-based shift number is played under: its inspections (count_for of them),
## all different, drawn from inspection_pool with the run's RNG, then its boon (boon_count_for)
## drawn from boon_pool with the same RNG (core/AGENTS.md: inspection draws use the run's RNG).
## The run's last events (`previous`, last_of) are left out while enough others remain, so no
## event comes twice in a row when it can be helped. Fewer when a pool is smaller; empty when the
## shift has no event (then no RNG is used).
static func draw_for(
	rng: RandomNumberGenerator,
	balance: BalanceDefinition,
	shift_number: int,
	previous: Array[InspectionDefinition] = []
) -> Array[InspectionDefinition]:
	var drawn: Array[InspectionDefinition] = []
	# One draw per inspection, every one of `previous` left out (after a review, both of its
	# inspections): for a single previous inspection this draws as draw() does.
	_draw_into(drawn, rng, balance.inspection_pool, count_for(balance, shift_number), previous)
	var boons: int = boon_count_for(balance, shift_number)
	if boons > 0:
		_draw_into(drawn, rng, balance.boon_pool, boons, previous)
	return drawn


## Appends `count` different events of `pool` to `drawn`, each uniformly on `rng` from those not
## in `previous` while any remain.
static func _draw_into(
	drawn: Array[InspectionDefinition],
	rng: RandomNumberGenerator,
	pool: Array[InspectionDefinition],
	count: int,
	previous: Array[InspectionDefinition]
) -> void:
	for index: int in range(count):
		var fresh: Array[InspectionDefinition] = []
		var others: Array[InspectionDefinition] = []
		for event: InspectionDefinition in pool:
			if drawn.has(event):
				continue
			if previous.has(event):
				others.append(event)
			else:
				fresh.append(event)
		var candidates: Array[InspectionDefinition] = fresh if not fresh.is_empty() else others
		if candidates.is_empty():
			return
		drawn.append(candidates[rng.randi_range(0, candidates.size() - 1)])


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


## A run's last day events (no event twice in a row, draw_for): the last inspections, from its
## current shift's (`current`) or else the last inspected record's in `history`, then the last
## boon the same way.
static func last_of(
	current: Array[InspectionDefinition], history: Array[ShiftRecord]
) -> Array[InspectionDefinition]:
	var last: Array[InspectionDefinition] = []
	for boon: bool in [false, true]:
		var found: Array[InspectionDefinition] = _of_tone(current, boon)
		var index: int = history.size() - 1
		while found.is_empty() and index >= 0:
			found = _of_tone(history[index].inspections, boon)
			index -= 1
		last.append_array(found)
	return last


static func _of_tone(
	events: Array[InspectionDefinition], boon: bool
) -> Array[InspectionDefinition]:
	return InspectionDefinition.boons(events) if boon else InspectionDefinition.maluses(events)
