extends GdUnitTestSuite
## The count-up's tap and hold on the real shift screen (full build plan 6.2, plan section 8 since
## v0.20): a press of Space or the mouse released before CountUp.HOLD_THRESHOLD_MS is a tap that
## speeds the count to the verdict, a second tap skips the dessert, and a press held past the
## threshold fast-forwards. The checkout click and clicks on buttons that can be pressed are
## neither. Skips only speed tweens up, so the receipt ends up the same. Input goes through the
## scene runner (the count-up reads the input events); the checkout itself is sent to the screen's
## handler. A tapped or held count plays the same step-driven sounds as an untouched one (#62).

const SCREEN := "res://ui/shift_screen.tscn"
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Game time runs this much faster (Rush.speed_up): the tweens' beats and waits shrink, while the
## press windows (CountUp.HOLD_THRESHOLD_MS, CHECKOUT_DOUBLE_CLICK_MS), the hit-stops and the
## pause stay real, so a 7-item count still lasts a few seconds: long enough for every press to
## land mid-count. A tapped count shrinks by the same factor, so "clearly faster" keeps its margin.
const TIME_FACTOR := 4.0
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## The count-up's reference row (with Coupon engine, Slot engine and a Spot check): scans, notes,
## bonuses, stamps, echoes, armed shimmers, a denied, rattles, the ding and the register bell.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## Low enough for the ding to sound mid-row.
const SOUND_QUOTA := 50

var _folder: String = ""
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	Rush.restore()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Without input nothing is skipped or fast-forwarded, and the receipt is the whole result's.
func test_no_input_skips_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	await screen._on_checkout_pressed()
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_false()
	assert_int(int(count_up["skip_at_ms"])).is_equal(-1)
	assert_bool(count_up["fast_forward_used"]).is_false()
	assert_bool(count_up["dessert_skipped"]).is_false()
	await _assert_full_receipt(screen)


## A tap speeds the count to the verdict: the same row counts up clearly faster, the dessert still
## plays at normal speed, and the receipt is complete.
func test_a_tap_speeds_the_count_to_the_verdict() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	await screen._on_checkout_pressed()
	var untouched: int = int(_last_event("count_up")["count_up_ms"])
	screen._on_reward_skipped()
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(3)
	await _tap()
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_true()
	assert_int(int(count_up["skip_at_ms"])).is_between(0, int(count_up["count_up_ms"]))
	assert_bool(count_up["fast_forward_used"]).is_false()
	assert_bool(count_up["dessert_skipped"]).is_false()
	assert_int(int(count_up["count_up_ms"]) * 2).is_less(untouched)
	await _assert_full_receipt(screen)


## A second tap skips the dessert too; every line still prints.
func test_a_second_tap_skips_the_dessert() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(3)
	await _tap()
	await _frames(2)
	await _tap()
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_true()
	assert_bool(count_up["dessert_skipped"]).is_true()
	assert_bool(count_up["fast_forward_used"]).is_false()
	await _assert_full_receipt(screen)


## A press held past the threshold fast-forwards; it is not a tap.
func test_a_hold_fast_forwards_and_is_not_a_tap() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(3)
	_runner.simulate_key_press(KEY_SPACE)
	await _wall_ms(CountUp.HOLD_THRESHOLD_MS + 300)
	_runner.simulate_key_release(KEY_SPACE)
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["fast_forward_used"]).is_true()
	assert_bool(count_up["skip_used"]).is_false()
	assert_int(int(count_up["skip_at_ms"])).is_equal(-1)
	await _assert_full_receipt(screen)


## The checkout click, still held when the count-up starts, is neither a tap when released quickly
## nor a hold when held long.
func test_the_checkout_click_is_neither_a_tap_nor_a_hold() -> void:
	var screen: ShiftScreen = await _screen()
	_runner.set_mouse_position(screen._receipt.get_global_rect().get_center())
	_place_row(screen)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	screen._on_checkout_pressed()
	await _frames(2)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var quick: Dictionary = _last_event("count_up")
	assert_bool(quick["skip_used"]).is_false()
	assert_bool(quick["fast_forward_used"]).is_false()

	screen._on_reward_skipped()
	_place_row(screen)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	screen._on_checkout_pressed()
	await _wall_ms(CountUp.HOLD_THRESHOLD_MS + 300)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var held: Dictionary = _last_event("count_up")
	assert_bool(held["skip_used"]).is_false()
	assert_bool(held["fast_forward_used"]).is_false()


## A click on a button that can be pressed during the count-up (Deck, Export log) is neither.
## Headless runs keep the mouse at the window's corner and never move the hover, so a stand-in
## button sits there.
func test_clicks_on_buttons_are_neither() -> void:
	var screen: ShiftScreen = await _screen()
	var button: Button = Button.new()
	button.size = Vector2(40, 40)
	screen.add_child(button)
	button.global_position = Vector2.ZERO
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(2)
	screen.get_viewport().update_mouse_cursor_state()
	assert_object(screen.get_viewport().gui_get_hovered_control()).is_same(button)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await _frames(2)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _frames(2)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await _wall_ms(CountUp.HOLD_THRESHOLD_MS + 300)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_false()
	assert_bool(count_up["fast_forward_used"]).is_false()


## A press on a disabled button counts: CHECKOUT stays under the cursor, disabled, during its own
## count, and a click there does nothing else. A quick one is a tap, a long one a hold.
func test_a_press_on_a_disabled_button_counts() -> void:
	var screen: ShiftScreen = await _screen()
	var button: Button = Button.new()
	button.size = Vector2(40, 40)
	button.disabled = true
	screen.add_child(button)
	button.global_position = Vector2.ZERO
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(2)
	screen.get_viewport().update_mouse_cursor_state()
	assert_object(screen.get_viewport().gui_get_hovered_control()).is_same(button)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await _frames(2)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var tapped: Dictionary = _last_event("count_up")
	assert_bool(tapped["skip_used"]).is_true()
	assert_bool(tapped["fast_forward_used"]).is_false()

	screen._on_reward_skipped()
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(2)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await _wall_ms(CountUp.HOLD_THRESHOLD_MS + 300)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var held: Dictionary = _last_event("count_up")
	assert_bool(held["fast_forward_used"]).is_true()
	assert_bool(held["skip_used"]).is_false()


## Double-clicking CHECKOUT is one intent to check out: the second click, a double-click press on
## the now disabled button right after the start, is neither a tap nor a hold.
func test_the_second_click_of_a_checkout_double_click_is_ignored() -> void:
	var screen: ShiftScreen = await _screen()
	_disabled_button_at_the_mouse(screen)
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(1)
	screen.get_viewport().update_mouse_cursor_state()
	assert_bool(screen.get_viewport().gui_get_hovered_control() is Button).is_true()
	assert_bool(screen._counting).is_true()
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT, true)
	var since_start: int = Time.get_ticks_msec() - screen._count_up._presses.started_ms
	assert_int(since_start).is_less(CountUp.CHECKOUT_DOUBLE_CLICK_MS)
	await _frames(2)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_false()
	assert_int(int(count_up["skip_at_ms"])).is_equal(-1)
	assert_bool(count_up["fast_forward_used"]).is_false()
	await _assert_full_receipt(screen)


## A double-click press well after the start is a real tap (the second of two quick taps is a
## double-click too).
func test_a_late_double_click_press_is_a_tap() -> void:
	var screen: ShiftScreen = await _screen()
	_disabled_button_at_the_mouse(screen)
	_place_row(screen)
	screen._on_checkout_pressed()
	await _wall_ms(CountUp.CHECKOUT_DOUBLE_CLICK_MS + 100)
	screen.get_viewport().update_mouse_cursor_state()
	assert_bool(screen.get_viewport().gui_get_hovered_control() is Button).is_true()
	assert_bool(screen._counting).is_true()
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var count_up: Dictionary = _last_event("count_up")
	assert_bool(count_up["skip_used"]).is_true()
	assert_int(int(count_up["skip_at_ms"])).is_greater_equal(CountUp.CHECKOUT_DOUBLE_CLICK_MS)
	assert_bool(count_up["fast_forward_used"]).is_false()


## A press and release that arrive in the same frame (a touchpad tap, a long frame) are still a
## tap: presses come from the events, not from the state seen once a frame.
func test_a_press_and_release_in_one_frame_is_a_tap() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(3)
	_runner.simulate_key_press(KEY_SPACE)
	_runner.simulate_key_release(KEY_SPACE)
	await _count_up_end(screen)
	var key: Dictionary = _last_event("count_up")
	assert_bool(key["skip_used"]).is_true()
	assert_bool(key["fast_forward_used"]).is_false()
	await _assert_full_receipt(screen)

	screen._on_reward_skipped()
	_runner.set_mouse_position(screen._receipt.get_global_rect().get_center())
	_place_row(screen)
	screen._on_checkout_pressed()
	await _frames(3)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await _count_up_end(screen)
	var mouse: Dictionary = _last_event("count_up")
	assert_bool(mouse["skip_used"]).is_true()
	assert_bool(mouse["fast_forward_used"]).is_false()


## A tapped count and a held one play every sound and note of the untouched count, as often,
## the notes in the same order at the same volumes (#62). Only `tick`, three tween callbacks per
## payout roll that frame timing can bunch up, is left out.
func test_a_tapped_or_held_count_plays_the_same_sounds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	_place(screen, FULL_ROW)
	var result: ScoreResult = screen.run.preview()
	_play(screen, result)
	await _played(screen)
	var untouched: Dictionary = _heard(sfx)
	for sound: String in ["scan", "stamp", "armed", "denied", "ding", "register_bell", "rattle_l"]:
		assert_int(int(untouched.get(sound, 0))).override_failure_message(sound).is_greater(0)
	assert_int((untouched["notes"] as Array).size()).is_greater(5)

	sfx.clear()
	_play(screen, result)
	await _frames(3)
	await _tap()
	await _played(screen)
	assert_bool(screen._count_up._tapped).is_true()
	assert_dict(_heard(sfx)).is_equal(untouched)

	sfx.clear()
	_play(screen, result)
	await _frames(3)
	_runner.simulate_key_press(KEY_SPACE)
	await _wall_ms(CountUp.HOLD_THRESHOLD_MS + 300)
	_runner.simulate_key_release(KEY_SPACE)
	await _played(screen)
	assert_bool(screen._count_up.fast_forward_used).is_true()
	assert_dict(_heard(sfx)).is_equal(untouched)


## A tap after the count-up has ended does nothing.
func test_a_tap_after_the_count_up_does_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	_place_row(screen)
	await screen._on_checkout_pressed()
	await _tap()
	await _frames(2)
	assert_int(screen._count_up.first_tap_ms).is_equal(-1)
	assert_bool(screen._count_up.dessert_skipped).is_false()


## The count-up's receipt is the whole result's, line for line, under the shift's header (#75,
## the planning stub's), ended by the dessert (the verdict, the margin, PAID on a pass, the tear
## and the next shift's inspection notice when there is one), every line fully shown once the
## last fades (which overlap the printer feed) have ended.
func _assert_full_receipt(screen: ShiftScreen) -> void:
	await _lines_shown(screen._receipt)
	var run: RunState = screen.run
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		run.last_result,
		ShiftScreen._names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections),
		screen.receipt_header()
	)
	assert_str(_lines(expected)[0]).is_equal(ReceiptView.HEADER_TEXT + " | ")
	var notice: String = InspectionTag.next_notice(run.next_inspection)
	expected.show_shift_end(run.last_result.total, run.quota(), notice)
	assert_array(_lines(screen._receipt)).is_equal(_lines(expected))
	for line: Node in screen._receipt._lines.get_children():
		assert_float((line as CanvasItem).modulate.a).is_equal(1.0)


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


## Plays `result` on the screen's row from the same context every time (shift 1, no best yet).
func _play(screen: ShiftScreen, result: ScoreResult) -> void:
	screen._count_up.play(
		result,
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		SOUND_QUOTA,
		CountUpContext.new(1, 0),
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(screen.run.upgrades),
		screen._inspection_tag.sources(screen.run.inspections),
		InspectionTag.names(screen.run.inspections)
	)


func _played(screen: ShiftScreen) -> void:
	while screen._count_up._playing:
		await get_tree().process_frame


## What a recording Sfx heard: how often each sound was asked for but `tick`, and under "notes"
## every note as "index@volume_db", in order.
static func _heard(sfx: RecordingSfx) -> Dictionary:
	var heard: Dictionary = {}
	for sound: String in sfx.sound_names():
		if sound != "tick":
			heard[sound] = int(heard.get(sound, 0)) + 1
	var notes: Array[String] = []
	for entry: Dictionary in sfx.notes:
		notes.append("%d@%.1f" % [int(entry["index"]), float(entry["volume_db"])])
	heard["notes"] = notes
	return heard


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	Rush.speed_up(_runner, TIME_FACTOR)
	var screen: ShiftScreen = _runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


## A disabled stand-in for CHECKOUT under the mouse: headless runs keep the mouse at the window's
## corner and never move the hover.
func _disabled_button_at_the_mouse(screen: ShiftScreen) -> void:
	var button: Button = Button.new()
	button.size = Vector2(40, 40)
	button.disabled = true
	screen.add_child(button)
	button.global_position = Vector2.ZERO


func _place_row(screen: ShiftScreen) -> void:
	_place(screen, PASSING_ROW)


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())


## A quick press and release of Space, a couple of frames apart.
func _tap() -> void:
	_runner.simulate_key_press(KEY_SPACE)
	await _frames(2)
	_runner.simulate_key_release(KEY_SPACE)
	await _frames(1)


func _count_up_end(screen: ShiftScreen) -> void:
	while screen._counting:
		await get_tree().process_frame


func _wall_ms(ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
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
