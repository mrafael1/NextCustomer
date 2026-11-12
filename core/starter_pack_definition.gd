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
## The aisle (an AisleDefinition id, e.g. &"snacks") the pack needs unlocked before it is offered
## (v1.29, the Snack stand): empty for a pack offered from the first run. An aisle is unlocked
## once it is listable for the profile (RunStock.is_listable: its capsule items unlocked).
@export var needs_aisle: StringName = &""
## The family the pack's Family stickers come preset to (v1.29: the Breakfast run's is Breakfast;
## FamilySticker.chosen), until the player picks another on the belt; empty: pre-filled from the
## row like any other.
@export var sticker_family: String = ""
## The pack's cards before a card was retired from it (v1.29: the Breakfast run held the Breakfast
## sticker), card for card: a run dealt before still resumes (StartingDeck.could_deal). Empty for a
## pack whose cards never changed that way.
@export var former_cards: Array[CardDefinition] = []
## The pack's loyalty perk (v1.29, the user's "Pool + pack guarantee"; Milk bar: Perfect pair,
## Bargain bin: Salvage desk, Snack stand: Grab bag, Home basics: Home goods), or null: the machine
## guarantees it among the LOYALTY offer of the run's first UPGRADE visit (MachineContext.pack_perk;
## the player still picks it, and it takes a box), and the pack's family always fits your cart
## (UpgradeDefinition.fits). The pack's face names it.
@export var loyalty_perk: UpgradeDefinition
