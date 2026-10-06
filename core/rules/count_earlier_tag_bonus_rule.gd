class_name CountEarlierTagBonusRule
extends Rule
## A flat bonus for each earlier product with a tag, after the context pass.
## Milk: +2 for each earlier Breakfast product.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return 0
	var count: int = 0
	for earlier: int in range(slot):
		if state.is_product(earlier) and state.has_tag(earlier, tag):
			count += 1
	return count * bonus_each
