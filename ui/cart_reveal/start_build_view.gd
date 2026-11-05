class_name StartBuildView
extends RefCounted
## Read-only inputs to the staff room. Views need the offer and cards, not the live run machine.

var starter: DeckDefinition
var start_offer: StartOffer
var balance: BalanceDefinition
var pins: Array[PinDefinition] = []
