class_name WriteOffRule
extends Rule
## Write-off (v1.28, a Clearance coupon): the product in the next slot is written off. In the
## context pass it counts as WASTED (ScoreState.wasted, with a WRITTEN_OFF label, not a fizzle) for
## every rule that reads WASTED items (Dusty toffees, Flickering bulb), and it pays ×factor (an
## armed multiplier for that one slot, so a Repeat after it copies the multiplied payout). With no
## product in the next slot it fizzles.

@export var factor: int = 1


func modify_context(state: ScoreState, slot: int) -> void:
	if not _problem(state, slot).is_empty():
		return
	# Marked on a total-only score too, so the WASTED readers count it there (Scoring.total).
	state.wasted[slot + 1] = 1
	var text: String = text_for(state.definition(slot))
	state.add_step(ScoreStep.StepType.WRITTEN_OFF, slot + 1, slot, 0, 0, text)


func on_scanned(state: ScoreState, slot: int) -> void:
	if factor == 1 or not _problem(state, slot).is_empty():
		return
	var text: String = text_for(state.definition(slot))
	state.add_effect(SlotMultiplierEffect.new(slot, text, slot + 1, factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	return _problem(state, slot)


static func _problem(state: ScoreState, slot: int) -> String:
	if not state.is_product(slot + 1):
		return "no item in the next slot"
	return ""
