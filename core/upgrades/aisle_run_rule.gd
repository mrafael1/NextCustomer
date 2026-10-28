class_name AisleRunRule
extends UpgradeRule
## Upgrade (#108, an Aisle run perk): the last product of a run of at least `min_run` products of
## a family in a row pays x factor, as an upgrade multiplier. A run follows adjacency after the
## context pass (ScoreState.products_before), so a coupon breaks it unless a
## coupon links the products (2 for 1, Shelf swap), and tags after it (a Breakfast sticker's).
## Produce aisle run: 3 or more Produce in a row, the last x3. A run's last product worth 0 has
## nothing to multiply and fizzles there; with no run long enough the upgrade fizzles (#45),
## once, on the row's last slot.

@export var tag: String = ""
@export var min_run: int = 0
@export var factor: int = 1


func multiplier(state: ScoreState, slot: int) -> int:
	if factor == 1 or min_run <= 0 or tag.is_empty() or not _in_family(state, slot):
		return 1
	for later: int in range(slot + 1, state.size()):
		if _in_family(state, later) and state.products_before(later).has(slot):
			return 1
	return factor if run_length(state, slot) >= min_run else 1


func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return "the run's last %s paid nothing" % tag


func row_wasted_reason(state: ScoreState) -> String:
	if factor == 1 or min_run <= 0 or tag.is_empty():
		return ""
	for slot: int in range(state.size()):
		if _in_family(state, slot) and run_length(state, slot) >= min_run:
			return ""
	return "no %d %s products in a row" % [min_run, tag]


## The longest run of the family's products ending at `slot` (0 when it isn't one of them).
func run_length(state: ScoreState, slot: int) -> int:
	if not _in_family(state, slot):
		return 0
	var longest: int = 0
	for before: int in state.products_before(slot):
		if before < slot:
			longest = maxi(longest, run_length(state, before))
	return longest + 1


func _in_family(state: ScoreState, slot: int) -> bool:
	return state.is_product(slot) and state.has_tag(slot, tag)
