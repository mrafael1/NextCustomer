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
