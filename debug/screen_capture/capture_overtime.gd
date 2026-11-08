class_name CaptureOvertime
extends RefCounted
## The screen capture's over-quota reward options (v1.03, OvertimeTickets), kept out of
## ScreenCapture so it stays under gdlint's file length.
##
## `--laps=<n>[,used]` with `--checkout=<seconds>`: before CHECKOUT is pressed the fixed shift's
## quota is lowered so its row makes n laps (2: the SILVER medal's extra draw, 3: the GOLD's
## PREMIUM visit too; 4 and more: the gauge's brighter gold laps), so the count flies the week
## badge's medals into the gauge's lap lamp and turns the receipt (the week medals, 2026-11-06);
## `used` first spends the week's medals (a machine copy with no medal a week), so nothing flies
## and the receipt stays plain. The file gets laps<n>_[used_].
## `--pending=<n>` (CaptureStates, on planning): the fixed shift's quota is lowered so planning's
## projection makes n laps, so the medals it would spend shimmer and the receipt's edges glow in
## their metal. The file gets pending<n>_.
## With `--machine=<seconds>,overtime` the machine's shift makes ×2 and its ticket's visit is
## binned, so the SILVER medal's extra draw (the OVERTIME visit, AGAIN!) is shown;
## `--machine=<seconds>,x3` makes ×3, so the ticket's own visit is the PREMIUM visit the GOLD
## made, its receipt lighting 2 draw lamps; `--machine=<seconds>,lamps` makes ×2 and shows the
## TICKET visit, its receipt lighting 2 draw lamps (CLASSIC). `payday` (2026-11-06) makes the
## machine's shift a payday (a machine copy with it in premium_shifts and bonus_extra_shifts): with
## `lamps` its receipt lights 3 draw lamps (the payday's 2 PREMIUM draws and the SILVER's).
## `--receipt=<option>[,...]` with `--checkout=<seconds>` (2026-11-05, the gold receipt): `rm`
## checks out under reduced motion; `resume` lets the checkout end, then resumes the run as its
## save shows it (the receipt ended at once), the capture `seconds` later. The pointer is parked
## off the stage's hover spots. The file gets receipt_<options>_.

const LAPS_ARGUMENT := "--laps="
const RECEIPT_ARGUMENT := "--receipt="
const OVERTIME_OPTION := "overtime"
const X3_OPTION := "x3"
## --machine's lamps option: the row makes ×2 and the TICKET visit is shown, with 2 draw lamps.
const LAMPS_OPTION := "lamps"
## --machine's payday option: the machine's shift is a payday (REVIEW PASSED, 2 PREMIUM draws).
const PAYDAY_OPTION := "payday"

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


## --receipt's options before CHECKOUT is pressed: reduced motion, the pointer parked.
static func before_receipt_checkout(screen: ShiftScreen) -> void:
	var options: PackedStringArray = _argument(RECEIPT_ARGUMENT).split(",", false)
	if options.is_empty():
		return
	screen.profile.set_reduced_motion(options.has("rm"))
	screen.get_viewport().warp_mouse(Vector2.ONE)
	_part += "receipt_%s_" % "_".join(options)


## --receipt's resume: once the checkout has ended, the run resumes from its save.
static func after_receipt_checkout(screen: ShiftScreen) -> void:
	if not _argument(RECEIPT_ARGUMENT).split(",", false).has("resume"):
		return
	while screen._counting:
		await screen.get_tree().process_frame
	var saved: RunSave = RunSave.new()
	saved.run = screen.run
	saved.run_id = "capture"
	screen._resume_run(saved)


## --machine's overtime and x3 options: the placed row makes ×2 or ×3 (before the checkout);
## payday makes the shift a payday.
static func before_machine_checkout(run: RunState, options: PackedStringArray) -> void:
	if options.has(PAYDAY_OPTION):
		var machine: MachineDefinition = run.machine.machine.duplicate() as MachineDefinition
		var shift: PackedInt32Array = PackedInt32Array([run.shift_index + 1])
		machine.premium_shifts = shift
		machine.bonus_extra_shifts = shift
		run.machine.machine = machine
	if options.has(X3_OPTION):
		_make_laps(run, 3)
	elif options.has(OVERTIME_OPTION) or options.has(LAMPS_OPTION):
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


## --pending: planning's projection makes `laps` of the fixed shift's quota (the medals shimmer,
## the receipt's edges glow at once, so the capture shows them).
static func pending(screen: ShiftScreen, laps: int) -> void:
	_make_laps(screen.run, laps)
	screen._refresh_bar()
	screen._refresh_preview()
	var gold: ReceiptGold = screen._stage.receipt.gold
	var metal: int = gold.pending()
	gold.show_pending(ReceiptGold.PENDING_NONE, true)
	gold.show_pending(metal, true)


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
