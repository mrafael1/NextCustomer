class_name NthSlotMultiplierRule
extends UpgradeRule
## Upgrade (Slot engine): the card in row position slot_number (1-based; products and coupons
## both count, so it is that slot of the belt) pays x factor, after its own rules, its effects
## and a copy, so a later Repeat copies the multiplied payout. The slot never moves: Big basket's
## extra slot and Short belt's closed one leave it where it is (decided with the user on
## 2026-10-24, #106 follow-up; until then it was the Nth product, moving with the shift's slots).
## A card there that pays 0 has nothing to multiply, so the upgrade fizzles on it; a row with
## fewer cards fizzles once, on its last slot (#45). 0 means no slot. On a Double checkout shift
## (#122) the slot counts across both rows (ScoreState.slot_offset: slot 6 is row 2's slot 2 after
## a row of 4), and row 1 never fizzles for a slot row 2 may still have.

@export var slot_number: int = 0
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	return factor if slot_number > 0 and slot + state.slot_offset == slot_number - 1 else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "slot %d paid nothing" % slot_number


func row_wasted_reason(state: ScoreState) -> String:
	if factor == 1 or slot_number <= 0:
		return ""
	if state.more_rows:
		return ""
	var reach: int = state.slot_offset + state.size()
	return "fewer than %d cards" % slot_number if reach < slot_number else ""
