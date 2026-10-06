class_name SimHandBest
extends RefCounted
## The best checkout row for one hand, found by SimRowSearch.

## The best total, and the hand's cards in that row's order. When several rows tie, the row
## is the shortest of them.
var score: int = 0
var row: Array[CardInstance] = []
## For each card definition in the hand: the best total with every copy of it left out.
var best_without: Dictionary[CardDefinition, int] = {}


## True when the hand can't reach its best total without this card: removing it lowers the
## best score (plan section 8: a card that is never needed is dominated).
func is_needed(definition: CardDefinition) -> bool:
	return best_without.get(definition, score) < score


## True when the best row uses at least one copy of this card.
func uses(definition: CardDefinition) -> bool:
	for card: CardInstance in row:
		if card.definition == definition:
			return true
	return false
