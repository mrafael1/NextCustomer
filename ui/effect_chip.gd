class_name EffectChip
extends RefCounted
## Which steps mark a belt item (#75's effect chips; #80, step 7, draws them as one EffectMark per
## item; the base #71 extends): a step that lands on the item from elsewhere (an upgrade, an
## inspection or another card's FLAT or MULTIPLIER) or a WASTED step that fizzled on it. The rule
## only: it reads the ScoreResult's steps and never scores.


## Whether a step marks its item: a WASTED step, or a FLAT or MULTIPLIER step that another source
## caused (an upgrade, an inspection or another card).
static func qualifies(step: ScoreStep) -> bool:
	match step.step_type:
		ScoreStep.StepType.WASTED:
			return true
		ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER:
			return step.source_kind != ScoreStep.SourceKind.CARD or step.source_slot != step.slot
	return false


## The indices into `result.steps` of the steps that mark `slot`, in step order.
static func step_indices(result: ScoreResult, slot: int) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for index: int in range(result.steps.size()):
		var step: ScoreStep = result.steps[index]
		if step.slot == slot and qualifies(step):
			found.append(index)
	return found


## Whether the steps at `indices` of `result` show a fizzle mark (one of them fizzled) rather
## than a check.
static func fizzles(result: ScoreResult, indices: PackedInt32Array) -> bool:
	for index: int in indices:
		if result.steps[index].step_type == ScoreStep.StepType.WASTED:
			return true
	return false
