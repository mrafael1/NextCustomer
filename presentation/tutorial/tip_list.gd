class_name TipList
extends Resource
## The one-time tips (data/tutorial/tips.tres): each a TipDefinition.

const PATH := "res://data/tutorial/tips.tres"

@export var tips: Array[TipDefinition] = []


## The one-time tips (data/tutorial/tips.tres).
static func shared() -> TipList:
	return load(PATH) as TipList


## Tip `tip_id`, or null.
func tip(tip_id: StringName) -> TipDefinition:
	for each: TipDefinition in tips:
		if each.id == tip_id:
			return each
	return null


## The tips `trigger` makes due, in priority order (lower first; ties keep data order).
func for_trigger(trigger: StringName) -> Array[TipDefinition]:
	var found: Array[TipDefinition] = []
	for priority: int in range(_highest() + 1):
		for each: TipDefinition in tips:
			if each.trigger == trigger and each.priority == priority:
				found.append(each)
	return found


func _highest() -> int:
	var highest: int = 0
	for each: TipDefinition in tips:
		highest = maxi(highest, each.priority)
	return highest
