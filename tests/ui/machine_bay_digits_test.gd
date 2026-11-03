extends GdUnitTestSuite
## The V3 machine's parts (v0.96, mock-up docs/art/mockups/machine_relook_v2.html): the prize
## bay's header and pedestal strips (pure, and on a machine through a visit), the PREMIUM beacons,
## and A2's chunky price-gun digits on a MachineLine. Saves and the event log go to a test folder.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_bay_digits_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The prize bay's header and pedestal strips follow the plan: PRIZE BAY before the drop (none
## lit), YOUR PRIZES · KEEP 1 once it starts, each strip lit from its ticket's reveal, GOOD PICK
## from a pick's press, but never on a BIN; blank with no plan.
func test_the_prize_bay_header_and_strips_follow_the_plan() -> void:
	var tuning: MachineTuning = load(RewardMachineView.TUNING_PATH)
	assert_str(PrizeBay.header_text(null, 0.0)).is_equal("")
	for landing: int in [MachinePlan.Landing.NEW_CARD, MachinePlan.Landing.BIN]:
		var plan: MachinePlan = MachinePlan.new(tuning, MachineVisit.Kind.TICKET, false)
		assert_str(PrizeBay.header_text(plan, 0.0)).is_equal(PrizeBay.HEADER_WAIT)
		plan.set_draw([0, 1, 2] as Array[int])
		var before_drop: float = plan.drop_at[0] - 0.01
		assert_str(PrizeBay.header_text(plan, before_drop)).is_equal(PrizeBay.HEADER_WAIT)
		for index: int in range(3):
			assert_bool(PrizeBay.strip_lit(plan, before_drop, index)).is_false()
			var revealed: float = plan.reveal_at[index]
			if revealed > plan.drop_at[0]:
				assert_bool(PrizeBay.strip_lit(plan, revealed - 0.01, index)).is_false()
			assert_bool(PrizeBay.strip_lit(plan, revealed, index)).is_true()
		assert_bool(PrizeBay.strip_lit(plan, plan.pick_at, 3)).is_false()
		assert_str(PrizeBay.header_text(plan, plan.pick_at)).is_equal(PrizeBay.HEADER_DRAWN)
		plan.set_landing(landing, 1, MachinePlan.NO_VISIT)
		var picked: String = PrizeBay.header_text(plan, plan.press)
		if landing == MachinePlan.Landing.BIN:
			assert_str(picked).is_equal(PrizeBay.HEADER_DRAWN)
		else:
			assert_str(picked).is_equal(PrizeBay.HEADER_PICKED)


## The prize bay through a visit, on the stage: its header's hard pixel line says PRIZE BAY before
## the draw, YOUR PRIZES · KEEP 1 once the tickets drop and GOOD PICK after the pick; each
## pedestal strip lights as its ticket is revealed; every ticket and its pedestal sit inside the
## bay. The PREMIUM beacons are lit with the night face (held lit under reduced motion), never on a
## classic visit.
func test_the_prize_bay_follows_the_visit_and_premium_lights_its_beacons() -> void:
	var run: RunState = _passed_run(14)
	var view: RewardMachineView = await _open(run)
	view.show_at(view.plan.choose_at)
	await _frames(1)
	assert_str(view.bay.header().text()).is_equal(PrizeBay.HEADER_WAIT)
	assert_bool(view.cabinet.beacons_lit()).is_false()
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	var plan: MachinePlan = view.plan
	var count: int = plan.n_prizes
	assert_int(count).is_greater(0)
	view.show_at(plan.drop_at[0])
	assert_str(view.bay.header().text()).is_equal(PrizeBay.HEADER_DRAWN)
	view.show_at(plan.pick_at)
	await _frames(1)
	assert_int(view.bay.lit_strips().size()).is_equal(count)
	for index: int in range(count):
		var lit: bool = view.bay.lit_strips()[index]
		assert_bool(lit).override_failure_message("strip %d" % index).is_true()
	var bay: Rect2 = view.bay.get_global_rect()
	var to_global: Transform2D = view.bay.get_global_transform()
	for index: int in range(count):
		var where: String = "ticket %d of %d" % [index, count]
		var ticket: Rect2 = view.tickets[index].get_global_rect()
		assert_bool(bay.encloses(ticket)).override_failure_message(where).is_true()
		var pedestal: Rect2 = to_global * PrizeBay.pedestal_rect(index, count)
		assert_bool(bay.encloses(pedestal)).override_failure_message(where).is_true()
		assert_float(pedestal.position.y).is_greater_equal(ticket.end.y)
	assert_bool(view.cabinet.beacons_lit()).is_false()
	view.land(run.machine.pick(run, 0, null))
	view.show_at(view.plan.press + 0.01)
	assert_str(view.bay.header().text()).is_equal(PrizeBay.HEADER_PICKED)
	await _close(view)
	for rm: bool in [false, true]:
		var premium: RunState = _passed_run(16, _premium)
		var night: RewardMachineView = await _open(premium, rm)
		night.show_at(night.plan.choose_at)
		assert_bool(night.head.premium_face()).is_true()
		if rm:
			assert_bool(night.cabinet.beacons_lit()).is_true()
		else:
			var seen: Array[bool] = []
			for step: int in range(4):
				night.idle_time = (step + 0.5) / MachineCabinet.BEACON_RATE
				night.show_at(night.plan.choose_at)
				seen.append(night.cabinet.beacons_lit())
			assert_bool(seen.has(true)).override_failure_message(str(seen)).is_true()
			assert_bool(seen.has(false)).override_failure_message(str(seen)).is_true()
		await _close(night)


## A2's chunky digits (v0.96): the sheet holds every CHUNKY_ORDER glyph, 8 rows high with ink; an
## ASCII '-' prints as its −; on a MachineLine every number run prints in them and no Pixelify
## label holds a digit.
func test_the_machine_numbers_print_in_chunky_digits() -> void:
	var glyphs: Dictionary[String, Array] = PixelWords.chunky_glyphs()
	for character: String in PixelWords.CHUNKY_ORDER:
		assert_bool(glyphs.has(character)).override_failure_message(character).is_true()
		var rows: Array = glyphs[character]
		assert_int(rows.size()).override_failure_message(character).is_equal(8)
		assert_int((rows[0] as String).length()).override_failure_message(character).is_greater(0)
		assert_bool("#" in "".join(PackedStringArray(rows))).is_true()
	var chunky: PixelWords.Sheet = PixelWords.Sheet.CHUNKY
	var minus: Vector2i = PixelWords.font_size_of("−", chunky)
	assert_vector(PixelWords.font_size_of("-", chunky)).is_equal(minus)
	assert_int(minus.x).is_not_equal(PixelWords.font_size_of(" ", chunky).x)
	var digit: RegEx = RegEx.create_from_string("[0-9]")
	for text: String in ["SPEND 114€ ✓", "-2€", "ODDS +12%", "LV 2"]:
		var line: MachineLine = auto_free(MachineLine.make("Sample", text, Palette.INK))
		add_child(line)
		var numbers: Array[PixelWords] = line.number_words()
		assert_int(numbers.size()).override_failure_message(text).is_greater(0)
		for words: PixelWords in numbers:
			assert_int(words.sheet).is_equal(PixelWords.Sheet.CHUNKY)
			assert_object(digit.search(words.text)).is_not_null()
		for node: Node in line.find_children("*", "Label", true, false):
			var label: Label = node as Label
			(
				assert_object(digit.search(label.text))
				. override_failure_message("%s: %s" % [text, label.text])
				. is_null()
			)


## The machine on a 1280x720 stage at MACHINE_RECT (scale 1), open on `run`'s visit at its wait
## point (as reward_machine_layout_test opens it).
func _open(run: RunState, rm: bool = false) -> RewardMachineView:
	var stage: Control = auto_free(Control.new())
	stage.size = ShiftStage.SIZE
	add_child(stage)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.reduced_motion = func() -> bool: return rm
	add_child(view)
	view.position = ShiftStage.MACHINE_RECT.position
	var receipt: Control = Control.new()
	receipt.position = Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP)
	receipt.size = Vector2(
		ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	stage.add_child(receipt)
	view.open_visit(run, receipt, stage, false)
	view.fast_forward()
	await _frames(3)
	return view


func _close(view: RewardMachineView) -> void:
	view.close()
	await _frames(2)


## A run that passed shift 1 (`prepare`, when given, edits it first).
static func _passed_run(seed_value: int, prepare: Callable = Callable()) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(
		seed_value, load(STARTER) as DeckDefinition, balance, RunStock.starting(balance)
	)
	if prepare.is_valid():
		prepare.call(run)
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	return run


## Shift 1's ticket visit PREMIUM.
static func _premium(run: RunState) -> void:
	MachineSteps.premium_run(run, [1] as Array[int])


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
