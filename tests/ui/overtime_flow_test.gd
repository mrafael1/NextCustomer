extends GdUnitTestSuite
## The over-quota rewards (v1.03, OvertimeTickets; the week medals since 2026-11-06, mock-up
## docs/art/mockups/week_medals.html) through the real machine on the real shift screen, the
## rewards on (the live balance, never NoOvertime): a shift-1 row making ×3 spends the week's
## SILVER and GOLD medals (both sockets empty, the receipt gold); the receipt feeds once and lights
## 2 draw lamps; the ticket's visit opens PREMIUM with the GOLD MEDAL! stamp; after its prize the
## lamp goes out and the SILVER medal's extra draw opens on AGAIN! from the same receipt, PREMIUM
## too (the GOLD made the visit premium), with no ticket anywhere: no stub, no dock, no queued
## ticket; picking there starts shift 2. With a bonus extra shift on top the receipt lights 3
## lamps. A run saved at the extra draw resumes on it. Clicks are sent to the handlers (headless
## runs deliver no input).

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Milk, Multipack, Milk x5 = 109: ×3 the first shift's quota (30).
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const USED: Array[int] = [WeekMedals.State.USED, WeekMedals.State.USED]
## The removed ticket nodes' names (TicketQueue's dock, its icon, the top bar's ticket slots, the
## gauge's OvertimeChip, the receipt's BONUS stub and the dessert's banner beside it): none is
## left anywhere on the screen.
const GONE_NODES: Array[String] = [
	"Dock",
	"QueueIcon",
	"OvertimeTickets",
	"OvertimeChip",
	"TicketClip",
	"TicketSlot",
	"BonusTicket",
	"BonusStub",
	"BonusBanner",
]

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


func test_a_x3_shift_spends_both_medals_and_draws_twice_from_one_receipt() -> void:
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
	# Both medals left their sockets; the receipt turned gold; no stub was printed.
	screen._stage.gold_flow.flight.finish()
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(USED)
	assert_bool(screen._stage.receipt.gold.is_gold()).is_true()
	assert_object(screen._receipt.find_child("BonusStub", true, false)).is_null()
	# The ticket's visit: PREMIUM (the GOLD), the SILVER's extra draw next; 2 lamps.
	var view: RewardMachineView = screen._machine.view
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])
	assert_bool(view.plan.premium).is_true()
	assert_bool(view.plan.overtime).is_false()
	assert_int(view.plan.draws).is_equal(2)
	assert_int(view.plan.draw_index).is_equal(0)
	await _until_armed(screen)
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.GOLD_STAMP)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()
	assert_int(view.slot_plate.lamp_count()).is_equal(2)
	assert_int(view.slot_plate.lamps_lit()).is_equal(2)
	_assert_no_ticket(screen)
	await _pick_upgrade(screen)
	assert_str(_last_event("machine_visit")["kind"]).is_equal("ticket")
	# The SILVER's extra draw: AGAIN!, PREMIUM too (the GOLD's visit), from the same receipt.
	assert_int(run.shift_index).is_equal(0)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var overtime: MachineVisit = run.machine.current_visit()
	assert_int(overtime.kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(overtime.premium).is_true()
	assert_int(view.plan.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(view.plan.overtime).is_true()
	assert_bool(view.plan.is_again()).is_true()
	assert_int(view.plan.draw_index).is_equal(1)
	assert_int(view.plan.draws).is_equal(2)
	view.show_at(0.1)
	var again: Array = [OvertimeWords.AGAIN, "%s · draw 2 of 2" % OvertimeWords.SILVER_REASON]
	assert_array(Array(view.display.texts())).is_equal(again)
	assert_bool(view.display.ticket_icon().visible).is_false()
	await _until_armed(screen)
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.SILVER_STAMP)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.AGAIN)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()
	_assert_no_ticket(screen)
	await _pick_upgrade(screen)
	var logged: Dictionary = _last_event("machine_visit")
	assert_str(logged["kind"]).is_equal("overtime")
	assert_str(logged["chute"]).is_equal("upgrade")
	# Shift 2 starts, the machine closed; the week's medals stay spent.
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.is_open()).is_false()
	await _frames(2)
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(USED)


## A run saved at its extra draw (the PREMIUM ticket's pick made) resumes on that draw: PREMIUM,
## AGAIN! with the SILVER MEDAL! stamp, one lamp lit, armed at once; picking there starts shift 2.
## The week's medals stay spent through the resume.
func test_a_run_saved_at_the_extra_draw_resumes_on_it() -> void:
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
	assert_bool(resumed.machine.current_visit().premium).is_true()
	assert_bool(resumed.history[-1].overtime_ticket).is_true()
	assert_bool(view.plan.resumed).is_true()
	assert_bool(view.plan.overtime).is_true()
	assert_bool(view.is_armed()).is_true()
	assert_int(view.plan.draw_index).is_equal(1)
	assert_int(view.plan.draws).is_equal(2)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.SILVER_STAMP)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.AGAIN)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(USED)
	await _pick_upgrade(screen)
	assert_int(resumed.shift_index).is_equal(1)
	assert_int(resumed.phase).is_equal(RunState.Phase.PLANNING)
	await _frames(2)
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(USED)


## With a bonus extra shift on top (a machine copy), the receipt pays 3 draws: 3 lamps lit at the
## ticket's visit, 2 at the BONUS draw, 1 at the SILVER's; each later draw opens on AGAIN!.
func test_three_draws_light_three_lamps() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	var run: RunState = screen.run
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.bonus_extra_shifts = PackedInt32Array([1])
	_place(screen)
	await Rush.checkout(screen)
	assert_array(run.machine.pending_kinds()).is_equal(
		[MachineVisit.Kind.BONUS, MachineVisit.Kind.OVERTIME]
	)
	var view: RewardMachineView = screen._machine.view
	await _until_armed(screen)
	assert_int(view.plan.draws).is_equal(3)
	assert_int(view.slot_plate.lamp_count()).is_equal(3)
	assert_int(view.slot_plate.lamps_lit()).is_equal(3)
	for index: int in range(2):
		var at: Rect2 = view.slot_plate.lamp_rect(index)
		var next: Rect2 = view.slot_plate.lamp_rect(index + 1)
		assert_float(next.position.x - at.end.x).is_greater(0.0)
		assert_bool(SlotPlate.FACE_RECT.encloses(at)).is_true()
	for index: int in range(3):
		var lamp: Rect2 = view.slot_plate.lamp_rect(index)
		assert_bool(SlotPlate.FACE_RECT.encloses(lamp)).is_true()
		assert_bool(lamp.intersects(SlotPlate.ARROW_RECT)).is_false()
	await _pick_upgrade(screen)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_int(view.plan.draw_index).is_equal(1)
	await _until_armed(screen)
	assert_int(view.slot_plate.lamps_lit()).is_equal(2)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.AGAIN)
	await _pick_upgrade(screen)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_int(view.plan.draw_index).is_equal(2)
	await _until_armed(screen)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.AGAIN)
	_assert_no_ticket(screen)


## No ticket anywhere (2026-11-06): no bonus ticket in the machine's feed, none of the removed
## ticket nodes on the screen.
func _assert_no_ticket(screen: ShiftScreen) -> void:
	var found: Array[String] = []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for gone: String in GONE_NODES:
			if String(node.name).begins_with(gone):
				found.append(str(node.get_path()))
		stack.append_array(node.get_children())
	assert_array(found).is_empty()


func _place(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## UPGRADE, then its register prize picked and landed (stamped on the loyalty card).
func _pick_upgrade(screen: ShiftScreen) -> void:
	var view: RewardMachineView = screen._machine.view
	assert_bool(screen._machine._choose(RewardMachine.Chute.UPGRADE)).is_true()
	await _until_armed(screen)
	var index: int = MachineSteps.register_index(screen.run)
	assert_int(index).is_greater_equal(0)
	view.pick(index)
	screen._machine.on_deck_added()
	view.fast_forward()  # The landing plays to its end.
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
