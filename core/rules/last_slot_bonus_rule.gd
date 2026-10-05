class_name LastSlotBonusRule
extends Rule
## A flat bonus when this card is in the last filled slot. Final markdown: +6.

@export var bonus: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	return bonus if state.is_last_slot(slot) else 0


func wasted_reason(state: ScoreState, slot: int) -> String:
	return "" if bonus == 0 or state.is_last_slot(slot) else "not in the last slot"
