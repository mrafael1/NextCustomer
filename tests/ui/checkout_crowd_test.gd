extends GdUnitTestSuite
## The checkout cheering (#120, CheckoutCrowd) on the real shift screen and alone: every paid item
## pops its plan's standees; on every frame of the count each standee's ink stays inside the crowd's
## band and never reaches the hung monitor (its rods and under-strip included, hops too); the
## crowd draws over the back wall and the RECEIPT REWARDS machine and under the monitor and the
## fore (the belt, the items, the receipt), the hud (the top bar) and the overlay (the payout
## flights), taking no clicks; a passed verdict folds it down before the printer feed, which hides
## it; a payout of 0 slumps the newest standee and a missed verdict sinks them all; reduced motion
## makes no tween; a resumed checkout shows none. Alone: a hop never kills a running pop, the
## lifecycle's tweens replace each other, placement is seeded, fills the gaps before overlapping,
## prefers ink that shows (not behind the receipt or the bag) and spans a wider window. The real
## saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## Milk, Multipack, Milk x5 = 109.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const QUOTA := 40
## A quota the row misses.
const MISSED_QUOTA := 1000
const MAX_WAIT_MS := 60000
## Of a checkout's first standees, at least a third of each one's ink shows past the receipt and
## the bag.
const MOST_HIDDEN := 2.0 / 3.0

var _folder: String = ""
var _runner: GdUnitSceneRunner
## Frames where a standee was out of its band or over the monitor.
var _bad: Array[String] = []
var _peak: int = 0
var _tweened: bool = false
## Just before the crowd's own printer feed handler: [visible, standees up, folds not yet 0].
var _at_feed: Array = []
## Standees up at the last payout landed, and each slump seen as [before, after].
var _last_up: int = 0
var _slumps: Array[Array] = []
## Standees up just after the total landed.
var _at_total: int = -1
## Tweens made by a bare crowd (_recording).
var _tweens: Array[Tween] = []


func before_test() -> void:
	_folder = "user://test_checkout_crowd_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_bad.clear()
	_peak = 0
	_tweened = false
	_at_feed = []
	_last_up = 0
	_slumps.clear()
	_at_total = -1
	_tweens.clear()


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_crowd_grows_clear_of_the_monitor_and_is_gone_at_the_printer_feed() -> void:
	var screen: ShiftScreen = await _screen()
	var crowd: CheckoutCrowd = screen._stage.crowd
	_play(screen, false)
	await _until_played(screen)
	assert_array(_bad).override_failure_message("\n".join(_bad)).is_empty()
	var plan: CountUpPlan = screen._count_up.plan
	var expected: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.payout > 0:
			assert_int(beat.cheer_count).is_greater(0)
			expected += beat.cheer_count
	assert_int(crowd._popped).is_equal(expected)
	assert_int(_peak).is_greater(1)
	assert_bool(_tweened).is_true()
	# The passed verdict folded the whole crowd down before the printer feed...
	assert_int(_at_feed.size()).is_equal(3)
	assert_bool(_at_feed[0]).is_true()
	assert_int(_at_feed[1]).is_greater(0)
	assert_int(_at_feed[2]).is_equal(0)
	# ...which hid it, before the camera's glide to the machine.
	assert_bool(crowd.visible).is_false()
	assert_int(_shown(crowd)).is_equal(0)


func test_a_zero_payout_slumps_and_a_missed_verdict_sinks_the_crowd() -> void:
	# Spot check: the 3rd product pays 0.
	var screen: ShiftScreen = await _screen(true)
	var crowd: CheckoutCrowd = screen._stage.crowd
	_play(screen, false, MISSED_QUOTA)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	await _until_played(screen)
	assert_array(_bad).override_failure_message("\n".join(_bad)).is_empty()
	assert_bool(screen._count_up.plan.quota_reached).is_false()
	assert_int(_slumps.size()).is_greater(0)
	for slump: Array in _slumps:
		assert_int(slump[1]).is_equal(slump[0] - 1)
	assert_int(_at_total).is_equal(0)
	assert_bool(crowd.visible).is_false()
	assert_int(_shown(crowd)).is_equal(0)


func test_reduced_motion_makes_no_tween() -> void:
	var screen: ShiftScreen = await _screen()
	var crowd: CheckoutCrowd = screen._stage.crowd
	_play(screen, true)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	await _until_played(screen)
	assert_array(_bad).override_failure_message("\n".join(_bad)).is_empty()
	assert_int(_peak).is_greater(1)
	assert_bool(_tweened).is_false()
	assert_bool(crowd.visible).is_false()


func test_a_resumed_checkout_shows_no_crowd() -> void:
	var screen: ShiftScreen = await _screen()
	var crowd: CheckoutCrowd = screen._stage.crowd
	var context: CountUpContext = CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	screen._count_up.show_end_state(screen.run.preview(), QUOTA, context)
	await _frames(2)
	assert_bool(crowd.visible).is_false()
	assert_int(_shown(crowd)).is_equal(0)


func test_the_crowd_draws_between_the_machine_and_the_monitor_and_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var crowd: CheckoutCrowd = stage.crowd
	assert_object(crowd.get_parent()).is_same(stage.world)
	assert_int(crowd.get_index()).is_greater(stage.machine.get_index())
	assert_int(crowd.get_index()).is_less(stage.monitor.get_index())
	assert_int(crowd.get_index()).is_less(stage.fore.get_index())
	# The belt, the items and the receipt are in the fore; the top bar in the hud over the world;
	# the payout flights in the screen's overlay over the stage.
	for node: Node in [stage.belt, stage.row_strip, stage.receipt]:
		assert_bool(stage.fore.is_ancestor_of(node)).is_true()
	assert_object(stage.top_bar.get_parent()).is_same(stage)
	assert_bool(screen._camera.is_ancestor_of(stage.world)).is_true()
	assert_object(screen._camera.get_parent()).is_same(stage.get_parent())
	assert_int(stage.get_index()).is_greater(screen._camera.get_index())
	assert_int(screen._overlay.get_index()).is_greater(stage.get_index())
	assert_int(crowd.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	crowd.begin(7, true)
	crowd.pop(3, 3)
	for standee: CheerStandee in crowd.standees():
		assert_int(standee.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	crowd.clear()


func test_a_full_crowd_fills_the_gaps_first_and_never_reaches_the_monitor() -> void:
	var crowd: CheckoutCrowd = auto_free(CheckoutCrowd.new()) as CheckoutCrowd
	add_child(crowd)
	crowd.begin(20261030, true)
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	for index: int in range(tuning.cheer_max + 10):
		crowd.pop(1 + index % 3, 1)
	var standees: Array[CheerStandee] = crowd.standees()
	assert_int(standees.size()).is_equal(tuning.cheer_max)
	var scales: Dictionary[int, bool] = {}
	for standee: CheerStandee in standees:
		scales[standee.art_scale] = true
		# At the pose's extremes: the pop's overshoot and the highest hop.
		standee.level = 1.2
		standee.hop = crowd.max_hop(standee.tier)
		assert_float(fmod(standee.position.y, CheerStandee.GRID)).is_equal(0.0)
		assert_float(fmod(standee.position.x, CheerStandee.GRID)).is_equal(0.0)
	assert_int(scales.size()).is_greater(1)
	_check(crowd, "full crowd")
	assert_array(_bad).override_failure_message("\n".join(_bad)).is_empty()
	# The first standees fill the gaps: none overlaps another.
	var first: Array[Rect2] = []
	for standee: CheerStandee in standees.slice(0, 6):
		standee.level = 1.0
		standee.hop = 0.0
		var rect: Rect2 = standee.visible_rect()
		for other: Rect2 in first:
			assert_bool(rect.intersects(other)).is_false()
		first.append(rect)


func test_a_slump_takes_the_newest_standee() -> void:
	var crowd: CheckoutCrowd = _bare(5)
	crowd.pop(1, 2)
	var newest: CheerStandee = crowd.standees()[-1]
	crowd.slump()
	assert_int(crowd.standees().size()).is_equal(1)
	assert_bool(crowd.standees().has(newest)).is_false()
	_finish(newest.tween)
	assert_bool(newest.is_queued_for_deletion()).is_true()
	# The dropped standees free at the frame's end.
	await _frames(1)


func test_a_hop_never_kills_a_running_pop_and_replaces_the_others_tweens() -> void:
	var crowd: CheckoutCrowd = _bare(6)
	crowd.pop(1, 1)
	var done: CheerStandee = crowd.standees()[0]
	_finish(done.tween)
	assert_bool(done.popping).is_false()
	crowd.pop(3, 3)
	var popping: Array[CheerStandee] = crowd.standees().slice(1)
	var pops: Array[Tween] = []
	for standee: CheerStandee in popping:
		assert_bool(standee.popping).is_true()
		pops.append(standee.tween)
	var made: int = _tweens.size()
	crowd.hop_all()
	# Only the standee whose pop ended hops: its tween replaced (the old one killed), not stacked.
	assert_int(_tweens.size()).is_equal(made + 1)
	assert_object(done.tween).is_same(_tweens[-1])
	for index: int in range(popping.size()):
		assert_object(popping[index].tween).is_same(pops[index])
		assert_bool(pops[index].is_valid()).is_true()
	# A full crowd's pop hops the others and kills no running pop either.
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	crowd.pop(1, tuning.cheer_max + 4)
	assert_int(crowd.standees().size()).is_equal(tuning.cheer_max)
	for index: int in range(popping.size()):
		assert_object(popping[index].tween).is_same(pops[index])


func test_a_pop_hops_higher_for_a_bigger_payout() -> void:
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var peaks: Array[float] = []
	for tier: int in [1, 3]:
		var crowd: CheckoutCrowd = _bare(7)
		crowd.pop(tier, 1)
		var standee: CheerStandee = crowd.standees()[0]
		var peak: float = 0.0
		var step_s: float = 0.01
		var total_s: float = (tuning.cheer_pop_ms + tuning.cheer_frame_ms) / 1000.0
		for _step: int in range(ceili(total_s / step_s)):
			standee.tween.custom_step(step_s)
			peak = maxf(peak, standee.hop)
		peaks.append(peak)
	assert_float(peaks[0]).is_greater(0.0)
	assert_float(peaks[1]).is_greater(peaks[0])


func test_a_passed_verdict_folds_everyone_and_a_missed_one_sinks_them() -> void:
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var crowd: CheckoutCrowd = _bare(8)
	crowd.pop(2, 3)
	for standee: CheerStandee in crowd.standees():
		_finish(standee.tween)
	crowd.cheer_and_fold()
	var fold_s: float = (tuning.cheer_fold_delay_ms + tuning.cheer_fold_ms) / 1000.0
	for standee: CheerStandee in crowd.standees():
		standee.tween.custom_step(fold_s + 0.001)
		assert_float(standee.fold).is_equal(0.0)
	crowd.begin(9, false)
	assert_int(_shown(crowd)).is_equal(0)
	crowd.pop(1, 4)
	var sunk: Array[CheerStandee] = crowd.standees()
	crowd.sink_all()
	assert_int(crowd.standees().size()).is_equal(0)
	for standee: CheerStandee in sunk:
		_finish(standee.tween)
	assert_int(_shown(crowd)).is_equal(0)
	# The dropped standees free at the frame's end.
	await _frames(1)


func test_the_first_standees_show_clear_of_the_receipt_and_the_bag() -> void:
	for seed_value: int in [1, 2, 3, 42, 20261030]:
		var crowd: CheckoutCrowd = auto_free(CheckoutCrowd.new()) as CheckoutCrowd
		crowd.view_width = func() -> float: return ShiftStage.SIZE.x
		add_child(crowd)
		crowd.begin(seed_value, true)
		for index: int in range(6):
			crowd.pop(1 + index % 3, 1)
		for standee: CheerStandee in crowd.standees():
			var share: float = crowd.hidden_share(standee.visible_rect())
			var rect: Rect2 = standee.visible_rect()
			(
				assert_float(share)
				. override_failure_message("seed %d: %s %.2f hidden" % [seed_value, rect, share])
				. is_less(MOST_HIDDEN)
			)


func test_a_wider_window_spreads_the_crowd_and_a_resize_keeps_the_standees_up() -> void:
	var crowd: CheckoutCrowd = auto_free(CheckoutCrowd.new()) as CheckoutCrowd
	var width: Array[float] = [ShiftStage.SIZE.x]
	crowd.view_width = func() -> float: return width[0]
	add_child(crowd)
	crowd.begin(11, true)
	crowd.pop(2, 3)
	var earlier: Array[Rect2] = crowd.standee_rects()
	# 21:9 at a 720 px tall stage.
	width[0] = 1680.0
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	for index: int in range(tuning.cheer_max):
		crowd.pop(1 + index % 3, 1)
	assert_float(crowd.position.x).is_equal(-200.0)
	var rects: Array[Rect2] = crowd.standee_rects()
	assert_array(rects.slice(0, earlier.size())).is_equal(earlier)
	var left: bool = false
	var right: bool = false
	for rect: Rect2 in rects:
		left = left or rect.position.x < 0.0
		right = right or rect.end.x > ShiftStage.SIZE.x
	assert_bool(left).is_true()
	assert_bool(right).is_true()
	_check(crowd, "21:9")
	assert_array(_bad).override_failure_message("\n".join(_bad)).is_empty()


func test_the_placement_is_seeded() -> void:
	var lefts: Array[PackedFloat32Array] = []
	for _run: int in range(2):
		var crowd: CheckoutCrowd = auto_free(CheckoutCrowd.new()) as CheckoutCrowd
		add_child(crowd)
		crowd.begin(42, true)
		crowd.pop(2, 2)
		crowd.pop(3, 3)
		var positions: PackedFloat32Array = PackedFloat32Array()
		for standee: CheerStandee in crowd.standees():
			positions.append(standee.position.x)
			positions.append(standee.position.y)
		lefts.append(positions)
	assert_array(lefts[0]).is_equal(lefts[1])


## Every standee's ink inside the band and off the monitor, else a line in _bad.
func _check(crowd: CheckoutCrowd, when: String) -> void:
	var band: Rect2 = Rect2(crowd.position, crowd.size)
	for rect: Rect2 in crowd.standee_rects():
		if rect.size.y <= 0.0:
			continue
		if rect.position.y < band.position.y - 0.01 or rect.end.y > band.end.y + 0.01:
			_bad.append("%s: %s out of the band %s" % [when, rect, band])
		if rect.position.x < band.position.x - 0.01 or rect.end.x > band.end.x + 0.01:
			_bad.append("%s: %s out of the band %s" % [when, rect, band])
		for avoid: Rect2 in crowd.avoid:
			if rect.intersects(avoid):
				_bad.append("%s: %s over the monitor %s" % [when, rect, avoid])


func _play(screen: ShiftScreen, reduced: bool, quota: int = QUOTA) -> void:
	var count_up: CountUp = screen._count_up
	var crowd: CheckoutCrowd = screen._stage.crowd
	# Ahead of the crowd's own handler (which hides it): reconnected after the probe.
	count_up.printer_feed.disconnect(crowd.clear)
	count_up.printer_feed.connect(_on_feed.bind(crowd))
	count_up.printer_feed.connect(crowd.clear)
	count_up.payout_landed.connect(
		func(_payout: int, _subtotal: int) -> void: _last_up = crowd.standees().size()
	)
	count_up.beat_started.connect(_on_beat.bind(crowd))
	count_up.total_landed.connect(func() -> void: _at_total = crowd.standees().size())
	get_tree().process_frame.connect(_sample.bind(crowd))
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, reduced, screen.receipt_header())
	)


func _on_feed(crowd: CheckoutCrowd) -> void:
	var unfolded: int = 0
	for standee: CheerStandee in crowd.standees():
		if standee.fold > 0.0:
			unfolded += 1
	_at_feed = [crowd.visible, crowd.standees().size(), unfolded]


## After the crowd's handler (connected first): a payout beat of 0 has slumped the newest.
func _on_beat(
	beat: CountUpBeat,
	_step: ScoreStep,
	_line: String,
	_view: CardView,
	_items: int,
	crowd: CheckoutCrowd
) -> void:
	if CountUpPlan.is_payout_beat(beat) and beat.cheer_count == 0 and _last_up > 0:
		_slumps.append([_last_up, crowd.standees().size()])
		_last_up = crowd.standees().size()


## A bare crowd at the stage's width, `seed_value` placing it, its tweens recorded.
func _bare(seed_value: int) -> CheckoutCrowd:
	var crowd: CheckoutCrowd = auto_free(CheckoutCrowd.new()) as CheckoutCrowd
	crowd.view_width = func() -> float: return ShiftStage.SIZE.x
	add_child(crowd)
	crowd.begin(seed_value, false)
	crowd.make_tween = func() -> Tween:
		var tween: Tween = crowd.create_tween()
		_tweens.append(tween)
		return tween
	return crowd


## Runs `tween` to its end at once.
static func _finish(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.custom_step(60.0)


func _sample(crowd: CheckoutCrowd) -> void:
	_peak = maxi(_peak, crowd.standees().size())
	for standee: CheerStandee in crowd.standees():
		if standee.tween != null:
			_tweened = true
	_check(crowd, "frame %d" % Engine.get_process_frames())


func _until_played(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var started: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - started < MAX_WAIT_MS:
		await get_tree().process_frame
	get_tree().process_frame.disconnect(_sample)
	assert_bool(count_up._playing).override_failure_message("Still counting.").is_false()


func _screen(spot_check: bool = false) -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	if spot_check:
		screen._debug.set_inspection("spot_check")
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(PASSING_ROW.size())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _shown(crowd: CheckoutCrowd) -> int:
	var shown: int = 0
	for child: Node in crowd.get_children():
		if child is CheerStandee and not child.is_queued_for_deletion():
			shown += 1
	return shown


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
