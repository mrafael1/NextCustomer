class_name AdjacentMatchBonusRule
extends Rule
## A flat bonus when a matching product is adjacent, after the context pass.
## Banana: + its base if immediately after another Banana. Cheese: +4 if immediately after
## Bread. Frozen peas: + its base if beside another Frozen product. Golden Banana (#77): its
## pair bonus counts twice (`bonus_factor` 2). With no match it fizzles (#45): a WASTED step
## that names what was missing, the total unchanged.

enum Match { NONE, SAME_CARD, CARD_ID, TAG }
enum Position { NONE, IMMEDIATELY_AFTER, BESIDE }

@export var match_by: Match = Match.NONE
## The card id (CARD_ID) or tag (TAG) to match. Unused for SAME_CARD.
@export var match_value: String = ""
@export var position: Position = Position.NONE
@export var bonus: int = 0
## If true, the bonus is the card's own base value instead of `bonus`.
@export var bonus_is_base: bool = false
## How many times the bonus counts (1: once). Golden Banana's pair bonus counts twice.
@export var bonus_factor: int = 1


func flat_bonus(state: ScoreState, slot: int) -> int:
	if position == Position.NONE or match_by == Match.NONE:
		return 0
	var neighbours: PackedInt32Array = (
		state.products_beside(slot) if position == Position.BESIDE else state.products_before(slot)
	)
	if neighbours.is_empty():
		return 0
	var card: CardDefinition = state.definition(slot)
	for other: int in neighbours:
		if _matches(state, card, other):
			return bonus_for(card.base)
	return 0


## Explain path only (Scoring._report_fizzles). A rule paying nothing on a match (neutral
## numbers) never fizzles.
func wasted_reason(state: ScoreState, slot: int) -> String:
	if position == Position.NONE or match_by == Match.NONE:
		return ""
	if bonus_for(state.definition(slot).base) == 0 or flat_bonus(state, slot) != 0:
		return ""
	var where: String = "just before it" if position == Position.IMMEDIATELY_AFTER else "beside it"
	return "no %s %s" % [_match_name(state, slot), where]


## The bonus paid on a match by a card with this base value: its base when the bonus is the
## base, else `bonus`, counted `bonus_factor` times.
func bonus_for(base: int) -> int:
	return (base if bonus_is_base else bonus) * bonus_factor


## What a match is, for the fizzle's reason: "Banana" (the same product), "Bread" (a card id,
## capitalized: a data test checks it is that card's display name) or "Bakery product" (a tag).
func _match_name(state: ScoreState, slot: int) -> String:
	match match_by:
		Match.SAME_CARD:
			return state.definition(slot).product_card().display_name
		Match.CARD_ID:
			return match_value.capitalize()
	return "%s product" % match_value


## Whether the product in `other` matches `card` (the card in the slot looking for a match).
func _matches(state: ScoreState, card: CardDefinition, other: int) -> bool:
	if not state.is_product(other):
		return false
	match match_by:
		Match.SAME_CARD:
			return state.definition(other).is_same_product(card)
		Match.CARD_ID:
			# A variant counts as its base card (plan section 3, "same product").
			return String(state.definition(other).product_card().id) == match_value
		Match.TAG:
			return state.has_tag(other, match_value)
	return false
