class_name Scoring
extends RefCounted
## Scores a checkout row in two passes (plan sections 3.2 and 4), with the run's register
## upgrades (plan section 3.8) and the shift's inspections (plan section 3.9).
##
## score() is a pure function: the same row, upgrades and inspections always give the same
## ScoreResult. It uses no randomness, no time and no global state, and never changes card,
## upgrade or inspection definitions. With no upgrades and no inspections, every result is
## exactly what it was before they existed. total() gives the same total as score() without
## the steps (for the balance simulator's row searches, which score millions of rows: the
## passes below keep their work per slot small, e.g. the upgrades' and inspections' rules are
## listed once per row, not looked up again for every slot).


## `upgrades` are the run's upgrades in pick order; an upgrade step's source_index is its index
## in this list. `inspections` are the shift's inspections; an inspection step's source_index
## is its index in that list. `credits` (#108 piece 2) names what Big basket and Extra redraw
## earned: a CREDIT step after each credited slot's PAYOUT, which never changes the total.
static func score(
	row: Array[CardInstance],
	upgrades: Array[UpgradeDefinition] = [],
	inspections: Array[InspectionDefinition] = [],
	credits: ScoreCredits = null
) -> ScoreResult:
	var state: ScoreState = ScoreState.new(row)
	state.credits = credits
	return _run(state, upgrades, inspections).to_result()


## The total score() would give, without the steps that explain it (the balance simulator's
## searches score millions of rows and read only the total).
static func total(
	row: Array[CardInstance],
	upgrades: Array[UpgradeDefinition] = [],
	inspections: Array[InspectionDefinition] = []
) -> int:
	return _run(ScoreState.new(row, false), upgrades, inspections).subtotal


static func _run(
	state: ScoreState, upgrades: Array[UpgradeDefinition], inspections: Array[InspectionDefinition]
) -> ScoreState:
	# The upgrades' rules in order (each upgrade's in turn), with the index of their upgrade in
	# the run's list (which an upgrade step names) and their own index in that upgrade's rules.
	var upgrade_rules: Array[UpgradeRule] = []
	var rule_upgrades: PackedInt32Array = PackedInt32Array()
	var rule_numbers: PackedInt32Array = PackedInt32Array()
	for index: int in range(upgrades.size()):
		var upgrade: UpgradeDefinition = upgrades[index]
		state.product_slot_change += upgrade.extra_slots
		for number: int in range(upgrade.rules.size()):
			upgrade_rules.append(upgrade.rules[number])
			rule_upgrades.append(index)
			rule_numbers.append(number)
	state.upgrade_rules = upgrade_rules
	state.rule_upgrades = rule_upgrades
	# The inspections' rules likewise, with the index of their inspection.
	var inspection_rules: Array[InspectionRule] = []
	var rule_inspections: PackedInt32Array = PackedInt32Array()
	for index: int in range(inspections.size()):
		var inspection: InspectionDefinition = inspections[index]
		state.product_slot_change += inspection.extra_slots
		for rule: InspectionRule in inspection.rules:
			inspection_rules.append(rule)
			rule_inspections.append(index)
	var count: int = state.size()
	# Context pass: tag and adjacency changes for the whole row, before any values.
	for slot: int in range(count):
		for rule: Rule in state.definition(slot).rules:
			rule.modify_context(state, slot)
	if not upgrade_rules.is_empty():
		_upgrade_context(state, upgrades, upgrade_rules, rule_upgrades)
	# Value pass, left to right, for every card, product or coupon.
	var registers: Array = [upgrades, upgrade_rules, rule_upgrades, rule_numbers]
	var checks: Array = [inspections, inspection_rules, rule_inspections]
	for slot: int in range(count):
		_scan(state, slot, registers, checks)
	# Effects that never found a target fizzle at the end (a lost Coffee bonus, unused charges).
	state.report_unused_effects()
	# Upgrades whose condition the row never met fizzle last, on its last slot (#45), then the
	# day events that found nothing to boost (v0.69).
	if state.explain:
		_upgrade_row_fizzles(state, upgrades)
		_inspection_row_fizzles(state, checks)
	return state


## `registers` is [upgrades, their rules, each rule's upgrade index, each rule's index in its
## upgrade], `checks` is [inspections, their rules, each rule's inspection index] (see _run).
static func _scan(state: ScoreState, slot: int, registers: Array, checks: Array) -> void:
	var card: CardDefinition = state.definition(slot)
	var rules: Array[Rule] = card.rules
	var has_rules: bool = not rules.is_empty()
	var upgrade_rules: Array[UpgradeRule] = registers[1]
	var has_upgrades: bool = not upgrade_rules.is_empty()
	var value: int = card.base
	var explain: bool = state.explain
	if explain:
		state.add_step(ScoreStep.StepType.BASE, slot, slot, card.base, value, card.display_name)
	# Coupons never receive effects.
	var gets_effects: bool = (
		card.kind == CardDefinition.Kind.PRODUCT and not state.effects.is_empty()
	)

	# Flat bonuses: the card's own rules, then effects waiting for a product, then upgrades.
	if has_rules:
		for rule: Rule in rules:
			var own_bonus: int = rule.flat_bonus(state, slot)
			if own_bonus != 0:
				value += own_bonus
				if explain:
					var step: ScoreStep = state.add_step(
						ScoreStep.StepType.FLAT, slot, slot, own_bonus, value, rule.text_for(card)
					)
					step.support_slot = rule.flat_support(state, slot)
	if gets_effects:
		for effect: ScoreEffect in state.effects:
			var effect_bonus: int = effect.flat_bonus(state, slot)
			if effect_bonus != 0:
				value += effect_bonus
				if explain:
					state.add_step(
						ScoreStep.StepType.FLAT,
						slot,
						effect.source_slot,
						effect_bonus,
						value,
						effect.text
					)
	if has_upgrades:
		value = _upgrade_flat_bonuses(state, slot, value, registers)
	# Then the shift's day events' (v0.69: Late delivery's -€2, Happy hour's +€3).
	var inspection_rules: Array[InspectionRule] = checks[1]
	var has_checks: bool = not inspection_rules.is_empty()
	if has_checks:
		value = _inspection_flat_bonuses(state, slot, value, checks)
	state.prices[slot] = value

	# Multipliers: the card's own rules, then effects.
	if has_rules:
		for rule: Rule in rules:
			var own_factor: int = rule.multiplier(state, slot)
			if own_factor != 1:
				value *= own_factor
				if explain:
					state.add_step(
						ScoreStep.StepType.MULTIPLIER,
						slot,
						slot,
						own_factor,
						value,
						rule.text_for(card)
					)
	if gets_effects:
		for effect: ScoreEffect in state.effects:
			var effect_factor: int = effect.multiplier(state, slot)
			if effect_factor != 1:
				value *= effect_factor
				if effect.reached_last():
					_reached_step(state, slot, effect, effect_factor, value, registers)
				elif explain:
					state.add_step(
						ScoreStep.StepType.MULTIPLIER,
						slot,
						effect.source_slot,
						effect_factor,
						value,
						effect.text
					)

	# Copies (Repeat) come after the card and effect multipliers, so a copy is never multiplied
	# again by them. A copy always gets its step, even of a 0 payout, so the receipt can
	# explain it.
	if has_rules:
		for rule: Rule in rules:
			var copied_slot: int = rule.copied_from(state, slot)
			if copied_slot >= 0:
				var copied: int = state.payouts[copied_slot]
				value += copied
				var copy_step: ScoreStep = state.add_step(
					ScoreStep.StepType.COPY, slot, slot, copied, value, rule.text_for(card)
				)
				copy_step.linked_slot = copied_slot

	# Upgrade multipliers come last, after a copy (plan section 3.8: the Coupon engine doubles
	# a Repeat's copy). Those with nothing to multiply fizzle after the card's own fizzles.
	var upgrade_fizzles: Array[Vector2i] = []
	if has_upgrades:
		value = _upgrade_multipliers(state, slot, value, registers, upgrade_fizzles)
	# Then the day events' (v0.69: Free samples' ×2); those with nothing to multiply fizzle last.
	var check_fizzles: PackedInt32Array = PackedInt32Array()
	if has_checks:
		value = _inspection_multipliers(state, slot, value, checks, check_fizzles)

	# Final payout overrides (Soup beside Frozen pays 0).
	if has_rules:
		for rule: Rule in rules:
			var final_value: int = rule.final_payout(state, slot, value)
			if final_value != value:
				value = final_value
				if explain:
					state.add_step(
						ScoreStep.StepType.PAYOUT_OVERRIDE,
						slot,
						slot,
						value,
						value,
						rule.text_for(card)
					)
	# Then the shift's inspections (plan section 3.9: the 3rd product pays 0), like Soup's.
	if has_checks:
		value = _inspection_overrides(state, slot, value, checks)

	state.record_payout(slot, value)
	if explain and state.credits != null:
		_add_credit(state, slot, registers[0])

	# Only now do this card's effects for later cards become active, each with an
	# EFFECT_ARMED step (and the WASTED step of any effect it replaces, an Egg reset).
	if has_rules:
		for rule: Rule in rules:
			rule.on_scanned(state, slot)

	if explain:
		_report_fizzles(state, slot, card, registers[0], upgrade_fizzles)
		for at: int in check_fizzles:
			var waste: ScoreStep = _add_inspection_step(
				state, ScoreStep.StepType.WASTED, slot, at, 0, state.payouts[slot], checks
			)
			var rules_of_checks: Array[InspectionRule] = checks[1]
			waste.reason = rules_of_checks[at].wasted_reason(state, slot)
	if not state.effects.is_empty():
		state.drop_spent_effects()


## A use an upgrade's reach gave past a card effect's own charges (#108: Lemon squeezer): counted
## for the upgrade's row fizzle, and its MULTIPLIER step is the upgrade's (from its box).
static func _reached_step(
	state: ScoreState, slot: int, effect: ScoreEffect, factor: int, value: int, registers: Array
) -> void:
	var rule: UpgradeRule = effect.reach_rule
	state.reach_uses[rule] = state.reach_uses.get(rule, 0) + 1
	if not state.explain:
		return
	var upgrades: Array[UpgradeDefinition] = registers[0]
	_add_upgrade_step(
		state,
		ScoreStep.StepType.MULTIPLIER,
		slot,
		effect.reach_upgrade,
		factor,
		value,
		rule.text_for(upgrades[effect.reach_upgrade])
	)


## A CREDIT step after a slot's PAYOUT when a perk with no scoring rule earned it (ScoreCredits).
static func _add_credit(state: ScoreState, slot: int, upgrades: Array[UpgradeDefinition]) -> void:
	var credit: Array = state.credits.credit_for(state.row, slot, upgrades)
	var index: int = credit[0]
	if index < 0:
		return
	var payout: int = state.payouts[slot]
	var step: ScoreStep = _add_upgrade_step(
		state, ScoreStep.StepType.CREDIT, slot, index, payout, payout, upgrades[index].display_name
	)
	step.reason = credit[1]


## Fizzles of this card's own rules (Repeat with nothing to copy, Final markdown not last),
## then of upgrades that had nothing to multiply here: WASTED steps only, no value changes.
static func _report_fizzles(
	state: ScoreState,
	slot: int,
	card: CardDefinition,
	upgrades: Array[UpgradeDefinition],
	upgrade_fizzles: Array[Vector2i]
) -> void:
	for rule: Rule in card.rules:
		var reason: String = rule.wasted_reason(state, slot)
		if not reason.is_empty():
			state.add_waste(slot, rule.text_for(card), reason)
	for fizzle: Vector2i in upgrade_fizzles:
		var upgrade: UpgradeDefinition = upgrades[fizzle.x]
		var upgrade_rule: UpgradeRule = upgrade.rules[fizzle.y]
		var waste: ScoreStep = _add_upgrade_step(
			state,
			ScoreStep.StepType.WASTED,
			slot,
			fizzle.x,
			0,
			state.payouts[slot],
			upgrade_rule.text_for(upgrade)
		)
		waste.reason = upgrade_rule.wasted_reason(state, slot)


## The upgrades' context pass (Rule bender), after the cards': every step it adds is the
## upgrade's, named by its index in the run's upgrades.
static func _upgrade_context(
	state: ScoreState,
	upgrades: Array[UpgradeDefinition],
	upgrade_rules: Array[UpgradeRule],
	rule_upgrades: PackedInt32Array
) -> void:
	var explain: bool = state.explain
	var count: int = state.size()
	for at: int in range(upgrade_rules.size()):
		var rule: UpgradeRule = upgrade_rules[at]
		for slot: int in range(count):
			var first_new: int = state.steps.size()
			rule.modify_context(state, slot)
			if explain:
				for step: ScoreStep in state.steps.slice(first_new):
					step.source_kind = ScoreStep.SourceKind.UPGRADE
					step.source_index = rule_upgrades[at]
					step.text = rule.text_for(upgrades[rule_upgrades[at]])


static func _upgrade_flat_bonuses(
	state: ScoreState, slot: int, value: int, registers: Array
) -> int:
	var upgrade_rules: Array[UpgradeRule] = registers[1]
	for at: int in range(upgrade_rules.size()):
		var rule: UpgradeRule = upgrade_rules[at]
		var bonus: int = rule.flat_bonus(state, slot)
		if bonus != 0:
			value += bonus
			if state.explain:
				var upgrades: Array[UpgradeDefinition] = registers[0]
				var rule_upgrades: PackedInt32Array = registers[2]
				_add_upgrade_step(
					state,
					ScoreStep.StepType.FLAT,
					slot,
					rule_upgrades[at],
					bonus,
					value,
					rule.text_for(upgrades[rule_upgrades[at]])
				)
	return value


## Applies the upgrades' multipliers. A factor aimed at a value of 0 has nothing to multiply:
## it gets no step and is added to `fizzles` as (upgrade index, rule index) instead.
static func _upgrade_multipliers(
	state: ScoreState, slot: int, value: int, registers: Array, fizzles: Array[Vector2i]
) -> int:
	var upgrade_rules: Array[UpgradeRule] = registers[1]
	var rule_upgrades: PackedInt32Array = registers[2]
	for at: int in range(upgrade_rules.size()):
		var rule: UpgradeRule = upgrade_rules[at]
		var factor: int = rule.multiplier(state, slot)
		if factor == 1:
			continue
		if value == 0:
			var rule_numbers: PackedInt32Array = registers[3]
			fizzles.append(Vector2i(rule_upgrades[at], rule_numbers[at]))
			continue
		value *= factor
		if state.explain:
			var upgrades: Array[UpgradeDefinition] = registers[0]
			_add_upgrade_step(
				state,
				ScoreStep.StepType.MULTIPLIER,
				slot,
				rule_upgrades[at],
				factor,
				value,
				rule.text_for(upgrades[rule_upgrades[at]])
			)
	return value


## One WASTED step for each upgrade rule whose condition the whole row never met
## (UpgradeRule.row_wasted_reason), on the row's last slot, carrying that slot's payout.
static func _upgrade_row_fizzles(state: ScoreState, upgrades: Array[UpgradeDefinition]) -> void:
	var last: int = state.size() - 1
	if last < 0:
		return
	for index: int in range(upgrades.size()):
		var upgrade: UpgradeDefinition = upgrades[index]
		for rule: UpgradeRule in upgrade.rules:
			var reason: String = rule.row_wasted_reason(state)
			if reason.is_empty():
				continue
			var waste: ScoreStep = _add_upgrade_step(
				state,
				ScoreStep.StepType.WASTED,
				last,
				index,
				0,
				state.payouts[last],
				rule.text_for(upgrade)
			)
			waste.reason = reason
			waste.row_wide = true


## Applies the day events' flat bonuses, each with a FLAT step (the event's) when it changes the
## value.
static func _inspection_flat_bonuses(
	state: ScoreState, slot: int, value: int, checks: Array
) -> int:
	var inspection_rules: Array[InspectionRule] = checks[1]
	for at: int in range(inspection_rules.size()):
		var rule: InspectionRule = inspection_rules[at]
		var bonus: int = rule.flat_bonus(state, slot, value)
		if bonus == 0:
			continue
		value += bonus
		if state.explain:
			_add_inspection_step(state, ScoreStep.StepType.FLAT, slot, at, bonus, value, checks)
	return value


## Applies the day events' multipliers, each with a MULTIPLIER step (the event's). A factor aimed
## at a value of 0 has nothing to multiply: it gets no step and its rule's index (in checks[1]) is
## added to `fizzles` instead.
static func _inspection_multipliers(
	state: ScoreState, slot: int, value: int, checks: Array, fizzles: PackedInt32Array
) -> int:
	var inspection_rules: Array[InspectionRule] = checks[1]
	for at: int in range(inspection_rules.size()):
		var rule: InspectionRule = inspection_rules[at]
		var factor: int = rule.multiplier(state, slot)
		if factor == 1:
			continue
		if value == 0:
			fizzles.append(at)
			continue
		value *= factor
		if state.explain:
			_add_inspection_step(
				state, ScoreStep.StepType.MULTIPLIER, slot, at, factor, value, checks
			)
	return value


## One WASTED step for each day event rule that never found its target in the row
## (InspectionRule.row_wasted_reason), on the row's last slot, carrying that slot's payout.
static func _inspection_row_fizzles(state: ScoreState, checks: Array) -> void:
	var last: int = state.size() - 1
	var inspection_rules: Array[InspectionRule] = checks[1]
	if last < 0 or inspection_rules.is_empty():
		return
	for at: int in range(inspection_rules.size()):
		var reason: String = inspection_rules[at].row_wasted_reason(state)
		if reason.is_empty():
			continue
		var waste: ScoreStep = _add_inspection_step(
			state, ScoreStep.StepType.WASTED, last, at, 0, state.payouts[last], checks
		)
		waste.reason = reason
		waste.row_wide = true


## A step caused by the day event rule `at` of `checks` (see _run): source_kind INSPECTION,
## source_index its event's index in the shift's list, the rule's receipt text.
static func _add_inspection_step(
	state: ScoreState,
	step_type: ScoreStep.StepType,
	slot: int,
	at: int,
	value: int,
	value_after: int,
	checks: Array
) -> ScoreStep:
	var inspections: Array[InspectionDefinition] = checks[0]
	var inspection_rules: Array[InspectionRule] = checks[1]
	var rule_inspections: PackedInt32Array = checks[2]
	var index: int = rule_inspections[at]
	var step: ScoreStep = state.add_step(
		step_type, slot, slot, value, value_after, inspection_rules[at].text_for(inspections[index])
	)
	step.source_kind = ScoreStep.SourceKind.INSPECTION
	step.source_index = index
	return step


## Applies the inspections' final payout overrides, each with a PAYOUT_OVERRIDE step when it
## changes the value.
static func _inspection_overrides(state: ScoreState, slot: int, value: int, checks: Array) -> int:
	var inspection_rules: Array[InspectionRule] = checks[1]
	for at: int in range(inspection_rules.size()):
		var rule: InspectionRule = inspection_rules[at]
		var final_value: int = rule.final_payout(state, slot, value)
		if final_value == value:
			continue
		value = final_value
		if state.explain:
			var inspections: Array[InspectionDefinition] = checks[0]
			var rule_inspections: PackedInt32Array = checks[2]
			var step: ScoreStep = state.add_step(
				ScoreStep.StepType.PAYOUT_OVERRIDE,
				slot,
				slot,
				value,
				value,
				rule.text_for(inspections[rule_inspections[at]])
			)
			step.source_kind = ScoreStep.SourceKind.INSPECTION
			step.source_index = rule_inspections[at]
	return value


## A step caused by an upgrade: source_kind UPGRADE, source_index its index in the run's
## upgrades. source_slot is the slot the step lands on, never a -1 sentinel.
static func _add_upgrade_step(
	state: ScoreState,
	step_type: ScoreStep.StepType,
	slot: int,
	upgrade_index: int,
	value: int,
	value_after: int,
	text: String
) -> ScoreStep:
	var step: ScoreStep = state.add_step(step_type, slot, slot, value, value_after, text)
	step.source_kind = ScoreStep.SourceKind.UPGRADE
	step.source_index = upgrade_index
	return step
