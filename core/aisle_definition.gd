class_name AisleDefinition
extends Resource
## One aisle of the store (full build plan 7.2): a group of products stocked whole when the
## run lists it. Aisles reference cards; cards stay flat in data/cards/. Coupons are never in
## aisles. Definitions are shared by reference and never changed at runtime.

@export var id: StringName = &""
@export var display_name: String = ""
## The aisle sign's colour (the shopping list and the shelf, phase 3).
@export var sign_color: Color = Color()
## Products open from the start: always stocked when the aisle is, never in the machine. An
## aisle with base cards is always listable.
@export var base_cards: Array[CardDefinition] = []
## Products in the aisle's capsule machine (plan 7.1), key item first: stocked only once
## unlocked.
@export var capsule_cards: Array[CardDefinition] = []
