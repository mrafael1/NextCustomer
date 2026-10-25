class_name NthSlotMultiplierRule
extends UpgradeRule
## Upgrade (Slot engine): the card in row position slot_number (1-based; products and coupons
## both count, so it is that slot of the belt) pays x factor, after its own rules, its effects
## and a copy, so a later Repeat copies the multiplied payout. The slot never moves: Big basket's
## extra slot and Short belt's closed one leave it where it is (decided with the user on
## 2026-10-24, #106 follow-up; until then it was the Nth product, moving with the shift's slots).
## A card there that pays 0 has nothing to multiply, so the upgrade fizzles on it; a row with
## fewer cards fizzles once, on its last slot (#45). 0 means no slot.

@export var slot_number: int = 0
@export var factor: int = 1


func multiplier(_state: ScoreState, slot: int) -> int:
	return factor if slot_number > 0 and slot == slot_number - 1 else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "slot %d paid nothing" % slot_number


func row_wasted_reason(state: ScoreState) -> String:
	if factor == 1 or slot_number <= 0:
		return ""
	return "fewer than %d cards" % slot_number if state.size() < slot_number else ""
