class_name GrantChargedMultiplierRule
extends Rule
## After scanning, multiplies the next N products with a tag.
## Eggs: ×2 to the next Food product. A later card with the same `group` resets the
## charges instead of adding a second multiplier.
## With `just_after` (Batteries, #128: the Household product just after it pays ×2) only a
## product counted just after this card (a later product whose ScoreState.products_before holds
## this one: its neighbour, or one linked to it) can take the charge; a charge it doesn't take
## is WASTED at the row's end, on this card.

@export var tag: String = ""
@export var factor: int = 1
@export var charges: int = 0
@export var group: StringName = &""
@export var just_after: bool = false


func on_scanned(state: ScoreState, slot: int) -> void:
	if tag.is_empty() or factor == 1 or charges <= 0:
		return
	var card: CardDefinition = state.definition(slot)
	var effect := ChargedMultiplierEffect.new(slot, text_for(card), group, tag, factor, charges)
	if just_after:
		effect.limit_to(CardBatch.products_after(state, slot), "no %s product just after it" % tag)
	state.add_effect(effect)
