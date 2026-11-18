class_name TagCountRule
extends Rule
## Coffee (#128, Breakfast): +1 for each product with `tag` in the row, itself included, wherever
## it stands (`bonus_each`). A coupon takes no count; the Breakfast sticker's tag counts
## (ScoreState.has_tag). With none in the row it is WASTED.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, _slot: int) -> int:
	return _count(state) * bonus_each


func wasted_reason(state: ScoreState, _slot: int) -> String:
	if bonus_each != 0 and not tag.is_empty() and _count(state) == 0:
		return "no %s item in the row" % tag
	return ""


func _count(state: ScoreState) -> int:
	if tag.is_empty():
		return 0
	var count: int = 0
	for slot: int in range(state.size()):
		if state.is_product(slot) and state.has_tag(slot, tag):
			count += 1
	return count
