class_name NoOvertime
extends RefCounted
## Test helper (v1.03): turns the over-quota rewards (OvertimeTickets) off on a test's balance, for
## tests about other things whose low quotas would make every shift earn an OVERTIME visit or a
## PREMIUM ticket.

const LIVE_BALANCE := "res://data/balance/balance.tres"

## The live balance while live_off() holds it: the resource cache keeps only weak references, so
## without this the next load() would read a fresh one from disk.
static var _held: BalanceDefinition
## The live machine live_off() took off, put back by live_restore(), or by the next live_off()
## when a suite never restored it (so a leak can't turn the rewards off for later suites).
static var _taken: MachineDefinition


## `balance` (a copy the test owns) with its machine a copy whose overtime laps are 0. Returns it.
static func apply(balance: BalanceDefinition) -> BalanceDefinition:
	if balance.machine != null:
		var machine: MachineDefinition = balance.machine.duplicate()
		machine.overtime_ticket_laps = 0
		machine.overtime_premium_laps = 0
		balance.machine = machine
	return balance


## Turns the rewards off on `run`'s own machine (a copy), e.g. a shift screen's run on the live
## balance, before its checkout.
static func on_run(run: RunState) -> void:
	if run.machine == null or run.machine.machine == null:
		return
	var machine: MachineDefinition = run.machine.machine.duplicate()
	machine.overtime_ticket_laps = 0
	machine.overtime_premium_laps = 0
	run.machine.machine = machine


## Turns the rewards off on the live balance itself (the cached resource every run and resume of
## the suite loads, e.g. a shift screen's), for a suite's before_test. Returns the live machine,
## for live_restore() in after_test.
static func live_off() -> MachineDefinition:
	if _held != null and _taken != null:
		_held.machine = _taken  # An earlier suite's leak.
	_held = load(LIVE_BALANCE)
	var machine: MachineDefinition = _held.machine
	_taken = machine
	apply(_held)
	return machine


## Puts the live machine `machine` (from live_off()) back.
static func live_restore(machine: MachineDefinition) -> void:
	if machine != null and _held != null:
		_held.machine = machine
	_held = null
	_taken = null
