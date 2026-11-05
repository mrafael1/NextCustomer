class_name OvertimeWords
extends RefCounted
## The over-quota rewards' words (v1.03, OvertimeTickets): the quota gauge's reward chip at the
## checkout, the dessert's stub and banner, the OVERTIME ticket on the machine (the BONUS ticket's
## presentation with its own words) and the PREMIUM ticket an overtime's premium laps made. The
## laps in them ("×2", "×3") are the machine data's (MachineDefinition.overtime_*_laps).

## The gauge's chip (OvertimeChip): the reward earned, or the week's already used.
const CHIP_TICKET := "+1 TICKET"
const CHIP_PREMIUM := "PREMIUM TICKET"
const CHIP_USED := "USED THIS WEEK"
## The OVERTIME ticket: its title (the stub's, the ticket's, the display's), its small line's
## ending after the laps ("×2 over quota · keep me"), the dessert's banner.
const TICKET_TITLE := "OVERTIME TICKET"
const OVER_QUOTA := "%s over quota"
const KEEP_SUFFIX := " · keep me"
const BANNER := "+1 OVERTIME TICKET"
## The machine's head stamp on the OVERTIME visit, and its key lead.
const STAMP := "OVERTIME TICKET!"
const KEY_LEAD := "overtime ticket"
## The machine's dock caption while the OVERTIME ticket's stub waits there (MachineCabinet;
## "OVERTIME TICKET HERE" is wider than the dock).
const DOCK_TEXT := "OVERTIME TICKET"
## The PREMIUM ticket an overtime's premium laps made: the receipt read's ending, the head stamp.
const PREMIUM_READ := " · %s PREMIUM"
const PREMIUM_STAMP := "PREMIUM TICKET!"
## The laps' sign, as the gauge's lap lamp shows it (LapLamp.TIMES_TEXT).
const TIMES := "×"


## "×N", the laps a reward needs (`premium`: the PREMIUM transform's, else the extra ticket's).
static func laps_text(machine: MachineDefinition, premium: bool) -> String:
	if machine == null:
		return ""
	var laps: int = machine.overtime_premium_laps if premium else machine.overtime_ticket_laps
	return TIMES + str(laps)


## "×2 over quota" (`premium`: "×3 over quota").
static func over_quota(machine: MachineDefinition, premium: bool = false) -> String:
	return OVER_QUOTA % laps_text(machine, premium)


## The OVERTIME ticket's small line: "×2 over quota · keep me".
static func ticket_sub(machine: MachineDefinition) -> String:
	return over_quota(machine) + KEEP_SUFFIX


## Whether a ticket's small line `sub` is the OVERTIME ticket's (its title is then TICKET_TITLE).
static func is_ticket_sub(sub: String) -> bool:
	return sub.ends_with((OVER_QUOTA % "") + KEEP_SUFFIX)
