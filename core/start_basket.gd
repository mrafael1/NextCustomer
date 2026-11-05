class_name StartBasket
extends RefCounted
## One of the opening-time board's three baskets (start screen, full build plan 7.2): its source
## (StartSetup.STAPLES or an aisle id) and the cards dealt into it (empty until LOCK IN).

var source: StringName = &""
var cards: Array[CardDefinition] = []


func _init(basket_source: StringName = &"", basket_cards: Array[CardDefinition] = []) -> void:
	source = basket_source
	cards = basket_cards.duplicate()


func copy() -> StartBasket:
	return StartBasket.new(source, cards)


func to_dictionary() -> Dictionary:
	var ids: Array[String] = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return {"source": String(source), "cards": ids}
