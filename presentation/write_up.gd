class_name WriteUp
extends RefCounted
## The training week's words (v0.68; write-ups since v0.65, TrainingWeek): a missed quota the run
## forgives stamps SLIP n/limit on the receipt's margin line (CountUpDessert) with a "no ticket"
## line, and opens the next shift with a notice; week 1's planning shows a small hint with the
## slips left, and the shift after the training week opens with "Training is over".

const STAMP := "SLIP %d/%d"
## Printed on the receipt under a slip's stamp: the forgiven shift pays no ticket.
const NO_TICKET := "NO TICKET · TRAINING WEEK"
const NOTICE := "Training week: slip %d/%d"
## The notice once the last slip is used: the next miss ends the run.
const LAST_NOTICE := "Training week: slip %d/%d. The next miss ends the run"
## The planning hint (top bar, week 1): the slips the training week still forgives.
const HINT := "TRAINING WEEK · %d SLIPS"
const HINT_ONE := "TRAINING WEEK · 1 SLIP"
## The hint's short form, on the slip sign under the week chip (SlipSign): the slips used of the
## limit.
const HINT_SHORT := "SLIPS %d/%d"
## The notice the first shift after the training week opens with.
const OVER_NOTICE := "Training is over: from now on, any miss ends the run"


## The slip stamp for `run`'s shift just checked out: "SLIP 1/2" for a miss the run goes on after,
## else "" (a pass, or the miss that got the cashier fired).
static func stamp_text(run: RunState) -> String:
	if run.last_result == null or run.passed() or run.phase == RunState.Phase.LOST:
		return ""
	return STAMP % [run.write_ups, run.balance.write_up_limit]


## The notice the shift after a slip opens with.
static func notice_text(run: RunState) -> String:
	var limit: int = run.balance.write_up_limit
	return (LAST_NOTICE if run.write_ups >= limit else NOTICE) % [run.write_ups, limit]


## The planning hint for `run`'s current shift: "TRAINING WEEK · 2 SLIPS" in the training week
## (TrainingWeek.covers; `short`: the slips used, "SLIPS 0/2", at most the limit;
## `before_miss`: without the shift just checked out when it missed, for the count-up before its
## SLIP stamp), else "".
static func hint_text(run: RunState, short: bool = false, before_miss: bool = false) -> String:
	if not TrainingWeek.covers(run.balance, run.shift_index + 1):
		return ""
	if short:
		var used: int = run.write_ups
		if before_miss and not run.history.is_empty() and not run.history[-1].passed:
			used -= 1
		var limit: int = run.balance.write_up_limit
		return HINT_SHORT % [mini(used, limit), limit]
	var left: int = TrainingWeek.slips_left(run)
	return HINT_ONE if left == 1 else HINT % left


## The notice `run`'s current shift opens with (call it once the shift has started): "Training is
## over" on the first shift after the training week, else the slip notice when the shift before
## was a slip (the run's last record a miss), else "".
static func shift_notice(run: RunState) -> String:
	if TrainingWeek.just_ended(run):
		return OVER_NOTICE
	if not run.history.is_empty() and not run.history[-1].passed:
		return notice_text(run)
	return ""
