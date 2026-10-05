class_name GrantChargedMultiplierRule
extends Rule
## After scanning, multiplies the next N products with a tag.
## Eggs: ×2 to the next 2 Food products. A later card with the same `group` resets the
## charges instead of adding a second multiplier.

@export var tag: String = ""
@export var factor: int = 1
@export var charges: int = 0
@export var group: StringName = &""


func on_scanned(state: ScoreState, slot: int) -> void:
	if tag.is_empty() or factor == 1 or charges <= 0:
		return
	var card: CardDefinition = state.definition(slot)
	state.add_effect(ChargedMultiplierEffect.new(slot, text_for(card), group, tag, factor, charges))
