class_name InspectionDefinition
extends Resource
## One day event as designed (plan section 3.9; v0.69 generalised inspections into day events): a
## visible change to one shift, announced on the previous shift's receipt and shown on the top
## bar's chip during the shift. A MALUS is an inspection (a restriction: Spot check, Short belt);
## a BOON helps (Quiet morning, Extra till). The code keeps the name "inspection" for both; the
## player reads "Today:" on a boon's chip. Only maluses are inspections to the rules: they earn
## INSPECTION PASSED (and a bonus ticket when the machine gives one), and the reviews draw them.
## Day events never go on the loyalty card. Definitions are shared by reference and never changed
## at runtime; the shift's events are a list in RunState. A week event (v0.70, WeekEventDefinition)
## is one too, with the WEEK tone: neither a malus nor a boon, it applies to every shift of its
## week (WeekSchedule.shift_events) and is never in a shift's own list.

## MALUS: an inspection, a restriction (red chip). BOON: a good day (green chip). WEEK: a week
## event (v0.70, WeekEventDefinition), on the week chip.
enum Tone { MALUS, BOON, WEEK }

@export var id: StringName = &""
@export var display_name: String = ""
@export var tone: Tone = Tone.MALUS
## The announcement, printed under the previous shift's total and shown during the shift, e.g.
## "Slot 3 pays €0".
@export_multiline var notice_text: String = ""
## The effect in a few words, for the top bar's chip ("Inspection · −1 slot", mock-up B2; a boon's
## "Today: Quiet morning — quota −10%"); the chip's hover text gives the name and the notice.
@export var chip_text: String = ""
## Scoring rules, asked about every slot by the scoring loop (never attached to a card).
@export var rules: Array[InspectionRule] = []
## Shift modifiers (ShiftLimits), added to the run's limits for this shift only: slots (Short
## belt -1, Extra till +1), redraws (Till jam -1, Regulars' day +1), hand items (Small baskets
## -1; a positive delta is allowed but no live event has one since v0.70: the hand's baskets lay
## out 8 items) and the quota in percent (Rush hour +10, Quiet morning -10).
@export var extra_slots: int = 0
@export var extra_redraws: int = 0
@export var hand_size_delta: int = 0
@export var quota_percent: int = 0


func is_boon() -> bool:
	return tone == Tone.BOON


## Whether this is a week event (v0.70): on the week chip, never an inspection nor a boon.
func is_week() -> bool:
	return tone == Tone.WEEK


## The maluses (the inspections proper) of `events`, in order: never a boon or a week event.
static func maluses(events: Array[InspectionDefinition]) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	for event: InspectionDefinition in events:
		if event.tone == Tone.MALUS:
			found.append(event)
	return found


## The boons of `events`, in order.
static func boons(events: Array[InspectionDefinition]) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	for event: InspectionDefinition in events:
		if event.is_boon():
			found.append(event)
	return found
