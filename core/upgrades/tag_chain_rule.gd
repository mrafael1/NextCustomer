class_name TagChainRule
extends UpgradeRule
## Upgrade (#108, Banana stand): every product with the tag chains like a Banana: + the price of
## the product with the tag just before it (AdjacentMatchBonusRule.chain_price: a link's price,
## a chain's first product's payout), counted as many times as the card's own chain counts (a Golden
## Banana's twice), else once. A card whose own chain already matched (a Banana after a Banana)
## takes only its own bonus. The bonus is a flat bonus of the upgrade, so it is part of the price
## the next link passes on. With no two products of the tag side by side it fizzles (#45), once,
## on the row's last slot.

@export var tag: String = ""


func flat_bonus(state: ScoreState, slot: int) -> int:
	if tag.is_empty() or not _has_tag(state, slot):
		return 0
	var own: AdjacentMatchBonusRule = _own_chain(state.definition(slot))
	if own != null and own.previous_match(state, slot) >= 0:
		return 0
	var previous: int = _previous(state, slot)
	if previous < 0:
		return 0
	state.chained[slot] = 1
	return (
		AdjacentMatchBonusRule.chain_price(state, previous)
		* (own.bonus_factor if own != null else 1)
	)


func row_wasted_reason(state: ScoreState) -> String:
	if tag.is_empty():
		return ""
	for slot: int in range(state.size()):
		if _has_tag(state, slot) and _previous(state, slot) >= 0:
			return ""
	return "no two %s products side by side" % tag


## The nearest product with the tag counted as just before `slot`, or -1.
func _previous(state: ScoreState, slot: int) -> int:
	var found: int = -1
	for other: int in state.products_before(slot):
		if other < slot and other > found and _has_tag(state, other):
			found = other
	return found


func _has_tag(state: ScoreState, slot: int) -> bool:
	return state.is_product(slot) and state.has_tag(slot, tag)


## The card's own chain rule (the Banana's), or null.
static func _own_chain(card: CardDefinition) -> AdjacentMatchBonusRule:
	for rule: Rule in card.rules:
		var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if match_rule != null and match_rule.bonus_is_previous_price:
			return match_rule
	return null
