class_name MachineChuteInfo
extends RefCounted
## One chute's state for the UI (#77, build spec 1.1), from RewardMachine.chute_info: whether it
## is lit, its Regular meter and its exact odds card. The UI only displays it.

## RewardMachine.ChuteState.
var state: int = 0
## LOCKED_SHIFT: the 1-based shift after which the chute opens next, or 0 when it never does.
var opens_after_shift: int = 0
var level: int = 0
var max_level: int = 0
## Whether picking or binning here this visit raises the meter.
var meter_rises: bool = false
var odds: MachineOddsCard
## NEW ITEMS and COUPONS: the cart is at the deck limit, so a pick swaps a card out.
var cart_full: bool = false
## A BONUS visit only (else the defaults): what the shift's first visit, made at this chute,
## changed for its draw now (the odds card's bonus band). The Regular level its meter rose from
## (-1: it didn't rise), whether a prize was kept, and whether that draw spent the run's
## first-visit coupon.
var first_pick_level_before: int = -1
var first_pick_kept: bool = false
var first_pick_spent_coupon: bool = false
