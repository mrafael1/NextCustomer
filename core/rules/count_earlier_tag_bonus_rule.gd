class_name CountEarlierTagBonusRule
extends Rule
## A flat bonus for each earlier product with a tag, after the context pass.
## Milk: +2 for each earlier Breakfast product. With none it fizzles (#45): a WASTED step, the
## total unchanged. With `distinct_cards` (Fruit salad, #128) it counts each different product
## once (a BIG or GOLDEN tier counts as its plain card): +3 for each Produce kind before it.

@export var tag: String = ""
@export var bonus_each: int = 0
@export var distinct_cards: bool = false


func flat_bonus(state: ScoreState, slot: int) -> int:
	return _earlier_count(state, slot) * bonus_each


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or bonus_each == 0 or _earlier_count(state, slot) > 0:
		return ""
	return "no %s product before it" % tag


func _earlier_count(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return 0
	var numbers: PackedInt32Array = state.product_numbers
	var tags: Array[PackedStringArray] = state.tags
	var count: int = 0
	var kinds: Array[StringName] = []
	for earlier: int in range(mini(slot, numbers.size())):
		if numbers[earlier] > 0 and tags[earlier].has(tag):
			if distinct_cards:
				var kind: StringName = state.definition(earlier).product_card().id
				if kinds.has(kind):
					continue
				kinds.append(kind)
			count += 1
	return count
