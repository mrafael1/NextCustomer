extends GdUnitTestSuite
## The debug panel's Profile tools (#63, ShiftDebug): Give 1 / 5 coins, Draw from machine (the
## real draw, the key item first, no coin spent), Unlock all and Reset collection each change the
## profile and its saved file at once; the panel, Profile section included, fits a 1280x720
## window. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_each_profile_tool_changes_the_profile_and_its_file() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var panel: Control = screen._debug.panel
	assert_object(panel).is_not_null()
	panel.emit_signal(&"coins_requested", 1)
	panel.emit_signal(&"coins_requested", 5)
	assert_int(screen.profile.coins).is_equal(6)
	assert_int(_saved().coins).is_equal(6)
	panel.emit_signal(&"capsule_requested", "fruit_and_veg")
	assert_int(screen.profile.unlocked_items.get(&"fruit_salad", -9)).is_equal(0)
	assert_int(screen.profile.coins).is_equal(6)
	assert_bool(_saved().unlocked_items.has(&"fruit_salad")).is_true()
	assert_bool(_saved().has_capsule_seed).is_true()
	assert_str(_last_event("capsule")["item"]).is_equal("fruit_salad")
	panel.emit_signal(&"unlock_all_requested")
	assert_int(screen.profile.owned_capsules(screen._balance)).is_equal(30)
	assert_int(_saved().owned_capsules(screen._balance)).is_equal(30)
	# Every machine empty: the draw gives nothing.
	panel.emit_signal(&"capsule_requested", "bakery")
	assert_int(screen.profile.unlocked_items.size()).is_equal(30)
	panel.emit_signal(&"reset_collection_requested")
	assert_dict(screen.profile.unlocked_items).is_empty()
	assert_dict(_saved().unlocked_items).is_empty()
	assert_bool(_saved().has_capsule_seed).is_true()
	var actions: Array = []
	for event: Dictionary in _events("debug"):
		actions.append(event["action"])
	assert_array(actions).is_equal(["coins", "coins", "capsule", "unlock_all", "reset_collection"])


## During a run a debug draw comes out at the run's own index; once it has ended (record_run has
## counted it) at the ended run's, as a results draw, so the item rides the next run.
func test_a_debug_draw_uses_the_ended_runs_index_once_the_run_is_over() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var panel: Control = screen._debug.panel
	screen.profile.run_count = 3
	panel.emit_signal(&"capsule_requested", "fruit_and_veg")
	assert_int(screen.profile.unlocked_items.get(&"fruit_salad", -9)).is_equal(3)
	screen.run.phase = RunState.Phase.LOST
	panel.emit_signal(&"capsule_requested", "bakery")
	var bakery: AisleDefinition = load("res://data/aisles/bakery.tres")
	assert_int(screen.profile.unlocked_items.get(bakery.capsule_cards[0].id, -9)).is_equal(2)
	panel.emit_signal(&"reset_collection_requested")
	panel.emit_signal(&"unlock_all_requested")
	assert_int(screen.profile.unlocked_items.get(&"fruit_salad", -9)).is_equal(2)


func test_the_panel_fits_the_window() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var panel: Control = screen._debug.panel
	panel.visible = true
	for _frame: int in range(3):
		await await_idle_frame()
	var view: Rect2 = panel.get_viewport_rect()
	assert_vector(view.size).is_equal(Vector2(1280, 720))
	var rect: Rect2 = panel.get_global_rect()
	assert_bool(view.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_float(rect.size.y).is_greater(100.0)


func _saved() -> ProfileState:
	return SaveService.new(_folder).peek_profile()


func _events(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event["type"] == type:
			found.append(event)
	return found


func _last_event(type: String) -> Dictionary:
	var found: Array[Dictionary] = _events(type)
	return found[-1] if not found.is_empty() else {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
