extends GdUnitTestSuite
## Inspections on the real shift screen (plan section 3.9): the next shift's notice no longer
## printed on the anchored receipt (2026-11-09), before the RECEIPT REWARDS machine (#77) opens; the
## red tag in the top bar during the inspected shift (never on the loyalty card); inspection steps
## in the receipt and the count-up; the log fields; and the debug panel's inspection. Clicks are
## sent to the screen's handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const SHORT_BELT := "res://data/inspections/short_belt.tres"
const HAPPY_HOUR := "res://data/inspections/happy_hour.tres"
const EXTRA_TILL := "res://data/inspections/extra_till.tres"
## Checkouts rush their count (one tap): the suite tests what follows it.
const Rush := preload("res://tests/ui/count_up_rush.gd")
const ReceiptFed := preload("res://tests/ui/receipt_fed_lines.gd")
const NOTICE := "INSPECTION NEXT SHIFT: Slot 3 pays 0€"
const RECEIPT_LINE := "Spot check: slot 3 pays 0€"

## The windows the 0€ slot is checked at: the game's and a larger one the layout scales to.
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 1000)]

var _folder: String = ""
var _window: Vector2i = Vector2i.ZERO


func before_test() -> void:
	_window = get_tree().root.size
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().root.size = _window
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
	assert_str(screen._calendar.text()).is_equal(DayCalendar.NORMAL_WORD)  # The day calendar.

	# Shift 2 is not inspected: no notice after shift 1.
	await _pass_shift(screen)
	assert_str(_receipt_text(screen)).not_contains("INSPECTION")
	assert_str(_last_event("checkout")["next_inspection"]).is_empty()
	screen._machine.debug_skip()
	assert_str(screen._calendar.text()).is_equal(DayCalendar.NORMAL_WORD)  # The day calendar.

	# Shift 3 is: since the user's play test of 2026-11-09 the anchored receipt prints nothing
	# under its last row (no tear, no next-shift notice: the desk calendar, its tooltip and the
	# deck's "Next shift" say it); PAID stamps on the header after the margin's words.
	await _pass_shift(screen)
	var lines: PackedStringArray = _receipt_lines(screen)
	assert_str(screen._receipt.target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % 109)
	assert_bool(lines.has(NOTICE)).is_false()
	assert_bool(lines.has(ReceiptView.TEAR_PATTERN.repeat(ReceiptView.TEAR_REPEAT))).is_false()
	assert_str(screen._receipt.target.stamp.text).is_equal(ReceiptView.PAID_TEXT)
	# A full belt: nothing under the foot, the header kept on the screen, and nothing prints
	# right of the paper (2026-11-07, v1.18).
	var fed: Array[Control] = ReceiptFed.lines(screen._receipt)
	assert_array(fed).is_empty()
	var planned: Rect2 = ReceiptFed.planned_rect(screen)
	var failures: Array[String] = ReceiptFed.failures(
		screen._receipt, planned, screen.get_viewport_rect()
	)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	# 109€ is three laps of the quota, but shift 1 spent the week's medals (WeekMedals,
	# 2026-11-06): the paper stays plain (its metal is the medal won, the 2026-11-09 play test).
	var spent: Array[int] = [WeekMedals.State.USED, WeekMedals.State.USED]
	assert_array(screen._stage.medal_case.states()).is_equal(spent)
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	assert_bool(screen._receipt.gold.is_silver()).is_false()
	assert_bool(screen._machine.is_open()).is_true()
	assert_str(_last_event("checkout")["next_inspection"]).is_equal("spot_check")
	screen._machine.debug_skip()

	# Shift 3: the calendar shows the day's kind in the top bar (v1.16: no effect; its name and
	# notice on today's slip), never on the loyalty card.
	assert_int(run.shift_index).is_equal(2)
	assert_bool(screen._calendar.visible).is_true()
	assert_str(screen._calendar.text()).is_equal(InspectionTag.CAPTION)
	var said: String = _slip_text(screen)
	assert_str(said).contains("Spot check")
	assert_str(said).contains("Slot 3 pays 0€")
	assert_bool(screen._loyalty_card.is_ancestor_of(screen._calendar)).is_false()
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(run.upgrades.size())
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	# The top bar still fits the stage; the desk calendar stands on the register's top (left
	# column v2), inside the stage.
	await _frames(3)
	var top: Control = screen._top_bar
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(top.get_combined_minimum_size().x).is_less_equal(stage.size.x - 40)
	var parts: Dictionary = screen._calendar.part_rects()
	var tag: Rect2 = parts["pad"]
	assert_bool(stage.encloses(tag)).override_failure_message(str(tag)).is_true()
	assert_float(tag.end.y).is_equal_approx(stage.position.y + ShiftStage.REGISTER_TOP, 0.01)
	assert_int(screen._calendar.look()).is_equal(DayCalendarArt.Look.INSPECTION)
	# The warning sign and DAY lie inside the pad, apart (no kind word on the desk calendar).
	var signs: Array = parts["signs"]
	assert_int(signs.size()).is_equal(1)
	var icon: Rect2 = signs[0]
	var name_rect: Rect2 = parts["day"]
	assert_bool(tag.encloses(icon) and tag.encloses(name_rect)).is_true()
	assert_bool(icon.intersects(name_rect)).is_false()


func test_inspection_steps_print_and_play_from_the_tag() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	# The row misses: its receipt stays on screen as the run ends (no write-up, v0.65).
	Rush.no_write_ups(screen)
	_only_spot_check(screen)
	screen._debug.set_inspection("spot_check")
	assert_bool(screen._calendar.visible).is_true()
	assert_str(_last_event("debug")["action"]).is_equal("set_inspection")
	# Slot 3 wears the inspection's "0€" mark on the empty belt already (2026-10-28).
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
	assert_object(screen._count_up._beats._source_control(steps[0])).is_same(screen._calendar)
	# The anchored receipt pays planning's rows in place: the step plays on the monitor, not as a
	# printed line (2026-11-05).
	assert_str(_receipt_text(screen)).not_contains(RECEIPT_LINE)
	assert_object(screen.run.history[0].inspection).is_not_null()
	assert_int(dead.fired_count()).is_equal(1)


## One owner per fact (2026-11-02, shift scene polish v2 ticket brief section 3): with a card on
## Spot check's slot 3 the ticket's pay tag shows the 0€ with no warning sign, and the slot's
## talker is the cause-only chip (the warning sign, no text, its hover tip naming the cause),
## centred under the ticket, inside the window and clear of its neighbours, so exactly one "0€"
## shows on the ticket and the talker; the empty slot keeps the full "⚠ 0€" talker. At the game's
## window and a larger one. The count still fires the chip on the 0€ beat.
func test_a_carded_zero_slot_shows_its_zero_once() -> void:
	await _assert_zero_once(WINDOWS[0])


func test_a_carded_zero_slot_shows_its_zero_once_in_a_larger_window() -> void:
	await _assert_zero_once(WINDOWS[1])


func _assert_zero_once(window: Vector2i) -> void:
	get_tree().root.size = window
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	Rush.no_write_ups(screen)
	_only_spot_check(screen)
	screen._debug.set_inspection("spot_check")
	await _frames(3)
	var case: String = str(window)
	var dead: SlotMark = screen._row_strip.inspection_mark(2, 0)
	assert_object(dead).override_failure_message(case).is_not_null()
	# Empty: the full talker, its warning and "0€", the only 0€ on the slot.
	assert_bool(dead.is_compact()).override_failure_message(case).is_false()
	assert_bool(dead.shows_text()).override_failure_message(case).is_true()
	assert_bool(dead.icon().is_visible_in_tree()).override_failure_message(case).is_true()
	assert_str(dead.text()).is_equal(SlotMark.INSPECTION_TEXT)
	var tip: String = SlotMark.ZERO_TIP % ["Spot check", SlotMark.INSPECTION_TEXT]
	assert_str(TipTarget.tip_of(dead)).is_equal(tip)
	assert_int(dead.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	_assert_on_slot(screen, dead, 2)
	_place_ids(screen, ["bread", "bread", "bread", "bread"])
	await _frames(3)
	assert_object(screen._row_strip.inspection_mark(2, 0)).is_same(dead)
	# Carded: the cause-only chip, the warning alone and the tip kept.
	assert_bool(dead.is_compact()).override_failure_message(case).is_true()
	assert_bool(dead.shows_text()).override_failure_message(case).is_false()
	assert_bool(dead.icon().is_visible_in_tree()).override_failure_message(case).is_false()
	var chip: TextureRect = dead.inner().get_node(NodePath(SlotMark.CHIP_NAME)) as TextureRect
	assert_bool(chip.is_visible_in_tree()).override_failure_message(case).is_true()
	assert_str(chip.texture.resource_path).is_equal(SlotMark.CHIP.resource_path)
	assert_vector(dead.size).is_equal(SlotMark.CHIP.get_size() * ArtStyle.ART_SCALE)
	assert_str(TipTarget.tip_of(dead)).is_equal(tip)
	_assert_on_slot(screen, dead, 2)
	# Under its ticket, centred on it (within an art pixel), its top tucked behind the foot.
	var ticket: Rect2 = (screen._row_views[2] as ItemView).sticker().get_global_rect()
	var rect: Rect2 = dead.get_global_rect()
	var message: String = "%s: chip %s under ticket %s" % [case, rect, ticket]
	var scale: float = dead.get_global_transform().get_scale().x
	var off_centre: float = absf(rect.get_center().x - ticket.get_center().x)
	assert_float(off_centre).override_failure_message(message).is_less_equal(
		ArtStyle.ART_SCALE * scale
	)
	assert_float(rect.position.y).override_failure_message(message).is_less(ticket.end.y)
	assert_float(rect.end.y).override_failure_message(message).is_greater(ticket.end.y)
	# The ticket's price window owns the amount (tickets v5): "0€" in tomato dark, its reason in
	# the tip.
	var pay: PriceWindow = screen._stage.planning_layer.pay_tag(2)
	var sticker: PriceSticker = (screen._row_views[2] as ItemView).sticker()
	assert_object(pay).is_same(sticker.window())
	assert_int(pay.pay_state()).is_equal(PriceWindow.State.ZERO)
	assert_str(pay.digits().text).is_equal("0€")
	assert_str(pay.tip_text).contains("pays 0€")
	# No other "0€" shows on the ticket and the talker: the window's digits are the only one.
	var band: Rect2 = ticket.expand(rect.end)
	var zeros: int = 0
	for label: Node in screen.find_children("*", "Label", true, false):
		var shown: Label = label as Label
		if shown.is_visible_in_tree() and shown.text.contains("0€"):
			if shown.get_global_rect().intersects(band):
				zeros += 1
	assert_int(zeros).override_failure_message(message).is_equal(0)
	# The other slots' marks: none (Spot check marks slot 3 only).
	assert_object(screen._row_strip.inspection_mark(3)).is_null()
	# The count still plays the 0€ beat on it: the chip fires.
	await Rush.checkout(screen)
	assert_int(dead.fired_count()).override_failure_message(case).is_equal(1)


func test_the_debug_panel_clears_the_inspection() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_only_spot_check(screen)
	screen._debug.set_inspection("spot_check")
	assert_array(_last_event("shift_start")["inspections"]).is_equal(["spot_check"])
	screen._debug.set_inspection("")
	assert_str(screen._calendar.text()).is_equal(DayCalendar.NORMAL_WORD)  # The day calendar.
	assert_array(screen.run.inspections).is_empty()
	assert_array(_last_event("shift_start")["inspections"]).is_empty()
	# An unknown id changes nothing.
	screen._debug.set_inspection("no_such_inspection")
	assert_str(_last_event("debug")["inspection"]).is_empty()


## The planning notice (#77 machine v2's B1): an inspected shift whose pass earns the bonus ticket
## (RewardMachine.bonus_if_passed) shows the mustard "QUOTA MET › +1 EXTRA DRAW" pill in the chip,
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
	var tag: DayCalendar = screen._calendar
	assert_int(tag.bonus_state()).is_equal(InspectionTag.Bonus.PROMISED)
	# The whole promise is on today's slip; a tight top bar shortens the pill to its ticket and "+1".
	assert_str(_slip_text(screen)).contains("QUOTA MET › +1 EXTRA DRAW")
	assert_str(tag.full_text()).contains("+1")
	await _frames(3)
	# The calendar keeps the day's kind (its width holds every page, v1.17); today's slip keeps the
	# effect.
	var effect: String = (load(SPOT_CHECK) as InspectionDefinition).notice_text
	assert_bool(tag.is_shortened()).is_false()
	assert_str(tag.text()).is_equal(InspectionTag.CAPTION)
	var said: String = _slip_text(screen)
	assert_str(said).contains(effect)
	assert_str(said).contains((load(SPOT_CHECK) as InspectionDefinition).display_name)
	assert_str(said).contains(DayCalendar.PILL_TIP)
	var chip: Rect2 = tag.get_global_rect()
	var pill: Rect2 = tag.tags.pill().get_global_rect()
	assert_bool(tag.tags.pill().visible).is_true()
	# The pill stands over the pad (DayTags, left column v2), its right edge on the pad's.
	assert_float(pill.end.y).is_less_equal(chip.position.y)
	assert_float(pill.end.x).is_less_equal(chip.end.x + 0.5)
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_bool(stage.encloses(chip) and stage.encloses(pill)).is_true()
	assert_float(pill.end.x).is_less_equal(screen._loyalty_card.get_global_rect().position.x)
	for label: Label in tag.tags.pill().find_children("*", "Label", true, false):
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
	assert_str(passed.text).is_equal("QUOTA MET ✓")
	await _frames(2)
	assert_bool(screen._monitor.get_global_rect().encloses(passed.get_global_rect())).is_true()
	assert_bool(run.machine.bonus_earned(run)).is_true()
	assert_int(tag.bonus_state()).is_equal(InspectionTag.Bonus.EARNED)
	# EARNED (v1.17): the binding teal, the check mark and "Passed"; today's slip's line names it.
	assert_str(tag.text()).is_equal(DayCalendar.EARNED_WORD)
	assert_str(tag.full_text()).starts_with(DayCalendar.EARNED_WORD + " +1")
	assert_str(WeekFlow.bonus_line(tag.bonus_state(), run.inspections)).contains(
		"Spot check passed"
	)
	assert_int(tag.look()).is_equal(DayCalendarArt.Look.EARNED)
	# The pill without "PASS ›": whole, or "+1" where the bar has no room (DayTags.fit).
	assert_array([DayTags.PILL_TEXT, DayTags.PILL_SHORT]).contains([tag.tags.pill_text()])
	screen._machine.debug_skip()  # The ticket's visit and the bonus ticket's.
	# Shift 2 is not inspected: no pill.
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.history[-1].shift).is_equal(1)
	assert_str(tag.text()).is_equal(DayCalendar.NORMAL_WORD)  # The day calendar.
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
	assert_str(TipTarget.tip_of(panel)).contains("Short belt")
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
	assert_str(screen._calendar.text()).is_equal(InspectionTag.CAPTION)
	assert_str(_slip_text(screen)).contains("Short belt")
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
	assert_str(screen._notice_label.text).contains("Row full (6/6)")
	# The closed slot's panel says an inspection closed it, and its hover text which one.
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	var caption: Label = RowStrip.closed_caption_label(screen._row_strip.closed[0])
	assert_str(caption.text).is_equal("inspection")
	assert_str(TipTarget.tip_of(screen._row_strip.closed[0])).contains("Short belt")
	assert_str(screen._calendar.text()).is_equal(InspectionTag.CAPTION)


## Day events aimed at a slot wear its mark (2026-10-31: "day event that impact a specific slot
## should be shown visually on slot"): Happy hour's green "+3€" on the row's last filled slot (slot
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
	assert_str(happy.text()).is_equal("+3€")
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


## Today's slip's words (play test 2026-11-09: the slip in place of the calendar's tooltip), opened
## as a tap on the calendar opens it, then closed.
static func _slip_text(screen: ShiftScreen) -> String:
	screen._week.drop()  # The time card (a week's first shift) would keep the slip shut.
	screen._week.toggle_slip()
	var text: String = screen._week.slip.slip_text()
	screen._week.slip.clear()
	return text
