extends GdUnitTestSuite
## Day events on the real shift screen (v0.69, plan section 3.9): a boon day's green chip in the
## top bar ("Quiet morning" since v1.16, the boon coin) lies inside the chip, the bar and
## the stage between the QUOTA and LOYALTY chips, and the quota reads the boon's; the next shift's
## boon prints in green on the receipt ("TOMORROW: ..."), on screen; a boon day's pass earns no
## INSPECTION PASSED; and a boon's steps play in the count-up from its chip (Happy hour's +3€,
## Free samples' ×2). Clicks are sent to the screen's handlers, because headless runs don't
## deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const QUIET_MORNING := "res://data/inspections/quiet_morning.tres"

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


func test_a_boon_chip_lays_out_in_the_top_bar() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var quota: int = screen.run.quota()
	screen._debug.set_inspection("quiet_morning")
	var tag: InspectionTag = screen._inspection_tag
	assert_bool(tag.visible).is_true()
	assert_bool(tag.is_boon()).is_true()
	# The boon's name only (v1.16); its effect is in the tooltip and the day's slip.
	assert_str(tag.text()).is_equal("Quiet morning")
	assert_str(tag.tooltip_text).contains("TODAY: Quiet morning")
	# Green, never the inspection's tomato pale; the boon coin, not the warning sign.
	assert_float(tag.self_modulate.g).is_greater(tag.self_modulate.r)
	var icons: Array[Node] = tag.find_children("*", "TextureRect", true, false)
	assert_object((icons[0] as TextureRect).texture).is_same(InspectionTag.BOON)
	# No bonus ticket for a boon.
	assert_bool(tag.pill().visible).is_false()
	# The quota the shift plays is the boon's.
	assert_int(screen.run.quota()).is_equal(ShiftLimits.with_percent(quota, -10))
	await _frames(3)
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(screen._top_bar.get_combined_minimum_size().x).is_less_equal(stage.size.x - 40)
	var chip: Rect2 = tag.get_global_rect()
	assert_bool(stage.encloses(chip)).override_failure_message(str(chip)).is_true()
	assert_float(chip.end.y).is_less_equal(stage.position.y + ShiftStage.PANEL_TOP)
	var quota_chip: Rect2 = (screen._top_bar.get_child(1) as Control).get_global_rect()
	assert_float(chip.position.x).is_greater_equal(quota_chip.end.x)
	assert_float(chip.end.x).is_less_equal(screen._loyalty_card.get_global_rect().position.x)
	var icon: Rect2 = (icons[0] as Control).get_global_rect()
	var text: Rect2 = tag.label().get_global_rect()
	assert_bool(chip.encloses(icon) and chip.encloses(text)).is_true()
	assert_bool(icon.intersects(text)).is_false()
	# An inspection's chip is tomato pale (red), with the warning sign.
	screen._debug.set_inspection("spot_check")
	assert_bool(tag.is_boon()).is_false()
	assert_float(tag.self_modulate.r).is_greater(tag.self_modulate.g)


## Shift 2 is a boon day: its boon is announced in green under shift 1's tear, on screen, and
## passing it earns no INSPECTION PASSED.
func test_the_next_boon_prints_in_green_and_earns_no_stamp() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	await _pass_shift(screen)
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(run.next_inspections)
	assert_int(boons.size()).is_equal(1)
	var notice_text: String = InspectionTag.next_notice(run.next_inspections)
	assert_str(notice_text).starts_with("TOMORROW: %s (" % boons[0].display_name)
	var notice: Label = _receipt_label(screen, notice_text)
	assert_object(notice).is_not_null()
	assert_bool(notice.get_theme_color("font_color") == Palette.GREEN_DARK).is_true()
	await _frames(3)
	assert_bool(screen.get_global_rect().encloses(notice.get_global_rect())).is_true()
	(
		assert_bool(screen._machine.view.get_global_rect().intersects(notice.get_global_rect()))
		. is_false()
	)
	screen._machine.debug_skip()
	assert_int(run.shift_index).is_equal(1)
	assert_array(run.inspections).is_equal(boons)
	assert_bool(screen._inspection_tag.is_boon()).is_true()
	await _pass_shift(screen)
	assert_str(_receipt_text(screen)).not_contains("INSPECTION PASSED")
	assert_object(run.history[-1].inspection).is_null()


## Happy hour's +3€ is a step of its own: the count-up plays it as a bonus from the boon's chip,
## and the receipt prints it.
func test_a_boon_bonus_plays_in_the_count_up() -> void:
	await _check_boon_count_up("happy_hour", CountUpBeat.Kind.BONUS)


## Free samples' ×2 lands as a stamp from the boon's chip.
func test_a_boon_multiplier_plays_in_the_count_up() -> void:
	await _check_boon_count_up("free_samples", CountUpBeat.Kind.STAMP)


## A harmful day event's line on the monitor (the user's call of 2026-11-02): Late delivery's
## "−2€ Dairy pays less" and the Spot check's 0€ (slot 3, the 3rd Milk) print in tomato with the
## event's badge (#138 review; else the "!" mark), in planning (the scan's item lines) and at the
## count's end (a resumed checkout's last item, its earlier rows folded when they don't fit),
## inside the item column; their amounts keep their signs.
func test_harmful_lines_are_tomato_on_the_monitor() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.set_inspection("late_delivery")
	# Two events at once, so one row shows both (the debug panel sets one).
	screen.run.inspections.append(load("res://data/inspections/spot_check.tres"))
	_place_ids(screen, ["milk", "bread", "milk"])
	await _frames(3)
	var lines: ScanController.ItemLines = screen._scan.item_lines(2)
	assert_int(lines.harms.count(true)).is_equal(2)
	assert_bool(lines.fizzles.has(true)).is_false()
	screen._monitor.show_scan(screen.run.row[2].definition, screen.run.preview().tags[2], lines)
	await _frames(1)
	_assert_harmful_rows(screen, ["−2€", "= 0"])
	# Bread's planning lines are untouched by either event.
	(
		assert_array(screen._scan.item_lines(1).harms.filter(func(each: bool) -> bool: return each))
		. is_empty()
	)
	screen._monitor.end_scan()
	var result: ScoreResult = screen.run.preview()
	screen._count_up.show_end_state(result, screen.run.quota(), screen.count_up_context())
	screen._monitor.show_end_state(
		screen._count_up.plan, screen._row_views, false, result, screen._scan.line_of
	)
	await _frames(2)
	# The count keeps the newest rows that fit its room (PR #138 monitor), the earlier folded.
	_assert_harmful_rows(screen, ["−2€", "= 0"], true)


## The item column's step rows whose lines have these `amounts` are tomato with their source's
## icon or the "!" mark, inside the
## column; every other row with a mark keeps it off tomato. `folding`: the count's rows, where the
## earlier ones may fold into "+N earlier" (the last amount shown, the others folded).
func _assert_harmful_rows(
	screen: ShiftScreen, amounts: Array[String], folding: bool = false
) -> void:
	var column: MonitorItemColumn = screen._monitor.item_column()
	var area: Rect2 = column.get_global_rect().grow(0.5)
	var found: Array[String] = []
	for row: Control in column.step_rows():
		# Each row by its receipt line's amount ("= 0" reads "0€", or none when its words say it).
		var line: String = String(row.get_meta(&"line", ""))
		var key: String = ""
		for each: String in amounts:
			if line.contains(each):
				key = each
		if key.is_empty():
			continue
		found.append(key)
		# Its source's icon (#138 review: an event's badge, MonitorView.event_icon), else a tomato "!".
		var mark: Control = row.get_node("Mark") as Control
		if mark is TextureRect:
			assert_object((mark as TextureRect).texture).is_not_null()
		else:
			assert_str((mark as Label).text).is_equal(MonitorItemColumn.HARM_MARK)
			assert_that(mark.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
		var text: Label = row.get_node("Text") as Label
		assert_that(text.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
		assert_bool(area.encloses(row.get_global_rect())).override_failure_message(line).is_true()
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount == null:
			continue
		assert_that(amount.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
		assert_float(text.get_global_rect().end.x).is_less_equal(
			amount.get_global_rect().position.x
		)
	if folding and found.size() < amounts.size():
		assert_bool(found.has(amounts[-1])).is_true()
		assert_str(String(column.step_rows()[0].get_meta(&"line", ""))).ends_with("earlier")
		return
	assert_array(found).contains_exactly_in_any_order(amounts)


func _check_boon_count_up(id: String, expected: CountUpBeat.Kind) -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.set_inspection(id)
	assert_array(RunEvents.inspection_ids(screen.run.inspections)).is_equal([id])
	# A pass (109 plus the boon's), so the count-up's receipt stays up for the machine.
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"])
	var boon_steps: Array = screen.run.preview().steps.filter(
		func(each: ScoreStep) -> bool: return each.source_kind == ScoreStep.SourceKind.INSPECTION
	)
	assert_int(boon_steps.size()).is_equal(1)
	var boon_step: ScoreStep = boon_steps[0]
	await Rush.checkout(screen)
	var kinds: Array = []
	for beat: CountUpBeat in screen._count_up.plan.beats:
		for index: int in beat.steps:
			var counted: ScoreStep = screen.run.last_result.steps[index]
			if counted.source_kind == ScoreStep.SourceKind.INSPECTION:
				kinds.append(beat.kind)
	assert_array(kinds).is_equal([expected])
	var source: Control = screen._count_up._beats._source_control(boon_step)
	assert_object(source).is_same(screen._inspection_tag)
	var boon_name: String = (
		(load("res://data/inspections/%s.tres" % id) as InspectionDefinition).display_name
	)
	# The anchored receipt pays planning's rows in place: the boon plays on the monitor, not as a
	# printed line (2026-11-05).
	# (The next day's notice may name the same event: "TOMORROW: Free samples".)
	for line: String in _receipt_text(screen).split(char(10)):
		assert_bool(line.begins_with(boon_name)).override_failure_message(line).is_false()


func _pass_shift(screen: ShiftScreen) -> void:
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"])
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return "\n".join(texts)


static func _receipt_label(screen: ShiftScreen, text: String) -> Label:
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if (label as Label).text == text and not label.is_queued_for_deletion():
			return label
	return null


func _frames(count: int) -> void:
	for i: int in range(count):
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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
