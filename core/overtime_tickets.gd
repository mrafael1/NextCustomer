class_name OvertimeTickets
extends RefCounted
## The over-quota rewards (decided with the user on 2026-11-05, replacing the overtime coin; shown
## as the week's two medals since 2026-11-06, WeekMedals): a passed shift whose total makes
## MachineDefinition.overtime_ticket_laps laps of its quota (the ×N the quota gauge's lamp shows:
## whole multiples of the quota) spends the SILVER medal on an OVERTIME visit after it, one more
## draw of the same receipt (PREMIUM when the shift's ticket visit is), at most
## overtime_ticket_per_week times a week; one making overtime_premium_laps laps spends the GOLD
## medal to turn its ticket's visit PREMIUM, at most overtime_premium_per_week times a week, a cap
## of its own. A ×3 shift reaches ×2 too, so it also spends the SILVER while the week's is unused.
## A ticket visit already PREMIUM (a premium shift's) is not transformed and does not use the
## week's GOLD. The run's last shift has no machine visit, so it uses nothing. The shift's record
## keeps what it earned (ShiftRecord.overtime_ticket, overtime_premium): the week's use is read
## from the history, and saved with it. 0 laps turns a reward off. Pure.

## A reward's state for a shift, for the UI: NONE (not reached, off, a failed or last shift, or a
## PREMIUM ticket left as it was), EARNED, or USED (reached, but the week's reward is gone).
enum State { NONE, EARNED, USED }


## The laps `total` makes of `quota`: its whole multiples (0 for a quota of 0 or less).
static func laps(total: int, quota: int) -> int:
	if quota <= 0:
		return 0
	return floori(float(maxi(total, 0)) / quota)


## Sets what the just-recorded `record` (the run's last) earns at its checkout:
## `ticket_premium`, its ticket's visit is PREMIUM already. Call it once, at the checkout, before
## the visits are queued.
static func grant(run: RunState, record: ShiftRecord, ticket_premium: bool) -> void:
	record.overtime_ticket = false
	record.overtime_premium = false
	var machine: MachineDefinition = _machine(run)
	if machine == null or not record.passed or record.shift >= run.shift_count():
		return
	var made: int = laps(record.total, record.quota)
	if _reaches(made, machine.overtime_ticket_laps):
		record.overtime_ticket = (used(run, record.shift, false) < machine.overtime_ticket_per_week)
	if _reaches(made, machine.overtime_premium_laps) and not ticket_premium:
		record.overtime_premium = (
			used(run, record.shift, true) < machine.overtime_premium_per_week
		)


## How many of the week's rewards (the PREMIUM transform with `premium`, else the extra ticket)
## the shifts before `shift_number` in its week used.
static func used(run: RunState, shift_number: int, premium: bool) -> int:
	var week: int = WeekSchedule.week_of(run.balance, shift_number)
	var count: int = 0
	for record: ShiftRecord in run.history:
		if record.shift >= shift_number or WeekSchedule.week_of(run.balance, record.shift) != week:
			continue
		var took: bool = record.overtime_premium if premium else record.overtime_ticket
		count += 1 if took else 0
	return count


## Whether the week of the current shift still has its reward (the PREMIUM transform with
## `premium`, else the extra ticket) for the current shift: on, unused this week, and not the
## run's last shift. For planning and the time card.
static func available(run: RunState, premium: bool) -> bool:
	var machine: MachineDefinition = _machine(run)
	if machine == null or run.is_last_shift():
		return false
	var shift_number: int = run.shift_index + 1
	if premium:
		return (
			machine.overtime_premium_laps > 0
			and used(run, shift_number, true) < machine.overtime_premium_per_week
		)
	return (
		machine.overtime_ticket_laps > 0
		and used(run, shift_number, false) < machine.overtime_ticket_per_week
	)


## A checked-out `record`'s reward state (the PREMIUM transform with `premium`, else the extra
## ticket): EARNED when it got it, USED when it reached it on a passed shift with a machine visit
## but the week's was gone, else NONE (a PREMIUM ticket left as it was is NONE).
static func state(run: RunState, record: ShiftRecord, premium: bool) -> State:
	var machine: MachineDefinition = _machine(run)
	if machine == null or not record.passed or record.shift >= run.shift_count():
		return State.NONE
	if record.overtime_premium if premium else record.overtime_ticket:
		return State.EARNED
	var needed: int = machine.overtime_premium_laps if premium else machine.overtime_ticket_laps
	if not _reaches(laps(record.total, record.quota), needed):
		return State.NONE
	if premium and machine.is_premium_shift(record.shift):
		return State.NONE
	return State.USED


## The laps a reward needs: `needed` (0: the reward is off).
static func _reaches(made: int, needed: int) -> bool:
	return needed > 0 and made >= needed


## Whether the run's waiting machine visit is the PREMIUM ticket an overtime's premium laps made
## of its shift's ticket (not a premium shift's), for the machine's words.
static func is_premium_visit(run: RunState) -> bool:
	var visit: MachineVisit = run.machine.current_visit() if run.machine != null else null
	if visit == null or visit.kind != MachineVisit.Kind.TICKET or run.history.is_empty():
		return false
	return visit.premium and run.history[-1].overtime_premium


## The run's machine data: its machine's (RewardMachine.machine), else the balance's.
static func _machine(run: RunState) -> MachineDefinition:
	if run.machine != null and run.machine.machine != null:
		return run.machine.machine
	return run.balance.machine
