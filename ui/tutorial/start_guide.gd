class_name StartGuide
extends RefCounted
## The tutorial's adapter for the opening board (tutorial plan 1.1, WP-4): what a guide needs
## from StartBoard without reaching into its pages. It answers the anchors' rects in global
## coordinates (TutorialAnchors' start ids, from the shown page's own geometry: its hit list and
## its draw constants, never the mock-up's rects), passes through whether a callout must wait (a
## reveal, the slide: the board's tips_blocked), mounts the overlay over the board, and reads the
## quick tutorials' triggers. The gate, the locks and the hook events go through StartChoice
## (guide_gate, guide_locks) and StartBoard.guide_event; this class changes nothing on the board.

var board: StartBoard


func _init(shown_board: StartBoard) -> void:
	board = shown_board


## Anchor `id`'s rect in global coordinates, Rect2() when the board doesn't show it now.
func anchor_rect(id: StringName) -> Rect2:
	return anchor_of(board, id)


## Whether a callout must wait: the page slide, the clock-in, an opening, a held card, the pins
## step's pop, a swap window booster opening (StartBoard.tips_blocked).
func blocked() -> bool:
	return not is_instance_valid(board) or board.tips_blocked()


## Whether the BADGE PINS callout must wait: the slide, a flight, a pop. OPEN STORE waits
## and its step may be open (blocked's page 2 rule), and neither holds it.
func pins_blocked() -> bool:
	if not is_instance_valid(board) or board.busy or board.page != 2:
		return true
	var staff: BuildPage = board.staff
	return not board.is_visible_in_tree() or staff.run == null or staff.flight != null


## Puts `overlay` over the board (StartBoard.mount_overlay).
func mount(overlay: Control) -> void:
	board.mount_overlay(overlay)


## The page shown (0: page 1 YOUR STORE, 1: page 2 YOUR BUILD), as TutorialEvents' PAGE_SHOWN.
func shown_page() -> int:
	return board.page - 1


## Whether page 1 is stocked: every booster open (NEXT armed).
func stocked() -> bool:
	return board.store.page_done()


## The SWAP quick tutorial's trigger on page 2: its SWAP key shows, a swap is left and the window
## was not opened on this board yet.
func swap_due() -> bool:
	if board.page != 2 or board.swap_showing() or board.store.swap.seen:
		return false
	var staff: BuildPage = board.staff
	return (
		BuildRegulars.swap_shown(staff)
		and not staff.pins_open
		and StartSetupRules.swaps_left(staff.run, staff.profile) > 0
	)


## The RESTOCK quick tutorial's trigger on page 1: stocked, the key shown and a booster to return.
func restock_due() -> bool:
	var store: BoosterPage = board.store
	return (
		board.page == 1
		and stocked()
		and BoosterChromeDraw.key_shown(store)
		and not BoosterChromeDraw.key_locked(store)
		and store.counter.can_restock()
	)


## The BADGE PINS quick tutorial's trigger on page 2: OPEN STORE waits for the pins step.
func pins_due() -> bool:
	return board.page == 2 and board.staff.pins_pending()


## Anchor `id`'s global rect on `shown` (StartBoard.anchor_rect): the swap window's parts while it
## shows, else page 1's or page 2's, whichever is shown.
static func anchor_of(shown: StartBoard, id: StringName) -> Rect2:
	if not is_instance_valid(shown) or not shown.is_visible_in_tree():
		return Rect2()
	var art: Rect2 = Rect2()
	var on: Control = shown.store
	if shown.store.swap.visible():
		art = swap_rect(shown.store, id)
	elif shown.page == 2:
		on = shown.staff
		art = build_rect(shown.staff, id)
	else:
		art = store_rect(shown.store, id)
	if art.size == Vector2.ZERO:
		return Rect2()
	return on.get_global_transform() * Rect2(art.position * ArtPen.UNIT, art.size * ArtPen.UNIT)


## Page 1's anchor `id` in art px (Rect2(): not shown).
static func store_rect(page: BoosterPage, id: StringName) -> Rect2:
	if page.run == null:
		return Rect2()
	var fixed: Dictionary[StringName, Rect2] = {
		TutorialAnchors.PRIMARY: Rect2(BoosterArt.PRIMARY_RECT),
		TutorialAnchors.TITLE: Rect2(BoosterArt.TITLE_RECT),
		TutorialAnchors.TAB1: BoosterChromeDraw.tab_rect(0),
		TutorialAnchors.TAB2: BoosterChromeDraw.tab_rect(1),
		TutorialAnchors.CART: Rect2(BoosterChromeDraw.CART_LED),
	}
	if fixed.has(id):
		return fixed[id]
	if id == TutorialAnchors.RESTOCK:
		return BoosterChromeDraw.key_rect() if BoosterChromeDraw.key_shown(page) else Rect2()
	var booster: int = TutorialAnchors.index_of(id, TutorialAnchors.BOOSTER)
	if booster >= 0:
		return _booster_rect(page, booster)
	var back: int = TutorialAnchors.index_of(id, TutorialAnchors.RETURN)
	if back >= 0:
		return _return_rect(page, back)
	# The rest is the frame's own hits: a returnable fan, a booster's card.
	return _union_of(BoosterPageDraw.hits(page), id)


## Booster `index`'s rect: its bay before it is thrown, its pouch
## while sealed on the counter, its fan once opening or open.
static func _booster_rect(page: BoosterPage, index: int) -> Rect2:
	if index >= page.boosters.size():
		return Rect2()
	var b: BoosterOpening = page.boosters[index]
	if not page.roulette.landed(b):
		return AisleBoardArt.bay_rect(b.bay, page.roulette.count)
	if b.state == BoosterOpening.State.SEALED:
		var at: Vector2 = b.pouch_pos()
		return Rect2(at.x, at.y - 6, BoosterArt.BW, BoosterArt.BH + 6)
	return b.fan_rect()


## Booster `index`'s RETURN THIS ONE plate while RESTOCK is armed (BoosterChromeDraw.restock_call).
static func _return_rect(page: BoosterPage, index: int) -> Rect2:
	if not page.restock_armed or index >= page.boosters.size():
		return Rect2()
	if not page.counter.restockable(index):
		return Rect2()
	return BoosterChromeDraw.return_plate(page.boosters[index])


## Page 2's anchor `id` in art px (Rect2(): not shown).
static func build_rect(page: BuildPage, id: StringName) -> Rect2:
	if page.run == null:
		return Rect2()
	var top: float = PinStepDraw.box_y(page)
	var box: Rect2i = BuildPage.PIN_BOX
	if id == TutorialAnchors.PINS_CONFIRM:
		return PinStepDraw.confirm_rect(top) if page.pins_open else Rect2()
	if id == TutorialAnchors.PIN_BOARD:
		return Rect2(box.position.x + 10, top + 30, 82, 92) if page.pins_open else Rect2()
	var owned: Array[PinDefinition] = page.pins.owned()
	var count: int = owned.size() + PinStepDraw.locked_pins(page).size()
	var row: int = TutorialAnchors.index_of(id, TutorialAnchors.PIN_ROW)
	var wear: int = TutorialAnchors.index_of(id, TutorialAnchors.WEAR)
	var k: int = maxi(row, wear)
	if k >= 0:
		if not page.pins_open or k >= owned.size():
			return Rect2()
		var rect: Rect2 = PinStepDraw.row_rect(k, count, top)
		if row >= 0:
			return rect
		var compact: bool = count > PinStepDraw.FULL_ROWS
		var key_top: float = rect.position.y + (2 if compact else 4)
		return Rect2(rect.end.x - (31 if compact else 32), key_top, 28, 13)
	return _union_of(BuildPageDraw.hits(page), id)


## The swap window's anchor `id` in art px, its slide included (Rect2(): not shown).
static func swap_rect(page: BoosterPage, id: StringName) -> Rect2:
	var w: SwapWindow = page.swap
	var art: Rect2 = Rect2()
	var count: int = page.run.starter.core_cards.size()
	var booster: int = TutorialAnchors.index_of(id, TutorialAnchors.SWAP_BOOSTER)
	var regular: int = TutorialAnchors.index_of(id, TutorialAnchors.SWAP_REGULAR)
	if id == TutorialAnchors.SWAP_RESET:
		art = SwapWindowDraw.RESET_RECT
	elif id == TutorialAnchors.SWAP_DONE:
		art = SwapWindowDraw.DONE_RECT
	elif id == TutorialAnchors.SWAP_BOOSTERS:
		for bi: int in w.boosters.size():
			art = _merge(art, _swap_booster_rect(w, bi))
	elif booster >= 0:
		art = _swap_booster_rect(w, booster)
	elif regular >= 0 and regular < count:
		art = SwapWindowDraw.slot_rect(regular)
	else:
		for piece: SwapPiece in w.pieces:
			if not piece.regular and TutorialAnchors.swap_card(piece.booster, piece.k) == id:
				art = Rect2(
					piece.pos - Vector2(BoosterArt.CW, BoosterArt.CH) / 2.0,
					Vector2(BoosterArt.CW, BoosterArt.CH)
				)
	if art.size == Vector2.ZERO:
		return Rect2()
	return Rect2(art.position + Vector2(0, w.slide()), art.size)


## The swap window's booster `bi`: its pouch while sealed, its fan after.
static func _swap_booster_rect(w: SwapWindow, bi: int) -> Rect2:
	if bi < 0 or bi >= w.boosters.size():
		return Rect2()
	var b: BoosterOpening = w.boosters[bi]
	if b.state == BoosterOpening.State.SEALED:
		var at: Vector2 = SwapWindowDraw.pouch_pos(b.cx)
		return Rect2(at.x, at.y - 6, BoosterArt.BW, BoosterArt.BH + 6)
	var first: Vector2 = SwapWindowDraw.fan_centre(bi, 0)
	var last: Vector2 = SwapWindowDraw.fan_centre(bi, maxi(0, b.cards.size() - 1))
	var half: Vector2 = Vector2(BoosterArt.CW, BoosterArt.CH) / 2.0
	return Rect2(first - half, last - first + half * 2.0)


## Every hit in `hits` with id `id`, as one rect (Rect2(): none).
static func _union_of(hits: Array[Dictionary], id: StringName) -> Rect2:
	var found: Rect2 = Rect2()
	for entry: Dictionary in hits:
		if StringName(entry.id) == id:
			found = _merge(found, entry.rect as Rect2)
	return found


static func _merge(into: Rect2, rect: Rect2) -> Rect2:
	if rect.size == Vector2.ZERO:
		return into
	return rect if into.size == Vector2.ZERO else into.merge(rect)
