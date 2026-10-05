class_name GrantNextTagBonusRule
extends Rule
## After scanning, gives a flat bonus once to the next product with a tag, anywhere later.
## Coffee: +3 to the next Breakfast product. With no such product, the bonus is lost.

@export var tag: String = ""
@export var bonus: int = 0


func on_scanned(state: ScoreState, slot: int) -> void:
	if tag.is_empty() or bonus == 0:
		return
	var card: CardDefinition = state.definition(slot)
	state.add_effect(NextTagBonusEffect.new(slot, text_for(card), tag, bonus))
