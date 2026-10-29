class_name TagFlatBonusRule
extends InspectionRule
## Day event: every product carrying `tag` (as the context pass left the tags, so a Shelf swap's
## added tag counts) gets `bonus`, a flat bonus with the card's own (Late delivery: Dairy items pay
## −€2). A negative bonus never takes the item below €0. An empty tag or a 0 bonus does nothing.

@export var tag: String = ""
@export var bonus: int = 0


func flat_bonus(state: ScoreState, slot: int, value: int) -> int:
	if tag.is_empty() or bonus == 0 or not state.is_product(slot) or not state.has_tag(slot, tag):
		return 0
	return maxi(bonus, -maxi(value, 0))
