class_name EffectLinks
extends RefCounted
## Which steps an armed effect lands on or fizzles with (#60's D8, shared with #71's planning
## effects): the one matcher behind the count-up's tokens and pips and the planning chips. It
## reads ScoreResult steps only and never scores.
##
## An EFFECT_ARMED step carries the same text as the FLAT, MULTIPLIER or WASTED steps it causes,
## so the arming card's slot and that text are the key. A landing is a later CARD-sourced FLAT
## or MULTIPLIER step with the same source_slot and text; it lands on the latest such armed step
## before it. A fizzle is a later CARD-sourced WASTED step on the arming card's slot with the
## same text.


## The key an armed step and its landings share.
static func armed_key(step: ScoreStep) -> String:
	return "%d|%s" % [step.source_slot, step.text]


## For each step index, the index of the EFFECT_ARMED step it lands from, or -1.
static func armed_landings(steps: Array[ScoreStep]) -> PackedInt32Array:
	var landings: PackedInt32Array = PackedInt32Array()
	landings.resize(steps.size())
	landings.fill(-1)
	var armed_by_key: Dictionary[String, int] = {}
	for index: int in range(steps.size()):
		var step: ScoreStep = steps[index]
		var key: String = armed_key(step)
		if step.step_type == ScoreStep.StepType.EFFECT_ARMED:
			armed_by_key[key] = index
			continue
		var lands: bool = (
			step.source_kind == ScoreStep.SourceKind.CARD
			and (
				step.step_type == ScoreStep.StepType.FLAT
				or step.step_type == ScoreStep.StepType.MULTIPLIER
			)
			and armed_by_key.has(key)
		)
		if lands:
			landings[index] = armed_by_key[key]
	return landings


## The EFFECT_ARMED step that WASTED step `index` fizzles: the latest one before it on the same
## card with the same text, or -1 (an upgrade's fizzle, or a card rule's own).
static func armed_of_waste(steps: Array[ScoreStep], index: int) -> int:
	var step: ScoreStep = steps[index]
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return -1
	for armed: int in range(index - 1, -1, -1):
		var armed_step: ScoreStep = steps[armed]
		if (
			armed_step.step_type == ScoreStep.StepType.EFFECT_ARMED
			and armed_step.slot == step.slot
			and armed_step.text == step.text
		):
			return armed
	return -1


## What a landing does, on its token or chip: "×3" for a multiplier, "+3" otherwise ("−2" for a
## fall: Late delivery's, v0.69).
static func token_text(step: ScoreStep) -> String:
	if step.step_type == ScoreStep.StepType.MULTIPLIER:
		return "×%d" % step.value
	return "+%d" % step.value if step.value >= 0 else "−%d" % -step.value
