class_name DistinctTagBonusRule
extends UpgradeRule
## Upgrade: a flat bonus for each different tag among the row's products, using tags after the
## context pass, paid on the last product in the row (not the last slot). Category engine: +3
## per tag. With no product in the row it does nothing.

@export var bonus_per_tag: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_per_tag == 0 or not _is_last_product(state, slot):
		return 0
	var seen: Dictionary = {}
	for product: int in range(state.size()):
		if state.is_product(product):
			for tag: String in state.tags[product]:
				seen[tag] = true
	return seen.size() * bonus_per_tag


static func _is_last_product(state: ScoreState, slot: int) -> bool:
	if not state.is_product(slot):
		return false
	for later: int in range(slot + 1, state.size()):
		if state.is_product(later):
			return false
	return true
