extends GdUnitTestSuite
## The over-quota rewards (v1.03, OvertimeTickets) through the real machine on the real shift
## screen, the rewards on (the live balance, never NoOvertime): a shift-1 row making ×3 earns the
## PREMIUM ticket and the week's extra ticket; the ticket's visit opens PREMIUM with its own head
## stamp and the dock's OVERTIME caption; picking there brings the OVERTIME visit in the BONUS
## ticket's look, CLASSIC again, in its own words; picking there starts shift 2. A run saved at the
## OVERTIME visit resumes on it. Clicks are sent to the handlers (headless runs deliver no input).

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Milk, Multipack, Milk x5 = 109: ×3 the first shift's quota (30).
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_overtime_flow_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_x3_shift_plays_its_premium_ticket_then_the_overtime_visit() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	var run: RunState = screen.run
	_place(screen)
	await Rush.checkout(screen)
	var record: ShiftRecord = run.history[-1]
	assert_bool(record.overtime_ticket).is_true()
	assert_bool(record.overtime_premium).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	# The gauge's pills, held past the count, fade at once as the machine opens.
	var chip: OvertimeChip = screen._stage.quota_crossing.chip
	assert_int(chip.texts().size()).is_equal(2)
	assert_bool(chip.fading()).is_true()
	await _frames(2)
	assert_float(chip.modulate.a).is_less(1.0)
	# The ticket's visit: PREMIUM (the ×3), the OVERTIME visit next.
	var view: RewardMachineView = screen._machine.view
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])
	assert_bool(view.plan.premium).is_true()
	assert_bool(view.plan.overtime).is_true()
	await _until_armed(screen)
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.PREMIUM_STAMP)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()
	# The dock waits for the OVERTIME ticket's stub, its caption saying so, inside the dock.
	var caption: MachineLine = view.cabinet.dock_label()
	assert_str(caption.text()).is_equal(OvertimeWords.DOCK_TEXT)
	var icon: Control = view.cabinet.get_node("DockIcon")
	var caption_rect: Rect2 = Rect2(caption.position, caption.size).merge(
		Rect2(icon.position, icon.size)
	)
	(
		assert_bool(MachineCabinet.DOCK_RECT.encloses(caption_rect))
		. override_failure_message(str(caption_rect))
		. is_true()
	)
	await _pick_upgrade(screen)
	assert_str(_last_event("machine_visit")["kind"]).is_equal("ticket")
	# The OVERTIME visit: CLASSIC, shown as a BONUS visit in its own words.
	assert_int(run.shift_index).is_equal(0)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var overtime: MachineVisit = run.machine.current_visit()
	assert_int(overtime.kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(overtime.premium).is_false()
	assert_int(view.plan.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(view.plan.overtime).is_true()
	await _until_armed(screen)
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.STAMP)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.TICKET_TITLE)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_false()
	await _pick_upgrade(screen)
	var logged: Dictionary = _last_event("machine_visit")
	assert_str(logged["kind"]).is_equal("overtime")
	assert_str(logged["chute"]).is_equal("upgrade")
	# Shift 2 starts, the machine closed.
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.is_open()).is_false()


## A run saved at its OVERTIME visit (the PREMIUM ticket's pick made) resumes on that visit,
## CLASSIC, in its own words, armed at once; picking there starts shift 2.
func test_a_run_saved_at_the_overtime_visit_resumes_on_it() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(7, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	assert_object(MachineSteps.take_register(run)).is_not_null()
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(SaveService.new(_folder).save_run(run, "feedc0de12345678", 1000)).is_true()
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	await _frames(4)
	var resumed: RunState = screen.run
	var view: RewardMachineView = screen._machine.view
	assert_int(resumed.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_int(resumed.machine.current_visit().kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(resumed.machine.current_visit().premium).is_false()
	assert_bool(resumed.history[-1].overtime_ticket).is_true()
	assert_bool(view.plan.resumed).is_true()
	assert_bool(view.plan.overtime).is_true()
	assert_bool(view.is_armed()).is_true()
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.STAMP)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.TICKET_TITLE)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_false()
	await _pick_upgrade(screen)
	assert_int(resumed.shift_index).is_equal(1)
	assert_int(resumed.phase).is_equal(RunState.Phase.PLANNING)


func _place(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## UPGRADE, then its register prize picked and landed (stamped on the loyalty card).
func _pick_upgrade(screen: ShiftScreen) -> void:
	assert_bool(screen._machine._choose(RewardMachine.Chute.UPGRADE)).is_true()
	await _until_armed(screen)
	var index: int = MachineSteps.register_index(screen.run)
	assert_int(index).is_greater_equal(0)
	screen._machine.view.pick(index)
	screen._machine.on_deck_added()
	screen._machine.view.fast_forward()  # The landing plays to its end.
	await _frames(2)


func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()


func _frames(count: int) -> void:
	for _frame: int in range(count):
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


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
