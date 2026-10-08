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
	var neighbours: PackedInt32Array = (
		state.products_beside(slot) if position == Position.BESIDE else state.products_before(slot)
	)
	for other: int in neighbours:
		if _matches(state, slot, other):
			return true
	return false


func _matches(state: ScoreState, slot: int, other: int) -> bool:
	if not state.is_product(other):
		return false
	match match_by:
		Match.SAME_CARD:
			return state.definition(other).is_same_product(state.definition(slot))
		Match.CARD_ID:
			# A variant counts as its base card (plan section 3, "same product").
			return String(state.definition(other).product_card().id) == match_value
		Match.TAG:
			return state.has_tag(other, match_value)
	return false
