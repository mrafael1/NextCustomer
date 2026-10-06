class_name CardInstance
extends RefCounted
## One physical copy of a card in a run. Duplicates are separate instances with their own ids.

var definition: CardDefinition
var instance_id: int = 0


func _init(card_definition: CardDefinition, card_instance_id: int) -> void:
	definition = card_definition
	instance_id = card_instance_id
