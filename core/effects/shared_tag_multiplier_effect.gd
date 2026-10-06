class_name SharedTagMultiplierEffect
extends ScoreEffect
## A multiplier for every later product that shares at least one tag with a set of tags
## (Multipack: ×2 to every later product sharing a tag with the product before it).

var tags: PackedStringArray = PackedStringArray()
var factor: int = 1
var _applied: bool = false


func _init(
	effect_source_slot: int, effect_text: String, shared_tags: PackedStringArray, shared_factor: int
) -> void:
	super(effect_source_slot, effect_text)
	tags = shared_tags
	factor = shared_factor


func multiplier(state: ScoreState, slot: int) -> int:
	for tag: String in tags:
		if state.has_tag(slot, tag):
			_applied = true
			return factor
	return 1


func waste_reason() -> String:
	return "" if _applied else "no later product shared a tag"
