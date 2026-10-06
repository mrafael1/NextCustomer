class_name CatalogueDefinition
extends Resource
## Every deck and card variant in the game (full build plan 7.3), for the unlock check at the
## end of a run. Exported builds can't reliably list res:// folders, so the list is data; a data
## test checks it against data/decks and data/cards.

## Every deck, the starter included, in data order.
@export var decks: Array[DeckDefinition] = []
## Every card with variant_of, in data order.
@export var variants: Array[CardDefinition] = []
