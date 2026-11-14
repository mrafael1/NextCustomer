class_name OvertimeWords
extends RefCounted
## The over-quota rewards' words (v1.03, OvertimeTickets; the week's medals since 2026-11-06,
## WeekMedals): the week badge's SILVER and GOLD medals' tooltips, and the machine's words for the
## draws they pay (the SILVER's extra draw, the GOLD's PREMIUM visit). The laps in them ("2×",
## "3×") are the machine data's (MachineDefinition.overtime_*_laps). No ticket wording: the receipt
## feeds once and the draw lamps count its draws.

## The laps' sign, as the gauge's lap lamp shows it (LapLamp.TIMES_TEXT).
const TIMES := "×"
## The medals' names, their rules (the laps from the data), the weekly cap, their states.
const SILVER_NAME := "SILVER MEDAL"
const GOLD_NAME := "GOLD MEDAL"
## The rules: the € that wins it (WeekMedals.threshold_of) and its laps (hover tips revamp,
## approved 2026-11-13); without the € (no run), the laps alone.
const SILVER_RULE := "Score %s in one shift (%s the quota) to get one extra prize draw."
const GOLD_RULE := "Score %s in one shift (%s the quota): that shift's prize machine is PREMIUM."
const SILVER_RULE_LAPS := "Reach %s the quota once this week: one extra prize draw."
const GOLD_RULE_LAPS := "Reach %s the quota once this week: that shift's prize machine is PREMIUM."
const RULE_CAP := "Reach %s the quota %d times a week: %s"
const SILVER_PAYS := "one extra prize draw each time."
const GOLD_PAYS := "that shift's prize machine is PREMIUM each time."
## The tip's tag: how often it can be won.
const ONCE_TAG := "ONCE A WEEK"
const CAP_TAG := "%d TIMES A WEEK"
const STATE_AVAILABLE := "Ready to earn this week."
const STATE_PENDING := "Your plan earns it this checkout."
const STATE_USED := "Used this week. Back next week."
## The run's last shift has no machine visit after it, so nothing can spend a medal.
const STATE_LAST := "Last shift: no prize machine after it."
## The machine's head stamp on a draw a medal paid, and the line under it ("2× quota · extra
## draw").
const SILVER_STAMP := "SILVER MEDAL!"
const GOLD_STAMP := "GOLD MEDAL!"
const SILVER_UNDER := "%s quota · extra draw"
const GOLD_UNDER := "%s quota · premium"
## The receipt read's ending on the GOLD's PREMIUM visit.
const GOLD_READ := " · GOLD MEDAL"
## AGAIN! (the next draw of the same receipt) and its sub line's reason: the SILVER's extra draw, a
## payday's second PREMIUM draw, a bonus draw.
const AGAIN := "EXTRA DRAW!"
const AGAIN_SUB := "%s · draw %d of %d"
const SILVER_REASON := "silver medal"
const BONUS_REASON := "extra draw"
## The key lead on the SILVER's draw.
const SILVER_KEY_LEAD := "silver medal draw"


## "2×", the laps a medal needs (`gold`: the GOLD's, else the SILVER's).
static func laps_text(machine: MachineDefinition, gold: bool) -> String:
	if machine == null:
		return ""
	var laps: int = machine.overtime_premium_laps if gold else machine.overtime_ticket_laps
	return str(laps) + TIMES


## The head stamp's line under it on a draw medal `gold` paid ("2× quota · extra draw").
static func stamp_under(machine: MachineDefinition, gold: bool) -> String:
	return (GOLD_UNDER if gold else SILVER_UNDER) % laps_text(machine, gold)


## A medal's tooltip (`gold`: the GOLD's): its name, its rule (the € that wins it, `threshold`,
## when known, and its laps from the data; its weekly cap) and its state (STATE_*), on 3 lines.
static func medal_tip(
	machine: MachineDefinition, gold: bool, state: String, threshold: int = -1
) -> String:
	var laps: String = laps_text(machine, gold)
	var cap: int = cap_of(machine, gold)
	var rule: String = (GOLD_RULE_LAPS if gold else SILVER_RULE_LAPS) % laps
	if threshold >= 0:
		rule = (GOLD_RULE if gold else SILVER_RULE) % [MonitorText.euros(threshold), laps]
	if cap > 1:
		rule = RULE_CAP % [laps, cap, GOLD_PAYS if gold else SILVER_PAYS]
	return "%s\n%s\n%s" % [GOLD_NAME if gold else SILVER_NAME, rule, state]


## How many times a week medal `gold` can be won (the machine data's; 1 without it).
static func cap_of(machine: MachineDefinition, gold: bool) -> int:
	if machine == null:
		return 1
	return machine.overtime_premium_per_week if gold else machine.overtime_ticket_per_week


## A medal tip's tag: ONCE A WEEK, or how many times.
static func cap_tag(machine: MachineDefinition, gold: bool) -> String:
	var cap: int = cap_of(machine, gold)
	return ONCE_TAG if cap <= 1 else CAP_TAG % cap
