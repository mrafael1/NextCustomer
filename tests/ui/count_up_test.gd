extends GdUnitTestSuite
## The count-up playing its CountUpPlan on the real shift screen (#60): the full reference row
## (Eggs, Bread, Milk, Multipack, Milk x3 with Coupon engine, Slot engine and a Spot check) in
## about 4-6 s at normal speed, every frame inside the 1280x720 screen with Engine.time_scale
## untouched; notes that never drop, quiet armed notes and three ticks per payout; markers for
## every landing; the quota chip; the Fast setting and reduced motion; shakes that end where they
## started; and the run context (the best so far leaves out the shift being counted) and the
## count_up event's fields. The real saves and logs are never touched: both go to a temporary
## folder.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
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


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	# The game's window, not the headless default (1280x1280).
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The full reference row at normal speed, frame by frame: about 4-6 s from the click to the
## total, everything on screen, the newest line in the receipt's scroll area, lines unrotated,
## Engine.time_scale at 1; notes climb, armed notes are quiet, three ticks per payout; one
## marker per landing, made together at the armed beat and gone after the row; the ding and a
## chip that stays; the rattle target back at its origin; the receipt equal to show_result's;
## and the count_up event's new fields.
func test_the_full_row_counts_up_on_screen_in_four_to_six_seconds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _full_row(screen)
	var rest: float = screen._register.position.x
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
	assert_int(count_up_ms).is_between(4000, 6600)
	assert_int(count_up_ms).is_between(plan.planned_ms - 150, plan.planned_ms + 900)
	assert_float(float(event["base_speed"])).is_equal(1.0)
	assert_float(float(event["speed_setting"])).is_equal(1.0)
	assert_bool(event["reduced_motion"]).is_false()
	assert_int(int(event["step_count"])).is_equal(27)
	assert_int(int(event["planned_ms"])).is_equal(plan.planned_ms)

	_assert_sounds(sfx, plan, count_up.printer_feed_ms)
	_assert_markers(screen, probe)
	# Shift 1's quota (34) is reached mid-row: the ding, then a chip that stays.
	assert_int(plan.ding_beat).is_greater_equal(0)
	assert_int(_sounds(sfx, "ding")).is_equal(1)
	assert_bool(probe["chip_before_total"]).is_true()
	# The chip came at the ding beat, the subtotal past the quota but short of the total, and
	# stayed on every frame after.
	var quota: int = screen.run.quota()
	assert_int(quota).is_equal(34)
	assert_int(int(probe["chip_subtotal"])).is_between(quota, plan.total - 1)
	assert_int(int(probe["chip_subtotal"])).is_equal(plan.beats[plan.ding_beat].subtotal)
	assert_bool(probe["chip_lost"]).is_false()
	await _assert_chip(screen, true)
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
	# Hit-stops and the pause before the total are not sped up by base_speed (D6): the real
	# count-up takes as long as planned, no shorter.
	assert_int(int(event["count_up_ms"])).is_between(plan.planned_ms - 150, plan.planned_ms + 900)
	_assert_rattle_fills_the_pause(screen._count_up, probe)
	assert_float(float(event["base_speed"])).is_equal(1.5)
	assert_float(float(event["speed_setting"])).is_equal(1.5)
	await _assert_full_receipt(screen)


## Reduced motion: no node is ever shaken off its place (the rattle target, the cards, the
## loyalty-card boxes), markers fade in where they wait instead of flying, no rattle before the
## total, and the same receipt.
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
		var tokens: EffectTokens = screen._count_up._tokens
		for marker: EffectMarker in tokens.markers.values():
			var off: float = marker.global_position.distance_to(marker.parked_position())
			# Following its item, at most a frame behind its lift (a flight starts an item away).
			if not marker.following or off > ItemView.LIFT + 2.0:
				moved.append("a marker flew (%s px off)" % off)
	await _count_up_end(screen)
	assert_int(frames).is_greater(30)
	assert_array(moved).override_failure_message("\n".join(moved.slice(0, 10))).is_empty()
	var plan: CountUpPlan = screen._count_up.plan
	assert_bool(plan.reduced_motion).is_true()
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


## The quota met on the last payout: no ding, and the colour and chip arrive with the TOTAL line.
## Never reached: no chip, no colour change. Tapped through, the receipt is still the whole one.
func test_the_chip_comes_with_the_total_on_a_last_payout_crossing_and_never_on_a_fail() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	assert_int(result.total).is_equal(110)
	var count_up: CountUp = screen._count_up
	var chip_before_total: bool = false
	_play_tapped(screen, result, 110)
	while count_up._playing:
		await get_tree().process_frame
		if not count_up._verdict_shown and count_up._quota_chip != null:
			chip_before_total = true
	assert_bool(count_up.plan.chip_at_total).is_true()
	assert_bool(chip_before_total).is_false()
	assert_int(_sounds(sfx, "ding")).is_equal(0)
	await _assert_chip(screen, true)
	await _assert_receipt_of(screen, result, 110)

	_play_tapped(screen, result, 111)
	while count_up._playing:
		await get_tree().process_frame
		assert_object(count_up._quota_chip).is_null()
	assert_bool(count_up.plan.quota_reached).is_false()
	await _assert_chip(screen, false)
	await _assert_receipt_of(screen, result, 111)


## The value badge is the item's paid chip (#80, step 7): every item's shows "€N", a denied item
## (the Spot check's €0) on its muted face; each settles into the small face as the next item is
## scanned, so earlier chips stay, and the last one as the total shows; and after every scan's
## lift and drop each chip is back at its face's rest y over the item.
func test_a_denied_card_shows_the_muted_plaque_and_every_badge_rests() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	var plan: CountUpPlan = CountUpPlan.build(
		result.steps, 1, CountUpContext.new(), load(CountUp.TUNING_PATH)
	)
	var denied: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		if beat.kind == CountUpBeat.Kind.DENIED:
			denied.append(result.steps[beat.steps[0]].slot)
	assert_int(denied.size()).is_equal(1)
	# As the CHECKOUT click does: the chips settle, then follow the beats (BeltChips).
	screen._belt_chips.begin_count(result, screen._row_views, false)
	_play_tapped(screen, result, 110)
	await _played(screen)
	await _frames(30)
	for slot: int in range(screen._row_views.size()):
		var view: ItemView = screen._row_views[slot] as ItemView
		assert_object(view).is_not_null()
		var plaque: PayoutPlaque = view.badge as PayoutPlaque
		assert_bool(plaque.visible).override_failure_message(str(slot)).is_true()
		assert_str(plaque.text).is_equal(PayoutPlaque.text_for(result.payouts[slot]))
		assert_bool(plaque.is_current()).override_failure_message(str(slot)).is_false()
		assert_bool(plaque.is_muted()).override_failure_message(str(slot)).is_equal(
			slot in denied or result.payouts[slot] == 0
		)
		assert_float(view.badge.position.y).override_failure_message(str(slot)).is_equal(
			view.badge_rest_y()
		)


## An armed effect that fizzles (a Coffee with no Breakfast after it) leaves its pip on the
## card, greyed for good.
func test_a_fizzled_effect_leaves_a_grey_pip() -> void:
	var screen: ShiftScreen = await _screen()
	var placed: Array[String] = ["coffee", "banana", "cheese"]
	await _place(screen, placed)
	var result: ScoreResult = screen.run.preview()
	var fizzles: Array[int] = []
	var plan: CountUpPlan = CountUpPlan.build(
		result.steps, 1, CountUpContext.new(), load(CountUp.TUNING_PATH)
	)
	for index: int in range(plan.beats.size()):
		var step: ScoreStep = result.steps[plan.beats[index].steps[0]]
		if plan.beats[index].kind == CountUpBeat.Kind.FIZZLE and step.text == "Coffee bonus":
			fizzles.append(index)
	assert_int(fizzles.size()).is_equal(1)
	_play_tapped(screen, result, 1)
	await _played(screen)
	var tokens: EffectTokens = screen._count_up._tokens
	assert_int(tokens.pips.size()).is_equal(1)
	var pip: EffectMarker = tokens.pips.values()[0]
	assert_bool(is_instance_valid(pip)).is_true()
	assert_bool(pip.is_spent()).is_true()
	assert_bool(pip.has_icon()).is_true()
	assert_object(pip.target).is_same(screen._row_views[0].body)
	assert_bool(SCREEN_RECT.encloses(pip.get_global_rect())).is_true()
	# The next count-up starts clean.
	_play_tapped(screen, result, 1)
	await get_tree().process_frame
	assert_bool(is_instance_valid(pip) and not pip.is_queued_for_deletion()).is_false()
	await _played(screen)


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


## The LED and the TOTAL key through a passed shift (#55): PROJECTED in planning with the key
## up; from the click SUBTOTAL with the key down on every frame of the count-up and the
## dessert; TOTAL, green with its chip, and the key up on the reward panel; the next shift's
## planning shows PROJECTED and hides the chip (its anchor is empty) with the key still up.
func test_the_led_and_the_total_key_follow_a_passed_shift() -> void:
	var screen: ShiftScreen = await _screen()
	var led: LedDisplay = screen._led
	var cabinet: RegisterCabinet = screen._cabinet
	await _place(screen, PASSING_ROW)
	var total: int = screen.run.preview().total
	assert_str(led.caption()).is_equal(LedDisplay.PROJECTED_TEXT)
	assert_str(led.digits_label().text).is_equal("€%d" % total)
	assert_bool(cabinet.is_total_down()).is_false()
	screen._on_checkout_pressed()
	assert_bool(cabinet.is_total_down()).is_true()
	assert_str(led.caption()).is_equal(LedDisplay.SUBTOTAL_TEXT)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	var key_up_frames: int = 0
	while screen._counting:
		if not cabinet.is_total_down():
			key_up_frames += 1
		await get_tree().process_frame
	assert_int(key_up_frames).is_equal(0)
	assert_bool(cabinet.is_total_down()).is_false()
	assert_bool(screen._reward_panel.visible).is_true()
	assert_str(led.digits_label().text).is_equal("€%d" % total)
	await _assert_chip(screen, true)
	var chip: QuotaChip = screen._count_up._quota_chip
	# The next shift's planning: the projected total, and the chip goes with its anchor.
	screen._on_reward_skipped()
	await _frames(2)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_str(led.caption()).is_equal(LedDisplay.PROJECTED_TEXT)
	assert_bool(led.quota_anchor().has_area()).is_false()
	assert_bool(chip.visible).is_false()
	assert_bool(cabinet.is_total_down()).is_false()


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
## "marker_frames": {landing beat: first frame seen}, "chip_before_total": bool,
## "chip_subtotal": the shown subtotal on the chip's first frame (-1 for none), "chip_lost": the
## chip went away after it came, "last_rattle_ms": Time.get_ticks_msec() of the last frame the
## rattle target was off its rest x (-1 for none)}.
func _probe_count_up(screen: ShiftScreen) -> Dictionary:
	var count_up: CountUp = screen._count_up
	var failures: Array[String] = []
	var marker_frames: Dictionary[int, int] = {}
	var chip_before_total: bool = false
	var chip_subtotal: int = -1
	var chip_lost: bool = false
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
		if count_up._tokens != null:
			for landing: int in count_up._tokens.markers.keys():
				if not marker_frames.has(landing):
					marker_frames[landing] = frames
		if count_up._quota_chip != null:
			if not chip_before_total:
				chip_subtotal = count_up._shown_subtotal
			chip_before_total = true
		elif chip_before_total:
			chip_lost = true
		if screen._register.position.x != rest:
			last_rattle_ms = Time.get_ticks_msec()
	await _count_up_end(screen)
	return {
		"failures": failures,
		"frames": frames,
		"marker_frames": marker_frames,
		"chip_before_total": chip_before_total,
		"chip_subtotal": chip_subtotal,
		"chip_lost": chip_lost,
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


## Everything the count-up shows sits inside the 1280x720 screen: its labels, stamps, markers,
## pips and chip in the overlay, the receipt, the paper; the LED's digits (their measured text,
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
		var third_ms: float = rolls[roll] / 3.0 / plan.base_speed
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
		screen._count_up._play_rattle(px)
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


## One marker per landing, all of one armed beat made in the same frame, and none left after
## the row (nor a pip still waiting).
func _assert_markers(screen: ShiftScreen, probe: Dictionary) -> void:
	var plan: CountUpPlan = screen._count_up.plan
	var seen: Dictionary = probe["marker_frames"]
	var landings: int = 0
	var armed_frames: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		if beat.kind != CountUpBeat.Kind.ARMED or beat.targets.is_empty():
			continue
		var frame: int = int(seen.get(beat.targets[0], -1))
		assert_int(frame).is_greater(0)
		# Made at its own armed beat: after the markers of every earlier armed beat.
		if not armed_frames.is_empty():
			assert_int(frame).is_greater(armed_frames[-1])
		armed_frames.append(frame)
		for target: int in beat.targets:
			landings += 1
			assert_int(int(seen.get(target, -1))).is_equal(frame)
			assert_int(plan.beats[target].armed_from).is_greater_equal(0)
	# The reference row: Eggs lands once, Multipack three times.
	assert_int(armed_frames.size()).is_equal(2)
	assert_int(landings).is_equal(4)
	assert_int(seen.size()).is_equal(landings)
	assert_int(screen._count_up._tokens.markers.size()).is_equal(0)
	for child: Node in screen._overlay.get_children():
		var marker: EffectMarker = child as EffectMarker
		if marker != null and not marker.is_queued_for_deletion():
			assert_bool(marker.has_icon() and marker.is_spent()).is_true()


## The chip after a count-up: there (on the LED's quota line, inside the LED and the screen,
## covering "QUOTA €N", saying QUOTA with its icon) and the LED's total green, or neither. The
## LED says TOTAL.
func _assert_chip(screen: ShiftScreen, met: bool) -> void:
	var chip: QuotaChip = screen._count_up._quota_chip
	var color: Color = screen._led.digits_label().get_theme_color("font_color")
	assert_str(screen._led.caption()).is_equal(LedDisplay.TOTAL_TEXT)
	if not met:
		assert_object(chip).is_null()
		assert_that(color).is_equal(LedDisplay.COUNT_DIGITS_COLOR)
		return
	assert_object(chip).is_not_null()
	assert_bool(is_instance_valid(chip)).is_true()
	await _frames(2)
	assert_bool(chip.visible).is_true()
	assert_vector(chip.scale).is_equal(Vector2.ONE)
	assert_that(color).is_equal(Palette.GOOD)
	var texts: Array[Node] = chip.find_children("*", "Label", true, false)
	assert_str((texts[0] as Label).text).is_equal(QuotaChip.TEXT)
	assert_int(chip.find_children("*", "Line2D", true, false).size()).is_equal(1)
	var rect: Rect2 = chip.get_global_rect()
	var anchor: Rect2 = screen._led.quota_anchor()
	var quota_line: Rect2 = screen._led.quota_label().get_global_rect()
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	# Inside the LED and its chip room on the quota line, over "QUOTA €N".
	var led: Rect2 = screen._led.get_global_rect()
	assert_bool(led.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(anchor.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_float(rect.end.x).is_equal_approx(anchor.end.x, 0.5)
	assert_float(rect.get_center().y).is_equal_approx(quota_line.get_center().y, 1.0)
	# It covers the right-aligned "QUOTA €N" (ending at the anchor's end, as the chip does): it
	# starts left of the text's measured width.
	var width: float = screen._led.quota_text_width()
	(
		assert_float(rect.position.x)
		. override_failure_message("chip %s, text width %s" % [rect, width])
		. is_less_equal(quota_line.end.x - width)
	)


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
	while screen._count_up._playing:
		await get_tree().process_frame


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
	var marker: EffectMarker = control as EffectMarker
	if marker != null:
		return '"%s"' % marker.shown_text()
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
