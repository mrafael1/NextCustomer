class_name GrantChargedMultiplierRule
extends Rule
## After scanning, multiplies the next N products with a tag.
## Eggs: ×2 to the next Food product. A later card with the same `group` resets the
## charges instead of adding a second multiplier.
## Batteries (#128) work like Eggs on Household: ×2 to the next 2 Household products (2 charges
## since v1.29; the user's call of 2026-11-02: until then only the product just after them could
## take the charge).
## With `percent` (Stale popcorn, #128 v3: the redraw tension, the user's call of 2026-11-02) its
## factor grows with the shift's redraws left (ScoreState.redraws_left): `factor` times (1 plus
## `percent`% for each), ×1/×2/×3 with 0/1/2 left at factor 1 and 100%, Golden factor 2:
## ×2/×4/×6 (the user's call of 2026-11-02). It goes through ChargedMultiplierEffect.factor_percent,
## so a fractional factor rounds half up; one of ×1 (factor 1, none left) is WASTED.

@export var tag: String = ""
@export var factor: int = 1
@export var charges: int = 0
@export var group: StringName = &""
@export var percent: int = 0
## If set (Tea bags, #128 Breakfast), only the last `charges` products with `tag` after this card
## in the row can take a charge; with none after it, it is WASTED.
@export var last_only: bool = false


func on_scanned(state: ScoreState, slot: int) -> void:
	if tag.is_empty() or (factor == 1 and percent <= 0) or charges <= 0:
		return
	var factor_percent: int = 0
	var armed_factor: int = factor
	if percent > 0:
		factor_percent = live_percent(state.redraws_left)
		if factor_percent <= 100:
			return
		armed_factor = maxi(ScoreStep.times_percent(1, factor_percent), 2)
	var card: CardDefinition = state.definition(slot)
	var effect := ChargedMultiplierEffect.new(
		slot, text_for(card), group, tag, armed_factor, charges
	)
	effect.factor_percent = factor_percent
	if last_only:
		var ends: PackedInt32Array = last_ends(state, slot)
		if ends.is_empty():
			return
		effect.limit_to(ends, "no %s item after it" % tag)
	state.add_effect(effect)


func wasted_reason(state: ScoreState, slot: int) -> String:
	if last_only and charges > 0 and last_ends(state, slot).is_empty():
		return "no %s item after it" % tag
	if percent > 0 and live_percent(state.redraws_left) <= 100:
		return "no redraw left this shift"
	return ""


## The live factor in percent with `redraws_left`: `factor` times (100 plus `percent` for each).
func live_percent(redraws_left: int) -> int:
	return factor * (100 + percent * maxi(redraws_left, 0))


## The last `charges` products with `tag` after `slot` (#128 Tea bags), in row order.
func last_ends(state: ScoreState, slot: int) -> PackedInt32Array:
	var after: PackedInt32Array = PackedInt32Array()
	for other: int in range(slot + 1, state.size()):
		if state.is_product(other) and state.has_tag(other, tag):
			after.append(other)
	if after.size() > charges:
		after = after.slice(after.size() - charges)
	return after
