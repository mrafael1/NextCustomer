extends GdUnitTestSuite
## The day chip names the day's kind only, at one fixed width (v1.15, the user's play-test note of
## 2026-11-07: "Days shouldn't show quick effect (exemple : "D12 review . slot 3 pays 0 . quota +
## 10%"). bar is expanding too much depending on days"): "D5 Normal day", "D6 Inspection", "D7
## Fresh delivery" (a boon day's boon), "D8 Review", the effects only in the tooltip and the slip.
## On the real shift screen at 1280x720 and 1920x1080 the chip's width and every top bar chip's
## place are the same on every kind of day (each of the pool's events alone too), the texts whole
## and nothing overlapping, from week to week too; a hovered item's cause still names its
## inspection in the same width; and a worn Day off keeps the SKIP tag's room on the days it can't
## show.

const SCREEN := "res://ui/shift_screen.tscn"
const INSPECTIONS := "res://data/inspections/"
const DAY_OFF := "res://data/pins/day_off.tres"
## Week 2's days (0-based shift indexes 4 to 7: D5 to D8).
const WEEK_TWO := 4

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


## A normal day, an inspection, a boon day and a review in one week, then each of the pool's
## events alone: the chip reads "D<n>" and the day's kind, never an effect (the tooltip keeps it),
## and the top bar's chips keep their places, the day chip its width.
func test_every_kind_of_day_keeps_the_bar_still() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var bar: TopBar = screen._stage.top_bar
		var tag: InspectionTag = bar.inspection_tag
		var days: Array[Array] = [
			[[], WeekCardModel.NO_EVENT],
			[["spot_check"], InspectionTag.CAPTION],
			[["fresh_delivery"], "Fresh delivery"],
			[["spot_check", "small_baskets"], InspectionTag.REVIEW_CAPTION],
		]
		var first: Array[Rect2] = []
		for index: int in range(days.size()):
			var ids: Array = days[index][0]
			await _show_day(screen, WEEK_TWO + index, ids)
			var message: String = "D%d at %s" % [WEEK_TWO + index + 1, window]
			assert_str(tag.day_label().text).is_equal("D%d" % (WEEK_TWO + index + 1))
			assert_str(tag.label().text).override_failure_message(message).is_equal(days[index][1])
			for id: String in ids:
				var event: InspectionDefinition = load(INSPECTIONS + id + ".tres")
				assert_str(tag.tooltip_text).contains(event.notice_text)
				if not event.chip_text.is_empty():
					assert_str(tag.label().text).not_contains(event.chip_text)
			_assert_fits(screen, message)
			var rects: Array[Rect2] = _bar_rects(bar)
			if first.is_empty():
				first = rects
			assert_array(rects).override_failure_message(message).is_equal(first)
		# Every pool event alone on the same day: its kind, the same width.
		var pool: Array[InspectionDefinition] = WeekFlow.event_pool(screen.run)
		assert_int(pool.size()).is_greater(4)
		for event: InspectionDefinition in pool:
			await _show_day(screen, WEEK_TWO + 1, [event.resource_path.get_file().get_basename()])
			var message: String = "%s at %s" % [event.display_name, window]
			var kind: String = event.display_name if event.is_boon() else InspectionTag.CAPTION
			assert_str(tag.label().text).override_failure_message(message).is_equal(kind)
			_assert_fits(screen, message)
			assert_array(_bar_rects(bar)).override_failure_message(message).is_equal(first)


## A new week (v1.15 review: the week chip's name, TRAINING to CLEARANCE, moved the bar on D5, D9
## and D13): the week chip keeps the room of the run's widest week name and number, so every top
## bar chip keeps its place across weeks too, at both window sizes.
func test_a_new_week_keeps_the_bar_still() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var bar: TopBar = screen._stage.top_bar
		var review: Array = ["spot_check", "small_baskets"]
		# D4, D5 (week 2's first), D9, D12 (a review), D13 and D16 (the final review).
		var days: Array[Array] = [[3, []], [4, []], [8, []], [11, review], [12, []], [15, review]]
		var first: Array[Rect2] = []
		var named: bool = false
		for day: Array in days:
			await _show_day(screen, day[0] as int, day[1] as Array)
			var message: String = "D%d at %s" % [(day[0] as int) + 1, window]
			_assert_fits(screen, message)
			var rects: Array[Rect2] = _bar_rects(bar)
			if first.is_empty():
				first = rects
				named = bar.week_chip.name_shown()
			assert_array(rects).override_failure_message(message).is_equal(first)
			assert_bool(bar.week_chip.name_shown()).override_failure_message(message).is_equal(
				named
			)
			var label: Label = bar.week_chip.name_label()
			if label.visible:
				assert_float(label.get_minimum_size().x).is_less_equal(label.size.x + 0.5)


## Hovering an item an inspection touches names that inspection on the chip (#71), in the same
## width, whole; the ring off, the chip reads "Review" again.
func test_a_named_cause_keeps_the_chip_width() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var bar: TopBar = screen._stage.top_bar
		var tag: InspectionTag = bar.inspection_tag
		await _show_day(screen, WEEK_TWO + 3, ["spot_check", "small_baskets"])
		var rects: Array[Rect2] = _bar_rects(bar)
		for cause: int in range(2):
			tag.set_relation(true, cause)
			await _frames(1)
			assert_bool(tag.has_relation()).is_true()
			assert_str(tag.label().text).is_equal(screen.run.inspections[cause].display_name)
			assert_bool(tag.is_trimmed()).is_false()
			_assert_fits(screen, "cause %d at %s" % [cause, window])
			assert_array(_bar_rects(bar)).is_equal(rects)
		tag.set_relation(false)
		await _frames(1)
		assert_str(tag.label().text).is_equal(InspectionTag.REVIEW_CAPTION)


## A worn Day off (#132): its SKIP tag shows on a day that can be taken off, not on a review, and
## the chip keeps its room either way, so the bar stands still.
func test_a_worn_day_off_keeps_the_skip_room() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		RunPins.wear(screen.run, [load(DAY_OFF) as PinDefinition])
		var bar: TopBar = screen._stage.top_bar
		var tag: InspectionTag = bar.inspection_tag
		await _show_day(screen, WEEK_TWO, [])
		assert_bool(tag.skip_tag().is_visible_in_tree()).is_true()
		_assert_fits(screen, "skip at %s" % window)
		var rects: Array[Rect2] = _bar_rects(bar)
		var skip: Rect2 = tag.skip_tag().get_global_rect()
		assert_bool(tag.get_global_rect().encloses(skip)).is_true()
		assert_bool(skip.intersects(tag.label().get_global_rect())).is_false()
		await _show_day(screen, WEEK_TWO + 3, ["spot_check", "small_baskets"])
		assert_bool(tag.skip_tag().visible).is_false()
		_assert_fits(screen, "review at %s" % window)
		assert_array(_bar_rects(bar)).is_equal(rects)


func _screen(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	await _frames(3)
	return screen


## Shift `shift_index` (0-based) under the day events `ids` (data/inspections), in planning.
func _show_day(screen: ShiftScreen, shift_index: int, ids: Array) -> void:
	var run: RunState = screen.run
	run.debug_skip_to_shift(shift_index)
	var events: Array[InspectionDefinition] = []
	for id: String in ids:
		events.append(load(INSPECTIONS + id + ".tres") as InspectionDefinition)
	run.inspections = events
	screen._on_shift_started()
	screen._week.drop()
	screen._machine.notice.stop()
	await _frames(3)


## The top bar's shown chips and buttons, in order, rounded to the pixel.
static func _bar_rects(bar: TopBar) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child: Node in bar.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			var rect: Rect2 = control.get_global_rect()
			rects.append(Rect2(rect.position.round(), rect.size.round()))
	return rects


## The bar inside the stage and the window, its shown chips apart and in order; the day chip's
## number, icon, text and SKIP tag inside it and apart; its text whole.
func _assert_fits(screen: ShiftScreen, message: String) -> void:
	var bar: TopBar = screen._stage.top_bar
	var stage: Rect2 = screen._stage.get_global_rect()
	var window: Rect2 = Rect2(Vector2.ZERO, screen.size)
	assert_float(bar.get_combined_minimum_size().x).is_less_equal(TopBar.ROW_SIZE.x)
	var previous: Rect2 = Rect2()
	for child: Node in bar.get_children():
		var control: Control = child as Control
		if control == null or not control.visible or control.size.x <= 0.0:
			continue
		var rect: Rect2 = control.get_global_rect()
		var name_of: String = "%s: %s" % [message, control.name]
		assert_bool(stage.encloses(rect)).override_failure_message(name_of).is_true()
		assert_bool(window.encloses(rect)).override_failure_message(name_of).is_true()
		if previous.has_area():
			assert_float(rect.position.x).override_failure_message(name_of).is_greater_equal(
				previous.end.x
			)
		previous = rect
	var tag: InspectionTag = bar.inspection_tag
	var chip: Rect2 = tag.get_global_rect()
	var parts: Array[Control] = [tag.day_label()]
	for icon: Node in tag.find_children("*", "TextureRect", true, false):
		if (icon as Control).is_visible_in_tree():
			parts.append(icon as Control)
	parts.append(tag.label())
	if tag.skip_tag().visible:
		parts.append(tag.skip_tag())
	for index: int in range(parts.size()):
		var rect: Rect2 = parts[index].get_global_rect()
		assert_bool(chip.encloses(rect)).override_failure_message(message).is_true()
		if index > 0:
			var last: Rect2 = parts[index - 1].get_global_rect()
			assert_bool(last.intersects(rect)).override_failure_message(message).is_false()
	assert_bool(tag.is_trimmed()).override_failure_message(message).is_false()
	assert_float(tag.text_width(tag.label().text)).is_less_equal(tag.label().size.x)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
