class_name Scoring
extends RefCounted
## Scores a checkout row in two passes (plan sections 3.2 and 4).
##
## score() is a pure function: the same row always gives the same ScoreResult. It uses no
## randomness, no time and no global state, and never changes card definitions.


static func score(row: Array[CardInstance]) -> ScoreResult:
	var state: ScoreState = ScoreState.new(row)
	# Context pass: tag and adjacency changes for the whole row, before any values.
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			rule.modify_context(state, slot)
	# Value pass, left to right, for every card, product or coupon.
	for slot: int in range(state.size()):
		_scan(state, slot)
	# Effects that never found a target fizzle at the end (a lost Coffee bonus, unused charges).
	state.report_unused_effects()
	return state.to_result()


static func _scan(state: ScoreState, slot: int) -> void:
	var card: CardDefinition = state.definition(slot)
	var value: int = card.base
	state.add_step(ScoreStep.StepType.BASE, slot, slot, card.base, value, card.display_name)

	# Flat bonuses: the card's own rules, then effects waiting for a product.
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

	# Copies (Repeat) come after the multipliers, so a copy is never multiplied again. A copy
	# always gets its step, even of a 0 payout, so the receipt can explain it.
	for rule: Rule in card.rules:
		var copied_slot: int = rule.copied_from(state, slot)
		if copied_slot >= 0:
			var copied: int = state.payouts[copied_slot]
			value += copied
			var copy_step: ScoreStep = state.add_step(
				ScoreStep.StepType.COPY, slot, slot, copied, value, rule.text_for(card)
			)
			copy_step.linked_slot = copied_slot

	# Final payout overrides (Soup beside Frozen pays 0).
	for rule: Rule in card.rules:
		var final_value: int = rule.final_payout(state, slot, value)
		if final_value != value:
			value = final_value
			state.add_step(
				ScoreStep.StepType.PAYOUT_OVERRIDE, slot, slot, value, value, rule.text_for(card)
			)

	state.record_payout(slot, value)

	# Fizzles of this card's own rules (Repeat with nothing to copy, Final markdown not last).
	for rule: Rule in card.rules:
		var reason: String = rule.wasted_reason(state, slot)
		if not reason.is_empty():
			state.add_waste(slot, rule.text_for(card), reason)

	# Only now do this card's effects for later cards become active.
	for rule: Rule in card.rules:
		rule.on_scanned(state, slot)
	state.drop_spent_effects()
