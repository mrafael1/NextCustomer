class_name CaptureStates
extends RefCounted
## The screen capture's small planning states (polish pass 2026-11-03), to review the Redraw
## key's count and the monitor's notice sizes: `--redraws=<used>` spends that many of the shift's
## redraws (the key shows what is left), `--notice=<name>` shows one of NOTICES on the monitor.
## Each adds its part to the file name (redraws<used>_, notice_<name>_).

const REDRAWS_ARGUMENT := "--redraws="
const NOTICE_ARGUMENT := "--notice="
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
	return part
