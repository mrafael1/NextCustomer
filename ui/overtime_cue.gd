class_name OvertimeCue
extends RefCounted
## What the shift screen tells the count-up about the machine's extra tickets after a checkout
## (v1.03): the BONUS ticket and the payday (#77 machine v2, v0.68) as before, and the over-quota
## rewards (OvertimeTickets): each reward's state and laps for the gauge's chip (OvertimeChip), and
## the OVERTIME ticket's stub when it is the shift's first extra visit. Reads the run, changes
## nothing in it.


## Dresses `context` for `run`'s count after its checkout (the shift's record is the last).
static func dress(run: RunState, context: CountUpContext) -> void:
	var pending: Array[int] = []
	if run.machine != null:
		pending = run.machine.pending_kinds()
	# A bonus ticket follows the visit (#77 machine v2, Q2 = 2): the dessert prints its stub.
	context.bonus_ticket = pending.has(MachineVisit.Kind.BONUS)
	context.payday = context.bonus_ticket and run.machine.is_payday(run)
	if run.history.is_empty() or run.machine == null:
		return
	var record: ShiftRecord = run.history[-1]
	var machine: MachineDefinition = run.machine.machine
	# A Double checkout's row 1 (#122) is counted while still planning, before the shift's record
	# exists: the last record is an earlier shift's, so the rewards wait for row 2's count.
	if machine == null or not counts_shift(run, record):
		return
	context.overtime_ticket = OvertimeTickets.state(run, record, false)
	context.overtime_premium = OvertimeTickets.state(run, record, true)
	context.overtime_ticket_laps = machine.overtime_ticket_laps
	context.overtime_premium_laps = machine.overtime_premium_laps
	if not pending.is_empty() and pending[0] == MachineVisit.Kind.OVERTIME:
		context.overtime_stub = OvertimeWords.ticket_sub(machine)


## Whether `record` is the record of `run`'s shift on screen, checked out (not a Double checkout's
## row 1 counted while planning).
static func counts_shift(run: RunState, record: ShiftRecord) -> bool:
	return run.phase != RunState.Phase.PLANNING and record.shift == run.shift_index + 1


## The `checkout` event's over-quota fields (v1.03): whether the shift earned the extra ticket
## and the PREMIUM transform.
static func checkout_fields(run: RunState) -> Dictionary:
	var record: ShiftRecord = run.history[-1] if not run.history.is_empty() else null
	return {
		"overtime_ticket": record != null and record.overtime_ticket,
		"overtime_premium": record != null and record.overtime_premium,
	}
