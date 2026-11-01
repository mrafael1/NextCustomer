extends GdUnitTestSuite
## Inspections on the real shift screen (plan section 3.9): the next shift's notice printed in
## red under a passed total, before the RECEIPT REWARDS machine (#77) opens; the red tag in
## the top bar during the inspected shift (never on the loyalty card); inspection steps in the
## receipt and the count-up; the log fields; and the debug panel's inspection. Clicks are sent
## to the screen's handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const SHORT_BELT := "res://data/inspections/short_belt.tres"
const HAPPY_HOUR := "res://data/inspections/happy_hour.tres"
const EXTRA_TILL := "res://data/inspections/extra_till.tres"
## Checkouts rush their count (one tap): the suite tests what follows it.
const Rush := preload("res://tests/ui/count_up_rush.gd")
const NOTICE := "INSPECTION NEXT SHIFT: Slot 3 pays €0"
const RECEIPT_LINE := "Spot check: slot 3 pays €0"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_notice_comes_before_the_machine() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_only_spot_check(screen)
	var run: RunState = screen.run
	assert_str(screen._inspection_tag.text()).is_equal(WeekCardModel.NO_EVENT)  # The day chip.

	# Shift 2 is not inspected: no notice after shift 1.
	await _pass_shift(screen)
	assert_str(_receipt_text(screen)).not_contains("INSPECTION")
	assert_str(_last_event("checkout")["next_inspection"]).is_empty()
	screen._machine.debug_skip()
	assert_str(screen._inspection_tag.text()).is_equal(WeekCardModel.NO_EVENT)  # The day chip.

	# Shift 3 is: the notice prints in red under shift 2's dessert (after the tear, #61), on the
	# receipt beside the machine, so the pick can take it into account.
	await _pass_shift(screen)
	# Each line is a left and a right label: TOTAL and its verdict, the margin and PAID, the
	# tear, then the notice; the last two with an empty right side.
	var lines: PackedStringArray = _receipt_lines(screen)
	var quota: int = run.quota()
	(
		assert_array(Array(lines.slice(-8)))
		. is_equal(
			[
				"TOTAL",
				ReceiptView.verdict_text(109, quota),
				ReceiptView.margin_text(ShiftMargin.Kind.OVER, 109 - quota),
				ReceiptView.PAID_TEXT,
				ReceiptView.TEAR_PATTERN.repeat(ReceiptView.TEAR_REPEAT),
				"",
				NOTICE,
				"",
			]
		)
	)
	var notice: Label = _receipt_label(screen, NOTICE)
	assert_bool(notice.get_theme_color("font_color") == Palette.TOMATO).is_true()
	assert_bool(screen._machine.is_open()).is_true()
	await _frames(3)
	var notice_rect: Rect2 = notice.get_global_rect()
	assert_bool(screen.get_global_rect().encloses(notice_rect)).is_true()
	# The notice is not under the machine.
	var machine_rect: Rect2 = screen._machine.view.get_global_rect()
	assert_bool(machine_rect.intersects(notice_rect)).is_false()
	assert_str(_last_event("checkout")["next_inspection"]).is_equal("spot_check")
	screen._machine.debug_skip()

	# Shift 3: the chip shows the inspection's effect in the top bar (its name and notice on
	# hover), never on the loyalty card.
	assert_int(run.shift_index).is_equal(2)
	assert_bool(screen._inspection_tag.visible).is_true()
	# The bonus pill's chip may drop "Inspection · " to fit the bar (#77 machine v2).
	assert_str(screen._inspection_tag.text()).ends_with("Slot 3 pays €0")
	assert_str(screen._inspection_tag.tooltip_text).contains("Spot check")
	assert_str(screen._inspection_tag.tooltip_text).contains("Slot 3 pays €0")
	assert_bool(screen._loyalty_card.is_ancestor_of(screen._inspection_tag)).is_false()
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(run.upgrades.size())
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	# The top bar still fits the stage with the chip in it, above the shade, between the QUOTA
	# chip and the LOYALTY chip (B2's order).
	await _frames(3)
	var top: Control = screen._top_bar
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(top.get_combined_minimum_size().x).is_less_equal(stage.size.x - 40)
	var tag: Rect2 = screen._inspection_tag.get_global_rect()
	assert_bool(stage.encloses(tag)).override_failure_message(str(tag)).is_true()
	assert_float(tag.end.y).is_less_equal(stage.position.y + ShiftStage.PANEL_TOP)
	var quota_chip: Rect2 = (screen._top_bar.get_child(1) as Control).get_global_rect()
	assert_float(tag.position.x).is_greater_equal(quota_chip.end.x)
	assert_float(tag.end.x).is_less_equal(screen._loyalty_card.get_global_rect().position.x)
	# The warning sign and the name lie inside the chip, apart.
	var icons: Array[Node] = screen._inspection_tag.find_children("*", "TextureRect", true, false)
	var icon: Rect2 = (icons[0] as Control).get_global_rect()
	var name_rect: Rect2 = screen._inspection_tag.label().get_global_rect()
	assert_bool(tag.encloses(icon) and tag.encloses(name_rect)).is_true()
	assert_bool(icon.intersects(name_rect)).is_false()


func test_inspection_steps_print_and_play_from_the_tag() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	# The row misses: its receipt stays on screen as the run ends (no write-up, v0.65).
	Rush.no_write_ups(screen)
	_only_spot_check(screen)
	screen._debug.set_inspection("spot_check")
	assert_bool(screen._inspection_tag.visible).is_true()
	assert_str(_last_event("debug")["action"]).is_equal("set_inspection")
	# Slot 3 wears the inspection's "€0" mark on the empty belt already (2026-10-28).
	var dead: SlotMark = screen._row_strip.inspection_mark(2, 0)
	assert_object(dead).is_not_null()
	assert_bool(dead.is_visible_in_tree()).is_true()
	assert_str(dead.text()).is_equal(SlotMark.INSPECTION_TEXT)
	assert_object(screen._row_strip.inspection_mark(1)).is_null()
	_place_ids(screen, ["bread", "bread", "bread", "bread"])
	# The live preview already pays the 3rd Bread 0, and scanning it names the inspection (#75:
	# the planning receipt is a stub, its lines are read on the items).
	var preview: ScoreResult = screen.run.preview()
	assert_array(Array(preview.payouts)).is_equal([5, 5, 0, 5])
	assert_str(_receipt_text(screen)).not_contains(RECEIPT_LINE)
	assert_str(_scan_text(screen, 2)).contains(RECEIPT_LINE)
	var steps: Array = preview.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.INSPECTION
	)
	assert_int(steps.size()).is_equal(1)
	await Rush.checkout(screen)
	assert_object(screen._count_up._beats._source_control(steps[0])).is_same(screen._inspection_tag)
	assert_str(_receipt_text(screen)).contains(RECEIPT_LINE)
	assert_object(screen.run.history[0].inspection).is_not_null()
	assert_int(dead.fired_count()).is_equal(1)


func test_the_debug_panel_clears_the_inspection() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_only_spot_check(screen)
	screen._debug.set_inspection("spot_check")
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	screen._debug.set_inspection("")
	assert_str(screen._inspection_tag.text()).is_equal(WeekCardModel.NO_EVENT)  # The day chip.
	assert_array(screen.run.inspections).is_empty()
	assert_array(_last_event("shift_start")["inspections"]).is_empty()
	# An unknown id changes nothing.
	screen._debug.set_inspection("no_such_inspection")
	assert_str(_last_event("debug")["inspection"]).is_empty()


## The planning notice (#77 machine v2's B1): an inspected shift whose pass earns the bonus ticket
## (RewardMachine.bonus_if_passed) shows the mustard "PASS › +1 BONUS TICKET" pill in the chip,
## inside the chip and the top bar, right of the text; the chip pulses (PlanningTuning's Bonus
## notice times; the monitor's plate went with the store channel, #105 piece 2), back at 1 after,
## none under reduced motion. After the pass the monitor's count shows
## INSPECTION PASSED ✓ inside the screen and the chip turns EARNED: "<name> passed" with the
## check mark, teal pale, the pill without "PASS ›".
func test_the_planning_notice_promises_and_earns_the_bonus_ticket() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_only_spot_check(screen)
	# The live machine gives an inspection no bonus since v0.68 (Payday): a copy that does.
	MachineSteps.bonus_after_inspection(screen.run)
	screen._debug.set_inspection("spot_check")
	var run: RunState = screen.run
	assert_bool(run.machine.bonus_if_passed(run)).is_true()
	var tag: InspectionTag = screen._inspection_tag
	assert_int(tag.bonus_state()).is_equal(InspectionTag.Bonus.PROMISED)
	# The whole promise is in the tooltip; a tight top bar shortens the pill to its ticket and "+1".
	assert_str(tag.tooltip_text).contains("PASS › +1 BONUS TICKET")
	assert_str(tag.full_text()).contains("+1")
	await _frames(3)
	# The effect is cut only once everything else gave way (InspectionTag.fit_width; since v0.70
	# the week chip's name and pips too, TopBar.fit_inspection), and the tooltip keeps it whole.
	var effect: String = (load(SPOT_CHECK) as InspectionDefinition).chip_text
	if tag.is_trimmed():
		var week_chip: WeekChip = screen._stage.top_bar.week_chip
		assert_bool(week_chip.name_shown() or week_chip.pips_shown()).is_false()
	else:
		assert_str(tag.label().text).contains(effect)
	assert_str(tag.tooltip_text).contains((load(SPOT_CHECK) as InspectionDefinition).display_name)
	assert_str(tag.tooltip_text).contains(InspectionTag.PILL_TIP)
	var chip: Rect2 = tag.get_global_rect()
	var pill: Rect2 = tag.pill().get_global_rect()
	assert_bool(tag.pill().visible).is_true()
	assert_bool(chip.encloses(pill)).override_failure_message("%s in %s" % [pill, chip]).is_true()
	assert_float(pill.position.x).is_greater_equal(tag.label().get_global_rect().end.x)
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_bool(stage.encloses(chip)).is_true()
	assert_float(chip.end.y).is_less_equal(stage.position.y + ShiftStage.PANEL_TOP)
	assert_float(chip.end.x).is_less_equal(screen._loyalty_card.get_global_rect().position.x)
	for label: Label in tag.pill().find_children("*", "Label", true, false):
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var width: float = (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		assert_float(width).is_less_equal(label.size.x + 0.5)
	# The pulse: the chip alone (the store channel's plate went with #105 piece 2).
	var notice: BonusNotice = screen._machine.notice
	assert_bool(notice.is_playing()).is_true()
	var tuning: PlanningTuning = notice.tuning
	assert_int(tuning.notice_pulse_ms).is_greater(0)
	var peak: float = PI / 2.0 / tuning.notice_pulse_rate
	notice.show_at(peak)
	assert_float(tag.scale.x).is_equal_approx(1.0 + tuning.notice_pulse_scale, 0.001)
	assert_vector(tag.pivot_offset).is_equal(tag.size / 2.0)
	notice.show_at(notice.length())
	assert_bool(notice.is_playing()).is_false()
	assert_float(tag.scale.x).is_equal(1.0)
	notice.play(tag, true)  # Reduced motion: none.
	assert_bool(notice.is_playing()).is_false()
	assert_float(tag.scale.x).is_equal(1.0)
	# The pass: INSPECTION PASSED ✓ on the monitor, the chip EARNED.
	await _pass_shift(screen)
	var passed: Label = screen._monitor.inspection_passed_label
	assert_bool(passed.is_visible_in_tree()).is_true()
	assert_str(passed.text).is_equal("INSPECTION PASSED ✓")
	await _frames(2)
	assert_bool(screen._monitor.get_global_rect().encloses(passed.get_global_rect())).is_true()
	assert_bool(run.machine.bonus_earned(run)).is_true()
	assert_int(tag.bonus_state()).is_equal(InspectionTag.Bonus.EARNED)
	assert_str(tag.label().text).is_equal("Spot check passed")
	assert_str(tag.full_text()).starts_with("Spot check passed +1")
	# EARNED tints the paper frame teal pale (unearned, it is tomato pale).
	var pale: Color = Palette.TEAL_PALE
	var paper: Color = Palette.PAPER
	var earned_tint: Color = Color(pale.r / paper.r, pale.g / paper.g, pale.b / paper.b)
	assert_bool(tag.self_modulate.is_equal_approx(earned_tint)).is_true()
	screen._machine.debug_skip()  # The ticket's visit and the bonus ticket's.
	# Shift 2 is not inspected: no pill.
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.history[-1].shift).is_equal(1)
	assert_str(tag.text()).is_equal(WeekCardModel.NO_EVENT)  # The day chip (v0.70).
	assert_int(tag.bonus_state()).is_equal(InspectionTag.Bonus.NONE)


## Places a row that passes the first five quotas: Milk, Multipack, Milk x5 = 109.
func _pass_shift(screen: ShiftScreen) -> void:
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"])
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


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


## Scans the belt item in `slot` (the pointer on its sprite, its hover sent: headless runs never
## move the mouse; then its hold ends, #80) and returns its scan popup's footer, one line each,
## then ends the scan.
static func _scan_text(screen: ShiftScreen, slot: int) -> String:
	var view: ItemView = screen._row_views[slot] as ItemView
	var point: Vector2 = view.sprite().get_global_rect().get_center()
	screen._scan.pointer = func() -> Vector2: return point
	view.hovered.emit(view)
	screen._scan._go_full()
	# A belt item's scan shows on the hung monitor (#80), in its item column (#105 piece 2).
	var text: String = "\n".join(screen._monitor.item_column().step_texts())
	screen._scan.clear()
	return text


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
	var hand_box: Control = screen._hand_box
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


## These tests follow Spot check through the screen: the run draws from a pool holding only it,
## with no boon days (v0.69; a copy of the balance data, so the shared resource is untouched).
static func _only_spot_check(screen: ShiftScreen) -> void:
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	var pool: Array[InspectionDefinition] = [load(SPOT_CHECK)]
	balance.inspection_pool = pool
	balance.boon_shifts = PackedInt32Array()
	screen.run.balance = balance
	# The week's days (v0.70) as this balance draws them.
	screen.run.week = WeekSchedule.draw(RandomNumberGenerator.new(), balance, 1)
	screen.run.inspections = screen.run.week.day(screen.run.shift_index + 1)
	screen._week.skip()


## Short belt on the shift screen: 6 open slots plus a CLOSED panel after them, so the row keeps
## its usual 7 panels and its scale; the panel reads "inspection" and its hover text names the
## inspection, a click on it explains, the run's limits lose the slot and the top bar's chip says
## what the inspection took.
func test_a_closed_slot_shows_on_the_row() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	run.inspections = [load(SHORT_BELT)]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	await _frames(3)
	assert_int(screen._slots.size()).is_equal(6)
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	assert_int(screen._row_strip.box.get_child_count()).is_equal(7)
	assert_vector(screen._row_strip.box.scale).is_equal(Vector2.ONE)
	var panel: PanelContainer = screen._row_strip.closed[0]
	assert_str(panel.tooltip_text).contains("Short belt")
	assert_str((panel.get_child(0) as Label).text).is_equal("CLOSED")
	# Bare rubber: no mat, the open slots' cells all have one.
	assert_object(RowStrip.mat(panel)).is_null()
	for slot: PanelContainer in screen._slots:
		assert_object(RowStrip.mat(slot)).is_not_null()
	assert_vector(panel.get_global_rect().size).is_equal(ItemView.BELT_SIZE)
	# The rope, its posts and the sign, with "inspection" under them (the hover text names it);
	# the cell's parts never take the click from the panel.
	var caption: Label = RowStrip.closed_caption_label(panel)
	assert_str(caption.text).is_equal("inspection")
	assert_bool(panel.get_global_rect().encloses(caption.get_global_rect())).is_true()
	assert_float(caption.get_minimum_size().y).is_less_equal(caption.size.y)
	for part: Node in (panel.get_child(0) as Label).get_children():
		assert_int((part as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var sprite: TextureRect = part as TextureRect
		if sprite != null:
			assert_vector(sprite.size).is_equal(Vector2(sprite.texture.get_size()))
	var belt: Rect2 = Rect2(
		screen._stage.get_global_rect().position + ShiftStage.ROW_AREA.position,
		ShiftStage.ROW_AREA.size
	)
	var closed_rect: Rect2 = panel.get_global_rect()
	assert_bool(belt.encloses(closed_rect)).is_true()
	assert_float(closed_rect.position.x).is_greater_equal(screen._slots[-1].get_global_rect().end.x)
	assert_bool(closed_rect.intersects(screen._receipt.get_global_rect())).is_false()
	assert_int(screen.run.limits.slot_count).is_equal(6)
	assert_int(screen.run.limits.closed_slots).is_equal(1)
	assert_str(screen._inspection_tag.text()).is_equal("Inspection · −1 slot")
	screen._row_strip.closed_clicked.emit()
	assert_str(screen._notice_label.text).contains("Closed by the inspection")


## Short belt: one coupon and 5 products fill the 6-slot row, so a 7th card is refused with a
## notice, never silently.
func test_a_full_row_explains_why_a_card_does_not_fit() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	run.inspections = [load(SHORT_BELT)]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	run.place(run.debug_add_to_hand(load("res://data/cards/repeat.tres")), 0)
	for index: int in range(5):
		run.place(run.debug_add_to_hand(bread), index + 1)
	assert_int(run.row.size()).is_equal(RowCapacity.card_limit(run.limits))
	var extra: CardInstance = run.debug_add_to_hand(bread)
	assert_bool(run.can_place(extra)).is_false()
	screen._explain_if_refused()
	assert_str(screen._notice_label.text).contains("Row full (6/6 items)")
	# The closed slot's panel says an inspection closed it, and its hover text which one.
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	var caption: Label = RowStrip.closed_caption_label(screen._row_strip.closed[0])
	assert_str(caption.text).is_equal("inspection")
	assert_str(screen._row_strip.closed[0].tooltip_text).contains("Short belt")
	assert_str(screen._inspection_tag.text()).is_equal("Inspection · −1 slot")


## Day events aimed at a slot wear its mark (2026-10-31: "day event that impact a specific slot
## should be shown visually on slot"): Happy hour's green "+€3" on the row's last filled slot (slot
## 1 on the empty belt), moving as cards are placed, and Extra till's EXTRA on the slot it adds;
## each hangs under its own slot's ticket, on screen, and Happy hour's fires on its step.
func test_slot_day_events_mark_their_slots() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	Rush.no_write_ups(screen)
	var run: RunState = screen.run
	run.inspections = [load(HAPPY_HOUR), load(EXTRA_TILL)]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	screen._week.drop()
	await _frames(3)
	var open: int = RowCapacity.card_limit(run.limits)
	assert_int(screen._slots.size()).is_equal(open)
	var happy: SlotMark = screen._row_strip.inspection_mark(0, 0)
	assert_object(happy).is_not_null()
	assert_str(happy.text()).is_equal("+€3")
	assert_bool(happy.boon).is_true()
	var extra: SlotMark = screen._row_strip.inspection_mark(open - 1, 1)
	assert_object(extra).is_not_null()
	assert_str(extra.text()).is_equal(SlotMark.EXTRA_TEXT)
	assert_object(screen._row_strip.inspection_mark(open - 2)).is_null()
	_assert_on_slot(screen, happy, 0)
	_assert_on_slot(screen, extra, open - 1)
	_place_ids(screen, ["bread", "milk", "bread"])
	await _frames(3)
	assert_object(screen._row_strip.inspection_mark(0, 0)).is_null()
	happy = screen._row_strip.inspection_mark(2, 0)
	assert_object(happy).is_not_null()
	_assert_on_slot(screen, happy, 2)
	extra = screen._row_strip.inspection_mark(open - 1, 1)
	_assert_on_slot(screen, extra, open - 1)
	# The emptied row after the checkout moves the mark away: count its fires as it leaves.
	var fired: Array[int] = []
	var happy_mark: SlotMark = happy
	happy.tree_exiting.connect(func() -> void: fired.append(happy_mark.fired_count()))
	var extra_fired: Array[int] = []
	extra.tree_exiting.connect(func() -> void: extra_fired.append(extra.fired_count()))
	await Rush.checkout(screen)
	var happy_fires: int = fired[0] if not fired.is_empty() else happy.fired_count()
	assert_int(happy_fires).is_equal(1)
	assert_int(extra_fired[0] if not extra_fired.is_empty() else extra.fired_count()).is_equal(0)


## `mark` hangs on slot `slot`: across its cell's width, under its ticket and inside the screen.
func _assert_on_slot(screen: ShiftScreen, mark: SlotMark, slot: int) -> void:
	assert_bool(mark.is_visible_in_tree()).is_true()
	var panel: PanelContainer = screen._slots[slot]
	var cell: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
	var rect: Rect2 = mark.get_global_transform() * Rect2(Vector2.ZERO, mark.size)
	var message: String = "%s on %s" % [rect, cell]
	assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
		cell.position.x
	)
	assert_float(rect.end.x).override_failure_message(message).is_less_equal(cell.end.x + 0.5)
	assert_float(rect.position.y).override_failure_message(message).is_greater(cell.position.y)
	var screen_rect: Rect2 = screen.get_viewport_rect()
	assert_bool(screen_rect.encloses(rect)).override_failure_message(message).is_true()
	for other: int in range(screen._slots.size()):
		if other == slot:
			continue
		var other_panel: PanelContainer = screen._slots[other]
		var other_cell: Rect2 = (
			other_panel.get_global_transform() * Rect2(Vector2.ZERO, other_panel.size)
		)
		assert_bool(other_cell.intersects(rect)).override_failure_message(message).is_false()
