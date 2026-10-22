extends GdUnitTestSuite
## Event log writing and checkout measures (plan section 8).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()


func after_test() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_writer_creates_the_folder_and_appends_lines() -> void:
	var writer: EventLogWriter = EventLogWriter.new(_folder, "a.jsonl")
	assert_bool(writer.append({"type": "run_start", "seq": 1})).is_true()
	assert_bool(writer.append({"type": "shift_start", "seq": 2})).is_true()
	var lines: PackedStringArray = FileAccess.get_file_as_string(writer.file_path).split(
		"\n", false
	)
	assert_int(lines.size()).is_equal(2)
	assert_str(JSON.parse_string(lines[1])["type"]).is_equal("shift_start")


func test_a_second_writer_never_truncates() -> void:
	EventLogWriter.new(_folder, "a.jsonl").append({"n": 1})
	EventLogWriter.new(_folder, "a.jsonl").append({"n": 2})
	var text: String = FileAccess.get_file_as_string(_folder.path_join("a.jsonl"))
	assert_int(text.split("\n", false).size()).is_equal(2)


func test_join_logs_in_name_order() -> void:
	EventLogWriter.new(_folder, "20261006T100000_b.jsonl").append({"n": 2})
	EventLogWriter.new(_folder, "20261005T100000_a.jsonl").append({"n": 1})
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	assert_int(lines.size()).is_equal(2)
	assert_int(int(JSON.parse_string(lines[0])["n"])).is_equal(1)


func test_write_errors_go_to_the_reporter() -> void:
	var errors: Array[String] = []
	var reporter: Callable = func(message: String) -> void: errors.append(message)
	# A file name that is a folder can't be opened as a file.
	DirAccess.make_dir_recursive_absolute(_folder.path_join("blocked.jsonl"))
	var writer: EventLogWriter = EventLogWriter.new(_folder, "blocked.jsonl", reporter)
	assert_bool(writer.append({"n": 1})).is_false()
	assert_int(errors.size()).is_equal(1)
	DirAccess.remove_absolute(_folder.path_join("blocked.jsonl"))


func test_checkout_measures() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(1000)
	for i: int in range(5):
		tracker.on_place()
	tracker.on_remove()
	tracker.on_preview(3, 10)
	tracker.on_preview(3, 12)
	tracker.on_preview(3, 10)
	tracker.on_preview(4, 15)
	tracker.on_focus_lost(2000)
	tracker.on_focus_gained(5000)
	tracker.on_checkout(9000)
	var measures: Dictionary = tracker.measures(3)
	assert_int(measures["placements"]).is_equal(5)
	assert_int(measures["removals"]).is_equal(1)
	assert_int(measures["rearrangements"]).is_equal(2)
	assert_int(measures["distinct_projected_totals"]).is_equal(2)
	assert_int(measures["planning_ms"]).is_equal(5000)
	assert_str(measures["input_method"]).is_equal("click")


## Plan section 8: input_method is "click", "drag" or "both", from the placements and
## removals of this shift only.
func test_input_method_follows_placements_and_removals() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	assert_str(tracker.measures(0)["input_method"]).is_equal("click")
	tracker.on_place(true)
	tracker.on_place(true)
	assert_str(tracker.measures(2)["input_method"]).is_equal("drag")
	tracker.on_remove()
	assert_str(tracker.measures(1)["input_method"]).is_equal("both")
	assert_int(tracker.placements).is_equal(2)
	assert_int(tracker.removals).is_equal(1)
	tracker.begin(100)
	assert_str(tracker.input_method).is_equal("click")
	tracker.on_remove(true)
	assert_str(tracker.input_method).is_equal("drag")


func test_checkout_while_unfocused_stops_the_clock_at_focus_loss() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_focus_lost(3000)
	tracker.on_checkout(8000)
	assert_int(tracker.planning_ms()).is_equal(3000)


## Plan 8: planning time ends at the checkout click, so focus changes during the count-up
## don't count.
func test_focus_changes_after_checkout_are_ignored() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_checkout(1500)
	tracker.on_focus_lost(1700)
	tracker.on_focus_gained(2700)
	assert_int(tracker.planning_ms()).is_equal(1500)


func test_shift_started_while_away_counts_from_the_return() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0, false)
	tracker.on_focus_gained(4000)
	tracker.on_checkout(6000)
	assert_int(tracker.planning_ms()).is_equal(2000)


func test_rearrangements_never_negative() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_place()
	assert_int(tracker.rearrangements(3)).is_equal(0)


func test_export_joins_every_session_and_includes_its_own_event() -> void:
	var event_log: EventLogService = (Engine.get_main_loop() as SceneTree).root.get_node(
		"/root/EventLog"
	)
	var folder: String = _folder.path_join("playtest_logs")
	EventLogWriter.new(folder, "20200101T000000_old.jsonl").append({"type": "run_start"})
	event_log.use_folder(folder)
	var joined: String = event_log.export_logs("title", false)
	var lines: PackedStringArray = joined.split("\n", false)
	assert_int(lines.size()).is_equal(2)
	var last: Dictionary = JSON.parse_string(lines[1])
	assert_str(last["type"]).is_equal("log_export")
	assert_str(last["screen"]).is_equal("title")
	assert_int(int(last["files"])).is_equal(2)
	var exported: String = _folder.path_join("playtest_export.jsonl")
	assert_str(FileAccess.get_file_as_string(exported)).is_equal(joined)
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


## Plan section 8: run_start's and run_end's fields, JSON-friendly.
func test_run_start_and_run_end_fields() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(77, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	var start: Dictionary = RunEvents.run_start(run)
	(
		assert_array(start.keys())
		. contains_exactly_in_any_order(
			[
				"seed",
				"starting_deck",
				"shift_count",
				"listed_aisles",
				"stock",
			]
		)
	)
	assert_int(start["seed"]).is_equal(77)
	assert_int((start["starting_deck"] as Array).size()).is_equal(13)
	# The impulse rack's fields are gone with the rack (#77).
	assert_bool(start.has("impulse_offer")).is_false()
	assert_str(JSON.stringify(start)).contains(
		'"listed_aisles":["cold_cases","pantry","household"]'
	)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	var end: Dictionary = RunEvents.run_end(run, 4321)
	assert_dict(end).is_equal(
		{"result": "loss", "shift_reached": 1, "last_score": 0, "run_ms": 4321, "upgrades": []}
	)


## #77: the machine_visit event's fields, in order, from the visit just recorded (a REGISTER
## pick after shift 1), JSON-friendly; a bin (shift 2), and the BONUS visit of the inspected
## shift 3 naming its inspection.
## The `redraw` event (plan section 3.8, the basket redraw): the basket (1-based), the places
## swapped (0-based, left first) and the cards replaced and received in their order.
func test_redraw_event_fields() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(5, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	var hand_before: Array[CardInstance] = run.hand_places()
	var places: Array[int] = run.redraw_basket(1)
	var hand_after: Array[CardInstance] = run.hand_places()
	var replaced: Array[CardInstance] = [hand_before[2], hand_before[3]]
	var received: Array[CardInstance] = [hand_after[2], hand_after[3]]
	var event: Dictionary = RunEvents.redraw(1, places, replaced, received)
	assert_int(event["basket"]).is_equal(2)
	assert_array(event["places"]).is_equal([2, 3])
	assert_array(event["cards_replaced"]).is_equal(RunEvents.card_ids(replaced))
	assert_array(event["cards_received"]).is_equal(RunEvents.card_ids(received))
	# It survives the log's JSON round trip as plain numbers and ids.
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(event))
	assert_int(int(parsed["places"][1])).is_equal(3)


func test_machine_visit_event_fields() -> void:
	var run: RunState = _passed_run(81)
	run.machine.choose(run, RewardMachine.Chute.REGISTER)
	var odds: MachineOddsCard = run.machine.chute_info(run, RewardMachine.Chute.REGISTER).odds
	var timeline: OfferTimeline = OfferTimeline.new(100)
	timeline.mark_presented(330)
	timeline.mark_armed(460)
	var prizes: Array[MachinePrize] = run.machine.prizes()
	assert_object(run.machine.pick(run, 1)).is_not_null()
	var viewed: Array[int] = [RewardMachine.Chute.COUPONS, RewardMachine.Chute.REGISTER]
	var event: Dictionary = RunEvents.machine_visit(
		run, run.history[-1].visits[-1], odds, viewed, false, true, timeline.fields(1334)
	)
	(
		assert_array(event.keys())
		. is_equal(
			[
				"shift",
				"visit_index",
				"kind",
				"inspection",
				"chute",
				"level_before",
				"levels",
				"meter_rose",
				"odds_shown",
				"guarantee_held",
				"fallback",
				"chutes_viewed",
				"offered",
				"picked",
				"binned",
				"replaced",
				"upgraded",
				"cart_size",
				"cart_full_at_pick",
				"registers_owned",
				"resumed",
				"decide_ms",
				"presented_ms",
				"armed_ms",
				"presentation_skipped",
				"chute_wait_ms",
			]
		)
	)
	assert_int(event["shift"]).is_equal(1)
	assert_int(event["visit_index"]).is_equal(0)
	assert_str(event["kind"]).is_equal("ticket")
	assert_str(event["inspection"]).is_empty()
	assert_str(event["chute"]).is_equal("register")
	assert_int(event["level_before"]).is_equal(0)
	assert_array(event["levels"]).is_equal([0, 0, 1, 0])
	assert_bool(event["meter_rose"]).is_true()
	assert_array(event["chutes_viewed"]).is_equal(["coupons", "register"])
	assert_int((event["offered"] as Array).size()).is_equal(prizes.size())
	assert_str(event["offered"][1]["id"]).is_equal(String(prizes[1].id()))
	assert_str(event["offered"][1]["kind"]).is_equal("register")
	assert_int(event["picked"]).is_equal(1)
	assert_bool(event["binned"]).is_false()
	assert_int(event["registers_owned"]).is_equal(1)
	assert_bool(event["resumed"]).is_true()
	assert_bool(event["cart_full_at_pick"]).is_false()
	assert_int(event["cart_size"]).is_equal(13)
	assert_int(event["decide_ms"]).is_equal(1234)
	assert_int(event["presented_ms"]).is_equal(230)
	assert_int(event["armed_ms"]).is_equal(360)
	var shown: Dictionary = event["odds_shown"]
	assert_array(shown.keys()).is_equal(["rarity_pct", "p_rare_plus", "p_legendary"])
	var total: float = 0.0
	for pct: float in shown["rarity_pct"]:
		total += pct
	assert_float(total).is_equal_approx(100.0, 0.2)
	assert_str(JSON.stringify(event)).contains('"chute":"register"')
	assert_bool(RunEvents.odds_fields(null).is_empty()).is_true()
	# Shift 2: no STAMP DAY (a register is held), shift 3's inspection announced.
	MachineSteps.next_shift(run)
	_pass(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	var bin: Dictionary = RunEvents.machine_visit(
		run, run.history[-1].visits[-1], null, [], false, false, timeline.fields(900)
	)
	assert_int(bin["picked"]).is_equal(-1)
	assert_bool(bin["binned"]).is_true()
	assert_dict(bin["odds_shown"]).is_empty()
	assert_array(bin["fallback"]).is_empty()
	# Shift 3 is inspected: its BONUS visit names the inspection.
	run.next_shift()
	assert_array(run.inspections).is_not_empty()
	_pass(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	var bonus: Dictionary = RunEvents.machine_visit(
		run, run.history[-1].visits[-1], null, [], false, false, timeline.fields(900)
	)
	assert_str(bonus["kind"]).is_equal("bonus")
	assert_int(bonus["visit_index"]).is_equal(1)
	assert_str(bonus["inspection"]).is_equal(String(run.history[-1].inspection.id))


## Plan sections 3.9 and 8: inspection ids as logged (shift_start, checkout), plain strings.
func test_inspection_fields() -> void:
	var spot_check: InspectionDefinition = load("res://data/inspections/spot_check.tres")
	var inspections: Array[InspectionDefinition] = [spot_check]
	assert_array(RunEvents.inspection_ids(inspections)).is_equal(["spot_check"])
	assert_array(RunEvents.inspection_ids([])).is_empty()
	assert_str(RunEvents.inspection_id(spot_check)).is_equal("spot_check")
	assert_str(RunEvents.inspection_id(null)).is_equal("")
	var event: Dictionary = {"next_inspection": RunEvents.inspection_id(spot_check)}
	assert_str(JSON.stringify(event)).is_equal('{"next_inspection":"spot_check"}')


## Full build plan section 4: run_resume and run_abandon name the shift (1-based) and the save
## point by its run save name, and add the played time so far.
func test_run_resume_and_run_abandon_fields() -> void:
	var run: RunState = _passed_run(79)
	assert_dict(RunEvents.run_resume(run, 1500)).is_equal(
		{"shift": 1, "phase": "machine", "run_ms": 1500}
	)
	run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_dict(RunEvents.run_abandon(run, 1600)).is_equal(
		{"shift": 1, "phase": "machine_pick", "run_ms": 1600}
	)
	run.machine.bin(run)
	assert_dict(RunEvents.run_resume(run, 1700)).is_equal(
		{"shift": 1, "phase": "scored", "run_ms": 1700}
	)
	run.debug_skip_to_shift(2)
	assert_dict(RunEvents.run_resume(run, 90000)).is_equal(
		{"shift": 3, "phase": "planning", "run_ms": 90000}
	)
	assert_dict(RunEvents.run_abandon(run, 90000)).is_equal(
		{"shift": 3, "phase": "planning", "run_ms": 90000}
	)


## A resumed run logs under its saved run id; begin_run then starts a new one.
func test_resume_run_sets_the_run_id() -> void:
	var event_log: EventLogService = EventLogService.new()
	event_log.resume_run("0123456789abcdef")
	assert_str(event_log.run_id).is_equal("0123456789abcdef")
	event_log.begin_run()
	assert_str(event_log.run_id).is_not_equal("0123456789abcdef")
	assert_int(event_log.run_id.length()).is_equal(16)
	event_log.free()


## A run with every quota at 1 that passed shift 1 (two Breads): the machine waits for its chute.
static func _passed_run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	_pass(run)
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load("res://data/cards/bread.tres")), run.row.size())
	run.checkout()


## The `capsule` event (#63): the machine, the item, its run index, the coins left, the draw's
## stream index and the seed as a decimal string (it can pass 2^31).
func test_capsule_event_fields() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bakery: AisleDefinition = balance.aisles[4]
	var data: Dictionary = RunEvents.capsule(bakery, bakery.capsule_cards[0], -1, 3, 7, 4294967295)
	(
		assert_dict(data)
		. is_equal(
			{
				"machine": "bakery",
				"item": "baguette",
				"run_index": -1,
				"coins_left": 3,
				"draw": 7,
				"capsule_seed": "4294967295",
			}
		)
	)
	var read: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_str(read["capsule_seed"]).is_equal("4294967295")


## The derived streams of #63: the surprise list's and each capsule draw's, the same for the
## same seed and name, and different draws get different streams.
func test_capsule_and_surprise_list_streams() -> void:
	var first: RandomNumberGenerator = EventLogService.capsule_stream(5, 0)
	assert_int(first.seed).is_equal(EventLogService.derived_stream(5, "capsule_0").seed)
	assert_int(EventLogService.capsule_stream(5, 0).randi()).is_equal(first.randi())
	assert_int(EventLogService.capsule_stream(5, 1).seed).is_not_equal(
		EventLogService.capsule_stream(5, 0).seed
	)
	assert_str(EventLogService.SURPRISE_LIST_STREAM).is_equal("surprise_list")
