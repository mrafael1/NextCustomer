class_name DeckDefinition
extends Resource
## A starting deck (full build plan section 7.3): the cards a run begins with, one entry per
## copy. Definitions are shared by reference and never changed at runtime. The staples are the
## balance data's own list (BalanceDefinition.staples, section 7.2), not a deck's products.
##
## A deck is either fixed (`cards`, e.g. the starter deck the tests and the balance simulator's
## --deck use) or a recipe (v0.49, section 5.2: `random_count` > 0). A recipe's run starts with
## its `core_cards` plus `random_count` products drawn from the run's stock (StartingDeck.deal),
## and the dealt deck is a copy of the recipe with those cards in `cards`.

@export var id: StringName = &""
@export var display_name: String = ""
## Shown when choosing a deck.
@export_multiline var description: String = ""
## A fixed deck's cards; for a dealt recipe, the cards dealt (empty in a recipe's file).
@export var cards: Array[CardDefinition] = []
## A recipe's fixed cards, one entry per copy, dealt first.
@export var core_cards: Array[CardDefinition] = []
## How many products a recipe draws from the run's stock on top of its core cards (0: a fixed
## deck).
@export var random_count: int = 0
## The most copies of one product a dealt recipe holds, its core cards included.
@export var copy_max: int = 0
## An upgrade the run owns from the start (optional): offers skip it, and it takes a box of its
## own on the loyalty card before the upgrade-shift boxes.
@export var starting_upgrade: UpgradeDefinition
## What unlocks this deck; none means it is available from the start.
@export var unlock_condition: UnlockCondition


## Whether this deck is a recipe, dealt at the start of each run (StartingDeck).
func is_recipe() -> bool:
	return random_count > 0
