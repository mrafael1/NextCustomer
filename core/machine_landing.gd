class_name MachineLanding
extends RefCounted
## What a pick did (#77, build spec 1.6), from RewardMachine.pick, for the UI to animate.

var prize: MachinePrize
## The card copy added to the cart (a product or coupon), or null.
var added: CardInstance
## The cart card swapped out for it at the deck limit, or null.
var replaced: CardInstance
## An item upgrade: [old instance, new instance] per upgraded copy, in deck order.
var upgraded: Array = []
## A loyalty perk: the perk taken and its loyalty card box (its index in the run's upgrades); a
## level-up (#108) replaces the perk already in that box.
var register: UpgradeDefinition
var box_index: int = -1
var level_up: bool = false
var cart_before: int = 0
var cart_after: int = 0
## No other visit follows this shift.
var last_of_shift: bool = false
