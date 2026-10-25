class_name NewFamilyBonusRule
extends UpgradeRule
## Upgrade (#108, Mixed basket): a flat bonus on each product that brings a family no earlier
## product had, using tags after the context pass. The families are data (`families`: the aisle
## families; Food is left out, so it never counts). Mixed basket: +3. With no family on any
## product it fizzles (#45), once, on the row's last slot.

@export var families: PackedStringArray = PackedStringArray()
@export var bonus: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus == 0 or not state.is_product(slot):
		return 0
	for family: String in families:
		if not state.has_tag(slot, family):
			continue
		var seen: bool = false
		for other: int in range(slot):
			if state.is_product(other) and state.has_tag(other, family):
				seen = true
				break
		if not seen:
			return bonus
	return 0


func row_wasted_reason(state: ScoreState) -> String:
	if bonus == 0:
		return ""
	for slot: int in range(state.size()):
		if not state.is_product(slot):
			continue
		for family: String in families:
			if state.has_tag(slot, family):
				return ""
	return "no family on the products"
