class_name DistinctTagBonusRule
extends UpgradeRule
## Upgrade: a flat bonus for each different tag among the row's products, using tags after the
## context pass, paid on the last product in the row (not the last slot). Category engine: +3
## per tag. With no product in the row, or no tag among its products, it fizzles (#45), once, on
## the row's last slot.

@export var bonus_per_tag: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_per_tag == 0 or not _is_last_product(state, slot):
		return 0
	return _distinct_tags(state) * bonus_per_tag


func row_wasted_reason(state: ScoreState) -> String:
	if bonus_per_tag == 0:
		return ""
	for slot: int in range(state.size()):
		if state.is_product(slot):
			return "no tag on the products" if _distinct_tags(state) == 0 else ""
	return "no product in the row"


static func _distinct_tags(state: ScoreState) -> int:
	var seen: Dictionary = {}
	for product: int in range(state.size()):
		if state.is_product(product):
			for tag: String in state.tags[product]:
				seen[tag] = true
	return seen.size()


static func _is_last_product(state: ScoreState, slot: int) -> bool:
	if not state.is_product(slot):
		return false
	for later: int in range(slot + 1, state.size()):
		if state.is_product(later):
			return false
	return true
