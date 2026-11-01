extends GdUnitTestSuite
## The checkout cheering (#120, CheckoutCrowd) on the real shift screen and alone: every paid item
## pops its plan's standees; on every frame of the count each standee's ink stays inside the crowd's
## band and never reaches the hung monitor (its rods and under-strip included, hops too); the crowd
## draws over the back wall and the RECEIPT REWARDS machine and under the monitor and the fore (the
## belt, the items, the receipt), the hud (the top bar) and the overlay (the payout flights), taking
## no clicks; a passed verdict folds it down before the printer feed, which hides it; a failed
## payout of 0 slumps the newest standee, a coupon paying nothing of its own slumps none, meeting
## the quota pops cheer_quota_count more, and a missed verdict topples them all; reduced motion
## makes no tween; a resumed checkout shows none. Alone: a hop never kills a running pop, the
## lifecycle's tweens replace each other, placement is seeded, fills the gaps before overlapping
## and spans a wider window. On the real screen at 1920x1080 and 1280x720 no standee's ink reaches
## the receipt, the printer, the monitor, the bag or its shelf, even at its highest hop. Each
## standee's ground shadow lies on the belt's guard under it (the stage lays the shadow layer on
## the belt, under the row), stays there through a hop (narrower and lighter), narrows as it folds
## and goes with it; beside the belt it falls on the floor, never over the belt's end cap. The real
## saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## Milk, Multipack, Milk x5 = 109.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const QUOTA := 40
## A quota the row misses.
const MISSED_QUOTA := 1000
const MAX_WAIT_MS := 60000
## The window sizes the layout is checked at.
const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]

var _folder: String = ""
var _window_size: Vector2i = Vector2i.ZERO
var _runner: GdUnitSceneRunner
## Frames where a standee was out of its band or over the monitor.
var _bad: Array[String] = []
var _peak: int = 0
var _tweened: bool = false
## Just before the crowd's own printer feed handler: [visible, standees up, folds not yet 0].
var _at_feed: Array = []
## Standees up at the last step or payout landed, and each slump seen as [before, after]; each
## payout of 0 that didn't fail (a coupon's) as [before, after].
var _last_up: int = 0
var _slumps: Array[Array] = []
var _kept: Array[Array] = []
## At the quota's pop: [standees before, after].
var _at_quota: Array[int] = []
## The confetti's pieces at the printer feed (the final yay threw them).
var _confetti_at_feed: int = -1
## Standees up just after the total landed.
var _at_total: int = -1
## Tweens made by a bare crowd (_recording).
var _tweens: Array[Tween] = []


func before_test() -> void:
	_folder = "user://test_checkout_crowd_%d" % Time.get_ticks_usec()
	_window_size = get_tree().root.size
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_bad.clear()
	_peak = 0
	_tweened = false
	_at_feed = []
	_last_up = 0
	_slumps.clear()
	_kept.clear()
	_at_quota.clear()
	_confetti_at_feed = -1
	_at_total = -1
	_tweens.clear()


func after_test() -> void:
	get_tree().root.size = _window_size
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
	# One standee per bonus line as it lands (2026-11-01), none for a payout of its own.
	for beat: CountUpBeat in plan.beats:
		expected += beat.cheer_count
	assert_int(expected).is_greater(0)
	assert_int(_peak).is_greater(1)
	assert_bool(_tweened).is_true()
	# Meeting the quota popped cheer_quota_count more (v0.82).
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH) as CountUpTuning
	assert_int(_at_quota.size()).is_equal(2)
	assert_int(_at_quota[1] - _at_quota[0]).is_equal(tuning.cheer_quota_count)
	expected += tuning.cheer_quota_count
	# Multipack (a coupon) pays nothing of its own: no slump.
	assert_int(_kept.size()).is_greater(0)
	for kept: Array in _kept:
		assert_int(kept[1]).is_equal(kept[0])
	assert_int(crowd._popped).is_equal(expected)
	# The passed verdict folded the whole crowd down before the printer feed...
	assert_int(_at_feed.size()).is_equal(3)
	assert_bool(_at_feed[0]).is_true()
	assert_int(_at_feed[1]).is_greater(0)
	assert_int(_at_feed[2]).is_equal(0)
	# The final yay threw confetti, still flying at the feed.
	assert_int(_confetti_at_feed).is_greater(0)
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
	assert_int(crowd.confetti.pieces()).is_equal(0)
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
	# The shadows lie on the belt's guard, under the row's items.
	assert_object(crowd.shadow_layer.get_parent()).is_same(stage.belt)
	assert_int(crowd.shadow_layer.get_index()).is_less(stage.row_strip.get_index())
	assert_int(crowd.shadow_layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
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


func test_a_passed_verdict_folds_everyone_and_a_missed_one_topples_them() -> void:
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
	var confetti: CheerConfetti = auto_free(CheerConfetti.new())
	add_child(confetti)
	crowd.confetti = confetti
	crowd.pop(1, 4)
	for standee: CheerStandee in crowd.standees():
		_finish(standee.tween)
	var sunk: Array[CheerStandee] = crowd.standees()
	crowd.topple_all()
	assert_int(crowd.standees().size()).is_equal(0)
	# The miss (v0.82): arms down, each wilts with a lean, then keels over flat with a dust puff.
	var wilt_s: float = tuning.cheer_slump_ms * 2.0 / 1000.0
	for standee: CheerStandee in sunk:
		assert_bool(standee.is_cheering()).is_false()
		standee.tween.custom_step(wilt_s + 0.001)
		assert_float(absf(standee.lean)).is_equal_approx(tuning.cheer_lean_deg, 0.01)
		assert_float(standee.fold).is_equal(1.0)
	for standee: CheerStandee in sunk:
		_finish(standee.tween)
	assert_int(confetti.pieces()).is_greater_equal(tuning.cheer_dust_count)
	assert_int(_shown(crowd)).is_equal(0)
	# The dropped standees free at the frame's end.
	await _frames(1)


func test_the_crowd_stays_clear_of_the_receipt_the_monitor_and_the_bag_at_1920x1080() -> void:
	await _check_clear_at(WINDOWS[0])


func test_the_crowd_stays_clear_of_the_receipt_the_monitor_and_the_bag_at_1280x720() -> void:
	await _check_clear_at(WINDOWS[1])


func test_each_standee_casts_a_shadow_that_stays_on_the_ground_and_goes_with_it() -> void:
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var crowd: CheckoutCrowd = _bare(12)
	crowd.pop(1, 1)
	crowd.pop(3, 2)
	var standees: Array[CheerStandee] = crowd.standees()
	for standee: CheerStandee in standees:
		_finish(standee.tween)
		var shadow: CheerShadow = standee.shadow
		assert_object(shadow.get_parent()).is_same(crowd.shadow_layer)
		assert_bool(shadow.visible).is_true()
		assert_bool(shadow.cells().is_empty()).is_false()
		# On the guard's lit face under the belt's top (every open column is over the belt).
		var belt_top: float = ShiftStage.BELT_RECT.position.y - crowd.position.y
		assert_float(standee.ground_y).is_equal(belt_top)
		var rest: Rect2 = shadow.ground_rect()
		var face: float = belt_top + CheerShadow.DROP_ROWS * CheerShadow.GRID
		assert_float(rest.position.y).is_equal(face)
		assert_float(fmod(rest.position.x, CheerShadow.GRID)).is_equal(0.0)
		var ink: Rect2 = standee.visible_rect()
		var near: float = CheerShadow.GRID * 2.0
		assert_float(rest.get_center().x).is_equal_approx(ink.get_center().x, near)
		# A hop: the shadow stays on the ground, narrower and lighter.
		standee.hop = tuning.cheer_shadow_lift_px
		var lifted: Rect2 = shadow.ground_rect()
		assert_float(lifted.position.y).is_equal(rest.position.y)
		assert_float(lifted.end.y).is_equal(rest.end.y)
		assert_float(lifted.size.x).is_less(rest.size.x)
		assert_float(shadow.strength).is_equal_approx(tuning.cheer_shadow_lift_share, 0.01)
		standee.hop = 0.0
		assert_bool(shadow.ground_rect() == rest).is_true()
		# A fold narrows it; folded flat, it is gone.
		standee.fold = 0.5
		assert_float(shadow.ground_rect().size.x).is_less(rest.size.x)
		standee.fold = 0.0
		assert_bool(shadow.visible).is_false()
		standee.fold = 1.0
	# A hop run by the crowd keeps it on the ground on every step.
	var hopper: CheerStandee = standees[0]
	var ground: float = hopper.shadow.ground_rect().position.y
	crowd.hop_all()
	var lowest_strength: float = 1.0
	for _step: int in range(40):
		hopper.tween.custom_step(0.01)
		if hopper.shadow.visible:
			assert_float(hopper.shadow.ground_rect().position.y).is_equal(ground)
		lowest_strength = minf(lowest_strength, hopper.shadow.strength)
	assert_float(lowest_strength).is_less(1.0)
	# It goes with its standee: a slump, then the rest at once.
	var newest: CheerStandee = crowd.standees()[-1]
	var shadow_of_newest: CheerShadow = newest.shadow
	crowd.slump()
	_finish(newest.tween)
	assert_bool(shadow_of_newest.is_queued_for_deletion()).is_true()
	assert_object(shadow_of_newest.get_parent()).is_null()
	crowd.clear()
	assert_int(crowd.shadow_layer.get_child_count()).is_equal(0)
	assert_bool(crowd.shadow_layer.visible).is_false()
	await _frames(1)


## A shadow falls on the ground under each of its columns (2026-11-01): on the guard's lit face over
## the guard, on the floor beside the belt (past its end, a wider window's extra wall), never over
## the belt's end cap; a standee over the belt's end splits it between the guard and the floor.
func test_a_shadow_beside_the_belt_falls_on_the_floor() -> void:
	var crowd: CheckoutCrowd = _bare(5)
	crowd.view_width = func() -> float: return ShiftStage.SIZE.x + 400.0
	crowd.pop(1, 1)
	var standee: CheerStandee = crowd.standees()[0]
	_finish(standee.tween)
	var belt: Rect2 = ShiftStage.BELT_RECT
	var guard_end: float = belt.position.x + BeltPanel.GUARD_FACE.end.x
	var cap_end: float = belt.position.x + BeltPanel.FOOT_SPAN.y
	var face: float = belt.position.y + BeltPanel.GUARD_FACE.position.y
	var floor_rows: float = CheerShadow.ROWS * CheerShadow.GRID
	# Over the belt's end, then past it in the extra wall: the ink's middle at these stage x.
	for middle: float in [guard_end, ShiftStage.SIZE.x + 100.0]:
		var over_belt: bool = middle < cap_end
		var ink_middle: float = (
			(standee.ink.position.x + standee.ink.size.x / 2.0) * standee.art_scale
		)
		standee.position.x = middle - crowd.position.x - ink_middle
		standee.ground_y = (
			(belt.position.y if over_belt else ShiftStage.COUNTER_TOP) - crowd.position.y
		)
		standee.refresh()
		var shadow: CheerShadow = standee.shadow
		var guard_cells: Array[Rect2] = shadow.guard_cells()
		var floor_cells: Array[Rect2] = shadow.floor_cells()
		assert_bool(floor_cells.is_empty()).override_failure_message(str(middle)).is_false()
		assert_bool(guard_cells.is_empty()).is_equal(not over_belt)
		var to_stage: Vector2 = crowd.position + shadow.position - shadow.origin
		for cell: Rect2 in guard_cells:
			var at: Rect2 = Rect2(cell.position + to_stage, cell.size)
			assert_float(at.end.x).is_less_equal(guard_end)
			assert_float(at.position.y).is_greater_equal(face)
			assert_float(at.end.y).is_less_equal(face + BeltPanel.GUARD_FACE.size.y)
		for cell: Rect2 in floor_cells:
			var at: Rect2 = Rect2(cell.position + to_stage, cell.size)
			assert_float(at.position.x).is_greater_equal(cap_end)
			assert_float(at.position.y).is_greater_equal(ShiftStage.COUNTER_TOP)
			assert_float(at.end.y).is_less_equal(ShiftStage.COUNTER_TOP + floor_rows)
	crowd.clear()
	await _frames(1)


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


## On the real screen in a `window` sized window: a full crowd's ink (at its highest hop) never
## reaches the receipt, the printer, the monitor, the bag or its shelf (their global rects), and
## each shadow lies on the guard under the belt's top.
func _check_clear_at(window: Vector2i) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var crowd: CheckoutCrowd = stage.crowd
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var parts: Dictionary[String, Rect2] = {
		"receipt": stage.receipt.get_global_rect(),
		"printer lip": stage.printer_lip.get_global_rect(),
		"monitor": stage.monitor.get_global_rect(),
		"bag": stage.bag.get_global_rect(),
		"shelf": stage.get_global_transform() * ShiftStage.BAGGING_SHELF_RECT,
	}
	assert_float(parts["receipt"].size.y).is_greater(0.0)
	var belt_top: float = stage.belt.get_global_rect().position.y
	for seed_value: int in [1, 42, 20261030]:
		crowd.begin(seed_value, true)
		for index: int in range(tuning.cheer_max):
			crowd.pop(1 + index % 3, 1)
		for standee: CheerStandee in crowd.standees():
			standee.level = 1.0
			standee.hop = crowd.max_hop(standee.tier)
			var ink: Rect2 = crowd.get_global_transform() * standee.visible_rect()
			for part: String in parts:
				var message: String = (
					"%s, seed %d: %s over the %s %s" % [window, seed_value, ink, part, parts[part]]
				)
				(
					assert_bool(ink.intersects(parts[part]))
					. override_failure_message(message)
					. is_false()
				)
			standee.hop = 0.0
			var shadow: Rect2 = standee.shadow.get_global_rect()
			var face: float = belt_top + CheerShadow.DROP_ROWS * CheerShadow.GRID
			assert_float(shadow.position.y).is_equal_approx(face, 0.01)
		crowd.clear()


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
	count_up.step_landed.connect(func(_index: int) -> void: _last_up = crowd.standees().size())
	count_up.beat_started.connect(_on_beat.bind(crowd))
	count_up.total_landed.connect(func() -> void: _at_total = crowd.standees().size())
	# The standees just before and just after the crowd's own quota handler.
	var ahead: Callable = func(with_pop: bool) -> void:
		if with_pop:
			_at_quota.append(crowd.standees().size())
	var behind: Callable = func(with_pop: bool) -> void:
		if with_pop:
			_at_quota.append(crowd.standees().size())
	count_up.quota_met.disconnect(crowd._on_quota_met)
	count_up.quota_met.connect(ahead)
	count_up.quota_met.connect(crowd._on_quota_met)
	count_up.quota_met.connect(behind)
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
	_confetti_at_feed = crowd.confetti.pieces() if crowd.confetti != null else -1


## After the crowd's handler (connected first): a payout beat of 0 has slumped the newest.
func _on_beat(
	beat: CountUpBeat,
	_step: ScoreStep,
	_line: String,
	_view: CardView,
	_items: int,
	crowd: CheckoutCrowd
) -> void:
	# A slump needs a standee up; a kept coupon counts even on an empty crowd.
	var counted: bool = _last_up > 0 or not beat.cheer_failed
	if CountUpPlan.is_payout_beat(beat) and beat.payout <= 0 and counted:
		var pair: Array = [_last_up, crowd.standees().size()]
		if beat.cheer_failed:
			_slumps.append(pair)
		else:
			_kept.append(pair)
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
