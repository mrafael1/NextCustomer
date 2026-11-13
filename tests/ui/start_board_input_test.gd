extends GdUnitTestSuite
## The opening board's input and lifecycle on the real screen: the OPEN STORE shutter's click and
## Enter skips (reduced motion off) and its release, Esc stepping back (the swap tray, a RESTOCK
## pick, page 1, the title), the board leaving F1 to the debug panel, YOUR STORE scaling with the
## board at 1080p (a mouse click on a booster lands where it is drawn), the page slide and the
## page steps.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261104

var _folder: String


func before_test() -> void:
	_folder = "user://start_board_input_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## OPEN STORE (reduced motion off): a click skips the shutter straight to opened, shift 1
## starting behind it, and the reveal frees it.
func test_a_click_skips_the_open_store_shutter() -> void:
	var screen: ShiftScreen = await _screen()
	var shutter: RollerShutter = await _clock_in_with_motion(screen)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 300)
	get_tree().root.push_input(click, true)
	_assert_shutter_skipped(screen, shutter)
	await get_tree().process_frame
	assert_bool(is_instance_valid(shutter)).is_false()


## Enter skips it too.
func test_enter_skips_the_open_store_shutter() -> void:
	var screen: ShiftScreen = await _screen()
	var shutter: RollerShutter = await _clock_in_with_motion(screen)
	get_tree().root.push_input(_key(KEY_ENTER), true)
	_assert_shutter_skipped(screen, shutter)
	await get_tree().process_frame
	assert_bool(is_instance_valid(shutter)).is_false()


## A new run while the shutter plays frees it with no signal: the old pack never reaches the
## new run.
func test_a_new_run_frees_a_playing_shutter() -> void:
	var screen: ShiftScreen = await _screen()
	var shutter: RollerShutter = await _clock_in_with_motion(screen)
	screen.start_new_run(SEED + 1, true, false)
	assert_bool(shutter.is_done()).is_true()
	assert_object(screen._cart_reveal._shutter).is_null()
	await get_tree().process_frame
	assert_bool(is_instance_valid(shutter)).is_false()
	assert_int(screen.run.run_seed).is_equal(SEED + 1)


## Esc closes the swap tray, then stops a RESTOCK pick, then goes back from page 2 to page 1,
## then asks the screen for the title (the screen closes the board; the scene change is off in
## tests).
func test_escape_steps_back_from_tray_to_restock_to_store_to_title() -> void:
	var screen: ShiftScreen = await _screen(3)
	screen._start_choice.changes_scene = false
	var board: StartBoard = screen._cart_reveal.board
	var store: BoosterPage = board.store
	store.frozen = true
	var asked: Array[int] = [0]
	board.back_to_title.connect(func() -> void: asked[0] += 1)
	get_tree().root.push_input(_key(KEY_A), true)
	_run(store, 8.0)
	assert_bool(store.page_done()).is_true()
	assert_bool(store.counter.click_regular(0)).is_true()
	assert_int(store.tray_slot).is_equal(0)
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_int(store.tray_slot).is_equal(-1)
	assert_int(board.page).is_equal(1)
	get_tree().root.push_input(_key(KEY_R), true)
	assert_bool(store.restock_armed).is_true()
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_bool(store.restock_armed).is_false()
	assert_int(screen.run.start_setup.restock_booster()).is_equal(-1)
	assert_int(board.page).is_equal(1)
	_open_boosters(board)
	board.show_page(2)
	# Page 2 opens on the BADGE PINS step (v1.32): Esc closes it first.
	assert_bool(board.staff.pins_open).is_true()
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_bool(board.staff.pins_open).is_false()
	assert_int(board.page).is_equal(2)
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_int(board.page).is_equal(1)
	assert_int(asked[0]).is_equal(0)
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_int(asked[0]).is_equal(1)
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_object(screen._cart_reveal.board).is_null()


## The board answers only its own keys: F1 still reaches the debug panel.
func test_f1_reaches_the_debug_panel_through_the_board() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: Control = screen._debug.panel
	assert_object(panel).is_not_null()
	var shown: bool = panel.visible
	get_tree().root.push_input(_key(KEY_F1), true)
	assert_bool(panel.visible).is_equal(not shown)
	assert_int(screen._cart_reveal.board.page).is_equal(1)
	get_tree().root.push_input(_key(KEY_F1), true)
	assert_bool(panel.visible).is_equal(shown)


## YOUR STORE sits on the scaled stage: at 1920x1080 the page is drawn at 1.5x inside the board,
## a real mouse click on a booster (through the viewport) opens that booster, and the swap tray
## is 1.5x, inside the board and clear of the regulars' crate, its offers inside it and apart.
func test_your_store_scales_with_the_board() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: BoosterPage = board.store
	store.frozen = true
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(1920, 1080)
	board._resize()
	_run(store, 0.1)
	var frame: Rect2 = board.get_global_rect()
	var to_screen: Transform2D = store.get_global_transform()
	assert_float(to_screen.get_scale().x).is_equal_approx(1.5, 0.001)
	var pouch: Rect2 = BoosterArt.pouch_rect(store.boosters[1].cx)
	var at: Vector2 = to_screen * (pouch.get_center() * ArtPen.UNIT)
	assert_bool(frame.has_point(at)).is_true()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	click.global_position = at
	get_tree().root.push_input(click, true)
	assert_bool(screen.run.start_setup.boosters[1].opened).is_true()
	assert_bool(screen.run.start_setup.boosters[0].opened).is_false()
	store.openings.open_all("key")
	_run(store, 8.0)
	assert_bool(store.counter.click_regular(0)).is_true()
	store.advance(0.0)
	var tray: Rect2 = Rect2()
	var minis: Array[Rect2] = []
	var regulars: Array[Rect2] = []
	for entry: Dictionary in store.hits:
		var rect: Rect2 = (
			to_screen
			* Rect2(
				(entry.rect as Rect2).position * ArtPen.UNIT,
				(entry.rect as Rect2).size * ArtPen.UNIT
			)
		)
		if entry.id == "tray":
			tray = rect
		elif String(entry.id).begins_with("mini"):
			minis.append(rect)
		elif String(entry.id).begins_with("reg"):
			regulars.append(rect)
	assert_bool(tray.has_area()).is_true()
	assert_bool(frame.encloses(tray)).is_true()
	assert_bool(minis.is_empty()).is_false()
	assert_bool(regulars.is_empty()).is_false()
	for k: int in minis.size():
		assert_bool(tray.encloses(minis[k])).is_true()
		for other: int in k:
			assert_bool(minis[k].intersects(minis[other])).is_false()
	for regular: Rect2 in regulars:
		assert_bool(tray.intersects(regular)).is_false()


static func _run(store: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		store.advance(minf(1.0 / 60.0, left))
		left -= 1.0 / 60.0


## The page slide (reduced motion off), both ways: it starts the frame after the pages are built,
## and from then every frame moves it (monotonic, whole stage pixels, at most the distance one
## capped frame covers from where it is: never stepped to the art grid, never a jump after the
## build's frame), no node is built
## while it runs, and it settles at rest. Reduced motion swaps the pages at once.
func test_the_page_slide_moves_smoothly_every_frame() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	screen.profile.set_reduced_motion(false)
	var added: Array[Node] = []
	var count_added: Callable = func(node: Node) -> void: added.append(node)
	for next_page: int in [2, 1]:
		board.staff.pins.close()  # Page 2's BADGE PINS step holds the page while open.
		board.show_page(next_page)
		assert_bool(board.page_sliding()).is_true()
		var fresh: Control = (
			(board.staff as Control) if next_page == 2 else (board.store as Control)
		)
		var direction: float = 1.0 if next_page == 2 else -1.0
		get_tree().node_added.connect(count_added)
		var offsets: Array[float] = []
		var times: Array[float] = []
		while board.page_sliding():
			offsets.append(ShiftStage.SIZE.x - fresh.position.x * direction)
			times.append(board._slide_time)
			await get_tree().process_frame
		get_tree().node_added.disconnect(count_added)
		assert_array(added).is_empty()
		assert_int(offsets.size()).is_greater(int(board.slide_s * 30))
		var moved: int = 0
		for index: int in range(1, offsets.size()):
			var step: float = offsets[index] - offsets[index - 1]
			assert_float(step).is_greater_equal(0.0)
			var reach: float = (
				board._slide_offset(times[index - 1] + StartBoard.SLIDE_MAX_STEP)
				- board._slide_offset(times[index - 1])
			)
			assert_float(step).is_less_equal(reach + 1.0)
			# A frame that stays put is fine when the eased curve, snapped to whole pixels, gives
			# the same offset for its time (the ease-out's last frames move under half a pixel).
			var due: bool = (
				board._slide_offset(times[index]) != board._slide_offset(times[index - 1])
			)
			moved += 1 if step > 0.0 or not due else 0
		# Only the hold over the build's frame and a headless frame with no time in it repeat.
		assert_int(moved).is_greater_equal(offsets.size() - 4)
		assert_vector(board.store.position).is_equal(Vector2.ZERO)
		assert_vector(board.staff.position).is_equal(Vector2.ZERO)
		assert_bool(fresh.visible).is_true()
	for half: int in 3:
		assert_float(board._slide_offset(board.slide_s * half / 2.0)).is_equal_approx(
			[0.0, ShiftStage.SIZE.x * sin(PI / 4.0), ShiftStage.SIZE.x][half], 1.0
		)
	screen.profile.set_reduced_motion(true)
	_open_boosters(board)
	board.show_page(2)
	assert_bool(board.page_sliding()).is_false()
	assert_bool(board.staff.visible and not board.store.visible).is_true()


## The page tabs (v1.32: drawn in the shared top bar on the art grid, so on whole pixels at any
## scale): each page lights its own tab, the other tab's hit is the tab's drawn box (x 156 + 84 k,
## y 7, 82 x 20 art px), and a click on it turns the page, both ways, at 1280x720 and 1920x1080.
func test_the_page_tabs_turn_the_page_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.store.frozen = true
	get_tree().root.push_input(_key(KEY_A), true)
	_run(board.store, 8.0)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		board.show_page(1)
		board.store.advance(0.0)
		var tab2: Dictionary = _hit(board.store.hits, "tab2")
		assert_object(tab2.get("rect")).is_equal(Rect2(240, 7, 82, 20))
		(tab2.act as Callable).call()
		assert_int(board.page).is_equal(2)
		assert_int(BuildPageDraw.top_view(board.staff).tab).is_equal(2)
		board.back()  # The BADGE PINS step closes first.
		assert_int(board.page).is_equal(2)
		board.staff.advance(0.0)
		var tab1: Dictionary = _hit(board.staff.hits, "tab1")
		assert_object(tab1.get("rect")).is_equal(Rect2(156, 7, 82, 20))
		board.staff.click(Vector2(160, 12))
		assert_int(board.page).is_equal(1)
		var scale: float = board._stage.scale.x
		assert_float(scale).is_equal_approx(board_size.x / 1280.0, 0.001)


static func _hit(hits: Array[Dictionary], id: String) -> Dictionary:
	for entry: Dictionary in hits:
		if entry.id == id:
			return entry
	return {}


## Page 2 with reduced motion (the pins confirmed, pack 1 picked), then OPEN STORE with it off: the
## flight to the cart plays, then the shutter; returns the shutter once it plays.
func _clock_in_with_motion(screen: ShiftScreen) -> RollerShutter:
	var board: StartBoard = screen._cart_reveal.board
	_open_boosters(board)
	board.show_page(2)
	board.staff.advance(0.2)
	assert_bool(board.staff.primary()).is_true()
	board.pick(0)
	screen.profile.set_reduced_motion(false)
	board.refresh()
	assert_bool(board.clock_in()).is_true()
	assert_object(board.staff.flight).is_not_null()
	var ends: int = Time.get_ticks_msec() + 5000
	while screen._cart_reveal._shutter == null and Time.get_ticks_msec() < ends:
		await get_tree().process_frame
	var shutter: RollerShutter = screen._cart_reveal._shutter
	assert_object(shutter).is_not_null()
	await get_tree().process_frame
	assert_bool(shutter.is_done()).is_false()
	assert_int(screen.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	return shutter


func _assert_shutter_skipped(screen: ShiftScreen, shutter: RollerShutter) -> void:
	assert_bool(shutter.is_done()).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_object(screen._cart_reveal._shutter).is_null()


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


func _screen(completed: int = 0) -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
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
	# One earned pin, so page 2 opens on the BADGE PINS step (the pins every profile starts with
	# don't hold the packs).
	for pin: PinDefinition in screen._catalogue.pins:
		if pin.unlock_condition != null:
			screen.profile.unlocked_pins.append(pin.id)
			break
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	return screen


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## Opens every dealt booster through the board's actions (page 1's job), so page 2's OPEN STORE
## isn't held by a sealed booster.
static func _open_boosters(board: StartBoard) -> void:
	for index: int in board.run.start_setup.boosters.size():
		board._choice.open_booster.call(index)
