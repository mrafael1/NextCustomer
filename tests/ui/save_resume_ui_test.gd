extends GdUnitTestSuite
## Save and resume on the real shift screen (full build plan section 4): run.json is written at
## every save point and deleted when the run ends; a new screen over the same save folder resumes
## the same state (with the RECEIPT REWARDS machine laid out on screen at each of its wait points,
## #77) and logs run_resume under the saved run id; an unreadable save is reported, backed up and
## replaced by a new run. Clicks are sent to the screen's handlers, because headless runs don't
## deliver input events.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_errors = []
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Every save point writes run.json: the shift's start, each place, remove and redraw, the
## checkout click (so the machine waits even during the count-up), the chute chosen (after the
## draw), the visit picked or binned, and the next shift's start. The checkout click that ends
## the run deletes it.
func test_the_screen_saves_at_every_save_point_and_deletes_the_save_at_the_end() -> void:
	var screen: ShiftScreen = await _screen()
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_str(_saved()["run_id"]).is_equal(_event_log().run_id)
	assert_array(_ints(_saved()["draw_pile"])).is_equal(_instance_ids(screen.run.deck.draw_pile()))
	var hand: Array[CardInstance] = screen.run.hand()
	screen._on_hand_card_clicked(_view_for(screen, hand[0]))
	screen._on_slot_input(_left_click(), 0)
	assert_array(_ints(_saved()["row"])).is_equal([hand[0].instance_id])
	screen._on_row_card_clicked(screen._row_views[0])
	assert_array(_saved()["row"]).is_empty()
	screen._on_background_input(_left_click())
	screen._on_redraw_pressed()
	screen._on_basket_clicked(3)
	assert_int(int(_saved()["redraws_used"])).is_equal(1)
	screen._basket_redraw.stop()
	assert_array(_hand_ids(_saved())).is_equal(_instance_ids(screen.run.deck.hand()))
	_place_ids(screen, PASSING_ROW)
	assert_int((_saved()["row"] as Array).size()).is_equal(PASSING_ROW.size())

	screen._on_checkout_pressed()
	assert_bool(screen._counting).is_true()
	assert_str(_saved()["phase"]).is_equal("machine")
	await _count_up_end(screen)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_str(_saved()["phase"]).is_equal("machine_pick")
	screen._machine._on_binned()
	screen._machine.view.fast_forward()  # The landing plays to its end.
	screen._machine._end_return()  # No glide back (#77 machine v2).
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_int(int(_saved()["shift_index"])).is_equal(1)
	_place_ids(screen, PASSING_ROW)
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_str(_saved()["phase"]).is_equal("machine")
	assert_bool(screen._machine._choose(RewardMachine.Chute.UPGRADE)).is_true()
	assert_str(_saved()["phase"]).is_equal("machine_pick")
	var perk: int = _first_perk(screen.run)
	assert_int(perk).is_greater_equal(0)
	var upgrade: UpgradeDefinition = screen.run.machine.prizes()[perk].upgrade
	screen._machine._on_prize_picked(perk)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	screen._machine._end_return()  # No glide back (#77 machine v2).
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_array(_saved()["upgrades"]).is_equal([String(upgrade.id)])

	# An empty row misses shift 3: a write-up (v0.65), saved at the click after the checkout, and the
	# run goes on to shift 4's planning, saved there.
	screen._on_checkout_pressed()
	assert_str(_saved()["phase"]).is_equal("scored")
	await _count_up_end(screen)
	assert_int(screen.run.write_ups).is_equal(1)
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_int(int(_saved()["shift_index"])).is_equal(3)
	# A second miss gets the cashier fired: the run ends at the click and its save is gone.
	screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	await _count_up_end(screen)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_array(_errors).is_empty()


## A resumed planning shift has the same hand, the same row in order and the same redraw used,
## logs run_resume (and no shift_start) under the saved run id, and continues exactly as the
## run would have.
func test_a_new_screen_resumes_the_hand_the_row_and_the_redraws() -> void:
	var first: ShiftScreen = await _screen()
	first._on_redraw_pressed()
	first._on_basket_clicked(3)
	first._basket_redraw.stop()
	var hand: Array[CardInstance] = first.run.hand()
	first._on_hand_card_clicked(_view_for(first, hand[0]))
	first._on_slot_input(_left_click(), 0)
	first._on_hand_card_clicked(_view_for(first, hand[1]))
	first._on_slot_input(_left_click(), 0)
	var run_id: String = _event_log().run_id

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(_cards(resumed.run.deck.hand())).is_equal(_cards(first.run.deck.hand()))
	assert_array(_cards(resumed.run.row)).is_equal(_cards([hand[1], hand[0]]))
	assert_array(_cards(resumed.run.deck.draw_pile())).is_equal(_cards(first.run.deck.draw_pile()))
	assert_int(resumed.run.redraws_used).is_equal(1)
	assert_int(resumed.run.redraws_allowed).is_equal(2)
	assert_bool(resumed._redraw_button.disabled).is_false()
	assert_str(resumed._redraw_button.caption).is_equal("Redraw")
	assert_str(resumed._redraw_button.note()).is_equal("1 left")
	assert_int(resumed._row_views.size()).is_equal(2)
	assert_int(_hand_views(resumed).size()).is_equal(resumed.run.hand().size())
	assert_bool(resumed._machine.is_open()).is_false()
	# The monitor's one screen in planning (#105 piece 2): belt slot 1's item and PLAN over the
	# projected total, which the QUOTA chip shows too.
	assert_int(resumed._monitor.mode()).is_equal(MonitorView.Mode.NEXT)
	var plan_column: CheckoutColumn = resumed._monitor.checkout()
	assert_str(plan_column.caption().text).is_equal(MonitorText.PLAN_CAPTION)
	assert_int(plan_column.total_number().value()).is_equal(first.run.preview().total)
	var projected: String = "€%d" % first.run.preview().total
	assert_str(resumed._quota_meter.amount_label.text).is_equal(projected)
	assert_bool(resumed._cabinet.checkout_key.held).is_false()
	# The receipt is the itemised planning receipt (#80): the header, the items and PROJECTED.
	var stub: PackedStringArray = _receipt_lines(resumed)
	assert_array(stub).is_equal(_receipt_lines(first))
	# A line's left text, then its (empty) right text.
	var shift_line: String = ReceiptView.SHIFT_TEXT % [1, resumed.run.shift_count(), 2]
	assert_array(Array(stub.slice(0, 4))).is_equal([ReceiptView.HEADER_TEXT, "", shift_line, ""])
	assert_bool(stub.has(ReceiptView.PROJECTED_TEXT)).is_true()
	assert_bool(stub.has(ReceiptView.money(first.run.preview().total))).is_true()
	assert_str(_event_log().run_id).is_equal(run_id)
	var resume: Dictionary = _last_event("run_resume")
	assert_str(resume["run_id"]).is_equal(run_id)
	assert_int(int(resume["shift"])).is_equal(1)
	assert_str(resume["phase"]).is_equal("planning")
	assert_int(int(resume["run_ms"])).is_greater_equal(0)
	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	assert_array(types.slice(types.rfind("run_resume") + 1)).is_empty()

	# The same checkout and, after a pass, the same machine draw.
	assert_int(resumed.run.checkout().total).is_equal(first.run.checkout().total)
	assert_int(resumed.run.phase).is_equal(first.run.phase)
	if first.run.phase == RunState.Phase.MACHINE_CHOOSE:
		for screen: ShiftScreen in [first, resumed]:
			screen.run.machine.choose(screen.run, RewardMachine.Chute.NEW_ITEMS)
		assert_array(_prize_ids(resumed.run)).is_equal(_prize_ids(first.run))
	assert_array(_errors).is_empty()


## Quitting during the count-up loses nothing: the save was written at the click, so a new
## screen opens on the machine waiting for its chute, laid out inside the screen, and continues
## like the first.
func test_quitting_during_the_count_up_resumes_on_the_machine() -> void:
	var first: ShiftScreen = await _screen()
	_place_ids(first, PASSING_ROW)
	first._on_checkout_pressed()
	assert_bool(first._counting).is_true()

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_int(resumed.run.last_result.total).is_equal(first.run.last_result.total)
	# The reading at TOTAL and met (#60, D5; #105 piece 2: the checkout column's TOTAL over the
	# number, its sunburst turning), and CHECKOUT up (not held): nothing is being counted on the
	# resumed screen.
	assert_int(resumed._led.mode()).is_equal(LedDisplay.Mode.TOTAL)
	assert_int(resumed._led.amount()).is_equal(first.run.last_result.total)
	var column: CheckoutColumn = resumed._monitor.checkout()
	assert_str(column.caption().text).is_equal(MonitorText.TOTAL_CAPTION)
	assert_int(column.total_number().value()).is_equal(first.run.last_result.total)
	assert_bool(column.sunburst().visible).is_true()
	assert_bool(resumed._count_up._met).is_true()
	await _assert_monitor_end_state(resumed)
	assert_bool(resumed._cabinet.checkout_key.held).is_false()
	assert_bool(first._cabinet.checkout_key.held).is_true()
	assert_str(_last_event("run_resume")["phase"]).is_equal("machine")
	assert_bool(resumed._machine.is_open()).is_true()
	# No shade over the store during a visit (#77 machine v2): the camera is at the machine.
	assert_bool(resumed._shade.visible).is_false()
	# The keys, no prizes yet, on a new timeline (no dessert on a resume, #61).
	var view: RewardMachineView = resumed._machine.view
	assert_array(view.tickets).is_empty()
	assert_bool(resumed._machine._resumed).is_true()
	assert_bool(resumed._machine._timeline.presentation_skipped).is_false()
	await _assert_on_screen(resumed, view)
	var machine: Rect2 = view.get_global_rect()
	for key: ChuteKey in view.keys:
		assert_bool(machine.encloses(key.get_global_rect())).is_true()
	# At the machine at once (#77 machine v2): the camera at 2x, the machine at MACHINE_RECT.
	var on_stage: Vector2 = resumed._stage.get_global_rect().position
	assert_that(machine.position).is_equal(on_stage + ShiftStage.MACHINE_RECT.position)

	await _count_up_end(first)
	# The receipt	await _count_up_end(first)
	# The receipt (under the shift's header, #75), totals and met state beside the machine, as
	# the count-up left them.
	assert_str(_receipt_lines(resumed)[0]).is_equal(ReceiptView.HEADER_TEXT)
	assert_bool(_receipt_lines(resumed).has(ReceiptView.PROJECTED_TEXT)).is_false()
	assert_array(_receipt_lines(resumed)).is_equal(_receipt_lines(first))
	_assert_same_led(resumed, first)
	assert_bool(first._cabinet.checkout_key.held).is_false()
	assert_bool(first._count_up._met).is_true()
	assert_bool(resumed._count_up._met).is_true()
	# The belt as the count left it (#86 v6): empty, every item in the bag, in both.
	for screen: ShiftScreen in [first, resumed]:
		_assert_belt_counted(screen, PASSING_ROW.size())
	first._machine.debug_skip()
	resumed._machine.debug_skip()
	assert_int(resumed.run.shift_index).is_equal(1)
	assert_array(_cards(resumed.run.hand())).is_equal(_cards(first.run.hand()))
	# The next shift's planning brings the row back and empties the bag.
	for screen: ShiftScreen in [first, resumed]:
		for cell: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
			assert_bool(cell.visible).is_true()
		assert_vector(screen._row_strip.box.position).is_equal(Vector2.ZERO)
		assert_array(screen._stage.bag.items()).is_empty()
		# The monitor's met state goes too.
		var monitor: MonitorView = screen._monitor
		assert_bool(monitor.checkout().tab().visible).is_false()
		assert_bool(monitor.checkout().stamp().visible).is_false()
		assert_bool(monitor.checkout().sunburst().visible).is_false()
		assert_bool(monitor.climax().is_running()).is_false()
		assert_bool(monitor.bay().is_met()).is_false()
		assert_bool(screen._stage.rail_light.is_lit()).is_false()
	assert_array(_errors).is_empty()


## A resumed checkout keeps the monitor on the final item and its complete explanation,
## with a green bay, no climax or rail light, and the final register total without celebration.
func _assert_monitor_end_state(resumed: ShiftScreen) -> void:
	var monitor: MonitorView = resumed._monitor
	var column: CheckoutColumn = monitor.checkout()
	for frame: int in range(2):
		var total: int = resumed.run.last_result.total
		assert_int(total - resumed.run.quota()).is_greater(0)
		assert_bool(column.is_visible_in_tree()).is_false()
		assert_int(resumed._register.total_display.amount()).is_equal(total)
		assert_bool(resumed._register.total_display.is_celebrating()).is_false()
		assert_bool(monitor.climax().is_running()).is_false()
		assert_that(monitor.bay().light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
		# The bay's end state (#86 round 7): the bed empty and idle on ALL PAID, THANK YOU, DONE.
		var bay: ScannerBay = monitor.bay()
		assert_object(bay.bed().art()).is_null()
		assert_bool(bay.bed().idle_label().visible).is_true()
		assert_str(bay.bed().idle_label().text).is_equal(BayBed.END_TEXT)
		assert_str(bay.chip().chip_text()).is_equal(ScannerBay.END_NAME)
		assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
		var last: int = resumed.run.row.size() - 1
		var items: MonitorItemColumn = monitor.item_column()
		assert_object(items.shown_definition()).is_same(resumed.run.row[last].definition)
		assert_int(items.shown_value()).is_equal(resumed.run.last_result.payouts[last])
		# The last item's payment equation (the last Milk under Multipack's ×3 has one), as the
		# count showed it: the newest row, inside the item column, below the line above it.
		var equation: PaymentEquation = PaymentEquation.of(resumed.run.last_result.steps, last)
		assert_object(equation).override_failure_message("PASSING_ROW's last Milk").is_not_null()
		var rows: Array[Control] = items.step_rows()
		var equations: Array[String] = []
		for row: Control in rows:
			if row.has_meta(&"equation"):
				equations.append(String(row.get_meta(&"line")))
		assert_array(equations).is_equal([equation.text(MonitorItemColumn._arrow())])
		assert_bool(rows[-1].has_meta(&"equation")).is_true()
		var shown: Rect2 = rows[-1].get_global_rect()
		(
			assert_bool(items.get_global_rect().grow(0.5).encloses(shown))
			. override_failure_message("%s outside %s" % [shown, items.get_global_rect()])
			. is_true()
		)
		assert_int(rows.size()).is_greater(1)
		assert_float(shown.position.y).is_greater_equal(rows[-2].get_global_rect().end.y - 0.5)
		assert_bool(resumed._stage.rail_light.is_lit()).is_false()
		assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)
		await _frames(5)


## `screen`'s belt as the count leaves it (#86 v6): every cell hidden, the row at rest, the
## scanner clear and `items` items in the bag, its peeking art inside the stage.
func _assert_belt_counted(screen: ShiftScreen, items: int) -> void:
	for cell: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
		assert_bool(cell.visible).is_false()
	assert_vector(screen._row_strip.box.position).is_equal(Vector2.ZERO)
	assert_bool(screen._stage.scan_layer.is_posed()).is_false()
	var bagged: Array[Control] = screen._stage.bag.items()
	assert_int(bagged.size()).is_equal(items)
	# Read in the fore's frame (the stage's at rest): at the machine it drops out of frame (#77 v2).
	var to_fore: Transform2D = screen._stage.fore.get_global_transform().affine_inverse()
	var stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	for art: Control in bagged:
		assert_bool(stage.encloses(to_fore * art.get_global_rect())).is_true()


## A run saved after its chute was chosen resumes on the same prizes (#77, MACHINE_PICK), laid
## out in the machine on screen, presented at once; the pick then lands as in the first run.
func test_a_new_screen_resumes_the_prizes() -> void:
	var first: ShiftScreen = await _screen()
	_place_ids(first, PASSING_ROW)
	await Rush.checkout(first)
	assert_bool(first._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_str(_last_event("run_resume")["phase"]).is_equal("machine_pick")
	assert_bool(resumed._machine.is_open()).is_true()
	assert_array(_prize_ids(resumed.run)).is_equal(_prize_ids(first.run))
	assert_array(_ticket_ids(resumed)).is_equal(_prize_ids(first.run))
	var times: Dictionary = resumed._machine._timeline.fields(Time.get_ticks_msec())
	assert_int(int(times["presented_ms"])).is_between(0, 100)
	var view: RewardMachineView = resumed._machine.view
	await _assert_on_screen(resumed, view)
	var window: Rect2 = resumed.get_viewport_rect()
	for ticket: PrizeTicket in view.tickets:
		assert_bool(window.encloses(ticket.get_global_rect())).is_true()
	first._machine._on_prize_picked(0)
	first._machine.view.fast_forward()  # The landing plays to its end.
	first._machine._end_return()  # No glide back (#77 machine v2).
	resumed._machine._on_prize_picked(0)
	resumed._machine.view.fast_forward()  # The landing plays to its end.
	resumed._machine._end_return()  # No glide back (#77 machine v2).
	assert_int(resumed.run.shift_index).is_equal(1)
	assert_array(_cards(resumed.run.deck.cards)).is_equal(_cards(first.run.deck.cards))
	assert_array(_cards(resumed.run.hand())).is_equal(_cards(first.run.hand()))
	var visit: Dictionary = _last_event("machine_visit")
	assert_bool(visit["resumed"]).is_true()
	assert_int(int(visit["picked"])).is_equal(0)
	assert_array(_errors).is_empty()


## A format 5 save (before #108) waiting on STAMP DAY's pick: a new screen resumes it with no
## error, at the next shift's planning (RunSaveMigration drops the free perk), the machine closed
## and the loyalty card unstamped.
func test_a_new_screen_resumes_a_migrated_stamp_day() -> void:
	var first: ShiftScreen = await _screen()
	_place_ids(first, PASSING_ROW)
	await Rush.checkout(first)
	first._machine.debug_skip()
	_place_ids(first, PASSING_ROW)
	await Rush.checkout(first)
	assert_bool(first._machine._choose(RewardMachine.Chute.UPGRADE)).is_true()
	assert_str(_saved()["phase"]).is_equal("machine_pick")
	var old: Dictionary = LegacySave.as_format(_saved(), 5)
	old["machine"]["visit"]["kind"] = "stamp_day"
	var file: FileAccess = FileAccess.open(_run_file(), FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()

	var resumed: ShiftScreen = await _screen()
	assert_str(_last_event("run_resume")["phase"]).is_equal("scored")
	assert_int(resumed.run.shift_index).is_equal(2)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(resumed._machine.is_open()).is_false()
	assert_array(resumed.run.upgrades).is_empty()
	assert_int(resumed._loyalty_card.stamped_boxes().size()).is_equal(0)
	assert_array(_errors).is_empty()


## The bonus ticket's visit (#77): after the first passed inspected shift's ticket is binned, a
## new screen resumes it waiting for its chute (the BONUS TICKET! stamp, "BONUS TICKET" on the
## display, the BONUS slip checked INSPECTION PASSED), then again with its prizes drawn; the pick
## plays the same.
func test_a_new_screen_resumes_a_bonus_visit() -> void:
	var first: ShiftScreen = await _screen()
	first.start_new_run(5)
	var reached: bool = false
	for _shift: int in range(first.run.shift_count() - 1):
		_place_ids(first, PASSING_ROW)
		await first._on_checkout_pressed()
		# A PREMIUM ticket visit's draw can be binned too (v0.61, #108).
		var ticket_chute: int = MachineSteps.first_lit(first.run, RewardMachine.Chute.NEW_ITEMS)
		assert_bool(first._machine._choose(ticket_chute)).is_true()
		if first.run.machine.can_bin():
			first._machine._on_binned()
		else:
			first._machine._on_prize_picked(0)
		first._machine.view.fast_forward()  # The landing plays to its end.
		first._machine._end_return()  # No glide back (#77 machine v2).
		var run: RunState = first.run
		# The first PREMIUM bonus visit: after shift 4's Manager's review (v0.65; shift 3's bonus is
		# CLASSIC since then).
		if (
			run.phase == RunState.Phase.MACHINE_CHOOSE
			and run.machine.current_visit().kind == MachineVisit.Kind.BONUS
			and run.machine.current_visit().premium
		):
			reached = true
			break
		first._machine.debug_skip()
	assert_bool(reached).override_failure_message("no bonus visit").is_true()

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_int(resumed.run.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_str(_last_event("run_resume")["phase"]).is_equal("machine")
	_assert_bonus_faces(resumed)
	assert_str(resumed._machine.view.display.texts()[0]).is_equal(RewardMachineView.BONUS_TITLE)
	await _assert_on_screen(resumed, resumed._machine.view)
	var chute: int = MachineSteps.first_lit(first.run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(first._machine._choose(chute)).is_true()
	assert_bool(resumed._machine._choose(chute)).is_true()

	var again: ShiftScreen = await _screen()
	assert_int(again.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_int(again.run.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_str(_last_event("run_resume")["phase"]).is_equal("machine_pick")
	_assert_bonus_faces(again)
	assert_array(_prize_ids(again.run)).is_equal(_prize_ids(first.run))
	assert_array(_ticket_ids(again)).is_equal(_prize_ids(first.run))
	first._machine._on_prize_picked(0)
	first._machine.view.fast_forward()  # The landing plays to its end.
	first._machine._end_return()  # No glide back (#77 machine v2).
	again._machine._on_prize_picked(0)
	again._machine.view.fast_forward()  # The landing plays to its end.
	again._machine._end_return()  # No glide back (#77 machine v2).
	assert_array(_cards(again.run.deck.cards)).is_equal(_cards(first.run.deck.cards))
	assert_array(_upgrade_ids(again.run.upgrades)).is_equal(_upgrade_ids(first.run.upgrades))
	var visit: Dictionary = _last_event("machine_visit")
	assert_str(visit["kind"]).is_equal("bonus")
	assert_bool(visit["resumed"]).is_true()
	assert_array(_errors).is_empty()


## A bonus visit's machine (#77 machine v2): the head's BONUS TICKET! stamp over INSPECTION PASSED,
## on the PREMIUM face (after a premium shift, v0.53: the inspected shifts are the premium ones,
## so this run's is) with gold keys and, once drawn, the chosen chute's gold column (v0.61, #108).
func _assert_bonus_faces(screen: ShiftScreen) -> void:
	var view: RewardMachineView = screen._machine.view
	assert_str(view.head.stamp_texts()[0]).is_equal("BONUS TICKET!")
	assert_str(view.head.stamp_texts()[1]).is_equal(RewardMachineView.BONUS_UNDER)
	var visit: MachineVisit = screen.run.machine.current_visit()
	assert_bool(visit.premium).is_true()
	assert_bool(view.plan.premium_held).is_true()
	assert_bool(view.head.premium_face()).is_true()
	for chute: int in RewardMachine.CHUTES:
		assert_bool(view.keys[chute].gold).is_true()
		var lit: bool = view.stock.column_lit(chute)
		assert_bool(view.stock.column_gold(chute)).is_equal(lit)


## A run saved after the shift's last visit (SCORED) resumes on the next shift's planning.
func test_a_new_screen_resumes_a_scored_run_on_the_next_shift() -> void:
	var first: ShiftScreen = await _screen()
	_place_ids(first, PASSING_ROW)
	await first._on_checkout_pressed()
	MachineSteps.pass_visits(first.run)
	assert_int(first.run.phase).is_equal(RunState.Phase.SCORED)
	var run_id: String = _event_log().run_id
	assert_bool(SaveService.new(_folder).save_run(first.run, run_id, 1000)).is_true()

	var resumed: ShiftScreen = await _screen()
	assert_str(_last_event("run_resume")["phase"]).is_equal("scored")
	assert_int(resumed.run.shift_index).is_equal(1)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(resumed._machine.is_open()).is_false()
	assert_str(_saved()["phase"]).is_equal("planning")
	first.run.next_shift()
	assert_array(_cards(resumed.run.hand())).is_equal(_cards(first.run.hand()))
	assert_array(_errors).is_empty()


## A resumed run counts only played time: run_resume carries the saved run_ms, and run_end's
## run_ms continues from it under the saved run id.
func test_a_resumed_run_keeps_its_run_id_and_played_time() -> void:
	var first: ShiftScreen = await _screen()
	assert_bool(SaveService.new(_folder).save_run(first.run, "feedc0de12345678", 600000)).is_true()
	var resumed: ShiftScreen = await _screen()
	var resume: Dictionary = _last_event("run_resume")
	assert_str(resume["run_id"]).is_equal("feedc0de12345678")
	assert_int(int(resume["run_ms"])).is_equal(600000)
	Rush.no_write_ups(resumed)  # The empty row's miss ends the run (v0.65).
	await Rush.checkout(resumed)
	var run_end: Dictionary = _last_event("run_end")
	assert_str(run_end["run_id"]).is_equal("feedc0de12345678")
	assert_int(int(run_end["run_ms"])).is_between(600000, 660000)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_array(_errors).is_empty()


## An unreadable run save is reported (to the screen's reporter: nothing prints), kept as
## run.json.bad, and a new run starts; its first save point writes over it.
func test_an_unreadable_run_save_is_backed_up_and_a_new_run_starts() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var file: FileAccess = FileAccess.open(_run_file(), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var screen: ShiftScreen = await _screen()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("can't read")
	var backup: String = _run_file() + SaveService.BACKUP_SUFFIX
	assert_str(FileAccess.get_file_as_string(backup)).is_equal("{broken")
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.is_open()).is_false()
	assert_dict(_last_event("run_resume")).is_empty()
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var saved: RunSave = SaveService.new(_folder).peek_run(lookup)
	assert_object(saved).is_not_null()
	assert_str(saved.run_id).is_equal(_event_log().run_id)


## A run started without saving (the --demo-row run) never writes or deletes the run save, so
## the run in progress survives a demo session. A new run started as usual saves again.
func test_a_run_that_doesnt_save_leaves_the_run_save_untouched() -> void:
	var screen: ShiftScreen = await _screen()
	var kept: String = FileAccess.get_file_as_string(_run_file())
	screen.start_new_run(77, false)
	Rush.no_write_ups(screen)  # The miss below ends the run (v0.65).
	_place_ids(screen, PASSING_ROW)
	await Rush.checkout(screen)
	screen._machine.debug_skip()
	# An empty row loses shift 2: the run ends without deleting the save.
	screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	await _count_up_end(screen)
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal(kept)
	screen._on_new_run_pressed()
	assert_str(_saved()["run_id"]).is_equal(_event_log().run_id)
	assert_str(FileAccess.get_file_as_string(_run_file())).is_not_equal(kept)
	assert_array(_errors).is_empty()


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	screen.report_error = _record_error
	scene_runner(screen)
	await _frames(4)
	return screen


func _record_error(message: String) -> void:
	_errors.append(message)


## The resumed screen's reading is the live one's after its count-up (#105 piece 2): the same
## mode, amount and met state, and the checkout column's same caption, number, lit lamps and tab.
func _assert_same_led(resumed: ShiftScreen, live: ShiftScreen) -> void:
	var led: LedDisplay = resumed._led
	var other: LedDisplay = live._led
	assert_int(led.mode()).is_equal(other.mode())
	assert_int(led.amount()).is_equal(other.amount())
	assert_int(led.amount()).is_greater(0)
	assert_bool(led.is_met()).is_equal(other.is_met())
	var column: CheckoutColumn = resumed._monitor.checkout()
	var live_column: CheckoutColumn = live._monitor.checkout()
	assert_str(column.caption().text).is_equal(live_column.caption().text)
	assert_int(column.total_number().value()).is_equal(live_column.total_number().value())
	assert_int(column.lit_lamps()).is_equal(live_column.lit_lamps())
	assert_str(column.tab().text).is_equal(live_column.tab().text)


## The panel is visible, fits the window and sits inside the screen once laid out.
func _assert_on_screen(screen: ShiftScreen, panel: Control) -> void:
	await _frames(4)
	await get_tree().create_timer(0.3).timeout
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var rect: Rect2 = panel.get_global_rect()
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_float(rect.size.x).is_greater(100.0)
	assert_float(rect.size.x).is_less_equal(width)
	assert_float(rect.size.y).is_less_equal(height)
	assert_bool(screen.get_global_rect().encloses(rect)).is_true()


## Waits for the screen's checkout to end, the count rushed (one tap, Rush): call it only once
## what needs the count still running has been checked.
func _count_up_end(screen: ShiftScreen) -> void:
	await Rush.finish(screen)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


## Adds the cards to the hand through the debug tools and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


func _run_file() -> String:
	return _folder.path_join(SaveService.RUN_FILE)


## The first perk (a LOYALTY prize) of `run`'s draw.
static func _first_perk(run: RunState) -> int:
	var prizes: Array[MachinePrize] = run.machine.prizes()
	for index: int in range(prizes.size()):
		if prizes[index].kind == MachinePrize.Kind.REGISTER:
			return index
	return -1


## The run save as written.
func _saved() -> Dictionary:
	if not FileAccess.file_exists(_run_file()):
		return {}
	var json: JSON = JSON.new()
	json.parse(FileAccess.get_file_as_string(_run_file()))
	return json.data


## The receipt's labels in order (a line's left text, then its right text).
static func _receipt_lines(screen: ShiftScreen) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return texts


## The prize ids of the machine's ticket views, in order.
static func _ticket_ids(screen: ShiftScreen) -> Array:
	var ids: Array = []
	for ticket: PrizeTicket in screen._machine.view.tickets:
		if not ticket.is_queued_for_deletion():
			ids.append(String(ticket.prize.id()))
	return ids


static func _hand_views(screen: ShiftScreen) -> Array[CardView]:
	var views: Array[CardView] = []
	for child: Node in screen._hand_box.get_children():
		if child is CardView and not child.is_queued_for_deletion():
			views.append(child)
	return views


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: CardView in _hand_views(screen):
		if view.card == card:
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## "instance id:card id" for each card, in order.
static func _cards(cards: Array[CardInstance]) -> Array:
	return cards.map(
		func(card: CardInstance) -> String: return "%d:%s" % [card.instance_id, card.definition.id]
	)


static func _instance_ids(cards: Array[CardInstance]) -> Array:
	return cards.map(func(card: CardInstance) -> int: return card.instance_id)


static func _hand_ids(saved: Dictionary) -> Array:
	return (saved["hand"] as Array).map(func(pair: Array) -> int: return int(pair[0]))


static func _ints(values: Array) -> Array:
	return values.map(func(value: Variant) -> int: return int(value))


## The run's machine prizes (ids, reveal order).
static func _prize_ids(run: RunState) -> Array:
	return run.machine.prizes().map(func(prize: MachinePrize) -> String: return String(prize.id()))


static func _upgrade_ids(upgrades: Array[UpgradeDefinition]) -> Array:
	return upgrades.map(func(upgrade: UpgradeDefinition) -> String: return String(upgrade.id))


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
