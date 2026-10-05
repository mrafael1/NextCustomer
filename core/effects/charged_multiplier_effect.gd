class_name ChargedMultiplierEffect
extends ScoreEffect
## A multiplier for the next N products with a tag (Eggs: ×2 to the next 2 Food products).
## A product with that tag uses a charge even when its payout ends up 0.

var tag: String = ""
var factor: int = 1
var charges: int = 0


func _init(
	effect_source_slot: int,
	effect_text: String,
	effect_group: StringName,
	charge_tag: String,
	charge_factor: int,
	charge_count: int
) -> void:
	super(effect_source_slot, effect_text, effect_group)
	tag = charge_tag
	factor = charge_factor
	charges = charge_count


func multiplier(state: ScoreState, slot: int) -> int:
	if charges <= 0 or not state.has_tag(slot, tag):
		return 1
	charges -= 1
	return factor


func waste_reason() -> String:
	if charges <= 0:
		return ""
	return "%d charge%s unused" % [charges, "" if charges == 1 else "s"]


func reset_reason() -> String:
	if charges <= 0:
		return ""
	return "%d charge%s wiped by a reset" % [charges, "" if charges == 1 else "s"]


func is_spent() -> bool:
	return charges <= 0
