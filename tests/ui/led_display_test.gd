extends GdUnitTestSuite
## The register's reading (#55; a model since #105 piece 2, LedDisplay): its mode per phase
## (blank, PROJECTED, SUBTOTAL, TOTAL), the amount, quota and met state it says through
## reading_changed (which the monitor's checkout column and the top bar's gauge both follow). On
## the real screen it draws nothing, stays blank in planning and reads core's ScoreResult total at
## a checkout's end, and the checkout column and the top bar show that same number. The real saves
## and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_led_display_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Blank, then PROJECTED (met once it reaches the quota), SUBTOTAL from 0 and not met, the
## running totals, TOTAL over the amount shown, and blank again; every mode set
## says mode_changed (even the same one) and every amount says reading_changed.
func test_the_mode_and_reading_follow_the_phase() -> void:
	var led: LedDisplay = auto_free(LedDisplay.new())
	var modes: Array[LedDisplay.Mode] = []
	var readings: Array[Array] = []
	led.mode_changed.connect(func(mode: LedDisplay.Mode) -> void: modes.append(mode))
	led.reading_changed.connect(
		func(amount: int, quota: int, met: bool) -> void: readings.append([amount, quota, met])
	)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_bool(led.is_counting()).is_false()
	led.show_projected(30, 34)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.PROJECTED)
	assert_bool(led.is_met()).is_false()
	led.show_projected(34, 34)
	assert_bool(led.is_met()).is_true()
	led.start_count(50)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.SUBTOTAL)
	assert_bool(led.is_counting()).is_true()
	assert_int(led.amount()).is_equal(0)
	assert_bool(led.is_met()).is_false()
	led.show_subtotal(12, false)
	led.show_subtotal(61, true)
	assert_int(led.amount()).is_equal(61)
	assert_int(led.quota()).is_equal(50)
	led.show_total()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.TOTAL)
	assert_int(led.amount()).is_equal(61)
	led.show_total()
	led.clear()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_int(led.amount()).is_equal(0)
	assert_bool(led.is_met()).is_false()
	(
		assert_array(modes)
		. is_equal(
			[
				LedDisplay.Mode.PROJECTED,
				LedDisplay.Mode.PROJECTED,
				LedDisplay.Mode.SUBTOTAL,
				LedDisplay.Mode.TOTAL,
				LedDisplay.Mode.TOTAL,
				LedDisplay.Mode.BLANK,
			]
		)
	)
	var expected: Array[Array] = [
		[30, 34, false], [34, 34, true], [0, 50, false], [12, 50, false], [61, 50, true]
	]
	assert_array(readings).is_equal(expected)


## On the real screen the reading is the monitor's model (no drawn node): blank in planning as
## cards are placed, and a checkout's end state reads core's total, TOTAL and met, which the
## checkout column's number and the top bar's gauge show too.
func test_the_screen_reads_core_totals() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	var led: LedDisplay = screen._led
	var model: Object = led
	assert_bool(model is CanvasItem).is_false()
	var run: RunState = screen.run
	for id: String in ["milk", "bread", "milk"]:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % id))
		assert_bool(run.place(card, run.row.size())).is_true()
		screen._refresh()
		assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	var result: ScoreResult = run.preview()
	screen._count_up.show_end_state(result, 1, screen.count_up_context())
	await _frames(2)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.TOTAL)
	assert_int(led.amount()).is_equal(result.total)
	assert_int(screen._stage.monitor.checkout().total_number().value()).is_equal(result.total)
	assert_str(screen._quota_meter.shown_text()).contains("%d" % result.total)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
