class_name CopiesBonusRule
extends UpgradeRule
## Upgrade (#108, Bulk deal): each product pays a flat bonus for each earlier copy of the same
## product in the row (a BIG or GOLDEN copy counts as its plain card). Bulk deal: +3 per copy.
## With no product that has a copy before it, it fizzles (#45), once, on the row's last slot.

@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_each == 0:
		return 0
	return _copies_before(state, slot) * bonus_each


func row_wasted_reason(state: ScoreState) -> String:
	if bonus_each == 0:
		return ""
	for slot: int in range(state.size()):
		if _copies_before(state, slot) > 0:
			return ""
	return "no product with a copy before it"


static func _copies_before(state: ScoreState, slot: int) -> int:
	if not state.is_product(slot):
		return 0
	var card: CardDefinition = state.definition(slot)
	var found: int = 0
	for other: int in range(slot):
		if state.is_product(other) and state.definition(other).is_same_product(card):
			found += 1
	return found
