class_name EndSlotsMultiplierRule
extends InspectionRule
## A badge pin's event (Express lane, #132): the row's first and last slots (any card) are
## multiplied by `factor`, after every card, effect and upgrade multiplier. The last slot is the
## row's last open slot (the shift's slot count, ScoreCredits.row_slots: slot 5 on a 5-slot row,
## slot 4 on a Short belt shift), not the last filled one: a row that doesn't reach it gets only
## slot 1's. A bare score (no credits) has no slot count and takes the last filled slot. A card
## paying 0€ there has nothing to multiply (WASTED). On a Double checkout shift each row has its
## own ends.

@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	if factor == 1 or (slot != 0 and slot != last_slot(state)):
		return 1
	return factor


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "nothing to multiply"


## The row's last slot: its last open one when the run gave its slot count, else its last filled.
static func last_slot(state: ScoreState) -> int:
	if state.credits != null and state.credits.row_slots > 0:
		return state.credits.row_slots - 1
	return state.size() - 1
