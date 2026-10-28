extends GdUnitTestSuite
## The count-up's landings on the real shift screen (CountUp.landing, payout_landed and
## total_landed; the one monitor screen of #105 piece 2): every landing beat lands on the total
## once; every paid beat lands once, with its payout and its subtotal; the quota is met once, as
## the ding beat's last tick brings the shown total to it (D1); the TOTAL lands once, after every
## payout and landing, on the total; the checkout column's number never punches past the largest
## punch (CountTotalTuning). On every frame of the count the top bar's gauge, the checkout
## column's number and (while it runs) the climax's number read the register's same whole number.
## The same holds untouched, tapped (TAP_SKIP), held (FAST_FORWARD) and when the last payout meets
## the quota with the TOTAL (chip_at_total). The
## real saves and logs are never touched.

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
## What the count emitted, in order: [name, frame, payout, subtotal, the reading met, the shown
## subtotal].
var _events: Array[Array] = []
var _peak: float = 1.0
## Frames where the top bar, the checkout column or the climax read another number.
var _out_of_sync: Array[String] = []


func before_test() -> void:
	_folder = "user://test_count_up_landing_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_events.clear()
	_peak = 1.0
	_out_of_sync.clear()


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
	var tune: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	var expected: Array[Array] = []
	for beat: CountUpBeat in plan.beats:
		if beat.payout > 0:
			expected.append([beat.payout, beat.subtotal])
	var landed: Array[Array] = []
	var payouts: Array[Array] = []
	var landings: Array[int] = []
	var mets: Array[int] = []
	var totals: Array[int] = []
	for index: int in range(_events.size()):
		var event: Array = _events[index]
		match event[0]:
			"payout":
				landed.append([event[2], event[3]])
				payouts.append(event)
			"landing":
				landings.append(index)
			"met":
				mets.append(index)
			"total":
				totals.append(index)
	var message: String = str(_events)
	# Every paid beat lands once, with its payout and the subtotal it pays to (the shown total
	# then: the plan's shown_to at a PAYOUT is its subtotal).
	assert_array(landed).override_failure_message(message).is_equal(expected)
	# Every landing beat lands on the total once, in order.
	assert_int(landings.size()).override_failure_message(message).is_equal(plan.landing_count)
	assert_int(mets.size()).override_failure_message(message).is_equal(1)
	assert_int(totals.size()).override_failure_message(message).is_equal(1)
	var met: Array = _events[mets[0]]
	assert_bool(screen._led.is_met()).is_true()
	assert_array(_out_of_sync).override_failure_message("\n".join(_out_of_sync)).is_empty()
	# The TOTAL after every payout and every landing, on the total.
	assert_int(totals[0]).is_greater(_events.find(payouts[-1]))
	assert_int(totals[0]).is_greater(landings[-1])
	assert_int(_events[totals[0]][5]).is_equal(plan.total)
	if at_total:
		assert_int(plan.ding_beat).is_equal(-1)
		# Met with the TOTAL: in its frame, just before total_landed.
		assert_int(mets[0]).is_equal(totals[0] - 1)
		assert_int(met[1]).is_equal(_events[totals[0]][1])
	else:
		# Met on the ding beat's crossing tick (D1: on the shown total): the reading then is that
		# tick's, at or past the quota, which its shown_from was short of.
		assert_int(plan.ding_beat).is_greater_equal(0)
		var ding: CountUpBeat = plan.beats[plan.ding_beat]
		assert_int(met[5]).override_failure_message(message).is_equal(ding.ticks[ding.ding_tick])
		assert_int(ding.ticks[ding.ding_tick]).is_greater_equal(quota)
		assert_int(ding.shown_to).is_greater_equal(quota)
		assert_int(ding.shown_from).is_less(quota)
		assert_int(mets[0]).is_less(totals[0])
	assert_float(_peak).is_greater(1.0)
	var largest: float = maxf(tune.punch_base, maxf(tune.punch_add, tune.punch_mul))
	assert_float(_peak).is_less_equal(largest + 0.001)


## Plays the row against `quota` (a shift-1 count-up under the screen's receipt header),
## recording its landings, its win and its TOTAL, and every frame the number's largest scale and
## whether the top bar, the checkout column and the climax read the register's number.
func _play(screen: ShiftScreen, quota: int) -> void:
	var count_up: CountUp = screen._count_up
	count_up.payout_landed.connect(
		func(payout: int, subtotal: int) -> void: _record(["payout", payout, subtotal], screen)
	)
	count_up.quota_met.connect(func(_pop: bool) -> void: _record(["met", 0, 0], screen))
	count_up.landing.connect(
		func(beat: CountUpBeat) -> void: _record(["landing", beat.gain, beat.shown_to], screen)
	)
	count_up.total_landed.connect(func() -> void: _record(["total", 0, 0], screen))
	get_tree().process_frame.connect(_sample.bind(screen))
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	)


func _record(head: Array, screen: ShiftScreen) -> void:
	_sample(screen)
	var frame: int = Engine.get_process_frames()
	var shown: int = screen._count_up._shown_subtotal
	_events.append([head[0], frame, head[1], head[2], screen._led.is_met(), shown])


func _sample(screen: ShiftScreen) -> void:
	var number: TotalNumber = screen._monitor.checkout().total_number()
	_peak = maxf(_peak, number.punch_scale())
	if not screen._led.is_counting():
		return
	var reading: int = screen._led.amount()
	var top: String = screen._quota_meter.amount_label.text
	var frame: int = Engine.get_process_frames()
	if top != "€%d" % reading:
		_out_of_sync.append("frame %d: the top bar %s, the reading %d" % [frame, top, reading])
	if number.value() != reading:
		_out_of_sync.append(
			"frame %d: the column %d, the reading %d" % [frame, number.value(), reading]
		)
	var climax: MonitorClimax = screen._monitor.climax()
	if climax.is_running() and climax.number().value() != reading:
		var at: int = climax.number().value()
		_out_of_sync.append("frame %d: the climax %d, the reading %d" % [frame, at, reading])


func _until_played(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var started: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - started < MAX_WAIT_MS:
		await get_tree().process_frame
	_sample(screen)
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
