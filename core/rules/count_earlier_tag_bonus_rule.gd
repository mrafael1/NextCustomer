class_name CountEarlierTagBonusRule
extends Rule
## A flat bonus for each earlier product with a tag, after the context pass.
## Milk: +2 for each earlier Breakfast product. With none it fizzles (#45): a WASTED step, the
## total unchanged.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	return _earlier_count(state, slot) * bonus_each


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or bonus_each == 0 or _earlier_count(state, slot) > 0:
		return ""
	return "no %s product before it" % tag


func _earlier_count(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return 0
	var count: int = 0
	for earlier: int in range(slot):
		if state.is_product(earlier) and state.has_tag(earlier, tag):
			count += 1
	return count
