class_name PairBonusRule
extends Rule
## A flat bonus in an exact pair, after the context pass (Odd socks, #128: +8 in a pair: one
## Household product beside it, with no other Household product beside that one). Beside is
## ScoreState.products_beside (a neighbour, or a product linked to it), so a run of 3 pays none
## of its ends: the sticker and the rule agree. With no pair it fizzles (#45): a WASTED step
## that says why, the total unchanged.

@export var tag: String = ""
@export var bonus: int = 0


func flat_bonus(state: ScoreState, slot: int) -> int:
	return bonus if _partner(state, slot) >= 0 else 0


func flat_support(state: ScoreState, slot: int) -> int:
	return _partner(state, slot)


func wasted_reason(state: ScoreState, slot: int) -> String:
	if tag.is_empty() or bonus == 0 or _partner(state, slot) >= 0:
		return ""
	var beside: PackedInt32Array = _tagged_beside(state, slot, -1)
	if beside.is_empty():
		return "no %s item beside it" % tag
	if beside.size() > 1:
		return "two %s items beside it" % tag
	return "3 in a row is not a pair"


## The one product with the tag beside the card in `slot` when the two make an exact pair (the
## partner has no other product with the tag beside it), else -1.
func _partner(state: ScoreState, slot: int) -> int:
	if tag.is_empty():
		return -1
	var beside: PackedInt32Array = _tagged_beside(state, slot, -1)
	if beside.size() != 1:
		return -1
	var partner: int = beside[0]
	if not _tagged_beside(state, partner, slot).is_empty():
		return -1
	return partner


## The different products with the tag beside `slot`, leaving out `skip`.
func _tagged_beside(state: ScoreState, slot: int, skip: int) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for other: int in state.products_beside(slot):
		if other != skip and other != slot and not found.has(other) and state.has_tag(other, tag):
			found.append(other)
	return found
