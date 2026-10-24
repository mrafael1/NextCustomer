extends GdUnitTestSuite
## The count-up's landings on the real shift screen (the monitor juice, mock-up
## monitor_juice_v2.html; CountUp.payout_landed and total_landed): every paid beat lands once, at
## the end of its roll, with its payout and the subtotal then shown; the landing that meets the
## quota comes just before quota_met, in the same frame, and the gold's target goes over the brim
## in that frame (held under it at the landing itself); the TOTAL lands once, after every payout;
## the digits' punch never passes digits_punch_max. The same holds untouched, tapped (TAP_SKIP),
## held (FAST_FORWARD) and when the last payout meets the quota with the TOTAL (chip_at_total).
## The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## Milk, Multipack, Milk x5 = 109.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const TOTAL := 109
## Met mid-row (a ding beat).
const MID_QUOTA := 40
## The longest a count may take here (real time) before the test fails instead of hanging.
const MAX_WAIT_MS := 60000

var _folder: String = ""
var _runner: GdUnitSceneRunner
## What the count emitted, in order: [name, frame, payout, subtotal, the tank's target, the
## shown subtotal].
var _events: Array[Array] = []
var _peak: float = 1.0


func before_test() -> void:
	_folder = "user://test_count_up_landing_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_events.clear()
	_peak = 1.0


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Untouched: the landings, the win in the ding beat's landing frame, the TOTAL after them.
func test_the_landings_untouched() -> void:
	var screen: ShiftScreen = await _screen()
	_play(screen, MID_QUOTA)
	await _until_played(screen)
	_assert_landings(screen, MID_QUOTA, false)


## Tapped (the count at TAP_SKIP): the same landings, in the same order.
func test_the_landings_tapped() -> void:
	var screen: ShiftScreen = await _screen()
	_play(screen, MID_QUOTA)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	await _until_played(screen)
	assert_bool(screen._count_up._tapped).is_true()
	_assert_landings(screen, MID_QUOTA, false)


## Held (the count at FAST_FORWARD): the same landings, in the same order.
func test_the_landings_held() -> void:
	var screen: ShiftScreen = await _screen()
	_play(screen, MID_QUOTA)
	await _frames(2)
	_runner.simulate_key_press(KEY_SPACE)
	await _until_played(screen)
	_runner.simulate_key_release(KEY_SPACE)
	assert_bool(screen._count_up.fast_forward_used).is_true()
	_assert_landings(screen, MID_QUOTA, false)


## The last payout meets the quota (chip_at_total): no ding beat; the quota is met with the TOTAL,
## in its frame, just before total_landed, the gold over the brim there.
func test_the_landings_with_the_win_at_the_total() -> void:
	var screen: ShiftScreen = await _screen()
	_play(screen, TOTAL)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	await _until_played(screen)
	assert_bool(screen._count_up.plan.chip_at_total).is_true()
	_assert_landings(screen, TOTAL, true)


## Checks the recorded events against the plan for `quota` (see the class comment); `at_total`:
## the quota is met with the TOTAL.
func _assert_landings(screen: ShiftScreen, quota: int, at_total: bool) -> void:
	var plan: CountUpPlan = screen._count_up.plan
	var tune: CountUpTuning = screen._count_up._tuning
	var expected: Array[Array] = []
	var ding: int = -1
	for beat: CountUpBeat in plan.beats:
		if beat.payout > 0:
			expected.append([beat.payout, beat.subtotal])
			if beat.ding:
				ding = expected.size() - 1
	var landed: Array[Array] = []
	var payouts: Array[Array] = []
	var mets: Array[int] = []
	var totals: Array[int] = []
	for index: int in range(_events.size()):
		var event: Array = _events[index]
		match event[0]:
			"payout":
				landed.append([event[2], event[3]])
				payouts.append(event)
				# At the end of its roll: the subtotal shown is the landing's.
				assert_int(event[5]).is_equal(event[3])
			"met":
				mets.append(index)
			"total":
				totals.append(index)
	var message: String = str(_events)
	assert_array(landed).override_failure_message(message).is_equal(expected)
	assert_int(mets.size()).override_failure_message(message).is_equal(1)
	assert_int(totals.size()).override_failure_message(message).is_equal(1)
	var met: Array = _events[mets[0]]
	assert_float(met[4]).is_equal(tune.tank_overfill)
	# The TOTAL after every payout.
	assert_int(totals[0]).is_greater(_events.find(payouts[-1]))
	if at_total:
		assert_int(ding).is_equal(-1)
		# Met with the TOTAL: in its frame, just before total_landed.
		assert_int(mets[0]).is_equal(totals[0] - 1)
		assert_int(met[1]).is_equal(_events[totals[0]][1])
	else:
		assert_int(ding).is_greater_equal(0)
		var crossing: Array = payouts[ding]
		# The crossing landing, then the win, in one frame; the gold held at the landing itself.
		assert_int(mets[0]).is_equal(_events.find(crossing) + 1)
		assert_int(met[1]).is_equal(crossing[1])
		assert_float(crossing[4]).is_less(tune.tank_overfill)
		assert_int(crossing[3]).is_greater_equal(quota)
		assert_int(payouts[ding - 1][3] if ding > 0 else 0).is_less(quota)
	assert_float(_peak).is_greater(1.0)
	assert_float(_peak).is_less_equal(tune.digits_punch_max + 0.001)


## Plays the row against `quota` (a shift-1 count-up under the screen's receipt header),
## recording its landings, its win and its TOTAL, and the digits' largest scale every frame.
func _play(screen: ShiftScreen, quota: int) -> void:
	var count_up: CountUp = screen._count_up
	var led: LedDisplay = screen._led
	var tank: GoldTank = led.gold_tank
	count_up.payout_landed.connect(
		func(payout: int, subtotal: int) -> void:
			_record(["payout", payout, subtotal], tank, count_up, led)
	)
	count_up.quota_met.connect(
		func(_pop: bool) -> void: _record(["met", 0, 0], tank, count_up, led)
	)
	count_up.total_landed.connect(func() -> void: _record(["total", 0, 0], tank, count_up, led))
	get_tree().process_frame.connect(_sample.bind(led))
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	)


func _record(head: Array, tank: GoldTank, count_up: CountUp, led: LedDisplay) -> void:
	_sample(led)
	var frame: int = Engine.get_process_frames()
	_events.append([head[0], frame, head[1], head[2], tank.target(), count_up._shown_subtotal])


func _sample(led: LedDisplay) -> void:
	_peak = maxf(_peak, led.digits_label().scale.x)


func _until_played(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var started: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - started < MAX_WAIT_MS:
		await get_tree().process_frame
	_sample(screen._led)
	get_tree().process_frame.disconnect(_sample)
	assert_bool(count_up._playing).override_failure_message("Still counting.").is_false()


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(PASSING_ROW.size())
	assert_int(screen.run.preview().total).is_equal(TOTAL)
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
