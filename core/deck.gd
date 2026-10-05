class_name Deck
extends RefCounted
## The run's cards, and drawing for a shift.
##
## Every shift draws from the whole deck, freshly shuffled. Cards replaced by the redraw are
## set aside for the rest of that shift, so the redraw can't bring them back. All randomness
## comes from the RandomNumberGenerator passed in, never from the global RNG.

var cards: Array[CardInstance] = []
var _rng: RandomNumberGenerator
var _next_instance_id: int = 1
var _hand: Array[CardInstance] = []
var _draw_pile: Array[CardInstance] = []


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


static func from_definition(deck_definition: DeckDefinition, rng: RandomNumberGenerator) -> Deck:
	var deck: Deck = Deck.new(rng)
	for card_definition: CardDefinition in deck_definition.cards:
		deck.add_card(card_definition)
	return deck


## Adds a new copy of a card, with its own instance id.
func add_card(card_definition: CardDefinition) -> CardInstance:
	var card: CardInstance = CardInstance.new(card_definition, _next_instance_id)
	_next_instance_id += 1
	cards.append(card)
	return card


func remove_card(card: CardInstance) -> void:
	cards.erase(card)


func size() -> int:
	return cards.size()


## Starts a shift: shuffles the whole deck and draws `count` cards (fewer if the deck is smaller).
func draw_hand(count: int) -> Array[CardInstance]:
	_draw_pile = cards.duplicate()
	_shuffle(_draw_pile)
	_hand = []
	while _hand.size() < count and not _draw_pile.is_empty():
		_hand.append(_draw_pile.pop_back())
	return _hand.duplicate()


## Replaces cards in the current hand with new ones from the draw pile. Replaced cards are set
## aside for the rest of the shift. Cards not in the hand are ignored. Returns the new hand,
## with each new card in the place of the card it replaced.
func redraw(replaced: Array[CardInstance]) -> Array[CardInstance]:
	for card: CardInstance in replaced:
		var index: int = _hand.find(card)
		if index == -1 or _draw_pile.is_empty():
			continue
		_hand[index] = _draw_pile.pop_back()
	return _hand.duplicate()


func hand() -> Array[CardInstance]:
	return _hand.duplicate()


## Fisher-Yates shuffle with the run's RNG. Array.shuffle() would use the global RNG.
func _shuffle(pile: Array[CardInstance]) -> void:
	for index: int in range(pile.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var swap: CardInstance = pile[index]
		pile[index] = pile[other]
		pile[other] = swap
