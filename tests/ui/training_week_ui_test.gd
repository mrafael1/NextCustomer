extends GdUnitTestSuite
## The training week on the real shift screen (v0.68, full build plan section 5.3), with the loaded
## balance's slips (never Rush.no_write_ups): a missed shift 1-4 stamps SLIP n/2 and NO TICKET on
## the receipt, gets no machine visit, brings the music back and opens the next shift with its
## notice; the third miss ends the run, and the final receipt reads "slip" for the forgiven
## misses. Week 1's planning shows the TRAINING WEEK hint in the SHIFT chip (its geometry checked),
## gone from shift 5, which opens with "Training is over" once the glide back from the review's
## visits has ended; a slip's notice before a payday waits for its announce's print. A save taken
## at a slip's click resumes
## into the next shift with the notice. Clicks are sent to the screen's handlers, because headless
## runs don't deliver input events.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const STEP := 0.1

var _folder: String = ""
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_training_%d" % Time.get_ticks_usec()
	_errors = []
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Two slips, then the third miss: each slip's receipt carries SLIP n/2 and NO TICKET, no visit
## opens, the music is back and the next shift's planning shows the notice; the third miss shows
## the results, whose final receipt reads "slip" for the slips and "fail" for the last miss.
func test_slips_then_fired() -> void:
	var screen: ShiftScreen = await _screen()
	assert_int(screen.run.balance.write_up_limit).is_equal(2)
	for slip: int in range(1, 3):
		var printed: PackedStringArray = await _checkout_empty(screen)
		var stamp: String = "SLIP %d/2" % slip
		assert_bool(printed.has(stamp)).override_failure_message(str(printed)).is_true()
		assert_bool(printed.has(WriteUp.NO_TICKET)).override_failure_message(str(printed)).is_true()
		assert_str(screen._count_up._dessert.write_up).is_equal(stamp)
		assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
		assert_int(screen.run.shift_index).is_equal(slip)
		assert_bool(screen._machine.is_open()).is_false()
		assert_bool(screen._results.visible).is_false()
		assert_bool(screen._music.is_ducked()).is_false()
		await _frames(2)  # The notice shows once planning takes input (MachineFlow).
		assert_bool(screen._notice_label.is_showing()).is_true()
		assert_str(screen._notice_label.text).is_equal(WriteUp.notice_text(screen.run))
		assert_str(screen._notice_label.text).starts_with("Slip %d/2" % slip)
	assert_str(screen._notice_label.text).contains("the next miss ends the run")
	await _checkout_empty(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	assert_bool(screen._results.visible).is_true()
	# The results screen's own receipt: its shift lines, as FinalReceipt.lines printed them.
	var texts: PackedStringArray = screen._results.texts()
	var verdicts: Array[String] = []
	for shift: int in range(1, 4):
		verdicts.append(_shift_line(texts, shift))
	assert_str(verdicts[0]).override_failure_message(str(texts)).contains("slip")
	assert_str(verdicts[1]).override_failure_message(str(texts)).contains("slip")
	assert_str(verdicts[2]).override_failure_message(str(texts)).contains("fail")
	assert_str(verdicts[2]).not_contains("slip")
	assert_array(_errors).is_empty()


## A passed review (shift 4, both inspections) and its two PREMIUM visits, then the glide back to
## shift 5: "Training is over" waits for the glide to end, so it shows with the store in view.
func test_training_is_over_waits_for_the_glide_back() -> void:
	var screen: ShiftScreen = await _screen()
	_low_quotas(screen)
	screen._debug.skip_to_shift(4)
	await _frames(2)
	assert_int(screen.run.inspections.size()).is_equal(2)
	await _pass(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	for _visit: int in range(6):
		if not RunState.MACHINE_PHASES.has(screen.run.phase):
			break
		_end_visit(screen)
	var flow: MachineFlow = screen._machine
	assert_int(screen.run.shift_index).is_equal(4)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(flow.is_gliding()).is_true()
	var length: float = MachinePlan.return_length(flow.view.tuning, false)
	var elapsed: float = 0.0
	while flow.is_gliding() and elapsed < length + 1.0:
		assert_bool(screen._notice_label.is_showing()).is_false()
		flow._process(STEP)
		elapsed += STEP
	assert_bool(flow.is_gliding()).is_false()
	# Shift 5 opens week 2: its time card (v0.70) plays first, and the notice waits for it.
	flow._process(STEP)
	assert_bool(screen._notice_label.is_showing()).is_false()
	screen._week._process(STEP)
	var card: WeekCard = screen._week.card
	assert_bool(card.is_open()).is_true()
	card.finish()
	card.advance(WeekCard.HOLD + 0.1)
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	flow._process(STEP)
	assert_bool(screen._notice_label.is_showing()).is_true()
	assert_str(screen._notice_label.text).is_equal(WriteUp.OVER_NOTICE)
	assert_array(_errors).is_empty()


## A slip on shift 3, then shift 4 (a review and a payday): the slip's notice waits until the
## PAYDAY announce has printed on the monitor, so they never cover each other.
func test_a_slip_notice_waits_for_the_payday_announce() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(3)
	await _frames(2)
	await _checkout_empty(screen)
	assert_int(screen.run.shift_index).is_equal(3)
	assert_bool(Payday.if_passed(screen.run)).is_true()
	var flow: MachineFlow = screen._machine
	var announce: PremiumAnnounce = flow.announce
	var printed: bool = false
	var shown_at: float = -1.0
	var elapsed: float = 0.0
	while elapsed < 6.0 and shown_at < 0.0:
		announce._process(STEP)
		flow._process(STEP)
		elapsed += STEP
		printed = printed or announce.is_shown()
		if screen._notice_label.is_showing():
			shown_at = elapsed
			# Within a step: the flow and the announce tick in either order each frame.
			assert_float(announce.print_left()).is_less_equal(STEP)
	assert_bool(printed).override_failure_message("the announce never printed").is_true()
	assert_float(shown_at).override_failure_message("the notice never showed").is_greater(0.0)
	assert_float(shown_at).is_greater_equal(
		PremiumAnnounce.FLY_TO + PremiumAnnounce.RING_LENGTH - 2.0 * STEP
	)
	assert_str(screen._notice_label.text).starts_with("Slip 1/2")
	assert_array(_errors).is_empty()


## The run's balance with every quota low, so a few Milks pass any shift (the loaded balance is
## shared, so it is never changed itself).
static func _low_quotas(screen: ShiftScreen) -> void:
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(balance.quotas.size())
	quotas.fill(5)
	balance.quotas = quotas
	screen.run.balance = balance


## Places Milks until the row meets the quota, then checks out, rushed.
func _pass(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	for _card: int in range(8):
		if run.preview().total >= run.quota():
			break
		screen._debug.add_card("milk")
		screen._on_hand_card_clicked(_view_for(screen, run.hand()[-1]))
		screen._on_slot_input(_left_click(), run.row.size())
	assert_int(run.preview().total).is_greater_equal(run.quota())
	await Rush.checkout(screen)


## Ends the machine's current visit: chooses a lit chute, then takes or bins its first prize.
static func _end_visit(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	screen._machine.view.fast_forward()
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS)
		screen._machine._choose(chute)
	if run.machine.can_bin():
		screen._machine._on_binned()
	else:
		screen._machine._take(0, run.deck.cards[0] if run.deck_is_full() else null)
	screen._machine.view.fast_forward()


## The receipt line of `shift` among `texts` ("  3  €0 / €40  fail"), else "".
static func _shift_line(texts: PackedStringArray, shift: int) -> String:
	var lead: String = "%3d  " % shift
	for text: String in texts:
		if text.begins_with(lead):
			return text
	return ""


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


## The hint sits in the SHIFT chip, which keeps its height (the quota chip's), clear of the quota
## chip, and the row's chips stay inside the row's width on an inspected shift too; it counts the
## slips left and is gone on shift 5, which opens with "Training is over".
func test_the_training_hint_in_the_shift_chip() -> void:
	var screen: ShiftScreen = await _screen()
	var bar: TopBar = screen._top_bar as TopBar
	var hint: Label = bar.training_label
	# The week chip and the day chip (v0.70) take room: the hint may show its short form.
	await _frames(2)
	assert_bool(hint.is_visible_in_tree()).is_true()
	assert_str(WriteUp.hint_text(screen.run)).is_equal("TRAINING WEEK · 2 SLIPS")
	assert_array(_hint_forms(screen)).contains([hint.text])
	_assert_hint_layout(bar)
	await _checkout_empty(screen)
	# Shift 2's boon (drawn with week 1, v0.70) may need the room: a day without one has it.
	screen._debug.set_inspection("")
	await _frames(2)
	assert_str(WriteUp.hint_text(screen.run)).is_equal("TRAINING WEEK · 1 SLIP")
	assert_array(_hint_forms(screen)).contains([hint.text])
	_assert_hint_layout(bar)
	# Shift 3 is inspected: its chip shares the row with the hint.
	screen._debug.skip_to_shift(3)
	await _frames(2)
	assert_bool(bar.inspection_tag.is_visible_in_tree()).is_true()
	_assert_hint_shares_the_row(screen, bar)
	# Shift 4 is the review: two inspections in its chip, beside the hint.
	screen._debug.skip_to_shift(4)
	await _frames(2)
	assert_int(screen.run.inspections.size()).is_equal(2)
	_assert_hint_shares_the_row(screen, bar)
	screen._debug.skip_to_shift(5)
	screen._week.skip()  # Week 2's time card (v0.70) is not what this checks.
	await _frames(2)
	assert_bool(hint.visible).is_false()
	assert_str(screen._notice_label.text).is_equal(WriteUp.OVER_NOTICE)
	# Counting hides the hint (on a day without an event: the hint has room).
	screen._debug.skip_to_shift(2)
	screen._debug.set_inspection("")
	await _frames(2)
	assert_bool(hint.visible).is_true()
	screen._on_checkout_pressed()
	assert_bool(hint.visible).is_false()
	await Rush.finish(screen)
	assert_array(_errors).is_empty()


## A save taken at a slip's click (SCORED, before the count-up's end) resumes into the next
## shift's planning with the slip's notice; quitting there and resuming shows it again.
func test_resuming_after_a_slip_shows_the_notice() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_checkout_pressed()
	assert_str(_saved_phase()).is_equal("scored")
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.shift_index).is_equal(1)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(resumed._notice_label.is_showing()).is_true()
	assert_str(resumed._notice_label.text).is_equal("Slip 1/2 — training week")
	var again: ShiftScreen = await _screen()
	assert_int(again.run.shift_index).is_equal(1)
	assert_str(again._notice_label.text).is_equal("Slip 1/2 — training week")
	assert_array(_errors).is_empty()


## On an inspected shift the hint is shown whole or short, or gives way to the day's effects
## (v0.70: the week and day chips take room), its tooltip whole; the inspection's effects are
## trimmed only once the week chip's name and pips gave way too.
func _assert_hint_shares_the_row(screen: ShiftScreen, bar: TopBar) -> void:
	var hint: Label = bar.training_label
	var forms: Array[String] = [WriteUp.hint_text(screen.run), WriteUp.hint_text(screen.run, true)]
	var shift_chip: Control = bar.shift_label.get_parent().get_parent() as Control
	assert_str(shift_chip.tooltip_text).is_equal(forms[0])
	if bar.inspection_tag.is_trimmed():
		assert_bool(hint.visible).is_false()
		assert_bool(bar.week_chip.name_shown() or bar.week_chip.pips_shown()).is_false()
	if hint.visible:
		assert_array(forms).contains([hint.text])
		_assert_hint_layout(bar)


## The hint's two forms: whole and short.
static func _hint_forms(screen: ShiftScreen) -> Array[String]:
	return [WriteUp.hint_text(screen.run), WriteUp.hint_text(screen.run, true)]


func _assert_hint_layout(bar: TopBar) -> void:
	var hint: Rect2 = bar.training_label.get_global_rect()
	var shift_chip: Control = bar.shift_label.get_parent().get_parent() as Control
	var chip: Rect2 = shift_chip.get_global_rect()
	var row: Rect2 = Rect2(bar.global_position, TopBar.ROW_SIZE)
	assert_bool(hint.has_area()).is_true()
	assert_bool(chip.encloses(hint)).override_failure_message("%s in %s" % [hint, chip]).is_true()
	assert_float(chip.position.x).is_greater_equal(row.position.x)
	# With weeks (v0.82) the chip holds the hint alone; without them it follows "SHIFT n/m".
	if bar.shift_label.visible:
		var shift: Rect2 = bar.shift_label.get_global_rect()
		assert_float(hint.position.x).is_greater_equal(shift.end.x)
	var quota_chip: Rect2 = (bar.quota_meter.get_parent() as Control).get_global_rect()
	# The hint doesn't make the SHIFT chip taller than its neighbour.
	var heights: String = "%s beside %s" % [chip, quota_chip]
	assert_float(chip.size.y).override_failure_message(heights).is_equal(quota_chip.size.y)
	assert_float(chip.position.y).override_failure_message(heights).is_equal(quota_chip.position.y)
	assert_bool(quota_chip.intersects(hint)).is_false()
	assert_float(quota_chip.size.x).is_greater(0.0)
	for child: Node in bar.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			var rect: Rect2 = control.get_global_rect()
			assert_float(rect.end.x).override_failure_message(control.name).is_less_equal(row.end.x)


## Checks out the current (empty) row, rushed, and returns every receipt text printed while it
## counted.
func _checkout_empty(screen: ShiftScreen) -> PackedStringArray:
	var printed: PackedStringArray = PackedStringArray()
	screen._on_checkout_pressed()
	Rush.rush(screen._count_up)
	var start: int = Time.get_ticks_msec()
	while screen._counting and Time.get_ticks_msec() - start < Rush.MAX_WAIT_MS:
		Rush.rush(screen._count_up)
		for text: String in _receipt_texts(screen):
			if not printed.has(text):
				printed.append(text)
		await get_tree().process_frame
	assert_bool(screen._counting).is_false()
	return printed


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	screen.report_error = _record_error
	scene_runner(screen)
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(4)
	return screen


func _record_error(message: String) -> void:
	_errors.append(message)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


func _saved_phase() -> String:
	var file: FileAccess = FileAccess.open(_folder.path_join(SaveService.RUN_FILE), FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	return str((data as Dictionary).get("phase", "")) if data is Dictionary else ""


static func _receipt_texts(screen: ShiftScreen) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			texts.append((label as Label).text)
	return texts


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
