class_name WastedBeforeRule
extends Rule
## Clearance (#128 v3): profit from what went wrong. A WASTED product is an earlier product one
## of whose own rules fizzled (ScoreState.wasted: a card's own WASTED line, not an upgrade's,
## a day event's or a lost effect's). Dusty toffees SALVAGE: +5 for each WASTED product before
## it, up to `max_count` (0: no limit). Flickering bulb FAIL FORWARD (`factor`): ×4 if the
## product just before it (ScoreState.products_before) was WASTED.

@export var bonus_each: int = 0
@export var max_count: int = 0
@export var factor: int = 1


func reads_waste() -> bool:
	return true


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_each == 0:
		return 0
	return _count(state, slot) * bonus_each


func multiplier(state: ScoreState, slot: int) -> int:
	if factor == 1 or not _just_before_wasted(state, slot):
		return 1
	return factor


func wasted_reason(state: ScoreState, slot: int) -> String:
	if bonus_each != 0 and _count(state, slot) == 0:
		return "no WASTED item before it"
	if factor != 1 and not _just_before_wasted(state, slot):
		return "the item right before it was not WASTED"
	return ""


func _count(state: ScoreState, slot: int) -> int:
	var count: int = 0
	for earlier: int in range(mini(slot, state.wasted.size())):
		if state.wasted[earlier] == 1 and state.is_product(earlier):
			count += 1
	return count if max_count <= 0 else mini(count, max_count)


func _just_before_wasted(state: ScoreState, slot: int) -> bool:
	for earlier: int in state.products_before(slot):
		if state.wasted[earlier] == 1:
			return true
	return false
