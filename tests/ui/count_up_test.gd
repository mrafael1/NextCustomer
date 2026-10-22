extends GdUnitTestSuite
## The count-up playing its CountUpPlan on the real shift screen (#60): the full reference row
## (Eggs, Bread, Milk, Multipack, Milk x3 with Coupon engine, Slot engine and a Spot check) in
## about 4-7 s at normal speed (#86 v6: a ride gap before each item), every frame inside the
## 1280x720 screen with Engine.time_scale untouched; notes that never drop, quiet armed notes and
## three ticks per payout; a ride before each item's scan and the last one's bag hop; the quota
## met (quota_met) at the ding, its reward running in real time through the hold; the payouts'
## chips flying from where the item is (source_rect); the Fast setting and reduced motion; shakes
## that end where they started; and the run context (the best so far leaves out the shift being
## counted) and the count_up event's fields. The real saves and logs are never touched: both go to
## a temporary folder.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## A newest receipt line is checked against the scroll area once it has had this many frames to
## scroll into view.
const SCROLL_FRAMES := 3

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner
## count_started's emissions (#86 round 7), as [views, rides before it], from _record_rides.
var _count_starts: Array[Array] = []


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	# The game's window, not the headless default (1280x1280).
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	Rush.restore()
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The full reference row at normal speed, frame by frame: about 4-7 s from the click to the
## total, everything on screen, the newest line in the receipt's scroll area, lines unrotated,
## Engine.time_scale at 1; notes climb, armed notes are quiet, three ticks per payout; a ride
## before each item's first beat and the last item's bag hop; the ding and the quota met for good;
## the rattle target back at its origin; the receipt equal to show_result's; and the count_up
## event's new fields.
func test_the_full_row_counts_up_on_screen_in_five_to_nine_seconds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _full_row(screen)
	var rest: float = screen._register.position.x
	var rides: Array[Array] = _record_rides(screen._count_up)
	screen._on_checkout_pressed()
	var probe: Dictionary = await _probe_count_up(screen)
	var count_up: CountUp = screen._count_up
	var plan: CountUpPlan = count_up.plan
	var failures: Array = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(probe["frames"]).is_greater(30)
	_assert_rattle_fills_the_pause(count_up, probe)

	var event: Dictionary = _last_event("count_up")
	var count_up_ms: int = int(event["count_up_ms"])
	prints("#60 full row: count_up_ms", count_up_ms, "planned_ms", plan.planned_ms)
	assert_int(plan.step_count).is_equal(27)
	# The 4-7.6 s window at the 0.8 count tempo (2026-10-20): 1.25x slower.
	assert_int(count_up_ms).is_between(5000, 9500)
	assert_int(count_up_ms).is_between(plan.planned_ms - 150, plan.planned_ms + 900)
	assert_float(float(event["base_speed"])).is_equal(1.0)
	assert_float(float(event["speed_setting"])).is_equal(1.0)
	assert_bool(event["reduced_motion"]).is_false()
	assert_int(int(event["step_count"])).is_equal(27)
	assert_int(int(event["planned_ms"])).is_equal(plan.planned_ms)

	_assert_sounds(sfx, plan, count_up.printer_feed_ms)
	_assert_rides(rides, plan)
	# Shift 1's quota (34) is reached mid-row: the ding, then the quota met for good.
	assert_int(plan.ding_beat).is_greater_equal(0)
	assert_int(_sounds(sfx, "ding")).is_equal(1)
	assert_bool(probe["met_before_total"]).is_true()
	# It was met at the ding beat, the subtotal past the quota but short of the total, and stayed
	# met on every frame after.
	var quota: int = screen.run.quota()
	assert_int(quota).is_equal(34)
	assert_int(int(probe["met_subtotal"])).is_between(quota, plan.total - 1)
	assert_int(int(probe["met_subtotal"])).is_equal(plan.beats[plan.ding_beat].subtotal)
	assert_bool(probe["met_lost"]).is_false()
	assert_array(probe["pops"]).is_equal([true])
	_assert_met(screen, true)
	# The 110 is huge against the €45 floor.
	assert_int(plan.size).is_equal(CountUpPlan.Size.HUGE)
	assert_object(count_up.intensity).is_not_null()
	assert_bool(count_up.intensity.is_huge).is_true()
	assert_float(screen._register.position.x).is_equal(rest)
	await _assert_full_receipt(screen)


## Fast (set through the temporary debug toggle, saved in the profile): faster than planned at
## normal speed, the same receipt, and the event says so.
func test_the_fast_setting_counts_faster_with_the_same_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_fast_count_up(true)
	assert_float(screen.profile.count_up_speed()).is_equal(ProfileState.COUNT_UP_FAST)
	var saved: ProfileState = SaveService.new(SaveService.default_folder()).load_profile()
	assert_float(saved.count_up_speed()).is_equal(ProfileState.COUNT_UP_FAST)
	await _full_row(screen)
	screen._on_checkout_pressed()
	var probe: Dictionary = await _probe_count_up(screen)
	var failures: Array = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	var plan: CountUpPlan = screen._count_up.plan
	var normal: CountUpPlan = CountUpPlan.build(
		screen.run.last_result.steps, 34, CountUpContext.new(1, 0), load(CountUp.TUNING_PATH)
	)
	assert_float(plan.base_speed).is_equal(1.5)
	assert_int(plan.planned_ms).is_less(normal.planned_ms)
	var event: Dictionary = _last_event("count_up")
	prints("#60 full row on Fast: count_up_ms", event["count_up_ms"], "planned_ms", plan.planned_ms)
	# Hit-stops and the pause before the total are not sped up by count_speed (D6): the real
	# count-up takes as long as planned, no shorter.
	assert_int(int(event["count_up_ms"])).is_between(plan.planned_ms - 150, plan.planned_ms + 900)
	_assert_rattle_fills_the_pause(screen._count_up, probe)
	assert_float(float(event["base_speed"])).is_equal(1.5)
	assert_float(float(event["speed_setting"])).is_equal(1.5)
	await _assert_full_receipt(screen)


## Reduced motion: no node is ever shaken off its place (the rattle target, the cards, the
## loyalty-card boxes), no payout chip flies (each line shows at once), every ride still plays,
## no rattle before the total, and the same receipt.
func test_reduced_motion_shakes_nothing_and_keeps_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	await _full_row(screen)
	var rest: float = screen._register.position.x
	var boxes: Array[Control] = screen._loyalty_card.stamped_boxes()
	var box_rests: Array[Vector2] = []
	var box_turns: Array[float] = []
	for box: Control in boxes:
		box_rests.append(box.position)
		box_turns.append(box.rotation)
	var rides: Array[Array] = _record_rides(screen._count_up)
	screen._on_checkout_pressed()
	var moved: Array[String] = []
	var frames: int = 0
	while screen._counting and not screen._count_up._verdict_shown:
		await get_tree().process_frame
		frames += 1
		if screen._register.position.x != rest:
			moved.append("register at %s" % screen._register.position.x)
		for view: CardView in screen._row_views:
			if view.body.position.x != 0.0:
				moved.append("%s body at %s" % [view.card.definition.id, view.body.position])
		for index: int in range(boxes.size()):
			if (
				boxes[index].position != box_rests[index]
				or boxes[index].rotation != box_turns[index]
			):
				moved.append("upgrade box %d moved" % index)
		for child: Node in screen._overlay.get_children():
			if ReceiptFly.is_chip(child):
				moved.append("a payout chip flew")
	await _count_up_end(screen)
	assert_int(frames).is_greater(30)
	assert_array(moved).override_failure_message("\n".join(moved.slice(0, 10))).is_empty()
	var plan: CountUpPlan = screen._count_up.plan
	assert_bool(plan.reduced_motion).is_true()
	_assert_rides(rides, plan)
	assert_float(plan.final_rattle_px).is_equal(0.0)
	assert_bool(_last_event("count_up")["reduced_motion"]).is_true()
	assert_bool(screen._count_up.intensity.reduced_motion).is_true()
	await _assert_full_receipt(screen)


## Shakes that overlap on one node replace each other from the same rest position, so the node
## always ends where it started and never strays further than the biggest shake.
func test_overlapping_shakes_end_at_the_origin() -> void:
	var screen: ShiftScreen = await _screen()
	var fx: CountUpMotion = screen._count_up._fx
	fx.reset(false)
	var node: Control = screen._register
	var rest: float = node.position.x
	var furthest: float = 0.0
	fx.shake(node, 8.0)
	for amount: float in [12.0, 5.0, 10.0]:
		await get_tree().process_frame
		furthest = maxf(furthest, absf(node.position.x - rest))
		fx.shake(node, amount, 6)
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 600:
		await get_tree().process_frame
		furthest = maxf(furthest, absf(node.position.x - rest))
	assert_float(node.position.x).is_equal(rest)
	assert_float(furthest).is_greater(0.0)
	assert_float(furthest).is_less_equal(12.0)
	# Under reduced motion a shake does nothing at all.
	fx.reset(true)
	fx.shake(node, 12.0)
	await _frames(3)
	assert_float(node.position.x).is_equal(rest)


## The quota met on the last payout: no ding, and the quota is met (with its pop) with the TOTAL
## line. Never reached: never met, no colour change. Tapped through, the receipt is still whole.
func test_the_quota_is_met_with_the_total_on_a_last_payout_crossing_and_never_on_a_fail() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	assert_int(result.total).is_equal(110)
	var count_up: CountUp = screen._count_up
	var mets: Array[bool] = []
	var led: LedDisplay = screen._led
	count_up.quota_met.connect(
		func(_pop: bool) -> void: mets.append(led.caption_label().text == LedDisplay.TOTAL_TEXT)
	)
	_play_tapped(screen, result, 110)
	await _played(screen)
	assert_bool(count_up.plan.chip_at_total).is_true()
	# Once, as the total shows (never before it).
	assert_array(mets).is_equal([true])
	assert_int(_sounds(sfx, "ding")).is_equal(0)
	_assert_met(screen, true)
	await _assert_receipt_of(screen, result, 110)

	mets.clear()
	_play_tapped(screen, result, 111)
	await _played(screen)
	assert_array(mets).is_empty()
	assert_bool(count_up.plan.quota_reached).is_false()
	_assert_met(screen, false)
	await _assert_receipt_of(screen, result, 111)


## Flights and puffs start where the item is now (#86 v6, source_rect: the belt ride gives the
## scanner, or the bag's mouth once an item is bagged): each payout's paper chip starts at its
## item's rect, and the lost Coffee bonus (a trailing fizzle on the long-scanned Coffee; Potatoes
## and Soup have no condition to fizzle, #45) puffs from Coffee's.
func test_flights_and_puffs_start_where_the_item_is_now() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee", "potatoes", "soup"])
	var count_up: CountUp = screen._count_up
	var rect_of: Callable = func(slot: int) -> Rect2:
		return Rect2(Vector2(300.0 + 40.0 * slot, 200.0), Vector2(40, 40))
	count_up.source_rect = rect_of
	# Where each chip or puff stands once it is set up (deferred: after the frame's own code).
	var starts: Array[Vector2] = []
	var puffs: Array[Vector2] = []
	var record: Callable = func(node: Control) -> void:
		var centre: Vector2 = node.get_global_rect().get_center()
		if ReceiptFly.is_chip(node):
			starts.append(centre)
		elif node is Label and (node as Label).text == "WASTED":
			puffs.append(centre)
	var on_added: Callable = func(node: Node) -> void:
		if node is Control:
			record.call_deferred(node)
	screen._overlay.child_entered_tree.connect(on_added)
	var result: ScoreResult = screen.run.preview()
	count_up.play(
		result, screen._row_views, ShiftScreen._names(screen.run.row), 1, CountUpContext.new()
	)
	await _played(screen)
	screen._overlay.child_entered_tree.disconnect(on_added)
	count_up.source_rect = Callable()
	# Three payouts, three chips, each from its item's rect.
	assert_int(starts.size()).is_equal(3)
	for slot: int in range(starts.size()):
		var item: Vector2 = (rect_of.call(slot) as Rect2).get_center()
		assert_float(starts[slot].distance_to(item)).override_failure_message(str(starts)).is_less(
			1.0
		)
	# One lost bonus, one puff, 30 px over Coffee's rect.
	assert_int(puffs.size()).is_equal(1)
	var coffee: Vector2 = (rect_of.call(0) as Rect2).get_center() + Vector2(0, -30)
	assert_float(puffs[0].distance_to(coffee)).is_less(1.0)


## A payout that prints no line still flies its chip (#86 v6): Cheese after Bread pays its base
## plus its own +4 bonus, so its item and bonus lines already add up and add_step returns null
## for its payout; the chip flies to Cheese's last line, which stays shown.
## Bread, plain, flies its own: two items, two chips.
func test_a_payout_that_prints_no_line_still_flies_its_chip() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["bread", "cheese"])
	var chips: Array[String] = []
	var on_added: Callable = func(node: Node) -> void:
		if ReceiptFly.is_chip(node):
			chips.append(((node as Control).get_child(0) as Label).text)
	screen._overlay.child_entered_tree.connect(on_added)
	var result: ScoreResult = screen.run.preview()
	var cheese: int = -1
	for step: ScoreStep in result.steps:
		if step.slot == 1 and step.step_type == ScoreStep.StepType.PAYOUT:
			cheese = step.value
	var count_up: CountUp = screen._count_up
	count_up.play(
		result, screen._row_views, ShiftScreen._names(screen.run.row), 1, CountUpContext.new()
	)
	await _played(screen)
	screen._overlay.child_entered_tree.disconnect(on_added)
	assert_array(chips).is_equal(["+€5", ReceiptFly.amount_text(cheese)])
	var last: Control = screen._count_up._beats._last_lines.get(1) as Control
	assert_object(last).is_not_null()
	assert_float(last.modulate.a).is_equal(1.0)


## The count-up's best so far is the best total of the run's earlier shifts, never the shift
## being counted, which RunState.checkout() has already recorded.
func test_the_best_so_far_leaves_out_the_shift_being_counted() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	screen._on_checkout_pressed()
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	await _count_up_end(screen)
	# Shift 1 totals 109, yet its count-up measured against the €45 floor.
	assert_int(screen.run.history.size()).is_equal(1)
	assert_int(screen.run.history[0].total).is_equal(109)
	assert_int(screen._count_up.plan.best).is_equal(45)
	screen._on_reward_skipped()
	await _place(screen, ["milk", "bread"])
	screen._on_checkout_pressed()
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	await _count_up_end(screen)
	assert_int(screen._count_up.plan.best).is_equal(109)
	assert_int(screen.count_up_context().shift).is_equal(2)
	assert_int(screen.count_up_context().best_so_far).is_equal(109)
	# The helper on its own: every record but the last.
	var history: Array[ShiftRecord] = []
	assert_int(ShiftScreen.best_earlier_total(history)).is_equal(0)
	history.append(ShiftRecord.new(1, 34, 60))
	assert_int(ShiftScreen.best_earlier_total(history)).is_equal(0)
	history.append(ShiftRecord.new(2, 35, 40))
	history.append(ShiftRecord.new(3, 53, 200))
	assert_int(ShiftScreen.best_earlier_total(history)).is_equal(60)


## The LED and CHECKOUT's key through a passed shift (#55; #80, step 9): planning shows the
## monitor's store channel (the LED blank and hidden, the projected total on the top bar's QUOTA
## chip) with CHECKOUT up; from the click SUBTOTAL with CHECKOUT held down (its off look, sunk) on
## every frame of the count-up and the dessert; TOTAL, green (met), and CHECKOUT up on the reward
## panel; the next shift's planning brings the channel back with its brief, blanks the LED (its
## digits empty, no stamp) with CHECKOUT up and pressable again.
func test_the_led_and_checkout_follow_a_passed_shift() -> void:
	var screen: ShiftScreen = await _screen()
	var led: LedDisplay = screen._led
	var checkout: RegisterKey = screen._stage.checkout_button
	await _place(screen, PASSING_ROW)
	var total: int = screen.run.preview().total
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_str(screen._quota_meter.amount_label.text).is_equal("€%d" % total)
	assert_bool(checkout.held).is_false()
	assert_int(checkout.look()).is_equal(RegisterKey.Look.NORMAL)
	screen._on_checkout_pressed()
	assert_bool(checkout.held).is_true()
	assert_str(led.caption_label().text).is_equal(LedDisplay.SUBTOTAL_TEXT)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	var key_up_frames: int = 0
	while screen._counting:
		if not checkout.held or checkout.look() != RegisterKey.Look.OFF or not checkout.is_sunk():
			key_up_frames += 1
		await get_tree().process_frame
	assert_int(key_up_frames).is_equal(0)
	assert_bool(checkout.held).is_false()
	assert_bool(screen._reward_panel.visible).is_true()
	assert_str(led.digits_label().text).is_equal(str(total))
	_assert_met(screen, true)
	# The next shift's planning: the projected total, the LED blank.
	screen._on_reward_skipped()
	await _frames(2)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_str(screen._monitor.channel.current_key()).is_equal(MonitorChannel.BRIEF_KEY)
	var shift_text: String = MonitorChannel.SHIFT_TEXT % [2, screen.run.shift_count()]
	assert_bool(screen._monitor.channel.slide_texts(0).has(shift_text)).is_true()
	assert_str(led.digits_label().text).is_empty()
	assert_bool(led.beat().stamp().is_showing()).is_false()
	assert_bool(checkout.held).is_false()
	assert_int(checkout.look()).is_equal(RegisterKey.Look.NORMAL)


## TEMPORARY (#60): the debug panel's count-up toggles show the profile's settings and the
## panel still fits the screen with them.
func test_the_debug_panel_shows_the_count_up_settings_on_screen() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: Control = screen._debug.panel
	assert_object(panel).is_not_null()
	panel.visible = true
	await _frames(4)
	var rect: Rect2 = panel.get_global_rect()
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	var checks: Array[Node] = panel.find_children("*", "CheckBox", true, false)
	assert_int(checks.size()).is_equal(2)
	for check: Node in checks:
		assert_bool((check as CheckBox).button_pressed).is_false()
		var check_rect: Rect2 = (check as Control).get_global_rect()
		assert_bool(rect.encloses(check_rect)).is_true()
	(checks[1] as CheckBox).button_pressed = true
	assert_bool(screen.profile.reduced_motion()).is_true()
	(checks[0] as CheckBox).button_pressed = true
	assert_float(screen.profile.count_up_speed()).is_equal(ProfileState.COUNT_UP_FAST)
	# A new screen reads them back from the saved profile.
	var again: ShiftScreen = await _screen()
	var reread: Array[Node] = again._debug.panel.find_children("*", "CheckBox", true, false)
	assert_bool((reread[0] as CheckBox).button_pressed).is_true()
	assert_bool((reread[1] as CheckBox).button_pressed).is_true()


# --- Helpers ---------------------------------------------------------------------------------


## Plays the count-up until its end, checking every frame up to the verdict (the final total
## shown; the slam after it is #61's). Returns {"failures": Array[String], "frames": int,
## "met_before_total": bool, "met_subtotal": the shown subtotal on the first met frame (-1 for
## none), "met_lost": the met state went away after it came, "pops": quota_met's pops,
## "last_rattle_ms": Time.get_ticks_msec() of the last frame the rattle target was off its rest x
## (-1 for none)}.
func _probe_count_up(screen: ShiftScreen) -> Dictionary:
	var count_up: CountUp = screen._count_up
	var failures: Array[String] = []
	var pops: Array[bool] = []
	count_up.quota_met.connect(func(pop: bool) -> void: pops.append(pop))
	var met_before_total: bool = false
	var met_subtotal: int = -1
	var met_lost: bool = false
	var rest: float = screen._register.position.x
	var last_rattle_ms: int = -1
	var frames: int = 0
	var newest: Control = null
	var newest_frames: int = 0
	while screen._counting and not count_up._verdict_shown:
		await get_tree().process_frame
		if count_up._verdict_shown:
			break
		frames += 1
		if Engine.time_scale != 1.0:
			failures.append("Engine.time_scale is %s" % Engine.time_scale)
		_check_on_screen(screen, failures)
		# The line being counted (#80: framed) is the one kept in view; the newest without one.
		var lines: Array[Node] = screen._receipt._lines.get_children()
		var last: Control = lines[-1] as Control if not lines.is_empty() else null
		if screen._receipt._framed_line() != null:
			last = screen._receipt._framed_line()
		if last != newest:
			newest = last
			newest_frames = 0
		newest_frames += 1
		if newest != null and newest_frames >= SCROLL_FRAMES:
			var scroll: Rect2 = screen._receipt._scroll.get_global_rect().grow(1.0)
			if not scroll.encloses(newest.get_global_rect()):
				failures.append("newest line %s outside %s" % [newest.get_global_rect(), scroll])
		if count_up._met:
			if not met_before_total:
				met_subtotal = count_up._shown_subtotal
			met_before_total = true
		elif met_before_total:
			met_lost = true
		if screen._register.position.x != rest:
			last_rattle_ms = Time.get_ticks_msec()
	await _count_up_end(screen)
	return {
		"failures": failures,
		"frames": frames,
		"met_before_total": met_before_total,
		"met_subtotal": met_subtotal,
		"met_lost": met_lost,
		"pops": pops,
		"last_rattle_ms": last_rattle_ms,
	}


## A large total's register rattle lasts the whole pause before the TOTAL line (D4): the rattle
## target is still off its rest x within the last fifth of the pause.
func _assert_rattle_fills_the_pause(count_up: CountUp, probe: Dictionary) -> void:
	var plan: CountUpPlan = count_up.plan
	assert_float(plan.final_rattle_px).is_greater(0.0)
	var still_ms: int = count_up.total_shown_ms - int(probe["last_rattle_ms"])
	prints("#60 pause", plan.pause_ms, "ms: still for the last", still_ms, "ms")
	assert_int(int(probe["last_rattle_ms"])).is_greater(0)
	assert_int(still_ms).is_less_equal(roundi(plan.pause_ms * 0.2))


## Everything the count-up shows sits inside the 1280x720 screen: its labels, stamps and payout
## chips in the overlay, the receipt, the paper; the LED's digits (their measured text,
## punched) on the monitor's paper (#80: the count layout has no glass); receipt lines unrotated.
func _check_on_screen(screen: ShiftScreen, failures: Array[String]) -> void:
	var digits: Rect2 = screen._led.digits_text_rect()
	var stage: Transform2D = screen._stage.get_global_transform()
	var paper: Rect2 = stage * ShiftStage.MONITOR_SCREEN_RECT.grow(-MonitorView.OUTLINE)
	if not paper.encloses(digits):
		failures.append("LED digits %s at %s" % [screen._led.digits_label().text, digits])
	var shown: Array[Control] = [screen._receipt]
	for child: Node in screen._overlay.get_children():
		var control: Control = child as Control
		if control != null and control.visible and not control.is_queued_for_deletion():
			shown.append(control)
	for control: Control in shown:
		var rect: Rect2 = control.get_global_rect()
		if not SCREEN_RECT.encloses(rect):
			failures.append("%s %s at %s" % [control.get_class(), _text_of(control), rect])
	for line: Node in screen._receipt._lines.get_children():
		var item: Control = line as Control
		if item.get_global_transform().get_rotation() != 0.0:
			failures.append("receipt line rotated: %s" % _text_of(item))


## Notes never drop and step only on gain beats; armed beats replay their note quietly; a stamp
## plays its sample with the note under it; three ticks per payout roll at a fixed pitch, at 0,
## 1/3 and 2/3 of the roll; the print sound at the printer speed's pitch (capped) before the
## printer feed at `feed_ms` (the reward print-out's own print comes after it, #61).
func _assert_sounds(sfx: Sfx, plan: CountUpPlan, feed_ms: int) -> void:
	var notes: Array[Dictionary] = sfx.get("notes")
	var expected_notes: int = 0
	var armed_notes: int = 0
	var rolls: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		if beat.note >= 0:
			expected_notes += 1
		if beat.kind == CountUpBeat.Kind.ARMED and beat.note >= 0:
			armed_notes += 1
		if CountUpPlan.is_payout_beat(beat) and beat.payout > 0 and beat.roll_ms > 0:
			rolls.append(beat.roll_ms)
	assert_int(notes.size()).is_equal(expected_notes)
	var quiet: int = 0
	var previous: int = -1
	for entry: Dictionary in notes:
		var index: int = int(entry["index"])
		assert_int(index).is_greater_equal(previous)
		previous = index
		if float(entry["volume_db"]) == CountUp.ARMED_NOTE_DB:
			quiet += 1
	assert_int(quiet).is_equal(armed_notes)
	assert_int(previous).is_equal(plan.gain_count - 1)
	var tick_usec: Array[int] = []
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var print_pitch: float = minf(plan.printer_speed, tuning.print_pitch_max)
	assert_float(plan.printer_speed).is_greater(1.0)
	var prints_heard: int = 0
	for entry: Dictionary in sfx.get("sounds"):
		if entry["sound"] == "tick":
			tick_usec.append(int(entry["usec"]))
			assert_float(float(entry["pitch"])).is_equal(1.0)
			assert_float(float(entry["volume_db"])).is_equal(CountUp.TICK_DB)
		elif entry["sound"] == "print" and floori(int(entry["usec"]) / 1000.0) < feed_ms:
			prints_heard += 1
			assert_float(float(entry["pitch"])).is_equal_approx(print_pitch, 0.0001)
	assert_int(prints_heard).is_greater(0)
	assert_int(tick_usec.size()).is_equal(CountUp.TICKS_PER_ROLL * rolls.size())
	# Within each roll (rolls never overlap), the ticks are a third of the roll apart, give or
	# take a frame or two (Godot carries a late frame over to the next tick).
	var gaps: Array[String] = []
	for roll: int in range(rolls.size()):
		var third_ms: float = rolls[roll] / 3.0 / plan.count_speed
		for tick: int in range(1, CountUp.TICKS_PER_ROLL):
			var at: int = roll * CountUp.TICKS_PER_ROLL + tick
			var gap_ms: float = (tick_usec[at] - tick_usec[at - 1]) / 1000.0
			gaps.append("%.0f/%.0f" % [gap_ms, third_ms])
			assert_float(gap_ms).override_failure_message(str(gaps)).is_between(
				third_ms - 25.0, third_ms + 45.0
			)
	prints("#60 tick gaps (real/planned ms):", " ".join(gaps))
	assert_int(_sounds(sfx, "bonus")).is_equal(0)
	_assert_rattle_and_armed_sounds(sfx, plan)


## #62: every armed beat plays its shimmer; every rattling payout and a large total's pause play
## a rattle take for their pixels, at the volume for their pixels (louder for more); a huge total
## rings the register bell.
func _assert_rattle_and_armed_sounds(sfx: Sfx, plan: CountUpPlan) -> void:
	var armed: int = 0
	var rattle_px: Array[float] = []
	for beat: CountUpBeat in plan.beats:
		if beat.kind == CountUpBeat.Kind.ARMED:
			armed += 1
		if CountUpPlan.is_payout_beat(beat) and beat.payout > 0 and beat.roll_ms > 0:
			if beat.rattle_px > 0.0:
				rattle_px.append(beat.rattle_px)
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	if plan.size == CountUpPlan.Size.HUGE:
		rattle_px.append(tuning.final_rattle_huge_px)
	elif plan.size == CountUpPlan.Size.LARGE:
		rattle_px.append(tuning.final_rattle_large_px)
	assert_int(_sounds(sfx, "armed")).is_equal(armed)
	var heard: Array[Dictionary] = []
	for entry: Dictionary in sfx.get("sounds"):
		if String(entry["sound"]).begins_with("rattle_"):
			heard.append(entry)
	assert_int(heard.size()).is_equal(rattle_px.size())
	for index: int in range(mini(heard.size(), rattle_px.size())):
		var px: float = rattle_px[index]
		assert_str(String(heard[index]["sound"])).is_equal(_rattle_take(px))
		var volume: float = lerpf(
			CountUp.RATTLE_QUIET_DB, 0.0, clampf(px / CountUp.RATTLE_FULL_PX, 0.0, 1.0)
		)
		assert_float(float(heard[index]["volume_db"])).is_equal_approx(volume, 0.01)
	var bell: int = 1 if plan.size == CountUpPlan.Size.HUGE else 0
	assert_int(_sounds(sfx, "register_bell")).is_equal(bell)


static func _rattle_take(px: float) -> String:
	if px >= CountUp.RATTLE_LARGE_PX:
		return "rattle_l"
	return "rattle_m" if px >= CountUp.RATTLE_MEDIUM_PX else "rattle_s"


## #62: the register rattle's take and volume for a shake of some pixels, written out: rattle_s
## under 6 px, rattle_m from 6, rattle_l from 10; from -10 dB at 0 px up to 0 dB at 12 px.
func test_a_stronger_rattle_plays_a_bigger_take_louder() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	for px: float in [3.0, 6.0, 10.0, 12.0, 16.0]:
		screen._count_up._beats.play_rattle(px)
	var takes: Array[String] = []
	var volumes: Array[float] = []
	for entry: Dictionary in sfx.get("sounds"):
		takes.append(String(entry["sound"]))
		volumes.append(float(entry["volume_db"]))
	assert_array(takes).is_equal(["rattle_s", "rattle_m", "rattle_l", "rattle_l", "rattle_l"])
	var expected: Array[float] = [-7.5, -5.0, -10.0 / 6.0, 0.0, 0.0]
	for index: int in range(expected.size()):
		assert_float(volumes[index]).is_equal_approx(expected[index], 0.01)


## #62, Q5: the next shift's notice prints with the printer's feed (at the printer's pitch), and
## the clerk's stamp lands just after it, last of all.
func test_the_notice_prints_then_its_stamp_lands() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, ["milk"])
	var count_up: CountUp = screen._count_up
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		1,
		CountUpContext.new(1, 0),
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(screen.run.upgrades),
		screen._inspection_tag.sources(screen.run.inspections),
		InspectionTag.names(screen.run.inspections),
		"Next shift: test notice"
	)
	await _played(screen)
	var sounds: Array[Dictionary] = sfx.get("sounds")
	assert_int(sounds.size()).is_greater(2)
	var stamp: Dictionary = sounds[-1]
	var feed: Dictionary = sounds[-2]
	assert_str(String(stamp["sound"])).is_equal("stamp_notice")
	assert_str(String(feed["sound"])).is_equal("print")
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var pitch: float = minf(count_up.plan.printer_speed, tuning.print_pitch_max)
	assert_float(float(feed["pitch"])).is_equal_approx(pitch, 0.0001)
	var gap_ms: float = (int(stamp["usec"]) - int(feed["usec"])) / 1000.0
	assert_float(gap_ms).is_between(CountUpDessert.NOTICE_STAMP_GAP * 1000.0 - 5.0, 200.0)


## Records the count-up's rides as [bag_slot, scan_slot, ride_ms, Time.get_ticks_usec(), the
## number of beats started so far], and its count_started in _count_starts.
func _record_rides(count_up: CountUp) -> Array[Array]:
	var rides: Array[Array] = []
	var started: Array[int] = [0]
	_count_starts.clear()
	count_up.count_started.connect(
		func(views: Array[CardView]) -> void: _count_starts.append([views.size(), rides.size()])
	)
	count_up.beat_started.connect(
		func(_b: CountUpBeat, _s: ScoreStep, _l: String, _v: CardView, _i: int) -> void:
			started[0] += 1
	)
	count_up.ride.connect(
		func(bag: int, scan: int, ms: int) -> void:
			rides.append([bag, scan, ms, Time.get_ticks_usec(), started[0]])
	)
	return rides


## One ride before each scan group's first beat, the item before it bagging (#86 v6), with the
## plan's ride gap (none for item 0 in the first cell), then the last item's bag hop after the
## last beat; every item scanned in turn. count_started came once, before the first ride, with
## a view for each item scanned.
func _assert_rides(rides: Array[Array], plan: CountUpPlan) -> void:
	var items: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.opens_slot:
			items += 1
	assert_array(_count_starts).is_equal([[items, 0]])
	var expected: Array[Array] = []
	var last: int = -1
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		if beat.opens_slot:
			expected.append([last, beat.scan_slot, beat.ride_ms, index])
			last = beat.scan_slot
	expected.append([last, -1, plan.bag_ms, plan.beats.size()])
	assert_int(rides.size()).is_equal(expected.size())
	for index: int in range(mini(rides.size(), expected.size())):
		# [bag, scan, ms] and the beats started before it: each ride comes before its beat.
		var seen: Array = [rides[index][0], rides[index][1], rides[index][2], rides[index][4]]
		assert_array(seen).override_failure_message(str(rides)).is_equal(expected[index])
	# The reference row's seven items, in turn, the first already in the scanner's cell.
	if plan.step_count == 27:
		var scans: Array[int] = []
		for ride: Array in rides:
			scans.append(int(ride[1]))
		assert_array(scans).is_equal([0, 1, 2, 3, 4, 5, 6, -1])


## The met state after a count-up: the LED says TOTAL in its gold (met or not, #86 v6), and the
## monitor's € tank is full and overflowing once met (the LED's reading said so).
func _assert_met(screen: ShiftScreen, met: bool) -> void:
	var color: Color = screen._led.digits_label().get_theme_color("font_color")
	assert_str(screen._led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	assert_bool(screen._count_up._met).is_equal(met)
	assert_that(color).is_equal(LedDisplay.COUNT_DIGITS_COLOR)
	assert_bool(screen._monitor.tank().is_overflowing()).is_equal(met)


## Plays `result` on the screen's row against `quota`, tapped twice (the count and the dessert
## at skip speed), as a shift-1 count-up under the screen's receipt header.
func _play_tapped(screen: ShiftScreen, result: ScoreResult, quota: int) -> void:
	var count_up: CountUp = screen._count_up
	count_up.play(
		result,
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header()),
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(screen.run.upgrades),
		screen._inspection_tag.sources(screen.run.inspections),
		InspectionTag.names(screen.run.inspections)
	)
	count_up._tap(Time.get_ticks_msec())
	count_up._tap(Time.get_ticks_msec())


func _played(screen: ShiftScreen) -> void:
	await Rush.played(screen._count_up)  # One tap (none if tapped): no caller times the count.


func _assert_full_receipt(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var notice: String = InspectionTag.next_notice(run.next_inspection)
	await _assert_receipt_of(screen, run.last_result, run.quota(), notice)


## The count-up's receipt is `result`'s, line for line, under the shift's header (#75, the
## planning stub's), ended by the dessert against `quota` (with `notice` under the tear when
## there is one), every line fully shown (once the last fades, which overlap the printer feed,
## have ended) and unrotated.
func _assert_receipt_of(
	screen: ShiftScreen, result: ScoreResult, quota: int, notice: String = ""
) -> void:
	await _lines_shown(screen._receipt)
	var run: RunState = screen.run
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		result,
		ShiftScreen._names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections),
		screen.receipt_header()
	)
	assert_str(_lines(expected)[0]).is_equal(ReceiptView.HEADER_TEXT + " | ")
	expected.show_shift_end(result.total, quota, notice)
	assert_array(_lines(screen._receipt)).is_equal(_lines(expected))
	for line: Node in screen._receipt._lines.get_children():
		assert_float((line as CanvasItem).modulate.a).is_equal(1.0)
		assert_float((line as Control).rotation).is_equal(0.0)


## Waits until every receipt line has faded in, or half a second.
func _lines_shown(receipt: ReceiptView) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 500:
		var fading: bool = false
		for line: Node in receipt._lines.get_children():
			fading = fading or (line as CanvasItem).modulate.a < 1.0
		if not fading:
			return
		await get_tree().process_frame


## A receipt's lines as text ("left | right"; "---" for the rule above the total).
static func _lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HSeparator:
			lines.append("---")
			continue
		var texts: PackedStringArray = PackedStringArray()
		for label: Node in line.get_children():
			texts.append((label as Label).text)
		lines.append(" | ".join(texts))
	return lines


static func _text_of(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		return '"%s"' % label.text
	return str(control.name)


## A recording Sfx in place of the screen's, for the count-up.
func _recording_sfx(screen: ShiftScreen) -> Sfx:
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	return sfx


static func _sounds(sfx: Sfx, sound: String) -> int:
	var count: int = 0
	for entry: Dictionary in sfx.get("sounds"):
		if entry["sound"] == sound:
			count += 1
	return count


## #86 v6: the count-up itself moves neither the belt nor the items (the belt ride does, on its
## rides): the slats and every item stay put through the count. A ride's gap is a count-up wait:
## a hit-stop freezes it, so the item's beat never starts while it lasts.
func test_the_rides_wait_on_the_count_and_move_nothing_themselves() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	var belt: BeltPanel = screen._stage.belt
	var start: int = belt.frame()
	var item_rests: Array[Vector2] = []
	for view: CardView in screen._row_views:
		item_rests.append(view.global_position)
	# The count-up alone: the belt ride (which plays the rides on the belt) stops following it.
	count_up.ride.disconnect(screen._ride._on_ride)
	var rides: Array[Array] = _record_rides(count_up)
	var started: Array[int] = [0]
	count_up.beat_started.connect(
		func(_b: CountUpBeat, _s: ScoreStep, _l: String, _v: CardView, _i: int) -> void:
			started[0] += 1
	)
	Rush.speed_up(_runner, 2.0)  # Untimed; a ride's gap still lasts many frames for the stop.
	screen._on_checkout_pressed()
	var forced: bool = false
	var failures: Array[String] = []
	while screen._counting:
		await get_tree().process_frame
		if belt.frame() != start:
			failures.append("the belt moved")
		if not forced and rides.size() == 2:
			forced = true
			# A hit-stop as _land sets one, during the 2nd item's ride: its beat waits.
			var started_then: int = started[0]
			count_up._hit_stop_left_ms = 60000.0
			count_up._hit_stop_us = Time.get_ticks_usec()
			count_up._apply_speed()
			await _frames(5)
			if started[0] != started_then:
				failures.append("a beat started in a hit-stop during a ride")
			count_up._hit_stop_left_ms = 0.0
			count_up._apply_speed()
	assert_bool(forced).is_true()
	assert_array(failures.slice(0, 5)).override_failure_message(str(failures)).is_empty()
	for index: int in range(item_rests.size()):
		assert_vector(screen._row_views[index].global_position).is_equal(item_rests[index])
	_assert_rides(rides, count_up.plan)


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


func _count_up_end(screen: ShiftScreen) -> void:
	while screen._counting:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for frame: int in range(count):
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


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## #86 v6: the quota's reward runs in real time through the count's hold at the ding (its
## hit-stop freezes the count's tweens): the gold flies (TankBurst), the monitor shakes, the tank
## bursts, the bay's light turns green and the SPEND MET stamp slams on the paper while the
## subtotal stands still; the count goes on after.
func test_the_burst_runs_in_real_time_through_the_quota_hold() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	var monitor: MonitorView = screen._monitor
	var burst: TankBurst = screen._stage.tank_burst
	var pops: Array[bool] = []
	count_up.quota_met.connect(func(pop: bool) -> void: pops.append(pop))
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		40,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	)
	var started: int = Time.get_ticks_msec()
	while pops.is_empty() and Time.get_ticks_msec() - started < 10000:
		await get_tree().process_frame
	assert_array(pops).is_equal([true])
	await get_tree().process_frame
	assert_float(count_up._hit_stop_left_ms).is_greater(0.0)
	var held: int = count_up._shown_subtotal
	var earlier: Array[Rect2] = burst.drawn_rects(TankBurst.Layer.PARTICLES)
	assert_bool(monitor.tank().is_bursting()).is_true()
	assert_that(monitor.bay().light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
	var shaken: bool = false
	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 330:
		shaken = shaken or monitor.position != ShiftStage.MONITOR_RECT.position
		await get_tree().process_frame
	# Still held, yet everything of the reward moved.
	assert_float(count_up._hit_stop_left_ms).is_greater(0.0)
	assert_int(count_up._shown_subtotal).is_equal(held)
	assert_bool(shaken).is_true()
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_not_equal(earlier)
	var stamp: MetStamp = screen._led.beat().stamp()
	assert_bool(stamp.is_showing()).is_true()
	var paper: Rect2 = Rect2(
		screen._stage.get_global_rect().position + MonitorView.PAPER_RECT.position,
		MonitorView.PAPER_RECT.size
	)
	assert_bool(paper.grow(MonitorView.STAMP_SHAKE).encloses(stamp.drawn_rect())).is_true()
	count_up._tap(Time.get_ticks_msec())
	count_up._tap(Time.get_ticks_msec())
	await _played(screen)
	assert_array(pops).is_equal([true])
