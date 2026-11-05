class_name CardMorning
extends RefCounted
## The MORNING (#128, Breakfast's identity, the user's call of 2026-11-02): the row's opening run
## of products with the tag (Breakfast), from its first product until one without it. Coupons
## neither join nor end it (the Breakfast sticker's tag counts, ScoreState.has_tag). Read after
## the context pass; it depends only on the row, so every rule sees the same morning.


## The MORNING products' slots, in row order (empty when the first product lacks `tag`).
static func slots(state: ScoreState, tag: String) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	if tag.is_empty():
		return found
	for slot: int in range(state.size()):
		if not state.is_product(slot):
			continue
		if not state.has_tag(slot, tag):
			break
		found.append(slot)
	return found


## The MORNING the belt marks (#128, the keywords handbook's rising suns): its slots when a card
## in the row reads it (a MorningCountRule, or a GrantChargedMultiplierRule's `morning_end`), the
## first such rule's tag; empty otherwise.
static func read(state: ScoreState) -> PackedInt32Array:
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			var count_rule: MorningCountRule = rule as MorningCountRule
			if count_rule != null and not count_rule.tag.is_empty():
				return slots(state, count_rule.tag)
			var grant_rule: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
			if grant_rule != null and grant_rule.morning_end and not grant_rule.tag.is_empty():
				return slots(state, grant_rule.tag)
	return PackedInt32Array()
