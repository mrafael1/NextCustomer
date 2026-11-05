class_name StartReasons
extends RefCounted
## The opening board's words for StartSetupRules' reason ids (full build plan 7.2): what a row,
## a basket's RESTOCK tag, the NEW PACKS key or LOCK IN & DEAL shows when it is refused.


## Why aisle `aisle_id` can't take regular `slot` (StartSetupRules.target_block's `reason`).
static func target(run: RunState, reason: StringName) -> String:
	match reason:
		&"incomplete":
			return "Complete this aisle to use its items"
		&"swaps":
			return (
				"No replacements left (1 per completed aisle, up to %d)"
				% run.starter.core_cards.size()
			)
		&"aisle":
			return "%d regulars already come from this aisle" % run.balance.staple_swap_aisle_max
		&"copies":
			return "Nothing here fits the %d-copy limit" % run.starter.copy_max
		&"current":
			return "This regular is already this aisle's only item"
	return "Not a place for this regular"


## The short word a row shows for `reason` while a regular is carried.
static func target_word(reason: StringName) -> String:
	match reason:
		&"":
			return "DROP HERE"
		&"aisle":
			return "2 FROM IT"
		&"copies":
			return "FULL"
		&"swaps":
			return "NONE LEFT"
		&"current":
			return "IN CART"
	return ""


## Why regular `slot` can't become a strip's card (StartSetupRules.swap_block's `reason`).
static func swap_word(run: RunState, reason: StringName) -> String:
	match reason:
		&"slot":
			return "already here"
		&"aisle":
			return "%d from this aisle" % run.balance.staple_swap_aisle_max
		&"copies":
			return "max %d in the cart" % run.starter.copy_max
		&"swaps":
			return "no replacement left"
	return "not offered"


## Why basket `basket` can't be restocked (StartSetupRules.restock_block's `reason`).
static func restock(run: RunState, completed: int, reason: StringName, source: String) -> String:
	match reason:
		&"locked":
			return (
				"RESTOCK opens at %d completed aisles (%d/%d)"
				% [
					run.balance.restock_min_completed,
					mini(completed, run.balance.restock_min_completed),
					run.balance.restock_min_completed
				]
			)
		&"used":
			return "RESTOCK used this run"
		&"none":
			return "No other pair of products fits from %s" % source
		&"stage":
			return "LOCK IN & DEAL first"
	return "RESTOCK: replace both items of this basket from %s (once a run)" % source


## Why NEW PACKS can't be used (StartSetupRules.new_packs_block's `reason`).
static func new_packs(reason: StringName) -> String:
	match reason:
		&"used":
			return "New packs used this run"
		&"none":
			return "No other packs fit this cart"
		&"stage":
			return "LOCK IN & DEAL first"
	return "Swap these three crates for three others (once a run)"


## Why today's aisles can't be locked in (StartSetupRules.lock_block's `reason`).
static func lock(run: RunState, completed: int, reason: StringName) -> String:
	match reason:
		&"count":
			return (
				"Pick %d STARTER CART aisles and %d RUN ONLY"
				% [
					run.balance.dealt_aisle_count,
					run.balance.stock_aisle_count - run.balance.dealt_aisle_count
				]
			)
		&"listable":
			return "An aisle opens at %d items" % run.balance.aisle_listable_min
		&"locked":
			return choose_line(run, completed)
		&"stage":
			return "Today's aisles are locked in"
	return "Deals your 3 baskets for this run"


## "Choose your aisles at 6 completed aisles (n/6)".
static func choose_line(run: RunState, completed: int) -> String:
	var need: int = run.balance.pair_choice_min_completed
	return "Choose your aisles at %d completed aisles (%d/%d)" % [need, mini(completed, need), need]
