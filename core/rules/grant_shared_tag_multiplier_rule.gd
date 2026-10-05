class_name GrantSharedTagMultiplierRule
extends Rule
## After scanning, multiplies every later product that shares a tag with the product in the
## slot just before this card, using tags after the context pass (Multipack: ×2). In slot 1,
## or after a coupon, it does nothing. Several of these stack.

@export var factor: int = 1


func on_scanned(state: ScoreState, slot: int) -> void:
	var before: int = slot - 1
	if factor == 1 or not state.is_product(before):
		return
	var card: CardDefinition = state.definition(slot)
	state.add_effect(
		SharedTagMultiplierEffect.new(slot, text_for(card), state.tags[before].duplicate(), factor)
	)


func wasted_reason(state: ScoreState, slot: int) -> String:
	if factor == 1 or state.is_product(slot - 1):
		return ""
	return "no product just before it"
