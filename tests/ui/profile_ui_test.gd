extends GdUnitTestSuite
## The profile on the real shift screen (full build plan section 4): loaded from the save
## folder at start, recorded and saved when a run ends, untouched by a run restarted before
## its end.

const SCREEN := "res://ui/shift_screen.tscn"
const REPEAT := "res://data/cards/repeat.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_an_ended_run_is_saved_to_the_profile_and_a_restart_is_not() -> void:
	var saves: SaveService = SaveService.new(_folder)
	var saved: ProfileState = ProfileState.new()
	saved.run_count = 3
	saved.coupon_uses[&"repeat"] = 1
	saves.save_profile(saved)
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_int(screen.profile.run_count).is_equal(3)
	# A new run before this one ends (the debug seed) records nothing.
	screen.start_new_run(5)
	assert_int(saves.load_profile().run_count).is_equal(3)
	# A Repeat alone pays 0: the run is lost, recorded and saved at the click.
	screen.run.place(screen.run.debug_add_to_hand(load(REPEAT)), 0)
	# Saved at the click, before the count-up: closing the game during it loses nothing.
	screen._on_checkout_pressed()
	assert_bool(screen._counting).is_true()
	assert_int(saves.load_profile().run_count).is_equal(4)
	while screen._counting:
		await get_tree().process_frame
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	var read: ProfileState = saves.load_profile()
	assert_int(read.run_count).is_equal(4)
	assert_dict(read.coupon_uses).is_equal({&"repeat": 2})
	assert_int(screen.profile.run_count).is_equal(4)


func test_without_a_save_the_screen_starts_a_fresh_profile() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_int(screen.profile.run_count).is_equal(0)
	assert_bool(FileAccess.file_exists(_folder.path_join(SaveService.PROFILE_FILE))).is_false()


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
