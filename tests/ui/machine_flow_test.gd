extends GdUnitTestSuite
## The RECEIPT REWARDS machine on the real shift screen (#77, MachineFlow): a passed checkout
## opens it inside the stage, over the shade, with the register column left unshaded; its keys
## are lit or padlocked from the run; a confirmed chute draws its prizes, which the scanner reads
## as items once armed; a pick lands (the card in the deck, a register stamped on the loyalty
## card) and the next shift starts; BIN IT bins; STAMP DAY's stamps can't be binned; every visit
## is logged as machine_visit with its timeline; every resume frame of build spec 4.3 shows as
## its table says. Clicks are sent to the handlers, because headless runs don't deliver input
## events. The deck-full chooser: shift_screen_test; the resumed picks: save_resume_ui_test.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The machine stands in the store (#77 machine v2): once the camera has glided to it, it shows at
## the stage's MACHINE_RECT, inside the stage, with no shade over the store (the receipt has been
## fed: the stage's own is torn off); the keys sit in the machine, NEW ITEMS, COUPONS and REGISTER
## lit and UPGRADES padlocked after shift 1.
func test_a_pass_opens_the_machine_inside_the_stage_beside_the_receipt() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	assert_bool(screen._machine.is_open()).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	view.fast_forward()
	await _frames(3)
	assert_float(screen._camera.progress()).is_equal(1.0)
	var stage: Rect2 = screen._stage.get_global_rect()
	var machine: Rect2 = view.get_global_rect()
	assert_vector(machine.position).is_equal(stage.position + ShiftStage.MACHINE_RECT.position)
	assert_vector(machine.size).is_equal(ShiftStage.MACHINE_RECT.size)
	assert_bool(stage.encloses(machine)).override_failure_message(str(machine)).is_true()
	assert_bool(screen._shade.visible).is_false()
	assert_bool(screen._receipt.visible).is_false()
	assert_int(view.keys.size()).is_equal(RewardMachine.CHUTES.size())
	for key: ChuteKey in view.keys:
		assert_bool(machine.encloses(key.get_global_rect())).is_true()
	var states: Array = RewardMachine.CHUTES.map(
		func(chute: int) -> int: return screen.run.machine.chute_info(screen.run, chute).state
	)
	var open: int = RewardMachine.ChuteState.OPEN
	assert_array(states).is_equal([open, open, open, RewardMachine.ChuteState.LOCKED_SHIFT])
	assert_array(view.tickets).is_empty()


## The real flow: a lit key's odds card, CONFIRM draws the prizes (saved at MACHINE_PICK), the
## scanner reads a prize item once armed, the pick lands in the deck, machine_visit logs the
## visit (the odds card viewed, its timeline) and the next shift starts with the machine closed.
func test_choose_scan_and_pick_a_prize() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _until_armed(screen)
	view.hover_key(RewardMachine.Chute.NEW_ITEMS)
	assert_bool(view.odds_card.visible).is_true()
	# Machine v2: the key is pressed, then CONFIRM › on the display confirms it.
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	view.display.press_confirm()
	view.display._confirm_at_ms -= view.tuning.confirm_down_ms + 1
	view.display.frame(view.clock)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_str(_saved_phase()).is_equal("machine_pick")
	var prizes: Array[MachinePrize] = screen.run.machine.prizes()
	assert_int(view.tickets.size()).is_equal(prizes.size())
	await _frames(3)
	var machine: Rect2 = view.get_global_rect()
	for ticket: PrizeTicket in view.tickets:
		assert_bool(machine.encloses(ticket.get_global_rect())).is_true()
	# The prize items are the scanner's once the machine has armed.
	var items: Array[ItemView] = view.items()
	assert_int(items.size()).is_equal(prizes.size())
	await _until_armed(screen)
	assert_bool(view.can_scan()).is_true()
	screen._scan._on_hovered(items[0])
	assert_object(screen._scan.scanned()).is_same(items[0])
	screen._scan.clear()
	var card: CardDefinition = prizes[1].card
	view.pick(1)
	view.fast_forward()  # The landing plays to its end.
	assert_int(screen.run.deck.size()).is_equal(14)
	assert_array(screen.run.history[0].cards_added()).is_equal([card])
	assert_int(screen.run.shift_index).is_equal(1)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.is_open()).is_false()
	var visit: Dictionary = _last_event("machine_visit")
	assert_str(visit["kind"]).is_equal("ticket")
	assert_str(visit["chute"]).is_equal("new_items")
	assert_int(int(visit["picked"])).is_equal(1)
	assert_array(visit["chutes_viewed"]).is_equal(["new_items"])
	assert_bool((visit["odds_shown"] as Dictionary).is_empty()).is_false()
	assert_int(int(visit["presented_ms"])).is_greater_equal(0)
	assert_int(int(visit["armed_ms"])).is_greater_equal(int(visit["presented_ms"]))
	assert_int(int(visit["decide_ms"])).is_greater_equal(int(visit["armed_ms"]))
	assert_bool(visit["presentation_skipped"]).is_false()
	assert_bool(visit["resumed"]).is_false()


## BIN IT bins the draw: the deck is kept, the visit logged as binned, the next shift starts.
func test_bin_it_bins_the_draw() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	assert_bool(screen._machine._choose(RewardMachine.Chute.COUPONS)).is_true()
	assert_bool(view.display.bin_button().visible).is_false()  # Shown once the reveals end.
	await _until_armed(screen)
	assert_bool(view.display.bin_button().visible).is_true()
	view._on_bin_pressed()
	view.fast_forward()  # The landing plays to its end.
	assert_int(screen.run.deck.size()).is_equal(13)
	assert_int(screen.run.shift_index).is_equal(1)
	var visit: Dictionary = _last_event("machine_visit")
	assert_str(visit["chute"]).is_equal("coupons")
	assert_bool(visit["binned"]).is_true()
	assert_int(int(visit["picked"])).is_equal(-1)


## STAMP DAY (shift 2, no register yet): after the ticket's visit its REGISTER draw waits for a
## pick that can't be binned; the stamp lands on the loyalty card and the visit is logged.
func test_stamp_day_stamps_the_loyalty_card() -> void:
	var screen: ShiftScreen = await _passed_screen()
	screen._machine.debug_skip()
	await _pass(screen)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until_armed(screen)
	screen._machine.view._on_bin_pressed()
	screen._machine.view.fast_forward()  # The landing plays to its end.
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	assert_bool(screen._machine.is_open()).is_true()
	var view: RewardMachineView = screen._machine.view
	assert_bool(view.display.bin_button().visible).is_false()
	assert_str(RewardMachineView.pick_prompt(view.tickets.size(), run)).is_equal("PICK 1 STAMP")
	var register: UpgradeDefinition = run.machine.prizes()[0].upgrade
	await _until_armed(screen)
	view._on_bin_pressed()
	view.fast_forward()  # The landing plays to its end.
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	view.pick(0)
	view.fast_forward()  # The landing plays to its end.
	assert_array(run.upgrades).is_equal([register])
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(1)
	assert_int(run.shift_index).is_equal(2)
	var visit: Dictionary = _last_event("machine_visit")
	assert_str(visit["kind"]).is_equal("stamp_day")
	assert_str(visit["chute"]).is_equal("register")
	assert_int(int(visit["registers_owned"])).is_equal(1)
	assert_bool((visit["odds_shown"] as Dictionary).is_empty()).is_false()


## A ticket pick followed by another visit (shift 2's STAMP DAY, no register yet) refreshes only
## the top bar: the Cart counts the pick, while the belt stays as the count-up left it (every
## cell hidden, the row in the bag) behind the machine. STAMP DAY's visit doesn't inherit the
## dessert's skip, which only the ticket's visit followed.
func test_a_pick_before_another_visit_keeps_the_belt_and_counts_the_cart() -> void:
	var screen: ShiftScreen = await _passed_screen()
	screen._machine.debug_skip()
	await _pass(screen)
	var run: RunState = screen.run
	screen._count_up.dessert_skipped = true
	screen._machine.open(false)
	assert_bool(screen._machine._timeline.presentation_skipped).is_true()
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until_armed(screen)
	var size_before: int = run.deck.size()
	screen._machine.view.pick(0)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	assert_int(run.deck.size()).is_equal(size_before + 1)
	assert_str(screen._deck_button.caption).is_equal(
		"Cart %d/%d" % [run.deck.size(), run.balance.deck_limit]
	)
	for cell: PanelContainer in screen._stage.row_strip.slots + screen._stage.row_strip.closed:
		assert_bool(cell.visible).override_failure_message("a belt cell shows again").is_false()
	assert_int(screen._stage.bag.items().size()).is_equal(run.row.size())
	assert_bool(screen._machine._timeline.presentation_skipped).is_false()
	await _until_armed(screen)
	screen._machine.view.pick(0)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_bool(_last_event("machine_visit")["presentation_skipped"]).is_false()


## Every resume frame of build spec 4.3, each on a new screen over a run saved at that point:
## TICKET, BONUS and STAMP DAY at their wait points (the receipt already fed, no copy in the slot;
## the head stamp at rest or none; the display's wait lines; the slip's "?" lines, or the chute's
## ticked and PACKED; the saved meter levels, not punching; the keys from chute_info, only the
## chosen one lit once picking, REGISTER's SEE ODDS tab on STAMP DAY; the odds card closed; an
## empty belt, or the prizes open in their cells with their tabs), armed at once; a run saved at
## SCORED starts the next shift with the machine closed.
func test_every_resume_frame() -> void:
	var run: RunState = _core_passed_run()
	await _assert_resume_frame(run, MachineVisit.Kind.TICKET, false)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _assert_resume_frame(run, MachineVisit.Kind.TICKET, true)
	run = _core_passed_run()
	run.history[-1].inspection = load(SPOT_CHECK)
	run.machine.begin_after_checkout(run)
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	await _assert_resume_frame(run, MachineVisit.Kind.BONUS, false)
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	await _assert_resume_frame(run, MachineVisit.Kind.BONUS, true)
	run = _core_passed_run()
	assert_bool(MachineSteps.next_shift(run)).is_true()
	_core_pass(run)
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(run.machine.bin(run)).is_true()
	await _assert_resume_frame(run, MachineVisit.Kind.STAMP_DAY, true)
	run = _core_passed_run()
	assert_bool(MachineSteps.pass_visits(run)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	_save(run)
	var scored: ShiftScreen = await _resumed_screen()
	assert_int(scored.run.shift_index).is_equal(1)
	assert_int(scored.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(scored._machine.is_open()).is_false()


## `run` saved at its wait point (`picking`: MACHINE_PICK) resumes on a new screen showing the
## visit of `kind` as build spec 4.3's resume table says.
func _assert_resume_frame(run: RunState, kind: int, picking: bool) -> void:
	var phase: int = RunState.Phase.MACHINE_PICK if picking else RunState.Phase.MACHINE_CHOOSE
	assert_int(run.phase).is_equal(phase)
	assert_int(run.machine.current_visit().kind).is_equal(kind)
	_save(run)
	var screen: ShiftScreen = await _resumed_screen()
	var resumed: RunState = screen.run
	var view: RewardMachineView = screen._machine.view
	var where: String = "%s %s" % [MachineVisit.KIND_NAMES[kind], "pick" if picking else "choose"]
	assert_int(resumed.phase).override_failure_message(where).is_equal(phase)
	assert_bool(view.plan.resumed).override_failure_message(where).is_true()
	assert_float(view.clock).is_equal(view.plan.pick_at if picking else view.plan.choose_at)
	assert_bool(view.is_armed()).override_failure_message(where).is_true()
	# The receipt: already fed (#77 machine v2: the stage's own is torn off until the next shift),
	# no copy; a bonus ticket to come waits in the dock.
	assert_object(view.receipt_feed.paper).is_null()
	assert_bool(screen._receipt.visible).is_false()
	var bonus: BonusTicket = view.receipt_feed.ticket
	if kind == MachineVisit.Kind.TICKET and view.plan.stub:
		assert_object(bonus).override_failure_message(where).is_not_null()
		assert_bool(bonus.is_visible_in_tree()).is_true()
		var dock: Rect2 = view.slot_plate.dock_global_rect()
		var shown: Rect2 = bonus.get_global_rect()
		assert_vector(shown.get_center()).is_equal_approx(dock.get_center(), Vector2.ONE)
	else:
		assert_bool(bonus != null and bonus.visible).override_failure_message(where).is_false()
	# At the machine at once: no glide on a resume.
	assert_float(screen._camera.progress()).override_failure_message(where).is_equal(1.0)
	# The head stamp, at rest.
	var stamps: Array[String] = ["", "BONUS TICKET!", "STAMP DAY!"]
	assert_str(view.head.stamp_texts()[0]).override_failure_message(where).is_equal(stamps[kind])
	assert_bool(view.head.stamp_shown()).is_equal(kind != MachineVisit.Kind.TICKET)
	if view.head.stamp_shown():
		assert_float(view.head.stamp_scale()).is_equal(1.0)
	# The display's wait lines.
	var lines: PackedStringArray = view.display.texts()
	var prizes: Array[MachinePrize] = resumed.machine.prizes()
	if picking:
		assert_str(lines[0]).is_equal(RewardMachineView.pick_prompt(prizes.size(), resumed))
	elif kind == MachineVisit.Kind.BONUS:
		var bonus_sub: String = RewardMachineView.BONUS_SUB % view.display.why_words()
		assert_array(Array(lines)).is_equal([RewardMachineView.BONUS_TITLE, bonus_sub])
	else:
		var spend: String = RewardMachineView.SPEND_LINE % resumed.history[-1].total
		assert_array(Array(lines)).is_equal([spend, RewardMachineView.CHOOSE_SUB])
	# The order slip.
	var slip: PackedStringArray = view.slip.texts()
	var titles: Array[String] = ["ORDER #", "BONUS #", "STAMP DAY"]
	assert_str(slip[0]).override_failure_message(where).starts_with(titles[kind])
	for index: int in range(2, slip.size()):
		var question: bool = slip[index].ends_with("?")
		assert_bool(question).override_failure_message(slip[index]).is_equal(not picking)
		assert_bool(view.slip.is_ticked(index - 2)).is_equal(picking)
	if picking and kind != MachineVisit.Kind.STAMP_DAY:
		assert_bool(view.slip.is_packed()).override_failure_message(where).is_true()
	# The meters at their saved levels, still; the keys from chute_info.
	var visit: MachineVisit = resumed.machine.current_visit()
	for chute: int in RewardMachine.CHUTES:
		var meter: PunchMeter = view.meters[chute]
		assert_int(meter.shown_level()).is_equal(resumed.machine.level(chute))
		assert_bool(meter.is_punching()).is_false()
		var info: MachineChuteInfo = resumed.machine.chute_info(resumed, chute)
		var key: ChuteKey = view.keys[chute]
		assert_int(key.state).is_equal(info.state)
		var open: bool = info.state == RewardMachine.ChuteState.OPEN
		var lit: bool = open and (not picking or visit.chute == chute)
		var which: String = "%s key %d" % [where, chute]
		assert_bool(key.looks_lit()).override_failure_message(which).is_equal(lit)
		var tab: bool = (
			kind == MachineVisit.Kind.STAMP_DAY and chute == RewardMachine.Chute.REGISTER
		)
		assert_bool(key.has_tab()).override_failure_message(which).is_equal(tab)
	assert_bool(view.odds_card.visible).is_false()
	# No key is pressed on a resume at the chutes (at a pick, the chosen chute's stays down): the
	# display shows the wait's lines, no CONFIRM ›.
	var pressed: int = visit.chute if picking and kind != MachineVisit.Kind.STAMP_DAY else -1
	assert_int(view.pressed_chute()).override_failure_message(where).is_equal(pressed)
	assert_bool(view.display.in_title_mode()).is_false()
	assert_bool(view.display.confirm_key().visible).is_false()
	# The belt: empty, or the prizes open in their cells.
	assert_array(view.box_lane.riding(view.clock)).is_empty()
	assert_int(view.tickets.size()).is_equal(prizes.size() if picking else 0)
	for index: int in range(view.tickets.size()):
		var ticket: PrizeTicket = view.tickets[index]
		assert_bool(ticket.visible).is_true()
		assert_bool(ticket.shows_box()).is_false()
		assert_bool(ticket.tab.visible).is_true()
		assert_float(ticket.position.x).is_equal(RewardMachineView.cell_x(index, prizes.size()))


## A run (seed 7) that passed shift 1 with the passing row, at its ticket's chute wait.
func _core_passed_run() -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(7, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	_core_pass(run)
	return run


func _core_pass(run: RunState) -> void:
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()


func _save(run: RunState) -> void:
	assert_bool(SaveService.new(_folder).save_run(run, "feedc0de12345678", 1000)).is_true()


## A new screen over the save folder (it resumes the run saved there), laid out.
func _resumed_screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	await _frames(4)
	return screen


## The screen on shift 1 with a passing row checked out: the machine waits for its chute.
func _passed_screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass(screen)
	return screen


func _pass(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## Fast-forwards the machine to its wait point (as a tap would, unlogged), then waits (at most
## 3 s) for it to arm: the mouse is up, so it arms on its next frame.
func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _saved_phase() -> String:
	var path: String = _folder.path_join(SaveService.RUN_FILE)
	if not FileAccess.file_exists(path):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str((data as Dictionary).get("phase", ""))


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
