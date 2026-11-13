extends GdUnitTestSuite
## Today's slip (DaySlip, 2026-10-31) on the real shift screen: tapping the day calendar (v1.17, in
## place of the day chip) pops the slip up over it (play test 2026-11-09: over the planning
## receipt, clear of CHECKOUT, the week glass, the medals and the belt; a review day prints compact
## where it must; a long hover opens it, leaving closes it, a tap pins it), inside the screen at
## 1280x720 and 1920x1080,
## reading "DAY 5 · TODAY", the day event's name, effect and where it touches the belt (Short belt's
## closed slot, Spot check's 0€ slot, none on a plain day); a second tap, a click elsewhere or Esc
## closes it; the week glass opens the time card, which closes the slip, and the calendar never
## does. Clicks are sent to the handlers, because headless runs don't deliver input events. The
## event's icon sits on the left of its block, centred on its height (2026-11-01). Under the day's
## events the week's bonus is reminded (v1.02): "WEEK 2 · BAKERY FESTIVAL" and its effect, in the
## paper.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
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
	var balance: BalanceDefinition = load(BALANCE)
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


## In a 1280x720 and a 1920x1080 window, the day calendar pops the slip up over its pad (play test
## 2026-11-09: "needs to be higher"): its foot GAP over the pad and its tags, its right edge on the
## pad's, inside the screen and the receipt's column, clear of the register's keys, the week glass,
## the medals and the belt; its lines inside the paper and apart; Short belt reads its name,
## effect and closed slot.
func test_the_slip_pops_up_over_the_calendar_inside_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for window_size: Vector2 in WINDOWS:
		screen.size = window_size
		_set_event(screen, "short_belt")
		await _frames(3)
		var slip: DaySlip = screen._week.slip
		var chip: DayCalendar = screen._stage.day_calendar
		chip.call("_gui_input", _left_click())
		assert_bool(slip.is_open()).is_true()
		slip.settle()
		await _frames(2)
		var paper: Rect2 = slip.paper().get_global_rect()
		_assert_over_the_calendar(screen, paper, "%s" % window_size)
		assert_bool(slip.is_compact()).is_false()
		# It fits its content: every line inside the paper, the lines apart, top to bottom.
		var lines: Array[Label] = [slip.paper().find_child("Head", true, false) as Label]
		lines.append_array(slip.name_labels())
		lines.append_array(slip.effect_labels())
		lines.append_array(slip.where_labels())
		# The week's reminder comes last, under the day's events.
		var week_line: Control = slip.week_line()
		assert_object(week_line).is_not_null()
		lines.append(week_line.find_child("WeekHead", true, false) as Label)
		for event: Node in slip.paper().find_children("Event", "PanelContainer", true, false):
			var event_rect: Rect2 = (event as Control).get_global_rect()
			assert_bool(event_rect.intersects(week_line.get_global_rect())).is_false()
			assert_float(week_line.get_global_rect().position.y).is_greater_equal(event_rect.end.y)
		var previous: float = paper.position.y
		for label: Label in lines:
			var rect: Rect2 = label.get_global_rect()
			assert_bool(paper.encloses(rect)).override_failure_message(label.text).is_true()
			assert_float(rect.size.x).is_greater_equal(label.get_minimum_size().x - 0.5)
			assert_float(rect.position.y).is_greater_equal(previous)
			previous = rect.end.y
		var effect: RichTextLabel = week_line.find_child("WeekEffect", true, false) as RichTextLabel
		var effect_rect: Rect2 = effect.get_global_rect()
		assert_bool(paper.encloses(effect_rect)).is_true()
		assert_bool(week_line.get_global_rect().encloses(effect_rect)).is_true()
		assert_float(effect_rect.position.y).is_greater_equal(previous)
		assert_float(effect_rect.size.y).is_greater_equal(float(DaySlip.WEEK_SIZE))
		# The event icon: at ICON_SCALE, on the left of its block, centred on the block's height.
		var icon: TextureRect = slip.paper().find_child("Icon", true, false) as TextureRect
		var icon_rect: Rect2 = icon.get_global_rect()
		var block: Rect2 = (icon.get_parent() as Control).get_global_rect()
		assert_float(icon_rect.size.x).is_equal(icon.texture.get_width() * DaySlip.ICON_SCALE)
		assert_float(icon_rect.position.x).is_equal_approx(block.position.x, 1.0)
		assert_float(icon_rect.get_center().y).is_equal_approx(block.get_center().y, 1.0)
		var text: String = slip.slip_text()
		assert_str(text).contains(DaySlip.HEAD % SHIFT)
		assert_str(text).contains("Short belt")
		assert_str(text).contains("One slot fewer")
		assert_str(text).contains(DaySlip.WHERE_CLOSED % 7)
		var week: WeekCardModel = WeekCardModel.of(screen.run)
		assert_str(text).contains(DaySlip.WEEK_HEAD % [week.week_number, week.title()])
		assert_str(text).contains(week.effect())
		chip.call("_gui_input", _left_click())
		assert_bool(slip.is_open()).is_false()
		await _frames(2)


## A review day's two events and the week's line: the paper still stands over the calendar inside
## the screen at both sizes (compact at 1280x720, where the full print is taller than its room),
## every event's name inside it; a promised bonus ticket reads its whole line under the head.
func test_a_review_day_fits_over_the_calendar() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var events: Array[InspectionDefinition] = [
		load(INSPECTIONS % "short_belt") as InspectionDefinition,
		load(INSPECTIONS % "spot_check") as InspectionDefinition,
	]
	for window_size: Vector2 in WINDOWS:
		screen.size = window_size
		_set_event(screen, "")
		screen.run.inspections = events.duplicate()
		screen._on_shift_started()
		screen._week.skip()
		screen._stage.day_calendar.show_bonus(InspectionTag.Bonus.PROMISED)
		await _frames(3)
		var slip: DaySlip = screen._week.slip
		screen._stage.day_calendar.call("_gui_input", _left_click())
		assert_bool(slip.is_open()).is_true()
		slip.settle()
		await _frames(2)
		var paper: Rect2 = slip.paper().get_global_rect()
		var message: String = "%s review" % window_size
		_assert_over_the_calendar(screen, paper, message)
		assert_int(slip.name_labels().size()).is_equal(2)
		for label: Label in slip.name_labels():
			assert_bool(paper.encloses(label.get_global_rect())).is_true()
		assert_str(slip.slip_text()).contains(DayCalendar.PILL_TIP)
		if window_size.y <= 720.0:
			assert_bool(slip.is_compact()).override_failure_message(message).is_true()
		slip.clear()


## A long hover on the calendar (HOVER_OPEN_S) opens the slip quietly, over the calendar; leaving
## the calendar for HOVER_GRACE closes it (no sound), coming onto the paper keeps it; a tap while
## hover-opened pins it (leaving no longer closes it) and a second tap closes it. The calendar has
## no native tooltip any more: the slip says it. No long hover while an item is dragged.
func test_a_long_hover_opens_the_slip_and_a_tap_pins_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var chip: DayCalendar = screen._stage.day_calendar
	var slip: DaySlip = screen._week.slip
	_set_event(screen, "short_belt")
	await _frames(2)
	assert_str(chip.tooltip_text).is_empty()
	assert_str(chip.tags.pill().tooltip_text).is_empty()
	assert_float(DayCalendar.HOVER_OPEN_S).is_between(0.3, 0.6)
	var dwell: Timer = chip.get_node("Dwell") as Timer
	# Hover: the wait starts, and leaving before it ends opens nothing.
	chip.notification(Control.NOTIFICATION_MOUSE_ENTER_SELF)
	assert_bool(dwell.is_stopped()).is_false()
	assert_float(dwell.wait_time).is_equal(DayCalendar.HOVER_OPEN_S)
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	assert_bool(dwell.is_stopped()).is_true()
	assert_bool(slip.is_open()).is_false()
	# A long hover opens it, quietly, over the calendar.
	chip.notification(Control.NOTIFICATION_MOUSE_ENTER_SELF)
	dwell.stop()
	dwell.timeout.emit()
	assert_bool(slip.is_open()).is_true()
	assert_bool(slip.is_hover_open()).is_true()
	slip.settle()
	await _frames(2)
	_assert_over_the_calendar(screen, slip.paper().get_global_rect(), "hover")
	assert_str(slip.slip_text()).contains("Short belt")
	# Off the calendar, onto the paper within the grace: it stays.
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	slip.advance(DaySlip.HOVER_GRACE * 0.5)
	slip.paper().mouse_entered.emit()
	slip.advance(DaySlip.HOVER_GRACE * 2.0)
	assert_bool(slip.is_open()).is_true()
	# Off the paper and the calendar: it closes after the grace.
	slip.paper().mouse_exited.emit()
	slip.advance(DaySlip.HOVER_GRACE * 0.5)
	assert_bool(slip.is_open()).is_true()
	slip.advance(DaySlip.HOVER_GRACE)
	assert_bool(slip.is_open()).is_false()
	slip.clear()
	# Hover open, then a tap pins it: leaving no longer closes it; a second tap closes it.
	chip.notification(Control.NOTIFICATION_MOUSE_ENTER_SELF)
	dwell.stop()
	dwell.timeout.emit()
	chip.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_true()
	assert_bool(slip.is_hover_open()).is_false()
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	slip.advance(DaySlip.HOVER_GRACE * 4.0)
	assert_bool(slip.is_open()).override_failure_message("pinned").is_true()
	chip.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_false()
	slip.clear()
	# A tap stops the hover's wait: a slip tapped open and shut never reopens on its own.
	chip.notification(Control.NOTIFICATION_MOUSE_ENTER_SELF)
	chip.call("_gui_input", _left_click())
	assert_bool(dwell.is_stopped()).override_failure_message("tap stops the dwell").is_true()
	chip.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_false()
	slip.clear()
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	# A tap-opened slip stays when the pointer leaves, as before.
	chip.call("_gui_input", _left_click())
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	slip.advance(DaySlip.HOVER_GRACE * 4.0)
	assert_bool(slip.is_open()).is_true()
	slip.clear()
	# A long hover while the slip is open (tapped) changes nothing; none while the count runs.
	screen._counting = true
	chip.notification(Control.NOTIFICATION_MOUSE_ENTER_SELF)
	dwell.stop()
	dwell.timeout.emit()
	assert_bool(slip.is_open()).is_false()
	screen._counting = false
	chip.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)


## Spot check reads its 0€ slot; a plain day reads "Normal day", "No event today" and no slot.
func test_the_slip_reads_spot_check_and_a_plain_day() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var chip: DayCalendar = screen._stage.day_calendar
	var slip: DaySlip = screen._week.slip
	_set_event(screen, "spot_check")
	await _frames(2)
	chip.call("_gui_input", _left_click())
	var text: String = slip.slip_text()
	assert_str(text).contains("Spot check")
	assert_str(text).contains("Slot 3 pays 0€")
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
	var chip: DayCalendar = screen._stage.day_calendar
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


## The week glass opens the time card, which closes the slip; the day calendar never opens the
## card, and never drops the slip over it; the slip never opens while the shift is counted.
func test_the_week_glass_opens_the_card_and_the_calendar_the_slip() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var slip: DaySlip = screen._week.slip
	var card: WeekCard = screen._week.card
	_set_event(screen, "spot_check")
	await _frames(2)
	screen._stage.day_calendar.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_true()
	assert_bool(card.is_open()).is_false()
	screen._stage.week_glass.call("_gui_input", _left_click())
	assert_bool(card.is_open()).is_true()
	assert_bool(slip.visible).is_false()
	screen._stage.day_calendar.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).override_failure_message("never over the card").is_false()
	card.call("_gui_input", _left_click())
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	screen._counting = true
	screen._stage.day_calendar.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).override_failure_message("never in the count").is_false()
	screen._counting = false
	screen._stage.day_calendar.call("_gui_input", _left_click())
	assert_bool(slip.is_open()).is_true()
	screen._counting = true
	await _frames(2)
	assert_bool(slip.visible).override_failure_message("the count closes it").is_false()
	screen._counting = false


## The slip's `paper` stands over the day calendar (play test 2026-11-09): its foot GAP over the
## pad and its tags, its right edge on the pad's (clamped to the margin at most), inside the screen
## and left of the top bar's start, never over the register's keys, the week glass, the medal case,
## the bag or the belt.
func _assert_over_the_calendar(screen: ShiftScreen, paper: Rect2, message: String) -> void:
	var bounds: Rect2 = screen.get_global_rect()
	var chip: DayCalendar = screen._stage.day_calendar
	var pad: Rect2 = chip.get_global_rect()
	var reach: Rect2 = pad
	var tags: Rect2 = chip.part_rects()["tags"]
	if tags.has_area():
		reach = reach.merge(tags)
	var info: String = "%s: %s, pad %s in %s" % [message, paper, reach, bounds]
	(
		assert_bool(bounds.grow(-DaySlip.MARGIN + 0.5).encloses(paper))
		. override_failure_message(info)
		. is_true()
	)
	assert_float(paper.end.y).override_failure_message(info).is_less_equal(reach.position.y)
	assert_float(reach.position.y - paper.end.y).override_failure_message(info).is_less_equal(
		DaySlip.GAP + 1.0
	)
	assert_float(paper.end.x).override_failure_message(info).is_equal_approx(pad.end.x, 1.0)
	var stage: ShiftStage = screen._stage
	var clear_of: Dictionary[String, Rect2] = {
		"checkout": screen._cabinet.checkout_key.get_global_rect(),
		"week glass": stage.week_glass.get_global_rect(),
		"medals": stage.medal_case.get_global_rect(),
		"belt": stage.belt.get_global_rect(),
		"calendar": pad,
	}
	for part: String in clear_of:
		var rect: Rect2 = clear_of[part]
		(
			assert_bool(rect.has_area() and paper.intersects(rect))
			. override_failure_message("%s over %s %s" % [info, part, rect])
			. is_false()
		)


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


## The week's reminder shows only for a week with an event: a slip opened without a week, or for
## a week without an event, has none; the training week's reads its misses.
func test_the_week_reminder_needs_a_week_event() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	host.size = Vector2(1280, 720)
	var slip: DaySlip = DaySlip.new()
	host.add_child(slip)
	var balance: BalanceDefinition = load(BALANCE)
	var events: Array[InspectionDefinition] = []
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, [], 0, events)
	slip.open(1, events, limits, null, true)
	assert_object(slip.week_line()).is_null()
	var plain: WeekCardModel = WeekCardModel.new()
	slip.open(1, events, limits, null, true, plain)
	assert_object(slip.week_line()).is_null()
	var training: WeekCardModel = WeekCardModel.new()
	training.event = balance.weeks[0]
	training.allowed_misses = balance.write_up_limit
	slip.open(1, events, limits, null, true, training)
	assert_object(slip.week_line()).is_not_null()
	assert_str(slip.slip_text()).contains(WeekCardModel.ALLOWS_LEAD)
	assert_str(slip.slip_text()).contains(training.misses_text())
	assert_str(slip.slip_text()).contains(DaySlip.WEEK_HEAD % [1, training.title()])
	slip.clear()


## The week reminder's effect reads its gains green and its quota red, as the monitor's bonus
## and harmful names (v1.02 review: "+2€" green, "+10%" red), the rest in ink, from the week
## event's data: Bakery festival's tag bonus and quota_percent.
func test_the_week_effect_colours_gains_green_and_the_quota_red() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	host.size = Vector2(1280, 720)
	var slip: DaySlip = DaySlip.new()
	host.add_child(slip)
	var balance: BalanceDefinition = load(BALANCE)
	var events: Array[InspectionDefinition] = []
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, [], 0, events)
	var week: WeekCardModel = WeekCardModel.new()
	week.week_number = 2
	week.event = load("res://data/weeks/bakery_festival.tres") as WeekEventDefinition
	slip.open(1, events, limits, null, true, week)
	var effect: RichTextLabel = (
		slip.week_line().find_child("WeekEffect", true, false) as RichTextLabel
	)
	assert_object(effect).is_not_null()
	assert_str(effect.get_parsed_text()).is_equal(week.effect())
	assert_str(effect.get_parsed_text()).is_equal("Bakery items +2€, quota +10%")
	var gain: String = "[color=#%s]+2€[/color]" % Palette.GREEN_DARK.to_html(false)
	var harm: String = "[color=#%s]+10%%[/color]" % Palette.TOMATO_DARK.to_html(false)
	assert_str(effect.text).is_equal("Bakery items %s, quota %s" % [gain, harm])
	assert_bool(effect.get_theme_color("default_color") == Palette.INK).is_true()
	assert_bool(WeekCard.GAIN_INK == MonitorStepRow.BONUS_COLOR).is_true()
	assert_bool(WeekCard.HARM_INK == MonitorStepRow.HARM_COLOR).is_true()
	# The runs come from the data: a gain, a harm, and plain text between.
	var tones: Array[WeekCardModel.Tone] = []
	for run: WeekCardModel.EffectRun in week.effect_runs():
		tones.append(run.tone)
	var plain: WeekCardModel.Tone = WeekCardModel.Tone.PLAIN
	assert_array(tones).is_equal([plain, WeekCardModel.Tone.GAIN, plain, WeekCardModel.Tone.HARM])
	# Holiday rush: its quota red, its machine odds green.
	week.event = load("res://data/weeks/holiday_rush.tres") as WeekEventDefinition
	slip.open(1, events, limits, null, true, week)
	effect = slip.week_line().find_child("WeekEffect", true, false) as RichTextLabel
	assert_str(effect.text).contains(
		"[color=#%s]+15%%[/color]" % Palette.TOMATO_DARK.to_html(false)
	)
	assert_str(effect.text).contains(
		"[color=#%s]Rarer prizes[/color]" % Palette.GREEN_DARK.to_html(false)
	)
	slip.clear()


## The training week's reminder reads its misses as the time card's banner does (v1.02 review):
## "THIS WEEK ALLOWS" in ink, then "2 MISSES" on the card's red tag (paper on tomato, ink rim), on
## one line, apart, inside the reminder and the slip, at 1280x720 and 1920x1080.
func test_the_training_week_misses_read_as_on_the_card() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var events: Array[InspectionDefinition] = []
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, [], 0, events)
	var training: WeekCardModel = WeekCardModel.new()
	training.event = balance.weeks[0]
	training.allowed_misses = balance.write_up_limit
	assert_bool(training.event.forgives_slips).is_true()
	var card_tag: Label = WeekCard.misses_tag(training.misses_text(), WeekCard.BANNER_EFFECT_SIZE)
	var card_box: StyleBoxFlat = card_tag.get_theme_stylebox("normal") as StyleBoxFlat
	card_tag.free()
	for window: Vector2 in WINDOWS:
		var host: Control = auto_free(Control.new())
		add_child(host)
		host.size = window
		var slip: DaySlip = DaySlip.new()
		host.add_child(slip)
		slip.open(1, events, limits, null, true, training)
		await _frames(2)
		var week_line: Control = slip.week_line()
		var tag: Label = week_line.find_child("MissesTag", true, false) as Label
		var lead: Label = week_line.find_child("Lead", true, false) as Label
		assert_object(tag).is_not_null()
		assert_object(lead).is_not_null()
		assert_str(tag.text).is_equal("%d MISSES" % balance.write_up_limit)
		assert_object(tag.get_theme_color("font_color")).is_equal(Palette.PAPER)
		assert_object(lead.get_theme_color("font_color")).is_equal(Palette.INK)
		var box: StyleBoxFlat = tag.get_theme_stylebox("normal") as StyleBoxFlat
		assert_object(box.bg_color).is_equal(Palette.TOMATO)
		assert_object(box.bg_color).is_equal(card_box.bg_color)
		assert_object(box.border_color).is_equal(card_box.border_color)
		var tag_rect: Rect2 = tag.get_global_rect()
		var lead_rect: Rect2 = lead.get_global_rect()
		assert_bool(tag_rect.intersects(lead_rect)).is_false()
		assert_float(tag_rect.position.x).is_greater_equal(lead_rect.end.x)
		assert_float(absf(tag_rect.get_center().y - lead_rect.get_center().y)).is_less_equal(1.0)
		var line_rect: Rect2 = week_line.get_global_rect()
		assert_bool(line_rect.encloses(tag_rect) and line_rect.encloses(lead_rect)).is_true()
		assert_bool(slip.paper().get_global_rect().encloses(line_rect)).is_true()
		slip.clear()
