class_name MorningCountRule
extends Rule
## Coffee (#128, Breakfast's MORNING): +1 for each MORNING item in the row (CardMorning: a product
## with `tag` in the row's first `zone.slots` slots), wherever the Coffee stands (`bonus_each`).
## With no MORNING item it is WASTED.

@export var tag: String = ""
@export var bonus_each: int = 0
## The MORNING ZONE (data/balance/morning_zone.tres). None: no MORNING item.
@export var zone: MorningZone


func flat_bonus(state: ScoreState, _slot: int) -> int:
	return CardMorning.slots(state, tag, zone).size() * bonus_each


func wasted_reason(state: ScoreState, _slot: int) -> String:
	if bonus_each != 0 and not tag.is_empty() and CardMorning.slots(state, tag, zone).is_empty():
		return "no MORNING item in the row"
	return ""
