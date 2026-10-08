class_name RowCapacity
extends RefCounted
## The checkout row's limits (plan section 3.1): at most `slot_count` products and at most
## `slot_count + coupon_slot_count` cards, from the shift's ShiftLimits (upgrades can add
## slots). Only coupons can use the coupon-only room. Cards are
## told apart by `kind`, never by id: every card that isn't a coupon counts as a product here,
## so a card of an unknown kind can't get past the product limit. The row stays one compacted
## list, so these are counts, not positions.


static func card_limit(limits: ShiftLimits) -> int:
	return limits.card_limit()


## Cards that use a product slot: every card that isn't a coupon.
static func product_count(row: Array[CardInstance]) -> int:
	var count: int = 0
	for card: CardInstance in row:
		if not card.definition.is_coupon():
			count += 1
	return count


## True when every product slot is used. A coupon may still fit.
static func products_full(limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	return product_count(row) >= limits.slot_count


## Whether one more card of this kind fits in the row. A card that isn't a coupon needs a
## free product slot as well.
static func fits(limits: ShiftLimits, row: Array[CardInstance], card: CardDefinition) -> bool:
	if row.size() >= card_limit(limits):
		return false
	return card.is_coupon() or not products_full(limits, row)


## Coupon slots in use: the first coupons in the row take them, so a coupon only uses a product
## slot once every coupon slot is taken.
static func coupon_slots_used(limits: ShiftLimits, row: Array[CardInstance]) -> int:
	return mini(row.size() - product_count(row), limits.coupon_slot_count)
