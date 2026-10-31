extends GdUnitTestSuite
## The TOY MACHINES from the results (#63) on the real shift screen: after a run ends, "Toy
## machines ›" opens the machines over the results (below the debug panel); a draw changes the
## screen's profile and the saved file at the ended run's index; Done returns to the results as
## they were; New run then stocks the drawn item. When the run's profile save failed, the
## machines open switched off. Saves and logs go to a temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_entry_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_the_results_open_the_machines_and_new_run_stocks_the_draw() -> void:
	var screen: ShiftScreen = await _ended_run(true)
	var results: ResultsPanel = screen._results
	results.toy_machines_requested.emit()
	await _frames(3)
	var toys: ToyMachinesScreen = screen._toys
	assert_bool(toys.visible).is_true()
	assert_int(toys.get_index()).is_greater(results.get_index())
	if screen._debug.panel != null:
		assert_int(toys.get_index()).is_less(screen._debug.panel.get_index())
	var cold: ToyMachineView = toys.machines()[0]
	(
		assert_bool(Kit.SCREEN_RECT.encloses(Rect2(cold.global_position, ToyMachineView.SIZE)))
		. is_true()
	)
	cold._gui_input(Kit.left_click())
	assert_int(screen.profile.unlocked_items[&"cream"]).is_equal(0)
	assert_int(screen.profile.coins).is_equal(1)
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.unlocked_items[&"cream"]).is_equal(0)
	var event: Dictionary = Kit.events(_folder, "capsule")[-1]
	assert_str(event["run_id"]).is_equal(Kit.event_log().run_id)
	assert_str(event["run_id"]).is_not_empty()
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	toys.reveal().dismiss()
	toys.done_button().pressed.emit()
	assert_bool(toys.visible).is_false()
	assert_bool(results.visible).is_true()
	screen._on_new_run_pressed()
	assert_bool(screen.run.stock.card_ids().has("cream")).is_true()


func test_a_failed_profile_save_opens_the_machines_switched_off() -> void:
	var screen: ShiftScreen = await _ended_run(false)
	screen._results.toy_machines_requested.emit()
	await _frames(2)
	for machine: ToyMachineView in screen._toys.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
	assert_int(screen._toys.strip_kind()).is_equal(ToyMachinesScreen.Strip.OFF)


## A shift screen whose run just ended, its results up: the profile has 2 coins after 1 run,
## saved (or, without `profile_saved`, as when the run's profile save failed).
func _ended_run(profile_saved: bool) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	screen.profile.coins = 2
	screen.profile.run_count = 1
	screen._profile_saved = profile_saved
	assert_bool(SaveService.new(_folder).save_profile(screen.profile)).is_true()
	screen.run.phase = RunState.Phase.LOST
	var result: ScoreResult = ScoreResult.new()
	screen._show_results(result)
	screen._results.skip_printing()
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
