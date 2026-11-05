extends GdUnitTestSuite
## The opening board draws three stocked aisles on its named stream and leaves last_list
## untouched. Replaying the seed keeps the stock; a new profile stocks its three base aisles.

const SCREEN := "res://ui/shift_screen.tscn"

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


func test_the_opening_board_stocks_its_seeded_three_aisles() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 3
	profile.unlocked_items = {&"cream": 0, &"sugar_cubes": 1, &"egg_timer": 2}
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var balance: BalanceDefinition = screen._balance
	var seed_value: int = screen.run.run_seed
	var drawn: Array[StringName] = StartSetupRules.suggest_aisles(
		balance,
		profile,
		EventLogService.derived_stream(seed_value, EventLogService.STOCK_AISLES_STREAM)
	)
	var expected: Array[StringName] = []
	for aisle: AisleDefinition in balance.aisles:
		if drawn.has(aisle.id):
			expected.append(aisle.id)
	assert_int(expected.size()).is_equal(balance.stock_aisle_count)
	assert_array(screen.run.start_setup.stock_aisles).is_equal(drawn)
	assert_array(screen.run.stock.aisle_ids).is_equal(expected)
	assert_bool(screen.run.stock.list_skipped).is_false()
	assert_array(screen.profile.last_list).is_empty()
	var logged: Dictionary = _last_event("run_start")
	assert_array(logged["listed_aisles"]).is_equal(expected.map(_text))
	# The debug panel's replay of the same seed gives the same list.
	screen._debug.replay_seed(seed_value)
	assert_array(screen.run.stock.aisle_ids).is_equal(expected)
	assert_array(screen.profile.last_list).is_empty()
	assert_array(SaveService.new(_folder).load_profile().last_list).is_empty()


func test_a_fresh_profile_stocks_every_base_aisle() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_bool(screen.run.stock.list_skipped).is_false()
	assert_array(screen.run.stock.aisle_ids).is_equal([&"cold_cases", &"pantry", &"household"])
	assert_array(screen.profile.last_list).is_empty()


func _last_event(type: String) -> Dictionary:
	var found: Dictionary = {}
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event["type"] == type:
			found = event
	return found


static func _text(id: StringName) -> String:
	return String(id)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
