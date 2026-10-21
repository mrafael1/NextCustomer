class_name CountEarlierTagBonusRule
extends Rule
## A flat bonus for each earlier product with a tag, after the context pass.
## Milk: +2 for each earlier Breakfast product.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return 0
	var numbers: PackedInt32Array = state.product_numbers
	var tags: Array[PackedStringArray] = state.tags
	var count: int = 0
	for earlier: int in range(mini(slot, numbers.size())):
		if numbers[earlier] > 0 and tags[earlier].has(tag):
			count += 1
	return count * bonus_each
