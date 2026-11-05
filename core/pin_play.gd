class_name PinPlay
extends RefCounted
## The badge pins a player uses during a shift (#132, picked by the user on 2026-11-02; full build
## plan 7.4): Stock list's look at the draw pile, Day off's skipped shift, Golden basket's kept
## items and Price gun's relabels. Each reads the run's worn pins (RunState.pins); the UI asks
## here and displays, it never applies the rules itself. RunPins holds the pins that change the
## run's shape (repack, Double checkout, base slots, events, the deal).


## How many of the draw pile's next items the worn pins show (Stock list's peek_count; the most
## of any worn pin), 0 for none.
static func peek_count(run: RunState) -> int:
	var count: int = 0
	for pin: PinDefinition in run.pins:
		count = maxi(count, pin.peek_count)
	return count


## The draw pile's next items, the next one first (Deck.draw_pile draws from its end), at most
## peek_count; none outside planning.
static func peek(run: RunState) -> Array[CardInstance]:
	var next: Array[CardInstance] = []
	if run.phase != RunState.Phase.PLANNING:
		return next
	var pile: Array[CardInstance] = run.deck.draw_pile()
	for index: int in range(mini(peek_count(run), pile.size())):
		next.append(pile[pile.size() - 1 - index])
	return next


## The days off a week the worn pins give (the sum of their days_off_per_week).
static func days_off_per_week(run: RunState) -> int:
	var days: int = 0
	for pin: PinDefinition in run.pins:
		days += pin.days_off_per_week
	return days


## The days off left in the current shift's week: the pins' days less the week's shifts taken
## off (the history's day_off records in the same week).
static func days_off_left(run: RunState) -> int:
	var week: int = WeekSchedule.week_of(run.balance, run.shift_index + 1)
	var taken: int = 0
	for record: ShiftRecord in run.history:
		if record.day_off and WeekSchedule.week_of(run.balance, record.shift) == week:
			taken += 1
	return maxi(days_off_per_week(run) - taken, 0)


## Whether the current shift may be taken off: any day but a Manager's review (the balance's
## review_shifts, whose pass pays the PREMIUM tickets; the user's call of 2026-11-02), so an
## inspection day and a boon day can be skipped too.
static func is_skippable_day(run: RunState) -> bool:
	return not run.balance.review_shifts.has(run.shift_index + 1)


## A day off needs a day left this week, planning before any checkout (a Double checkout's row 1
## included), a day that isn't a review, and a shift that isn't the run's last.
static func can_take_day_off(run: RunState) -> bool:
	if days_off_left(run) <= 0 or run.phase != RunState.Phase.PLANNING:
		return false
	if run.first_result != null or run.is_last_shift():
		return false
	return is_skippable_day(run)


## Puts a Day off's pile on the belt (`pending`: the row's cards go back to the hand, and it
## takes none) or takes it back; false when today can't be taken off.
static func set_day_off(run: RunState, pending: bool) -> bool:
	if pending and not can_take_day_off(run):
		return false
	if pending:
		for card: CardInstance in run.row.duplicate():
			run.remove(card)
	run.day_off_pending = pending
	return true


## A day off's result: exactly the quota, with no slot and no step (no lap over it, so no
## over-quota reward: OvertimeTickets).
static func day_off_result(run: RunState) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = run.quota()
	return result


## How many items a worn Golden basket keeps (the most of any worn pin's keep_count), 0 for none.
static func keep_count(run: RunState) -> int:
	var count: int = 0
	for pin: PinDefinition in run.pins:
		count = maxi(count, pin.keep_count)
	return count


## The items the shift's checkout put on the belt (a Double checkout's both rows), which a Golden
## basket keeps from; none before the checkout, after a day off, or once the run is over.
static func keepable(run: RunState) -> Array[CardInstance]:
	var found: Array[CardInstance] = []
	if keep_count(run) <= 0 or run.history.is_empty():
		return found
	var after: bool = run.phase == RunState.Phase.SCORED or RunState.MACHINE_PHASES.has(run.phase)
	var record: ShiftRecord = run.history[-1]
	if not after or record.shift != run.shift_index + 1 or record.day_off:
		return found
	found.append_array(run.first_row)
	found.append_array(run.row)
	return found


## Whether `card` is kept for the next shift.
static func is_kept(run: RunState, card: CardInstance) -> bool:
	return run.kept.has(card.instance_id)


## Keeps `card` for the next shift's first basket, or lets it go when it is kept already. False,
## changing nothing, for an item not keepable or past keep_count.
static func keep(run: RunState, card: CardInstance) -> bool:
	if not keepable(run).has(card):
		return false
	var at: int = run.kept.find(card.instance_id)
	if at >= 0:
		run.kept.remove_at(at)
		return true
	if run.kept.size() >= keep_count(run):
		return false
	run.kept.append(card.instance_id)
	return true


## The relabels a shift the worn pins allow (the sum of relabels_per_shift).
static func relabels_per_shift(run: RunState) -> int:
	var count: int = 0
	for pin: PinDefinition in run.pins:
		count += pin.relabels_per_shift
	return count


## The relabels left this shift: the pins' relabels_per_shift less the items relabelled.
static func relabels_left(run: RunState) -> int:
	return maxi(relabels_per_shift(run) - run.relabels.size(), 0)


## The families the worn Price guns can give, in their data's order.
static func relabel_tags(run: RunState) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	for pin: PinDefinition in run.pins:
		for tag: String in pin.relabel_tags:
			if not tags.has(tag):
				tags.append(tag)
	return tags


## A relabel needs planning, a product of this shift's hand or row (not a Double checkout's
## checked-out row 1), a family the pins give that the product hasn't, and a relabel left (moving
## the family of an item already relabelled costs none).
static func can_relabel(run: RunState, card: CardInstance, tag: String) -> bool:
	if run.phase != RunState.Phase.PLANNING or card == null or not card.definition.is_product():
		return false
	if not run.deck.hand().has(card) or run.first_row.has(card):
		return false
	if not relabel_tags(run).has(tag) or card.definition.tags.has(tag):
		return false
	return run.relabels.has(card.instance_id) or run.relabels.size() < relabels_per_shift(run)


## Gives `card` the family `tag` for this shift (scoring adds it to its tags: ScoreCredits), or,
## with an empty `tag`, takes its relabel back (free, during planning). False when not allowed.
static func relabel(run: RunState, card: CardInstance, tag: String) -> bool:
	if tag.is_empty():
		if run.phase != RunState.Phase.PLANNING or card == null:
			return false
		if not run.relabels.has(card.instance_id) or run.first_row.has(card):
			return false
		run.relabels.erase(card.instance_id)
		return true
	if not can_relabel(run, card, tag):
		return false
	run.relabels[card.instance_id] = tag
	return true


## The family `card` gained this shift, or "".
static func relabel_of(run: RunState, card: CardInstance) -> String:
	return run.relabels.get(card.instance_id, "")
