class_name SwapPiece
extends RefCounted
## One thing the swap window (SwapWindow) moves: a swap booster's card, or a regular of the
## basket. A card rests in its booster's fan (card form) or, swapped in, on its basket slot (item
## form); a regular rests on its slot, or, swapped out, on the fan spot of the card that took its
## place (OUT). Where it rests comes from the run's regulars (SwapWindow.target); this only holds
## its pose and its flight there. Positions are centres in art px.

var regular: bool = false
var card: CardDefinition
## A regular's slot; a card's booster (0, 1) and its place in the fan.
var slot: int = -1
var booster: int = -1
var k: int = -1
var pos: Vector2 = Vector2.ZERO
var item: bool = false
var sc: float = 1.0
## The rest it flies to or sits at ("" after a drop: it flies from where it was let go).
var key: String = ""
## Its flight: from, from_item, from_sc, to, to_item, t0, dur, bounce, arc (empty: none).
var fly: Dictionary = {}
var bounce: bool = false
## When it landed in the basket (its pop).
var land_t: float = -INF


func _init(
	is_regular: bool, piece_card: CardDefinition, piece_slot: int, bi: int, place: int
) -> void:
	regular = is_regular
	card = piece_card
	slot = piece_slot
	booster = bi
	k = place


## Whether it is in flight at `now`.
func flying(now: float) -> bool:
	return not fly.is_empty() and now - (fly.t0 as float) < (fly.dur as float)
