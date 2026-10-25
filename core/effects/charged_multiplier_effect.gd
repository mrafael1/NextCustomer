class_name ChargedMultiplierEffect
extends ScoreEffect
## A multiplier for the next N products with a tag (Eggs: ×2 to the next Food product).
## A product with that tag uses a charge even when its payout ends up 0.

var tag: String = ""
var factor: int = 1
var charges: int = 0
## The last use came from a reaching upgrade (past the charges).
var _reached: bool = false


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


func armed_value() -> int:
	return factor


## With a reaching upgrade (#108), every later product with the tag takes the factor once the
## charges are spent: those uses are the upgrade's (reached_last).
func multiplier(state: ScoreState, slot: int) -> int:
	_reached = false
	if not state.has_tag(slot, tag):
		return 1
	if charges > 0:
		charges -= 1
		return factor
	if reach_rule == null:
		return 1
	_reached = true
	return factor


func reached_last() -> bool:
	return _reached


func waste_reason() -> String:
	if charges <= 0:
		return ""
	return "%d charge%s unused" % [charges, "" if charges == 1 else "s"]


func reset_reason() -> String:
	if charges <= 0:
		return ""
	return "%d charge%s wiped by a reset" % [charges, "" if charges == 1 else "s"]


func is_spent() -> bool:
	return charges <= 0 and reach_rule == null
