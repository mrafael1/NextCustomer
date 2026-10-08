class_name ScoreState
extends RefCounted
## Working state for one Scoring.score() call. It is created fresh for every call and thrown
## away afterwards, which keeps rules stateless and scoring pure.

var row: Array[CardInstance] = []
## Tags of each slot, changed by the context pass. Copies: definitions are never changed.
var tags: Array[PackedStringArray] = []
## Final payout of each slot, filled in as slots are scanned.
var payouts: PackedInt32Array = PackedInt32Array()
## Effects left by scanned cards for later products.
var effects: Array[ScoreEffect] = []
var steps: Array[ScoreStep] = []
var subtotal: int = 0
## Which slots have been scanned (their payout is final).
var _scanned: PackedByteArray = PackedByteArray()
## For each slot, the products counted as just before / just after it (plan section 3.4). A
## product has its real neighbours, plus any a connector links to it (2 for 1, Shelf swap); a
## link works both ways, so one side can hold several products.
var _before: Array[PackedInt32Array] = []
var _after: Array[PackedInt32Array] = []


func _init(row_cards: Array[CardInstance]) -> void:
	row = row_cards.duplicate()
	var count: int = row.size()
	payouts.resize(count)
	_scanned.resize(count)
	for slot: int in range(count):
		tags.append(definition(slot).tags.duplicate())
		_before.append(PackedInt32Array())
		_after.append(PackedInt32Array())
	# Neighbouring products are adjacent. A coupon between them breaks adjacency unless a
	# connector's rule bridges it in the context pass.
	for slot: int in range(1, count):
		if is_product(slot - 1) and is_product(slot):
			_link(slot - 1, slot)


func size() -> int:
	return row.size()


func definition(slot: int) -> CardDefinition:
	return row[slot].definition


func is_in_row(slot: int) -> bool:
	return slot >= 0 and slot < row.size()


func is_product(slot: int) -> bool:
	return is_in_row(slot) and definition(slot).is_product()


func is_coupon(slot: int) -> bool:
	return is_in_row(slot) and definition(slot).is_coupon()


## The products counted as just before this slot: its real neighbour and any linked to it.
func products_before(slot: int) -> PackedInt32Array:
	return _before[slot] if is_in_row(slot) else PackedInt32Array()


## The products counted as beside this slot, on either side.
func products_beside(slot: int) -> PackedInt32Array:
	return _before[slot] + _after[slot] if is_in_row(slot) else PackedInt32Array()


## The row's first product (coupons skipped), or -1 when the row holds none.
func first_product() -> int:
	for slot: int in range(row.size()):
		if is_product(slot):
			return slot
	return -1


func is_connector(slot: int) -> bool:
	return is_coupon(slot) and definition(slot).is_connector


## The row is compacted, so the last slot is the last filled one.
func is_last_slot(slot: int) -> bool:
	return slot == row.size() - 1


func has_tag(slot: int, tag: String) -> bool:
	return is_in_row(slot) and tags[slot].has(tag)


## Context pass: give a slot a tag, with a receipt step.
func add_tag(slot: int, tag: String, source_slot: int, text: String) -> void:
	var slot_tags: PackedStringArray = tags[slot]
	slot_tags.append(tag)
	tags[slot] = slot_tags
	var step: ScoreStep = add_step(ScoreStep.StepType.TAG_ADDED, slot, source_slot, 0, 0, text)
	step.tag = tag


## Context pass: count two products as adjacent, with a receipt step.
func link_products(left: int, right: int, source_slot: int, text: String) -> void:
	_link(left, right)
	var step: ScoreStep = add_step(ScoreStep.StepType.LINKED, left, source_slot, 0, 0, text)
	step.linked_slot = right


## Records that a card's effect did nothing (a fizzle), with a 0-value receipt step.
## `source_slot` is the card that caused the waste when it isn't the card itself (a reset).
func add_waste(slot: int, text: String, reason: String, source_slot: int = -1) -> void:
	var running: int = payouts[slot] if _scanned[slot] else 0
	var source: int = slot if source_slot < 0 else source_slot
	var step: ScoreStep = add_step(ScoreStep.StepType.WASTED, slot, source, 0, running, text)
	step.reason = reason


## Arms an effect for later cards, with an EFFECT_ARMED step. Effects with the same non-empty
## group replace each other. Whatever the replaced effect had left is wasted, right after the
## new effect's EFFECT_ARMED step (an Egg reset wipes the earlier Egg's unused charges).
func add_effect(effect: ScoreEffect) -> void:
	var source: int = effect.source_slot
	var running: int = payouts[source] if _scanned[source] else 0
	add_step(
		ScoreStep.StepType.EFFECT_ARMED, source, source, effect.armed_value(), running, effect.text
	)
	if effect.group != &"":
		var kept: Array[ScoreEffect] = []
		for existing: ScoreEffect in effects:
			if existing.group != effect.group:
				kept.append(existing)
			else:
				var reset_reason: String = existing.reset_reason()
				if not reset_reason.is_empty():
					add_waste(existing.source_slot, existing.text, reset_reason, effect.source_slot)
		effects = kept
	effects.append(effect)


## End of the value pass: effects that still have something left are wasted.
func report_unused_effects() -> void:
	for effect: ScoreEffect in effects:
		_report_waste(effect)


func _report_waste(effect: ScoreEffect) -> void:
	var reason: String = effect.waste_reason()
	if not reason.is_empty():
		add_waste(effect.source_slot, effect.text, reason)


func drop_spent_effects() -> void:
	var kept: Array[ScoreEffect] = []
	for effect: ScoreEffect in effects:
		if not effect.is_spent():
			kept.append(effect)
	effects = kept


func add_step(
	step_type: ScoreStep.StepType,
	slot: int,
	source_slot: int,
	value: int,
	value_after: int,
	text: String
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = step_type
	step.slot = slot
	step.source_slot = source_slot
	step.value = value
	step.value_after = value_after
	step.subtotal = subtotal
	step.text = text
	steps.append(step)
	return step


func record_payout(slot: int, payout: int) -> void:
	payouts[slot] = payout
	_scanned[slot] = 1
	subtotal += payout
	add_step(ScoreStep.StepType.PAYOUT, slot, slot, payout, payout, definition(slot).display_name)


func to_result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = subtotal
	result.payouts = payouts
	result.tags = tags
	result.steps = steps
	return result


## Packed arrays are copied when read out of an Array, so each side is written back.
func _link(left: int, right: int) -> void:
	var after: PackedInt32Array = _after[left]
	if not after.has(right):
		after.append(right)
		_after[left] = after
	var before: PackedInt32Array = _before[right]
	if not before.has(left):
		before.append(left)
		_before[right] = before
