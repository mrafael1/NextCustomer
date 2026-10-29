class_name NthSlotZeroPayoutRule
extends InspectionRule
## Inspection (Spot check since 2026-10-28): the card in row position slot_number (1-based;
## products and coupons both count, so it is that slot of the belt) pays 0, like Soup beside
## Frozen: after flat bonuses and multipliers, so bonuses aimed at it are spent and an Egg charge
## is used up. It still arms its own effects, so a coupon there still works. The slot never
## moves: Big basket's extra slot and Short belt's closed one leave it where it is, as Slot
## engine's slot 6 (NthSlotMultiplierRule). With fewer cards in the row it does nothing. 0 means
## no slot.

@export var slot_number: int = 0


func final_payout(_state: ScoreState, slot: int, payout: int) -> int:
	if slot_number <= 0 or slot != slot_number - 1:
		return payout
	return 0
