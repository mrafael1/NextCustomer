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
## The crate's strategy sentence: how the cards work together.
@export_multiline var hint_text: String = ""
## A concrete row and its payoff for the crate (start screen YOUR BUILD): `example_text` names the
## row and ends on its total, `example_cards` is the row and `example_total` its total at shift 1
## with no upgrades or day events (a data test scores it with the live card rules).
@export_multiline var example_text: String = ""
@export var example_cards: Array[CardDefinition] = []
@export var example_total: int = 0
