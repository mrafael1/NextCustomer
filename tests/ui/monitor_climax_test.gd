extends GdUnitTestSuite
## SPEND MET's climax on the real shift screen (#105 piece 2, mock-up readability_v3.html,
## monitor b; MonitorClimax), on the reference row of shift 1 (its quota, 29, met mid-row):
## - it starts on the ding beat's crossing tick and takes the monitor's whole paper, inside the
##   screen's ink border, on every frame: the 84 px number (growing past full size and settling,
##   then shrinking toward the checkout column's number), the stamp and the tab all on the paper;
## - it lasts climax_hold_s + climax_out_s of real time, through the ding's hold, and leaves the
##   checkout column reading "+N€ over";
## - a tap cuts it short; under reduced motion it cuts in and out still (no grow, no turn, no
##   coins) after climax_hold_s;
## - a resumed checkout shows the met end (the stamp and the "+N€" tab) with no climax.
## The saves and logs go to a temporary folder only.

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


## See the suite comment: untouched, normal motion.
func test_the_climax_takes_the_paper_then_shrinks_back() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, false)
	var failures: Array[String] = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 12))).is_empty()
	var tuning: CountTotalTuning = screen._count_up.total_tuning()
	var plan: CountUpPlan = screen._count_up.plan
	assert_int(plan.ding_beat).is_greater_equal(0)
	var ding: CountUpBeat = plan.beats[plan.ding_beat]
	# It started at the crossing tick's reading.
	assert_int(int(probe["start_reading"])).is_equal(ding.ticks[ding.ding_tick])
	assert_int(int(probe["start_reading"])).is_greater_equal(screen.run.quota())
	# It grew past full size and settled, shrank toward the column's number at its end.
	assert_float(float(probe["peak_scale"])).is_greater(1.1)
	assert_float(float(probe["peak_scale"])).is_less_equal(tuning.climax_over + 0.01)
	assert_float(float(probe["end_scale"])).is_less(0.6)
	var paper_centre: Vector2 = _on_stage(screen, MonitorView.PAPER_RECT).get_center()
	var column_centre: Vector2 = screen._monitor.checkout().number_centre()
	var end_centre: Vector2 = probe["end_centre"]
	assert_float(end_centre.distance_to(column_centre)).is_less(
		end_centre.distance_to(paper_centre)
	)
	assert_bool(probe["stamp_seen"]).is_true()
	assert_bool(probe["tab_seen"]).is_true()
	assert_bool(probe["coins_seen"]).is_true()
	# Real time, through the ding's hold.
	var planned_ms: float = (tuning.climax_hold_s + tuning.climax_out_s) * 1000.0
	assert_float(float(probe["took_ms"])).is_between(planned_ms * 0.95, planned_ms * 1.25)
	# Then the column reads "+N€ over" (the count goes on past the quota).
	assert_str(String(probe["status_after"])).starts_with("+")
	assert_str(String(probe["status_after"])).ends_with("over")


## A tap as the climax starts speeds it with the count: it ends in well under its planned time.
func test_a_tap_cuts_the_climax_short() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, true)
	var tuning: CountTotalTuning = screen._count_up.total_tuning()
	var planned_ms: float = (tuning.climax_hold_s + tuning.climax_out_s) * 1000.0
	assert_float(float(probe["took_ms"])).is_less(planned_ms * 0.5)


## Reduced motion: the climax cuts in still (scale 1 on every frame, no turn, no coins, the stamp
## and the tab in at once) and cuts out after climax_hold_s, on the paper.
func test_reduced_motion_cuts_the_climax_in_and_out_still() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _full_row(screen)
	var probe: Dictionary = await _watch(screen, false)
	var failures: Array[String] = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 12))).is_empty()
	assert_bool(probe["still"]).is_true()
	assert_float(float(probe["peak_scale"])).is_equal(1.0)
	assert_float(float(probe["low_scale"])).is_equal(1.0)
	assert_bool(probe["turned"]).is_false()
	assert_bool(probe["coins_seen"]).is_false()
	assert_bool(probe["stamp_at_start"]).is_true()
	var tuning: CountTotalTuning = screen._count_up.total_tuning()
	var planned_ms: float = tuning.climax_hold_s * 1000.0
	assert_float(float(probe["took_ms"])).is_between(planned_ms * 0.95, planned_ms * 1.25)


## A resumed checkout (the screen's own two calls): the met end, the stamp and the tab on the
## paper, every gain landing's lamp lit, and no climax.
func test_a_resumed_checkout_shows_the_met_end_without_the_climax() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	var quota: int = screen.run.quota()
	screen._count_up.show_end_state(result, quota, screen.count_up_context())
	screen._monitor.show_end_state(screen._count_up.plan, screen._row_views)
	await _frames(2)
	var monitor: MonitorView = screen._monitor
	var column: CheckoutColumn = monitor.checkout()
	assert_bool(monitor.climax().is_running()).is_false()
	assert_bool(monitor.climax().visible).is_false()
	assert_int(column.total_number().value()).is_equal(result.total)
	assert_bool(column.stamp().is_visible_in_tree()).is_true()
	assert_bool(column.tab().is_visible_in_tree()).is_true()
	assert_str(column.tab().text).is_equal(MonitorText.over_tab(result.total, quota))
	assert_int(column.lit_lamps()).is_equal(screen._count_up.plan.lamp_count)
	var paper: Rect2 = _on_stage(screen, MonitorView.PAPER_RECT)
	for part: Control in [column.stamp(), column.tab()]:
		assert_bool(paper.encloses(MonitorKit.drawn_rect(part))).is_true()


# --- Helpers ---------------------------------------------------------------------------------


## Presses CHECKOUT (tapping as the climax starts when `tap`) and watches the climax on every
## frame until it ends. Returns {"failures", "start_reading", "peak_scale", "low_scale",
## "end_scale", "end_centre", "stamp_seen", "tab_seen", "stamp_at_start", "coins_seen", "turned",
## "still", "took_ms", "status_after"}.
func _watch(screen: ShiftScreen, tap: bool) -> Dictionary:
	var count_up: CountUp = screen._count_up
	var monitor: MonitorView = screen._monitor
	var climax: MonitorClimax = monitor.climax()
	var paper: Rect2 = _on_stage(screen, MonitorView.PAPER_RECT)
	var screen_rect: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT)
	var failures: Array[String] = []
	var started: Array[int] = []
	var start_reading: Array[int] = []
	count_up.quota_met.connect(
		func(pop: bool) -> void:
			if not pop or not started.is_empty():
				return
			started.append(Time.get_ticks_msec())
			start_reading.append(screen._led.amount())
			if tap:
				count_up._tap(Time.get_ticks_msec())
	)
	screen._on_checkout_pressed()
	while started.is_empty() and screen._counting:
		await get_tree().process_frame
	assert_bool(started.is_empty()).override_failure_message("no climax").is_false()
	assert_bool(climax.is_running()).is_true()
	var probe: Dictionary = {
		"peak_scale": 0.0,
		"low_scale": 9.0,
		"end_scale": 1.0,
		"end_centre": Vector2.ZERO,
		"stamp_seen": false,
		"tab_seen": false,
		"stamp_at_start": climax.stamp().visible,
		"coins_seen": false,
		"turned": false,
		"still": climax.is_still(),
	}
	var angle: float = climax.sunburst().angle()
	var frame: int = 0
	while climax.is_running():
		frame += 1
		var where: String = "frame %d (%.2f s)" % [frame, climax.progress()]
		var front: Control = climax._front
		probe["peak_scale"] = maxf(float(probe["peak_scale"]), front.scale.x)
		probe["low_scale"] = minf(float(probe["low_scale"]), front.scale.x)
		probe["end_scale"] = front.scale.x
		var number: Rect2 = climax.number().drawn_rect()
		probe["end_centre"] = number.get_center()
		if climax.get_global_rect() != paper or not screen_rect.encloses(paper):
			failures.append(
				"%s: the climax %s, the paper %s" % [where, climax.get_global_rect(), paper]
			)
		if not climax.clip_contents:
			failures.append("%s: the climax does not clip" % where)
		if not paper.grow(0.5).encloses(number):
			failures.append("%s: the number %s off the paper" % [where, number])
		for part: Control in [climax.stamp(), climax.tab()]:
			if part.is_visible_in_tree():
				var rect: Rect2 = MonitorKit.drawn_rect(part)
				if not paper.grow(0.5).encloses(rect):
					failures.append("%s: %s %s off the paper" % [where, part.name, rect])
		probe["stamp_seen"] = bool(probe["stamp_seen"]) or climax.stamp().is_visible_in_tree()
		probe["tab_seen"] = bool(probe["tab_seen"]) or climax.tab().is_visible_in_tree()
		probe["turned"] = bool(probe["turned"]) or climax.sunburst().angle() != angle
		probe["coins_seen"] = bool(probe["coins_seen"]) or _coins_now(climax)
		await get_tree().process_frame
	probe["took_ms"] = Time.get_ticks_msec() - started[0]
	probe["start_reading"] = start_reading[0]
	await get_tree().process_frame
	probe["status_after"] = monitor.checkout().status_label().text
	probe["failures"] = failures
	while screen._counting:
		await get_tree().process_frame
	return probe


## Whether any of the climax's coins is up now (the age window of at least one).
static func _coins_now(climax: MonitorClimax) -> bool:
	if climax.is_still():
		return false
	var q: float = climax.progress()
	for index: int in range(MonitorClimax.COIN_WAVE):
		var age: float = q - MonitorClimax.COIN_START_S - index * MonitorClimax.COIN_DELAY_S
		if age >= 0.0 and age <= MonitorClimax.COIN_LIFE_S:
			return true
	return false


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
