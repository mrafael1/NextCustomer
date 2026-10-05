class_name DeckDefinition
extends Resource
## A starting deck: the cards a run begins with, one entry per copy.

@export var id: StringName = &""
@export var display_name: String = ""
@export var cards: Array[CardDefinition] = []
