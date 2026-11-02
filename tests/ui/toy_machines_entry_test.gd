extends GdUnitTestSuite
## The TOY MACHINES after a run (#63), now reached through the title: the results' Return to
## menu logs results_exit and asks for the title with its sign lit; the title made next opens
## lit (no intro), REWARDS > TOY MACHINES draws on the saved profile at the ended run's index,
## and the next run's shift screen stocks the drawn item. The scene is never changed (the
## screens' changes_scene seams). Saves and logs go to a temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const TITLE := "res://ui/title_screen.tscn"

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_entry_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)
	TitleScreen.take_lit_request()


func after_test() -> void:
	TitleScreen.take_lit_request()
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


## Return to menu logs results_exit (the time since the run's end, from the results) under the
## ended run's id and requests the title lit, without changing the scene here.
func test_return_to_menu_logs_results_exit_and_requests_the_title_lit() -> void:
	var screen: ShiftScreen = await _ended_run()
	var run_id: String = Kit.event_log().run_id
	screen._run_ended_ms = Time.get_ticks_msec() - 500
	screen._results.menu_requested.emit()
	var event: Dictionary = Kit.events(_folder, "results_exit")[-1]
	assert_str(event["screen"]).is_equal("results")
	assert_int(int(event["since_run_end_ms"])).is_between(500, 5000)
	assert_str(event["run_id"]).is_equal(run_id)
	assert_array(Kit.events(_folder, "restart")).is_empty()
	assert_bool(screen.is_inside_tree()).is_true()
	assert_bool(TitleScreen.take_lit_request()).is_true()
	assert_bool(TitleScreen.take_lit_request()).is_false()


## The title made after Return to menu opens lit; its TOY MACHINES draw at the ended run's index
## (no run saved: a run's end deletes its save) and the next run's shift screen stocks the item.
func test_the_title_after_the_results_draws_and_the_next_run_stocks_it() -> void:
	var screen: ShiftScreen = await _ended_run()
	screen._results.menu_requested.emit()
	assert_bool(SaveService.new(_folder).delete_run()).is_true()
	var title: TitleScreen = scene_runner(TITLE).scene() as TitleScreen
	title.changes_scene = false
	await _frames(3)
	assert_bool(title.is_intro_playing()).is_false()
	assert_bool(title.storefront().is_lit()).is_true()
	assert_bool(TitleScreen.take_lit_request()).is_false()
	title._on_toy_machines_pressed()
	await _frames(3)
	assert_bool(title.toy_machines_open()).is_true()
	title._toys.machines()[0]._gui_input(Kit.left_click())
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.coins).is_equal(1)
	assert_int(saved.unlocked_items[&"cream"]).is_equal(0)
	var next: ShiftScreen = scene_runner(SCREEN).scene() as ShiftScreen
	await _frames(2)
	assert_bool(next.run.stock.card_ids().has("cream")).is_true()


## A shift screen whose run just ended, its results up and its scene change off: the profile
## has 2 coins after 1 run, saved.
func _ended_run() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.changes_scene = false
	await _frames(2)
	screen.profile.coins = 2
	screen.profile.run_count = 1
	assert_bool(SaveService.new(_folder).save_profile(screen.profile)).is_true()
	screen.run.phase = RunState.Phase.LOST
	screen._show_results(ScoreResult.new())
	screen._results.skip_printing()
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
