extends GdUnitTestSuite
## The cart reveal on the real shift screen (v0.51): who opens it (the title's request for the new
## run of the screen it opens, the results' New run, the debug panel's new run with a seed; never a
## resumed run, nor a screen opened another way), that it shows the run as dealt and saved, that
## it sits over the screen under the top bar with the Cart button clear for its fold, and that a
## run started without it closes it.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	# A request no screen took must not reach another suite's screen.
	CartReveal._request = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_screen_opened_without_a_request_starts_without_it() -> void:
	var screen: ShiftScreen = await _screen()
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_bool(screen._cart_reveal.requested).is_false()


## The title's New run: the new run opens on the reveal, already dealt and saved, showing its
## staples and picks; the request is used up.
func test_the_titles_request_opens_it_on_the_new_run() -> void:
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	var reveal: CartReveal = screen._cart_reveal
	assert_bool(reveal.is_open()).is_true()
	# The machine's notice waits for the reveal to fold (it would pulse under the dim).
	assert_bool(screen._machine._notice_due).is_false()
	assert_bool(CartReveal._request).is_false()
	var panel: RevealPanel = reveal.panel()
	assert_array(panel.staples).is_equal(screen.run.starter.core_cards)
	assert_array(panel.picks).is_equal(StartingDeck.picks(screen.run.starter))
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE))).is_true()
	# Over the deck view and the machine: the screen's last child but the debug panel.
	assert_int(reveal.get_index()).is_greater(screen._deck_view.get_index())


## A resumed run never shows it, and drops the title's request.
func test_a_resumed_run_drops_the_request() -> void:
	var first: ShiftScreen = await _screen()
	var seed_value: int = first.run.run_seed
	first.queue_free()
	await get_tree().process_frame
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	assert_int(screen.run.run_seed).is_equal(seed_value)
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_bool(CartReveal._request).is_false()


func test_the_results_and_the_debug_new_runs_open_it() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_new_run_pressed()
	assert_bool(screen._cart_reveal.is_open()).is_true()
	screen._cart_reveal.close()
	screen._debug.replay_seed(42)
	assert_bool(screen._cart_reveal.is_open()).is_true()
	assert_int(screen.run.run_seed).is_equal(42)
	# A run started without it (a demo row, a test's seed) closes it.
	screen.start_new_run(43)
	assert_bool(screen._cart_reveal.is_open()).is_false()


## On screen at 1280x720: the panel inside the stage under the top bar, the dim from the top
## bar's bottom, the Cart button above the panel (clear for the fold's ring), and the fold ends
## with shift 1's planning as it was.
func test_it_sits_under_the_top_bar_and_folds_into_the_cart() -> void:
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	var reveal: CartReveal = screen._cart_reveal
	reveal.set_process(false)
	reveal.freeze_at(reveal.end_time())
	await get_tree().process_frame
	var stage: Rect2 = screen._stage.get_global_rect()
	var panel: Rect2 = reveal.panel().get_global_rect()
	assert_bool(stage.encloses(panel)).is_true()
	assert_float(panel.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	assert_bool(reveal.get_global_rect().encloses(screen.get_global_rect())).is_true()
	var cart: Rect2 = screen._deck_button.get_global_rect()
	assert_float(cart.end.y + CartReveal.RING_GAP + CartReveal.RING_WIDTH).is_less(panel.position.y)
	assert_bool(stage.encloses(cart.grow(CartReveal.RING_GAP + CartReveal.RING_WIDTH))).is_true()
	var hand: Array[CardInstance] = screen.run.hand()
	reveal.freeze_at(reveal.end_time())
	reveal.tap()
	var folding_ms: int = Time.get_ticks_msec()
	reveal.advance(reveal.tuning.outro_s + 0.1)
	assert_bool(reveal.is_open()).is_false()
	# Shift 1's time to checkout starts once the reveal is gone (plan section 8).
	assert_int(screen.tracker._start_ms).is_greater_equal(folding_ms)
	assert_bool(screen._machine._notice_due).is_true()
	assert_array(screen.run.hand()).is_equal(hand)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(screen.run.row).is_empty()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for _frame: int in range(2):
		await get_tree().process_frame
	return screen


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
