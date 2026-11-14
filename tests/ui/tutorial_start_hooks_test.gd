extends GdUnitTestSuite
## The opening board's tutorial hooks (tutorial plan WP-4): the hook events the board sends
## (StartBoard.guide_event, each with its contract args), the gate (StartChoice.guide_gate through
## StartBoardActions: a refused click or key does nothing and flashes nothing, an allowed one
## acts, no gate allows everything), the tutorial's locks (the swap plate, RESTOCK's key drawn
## even before it unlocks, NEW PACKS: drawn LOCKED and refused), the crowded crate (6 regulars in
## two zigzag rows, 4 as before) and StartGuide's anchors at 1280x720 and 1920x1080 (on the
## board, where the page draws them). The pages run on their own clock: the tests freeze it and
## step it.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const STEP := 1.0 / 60.0
const SIZES: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]

var _folder: String


func before_test() -> void:
	_folder = "user://tutorial_start_hooks_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## The board sends its page on opening, each booster's opening, STOCKED! once, page 2's arrival
## and the pick, the hover and OPEN STORE, every one with exactly its contract args.
func test_the_board_sends_its_hooks() -> void:
	var page: BoosterPage = await _page(0)
	var board: StartBoard = _board(page)
	var events: Array[Array] = _listen(board)
	await get_tree().process_frame
	assert_bool(_has(events, TutorialEvents.PAGE_SHOWN, {TutorialEvents.ARG_PAGE: 0})).is_true()
	page.openings.roll_up()
	page.openings.end_arrival()
	_run(page, 1.0)
	_click(page, BoosterArt.pouch_pos(page.boosters[0].cx) + Vector2(40, 40))
	(
		assert_bool(_has(events, TutorialEvents.BOOSTER_OPENED, {TutorialEvents.ARG_INDEX: 0}))
		. is_true()
	)
	page.openings.open_all("key")
	(
		assert_bool(_has(events, TutorialEvents.BOOSTER_OPENED, {TutorialEvents.ARG_INDEX: 1}))
		. is_true()
	)
	_run(page, 8.0)
	assert_int(_count(events, TutorialEvents.BOOSTERS_ALL_OPEN)).is_equal(1)
	_run(page, 1.0)
	assert_int(_count(events, TutorialEvents.BOOSTERS_ALL_OPEN)).is_equal(1)
	board.show_page(2, "tab")
	board._end_slide()
	assert_bool(_has(events, TutorialEvents.PAGE_SHOWN, {TutorialEvents.ARG_PAGE: 1})).is_true()
	var staff: BuildPage = board.staff
	staff.frozen = true
	for _step: int in 240:
		staff.advance(STEP)
	staff.mouse = Vector2(BuildPage.STX[1] + 30, 200)
	staff.advance(STEP)
	assert_bool(_has(events, TutorialEvents.PACK_HOVERED, {TutorialEvents.ARG_INDEX: 1})).is_true()
	assert_bool(staff.pick_pack(1, "click")).is_true()
	assert_bool(_has(events, TutorialEvents.PACK_PICKED, {TutorialEvents.ARG_INDEX: 1})).is_true()
	assert_bool(staff.open_store()).is_true()
	assert_int(_count(events, TutorialEvents.STORE_OPENED)).is_equal(1)
	for event: Array in events:
		(
			assert_bool(TutorialEvents.args_valid(event[0], event[1]))
			. override_failure_message(str(event))
			. is_true()
		)


## RESTOCK (3 finished aisles): arming, cancelling and returning a booster send their hooks.
func test_restock_sends_its_hooks() -> void:
	var page: BoosterPage = await _page(3)
	var events: Array[Array] = _listen(_board(page))
	_stocked(page)
	assert_bool(page.counter.arm_restock()).is_true()
	assert_int(_count(events, TutorialEvents.RESTOCK_ARMED)).is_equal(1)
	page.cancel_restock("ui_back")
	assert_int(_count(events, TutorialEvents.RESTOCK_CANCELLED)).is_equal(1)
	assert_bool(page.counter.arm_restock()).is_true()
	assert_bool(page.counter.restock(0)).is_true()
	assert_bool(_has(events, TutorialEvents.RESTOCK_DONE, {TutorialEvents.ARG_INDEX: 0})).is_true()
	_run(page, 3.0)
	page.openings.open_all("key")
	_run(page, 8.0)
	assert_int(_count(events, TutorialEvents.BOOSTERS_ALL_OPEN)).is_equal(2)


## The swap window (2 finished aisles): its opening, a booster, a swap, its undo, RESET's undo and
## DONE send their hooks, each with its args.
func test_the_swap_window_sends_its_hooks() -> void:
	var page: BoosterPage = await _page(2)
	var events: Array[Array] = _listen(_board(page))
	_stocked(page)
	assert_bool(page.swap.open_window(false)).is_true()
	assert_int(_count(events, TutorialEvents.SWAP_OPENED)).is_equal(1)
	for bi: int in page.swap.boosters.size():
		page.swap.open_booster(bi, "key")
	assert_bool(_has(events, TutorialEvents.SWAP_BOOSTER_OPENED, {TutorialEvents.ARG_INDEX: 0}))
	_run(page, 3.0)
	var piece: SwapPiece = _card_piece(page)
	page.swap._apply(piece, 0, "drag")
	(
		assert_bool(
			_has(
				events,
				TutorialEvents.SWAP_APPLIED,
				{TutorialEvents.ARG_SLOT: 0, TutorialEvents.ARG_CARD: piece.card.id}
			)
		)
		. is_true()
	)
	page.swap._undo(0, "drag")
	assert_bool(_has(events, TutorialEvents.SWAP_UNDONE, {TutorialEvents.ARG_SLOT: 0})).is_true()
	page.swap._apply(piece, 1, "drag")
	assert_bool(page.swap.reset()).is_true()
	assert_bool(_has(events, TutorialEvents.SWAP_UNDONE, {TutorialEvents.ARG_SLOT: 1})).is_true()
	page.swap.close(true)
	assert_int(_count(events, TutorialEvents.SWAP_DONE)).is_equal(1)
	for event: Array in events:
		assert_bool(TutorialEvents.args_valid(event[0], event[1])).is_true()


## The gate: a refused click, key or Space acts on nothing and flashes nothing; the same input
## once allowed acts; each ask names its hit as TutorialActions.HIT {id}.
func test_the_gate_refuses_and_allows_page_one_input() -> void:
	var page: BoosterPage = await _page(0)
	var board: StartBoard = _board(page)
	var asked: Array[StringName] = []
	var allowed: Array[StringName] = []
	_gate(board).guide_gate = func(action: StringName, args: Dictionary) -> bool:
		assert_str(action).is_equal(TutorialActions.HIT)
		asked.append(args[TutorialActions.ARG_ID] as StringName)
		return allowed.has(args[TutorialActions.ARG_ID] as StringName)
	_click(page, Vector2(320, 200))
	assert_int(page.shutter).is_equal(BoosterPage.Shutter.DOWN)
	assert_array(asked).contains([TutorialAnchors.ROLLUP])
	allowed.append(TutorialAnchors.ROLLUP)
	_click(page, Vector2(320, 200))
	assert_int(page.shutter).is_not_equal(BoosterPage.Shutter.DOWN)
	page.openings.end_arrival()
	_run(page, 1.0)
	var pouch: Vector2 = BoosterArt.pouch_pos(page.boosters[0].cx) + Vector2(40, 40)
	_click(page, pouch)
	board._input(_key(KEY_1))
	board._input(_key(KEY_A))
	board._input(_key(KEY_ENTER))
	board._input(_key(KEY_SPACE))
	_run(page, 1.0)
	assert_bool(page.openings.any_sealed()).is_true()
	assert_int(page.boosters[0].state).is_equal(BoosterOpening.State.SEALED)
	assert_float(page.hold_t).is_less(0.0)
	assert_str(page.message).is_empty()
	assert_array(asked).contains([TutorialAnchors.booster(0), TutorialAnchors.PRIMARY])
	allowed.append(TutorialAnchors.booster(0))
	_click(page, pouch)
	assert_int(page.boosters[0].state).is_equal(BoosterOpening.State.OPENING)
	assert_int(page.boosters[1].state).is_equal(BoosterOpening.State.SEALED)
	# Esc is never asked (the page's own Esc; the board's opens the options).
	asked.clear()
	page.handle_key(KEY_ESCAPE)
	assert_array(asked).is_empty()


## Page 2 and the reveal's own entries: a refused pack, NEW PACKS, OPEN STORE (click, key, or the
## reveal's take) do nothing; allowed, they act.
func test_the_gate_refuses_and_allows_page_two_input() -> void:
	var page: BoosterPage = await _page(0)
	var board: StartBoard = _board(page)
	_stocked(page)
	board.show_page(2, "tab")
	board._end_slide()
	var staff: BuildPage = board.staff
	staff.frozen = true
	for _step: int in 240:
		staff.advance(STEP)
	var allowed: Array[StringName] = []
	_gate(board).guide_gate = func(_action: StringName, args: Dictionary) -> bool:
		return allowed.has(args[TutorialActions.ARG_ID] as StringName)
	var packs_before: Array[StarterPackDefinition] = board.run.start_offer.packs.duplicate()
	staff.click(Vector2(BuildPage.STX[0] + 30, 200))
	board._input(_key(KEY_2))
	board.pick(2)
	board._input(_key(KEY_N))
	assert_int(staff.picked()).is_equal(-1)
	assert_array(board.run.start_offer.packs).is_equal(packs_before)
	allowed.append(TutorialAnchors.pack(0))
	staff.click(Vector2(BuildPage.STX[0] + 30, 200))
	assert_int(staff.picked()).is_equal(0)
	board._input(_key(KEY_ENTER))
	assert_bool(board.clock_in()).is_false()
	assert_object(staff.flight).is_null()
	allowed.append(TutorialAnchors.PRIMARY)
	assert_bool(board.clock_in()).is_true()


## The locks: the swap plate, RESTOCK's key (shown LOCKED on a fresh profile, where it is
## otherwise hidden) and NEW PACKS are drawn locked, their clicks and keys refused; anchors find
## them. Without the locks a fresh profile's page is as before.
func test_the_locks_draw_and_refuse() -> void:
	var page: BoosterPage = await _page(1)
	var board: StartBoard = _board(page)
	_stocked(page)
	assert_bool(BoosterChromeDraw.key_shown(page)).is_false()
	var locks: Array[StringName] = [
		TutorialAnchors.SWAP_PLATE, TutorialAnchors.RESTOCK, TutorialAnchors.NEWPACKS
	]
	_gate(board).guide_locks = func(id: StringName) -> bool: return locks.has(id)
	page.advance(0.0)
	assert_bool(BoosterChromeDraw.key_shown(page)).is_true()
	assert_bool(BoosterChromeDraw.key_locked(page)).is_true()
	assert_bool(_ids(page.hits).has("restock")).is_true()
	assert_float(BoosterChromeDraw.hint_rect(page).end.x).is_less_equal(
		BoosterChromeDraw.key_rect().position.x
	)
	_click(page, BoosterChromeDraw.key_rect().get_center())
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	_click(page, BoosterChromeDraw.CRATE_RECT.get_center())
	_click(page, BoosterChromeDraw.SWAP_PLATE_RECT.get_center())
	assert_bool(page.swap.active).is_false()
	assert_str(page.message).is_empty()
	page.queue_redraw()
	await get_tree().process_frame
	board.show_page(2, "tab")
	board._end_slide()
	var staff: BuildPage = board.staff
	staff.frozen = true
	for _step: int in 240:
		staff.advance(STEP)
	assert_bool(BuildPageDraw.deck_live(staff)).is_false()
	var packs_before: Array[StarterPackDefinition] = board.run.start_offer.packs.duplicate()
	staff.click(Vector2(BuildPage.DECK) + Vector2(20, 40))
	assert_bool(board.new_packs()).is_false()
	assert_array(board.run.start_offer.packs).is_equal(packs_before)
	assert_bool(board.run.start_setup.packs_redrawn).is_false()
	await get_tree().process_frame
	locks.clear()
	assert_bool(BuildPageDraw.deck_live(staff)).is_true()


## Six regulars stand in the crate in two zigzag rows: each inside the crate, in reading order,
## their tip rects apart; four stand as before (REG_X + k * REG_STEP). A page with 6 draws.
func test_the_crate_holds_six_regulars() -> void:
	for k: int in 4:
		assert_vector(BoosterArt.regular_at(k, 4)).is_equal(
			Vector2(BoosterArt.REG_X + k * BoosterArt.REG_STEP, BoosterArt.REG_Y)
		)
	var crate: Rect2 = BoosterChromeDraw.CRATE_RECT
	var rects: Array[Rect2] = []
	for k: int in 6:
		var at: Vector2 = BoosterArt.regular_at(k, 6)
		# The sprite's 32 px of art inside its 48 px canvas stays inside the crate.
		(
			assert_bool(crate.encloses(Rect2(at + Vector2(8, 0), Vector2(32, 36))))
			. override_failure_message("regular %d at %s" % [k, at])
			. is_true()
		)
		if k > 0:
			assert_float(at.x).is_greater(BoosterArt.regular_at(k - 1, 6).x)
		rects.append(BoosterArt.regular_rect(k, 6))
	for a: int in rects.size():
		assert_bool(crate.encloses(rects[a])).is_true()
		for b: int in range(a + 1, rects.size()):
			(
				assert_bool(rects[a].intersects(rects[b]))
				. override_failure_message("%d and %d" % [a, b])
				. is_false()
			)
	assert_array(BoosterArt.crate_order(6)).is_equal([1, 3, 5, 0, 2, 4])
	assert_array(BoosterArt.crate_order(4)).is_equal([0, 1, 2, 3])
	var page: BoosterPage = await _page(0)
	var starter: DeckDefinition = page.run.starter.duplicate()
	var extra: Array[CardDefinition] = [
		load("res://data/cards/bread.tres") as CardDefinition,
		load("res://data/cards/coffee.tres") as CardDefinition,
	]
	var regulars: Array[CardDefinition] = starter.core_cards.duplicate()
	regulars.append_array(extra)
	starter.core_cards = regulars
	page.run.starter = starter
	page.run.start_setup.originals.append_array(extra)
	_stocked(page)
	await get_tree().process_frame
	assert_int(BoosterChromeDraw.tip_entries(page).size()).is_greater_equal(6)


## StartGuide's anchors at both sizes: page 1's, the swap window's and page 2's lie on the board,
## where the page draws them (a booster's pouch, then its fan); one not shown is Rect2().
func test_the_anchors_lie_on_the_board_at_both_sizes() -> void:
	for size: Vector2 in SIZES:
		var page: BoosterPage = await _page(2)
		var board: StartBoard = _board(page)
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = size
		board._resize()
		var guide: StartGuide = StartGuide.new(board)
		var frame: Rect2 = board.get_global_rect()
		page.openings.roll_up()
		page.openings.end_arrival()
		_run(page, 1.0)
		var sealed: Rect2 = guide.anchor_rect(TutorialAnchors.booster(0))
		_assert_on(frame, sealed, "booster0 sealed %s" % size)
		_stocked(page)
		var ids: Array[StringName] = [
			TutorialAnchors.CRATE,
			TutorialAnchors.SWAP_PLATE,
			TutorialAnchors.PRIMARY,
			TutorialAnchors.TITLE,
			TutorialAnchors.TAB2,
			TutorialAnchors.booster(0),
			TutorialAnchors.booster(1),
			TutorialAnchors.card(0, 1),
		]
		for id: StringName in ids:
			_assert_on(frame, guide.anchor_rect(id), "%s %s" % [id, size])
		assert_object(guide.anchor_rect(TutorialAnchors.booster(0))).is_not_equal(sealed)
		assert_object(guide.anchor_rect(TutorialAnchors.RESTOCK)).is_equal(Rect2())
		assert_object(guide.anchor_rect(TutorialAnchors.pack(0))).is_equal(Rect2())
		var plate: Rect2 = guide.anchor_rect(TutorialAnchors.SWAP_PLATE)
		var expected: Rect2 = _on_screen(page, BoosterChromeDraw.SWAP_PLATE_RECT)
		assert_vector(plate.position).is_equal_approx(expected.position, Vector2.ONE)
		assert_bool(guide.swap_due()).is_true()
		assert_bool(page.swap.open_window(false)).is_true()
		_run(page, 2.0)
		for id: StringName in [
			TutorialAnchors.SWAP_DONE,
			TutorialAnchors.SWAP_RESET,
			TutorialAnchors.SWAP_BOOSTERS,
			TutorialAnchors.indexed(TutorialAnchors.SWAP_BOOSTER, 0),
			TutorialAnchors.indexed(TutorialAnchors.SWAP_REGULAR, 3),
		]:
			_assert_on(frame, guide.anchor_rect(id), "%s %s" % [id, size])
		page.swap.close(false)
		_run(page, 2.0)
		board.show_page(2, "tab")
		board._end_slide()
		var staff: BuildPage = board.staff
		staff.frozen = true
		for _step: int in 240:
			staff.advance(STEP)
		assert_int(guide.shown_page()).is_equal(1)
		for id: StringName in [
			TutorialAnchors.pack(0),
			TutorialAnchors.pack(2),
			TutorialAnchors.NEWPACKS,
			TutorialAnchors.PRIMARY,
			TutorialAnchors.BACK,
			TutorialAnchors.PINS,
			TutorialAnchors.TAB1,
		]:
			_assert_on(frame, guide.anchor_rect(id), "%s %s" % [id, size])
		assert_object(guide.anchor_rect(TutorialAnchors.PINS_CONFIRM)).is_equal(Rect2())
		assert_object(guide.anchor_rect(TutorialAnchors.CRATE)).is_equal(Rect2())


## The overlay's mount point is over both pages and their tips; StartGuide passes the board's
## tips_blocked through.
func test_the_overlay_mounts_over_the_board() -> void:
	var page: BoosterPage = await _page(0)
	var board: StartBoard = _board(page)
	var guide: StartGuide = StartGuide.new(board)
	assert_bool(guide.blocked()).is_true()
	var overlay: Control = auto_free(Control.new())
	guide.mount(overlay)
	assert_object(overlay.get_parent()).is_same(board)
	assert_int(overlay.get_index()).is_equal(board.get_child_count() - 1)
	await get_tree().process_frame
	assert_vector(overlay.size).is_equal(board.size)
	_stocked(page)
	assert_bool(guide.blocked()).is_equal(board.tips_blocked())


static func _listen(board: StartBoard) -> Array[Array]:
	var events: Array[Array] = []
	board.guide_event.connect(
		func(event: StringName, args: Dictionary) -> void: events.append([event, args])
	)
	return events


static func _has(events: Array[Array], event: StringName, args: Dictionary) -> bool:
	for entry: Array in events:
		if entry[0] == event and entry[1] == args:
			return true
	return false


static func _count(events: Array[Array], event: StringName) -> int:
	var n: int = 0
	for entry: Array in events:
		if entry[0] == event:
			n += 1
	return n


static func _ids(hits: Array[Dictionary]) -> Array[String]:
	var found: Array[String] = []
	for entry: Dictionary in hits:
		found.append(entry.id)
	return found


static func _card_piece(page: BoosterPage) -> SwapPiece:
	for piece: SwapPiece in page.swap.pieces:
		if not piece.regular and page.swap.drop_reason(piece, 0) == "":
			return piece
	return null


func _assert_on(frame: Rect2, rect: Rect2, what: String) -> void:
	(
		assert_bool(rect.size.x > 0.0 and rect.size.y > 0.0)
		. override_failure_message("empty " + what)
		. is_true()
	)
	(
		assert_bool(frame.grow(1.0).encloses(rect))
		. override_failure_message("%s: %s off %s" % [what, rect, frame])
		. is_true()
	)


## The screen's StartChoice (its gate and locks).
static func _gate(board: StartBoard) -> StartChoice:
	var node: Node = board.get_parent()
	while node != null and not node is ShiftScreen:
		node = node.get_parent()
	return (node as ShiftScreen)._start_choice


## The page (frozen on its clock, reduced motion off) of a new run with `completed` aisles
## complete.
func _page(completed: int) -> BoosterPage:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(false)
	for index: int in screen._balance.aisles.size():
		var aisle: AisleDefinition = screen._balance.aisles[index]
		var count: int = (
			aisle.capsule_cards.size()
			if index < completed
			else (
				mini(4, aisle.capsule_cards.size())
				if aisle.base_cards.is_empty() and completed > 0
				else 0
			)
		)
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			screen.profile.unlocked_items[card.id] = 0
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	var page: BoosterPage = screen._cart_reveal.board.store
	page.frozen = true
	return page


static func _board(page: BoosterPage) -> StartBoard:
	var node: Node = page.get_parent()
	while node != null and not node is StartBoard:
		node = node.get_parent()
	return node as StartBoard


## Rolls up, opens every booster and lets STOCKED! come.
static func _stocked(page: BoosterPage) -> void:
	page.openings.roll_up()
	page.openings.end_arrival()
	page.openings.open_all("key")
	_run(page, 8.0)


static func _run(page: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		page.advance(minf(STEP, left))
		left -= STEP


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at * ArtPen.UNIT
	return button


## A click (press and release, no travel) at art point `at` through the page's input.
static func _click(page: BoosterPage, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at * ArtPen.UNIT
	page._gui_input(motion)
	page._gui_input(_button(at, true))
	page._gui_input(_button(at, false))
	page.advance(0.0)


static func _on_screen(page: BoosterPage, rect: Rect2) -> Rect2:
	return page.get_global_transform() * Rect2(rect.position * ArtPen.UNIT, rect.size * ArtPen.UNIT)


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog") as EventLogService
