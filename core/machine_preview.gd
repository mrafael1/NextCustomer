class_name MachinePreview
extends RefCounted
## What picking one prize would do (#77, build spec 1.6), from RewardMachine.preview, for the
## ticket face and the hover card. The UI only displays it; pick does exactly this.

var prize: MachinePrize
## A product or coupon joins the cart.
var adds_card: bool = false
## The cart is full: the pick needs a card swapped out.
var needs_replace: bool = false
## An item upgrade: the copies that step up, in deck order, with the card each becomes.
var targets: Array[CardInstance] = []
var to_cards: Array[CardDefinition] = []
## An item upgrade: how many copies change (SHELF UPGRADE: every copy below GOLDEN).
var copies: int = 0
## A loyalty perk: the loyalty card box it lands in (its index in the run's upgrades); for a
## level-up (#108) the owned perk's box, with the level it has now.
var box_index: int = -1
var level_up: bool = false
var from_level: int = 0
