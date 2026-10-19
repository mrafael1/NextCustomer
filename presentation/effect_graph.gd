class_name EffectGraph
extends RefCounted
## The planning effects of one ScoreResult (#71): one EffectLink per FLAT, MULTIPLIER, COPY,
## PAYOUT_OVERRIDE, WASTED and EFFECT_ARMED step, with its cause and the item it shows on. Built
## from RunState.preview() steps only (with or without a placed card), so planning never has a
## rule of its own; armed effects are matched by EffectLinks, the count-up's matcher. A superset of
## EffectChip.qualifies (the corner disc's rule). Pure data: no Node, and it never scores.

## The steps that carry a slot's running value (EffectLink.gain is measured from the last one).
const VALUE_STEPS: Array[ScoreStep.StepType] = [
	ScoreStep.StepType.BASE,
	ScoreStep.StepType.FLAT,
	ScoreStep.StepType.MULTIPLIER,
	ScoreStep.StepType.COPY,
	ScoreStep.StepType.PAYOUT_OVERRIDE,
]
## The steps whose links have a gain.
const GAIN_STEPS: Array[ScoreStep.StepType] = [
	ScoreStep.StepType.FLAT,
	ScoreStep.StepType.MULTIPLIER,
	ScoreStep.StepType.COPY,
]

## Every link, in step order.
var links: Array[EffectLink] = []


## The graph of `result`'s steps.
static func build(result: ScoreResult) -> EffectGraph:
	var graph: EffectGraph = EffectGraph.new()
	if result == null:
		return graph
	var steps: Array[ScoreStep] = result.steps
	var landings: PackedInt32Array = EffectLinks.armed_landings(steps)
	var gains: PackedInt32Array = _gains(steps)
	var armed_links: Dictionary[int, EffectLink] = {}
	for index: int in range(steps.size()):
		var link: EffectLink = _link(steps, index, landings)
		if link == null:
			continue
		link.gain = gains[index]
		link.cancelled = link.kind != EffectLink.Kind.DENIED and _overridden_later(steps, index)
		graph.links.append(link)
		if link.kind == EffectLink.Kind.ARMED:
			armed_links[index] = link
	for link: EffectLink in graph.links:
		if link.armed_step == -1 or not armed_links.has(link.armed_step):
			continue
		var armed: EffectLink = armed_links[link.armed_step]
		if link == armed:
			continue
		if link.kind == EffectLink.Kind.FIZZLE:
			armed.fizzled = true
		else:
			armed.landings.append(link.step_index)
			armed.landing_slots.append(link.target_slot)
	for armed: EffectLink in armed_links.values():
		if not armed.landings.is_empty():
			armed.token = EffectLinks.token_text(steps[armed.landings[0]])
	return graph


## The links shown on `slot` (ARMED pips aside), in step order.
func incoming(slot: int) -> Array[EffectLink]:
	var found: Array[EffectLink] = []
	for link: EffectLink in links:
		if link.kind != EffectLink.Kind.ARMED and link.target_slot == slot:
			found.append(link)
	return found


## The links the card at `slot` causes on other items, in step order.
func outgoing(slot: int) -> Array[EffectLink]:
	var found: Array[EffectLink] = []
	for link: EffectLink in links:
		if link.caused_by_card(slot) and link.target_slot != slot:
			found.append(link)
	return found


## The ARMED pips on the card at `slot`, in step order.
func pips(slot: int) -> Array[EffectLink]:
	var found: Array[EffectLink] = []
	for link: EffectLink in links:
		if link.kind == EffectLink.Kind.ARMED and link.target_slot == slot:
			found.append(link)
	return found


## The links upgrade `index` (of the run's upgrades) causes.
func by_upgrade(index: int) -> Array[EffectLink]:
	return _by_source(ScoreStep.SourceKind.UPGRADE, index)


## The links inspection `index` (of the shift's inspections) causes.
func by_inspection(index: int) -> Array[EffectLink]:
	return _by_source(ScoreStep.SourceKind.INSPECTION, index)


## The other slots tied to `slot`: the cards causing its incoming links and the targets of its
## outgoing ones, ascending.
func related_slots(slot: int) -> PackedInt32Array:
	var related: PackedInt32Array = PackedInt32Array()
	for link: EffectLink in incoming(slot):
		if link.cause_kind == ScoreStep.SourceKind.CARD and link.cause_slot != slot:
			related.append(link.cause_slot)
	for link: EffectLink in outgoing(slot):
		related.append(link.target_slot)
	var unique: PackedInt32Array = PackedInt32Array()
	related.sort()
	for other: int in related:
		if unique.is_empty() or unique[unique.size() - 1] != other:
			unique.append(other)
	return unique


func _by_source(kind: ScoreStep.SourceKind, index: int) -> Array[EffectLink]:
	var found: Array[EffectLink] = []
	for link: EffectLink in links:
		if link.cause_kind == kind and link.cause_index == index:
			found.append(link)
	return found


## Each step's gain (EffectLink.gain): for a FLAT, MULTIPLIER or COPY step, its `value_after`
## minus the previous value-carrying step's on its slot; 0 for every other step.
static func _gains(steps: Array[ScoreStep]) -> PackedInt32Array:
	var gains: PackedInt32Array = PackedInt32Array()
	gains.resize(steps.size())
	var running: Dictionary[int, int] = {}
	for index: int in range(steps.size()):
		var step: ScoreStep = steps[index]
		if not VALUE_STEPS.has(step.step_type):
			continue
		if GAIN_STEPS.has(step.step_type):
			gains[index] = step.value_after - running.get(step.slot, 0)
		running[step.slot] = step.value_after
	return gains


## Whether a PAYOUT_OVERRIDE after step `index` replaces its slot's value.
static func _overridden_later(steps: Array[ScoreStep], index: int) -> bool:
	var slot: int = steps[index].slot
	for later: int in range(index + 1, steps.size()):
		var step: ScoreStep = steps[later]
		if step.slot == slot and step.step_type == ScoreStep.StepType.PAYOUT_OVERRIDE:
			return true
	return false


## Step `index`'s link, or null for a step that shows none (BASE, PAYOUT, TAG_ADDED, LINKED).
static func _link(steps: Array[ScoreStep], index: int, landings: PackedInt32Array) -> EffectLink:
	var step: ScoreStep = steps[index]
	var link: EffectLink = EffectLink.new()
	link.target_slot = step.slot
	link.step_index = index
	link.value = step.value
	link.text = step.text
	link.cause_kind = step.source_kind
	if step.source_kind == ScoreStep.SourceKind.CARD:
		link.cause_slot = step.source_slot
	else:
		link.cause_index = step.source_index
	match step.step_type:
		ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER:
			var multiplies: bool = step.step_type == ScoreStep.StepType.MULTIPLIER
			link.kind = EffectLink.Kind.STAMP if multiplies else EffectLink.Kind.BONUS
			link.token = EffectLinks.token_text(step)
			link.armed_step = landings[index]
		ScoreStep.StepType.COPY:
			link.kind = EffectLink.Kind.COPY
			link.cause_slot = step.linked_slot
			link.token = "=€%d" % step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			link.kind = EffectLink.Kind.DENIED
			link.token = "€%d" % step.value
		ScoreStep.StepType.WASTED:
			link.kind = EffectLink.Kind.FIZZLE
			link.token = "pfff"
			link.reason = step.reason
			link.armed_step = EffectLinks.armed_of_waste(steps, index)
		ScoreStep.StepType.EFFECT_ARMED:
			link.kind = EffectLink.Kind.ARMED
			link.token = step.text
			link.armed_step = index
		_:
			return null
	link.own = link.caused_by_card(link.target_slot)
	return link
