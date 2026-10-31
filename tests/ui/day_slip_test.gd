extends GdUnitTestSuite
## Today's slip (DaySlip, 2026-10-31) on the real shift screen: tapping the day chip ("D5") drops
## the slip under it, inside the screen at 1280x720 and 1920x1080, reading "DAY 5 · TODAY", the
## day event's name, effect and where it touches the belt (Short belt's closed slot, Spot check's
## €0 slot, none on a plain day); a second tap, a click elsewhere or Esc closes it; the week chip
## still opens the time card, which closes the slip, and the day chip no longer does. Clicks are
## sent to the handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const INSPECTIONS := "res://data/inspections/%s.tres"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
## The fixed shift (day 5 of the real schedule).
const SHIFT := 5

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Where each slot event touches the belt, from its data and the shift's limits: Short belt
## closes the slot after the open ones, Extra till opens the last, Spot check zeroes its slot,
## Happy hour pays the last filled slot; an event off the belt has no line.
func test_where_lines_come_from_the_events_data() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var cases: Dictionary[String, PackedStringArray] = {
		"short_belt": PackedStringArray([DaySlip.WHERE_CLOSED % balance.slot_count]),
		"extra_till": PackedStringArray([DaySlip.WHERE_OPENS % (balance.slot_count + 1)]),
		"spot_check": PackedStringArray([DaySlip.WHERE_ZERO % 3]),
		"happy_hour": PackedStringArray([DaySlip.WHERE_LAST]),
		"rush_hour": PackedStringArray(),
		"free_samples": PackedStringArray(),
	}
	for id: String in cases:
		var event: InspectionDefinition = load(INSPECTIONS % id)
		var events: Array[InspectionDefinition] = [event]
		var limits: ShiftLimits = ShiftLimits.for_shift(balance, [], 0, events)
		var lines: PackedStringArray = DaySlip.where_lines(event, limits)
		assert_array(Array(lines)).override_failure_message(id).is_equal(Array(cases[id]))


## In a 1280x720 and a 1920x1080 window, the day chip drops the slip under the chip, inside the
## screen, its lines inside the paper and apart; Short belt reads its name, effect and closed slot.
func test_the_slip_hangs_under_the_day_chip_inside_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for window_size: Vector2 in WINDOWS:
		screen.size = window_size
		_set_event(screen, "short_belt")
		await _frames(3)
		var slip: DaySlip = screen._week.slip
		var chip: InspectionTag = screen._stage.top_bar.inspection_tag
		chip.call("_gui_input", _left_click())
		assert_bool(slip.is_open()).is_true()
		slip.settle()
		await _frames(2)
		var bounds: Rect2 = screen.get_global_rect()
		var paper: Rect2 = slip.paper().get_global_rect()
		var tag: Rect2 = chip.get_global_rect()
		var message: String = "%s %s in %s" % [window_size, paper, bounds]
		assert_bool(bounds.encloses(paper)).override_failure_message(message).is_true()
		assert_float(paper.position.y).is_greater_equal(tag.end.y)
		assert_float(paper.position.y - tag.end.y).is_less_equal(DaySlip.GAP + 1.0)
		assert_float(paper.position.x).is_equal_approx(tag.position.x, 1.0)
		# It fits its content: every line inside the paper, the lines apart, top to bottom.
		var lines: Array[Label] = [slip.paper().find_child("Head", true, false) as Label]
		lines.append_array(slip.name_labels())
		lines.append_array(slip.effect_labels())
		lines.append_array(slip.where_labels())
		var previous: float = paper.position.y
		for label: Label in lines:
			var rect: Rect2 = label.get_global_rect()
			assert_bool(paper.encloses(rect)).override_failure_message(label.text).is_true()
			assert_float(rect.size.x).is_greater_equal(label.get_minimum_size().x - 0.5)
			assert_float(rect.position.y).is_greater_equal(previous)
			previous = rect.end.y
		var text: String = slip.slip_text()
		assert_str(text).contains(DaySlip.HEAD % SHIFT)
		assert_str(text).contains("Short belt")
		assert_str(text).contains("One slot fewer")
		assert_str(text).contains(DaySlip.WHERE_CLOSED % 7)
		chip.call("_gui_input", _left_click())
		assert_bool(slip.is_open()).is_false()
		await _frames(2)


## Spot check reads its €0 slot; a plain day reads "Normal day", "No event today" and no slot.
func test_the_slip_reads_spot_check_and_a_plain_day() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var chip: InspectionTag = screen._stage.top_bar.inspection_tag
	var slip: DaySlip = screen._week.slip
	_set_event(screen, "spot_check")
	await _frames(2)
	chip.call("_gui_input", _left_click())
	var text: String = slip.slip_text()
	assert_str(text).contains("Spot check")
	assert_str(text).contains("Slot 3 pays €0")
	# The effect already names the slot: no repeated where line.
	assert_str(text).not_contains(DaySlip.WHERE_ZERO % 3)
	assert_int(slip.where_labels().size()).is_equal(0)
	slip.clear()
	_set_event(screen, "")
	await _frames(2)
	chip.call("_gui_input", _left_click())
	text = slip.slip_text()
	assert_str(text).contains(DaySlip.HEAD % SHIFT)
	assert_str(text).contains(DaySlip.NO_EVENT)
	assert_str(text).contains(DaySlip.NO_EVENT_EFFECT)
	assert_array(slip.where_labels()).is_empty()


## A click elsewhere closes the slip without taking the click; one on the slip closes it too; Esc
## closes it; the wheel leaves it open.
func test_a_click_elsewhere_or_esc_closes_the_slip() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var chip: InspectionTag = screen._stage.top_bar.inspection_tag
	var slip: DaySlip = screen._week.slip
	_set_event(screen, "short_belt")
	await _frames(2)
	chip.call("_gui_input", _left_click())
	slip.settle()
	var wheel: InputEventMouseButton = _left_click()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.position = Vector2(1, 700)
	slip.call("_input", wheel)
	assert_bool(slip.is_open()).is_true()
	var on_chip: InputEventMouseButton = _left_click()
	on_chip.position = chip.get_global_rect().get_center()
	slip.call("_input", on_chip)
	assert_bool(slip.is_open()).override_failure_message("the chip toggles it").is_true()
	var elsewhere: InputEventMouseButton = _left_click()
	elsewhere.position = Vector2(1, 700)
	slip.call("_input", elsewhere)
	assert_bool(slip.is_open()).is_false()
	await _frames(12)  # The fade.
	assert_bool(slip.visible).is_false()
	chip.call("_gui_input", _left_click())
	slip.settle()
	var on_slip: InputEventMouseButton = _left_click()
	on_slip.position = slip.paper().get_global_rect().get_center()
	slip.call("_input", on_slip)
	assert_bool(slip.is_open()).is_false()
	slip.clear()
	chip.call("_gui_input", _left_click())
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	slip.call("_input", escape)
	assert_bool(slip.is_open()).is_false()


## The week chip still opens the time card, which closes the slip; the day chip no longer opens
## the card, and never drops the slip over it; the slip never opens while the shift is counted.
func test_the_week_chip_opens_the_card_and_the_day_chip_the_slip() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var bar: TopBar = screen._stage.top_bar
	var slip: DaySlip = screen._week.slip
	var card: WeekCard = screen._week.card
	_set_event(screen, "spot_check")
	await _frames(2)
	bar.inspection_tag.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_true()
	assert_bool(card.is_open()).is_false()
	bar.week_chip.call("_gui_input", _left_click())
	assert_bool(card.is_open()).is_true()
	assert_bool(slip.visible).is_false()
	bar.inspection_tag.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).override_failure_message("never over the card").is_false()
	card.call("_gui_input", _left_click())
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	screen._counting = true
	bar.inspection_tag.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).override_failure_message("never in the count").is_false()
	screen._counting = false
	bar.inspection_tag.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_true()
	screen._counting = true
	await _frames(2)
	assert_bool(slip.visible).override_failure_message("the count closes it").is_false()
	screen._counting = false


## Starts the fixed shift (day 5) under the day event `id` (none when empty), the card skipped.
func _set_event(screen: ShiftScreen, id: String) -> void:
	screen._week.skip()
	screen._debug.skip_to_shift(SHIFT)
	screen._debug.set_inspection(id)
	screen._week.skip()


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
