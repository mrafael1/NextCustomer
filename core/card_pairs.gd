class_name CardPairs
extends RefCounted
## PAIRs (#128, Dairy's identity, the user's call of 2026-11-02): a product whose pair rule
## (AdjacentMatchBonusRule with `pair`: Butter beside Bakery, Cheese beside Bread, Yogurt beside
## Banana, Reduced yogurt beside Clearance, Scone beside Dairy, Cereal beside Milk) has its
## partner beside it. Read after the context pass; it depends only on the row.


## Whether the product in `slot` is PAIRED: one of its card's pair rules finds its partner.
static func is_paired(state: ScoreState, slot: int) -> bool:
	if not state.is_product(slot):
		return false
	for rule: Rule in state.definition(slot).rules:
		var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if match_rule != null and match_rule.pair and match_rule.is_paired(state, slot):
			return true
	return false


## How many products in the row are PAIRED (each paired product counts once).
static func count(state: ScoreState) -> int:
	var paired: int = 0
	for slot: int in range(state.size()):
		if is_paired(state, slot):
			paired += 1
	return paired


## Every PAIR of the row (#128, the belt's PAIR clasps): each paired product with each partner its
## pair rule finds, as (left slot, right slot), in row order, each pair once.
static func links(state: ScoreState) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for slot: int in range(state.size()):
		if not state.is_product(slot):
			continue
		for rule: Rule in state.definition(slot).rules:
			var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
			if match_rule == null or not match_rule.pair:
				continue
			for other: int in match_rule.partners(state, slot):
				var link: Vector2i = Vector2i(mini(slot, other), maxi(slot, other))
				if not found.has(link):
					found.append(link)
	found.sort()
	return found
