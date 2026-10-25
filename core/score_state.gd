class_name ScoreState
extends RefCounted
## Working state for one Scoring.score() call. It is created fresh for every call and thrown
## away afterwards, which keeps rules stateless and scoring pure.

var row: Array[CardInstance] = []
## Tags of each slot, changed by the context pass. Copies: definitions are never changed.
var tags: Array[PackedStringArray] = []
## Final payout of each slot, filled in as slots are scanned.
var payouts: PackedInt32Array = PackedInt32Array()
## Each scanned slot's value after its flat bonuses, before any multiplier: the price a
## Banana chain passes on from its middle (AdjacentMatchBonusRule, #106).
var prices: PackedInt32Array = PackedInt32Array()
## 1 for each scanned slot that took a chain bonus (a Banana after a Banana; with Banana stand,
## #108, any Produce after a Produce): such a link passes on its price, a chain's first product
## its payout (AdjacentMatchBonusRule.chain_price).
var chained: PackedByteArray = PackedByteArray()
## The run's upgrade rules and each one's upgrade index (set by Scoring): add_effect asks them
## whether they reach a card's effect further (UpgradeRule.reaches, #108's Lemon squeezer).
var upgrade_rules: Array[UpgradeRule] = []
var rule_upgrades: PackedInt32Array = PackedInt32Array()
## How many uses past an effect's own charges each reaching rule gave (by rule; Scoring counts).
var reach_uses: Dictionary[UpgradeRule, int] = {}
## What the perks with no scoring rule earned (#108 piece 2), or null: CREDIT steps.
var credits: ScoreCredits
## Effects left by scanned cards for later products.
var effects: Array[ScoreEffect] = []
var steps: Array[ScoreStep] = []
var subtotal: int = 0
## Slots the shift has more (+) or fewer (-) than the balance data's, from the run's
## upgrades and the shift's inspections (Big basket +1, Short belt -1). Set by Scoring.score().
## No live rule reads it since the Slot engine keeps to slot 6 (2026-10-24, #106 follow-up); a
## rule may, so the simulator's caches still key on it.
var product_slot_change: int = 0
## Read-only, set when the state is made (a row's kinds never change while it is scored): each
## slot's number among the row's products (coupons skipped; 1 for the first product, 0 for a
## coupon), the row's last product and its first coupon (-1 for none).
var product_numbers: PackedInt32Array = PackedInt32Array()
var last_product: int = -1
var first_coupon: int = -1
## False for a total-only score (Scoring.total): no steps are kept (add_step hands back a
## scratch step that nothing reads), and `row` and each slot's tags are the caller's and the
## definitions' own arrays until add_tag copies them. Totals never depend on the steps.
var explain: bool = true
## Which slots have been scanned (their payout is final).
var _scanned: PackedByteArray = PackedByteArray()
## For each slot, the products counted as just before / just after it (plan section 3.4). A
## product has its real neighbours, plus any a connector links to it (2 for 1, Shelf swap); a
## link works both ways, so one side can hold several products.
var _before: Array[PackedInt32Array] = []
var _after: Array[PackedInt32Array] = []
## The step add_step hands back when `explain` is false.
var _scratch: ScoreStep
## 1 for each slot holding a product (coupon), read by is_product (is_coupon).
var _products: PackedByteArray = PackedByteArray()
var _coupons: PackedByteArray = PackedByteArray()
## Each slot's card definition (definition() reads it).
var _definitions: Array[CardDefinition] = []


func _init(row_cards: Array[CardInstance], explained: bool = true) -> void:
	explain = explained
	row = row_cards.duplicate() if explained else row_cards
	var count: int = row.size()
	payouts.resize(count)
	prices.resize(count)
	chained.resize(count)
	_scanned.resize(count)
	_products.resize(count)
	_coupons.resize(count)
	_definitions.resize(count)
	product_numbers.resize(count)
	tags.resize(count)
	_before.resize(count)
	_after.resize(count)
	var products: int = 0
	for slot: int in range(count):
		var card: CardDefinition = row[slot].definition
		_definitions[slot] = card
		if card.kind == CardDefinition.Kind.PRODUCT:
			_products[slot] = 1
			products += 1
			product_numbers[slot] = products
			last_product = slot
			# Neighbouring products are adjacent. A coupon between them breaks adjacency
			# unless a connector's rule bridges it in the context pass.
			if products > 1 and _products[slot - 1] == 1:
				_after[slot - 1] = PackedInt32Array([slot])
				_before[slot] = PackedInt32Array([slot - 1])
		elif card.kind == CardDefinition.Kind.COUPON:
			_coupons[slot] = 1
			if first_coupon < 0:
				first_coupon = slot
		tags[slot] = card.tags.duplicate() if explained else card.tags


func size() -> int:
	return row.size()


func definition(slot: int) -> CardDefinition:
	return _definitions[slot]


func is_in_row(slot: int) -> bool:
	return slot >= 0 and slot < row.size()


func is_product(slot: int) -> bool:
	return slot >= 0 and slot < _products.size() and _products[slot] == 1


func is_coupon(slot: int) -> bool:
	return slot >= 0 and slot < _coupons.size() and _coupons[slot] == 1


## The products counted as just before this slot: its real neighbour and any linked to it.
func products_before(slot: int) -> PackedInt32Array:
	return _before[slot] if is_in_row(slot) else PackedInt32Array()


## The products counted as beside this slot, on either side.
func products_beside(slot: int) -> PackedInt32Array:
	return _before[slot] + _after[slot] if is_in_row(slot) else PackedInt32Array()


## The row's first product (coupons skipped), or -1 when the row holds none.
func first_product() -> int:
	return _products.find(1)


func is_connector(slot: int) -> bool:
	return is_coupon(slot) and definition(slot).is_connector


## The row is compacted, so the last slot is the last filled one.
func is_last_slot(slot: int) -> bool:
	return slot == row.size() - 1


func has_tag(slot: int, tag: String) -> bool:
	return slot >= 0 and slot < tags.size() and tags[slot].has(tag)


## Context pass: give a slot a tag, with a receipt step.
func add_tag(slot: int, tag: String, source_slot: int, text: String) -> void:
	var slot_tags: PackedStringArray = tags[slot].duplicate()
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
	if not explain:
		return
	var running: int = payouts[slot] if _scanned[slot] else 0
	var source: int = slot if source_slot < 0 else source_slot
	var step: ScoreStep = add_step(ScoreStep.StepType.WASTED, slot, source, 0, running, text)
	step.reason = reason


## Arms an effect for later cards, with an EFFECT_ARMED step. Effects with the same non-empty
## group replace each other. Whatever the replaced effect had left is wasted, right after the
## new effect's EFFECT_ARMED step (an Egg reset wipes the earlier Egg's unused charges).
func add_effect(effect: ScoreEffect) -> void:
	var source: int = effect.source_slot
	if explain:
		var running: int = payouts[source] if _scanned[source] else 0
		add_step(
			ScoreStep.StepType.EFFECT_ARMED,
			source,
			source,
			effect.armed_value(),
			running,
			effect.text
		)
	_reach(effect)
	if effect.group != &"":
		var kept: Array[ScoreEffect] = []
		for existing: ScoreEffect in effects:
			if existing.group != effect.group:
				kept.append(existing)
			elif explain:
				var reset_reason: String = existing.reset_reason()
				if not reset_reason.is_empty():
					add_waste(existing.source_slot, existing.text, reset_reason, effect.source_slot)
		effects = kept
	effects.append(effect)


## An upgrade rule that reaches the arming card's effect further takes it over past the
## effect's own charges (the first such rule; UpgradeRule.reaches).
func _reach(effect: ScoreEffect) -> void:
	var card: CardDefinition = definition(effect.source_slot)
	for at: int in range(upgrade_rules.size()):
		if upgrade_rules[at].reaches(card):
			effect.reach_rule = upgrade_rules[at]
			effect.reach_upgrade = rule_upgrades[at]
			return


## End of the value pass: effects that still have something left are wasted.
func report_unused_effects() -> void:
	if not explain:
		return
	for effect: ScoreEffect in effects:
		_report_waste(effect)


func _report_waste(effect: ScoreEffect) -> void:
	var reason: String = effect.waste_reason()
	if not reason.is_empty():
		add_waste(effect.source_slot, effect.text, reason)


func drop_spent_effects() -> void:
	var spent: bool = false
	for effect: ScoreEffect in effects:
		if effect.is_spent():
			spent = true
			break
	if not spent:
		return
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
	if not explain:
		if _scratch == null:
			_scratch = ScoreStep.new()
		return _scratch
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
	if explain:
		add_step(
			ScoreStep.StepType.PAYOUT, slot, slot, payout, payout, definition(slot).display_name
		)


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
