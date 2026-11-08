extends GdUnitTestSuite
## The week badge's medals (2026-11-06, the "spend" model, mock-up
## docs/art/mockups/week_medals.html): WeekMedals' states from the run (AVAILABLE, PENDING with the
## projection, USED once spent, both back at the next week's start, OFF with the reward off), the
## sockets as drawn (MedalSockets: a medal back from USED pops in, a PENDING one wobbles, a launch
## empties its socket), the flight into the gauge's lap lamp (MedalFlight: the coin lands on the
## lamp's rect, the lamp pops, the receipt turns its metal), planning's projection on the real
## screen (the medals it would spend shimmer and the receipt's edges glow in their metal, quiet
## again when it drops) and a medal already spent moving nothing at the checkout (the receipt
## stays plain). Runs play Breads (5€ each) against quotas of 10 in weeks of 4 shifts.

const SCREEN := "res://ui/shift_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const X1 := 2
const X2 := 4
const X3 := 6
const AVAILABLE := WeekMedals.State.AVAILABLE
const PENDING := WeekMedals.State.PENDING
const USED := WeekMedals.State.USED
const OFF := WeekMedals.State.OFF

var _balance: BalanceDefinition
var _folder: String = ""


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([10, 10, 10, 10, 10, 10, 10, 10])
	_balance.week_length = 4
	_balance.weeks = []
	_balance.inspection_shifts = PackedInt32Array()
	_balance.review_shifts = PackedInt32Array()
	_balance.boon_shifts = PackedInt32Array()
	_balance.write_up_limit = 0
	var machine: MachineDefinition = _balance.machine.duplicate()
	machine.premium_shifts = PackedInt32Array()
	machine.bonus_extra_shifts = PackedInt32Array()
	machine.bonus_after_inspection = false
	_balance.machine = machine
	_folder = "user://test_week_medals_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A week opens with both medals AVAILABLE; a ×2 checkout spends the SILVER (USED from the
## checkout on, through the week), a ×3 one later the GOLD; the next week's first shift has both
## back; a resumed run shows the spent medals as they were (the shift records, no new save field).
func test_the_medals_are_spent_once_a_week_and_come_back() -> void:
	var run: RunState = _run()
	assert_array(WeekMedals.states(run, false)).is_equal([AVAILABLE, AVAILABLE])
	_check_out(run, X2)
	# During the count the shift's own spend waits for its flight; after it, the socket is empty.
	assert_array(WeekMedals.states(run, true)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false)).is_equal([USED, AVAILABLE])
	_next(run)
	assert_array(WeekMedals.states(run, false)).is_equal([USED, AVAILABLE])
	assert_array(WeekMedals.states(_round_trip(run), false)).is_equal([USED, AVAILABLE])
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.history[-1].overtime_premium).is_true()
	assert_array(WeekMedals.states(run, false)).is_equal([USED, USED])
	_next(run)
	assert_array(WeekMedals.states(run, false)).is_equal([USED, USED])
	var resumed: RunState = _round_trip(run)
	assert_array(WeekMedals.states(resumed, false)).is_equal([USED, USED])
	for _shift: int in range(2):
		_check_out(run, X1)
		_next(run)
	# Shift 5 opens week 2: both medals back.
	assert_int(run.shift_index).is_equal(4)
	assert_array(WeekMedals.states(run, false)).is_equal([AVAILABLE, AVAILABLE])


## PENDING follows planning's projection: none under ×2, the SILVER from ×2, both from ×3; never a
## spent medal, never outside planning, never on the last shift; the GOLD isn't PENDING when the
## shift's visit is PREMIUM already (it would not spend it). A reward with 0 laps is OFF.
func test_pending_follows_the_projection() -> void:
	var run: RunState = _run()
	var quota: int = run.quota()
	assert_array(WeekMedals.states(run, false, quota)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 2 - 1)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 2)).is_equal([PENDING, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 3)).is_equal([PENDING, PENDING])
	assert_array(WeekMedals.states(run, true, quota * 3)).is_equal([AVAILABLE, AVAILABLE])
	_check_out(run, X2)
	assert_array(WeekMedals.states(run, false, quota * 3)).is_equal([USED, AVAILABLE])
	_next(run)
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([USED, PENDING])
	# A premium shift's visit is PREMIUM already: the GOLD would not be spent.
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.premium_shifts = PackedInt32Array([run.shift_index + 1])
	assert_bool(run.machine.premium_if_passed(run)).is_true()
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([USED, AVAILABLE])
	run.machine.machine.overtime_ticket_laps = 0
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([OFF, AVAILABLE])
	assert_bool(WeekMedals.pending_of(run, false, run.quota() * 3)).is_false()


## On the run's last shift no machine follows: an available medal's tip says it stays unspent.
func test_the_last_shift_tip_says_no_machine_follows() -> void:
	var run: RunState = _run()
	assert_str(WeekMedals.tip_of(run, false, AVAILABLE)).contains(OvertimeWords.STATE_AVAILABLE)
	run.shift_index = run.shift_count() - 1
	assert_str(WeekMedals.tip_of(run, true, AVAILABLE)).contains(OvertimeWords.STATE_LAST)
	assert_str(WeekMedals.tip_of(run, false, USED)).contains(OvertimeWords.STATE_USED)


## The sockets as drawn: their states and tooltips, a launch empties a socket, a PENDING medal
## wobbles (not under reduced motion), a medal back from USED pops in (not under reduced motion),
## and two coins never overlap, both inside the sockets' rect.
func test_the_sockets_show_the_states() -> void:
	var sockets: MedalSockets = auto_free(MedalSockets.new())
	add_child(sockets)
	var tips: PackedStringArray = PackedStringArray(["silver", "gold"])
	sockets.show_states([AVAILABLE, PENDING] as Array[int], tips)
	sockets.size = sockets.get_combined_minimum_size()
	assert_bool(sockets.visible).is_true()
	assert_bool(sockets.wobbling(true)).is_true()
	assert_bool(sockets.wobbling(false)).is_false()
	var silver: Rect2 = sockets.medal_rect(false)
	var gold: Rect2 = sockets.medal_rect(true)
	assert_bool(silver.intersects(gold)).is_false()
	assert_float(silver.position.x).is_less(gold.position.x)
	var bounds: Rect2 = Rect2(Vector2.ZERO, sockets.size).grow(0.5)
	assert_bool(bounds.encloses(silver) and bounds.encloses(gold)).is_true()
	assert_str(sockets._get_tooltip(gold.get_center())).is_equal("gold")
	sockets.launch(true)
	assert_int(sockets.state_of(true)).is_equal(USED)
	sockets.show_states([USED, USED] as Array[int], tips)
	assert_bool(sockets.popping(false)).is_false()
	sockets.show_states([AVAILABLE, AVAILABLE] as Array[int], tips)
	assert_bool(sockets.popping(false) and sockets.popping(true)).is_true()
	sockets.advance(MedalSockets.POP_SECONDS + 0.01)
	assert_bool(sockets.popping(false) or sockets.popping(true)).is_false()
	sockets.reduced_motion = true
	sockets.show_states([USED, PENDING] as Array[int], tips)
	assert_bool(sockets.wobbling(true)).is_false()
	sockets.show_states([AVAILABLE, AVAILABLE] as Array[int], tips)
	assert_bool(sockets.popping(false)).is_false()
	sockets.show_states([OFF, OFF] as Array[int], tips)
	assert_bool(sockets.visible).is_false()


## The flight on the real screen: the SILVER leaves its socket (USED at once), flies on its own
## layer and lands on the gauge's lap lamp, which pops; `landed` is told which medal landed.
## Reduced motion: no coin flies, it lands at once.
func test_a_medal_flies_into_the_lap_lamp() -> void:
	var screen: ShiftScreen = await _screen()
	var flight: MedalFlight = screen._stage.gold_flow.flight
	var sockets: MedalSockets = screen._stage.top_bar.week_chip.medals()
	assert_int(sockets.state_of(false)).is_equal(AVAILABLE)
	var landed: Array[bool] = []
	var on_land: Callable = func(gold: bool) -> void: landed.append(gold)
	flight.fly(false, false, on_land)
	assert_int(sockets.state_of(false)).is_equal(USED)
	assert_bool(flight.is_flying()).is_true()
	var flyer: Control = flight.flyers()[0]
	var lamp: Rect2 = screen._stage.quota_meter.lamp_canvas_rect()
	assert_bool(lamp.has_area()).is_true()
	await _frames(2)
	assert_bool(flyer.get_global_rect().is_equal_approx(lamp)).is_false()
	flight.finish()
	assert_bool(flight.is_flying()).is_false()
	assert_array(landed).is_equal([false])
	assert_bool(screen._stage.quota_meter.lamp_popping()).is_true()
	flight.fly(true, true, on_land)
	assert_bool(flight.is_flying()).is_false()
	assert_array(landed).is_equal([false, true])
	assert_int(sockets.state_of(true)).is_equal(USED)


## The flyer's last frame sits on the lamp (the arc's end is the lamp's rect).
func test_the_flight_ends_on_the_lamp() -> void:
	var from: Rect2 = Rect2(10, 10, 13, 13)
	var to: Rect2 = Rect2(300, 400, 26, 26)
	assert_object(MedalFlight._arc(from, to, 0.0)).is_equal(from)
	var end: Rect2 = MedalFlight._arc(from, to, 1.0)
	assert_vector(end.position).is_equal_approx(to.position, Vector2.ONE * 0.01)
	assert_vector(end.size).is_equal_approx(to.size, Vector2.ONE * 0.01)
	var mid: Rect2 = MedalFlight._arc(from, to, 0.5)
	var line_y: float = lerpf(from.get_center().y, to.get_center().y, 0.5)
	assert_float(mid.get_center().y).is_less(line_y)


## Planning on the real screen: the medals the preview's projection would spend shimmer and the
## receipt's edges glow in their metal (gold over silver), quiet again when it drops; the count
## begins with no glow.
func test_the_projection_lights_the_pending_medals_and_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	var sockets: MedalSockets = screen._stage.top_bar.week_chip.medals()
	var gold: ReceiptGold = screen._stage.receipt.gold
	screen._week.show_pending(0)
	assert_array(sockets.states()).is_equal([AVAILABLE, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	var quota: int = screen.run.quota()
	screen._week.show_pending(quota * 2)
	assert_array(sockets.states()).is_equal([PENDING, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_SILVER)
	screen._week.show_pending(quota * 3)
	assert_array(sockets.states()).is_equal([PENDING, PENDING])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_GOLD)
	screen._week.show_pending(quota)
	assert_array(sockets.states()).is_equal([AVAILABLE, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	# The real preview: a row making ×3 shows both pending.
	_place_milks(screen, 7)
	await _frames(2)
	assert_int(OvertimeTickets.laps(screen.run.preview().total, quota)).is_greater_equal(3)
	assert_array(sockets.states()).is_equal([PENDING, PENDING])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_GOLD)
	await Rush.checkout(screen)
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)


## A medal already spent this week moves nothing at the checkout (a cap of 0 stands for one spent
## earlier): reaching its laps, no coin flies, the socket stays empty and the receipt stays plain
## cream with no stamp; the lap still fills in its colour.
func test_a_spent_medal_leaves_the_receipt_plain() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.overtime_ticket_per_week = 0
	run.machine.machine.overtime_premium_per_week = 0
	screen._week.show_chips()
	var sockets: MedalSockets = screen._stage.top_bar.week_chip.medals()
	assert_array(sockets.states()).is_equal([USED, USED])
	_place_milks(screen, 7)
	await _frames(2)
	var quota: int = run.quota()
	assert_int(OvertimeTickets.laps(run.preview().total, quota)).is_greater_equal(3)
	assert_array(sockets.states()).is_equal([USED, USED])
	assert_int(screen._stage.receipt.gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	await Rush.checkout(screen)
	var flow: ReceiptGoldFlow = screen._stage.gold_flow
	assert_bool(flow.has_flown(false) or flow.has_flown(true)).is_false()
	assert_bool(flow.flight.is_flying()).is_false()
	var receipt: ReceiptView = screen._stage.receipt
	assert_bool(receipt.gold.is_gold() or receipt.gold.is_silver()).is_false()
	assert_object(receipt.gold.stamp()).is_null()
	assert_array(sockets.states()).is_equal([USED, USED])
	assert_int(screen._stage.quota_meter.multiples_made()).is_greater_equal(3)


func _run() -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(7, deck, _balance, RunStock.starting(_balance))
	run.start_shift()
	return run


## Checks out `breads` Breads (5€ each).
func _check_out(run: RunState, breads: int) -> void:
	for _index: int in range(breads):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


func _next(run: RunState) -> void:
	assert_bool(MachineSteps.next_shift(run)).is_true()


func _round_trip(run: RunState) -> RunState:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var data: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	return save.run if save != null else null


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	return screen


## `count` items on the belt: Milk, Multipack, then Milks (7 make 109€, ×3 the first quota).
func _place_milks(screen: ShiftScreen, count: int) -> void:
	var ids: Array[String] = ["milk", "multipack"]
	for _index: int in range(count - 2):
		ids.append("milk")
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
