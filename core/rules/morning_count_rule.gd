class_name MorningCountRule
extends Rule
## Coffee (#128, Breakfast's MORNING): +1 for each MORNING product in the row (CardMorning, the
## opening run of products with `tag`), wherever the Coffee stands (`bonus_each`). With no
## MORNING (the row's first product lacks the tag) it is WASTED.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, _slot: int) -> int:
	return CardMorning.slots(state, tag).size() * bonus_each


func wasted_reason(state: ScoreState, _slot: int) -> String:
	if bonus_each != 0 and not tag.is_empty() and CardMorning.slots(state, tag).is_empty():
		return "no MORNING item in the row"
	return ""
