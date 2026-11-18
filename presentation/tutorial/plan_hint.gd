class_name PlanHint
extends Resource
## One reactive hint of the guided run's first week (play test 1, 2026-11-15; cut to the two
## that react to what the row really did, v1.40): a short line that pops in a bubble over the
## item it is about after a move, once per run. Pure data, with the picker (pick) the director
## calls after each placement: the row is scored by the game's own Scoring, so a hint fires on
## what the rules really did.
##
## The line (`text`) is written as the guided lines are: `**WORD**` is a glossary chip and
## `{name}` a figure TutorialText fills.

## When the hint applies to a card in the row:
## - FIRED: the card's own rule changed a payout (its PAIR paid, its ×2 found its item): the
##   first combo;
## - WASTED: the card's own rule did nothing (a WASTED step for its slot): a real mistake.
enum When { FIRED, WASTED }

## The hint's id (its once-per-run key, and its `tutorial_hint` log id).
@export var id: StringName = &""
## The card definition id it is about; empty: any card.
@export var card: StringName = &""
@export var when: When = When.FIRED
## The bubble's title (chunky capitals: "COMBO!", "WASTED").
@export var title: String = ""
@export_multiline var text: String = ""
## The glossary words (TipWords keys) it teaches (the line checker's order: a hint can pop in any
## order, so it teaches every word it uses that the guided steps before it don't).
@export var teaches: PackedStringArray = PackedStringArray()


## A picked hint and the row slot its bubble points at.
class Pick:
	extends RefCounted
	var hint: PlanHint
	var slot: int = 0

	func _init(picked: PlanHint, at: int) -> void:
		hint = picked
		slot = at


## The hint to show after `placed` landed in `row` (scored `result`), skipping the ids in
## `shown`; null for none. `placed` may be null (a hint left waiting while another showed). The
## order: a FIRED hint, then, once the row is `complete` (no slot left: a rule that waits for a
## card still to come is no mistake yet), a WASTED one; the placed card's slot first for each.
static func pick(
	hints: Array[PlanHint],
	row: Array[CardInstance],
	result: ScoreResult,
	placed: CardInstance,
	complete: bool,
	shown: Array[StringName]
) -> Pick:
	var slots: Array[int] = _placed_first(row.size(), row.find(placed))
	for slot: int in slots:
		var fired: PlanHint = _for_card(hints, row[slot], When.FIRED, shown)
		if fired != null and fired_at(result, slot):
			return Pick.new(fired, slot)
	for slot: int in slots:
		var wasted: PlanHint = _for_card(hints, row[slot], When.WASTED, shown)
		if complete and wasted != null and wasted_at(result, slot):
			return Pick.new(wasted, slot)
	return null


## Whether the card at `slot`'s own rule changed a payout in `result`: a FLAT, MULTIPLIER, COPY
## or PAYOUT_OVERRIDE step it caused (on its own slot or a later one) with a value that counts.
static func fired_at(result: ScoreResult, slot: int) -> bool:
	for step: ScoreStep in result.steps:
		if step.source_kind != ScoreStep.SourceKind.CARD or step.source_slot != slot:
			continue
		match step.step_type:
			ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
				if step.value != 0:
					return true
			ScoreStep.StepType.MULTIPLIER:
				if step.value > 1:
					return true
			ScoreStep.StepType.PAYOUT_OVERRIDE:
				return true
	return false


## Whether `result` holds a WASTED step for the own rule of the card at `slot`.
static func wasted_at(result: ScoreResult, slot: int) -> bool:
	for step: ScoreStep in result.steps:
		if (
			step.step_type == ScoreStep.StepType.WASTED
			and step.source_kind == ScoreStep.SourceKind.CARD
			and step.slot == slot
			and not step.row_wide
		):
			return true
	return false


## The row's slots, `first` first (when it is one).
static func _placed_first(count: int, first: int) -> Array[int]:
	var slots: Array[int] = []
	if first >= 0 and first < count:
		slots.append(first)
	for slot: int in count:
		if slot != first:
			slots.append(slot)
	return slots


static func _for_card(
	hints: Array[PlanHint], item: CardInstance, kind: When, shown: Array[StringName]
) -> PlanHint:
	if item == null:
		return null
	for hint: PlanHint in hints:
		var about: bool = hint.card.is_empty() or hint.card == item.definition.id
		if hint.when == kind and about and not shown.has(hint.id):
			return hint
	return null
