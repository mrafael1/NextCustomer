extends GdUnitTestSuite
## The title screen with a run save (full build plan section 4): Continue and New run instead
## of "click anywhere", laid out on screen; New run asks first, and only a yes abandons the save
## (logged as run_abandon under its run id). The title never changes the test runner's scene.

const TITLE := "res://ui/title_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RUN_ID := "0011223344556677"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_without_a_run_save_a_click_starts() -> void:
	var title: TitleScreen = await _title()
	assert_object(title._continue_button).is_null()
	assert_object(title._new_run_button).is_null()
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_true()


## An unreadable run save is left for the shift screen to report and back up: the title works
## as without one and touches nothing.
func test_an_unreadable_run_save_shows_no_continue() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var file: FileAccess = FileAccess.open(_run_file(), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var title: TitleScreen = await _title()
	assert_object(title._continue_button).is_null()
	assert_bool(FileAccess.file_exists(_run_file() + SaveService.BACKUP_SUFFIX)).is_false()
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal("{broken")


## With a save, Continue (naming the shift) and New run show inside the window, clear of the
## title's labels. A background click starts nothing; Enter continues and keeps the save.
func test_a_run_save_shows_continue_and_new_run_on_screen() -> void:
	_save_run_at_shift(3)
	var title: TitleScreen = await _title()
	assert_str(title._continue_button.text).is_equal("Continue (shift 3 / %d)" % _shift_count())
	assert_str(title._new_run_button.text).is_equal("New run")
	var screen: Rect2 = title.get_viewport_rect()
	var labels: Array[Rect2] = [title._subtitle.get_global_rect(), title._coins.get_global_rect()]
	var buttons: Array[Rect2] = [
		title._continue_button.get_global_rect(), title._new_run_button.get_global_rect()
	]
	for button: Rect2 in buttons:
		assert_bool(screen.encloses(button)).is_true()
		assert_float(button.size.x).is_greater_equal(200.0)
		assert_float(button.size.y).is_greater_equal(64.0)
		for label: Rect2 in labels:
			assert_bool(button.intersects(label)).is_false()
	assert_bool(buttons[0].intersects(buttons[1])).is_false()
	assert_float(buttons[0].position.y).is_greater(title._coins.get_global_rect().end.y)
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_false()
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_true()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()
	assert_dict(_last_event("run_abandon")).is_empty()


func test_continue_keeps_the_save() -> void:
	_save_run_at_shift(1)
	var title: TitleScreen = await _title()
	assert_str(title._continue_button.text).is_equal("Continue (shift 1 / %d)" % _shift_count())
	title._continue_button.pressed.emit()
	assert_bool(title._starting).is_true()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()


## New run asks first, in a panel inside the window. No keeps the save; yes deletes it, logs
## run_abandon under the saved run id and starts a new run.
func test_new_run_asks_before_abandoning_the_save() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	title._new_run_button.pressed.emit()
	assert_bool(title._starting).is_false()
	assert_bool(title._confirm.visible).is_true()
	assert_bool(title._confirm_shade.visible).is_true()
	await _frames(4)
	await get_tree().create_timer(0.4).timeout
	var screen: Rect2 = title.get_viewport_rect()
	var panel: Rect2 = title._confirm.get_global_rect()
	assert_bool(screen.encloses(panel)).is_true()
	assert_float(panel.size.x).is_greater(300.0)
	for button: Button in [title._abandon_button, title._keep_button]:
		assert_bool(panel.encloses(button.get_global_rect())).is_true()
	# While it asks, Enter neither continues nor abandons.
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_false()

	title._keep_button.pressed.emit()
	assert_bool(title._confirm.visible).is_false()
	assert_bool(title._confirm_shade.visible).is_false()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()
	assert_bool(title._starting).is_false()
	assert_dict(_last_event("run_abandon")).is_empty()

	title._new_run_button.pressed.emit()
	title._abandon_button.pressed.emit()
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_bool(title._starting).is_true()
	var abandon: Dictionary = _last_event("run_abandon")
	assert_str(abandon["run_id"]).is_equal(RUN_ID)
	assert_int(int(abandon["shift"])).is_equal(2)
	assert_str(abandon["phase"]).is_equal("planning")
	assert_int(int(abandon["run_ms"])).is_equal(1000)


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	await _frames(4)
	return title


## A run in planning on `shift` (1-based), saved under RUN_ID.
func _save_run_at_shift(shift: int) -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(31, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	run.debug_skip_to_shift(shift - 1)
	assert_bool(SaveService.new(_folder).save_run(run, RUN_ID, 1000)).is_true()


static func _shift_count() -> int:
	return (load(BALANCE) as BalanceDefinition).quotas.size()


func _run_file() -> String:
	return _folder.path_join(SaveService.RUN_FILE)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
