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
	# The boosters wait sealed for their clicks (round 2 of the 2026-11-19 play test): each
	# opening sends its hook.
	assert_int(_count(events, TutorialEvents.BOOSTER_OPENED)).is_equal(0)
	_run(page, 14.0)
	assert_int(_count(events, TutorialEvents.BOOSTER_OPENED)).is_equal(0)
	_open_landed(page)
	_run(page, 8.0)
	for index: int in 2:
		(
			assert_bool(
				_has(events, TutorialEvents.BOOSTER_OPENED, {TutorialEvents.ARG_INDEX: index})
			)
			. is_true()
		)
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
	assert_bool(staff.keep_regulars()).is_true()
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
	_run(page, 8.0)
	_open_landed(page)
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


## The gate: a skip is never asked (Enter while the light runs, a click while a booster opens); a
## refused click or key on the stocked page acts on nothing and flashes nothing; the same input
## once allowed acts; each ask names its hit as TutorialActions.HIT {id}.
func test_the_gate_refuses_and_allows_page_one_input() -> void:
	var page: BoosterPage = await _page(3)
	var board: StartBoard = _board(page)
	var asked: Array[StringName] = []
	var allowed: Array[StringName] = []
	_gate(board).guide_gate = func(action: StringName, args: Dictionary) -> bool:
		assert_str(action).is_equal(TutorialActions.HIT)
		asked.append(args[TutorialActions.ARG_ID] as StringName)
		return allowed.has(args[TutorialActions.ARG_ID] as StringName)
	board._input(_key(KEY_ENTER))
	assert_int(page.roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
	assert_array(asked).is_empty()
	# Opening a sealed booster is asked (its hit, or the primary key): opened here unasked, a click
	# while they open only speeds them up.
	_open_landed(page)
	_click(page, Vector2(320, 150))
	board._input(_key(KEY_SPACE))
	assert_array(asked).is_empty()
	_run(page, 8.0)
	assert_bool(page.page_done()).is_true()
	_click(page, BoosterChromeDraw.key_rect().get_center())
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	_click(page, BoosterChromeDraw.tab_rect(1).get_center())
	board._input(_key(KEY_ENTER))
	board._input(_key(KEY_SPACE))
	assert_int(board.page).is_equal(1)
	assert_str(page.message).is_empty()
	assert_array(asked).contains(
		[TutorialAnchors.RESTOCK, TutorialAnchors.TAB2, TutorialAnchors.PRIMARY]
	)
	allowed.append(TutorialAnchors.RESTOCK)
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_true()
	asked.clear()
	board._input(_key(KEY_1))
	assert_int(page.run.start_setup.restock_booster()).is_equal(-1)
	var first: int = page.shown_boosters()[0].index
	assert_array(asked).contains([TutorialAnchors.indexed(TutorialAnchors.RCARDS, first)])
	# Esc is never asked (the page's own Esc; the board's opens the options).
	asked.clear()
	page.handle_key(KEY_ESCAPE)
	assert_array(asked).is_empty()
	assert_bool(page.restock_armed).is_false()
	allowed.append(TutorialAnchors.PRIMARY)
	board._input(_key(KEY_ENTER))
	assert_int(board.page).is_equal(2)


## Page 2: a refused OPEN STORE (click, key, or the board's clock-in) does nothing; allowed, it
## acts.
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
	assert_bool(staff.keep_regulars()).is_true()
	var allowed: Array[StringName] = []
	_gate(board).guide_gate = func(_action: StringName, args: Dictionary) -> bool:
		return allowed.has(args[TutorialActions.ARG_ID] as StringName)
	staff.click(Rect2(BuildPage.PRIMARY_RECT).get_center())
	board._input(_key(KEY_ENTER))
	assert_bool(board.clock_in()).is_false()
	assert_object(staff.flight).is_null()
	allowed.append(TutorialAnchors.PRIMARY)
	assert_bool(board.clock_in()).is_true()


## The locks: RESTOCK's key is drawn LOCKED (on a profile that has RESTOCK; one without it never
## sees the key, locked or not) and page 2's SWAP key is hidden; their clicks and keys are refused.
## Without the locks the pages are as before.
func test_the_locks_draw_and_refuse() -> void:
	var fresh: BoosterPage = await _page(1)
	_stocked(fresh)
	_gate(_board(fresh)).guide_locks = func(_id: StringName) -> bool: return true
	fresh.advance(0.0)
	assert_bool(BoosterChromeDraw.key_shown(fresh)).is_false()
	assert_bool(_ids(fresh.hits).has("restock")).is_false()
	var page: BoosterPage = await _page(3)
	var board: StartBoard = _board(page)
	_stocked(page)
	assert_bool(BoosterChromeDraw.key_shown(page)).is_true()
	assert_bool(BoosterChromeDraw.key_locked(page)).is_false()
	var locks: Array[StringName] = [TutorialAnchors.SWAP_KEY, TutorialAnchors.RESTOCK]
	_gate(board).guide_locks = func(id: StringName) -> bool: return locks.has(id)
	page.advance(0.0)
	assert_bool(BoosterChromeDraw.key_shown(page)).is_true()
	assert_bool(BoosterChromeDraw.key_locked(page)).is_true()
	assert_bool(_ids(page.hits).has("restock")).is_true()
	_click(page, BoosterChromeDraw.key_rect().get_center())
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	assert_str(page.message).is_empty()
	page.queue_redraw()
	await get_tree().process_frame
	board.show_page(2, "tab")
	board._end_slide()
	var staff: BuildPage = board.staff
	staff.frozen = true
	staff.pins.close()
	for _step: int in 240:
		staff.advance(STEP)
	assert_bool(BuildRegulars.swap_shown(staff)).is_false()
	assert_bool(_ids(staff.hits).has(BuildRegulars.ID)).is_false()
	board._input(_key(KEY_S))
	assert_bool(board.open_swap()).is_false()
	assert_bool(page.swap.active).is_false()
	await get_tree().process_frame
	locks.clear()
	staff.advance(0.0)
	assert_bool(BuildRegulars.swap_shown(staff)).is_true()
	assert_bool(_ids(staff.hits).has(BuildRegulars.ID)).is_true()


## StartGuide's anchors at both sizes: page 1's, the swap window's and page 2's lie on the board,
## where the page draws them (a booster's bay, then its fan); one not shown is Rect2(). The swap
## window's show while it is open over page 2.
func test_the_anchors_lie_on_the_board_at_both_sizes() -> void:
	for size: Vector2 in SIZES:
		var page: BoosterPage = await _page(2)
		var board: StartBoard = _board(page)
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = size
		board._resize()
		var guide: StartGuide = StartGuide.new(board)
		var frame: Rect2 = board.get_global_rect()
		_run(page, 0.5)
		var sealed: Rect2 = guide.anchor_rect(TutorialAnchors.booster(0))
		_assert_on(frame, sealed, "booster0 sealed %s" % size)
		var bay: Rect2 = AisleBoardArt.bay_rect(page.boosters[0].bay, page.roulette.count)
		assert_vector(sealed.position).is_equal_approx(_on_screen(page, bay).position, Vector2.ONE)
		_stocked(page)
		var ids: Array[StringName] = [
			TutorialAnchors.PRIMARY,
			TutorialAnchors.TITLE,
			TutorialAnchors.TAB2,
			TutorialAnchors.CART,
			TutorialAnchors.booster(0),
			TutorialAnchors.booster(1),
			TutorialAnchors.card(0, 1),
		]
		for id: StringName in ids:
			_assert_on(frame, guide.anchor_rect(id), "%s %s" % [id, size])
		assert_object(guide.anchor_rect(TutorialAnchors.booster(0))).is_not_equal(sealed)
		assert_object(guide.anchor_rect(TutorialAnchors.RESTOCK)).is_equal(Rect2())
		var fan: Rect2 = guide.anchor_rect(TutorialAnchors.booster(0))
		var expected: Rect2 = _on_screen(page, page.boosters[0].fan_rect())
		assert_vector(fan.position).is_equal_approx(expected.position, Vector2.ONE)
		assert_object(guide.anchor_rect(TutorialAnchors.SWAP_KEY)).is_equal(Rect2())
		assert_bool(guide.swap_due()).is_false()
		board.show_page(2, "tab")
		board._end_slide()
		var staff: BuildPage = board.staff
		staff.frozen = true
		staff.pins.close()
		for _step: int in 240:
			staff.advance(STEP)
		assert_int(guide.shown_page()).is_equal(1)
		assert_bool(guide.swap_due()).is_true()
		var key: Rect2 = guide.anchor_rect(TutorialAnchors.SWAP_KEY)
		_assert_on(frame, key, "swap_key %s" % size)
		var key_at: Rect2 = (
			staff.get_global_transform()
			* Rect2(
				Vector2(BuildRegulars.SWAP_RECT.position) * ArtPen.UNIT,
				Vector2(BuildRegulars.SWAP_RECT.size) * ArtPen.UNIT
			)
		)
		assert_vector(key.position).is_equal_approx(key_at.position, Vector2.ONE)
		assert_bool(board.open_swap()).is_true()
		assert_bool(guide.swap_due()).is_false()
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
		assert_bool(board.swap_showing()).is_false()
		staff.advance(0.0)
		for id: StringName in [
			TutorialAnchors.PRIMARY,
			TutorialAnchors.BACK,
			TutorialAnchors.PINS,
			TutorialAnchors.TAB1,
			TutorialAnchors.SWAP_KEY,
		]:
			_assert_on(frame, guide.anchor_rect(id), "%s %s" % [id, size])
		assert_object(guide.anchor_rect(TutorialAnchors.PINS_CONFIRM)).is_equal(Rect2())


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
	page.roulette.skip()
	_open_landed(page)
	_run(page, 8.0)


## Opens every booster waiting sealed on the counter (their clicks).
static func _open_landed(page: BoosterPage) -> void:
	var next: BoosterOpening = page.openings.next_sealed()
	while next != null and page.openings.open_booster(next.index, "click"):
		next = page.openings.next_sealed()


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
