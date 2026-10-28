class_name StarterPackDefinition
extends Resource
## A starter pack (#107, full build plan 7.2, v0.63): three cards that work together, one plan.
## A run's starting cart is the recipe's staples, the pack the player picks from an offer of
## `DeckDefinition.packs_offered` and the products dealt from today's stock (StartingDeck). A
## pack's cards come with it whatever the stock holds, and may go past the recipe's copy_max
## (the Banana bunch's 4 Bananas, decided with the user on 2026-10-26). Definitions are shared by
## reference and never changed at runtime.

@export var id: StringName = &""
@export var display_name: String = ""
## The family the pack's cards boost (a family id of data/families, e.g. "Breakfast"): its face's
## colour and glyph. Presentation only.
@export var family: String = ""
## The pack's cards, in the order they land in the cart.
@export var cards: Array[CardDefinition] = []
## The face's one line: how the cards work together.
@export_multiline var hint_text: String = ""
