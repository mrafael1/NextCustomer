class_name AdjacentMatchBonusRule
extends Rule
## A flat bonus when a matching product is adjacent, after the context pass.
## Banana: + its base if immediately after another Banana. Cheese: +4 if immediately after
## Bread. Frozen peas: + its base if beside another Frozen product.

enum Match { NONE, SAME_CARD, CARD_ID, TAG }
enum Position { NONE, IMMEDIATELY_AFTER, BESIDE }

@export var match_by: Match = Match.NONE
## The card id (CARD_ID) or tag (TAG) to match. Unused for SAME_CARD.
@export var match_value: String = ""
@export var position: Position = Position.NONE
@export var bonus: int = 0
## If true, the bonus is the card's own base value instead of `bonus`.
@export var bonus_is_base: bool = false


func flat_bonus(state: ScoreState, slot: int) -> int:
	if not _has_adjacent_match(state, slot):
		return 0
	return state.definition(slot).base if bonus_is_base else bonus


func _has_adjacent_match(state: ScoreState, slot: int) -> bool:
	if position == Position.NONE or match_by == Match.NONE:
		return false
	if _matches(state, slot, state.product_before[slot]):
		return true
	return position == Position.BESIDE and _matches(state, slot, state.product_after[slot])


func _matches(state: ScoreState, slot: int, other: int) -> bool:
	if not state.is_product(other):
		return false
	match match_by:
		Match.SAME_CARD:
			return state.definition(other).id == state.definition(slot).id
		Match.CARD_ID:
			return String(state.definition(other).id) == match_value
		Match.TAG:
			return state.has_tag(other, match_value)
	return false
