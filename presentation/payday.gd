class_name Payday
extends RefCounted
## Payday's words (v0.68, the loop rework): passing a Manager's review pays two PREMIUM tickets
## (MachineDefinition.is_payday_shift: a premium shift with a BONUS visit), shown as one reward. In
## the review's planning the PREMIUM announce reads PAYDAY (PremiumAnnounce) and the inspection
## chip promises no separate bonus ticket; at the checkout the receipt's stub banner, then the
## machine's head stamp across both visits, read REVIEW PASSED · 2 PREMIUM TICKETS.

## The one banner, in two lines (the dessert's, beside the receipt) or one (logs, tests).
const BANNER := "REVIEW PASSED\n2 PREMIUM TICKETS"
const BANNER_LINE := "REVIEW PASSED · 2 PREMIUM TICKETS"
## The machine's head stamp and the line under it, on both of the payday's visits.
const STAMP := "REVIEW PASSED"
const STAMP_UNDER := "2 PREMIUM TICKETS"
## The second ticket (the BONUS visit's): its title, its small line and the display's lines.
const TICKET_TITLE := "PREMIUM TICKET"
const TICKET_SUB := "review passed · 2 of 2"
const READ := " · REVIEW PASSED"
const FEED_SUB := "2nd premium ticket · feeding in"
const CHUTE_SUB := "2nd premium ticket · pick a chute"
const END_SUB := "2 premium prizes this shift"
const KEY_LEAD := "premium 2/2"
## The planning announce's texts (PremiumAnnounce) and its hanging tag.
const ANNOUNCE_HEAD := "PASS THE REVIEW"
const ANNOUNCE_TITLE := "PAYDAY"
const ANNOUNCE_BOOSTS: Array[String] = ["2 PREMIUM TICKETS", "EVERY TICKET RARE+"]
const TAG := "PAYDAY NEXT"


## Whether passing `run`'s current shift is a payday (its pass pays two PREMIUM tickets). False on
## the last shift, which no machine follows.
static func if_passed(run: RunState) -> bool:
	if run.machine == null or run.is_last_shift():
		return false
	return run.machine.machine.is_payday_shift(run.shift_index + 1)
