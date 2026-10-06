class_name Scoring
extends RefCounted
## Scores a checkout row in two passes (plan sections 3.2 and 4), with the run's register
## upgrades (plan section 3.8).
##
## score() is a pure function: the same row and upgrades always give the same ScoreResult. It
## uses no randomness, no time and no global state, and never changes card or upgrade
## definitions. With no upgrades, every result is exactly what it was before upgrades existed.


## `upgrades` are the run's upgrades in pick order; an upgrade step's source_index is its index
## in this list.
static func score(row: Array[CardInstance], upgrades: Array[UpgradeDefinition] = []) -> ScoreResult:
	var state: ScoreState = ScoreState.new(row)
	# Context pass: tag and adjacency changes for the whole row, before any values.
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			rule.modify_context(state, slot)
	# Value pass, left to right, for every card, product or coupon.
	for slot: int in range(state.size()):
		_scan(state, slot, upgrades)
	# Effects that never found a target fizzle at the end (a lost Coffee bonus, unused charges).
	state.report_unused_effects()
	return state.to_result()


static func _scan(state: ScoreState, slot: int, upgrades: Array[UpgradeDefinition]) -> void:
	var card: CardDefinition = state.definition(slot)
	var value: int = card.base
	state.add_step(ScoreStep.StepType.BASE, slot, slot, card.base, value, card.display_name)

	# Flat bonuses: the card's own rules, then effects waiting for a product, then upgrades.
	for rule: Rule in card.rules:
		var own_bonus: int = rule.flat_bonus(state, slot)
		if own_bonus != 0:
			value += own_bonus
			state.add_step(
				ScoreStep.StepType.FLAT, slot, slot, own_bonus, value, rule.text_for(card)
			)
	if card.is_product():
		for effect: ScoreEffect in state.effects:
			var effect_bonus: int = effect.flat_bonus(state, slot)
			if effect_bonus != 0:
				value += effect_bonus
				state.add_step(
					ScoreStep.StepType.FLAT,
					slot,
					effect.source_slot,
					effect_bonus,
					value,
					effect.text
				)
	value = _upgrade_flat_bonuses(state, slot, value, upgrades)

	# Multipliers: the card's own rules, then effects. Coupons never receive effects.
	for rule: Rule in card.rules:
		var own_factor: int = rule.multiplier(state, slot)
		if own_factor != 1:
			value *= own_factor
			state.add_step(
				ScoreStep.StepType.MULTIPLIER, slot, slot, own_factor, value, rule.text_for(card)
			)
	if card.is_product():
		for effect: ScoreEffect in state.effects:
			var effect_factor: int = effect.multiplier(state, slot)
			if effect_factor != 1:
				value *= effect_factor
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
	for rule: Rule in card.rules:
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
	value = _upgrade_multipliers(state, slot, value, upgrades, upgrade_fizzles)

	# Final payout overrides (Soup beside Frozen pays 0).
	for rule: Rule in card.rules:
		var final_value: int = rule.final_payout(state, slot, value)
		if final_value != value:
			value = final_value
			state.add_step(
				ScoreStep.StepType.PAYOUT_OVERRIDE, slot, slot, value, value, rule.text_for(card)
			)

	state.record_payout(slot, value)

	# Only now do this card's effects for later cards become active, each with an
	# EFFECT_ARMED step (and the WASTED step of any effect it replaces, an Egg reset).
	for rule: Rule in card.rules:
		rule.on_scanned(state, slot)

	# Fizzles of this card's own rules (Repeat with nothing to copy, Final markdown not last),
	# then of upgrades that had nothing to multiply here.
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
	state.drop_spent_effects()


static func _upgrade_flat_bonuses(
	state: ScoreState, slot: int, value: int, upgrades: Array[UpgradeDefinition]
) -> int:
	for index: int in range(upgrades.size()):
		var upgrade: UpgradeDefinition = upgrades[index]
		for rule: UpgradeRule in upgrade.rules:
			var bonus: int = rule.flat_bonus(state, slot)
			if bonus != 0:
				value += bonus
				_add_upgrade_step(
					state,
					ScoreStep.StepType.FLAT,
					slot,
					index,
					bonus,
					value,
					rule.text_for(upgrade)
				)
	return value


## Applies the upgrades' multipliers. A factor aimed at a value of 0 has nothing to multiply:
## it gets no step and is added to `fizzles` as (upgrade index, rule index) instead.
static func _upgrade_multipliers(
	state: ScoreState,
	slot: int,
	value: int,
	upgrades: Array[UpgradeDefinition],
	fizzles: Array[Vector2i]
) -> int:
	for index: int in range(upgrades.size()):
		var upgrade: UpgradeDefinition = upgrades[index]
		for rule_index: int in range(upgrade.rules.size()):
			var rule: UpgradeRule = upgrade.rules[rule_index]
			var factor: int = rule.multiplier(state, slot)
			if factor == 1:
				continue
			if value == 0:
				fizzles.append(Vector2i(index, rule_index))
				continue
			value *= factor
			_add_upgrade_step(
				state,
				ScoreStep.StepType.MULTIPLIER,
				slot,
				index,
				factor,
				value,
				rule.text_for(upgrade)
			)
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
