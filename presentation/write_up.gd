class_name WriteUp
extends RefCounted
## A write-up's words (v0.65, the loop rework): a missed quota the run goes on after stamps the
## receipt's margin line (CountUpDessert) and opens the next shift with a notice.

const STAMP := "WRITE-UP %d/%d"
const NOTICE := "Written up (%d/%d): miss one more quota and you're fired"


## The write-up stamp for `run`'s shift just checked out: "WRITE-UP 1/2" for a miss the run goes on
## after, else "" (a pass, or the miss that got the cashier fired).
static func stamp_text(run: RunState) -> String:
	if run.last_result == null or run.passed() or run.phase == RunState.Phase.LOST:
		return ""
	return STAMP % [run.write_ups, run.balance.write_up_limit]


## The notice the shift after a write-up opens with.
static func notice_text(run: RunState) -> String:
	return NOTICE % [run.write_ups, run.balance.write_up_limit]
