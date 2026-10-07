extends GdUnitTestSuite
## Inspections on the real shift screen (plan section 3.9): the next shift's notice printed in
## red under a passed total and shown on the reward panel, before the exit kiosk; the red tag in
## the top bar during the inspected shift (never on the loyalty card); inspection steps in the
## receipt and the count-up; the log fields; and the debug panel's inspection. Clicks are sent
## to the screen's handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const NOTICE := "INSPECTION NEXT SHIFT: The 3rd product pays €0"
const RECEIPT_LINE := "Spot check: the 3rd product pays €0"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_notice_comes_before_the_reward_and_the_kiosk() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	var run: RunState = screen.run
	assert_bool(screen._inspection_tag.visible).is_false()

	# Shift 2 is not inspected: no notice after shift 1.
	await _pass_shift(screen)
	assert_str(_receipt_text(screen)).not_contains("INSPECTION")
	assert_str(screen._reward_panel.warning_text()).is_empty()
	assert_str(_last_event("checkout")["next_inspection"]).is_empty()
	screen._on_reward_skipped()
	assert_bool(screen._inspection_tag.visible).is_false()

	# Shift 3 is: the notice prints in red right under shift 2's total, and the reward panel
	# shows it too, so the pick can take it into account. The kiosk comes after.
	await _pass_shift(screen)
	# Each line is a left and a right label: TOTAL, its amount, then the notice and its empty
	# right side.
	var lines: PackedStringArray = _receipt_lines(screen)
	assert_array(Array(lines.slice(-4))).is_equal(["TOTAL", "€27", NOTICE, ""])
	var notice: Label = _receipt_label(screen, NOTICE)
	assert_bool(notice.get_theme_color("font_color") == Palette.TOMATO).is_true()
	assert_str(screen._reward_panel.warning_text()).is_equal(NOTICE)
	assert_bool(screen._reward_panel.visible).is_true()
	assert_bool(screen._upgrade_panel.visible).is_false()
	await _frames(3)
	var warning_rect: Rect2 = screen._reward_panel._warning.get_global_rect()
	assert_bool(screen.get_global_rect().encloses(warning_rect)).is_true()
	assert_str(_last_event("checkout")["next_inspection"]).is_equal("spot_check")
	screen._on_reward_skipped()
	assert_bool(screen._upgrade_panel.visible).is_true()
	await _wait_wall_ms(450)
	screen._upgrade_panel._on_ticket_clicked(screen._upgrade_panel.tickets()[0])

	# Shift 3: the tag shows the inspection in the top bar, never on the loyalty card.
	assert_int(run.shift_index).is_equal(2)
	assert_bool(screen._inspection_tag.visible).is_true()
	assert_str(screen._inspection_tag.text()).is_equal("INSPECTION  The 3rd product pays €0")
	assert_str(screen._inspection_tag.tooltip_text).contains("Spot check")
	assert_bool(screen._loyalty_card.is_ancestor_of(screen._inspection_tag)).is_false()
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(run.upgrades.size())
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	# The top bar still fits the window with the tag in it.
	await _frames(3)
	var top: Control = screen._shift_label.get_parent()
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_float(top.get_combined_minimum_size().x).is_less_equal(width - 40)
	(
		assert_bool(screen.get_global_rect().encloses(screen._inspection_tag.get_global_rect()))
		. is_true()
	)


func test_inspection_steps_print_and_play_from_the_tag() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	screen._debug.set_inspection("spot_check")
	assert_bool(screen._inspection_tag.visible).is_true()
	assert_str(_last_event("debug")["action"]).is_equal("set_inspection")
	_place_ids(screen, ["bread", "bread", "bread", "bread"])
	# The live preview already pays the 3rd Bread 0 and names the inspection.
	var preview: ScoreResult = screen.run.preview()
	assert_array(Array(preview.payouts)).is_equal([3, 3, 0, 3])
	assert_str(_receipt_text(screen)).contains(RECEIPT_LINE)
	var steps: Array = preview.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.INSPECTION
	)
	assert_int(steps.size()).is_equal(1)
	await screen._on_checkout_pressed()
	assert_object(screen._count_up._source_control(steps[0])).is_same(screen._inspection_tag)
	assert_str(_receipt_text(screen)).contains(RECEIPT_LINE)
	assert_object(screen.run.history[0].inspection).is_not_null()


func test_the_debug_panel_clears_the_inspection() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	screen._debug.set_inspection("spot_check")
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	screen._debug.set_inspection("")
	assert_bool(screen._inspection_tag.visible).is_false()
	assert_array(screen.run.inspections).is_empty()
	assert_array(_last_event("shift_start")["inspections"]).is_empty()
	# An unknown id changes nothing.
	screen._debug.set_inspection("no_such_inspection")
	assert_str(_last_event("debug")["inspection"]).is_empty()


## Places a row that passes the first two quotas: Bread, Multipack, Bread x4 = 27.
func _pass_shift(screen: ShiftScreen) -> void:
	_place_ids(screen, ["bread", "multipack", "bread", "bread", "bread", "bread"])
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)


## Adds the cards to the hand through the debug panel and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## The receipt's labels in order (a line's left text, then its right text).
static func _receipt_lines(screen: ShiftScreen) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return texts


static func _receipt_text(screen: ShiftScreen) -> String:
	return "\n".join(_receipt_lines(screen))


static func _receipt_label(screen: ShiftScreen, text: String) -> Label:
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if (label as Label).text == text and not label.is_queued_for_deletion():
			return label
	return null


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


## Waits on wall-clock time: the suite speeds up game time.
func _wait_wall_ms(ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await get_tree().process_frame
	await get_tree().process_frame


func _last_event(type: String) -> Dictionary:
	var events: Array = _events()
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


func _events() -> Array:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	return events


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	var hand_box: HBoxContainer = screen._hand_box
	for child: Node in hand_box.get_children():
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
