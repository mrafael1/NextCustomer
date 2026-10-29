class_name TrainingWeek
extends RefCounted
## The training week (v0.68, the loop rework's safety net): a missed quota on the first shifts
## (up to the balance's write_up_last_shift) is a slip the run forgives, at most write_up_limit of
## them; the code calls them write-ups (RunState.write_ups). A slip gets no ticket and the run
## goes on; any other miss, or a missed last shift, ends the run. Pure.


## Whether a 1-based shift is in the training week: misses there can be forgiven (the balance's
## write_up_limit above 0, the shift at most write_up_last_shift when it is set).
static func covers(balance: BalanceDefinition, shift_number: int) -> bool:
	if balance.write_up_limit <= 0:
		return false
	return balance.write_up_last_shift <= 0 or shift_number <= balance.write_up_last_shift


## Whether a miss on `run`'s current shift is forgiven, counted with the misses already in its
## history (the shift's own too, after its checkout): not on the last shift nor after the
## training week, and at most write_up_limit misses.
static func forgives_miss(run: RunState) -> bool:
	var shift_number: int = run.shift_index + 1
	if run.is_last_shift() or not covers(run.balance, shift_number):
		return false
	var misses: int = run.write_ups
	if run.history.is_empty() or run.history[-1].shift != shift_number:
		misses += 1  # Before the checkout: the miss would be one more.
	return misses <= run.balance.write_up_limit


## The slips the training week still forgives on `run`'s current shift: 0 outside it.
static func slips_left(run: RunState) -> int:
	if not covers(run.balance, run.shift_index + 1):
		return 0
	return maxi(run.balance.write_up_limit - run.write_ups, 0)


## Whether `run`'s current shift is the first after the training week (it opens with "Training is
## over"): the shift after write_up_last_shift, on a balance with slips.
static func just_ended(run: RunState) -> bool:
	var balance: BalanceDefinition = run.balance
	if balance.write_up_limit <= 0 or balance.write_up_last_shift <= 0:
		return false
	return run.shift_index + 1 == balance.write_up_last_shift + 1
