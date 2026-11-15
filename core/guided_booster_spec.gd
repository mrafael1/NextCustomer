class_name GuidedBoosterSpec
extends Resource
## One fixed aisle booster of the guided first run's deal (the tutorial, GuidedStartDefinition):
## its aisle and the cards it holds, in their place order. A fixed booster has no hit place, so
## no card is RARE (StartSetupRules.deal_fixed deals it as a StartBooster with no hits): each
## card is a plain-tier product of `aisle`, all distinct, at most the balance's
## start_booster_size of them (GuidedStartDefinition.block checks it). Definitions are shared by
## reference and never changed at runtime.

@export var aisle: AisleDefinition
@export var cards: Array[CardDefinition] = []
