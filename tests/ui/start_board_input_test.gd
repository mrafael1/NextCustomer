extends GdUnitTestSuite
## The opening board's input and lifecycle on the real screen: the OPEN STORE shutter's click and
## Enter skips (reduced motion off) and its release, Esc stepping back (the swap shelf, a RESTOCK
## pick, page 1, the title), the board leaving F1 to the debug panel, and page 1's pop-ups
## scaling with the board at 1080p.

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


## Esc closes the swap shelf, then stops a RESTOCK pick, then goes back from page 2 to page 1,
## then asks the screen for the title (the screen closes the board; the scene change is off in
## tests).
func test_escape_steps_back_from_shelf_to_restock_to_store_to_title() -> void:
	var screen: ShiftScreen = await _screen(3)
	screen._start_choice.changes_scene = false
	var board: StartBoard = screen._cart_reveal.board
	var asked: Array[int] = [0]
	board.back_to_title.connect(func() -> void: asked[0] += 1)
	board.show_page(2)
	board.show_page(1)
	get_tree().root.push_input(_key(KEY_1), true)
	assert_object(board.popover).is_not_null()
	assert_int(board.store.open_slot).is_equal(0)
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_object(board.popover).is_null()
	assert_object(board._modal).is_null()
	assert_int(board.store.open_slot).is_equal(-1)
	assert_int(board.page).is_equal(1)
	get_tree().root.push_input(_key(KEY_R), true)
	assert_bool(board.store.restock_picking).is_true()
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_bool(board.store.restock_picking).is_false()
	assert_int(screen.run.start_setup.restock_basket).is_equal(-1)
	assert_int(board.page).is_equal(1)
	board.show_page(2)
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


## The pop-ups sit on the scaled stage: at 1920x1080 the swap shelf is 1.5x, inside the board,
## above its regular and clear of it, its tabs and offers inside it; the aisle choice the same
## under its sign.
func test_the_pop_ups_scale_with_the_board() -> void:
	var screen: ShiftScreen = await _screen(6)
	var board: StartBoard = screen._cart_reveal.board
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(1920, 1080)
	board._resize()
	var frame: Rect2 = board.get_global_rect()
	assert_bool(board.open_swap(0)).is_true()
	var shelf: Rect2 = board.popover.get_global_rect()
	assert_vector(shelf.size).is_equal_approx(board.popover.size * 1.5, Vector2.ONE)
	assert_bool(frame.encloses(shelf)).is_true()
	var tile: Rect2 = board.store.regulars[0].get_global_rect()
	assert_bool(shelf.intersects(tile)).is_false()
	assert_float(shelf.end.y).is_less_equal(tile.position.y)
	var keys: Array[Control] = []
	for tab: Button in board.popover.tabs.values():
		keys.append(tab)
	for offer: Button in board.popover.offers:
		keys.append(offer)
	_assert_inside_apart(shelf, keys)
	board.back()
	assert_bool(board.open_aisles(1)).is_true()
	var choice: Rect2 = board.popover.get_global_rect()
	assert_bool(frame.encloses(choice)).is_true()
	var sign_rect: Rect2 = board.store.signs[1].get_global_rect()
	assert_bool(choice.intersects(sign_rect)).is_false()
	assert_float(choice.position.y).is_greater_equal(sign_rect.end.y)
	var options: Array[Control] = []
	for option: Button in board.popover.options.values():
		options.append(option)
	assert_int(options.size()).is_greater(0)
	_assert_inside_apart(choice, options)


func _assert_inside_apart(outer: Rect2, controls: Array[Control]) -> void:
	var seen: Array[Rect2] = []
	for control: Control in controls:
		var rect: Rect2 = control.get_global_rect()
		assert_bool(outer.encloses(rect)).override_failure_message(control.name).is_true()
		for other: Rect2 in seen:
			assert_bool(rect.intersects(other)).override_failure_message(control.name).is_false()
		seen.append(rect)


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
	board.show_page(2)
	assert_bool(board.page_sliding()).is_false()
	assert_bool(board.staff.visible and not board.store.visible).is_true()


## The page tabs' step digits ("1", "2") sit exactly centred in their boxes, on whole screen
## pixels, at 1280x720 and 1920x1080 (the user: "1 & 2 inside boxes ... aren't centered"): the
## digit's ink (its 6x8 glyph fills its box) has the box's centre, both pages, both tab states.
func test_the_page_steps_are_centred_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		for page: int in [1, 2]:
			board.show_page(page)
			board.refresh()
			for index: int in 2:
				var box: Panel = board._rail.get_node("Tab%d/Step" % (index + 1))
				var digit: PixelWords = box.get_node("Digit")
				assert_str(digit.text).is_equal(str(index + 1))
				var ink: Rect2 = digit.get_global_rect()
				var frame: Rect2 = box.get_global_rect()
				assert_vector(ink.size).is_equal(
					(
						PixelWords.text_size(digit.text, digit.sheet, digit.cell)
						* board_size.x
						/ 1280.0
					)
				)
				assert_vector(ink.get_center()).is_equal(frame.get_center())
				for corner: Vector2 in [ink.position, ink.end, frame.position, frame.end]:
					assert_vector(corner).is_equal(corner.round())


## The RESTOCK pick's hover with motion on (as the redraw's, RedrawTuning): the basket eases up
## hover_lift px and wobbles about its centre-bottom, its tag hot; leaving puts it back at rest.
func test_a_restock_pick_hover_lifts_and_wobbles_the_basket() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	screen.profile.set_reduced_motion(false)
	board.refresh()
	assert_bool(board.start_restock()).is_true()
	var store: StorePage = board.store
	var bob: Control = store.bays[1].get_node("Bob")
	var tuning: RedrawTuning = load(BasketRedraw.TUNING_PATH)
	store.hits[1].mouse_entered.emit()
	assert_bool(store.restock_tag(1).is_hot()).is_true()
	var tilted: bool = false
	var ends: int = Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < ends:
		await get_tree().process_frame
		tilted = tilted or absf(bob.rotation) > 0.001
	assert_float(bob.position.y).is_equal_approx(-tuning.hover_lift, 0.01)
	assert_bool(tilted).is_true()
	assert_float(bob.rotation).is_less_equal(deg_to_rad(tuning.hover_wobble_deg) + 0.001)
	store.hits[1].mouse_exited.emit()
	ends = Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < ends:
		await get_tree().process_frame
	assert_float(bob.position.y).is_equal(0.0)
	assert_float(bob.rotation).is_equal(0.0)
	assert_bool(store.restock_tag(1).is_hot()).is_false()
	board.cancel_restock()
	assert_object(store.restock_tag(1)).is_null()


## Page 2 with reduced motion, then clock-in with it off; returns the shutter once it plays.
func _clock_in_with_motion(screen: ShiftScreen) -> RollerShutter:
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	screen.profile.set_reduced_motion(false)
	assert_bool(board.clock_in()).is_true()
	var ends: int = Time.get_ticks_msec() + 3000
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
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	return screen


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
