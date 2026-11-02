class_name SnackSpreadRule
extends Rule
## Snacks spread out (#128 v2, kept in v3). A lone product with `tag` has no product with that
## tag beside it (ScoreState.products_beside, after the context pass).
## Pick 'n' mix SPREAD (`spread` LONE): +3 (`bonus_each`) for each lone Snack in the row, itself
## included. Bent lolly GAP (`spread` GAP): +2 for each product between it and the nearest other
## Snack (coupons don't count), up to `max_count` (0: no limit); no product between them, or no
## other Snack in the row, is WASTED.

enum Spread { NONE, LONE, GAP }

@export var spread: Spread = Spread.NONE
@export var tag: String = ""
@export var bonus_each: int = 0
@export var max_count: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return 0
	match spread:
		Spread.LONE:
			return _lone_count(state) * bonus_each
		Spread.GAP:
			return maxi(_gap(state, slot), 0) * bonus_each
	return 0


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or bonus_each == 0:
		return ""
	if spread == Spread.LONE and _lone_count(state) == 0:
		return "no lone %s in the row" % tag
	if spread == Spread.GAP:
		var gap: int = _gap(state, slot)
		if gap < 0:
			return "no other %s in the row" % tag
		if gap == 0:
			return "no item between it and the next %s" % tag
	return ""


func _lone_count(state: ScoreState) -> int:
	var count: int = 0
	for slot: int in range(state.size()):
		if state.is_product(slot) and state.has_tag(slot, tag) and _is_lone(state, slot):
			count += 1
	return count


func _is_lone(state: ScoreState, slot: int) -> bool:
	for other: int in state.products_beside(slot):
		if state.has_tag(other, tag):
			return false
	return true


## The products between `slot` and the nearest other product with the tag, by the products'
## order on the belt; -1 when the row holds no other.
func _gap(state: ScoreState, slot: int) -> int:
	var numbers: PackedInt32Array = state.product_numbers
	if slot >= numbers.size() or numbers[slot] <= 0:
		return -1
	var best: int = -1
	for other: int in range(state.size()):
		if other == slot or numbers[other] <= 0 or not state.has_tag(other, tag):
			continue
		var between: int = absi(numbers[other] - numbers[slot]) - 1
		if best < 0 or between < best:
			best = between
	if best < 0 or max_count <= 0:
		return best
	return mini(best, max_count)
