class_name WeekMedals
extends RefCounted
## The week's two medals (2026-11-06, mock-up docs/art/mockups/week_medals.html, the "spend"
## model; since v1.17 in the register's medal case, MedalCase): the over-quota rewards
## (OvertimeTickets), SILVER (the overtime ticket's laps, 2×: one extra machine draw) then GOLD
## (the PREMIUM laps, 3×: the shift's machine visit turns PREMIUM). Every week starts with both
## AVAILABLE; a checkout reaching a medal's laps while it is available spends it, and its socket
## stays empty (USED) until the next week. While planning, a medal the preview's projected total
## would spend is PENDING (it shimmers, and the receipt's edges glow in its metal). A medal whose
## reward is off (0 laps) is OFF (not shown). Read from the run (the shift records), so a resume
## shows the week as it was. Display only.

enum State { OFF, AVAILABLE, PENDING, USED }


## The run's machine data: its machine's (RewardMachine.machine), else the balance's.
static func machine_data(run: RunState) -> MachineDefinition:
	if run.machine != null and run.machine.machine != null:
		return run.machine.machine
	return run.balance.machine


## The laps medal `gold` (else the SILVER) needs (0: off).
static func laps_of(machine: MachineDefinition, gold: bool) -> int:
	if machine == null:
		return 0
	return machine.overtime_premium_laps if gold else machine.overtime_ticket_laps


## The total medal `gold` needs on `run`'s shift (v1.17, the medal case's "at 258€"): its laps of
## today's quota (OvertimeTickets.total_for); 0 while it is off.
static func threshold_of(run: RunState, gold: bool) -> int:
	return OvertimeTickets.total_for(run.quota(), laps_of(machine_data(run), gold))


## Medal `gold`'s state in `run`'s week (never PENDING: pending_of says that). While `counting`,
## the shift on screen's own spend waits for its flight (ReceiptGoldFlow), so the medal still
## shows; outside a count the checked-out shift on screen counts.
static func state_of(run: RunState, gold: bool, counting: bool = false) -> State:
	var machine: MachineDefinition = machine_data(run)
	if laps_of(machine, gold) <= 0:
		return State.OFF
	var cap: int = machine.overtime_premium_per_week if gold else machine.overtime_ticket_per_week
	var spent: int = OvertimeTickets.used(run, run.shift_index + 1, gold)
	if not counting and not run.history.is_empty():
		var record: ShiftRecord = run.history[-1]
		var earned: bool = record.overtime_premium if gold else record.overtime_ticket
		if earned and OvertimeCue.counts_shift(run, record):
			spent += 1
	return State.USED if spent >= cap else State.AVAILABLE


## Whether checking out `run`'s planned shift at `projected` would spend medal `gold` (it is
## AVAILABLE, the shift has a machine visit, the projection makes its laps, and the GOLD's visit
## isn't PREMIUM already: a payday's is, so it would not spend it).
static func pending_of(run: RunState, gold: bool, projected: int) -> bool:
	if run.phase != RunState.Phase.PLANNING or run.is_last_shift():
		return false
	if state_of(run, gold) != State.AVAILABLE:
		return false
	var needed: int = laps_of(machine_data(run), gold)
	if OvertimeTickets.laps(projected, run.quota()) < needed:
		return false
	return not gold or run.machine == null or not run.machine.premium_if_passed(run)


## Both medals' states, [SILVER, GOLD], with the projection's PENDING (`projected` below 0:
## none) over AVAILABLE.
static func states(run: RunState, counting: bool, projected: int = -1) -> Array[int]:
	var shown: Array[int] = []
	for gold: bool in [false, true]:
		var state: int = state_of(run, gold, counting)
		if not counting and projected >= 0 and pending_of(run, gold, projected):
			state = State.PENDING
		shown.append(state)
	return shown


## Medal `gold`'s tooltip in `state`: its name, its rule, its state (an available medal on the
## run's last shift: no machine follows to spend it).
static func tip_of(run: RunState, gold: bool, state: int) -> String:
	var words: String = OvertimeWords.STATE_AVAILABLE
	if state == State.PENDING:
		words = OvertimeWords.STATE_PENDING
	elif state == State.USED:
		words = OvertimeWords.STATE_USED
	elif run.is_last_shift():
		words = OvertimeWords.STATE_LAST
	return OvertimeWords.medal_tip(machine_data(run), gold, words)
