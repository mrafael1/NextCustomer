extends GdUnitTestSuite
## V3 celebrates quota on the register while retaining the monitor's explanation. Normal,
## tapped and reduced-motion playback use real time through the count's quota hold. A resumed
## checkout shows the final reading quietly. Saves and logs use a temporary folder.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_climax_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_register_celebrates_without_covering_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, false)
	var plan: CountUpPlan = screen._count_up.plan
	var ding: CountUpBeat = plan.beats[plan.ding_beat]
	assert_int(probe["start_reading"]).is_equal(ding.shown_to)
	assert_int(probe["took_ms"]).is_between(800, 1100)
	assert_int(probe["frames"]).is_greater(2)


func test_a_tap_speeds_up_the_register_celebration() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, true)
	assert_int(probe["took_ms"]).is_less(425)


func test_reduced_motion_holds_a_still_spend_met_label() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, false)
	assert_int(probe["took_ms"]).is_between(800, 1100)
	assert_int(probe["frames"]).is_greater(2)


func test_a_resumed_checkout_shows_the_total_without_celebrating() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	screen._count_up.show_end_state(result, screen.run.quota(), screen.count_up_context())
	screen._monitor.show_end_state(
		screen._count_up.plan, screen._row_views, false, result, screen._scan.line_of
	)
	await _frames(2)
	assert_int(screen._register.total_display.amount()).is_equal(result.total)
	assert_bool(screen._register.total_display.is_celebrating()).is_false()
	assert_bool(screen._monitor.checkout().is_visible_in_tree()).is_false()
	assert_bool(screen._monitor.climax().is_running()).is_false()
	assert_int(screen._monitor.item_column().shown_value()).is_equal(result.payouts[-1])


func _watch(screen: ShiftScreen, tap: bool) -> Dictionary:
	var count_up: CountUp = screen._count_up
	var display: RegisterTotal = screen._register.total_display
	var started: Array[int] = []
	var readings: Array[int] = []
	count_up.quota_met.connect(
		func(pop: bool) -> void:
			if not pop:
				return
			started.append(Time.get_ticks_msec())
			readings.append(screen._led.amount())
			if tap:
				count_up._tap(Time.get_ticks_msec())
	)
	screen._on_checkout_pressed()
	while started.is_empty() and screen._counting:
		await get_tree().process_frame
	assert_array(started).is_not_empty()
	assert_bool(display.is_celebrating()).is_true()
	var frames: int = 0
	while display.is_celebrating():
		frames += 1
		assert_bool(screen._monitor.climax().is_running()).is_false()
		assert_bool(screen._monitor.item_column().is_visible_in_tree()).is_true()
		assert_int(display.amount()).is_equal(readings[0])
		await get_tree().process_frame
	var took_ms: int = Time.get_ticks_msec() - started[0]
	count_up._tap(Time.get_ticks_msec())
	count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	return {"start_reading": readings[0], "took_ms": took_ms, "frames": frames}


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	for id: String in FULL_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(FULL_ROW.size())
	await _frames(3)


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
