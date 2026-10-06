class_name CopyPreviousPayoutRule
extends Rule
## Pays a copy of the final payout of the product in the slot just before this card.
## Repeat. The copy is never multiplied again and triggers nothing. In slot 1, or after a
## coupon (including a connector), it pays 0.


func copied_from(state: ScoreState, slot: int) -> int:
	return slot - 1 if state.is_product(slot - 1) else -1


func wasted_reason(state: ScoreState, slot: int) -> String:
	return "" if state.is_product(slot - 1) else "no product just before it to copy"
