class_name CouponBridgeRule
extends UpgradeRule
## Upgrade, context pass (Rule bender): coupons no longer break adjacency between products.
## The last product before a run of coupons and the first product after it count as adjacent,
## for "immediately after" and "beside" alike, so hazards bridge too (Soup beside Frozen
## through a coupon pays 0). Rules that read the real slot don't change: Repeat still copies
## the slot just before it, Multipack still reads the product just before it. A pair a coupon
## already linked (2 for 1) isn't linked again. With nothing to bridge it does nothing.


func modify_context(state: ScoreState, slot: int) -> void:
	if not state.is_product(slot) or not state.is_coupon(slot + 1):
		return
	var after: int = slot + 1
	while state.is_coupon(after):
		after += 1
	if not state.is_product(after) or state.products_before(after).has(slot):
		return
	state.link_products(slot, after, slot, "")
