class_name FamilyRegularsRule
extends UpgradeRule
## Upgrade (#108, a Regulars perk): each product of a family pays a flat bonus for each earlier
## product of that family, using tags after the context pass (a Breakfast sticker's tag counts).
## Produce regulars: +1 per Produce before it. With fewer than two products of the family in the
## row it fizzles (#45), once, on the row's last slot.

@export var tag: String = ""
@export var bonus_each: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_each == 0 or tag.is_empty() or not _in_family(state, slot):
		return 0
	var earlier: int = 0
	for other: int in range(slot):
		if _in_family(state, other):
			earlier += 1
	return earlier * bonus_each


func row_wasted_reason(state: ScoreState) -> String:
	if bonus_each == 0 or tag.is_empty():
		return ""
	var count: int = 0
	for slot: int in range(state.size()):
		if _in_family(state, slot):
			count += 1
	return "fewer than two %s products" % tag if count < 2 else ""


func _in_family(state: ScoreState, slot: int) -> bool:
	return state.is_product(slot) and state.has_tag(slot, tag)
