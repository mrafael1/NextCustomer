class_name KeywordMultiplierRule
extends UpgradeRule
## Upgrade (v1.28, a playstyle perk: "<keyword> items pay ×2", LV 2 ×3, LV 3 ×4): every product
## the keyword names pays ×factor, as an upgrade multiplier (after its own and effect multipliers,
## plan section 3.8). The keywords read the row after the context pass:
## - PAIRED (Perfect pair): a product whose pair rule finds its partner beside it (CardPairs).
## - WASTED (Salvage desk): a product one of whose own rules fizzled, or that a Write-off wrote off
##   (ScoreState.wasted). Scoring marks a product's own fizzles before the upgrades' multipliers
##   when an owned rule reads waste (reads_waste), so the factor applies to that same product.
## - LONE (Grab bag): a product with `tag` and no product with `tag` beside it
##   (SnackSpreadRule.is_lone).
## - TAG (Home goods): a product with `tag`.
## A product worth 0 at that point has nothing to multiply and fizzles there; with no such
## product in the whole row the perk fizzles (#45), once, on the row's last slot.

enum Keyword { NONE, PAIRED, WASTED, LONE, TAG }

@export var keyword: Keyword = Keyword.NONE
@export var tag: String = ""
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	if factor == 1 or not matches(state, slot):
		return 1
	return factor


func reads_waste() -> bool:
	return keyword == Keyword.WASTED and factor != 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "the %s item paid nothing" % _word()


func row_wasted_reason(state: ScoreState) -> String:
	if factor == 1 or keyword == Keyword.NONE:
		return ""
	for slot: int in range(state.size()):
		if matches(state, slot):
			return ""
	return "no %s item in the row" % _word()


## Whether the product in `slot` is one the keyword names.
func matches(state: ScoreState, slot: int) -> bool:
	if not state.is_product(slot):
		return false
	match keyword:
		Keyword.PAIRED:
			return CardPairs.is_paired(state, slot)
		Keyword.WASTED:
			return state.wasted[slot] == 1
		Keyword.LONE:
			return (
				not tag.is_empty()
				and state.has_tag(slot, tag)
				and SnackSpreadRule.is_lone(state, slot, tag)
			)
		Keyword.TAG:
			return not tag.is_empty() and state.has_tag(slot, tag)
	return false


## The keyword as the receipt's reasons word it: "PAIRED", "WASTED", "lone Snack", "Household".
func _word() -> String:
	match keyword:
		Keyword.PAIRED:
			return "PAIRED"
		Keyword.WASTED:
			return "WASTED"
		Keyword.LONE:
			return "lone %s" % tag
	return tag
