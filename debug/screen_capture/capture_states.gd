class_name CaptureStates
extends RefCounted
## The screen capture's small planning states (polish pass 2026-11-03), to review the Redraw
## key's count and the monitor's notice sizes: `--redraws=<used>` spends that many of the shift's
## redraws (the key shows what is left), `--notice=<name>` shows one of NOTICES on the monitor.
## `--handbook=<entry id>` (v1.06) opens the staff handbook over the shift at that entry (its
## example clip on its final state); `--handbook=<entry id>,tab=<group id>` then picks that tab.
## `--pending=<laps>` (2026-11-06, the week medals) makes planning's projection reach that many
## laps of the quota (CaptureOvertime.pending). `--roll=<fraction>[,fall]` (2026-11-08 feedback)
## freezes the receipt's PROJECTED roll (ReceiptRoll) that far through: the belt's last item that
## counts comes off and goes back on (a rise, lifted), or with `fall` only comes off. Without
## --roll a roll from the capture's own setup lands first, so planning shows its settled number.
## `--history[=slip]` (2026-11-08 review) gives the run a played history before the fixed shift,
## every shift passed (with `slip`, the first missed), so the day calendar shows its passed (PAID)
## pips. `--pop=<ms>` (left column v2, 2026-11-09) plays the next day's arrival as after a
## checkout: the count's paper clears, the new stub pops out of the overhead printer, the gauge
## slides back into the top bar, the bell dings and the desk calendar flips from the day before;
## every tween, the calendar and the bell are then frozen `ms` in. Each adds its part to the file
## name (redraws<used>_, notice_<name>_, handbook_<id>_, pending<laps>_, roll<percent>_[fall_],
## history[_slip]_, pop<ms>_). `--prices=<state>:<amount>,...` (price leak, 2026-11-10) gives
## the belt's tickets those pays (CapturePrices), last. `--payday=<on|off>` (payday's look,
## 2026-11-10) makes the planned shift a payday or an ordinary day on a machine copy and shows it
## again (--at-shift=4 is the live schedule's first payday); `--payday=gold` forces the paper gold
## under payday's design, to review it (the game keeps a payday's GOLD medal in its socket, so its
## paper never turns gold); `--payday=quiet` ends the PAYDAY announce at once (before --checkout's
## press too), so its gold receipt is not on the monitor: it leaves no tag (2026-11-10). The file
## gets payday_<look>_.

const REDRAWS_ARGUMENT := "--redraws="
const NOTICE_ARGUMENT := "--notice="
const HANDBOOK_ARGUMENT := "--handbook="
const PENDING_ARGUMENT := "--pending="
const ROLL_ARGUMENT := "--roll="
const HISTORY_ARGUMENT := "--history"
const POP_ARGUMENT := "--pop="
const PAYDAY_ARGUMENT := "--payday="
const PAYDAY_QUIET := "quiet"
## A passed shift's scripted total: the quota and this much over.
const HISTORY_OVER := 5
const NOTICES: Dictionary[String, String] = {
	"day_off": PinFlow.DAY_OFF_ARMED,
	"gun_empty": PinFlow.GUN_EMPTY,
	"gun_none": PinFlow.GUN_NONE,
	"training": WriteUp.OVER_NOTICE,
}


## Applies the states `arguments` (the user arguments) ask for on `screen`; returns the file
## name's part ("" for none).
static func apply(screen: ShiftScreen, arguments: PackedStringArray) -> String:
	var part: String = ""
	var roll: ReceiptRoll = screen._receipt.target.roll
	if roll.rolling():
		roll.snap(roll.goal)  # The capture's own setup rolled the projection: it lands.
	for argument: String in arguments:
		if argument.begins_with(REDRAWS_ARGUMENT):
			var used: int = argument.trim_prefix(REDRAWS_ARGUMENT).to_int()
			screen.run.redraws_used = clampi(used, 0, screen.run.redraws_allowed)
			screen._refresh_buttons()
			part += "redraws%d_" % used
		elif argument.begins_with(NOTICE_ARGUMENT):
			var notice: String = argument.trim_prefix(NOTICE_ARGUMENT)
			screen._notice_label.show_notice(NOTICES.get(notice, notice))
			part += "notice_%s_" % notice
		elif argument.begins_with(HANDBOOK_ARGUMENT):
			var spec: PackedStringArray = argument.trim_prefix(HANDBOOK_ARGUMENT).split(",")
			var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
			page.reduced_motion = Callable()
			page.still = true
			page.open_at(StringName(spec[0]))
			if spec.size() > 1 and spec[1].begins_with("tab="):
				page.show_group(StringName(spec[1].trim_prefix("tab=")))
			part += "handbook_%s_" % spec[0]
		elif argument.begins_with(PENDING_ARGUMENT):
			var laps: int = maxi(argument.trim_prefix(PENDING_ARGUMENT).to_int(), 1)
			CaptureOvertime.pending(screen, laps)
			part += "pending%d_" % laps
		elif argument.begins_with(ROLL_ARGUMENT):
			part += _roll(screen, argument.trim_prefix(ROLL_ARGUMENT).split(","))
		elif argument.begins_with(HISTORY_ARGUMENT):
			var slip: bool = argument.ends_with("=slip")
			_history(screen, slip)
			part += "history_slip_" if slip else "history_"
		elif argument.begins_with(POP_ARGUMENT):
			var ms: int = maxi(argument.trim_prefix(POP_ARGUMENT).to_int(), 0)
			_pop(screen, ms)
			part += "pop%d_" % ms
		elif argument.begins_with(PAYDAY_ARGUMENT):
			var look: String = argument.trim_prefix(PAYDAY_ARGUMENT)
			_payday(screen, look)
			part += "payday_%s_" % look
	return part + CapturePrices.apply(screen, arguments)


## --payday=quiet, before --checkout's press: the announce is over, nothing of it on screen.
static func before_checkout(screen: ShiftScreen) -> void:
	if OS.get_cmdline_user_args().has(PAYDAY_ARGUMENT + PAYDAY_QUIET):
		_end_announce(screen)


## The announce, shown or about to be, is as on a resumed run at once: a payday's is gone (it
## leaves no tag), PREMIUM NEXT's is its hung tag.
static func _end_announce(screen: ShiftScreen) -> void:
	var flow: MachineFlow = screen._machine
	flow._announce_prints = false
	if flow.announce.is_shown():
		flow.announce.show_tag(false, flow.announce.payday)


## --payday: `look` "gold" forces the gold paper, "quiet" ends the announce; "on" or "off"
## makes the planned shift a payday or not on a machine copy and shows the shift again.
static func _payday(screen: ShiftScreen, look: String) -> void:
	if look == "gold":
		screen._receipt.gold.show_gold(true, true)
		return
	if look == PAYDAY_QUIET:
		_end_announce(screen)
		return
	if screen._counting:
		return  # A planned shift only: the count keeps the day it started on.
	var run: RunState = screen.run
	var machine: MachineDefinition = run.machine.machine.duplicate() as MachineDefinition
	var shift: int = run.shift_index + 1
	var premium: Array = Array(machine.premium_shifts)
	var bonus: Array = Array(machine.bonus_extra_shifts)
	premium.erase(shift)
	bonus.erase(shift)
	if look == "on":
		premium.append(shift)
		bonus.append(shift)
	machine.premium_shifts = PackedInt32Array(premium)
	machine.bonus_extra_shifts = PackedInt32Array(bonus)
	run.machine.machine = machine
	screen.debug_show_shift()
	screen._week.skip()


## --pop: the next day's arrival after a checkout, frozen `ms` in.
static func _pop(screen: ShiftScreen, ms: int) -> void:
	var run: RunState = screen.run
	var stage: ShiftStage = screen._stage
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var day: int = run.shift_index + 1
	stage.day_calendar.show_inspections(events, day - 1)
	stage.day_calendar.show_inspections(events, day)
	screen._receipt.begin_count(PackedStringArray(), CardInstance.names(run.row))
	screen._refresh_preview()
	stage.day_calendar.play_change(true)
	var seconds: float = ms / 1000.0
	for tween: Tween in screen.get_tree().get_processed_tweens():
		tween.pause()
		tween.custom_step(seconds)
	stage.day_calendar.advance(seconds)
	stage.day_calendar.set_process(false)
	stage.bell.advance(seconds)
	stage.bell.set_process(false)


## --history: every shift before the fixed one played and passed (the first missed with `slip`),
## then the week's chips and calendar shown again.
static func _history(screen: ShiftScreen, slip: bool) -> void:
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = []
	for shift_number: int in range(1, run.shift_index + 1):
		var quota: int = run.balance.quotas[shift_number - 1]
		var missed: bool = slip and shift_number == 1
		var total: int = quota - HISTORY_OVER if missed else quota + HISTORY_OVER
		history.append(ShiftRecord.new(shift_number, quota, total))
	run.history = history
	screen._week.show_chips()
	screen._stage.day_calendar.play_change(false)


## --roll: starts the projection's roll and freezes it `spec[0]` of the way through. The item
## taken off is the belt's last one whose removal changes the projection.
static func _roll(screen: ShiftScreen, spec: PackedStringArray) -> String:
	var run: RunState = screen.run
	var roll: ReceiptRoll = screen._receipt.target.roll
	roll.snap(roll.goal)  # Any roll from the shift's opening lands first.
	var full: int = roll.goal
	var fall: bool = spec.has("fall")
	for slot: int in range(run.row.size() - 1, -1, -1):
		var card: CardInstance = run.row[slot]
		run.remove(card)
		screen._refresh()
		if roll.goal == full:
			run.place(card, slot)
			screen._refresh()
			continue
		if not fall:
			roll.snap(roll.goal)
			run.place(card, slot)
			screen._refresh()
		break
	var tween: Tween = roll._tween
	var fraction: float = clampf(spec[0].to_float(), 0.0, 1.0)
	if tween != null:
		tween.pause()
		tween.custom_step(fraction * ReceiptRoll.seconds_for(roll.goal - roll.shown))
	return "roll%d_%s" % [roundi(fraction * 100.0), "fall_" if fall else ""]
