class_name MachineChuteInfo
extends RefCounted
## One chute's state for the UI (#77, build spec 1.1), from RewardMachine.chute_info: whether it
## is lit on this visit and its exact odds card. The UI only displays it.

## RewardMachine.ChuteState.
var state: int = 0
## UNLIT REGISTER or UPGRADES (a Normal visit): the 1-based shift after which the next BOOSTED
## visit comes, or 0 when none is left. 0 for the other chutes.
var opens_after_shift: int = 0
var odds: MachineOddsCard
## NEW ITEMS and COUPONS: the cart is at the deck limit, so a pick swaps a card out.
var cart_full: bool = false
## A BONUS visit only (else the defaults): what the shift's first visit, made at this chute,
## changed for its draw now (the odds card's bonus band): whether a prize was kept, and whether
## that draw spent the run's first-visit coupon.
var first_pick_kept: bool = false
var first_pick_spent_coupon: bool = false
