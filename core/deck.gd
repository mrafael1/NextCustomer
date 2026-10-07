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


## The cards not drawn this shift, the next one to draw last. Cards a redraw replaced are in
## neither the hand nor the draw pile.
func draw_pile() -> Array[CardInstance]:
	return _draw_pile.duplicate()


## The instance id the next new copy gets.
func next_instance_id() -> int:
	return _next_instance_id


## The run save only (RunSave): puts back the saved cards, hand, draw pile and next instance id.
## The hand and the draw pile hold the deck's own instances; a hand card that isn't a deck card
## (a debug copy, or a card a reward replaced after the checkout) is an instance of its own.
func restore(
	deck_cards: Array[CardInstance],
	hand_cards: Array[CardInstance],
	pile: Array[CardInstance],
	next_id: int
) -> void:
	cards = deck_cards.duplicate()
	_hand = hand_cards.duplicate()
	_draw_pile = pile.duplicate()
	_next_instance_id = next_id


## Debug panel only: a copy of a card for this shift's hand. It is not added to the deck.
func add_to_hand(card_definition: CardDefinition) -> CardInstance:
	var card: CardInstance = CardInstance.new(card_definition, _next_instance_id)
	_next_instance_id += 1
	_hand.append(card)
	return card


## Fisher-Yates shuffle with the run's RNG. Array.shuffle() would use the global RNG.
func _shuffle(pile: Array[CardInstance]) -> void:
	for index: int in range(pile.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var swap: CardInstance = pile[index]
		pile[index] = pile[other]
		pile[other] = swap
