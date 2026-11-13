class_name BoosterCounter
extends RefCounted
## YOUR STORE's counter (BoosterPage, v1.32): RESTOCK (its key arms the pick of an opened booster,
## whose cards fly into the returns tote as a fresh sealed one drops in) and the regulars' swap
## count (the swaps themselves are the swap window's, SwapWindow). Every rule goes through the
## page's StartBoardActions; the state lives on the page.

var page: BoosterPage


func _init(owner_page: BoosterPage) -> void:
	page = owner_page


## RESTOCK's key: arms (or disarms) the pick of an opened booster to return.
func arm_restock() -> bool:
	var block: StringName = restock_block()
	if block == &"locked":
		page.flash("RESTOCK AT %d FINISHED AISLES" % page.run.balance.restock_min_completed)
		return false
	if block == &"used":
		page.flash("RESTOCK USED")
		return false
	if not _any_restockable():
		page.flash("OPEN A BOOSTER FIRST")
		return false
	page.restock_armed = not page.restock_armed
	page.fx.sfx("ui_open" if page.restock_armed else "ui_close", -6.0)
	page.set_hint("PICK A BOOSTER TO RETURN" if page.restock_armed else "")
	return true


## Why RESTOCK can't be used at all (&"locked", &"used") or &"".
func restock_block() -> StringName:
	if (
		StartSetupRules.completed(page.run.balance, page.profile).size()
		< page.run.balance.restock_min_completed
	):
		return &"locked"
	if page.run.start_setup.restock_booster() >= 0 or page.run.balance.restocks_per_run <= 0:
		return &"used"
	return &""


func restock_unlocked() -> bool:
	return restock_block() != &"locked"


func can_restock() -> bool:
	return restock_block() == &"" and _any_restockable()


## Whether booster `index` can go back now (open at rest, and the rules allow it).
func restockable(index: int) -> bool:
	var opening: BoosterOpening = page.boosters[index]
	return (
		opening.state == BoosterOpening.State.OPEN
		and StartSetupRules.restock_block(page.run, page.profile, index) == &""
	)


func _any_restockable() -> bool:
	for index: int in page.boosters.size():
		if restockable(index):
			return true
	return false


## RESTOCK booster `index` (saved): its cards flip to their backs and fly into the returns tote,
## and a fresh sealed booster of its aisle drops in, RESTOCKED stamped on it.
func restock(index: int) -> bool:
	if index < 0 or index >= page.boosters.size() or not restockable(index):
		return false
	var opening: BoosterOpening = page.boosters[index]
	var old: Array[CardDefinition] = opening.cards.duplicate()
	if page.actions == null or not page.actions.restock_booster.call(index):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	page.tote_t = page.now
	page.tote_booster = index
	page.tote_cards = old
	page.tote_puff = false
	opening.take(page.run.start_setup.boosters[index])
	for k: int in opening.cards.size():
		BoosterArt.face(opening.cards[k], opening.rares[k])
	opening.state = BoosterOpening.State.SEALED
	# The returned cards leave the CART count at once (a sealed booster counts none), as the
	# mock-up's LED dropping to 7/15; it climbs again as the new booster opens.
	page.cart_n = page.cart_target()
	opening.boost = 1.0
	opening.drop_t = page.now + (0.0 if page.rm else page.tuning.restock_drop_s)
	page.restock_armed = false
	page.shelf_off[BoosterArt.zone_of(opening.cx)] = page.now + (0.0 if page.rm else 0.5)
	opening.lamp_flick = page.now + 0.55
	if page.rm:
		page.fx.sfx("shuffle", -6.0)
	else:
		for k: int in old.size():
			page.fx.cue(
				page.now + 0.12 + k * page.tuning.restock_flip_s,
				page.fx.sfx.bind("card_return", -6.0)
			)
		page.fx.cue(page.now + page.tuning.restock_tote_at_s, page.fx.sfx.bind("shuffle", -6.0))
		page.fx.cue(page.now + 0.9, page.fx.sfx.bind("stamp_notice", -4.0))
	# The clock stays at 7:00 (the mock-up's): STOCKED! comes again once the new booster is open.
	page.complete_t = INF
	page.stocked_t = INF
	page.set_hint("OPEN IT AGAIN")
	return true


## Whether the regulars can be swapped now: every booster open and STOCKED! come (the swap
## window opens even with no swap unlocked, its boosters locked).
func swaps_live() -> bool:
	if page.picking():
		return false
	return page.openings.all_open() and page.complete_t != INF


func swap_limit() -> int:
	return StartSetupRules.swap_limit(page.run, page.profile)


func swaps_used() -> int:
	return StartSetupRules.applied_swaps(page.run)
