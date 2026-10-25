class_name RowCapacity
extends RefCounted
## The checkout row's limit (plan section 3.1, v0.46): at most `slot_count` cards from the
## shift's ShiftLimits (upgrades can add slots, inspections close them). Every slot is a general
## slot: any card, product or coupon, fits any free slot. The row stays one compacted list, so
## this is a count, not positions.


## The most cards the row holds this shift.
static func card_limit(limits: ShiftLimits) -> int:
	return limits.slot_count


## Whether one more card fits in the row.
static func fits(limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	return row.size() < card_limit(limits)


## Whether a whole row fits the shift's limit.
static func row_fits(limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	return row.size() <= card_limit(limits)
