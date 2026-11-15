class_name PlanHint
extends Resource
## One reactive hint of the guided shift's free planning (play test 1, 2026-11-15): a short line
## that pops in a bubble over the item it is about (the checkout key for QUOTA) after a move,
## once per run. Pure data, with the picker (pick) the director calls after each placement: the
## row is scored by the game's own Scoring, so a hint fires on what the rules really did.
##
## The line (`text`) is written as the guided lines are: `**WORD**` is a glossary chip and
## `{name}` a figure TutorialText fills.

## When the hint applies to a card in the row:
## - PLACED: the card was just placed (its rule, in a few words);
## - FIRED: the card's own rule changed a payout (its PAIR paid, its ×2 found its item);
## - WASTED: the card's own rule did nothing (a WASTED step for its slot);
## - QUOTA: the row reaches the quota, short of SILVER (no card: the bubble points at CHECKOUT);
## - ROW_FULL: every slot is taken and a card is left in its basket (no card);
## - SILVER, GOLD: the row reaches the SILVER or GOLD medal's total, the machine's laps times the
##   quota (no card: the bubble points at the medal case);
## - REDRAWN: a basket was redrawn (no card: the bubble points at REDRAW; pick_redrawn).
enum When { PLACED, FIRED, WASTED, QUOTA, ROW_FULL, SILVER, GOLD, REDRAWN }

## The bubble's spot for a hint about no card: its Pick's `anchor` says where.
const NO_SLOT := -1

## The hint's id (its once-per-run key, and its `tutorial_hint` log id).
@export var id: StringName = &""
## The card definition id it is about (empty for QUOTA and ROW_FULL).
@export var card: StringName = &""
@export var when: When = When.PLACED
## The bubble's title (chunky capitals: "PAIR!", "WASTED").
@export var title: String = ""
@export_multiline var text: String = ""
## The glossary words (TipWords keys) it teaches (the line checker's order: a hint can pop in any
## order, so it teaches every word it uses that the guided steps before it don't).
@export var teaches: PackedStringArray = PackedStringArray()
## The one-time tip it stands for (TipDefinition id, e.g. T1 REDRAW): its pop marks that tip
## shown, and the tip waits out the guided run's first week (TipScheduler).
@export var covers_tip: StringName = &""


## A picked hint and the row slot its bubble points at (NO_SLOT: the checkout key).
class Pick:
	extends RefCounted
	var hint: PlanHint
	var slot: int = PlanHint.NO_SLOT
	## A hint about no card: the TutorialAnchors id its bubble points at.
	var anchor: StringName = &""

	func _init(picked: PlanHint, at: int, on: StringName = &"") -> void:
		hint = picked
		slot = at
		anchor = on


## The hint to show after `placed` landed in `row` (scored `result`; `totals`: the shift's quota,
## then the SILVER and GOLD medals' totals; `full`: no slot left and a card still in a basket),
## skipping the ids in `shown`; null for none. `placed` may be null (a hint left waiting while
## another showed). The order: the highest of GOLD, SILVER and QUOTA the total reaches (a lower one
## never after a higher one), a FIRED hint (the placed card's first), the placed card's PLACED
## hint, a WASTED hint for a card whose PLACED hint was shown (the placed card's first), then
## ROW_FULL.
static func pick(
	hints: Array[PlanHint],
	row: Array[CardInstance],
	result: ScoreResult,
	placed: CardInstance,
	totals: Array[int],
	full: bool,
	shown: Array[StringName]
) -> Pick:
	var levels: Array[When] = [When.QUOTA, When.SILVER, When.GOLD]
	var anchors: Array[StringName] = [
		TutorialAnchors.CHECKOUT, TutorialAnchors.MEDALS, TutorialAnchors.MEDALS
	]
	for level: int in range(mini(levels.size(), totals.size()) - 1, -1, -1):
		if totals[level] <= 0 or result.total < totals[level]:
			continue
		var reached: PlanHint = _of(hints, levels[level], shown)
		if reached != null:
			return Pick.new(reached, NO_SLOT, anchors[level])
		break  # The highest level reached was told: no lower one now.
	var at: int = row.find(placed)
	var slots: Array[int] = _placed_first(row.size(), at)
	for slot: int in slots:
		var fired: PlanHint = _for_card(hints, row[slot], When.FIRED, shown)
		if fired != null and fired_at(result, slot):
			return Pick.new(fired, slot)
	if at >= 0:
		var intro: PlanHint = _for_card(hints, placed, When.PLACED, shown)
		if intro != null:
			return Pick.new(intro, at)
	for slot: int in slots:
		var wasted: PlanHint = _for_card(hints, row[slot], When.WASTED, shown)
		var told: PlanHint = _for_card(hints, row[slot], When.PLACED, [])
		var introduced: bool = told == null or shown.has(told.id)
		if wasted != null and introduced and wasted_at(result, slot):
			return Pick.new(wasted, slot)
	var filled: PlanHint = _of(hints, When.ROW_FULL, shown)
	if filled != null and full:
		return Pick.new(filled, NO_SLOT, TutorialAnchors.CHECKOUT)
	return null


## The hint to show after a basket was redrawn (REDRAWN), skipping `shown`; null for none.
static func pick_redrawn(hints: Array[PlanHint], shown: Array[StringName]) -> Pick:
	var redrawn: PlanHint = _of(hints, When.REDRAWN, shown)
	return Pick.new(redrawn, NO_SLOT, TutorialAnchors.REDRAW) if redrawn != null else null


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
		if hint.when == kind and hint.card == item.definition.id and not shown.has(hint.id):
			return hint
	return null


static func _of(hints: Array[PlanHint], kind: When, shown: Array[StringName]) -> PlanHint:
	for hint: PlanHint in hints:
		if hint.when == kind and not shown.has(hint.id):
			return hint
	return null
