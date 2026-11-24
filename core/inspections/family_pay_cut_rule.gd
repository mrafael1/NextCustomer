class_name FamilyPayCutRule
extends InspectionRule
## The Picky regular's day (#182 grade 5, v1.49): every product carrying `tag` (as the context
## pass left the tags) pays `pay_percent` percent of its payout, rounded down (75: a -25% promo,
## so 7€ pays 5€), as a payout override after the card's own. An empty tag or 100 percent does
## nothing. The data's rule names no tag: a copy per family and day's cut carries both
## (GradeRules.picky_event); the data's share is the cut of a day with none drawn.

@export var tag: String = ""
## The share of the payout the family's items keep, in percent (a day's copy: 100 less its cut).
@export_range(0, 100) var pay_percent: int = 100


func final_payout(state: ScoreState, slot: int, payout: int) -> int:
	if tag.is_empty() or pay_percent >= 100 or payout <= 0:
		return payout
	if not state.is_product(slot) or not state.has_tag(slot, tag):
		return payout
	return floori(payout * maxi(pay_percent, 0) / 100.0)


## The day's cut, a promo and not a denial (ScoreStep.promo_cut): 25 for a pay_percent of 75.
func promo_cut() -> int:
	return clampi(100 - pay_percent, 0, 100)
