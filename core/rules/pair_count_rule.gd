class_name PairCountRule
extends Rule
## Cream (#128, Dairy's PAIR): +4 for each PAIRED product in the row (CardPairs), itself included
## when it has a pair rule (`bonus_each`). With none in the row it is WASTED.

@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, _slot: int) -> int:
	return CardPairs.count(state) * bonus_each


func wasted_reason(state: ScoreState, _slot: int) -> String:
	if bonus_each != 0 and CardPairs.count(state) == 0:
		return "no PAIR in the row"
	return ""
