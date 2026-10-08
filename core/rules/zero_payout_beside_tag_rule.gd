class_name ZeroPayoutBesideTagRule
extends Rule
## The final payout becomes 0 when a product with a tag is beside this card, after the
## context pass. Soup: pays 0 if beside a Frozen product. Bonuses and multipliers aimed at
## it are still spent (an Egg charge is used up).

@export var tag: String = ""


func final_payout(state: ScoreState, slot: int, payout: int) -> int:
	if tag.is_empty():
		return payout
	for neighbour: int in state.products_beside(slot):
		if state.is_product(neighbour) and state.has_tag(neighbour, tag):
			return 0
	return payout
