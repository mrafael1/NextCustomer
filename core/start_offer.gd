class_name StartOffer
extends RefCounted
## A run's starter pack offer (#107, full build plan 7.2, v0.63), dealt by StartingDeck.deal_offer
## before the run's first shift: the packs offered, today's shared products (the same whichever
## pack is taken), the pack raised for the player (a new profile's "good first pick", or null) and
## how the deal went (the fair-deal check's pack swaps and shared deals, for telemetry). A run
## holds it until the pick (RunState.take_pack), and the run save keeps it, so quitting can't
## reroll the offer.

var packs: Array[StarterPackDefinition] = []
## Today's products, dealt once for every pack.
var shared: Array[CardDefinition] = []
## The pack raised for the player before any click (the recipe's first_pick_pack while the
## profile has never won), or null.
var first_pick: StarterPackDefinition
## Offered packs swapped for an unoffered one by the fair-deal check, and deals of the shared
## products made (1: the first passed, or there is no check).
var swaps: int = 0
var deals: int = 1


## The pack taken when the player isn't asked (a run started without the reveal: tests, captures,
## the demo row): the first pick, else the first pack offered; null for no pack.
func default_pack() -> StarterPackDefinition:
	if first_pick != null:
		return first_pick
	return packs[0] if not packs.is_empty() else null


## The offered pack with this id, or null.
func pack(pack_id: StringName) -> StarterPackDefinition:
	for offered: StarterPackDefinition in packs:
		if offered.id == pack_id:
			return offered
	return null
