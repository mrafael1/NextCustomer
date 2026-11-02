class_name LooseKnotMultiplierRule
extends UpgradeRule
## Upgrade (#128, the Lemon squeezer jackpot since Produce links): a `card` (a BIG or GOLDEN copy
## too) that ties no chain (outside a CHAIN: no knot in its slot, CardChain.is_knot) still gives
## the next product with `tag` ×factor, as an upgrade multiplier: the Lemon's old "×2 next
## Produce" back as a reward. The next product is the first later product with the tag, wherever
## it sits. With no loose `card` in the row, or none with a product of its tag after it, it fizzles
## (#45), once, on the row's last slot.

@export var card: CardDefinition
@export var tag: String = ""
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	if factor == 1 or card == null or tag.is_empty() or not _tagged(state, slot):
		return 1
	return factor if _loose_before(state, slot) >= 0 else 1


## A loose `card` at `slot` that has a product with the tag after it: the perk doubles that
## product, so the card's own "not inside a CHAIN" fizzle is cleared (ChainRoleRule).
func spares_waste(state: ScoreState, slot: int) -> bool:
	if factor == 1 or card == null or tag.is_empty() or not _tagged(state, slot):
		return false
	if not state.definition(slot).is_same_product(card) or CardChain.is_knot(state, slot):
		return false
	for later: int in range(slot + 1, state.size()):
		if _tagged(state, later):
			return true
	return false


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "the %s after the %s paid nothing" % [tag, card.display_name]


func row_wasted_reason(state: ScoreState) -> String:
	if factor == 1 or card == null or tag.is_empty():
		return ""
	var present: bool = false
	var loose: bool = false
	for slot: int in range(state.size()):
		if _tagged(state, slot) and _loose_before(state, slot) >= 0:
			return ""
		if state.definition(slot).is_same_product(card):
			present = true
			loose = loose or not CardChain.is_knot(state, slot)
	if not present:
		return "no %s in the row" % card.display_name
	if not loose:
		return "every %s is inside a %s" % [card.display_name, CardText.CHAIN_WORD]
	return "no more %s products after the %s" % [tag, card.display_name]


## The loose `card` whose next product with the tag is `slot` (the nearest earlier product with the
## tag, when it is such a card), or -1.
func _loose_before(state: ScoreState, slot: int) -> int:
	for earlier: int in range(slot - 1, -1, -1):
		if not _tagged(state, earlier):
			continue
		var loose: bool = not CardChain.is_knot(state, earlier)
		if loose and state.definition(earlier).is_same_product(card):
			return earlier
		return -1
	return -1


func _tagged(state: ScoreState, slot: int) -> bool:
	return state.is_product(slot) and state.has_tag(slot, tag)
