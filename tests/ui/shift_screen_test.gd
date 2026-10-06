extends GdUnitTestSuite
## End-to-end: the real shift screen through placing, redraw, checkout, the count-up, the
## event log and the next shift. Clicks are sent to the screen's handlers, because headless
## runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_shift_from_draw_to_next_shift() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	assert_int(run.hand().size()).is_equal(8)

	# Redraw two cards through the redraw mode.
	var hand: Array[CardInstance] = run.hand()
	screen._on_redraw_pressed()
	screen._on_hand_card_clicked(_view_for(screen, hand[6]))
	screen._on_hand_card_clicked(_view_for(screen, hand[7]))
	screen._on_redraw_pressed()
	assert_bool(run.redraw_used).is_true()
	assert_bool(run.hand().has(hand[6])).is_false()

	# Place three cards with clicks: pick up a hand card, then click a slot.
	hand = run.hand()
	for index: int in range(3):
		screen._on_hand_card_clicked(_view_for(screen, hand[index]))
		screen._on_slot_input(_left_click(), index)
	assert_int(run.row.size()).is_equal(3)
	# Pick one back up and put it in front.
	screen._on_row_card_clicked(_row_view(screen, 2))
	screen._on_slot_input(_left_click(), 0)
	assert_object(run.row[0]).is_same(hand[2])
	var expected_total: int = run.preview().total

	await screen._on_checkout_pressed()
	var subtotal: Label = screen._subtotal_label
	assert_str(subtotal.text).is_equal("€%d" % expected_total)
	var banner: Control = screen._banner
	assert_bool(banner.visible).is_true()

	var passed: bool = expected_total >= run.quota()
	var events: Array = _events()
	var types: Array = events.map(func(event: Dictionary) -> String: return event["type"])
	var expected_types: Array = ["run_start", "shift_start", "redraw", "checkout"]
	if not passed:
		expected_types.append("run_end")
	expected_types.append("count_up")
	assert_array(types).contains_exactly(expected_types)
	var checkout: Dictionary = events[3]
	assert_int(int(checkout["score"])).is_equal(expected_total)
	assert_int(int(checkout["placements"])).is_equal(4)
	# A move within the row is 1 placement and 0 removals (plan section 8).
	assert_int(int(checkout["removals"])).is_equal(0)
	var count_up: Dictionary = events[-1]
	assert_int(int(count_up["count_up_ms"])).is_greater(0)
	assert_int(int(checkout["rearrangements"])).is_equal(1)
	assert_int((checkout["final_order"] as Array).size()).is_equal(3)
	assert_bool(checkout["passed"]).is_equal(passed)

	screen._on_banner_pressed()
	types = _events().map(func(event: Dictionary) -> String: return event["type"])
	if passed:
		assert_int(screen.run.shift_index).is_equal(1)
		assert_array(types.slice(-1)).is_equal(["shift_start"])
	else:
		assert_int(screen.run.shift_index).is_equal(0)
		assert_array(types.slice(-3)).is_equal(["restart", "run_start", "shift_start"])


## A row card picked up and dropped back in the hand is a removal; one placed again is not.
func test_dropping_a_picked_row_card_counts_as_a_removal() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var hand: Array[CardInstance] = screen.run.hand()
	for index: int in range(2):
		screen._on_hand_card_clicked(_view_for(screen, hand[index]))
		screen._on_slot_input(_left_click(), index)
	screen._on_row_card_clicked(_row_view(screen, 0))
	screen._on_background_input(_left_click())
	assert_int(screen.tracker.removals).is_equal(1)
	assert_int(screen.run.row.size()).is_equal(1)
	# A wheel tick over the background doesn't drop a picked card.
	screen._on_row_card_clicked(_row_view(screen, 0))
	var wheel: InputEventMouseButton = _left_click()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	screen._on_background_input(wheel)
	assert_object(screen._picked).is_not_null()


func test_full_row_highlights_no_slot() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var hand: Array[CardInstance] = screen.run.hand()
	for index: int in range(6):
		screen._on_hand_card_clicked(_view_for(screen, hand[index]))
		screen._on_slot_input(_left_click(), index)
	screen._on_hand_card_clicked(_view_for(screen, hand[6]))
	for panel: PanelContainer in screen._slots:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_bool(style.border_color == Palette.MUSTARD).is_false()


func test_empty_checkout_loses_and_logs_run_end() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await screen._on_checkout_pressed()
	var events: Array = _events()
	assert_str(events[-1]["type"]).is_equal("count_up")
	assert_str(events[-2]["type"]).is_equal("run_end")
	assert_str(events[-2]["result"]).is_equal("loss")
	assert_int(int(events[-3]["score"])).is_equal(0)


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	var hand_box: HBoxContainer = screen._hand_box
	for child: Node in hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _row_view(screen: ShiftScreen, slot: int) -> CardView:
	return screen._row_views[slot]


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _events() -> Array:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	return events


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
