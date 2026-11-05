class_name StartReasons
extends RefCounted
## The opening board's words for StartSetupRules' reason ids (full build plan 7.2): what a swap
## shelf's aisle tab or item, or the NEW PACKS key, shows when it is refused.


## Why aisle `aisle_id` can't take a card for regular `slot` (StartSetupRules.target_block's
## `reason`): a swap shelf tab's tip.
static func target(run: RunState, reason: StringName) -> String:
	match reason:
		&"incomplete":
			return "Complete this aisle to use its items"
		&"swaps":
			return "No swaps left (1 per completed aisle, up to %d)" % run.starter.core_cards.size()
		&"aisle":
			return "%d regulars already come from this aisle" % run.balance.staple_swap_aisle_max
		&"copies":
			return "Nothing here fits the %d-copy limit" % run.starter.copy_max
		&"current":
			return "This regular is already this aisle's only item"
	return "Not a place for this regular"


## Why regular `slot` can't become a shelf's card (StartSetupRules.swap_block's `reason`).
static func swap_word(run: RunState, reason: StringName) -> String:
	match reason:
		&"slot":
			return "already here"
		&"aisle":
			return "%d from this aisle" % run.balance.staple_swap_aisle_max
		&"copies":
			return "max %d in the cart" % run.starter.copy_max
		&"swaps":
			return "no swap left"
	return "not offered"


## Why NEW PACKS can't be used (StartSetupRules.new_packs_block's `reason`).
static func new_packs(reason: StringName) -> String:
	match reason:
		&"used":
			return "New packs used this run"
		&"none":
			return "No other packs fit this cart"
		&"stage":
			return "Not dealt yet"
	return "Swap these three crates for three others (once a run)"
