extends GdUnitTestSuite
## The title screen with a run save (full build plan section 4): Continue and New run instead
## of "click anywhere", laid out on screen; New run asks first, and only a yes abandons the save
## (logged as run_abandon under its run id). The title never changes the test runner's scene.

const TITLE := "res://ui/title_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RUN_ID := "0011223344556677"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")

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


## New run asks first, in a panel inside the window, that pops in with ui_open. No closes it
## with ui_close (#62) and keeps the save; yes deletes it, logs run_abandon under the saved run
## id and starts a new run.
func test_new_run_asks_before_abandoning_the_save() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	var sfx: Sfx = RECORDING_SFX.new()
	title.add_child(sfx)
	title._sfx = sfx
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
	assert_array(sfx.call("sound_names")).is_equal(["ui_click", "ui_open", "ui_close"])
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


## #63: the toy machine prop and the Toy machines button stand on the right, inside the window
## and clear of the title, the subtitle, the coins, the prompt or Continue and New run, and the
## bottom corner, with and without a run save.
func test_the_toy_machines_stand_clear_of_the_title() -> void:
	await _assert_toys_clear(false)


func test_the_toy_machines_stand_clear_of_continue_and_new_run() -> void:
	_save_run_at_shift(2)
	await _assert_toys_clear(true)


func _assert_toys_clear(saved: bool) -> void:
	var window: Vector2i = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	var title: TitleScreen = await _title()
	var screen: Rect2 = title.get_viewport_rect()
	var group: Rect2 = title._toys_group.get_global_rect()
	var button: Rect2 = title._toys_button.get_global_rect()
	assert_bool(screen.encloses(group)).override_failure_message(str(group)).is_true()
	assert_bool(group.encloses(button)).is_true()
	assert_float(button.size.x).is_greater_equal(200.0)
	var prop: Rect2 = (title._toys_group.get_child(0) as Control).get_global_rect()
	assert_vector(prop.size).is_equal(Vector2(144, 280))
	assert_float(screen.end.x - group.end.x).is_equal_approx(TitleScreen.TOYS_RIGHT, 0.5)
	var others: Array[Control] = [title._subtitle, title._coins]
	for label: Label in _labels(title):
		if label.text in ["NEXT CUSTOMER", "Click anywhere to start"]:
			others.append(label)
	for found: Node in title.find_children("*", "Button", true, false):
		if (found as Button).text == "Export log":
			others.append(found as Control)
	if saved:
		others.append(title._continue_button)
		others.append(title._new_run_button)
	for other: Control in others:
		var rect: Rect2 = other.get_global_rect()
		# A centred label spans the column: its text's own width must stay clear.
		var label: Label = other as Label
		if label != null and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			var width: float = label.get_minimum_size().x
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				width = label.custom_minimum_size.x
			rect = Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, rect.size.y)
		(
			assert_bool(rect.intersects(group))
			. override_failure_message("%s %s" % [other, rect])
			. is_false()
		)
	get_tree().root.size = window


## Toy machines opens the machines over the title; while they are open a background click and
## Enter start nothing; Done closes them and refreshes the coin line.
func test_the_toy_machines_open_over_the_title() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 2
	profile.run_count = 3
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	assert_str(title._coins.text).is_equal("Coins: 2")
	title._toys_button.pressed.emit()
	await _frames(2)
	assert_bool(title.toy_machines_open()).is_true()
	var toys: ToyMachinesScreen = title._toys
	assert_str(toys.coins_label().text).is_equal("2")
	title._on_background_input(_left_click())
	title._unhandled_key_input(_key(KEY_ENTER))
	title._unhandled_key_input(_key(KEY_SPACE))
	assert_bool(title._starting).is_false()
	toys.machines()[0]._gui_input(_left_click())
	assert_int(SaveService.new(_folder).load_profile().coins).is_equal(1)
	# No run is saved: the item rides the next runs, from the ended runs' index.
	assert_int(SaveService.new(_folder).load_profile().unlocked_items[&"cream"]).is_equal(2)
	assert_str(toys.reveal().stock_label().text).is_equal(CapsuleCounter.NEXT_RUN_LINE)
	assert_str(_last_event("capsule")["run_id"]).is_empty()
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	toys.reveal().dismiss()
	toys.done_button().pressed.emit()
	assert_bool(title.toy_machines_open()).is_false()
	assert_str(title._coins.text).is_equal("Coins: 1")
	# Closed again: a background click starts.
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_true()


## A real click on the toy machine prop opens the machines and starts no run; a click in the gap
## between the prop and the button starts nothing either.
func test_a_click_on_the_toy_machine_prop_opens_the_machines() -> void:
	# The window at the game's size, so the simulated mouse lands where the rects say.
	var window: Vector2i = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	await _click_the_toy_machine_prop()
	get_tree().root.size = window


func _click_the_toy_machine_prop() -> void:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	await _frames(4)
	var prop: Rect2 = title._toys_prop.get_global_rect()
	var button: Rect2 = title._toys_button.get_global_rect()
	runner.set_mouse_position(Vector2(prop.get_center().x, (prop.end.y + button.position.y) / 2.0))
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _frames(2)
	assert_bool(title._starting).is_false()
	assert_bool(title.toy_machines_open()).is_false()
	runner.set_mouse_position(prop.get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _frames(2)
	assert_bool(title._starting).is_false()
	assert_bool(title.toy_machines_open()).is_true()
	assert_int(title._toys_prop.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)


## With a run saved, a title draw gets that run's index and the saved-run stock line.
func test_a_title_draw_with_a_saved_run_rides_after_it() -> void:
	_save_run_at_shift(2)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 1
	profile.run_count = 4
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	title._toys_button.pressed.emit()
	await _frames(2)
	title._toys.machines()[1]._gui_input(_left_click())
	assert_int(SaveService.new(_folder).load_profile().unlocked_items[&"sugar_cubes"]).is_equal(4)
	assert_str(title._toys.reveal().stock_label().text).is_equal(
		CapsuleCounter.AFTER_SAVED_RUN_LINE
	)
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_false()


## An unreadable profile opens the machines switched off and leaves the file as it is.
func test_an_unreadable_profile_opens_the_machines_switched_off() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var path: String = SaveService.new(_folder).profile_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var title: TitleScreen = await _title()
	title._toys_button.pressed.emit()
	await _frames(2)
	for machine: ToyMachineView in title._toys.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
	assert_str(title._toys.coins_label().text).is_equal("?")
	assert_str(FileAccess.get_file_as_string(path)).is_equal("{broken")


static func _labels(root: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in root.find_children("*", "Label", true, false):
		found.append(child as Label)
	return found


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
