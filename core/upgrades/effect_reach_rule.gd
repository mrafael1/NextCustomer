class_name EffectReachRule
extends UpgradeRule
## Upgrade (#108, a jackpot: Fire sale; Lemon squeezer until v0.56 / #128): the charged
## multiplier `card` arms (a BIG or GOLDEN copy too) reaches every later product with its tag,
## with no charge count. The card's own charges stay the card's; every use past them is this
## upgrade's MULTIPLIER step (ScoreState.add_effect, Scoring). Fire sale: Squashed cake's x2
## reaches every later Clearance product. With no `card` in the row, or no product its reach
## gave the factor, it fizzles (#45), once, on the row's last slot.

@export var card: CardDefinition


func reaches(arming: CardDefinition) -> bool:
	return card != null and arming.is_same_product(card)


func row_wasted_reason(state: ScoreState) -> String:
	if card == null:
		return ""
	var present: bool = false
	for slot: int in range(state.size()):
		if state.definition(slot).is_same_product(card):
			present = true
			break
	if not present:
		return "no %s in the row" % card.display_name
	if state.reach_uses.get(self, 0) > 0:
		return ""
	return "no more %s items after the %s" % [_tag(), card.display_name]


## The tag the card's charged multiplier reaches ("" for none).
func _tag() -> String:
	for rule: Rule in card.rules:
		var charged: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
		if charged != null:
			return charged.tag
	return ""
