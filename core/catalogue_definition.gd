class_name CatalogueDefinition
extends Resource
## Every deck, card variant and badge pin in the game (full build plan 7.3 and 7.4), for the
## unlock check at the end of a run and the badge screen. Exported builds can't reliably list
## res:// folders, so the list is data; a data test checks it against data/decks and data/cards.

## Every deck, the starter included, in data order.
@export var decks: Array[DeckDefinition] = []
## Every card with variant_of, in data order.
@export var variants: Array[CardDefinition] = []
## Every badge pin (#122), in data order: the badge screen lists them so.
@export var pins: Array[PinDefinition] = []
