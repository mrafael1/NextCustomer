class_name MachineChuteInfo
extends RefCounted
## One chute's state for the UI (#77, build spec 1.1): whether it can draw on this visit and its
## exact odds card. The UI only displays it.

## RewardMachine.ChuteState.
var state: int = 0
var odds: MachineOddsCard
## The visit is PREMIUM (#108): every drop at least RARE, products at least BIG.
var premium: bool = false
## NEW ITEMS: the cart is at the deck limit, so a pick swaps a card out.
var cart_full: bool = false
## A BONUS visit only (else the defaults): what the shift's first visit, made at this chute,
## changed for its draw now (the odds card's bonus band): whether a prize was kept, and whether
## that draw spent the run's first-visit coupon.
var first_pick_kept: bool = false
var first_pick_spent_coupon: bool = false
## The odds levels the week event raised this visit's draw by (v0.70: Holiday rush's +1,
## WeekSchedule.odds_delta): the stock window says so ("ODDS +1"). 0: none.
var week_odds: int = 0
