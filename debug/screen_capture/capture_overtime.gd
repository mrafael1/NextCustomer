class_name CaptureOvertime
extends RefCounted
## The screen capture's over-quota reward options (v1.03, OvertimeTickets), kept out of
## ScreenCapture so it stays under gdlint's file length.
##
## `--laps=<n>[,used]` with `--checkout=<seconds>`: before CHECKOUT is pressed the fixed shift's
## quota is lowered so its row makes n laps (2: the extra ticket, 3: the PREMIUM ticket too), so
## the count shows the gauge's reward chip (OvertimeChip); `used` first uses up the week's rewards
## (a machine copy with no reward a week), so the chip reads USED THIS WEEK. The file gets
## laps<n>_[used_].
## With `--machine=<seconds>,overtime` the machine's shift makes ×2 and its ticket's visit is
## binned, so the OVERTIME visit is shown; `--machine=<seconds>,x3` makes ×3, so the ticket's own
## visit is the PREMIUM ticket the laps made.

const LAPS_ARGUMENT := "--laps="
const OVERTIME_OPTION := "overtime"
const X3_OPTION := "x3"

static var _part: String = ""


## --laps: lowers the fixed shift's quota so the row's preview makes the laps asked for (call it
## once the row is placed, before the press).
static func before_checkout(run: RunState) -> void:
	var spec: PackedStringArray = _argument(LAPS_ARGUMENT).split(",", false)
	if spec.is_empty():
		return
	var laps: int = maxi(spec[0].to_int(), 1)
	_make_laps(run, laps)
	if spec.has("used"):
		var machine: MachineDefinition = run.machine.machine.duplicate() as MachineDefinition
		machine.overtime_ticket_per_week = 0
		machine.overtime_premium_per_week = 0
		run.machine.machine = machine
	_part = "laps%d_%s" % [laps, "used_" if spec.has("used") else ""]


## --machine's overtime and x3 options: the placed row makes ×2 or ×3 (before the checkout).
static func before_machine_checkout(run: RunState, options: PackedStringArray) -> void:
	if options.has(X3_OPTION):
		_make_laps(run, 3)
	elif options.has(OVERTIME_OPTION):
		_make_laps(run, 2)


## --machine's overtime option, after the checkout: bins the ticket's visit, so the OVERTIME visit
## waits for its chute. Returns the visit kind the capture shows.
static func after_machine_checkout(run: RunState, options: PackedStringArray, wanted: int) -> int:
	if not options.has(OVERTIME_OPTION) or run.phase != RunState.Phase.MACHINE_CHOOSE:
		return wanted
	var chute: int = RewardMachine.Chute.NEW_ITEMS
	if run.machine.chute_info(run, chute).state != RewardMachine.ChuteState.OPEN:
		chute = RewardMachine.Chute.UPGRADE
	run.machine.choose(run, chute)
	run.machine.bin(run)
	return MachineVisit.Kind.OVERTIME


static func file_part() -> String:
	return _part


## Sets the shift's quota to the row's preview total over `laps` (rounded down, at least 1).
static func _make_laps(run: RunState, laps: int) -> void:
	run.limits.quota = maxi(floori(run.preview().total / float(laps)), 1)


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return ""
