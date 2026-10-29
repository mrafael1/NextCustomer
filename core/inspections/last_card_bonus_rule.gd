class_name LastCardBonusRule
extends InspectionRule
## Day event (Happy hour): the row's last card, product or coupon (the last filled slot: the row is
## compacted), gets `bonus`, a flat bonus after the card's own, effect and upgrade ones. An empty
## row has no last card. 0 does nothing.

@export var bonus: int = 0


func flat_bonus(state: ScoreState, slot: int, _value: int) -> int:
	return bonus if slot == state.size() - 1 else 0
