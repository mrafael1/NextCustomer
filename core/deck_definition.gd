class_name DeckDefinition
extends Resource
## A starting deck (full build plan section 7.3): the cards a run begins with, one entry per
## copy. Its distinct products are its staples (section 7.2). Definitions are shared by
## reference and never changed at runtime.

@export var id: StringName = &""
@export var display_name: String = ""
## Shown when choosing a deck.
@export_multiline var description: String = ""
@export var cards: Array[CardDefinition] = []
## An upgrade the run owns from the start (optional): offers skip it, and it takes a box of its
## own on the loyalty card before the upgrade-shift boxes.
@export var starting_upgrade: UpgradeDefinition
## What unlocks this deck; none means it is available from the start.
@export var unlock_condition: UnlockCondition
