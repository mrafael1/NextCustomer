class_name Payday
extends RefCounted
## Payday's words (v0.68, the loop rework): passing a Manager's review pays two PREMIUM draws
## (MachineDefinition.is_payday_shift: a premium shift with a BONUS visit), shown as one reward. In
## the review's planning the PREMIUM announce reads PAYDAY (PremiumAnnounce) and the inspection
## chip promises no separate bonus ticket; at the machine the head stamp across both draws reads
## REVIEW PASSED. Since 2026-11-06 (the week medals) the receipt feeds once and the reader plate's
## draw lamps count the draws: no second ticket, no stub on the receipt.

## The one reward's line (the week card's payday day, logs, tests).
const BANNER_LINE := "REVIEW PASSED · 2 PREMIUM DRAWS"
## The machine's head stamp and the line under it (none since 2026-11-06: the lamps count the
## draws), on every one of the payday's draws.
const STAMP := "REVIEW PASSED"
const STAMP_UNDER := ""
## The display's title for a payday's draw (MachineDisplay; no second ticket since 2026-11-06).
const TICKET_TITLE := "PREMIUM TICKET"
## The display's lines: the receipt read's ending, a later draw's reason, the chute's sub line, the
## landing's end ("%d": the draws).
const READ := " · REVIEW PASSED"
const REASON := "review passed"
const CHUTE_SUB := "review passed · premium · pick a chute"
const END_SUB := "%d premium prizes this shift"
const KEY_LEAD := "premium draw"
## The planning announce's texts (PremiumAnnounce; it leaves no tag since 2026-11-10).
const ANNOUNCE_HEAD := "PASS THE REVIEW"
const ANNOUNCE_TITLE := "PAYDAY"
const ANNOUNCE_BOOSTS: Array[String] = ["2 PREMIUM DRAWS", "EVERY TICKET RARE+"]


## Whether passing `run`'s current shift is a payday (its pass pays two PREMIUM tickets). False on
## the last shift, which no machine follows.
static func if_passed(run: RunState) -> bool:
	if run.machine == null or run.is_last_shift():
		return false
	return run.machine.machine.is_payday_shift(run.shift_index + 1)
