extends GdUnitTestSuite
## Start v4 B input and lifecycle on the real screen: the OPEN STORE shutter's click and Enter
## skips (reduced motion off) and its release, Esc stepping back (a carried regular, the swap
## strip and its preview, page 1, the title), the board leaving F1 to the debug panel, and the
## swap strip scaling with the board at 1080p.

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


## Esc puts a carried regular down, closes the swap strip, then its preview, then goes back from
## page 2 to page 1, then asks the screen for the title (the screen closes the board; the scene
## change is off in tests).
func test_escape_steps_back_from_carry_to_strip_to_store_to_title() -> void:
	var screen: ShiftScreen = await _screen(1)
	screen._start_choice.changes_scene = false
	var board: StartBoard = screen._cart_reveal.board
	var asked: Array[int] = [0]
	board.back_to_title.connect(func() -> void: asked[0] += 1)
	board.show_page(2)
	board.show_page(1)
	get_tree().root.push_input(_key(KEY_1), true)
	assert_int(board.store.carry_slot).is_equal(0)
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_bool(board.store.carrying()).is_false()
	assert_int(board.page).is_equal(1)
	var aisle: StringName = screen.run.balance.aisles[0].id
	board._dropped(0, aisle, "click")
	assert_object(board.strip).is_not_null()
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_object(board.strip).is_null()
	assert_object(board._modal).is_null()
	board._dropped(0, aisle, "click")
	board.strip.choose(_open_item(board))
	assert_bool(board.strip.previewing).is_true()
	get_tree().root.push_input(_key(KEY_ESCAPE), true)
	assert_object(board._modal).is_null()
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


## The swap strip sits on the scaled stage: at 1920x1080 it is 1.5x, inside the board, beside the
## aisle board and clear of it; its preview too.
func test_the_swap_strip_scales_with_the_board() -> void:
	var screen: ShiftScreen = await _screen(1)
	var board: StartBoard = screen._cart_reveal.board
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(1920, 1080)
	board._resize()
	board._dropped(0, screen.run.balance.aisles[0].id, "click")
	var strip: RegularSwapStrip = board.strip
	var frame: Rect2 = board.get_global_rect()
	var aisles: Rect2 = (board.store.board.get_node("Board") as Control).get_global_rect()
	for step: int in 2:
		var rect: Rect2 = strip.get_global_rect()
		assert_vector(rect.size).is_equal_approx(strip.size * 1.5, Vector2.ONE)
		assert_bool(frame.encloses(rect)).is_true()
		assert_bool(rect.intersects(aisles)).is_false()
		for button: Button in strip.items:
			assert_bool(rect.encloses(button.get_global_rect())).is_true()
		if step == 0:
			strip.choose(_open_item(board))
	assert_bool(strip.previewing).is_true()
	var confirm: Rect2 = strip.confirm_key.get_global_rect()
	var cancel: Rect2 = strip.cancel_key.get_global_rect()
	assert_bool(strip.get_global_rect().encloses(confirm)).is_true()
	assert_bool(strip.get_global_rect().encloses(cancel)).is_true()
	assert_bool(confirm.intersects(cancel)).is_false()


static func _open_item(board: StartBoard) -> int:
	for at: int in board.strip.items.size():
		if not board.strip.items[at].disabled:
			return at
	return 0


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
	assert_bool(screen._cart_reveal.board.lock_in()).is_true()
	return screen


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
