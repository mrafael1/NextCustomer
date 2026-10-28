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


## v0.49: a run dealt from the recipe deck logs the cards it was dealt as its starting_deck.
func test_run_start_logs_the_dealt_starting_deck() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: RunStock = RunStock.starting(balance)
	var deck: DeckDefinition = StartingDeck.deal(
		load("res://data/decks/random_starter.tres"),
		stock,
		balance,
		EventLogService.derived_stream(77, EventLogService.STARTING_DECK_STREAM)
	)
	var run: RunState = RunState.new(77, deck, balance, stock)
	var start: Dictionary = RunEvents.run_start(run)
	var expected: Array = deck.cards.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	assert_int(expected.size()).is_equal(13)
	assert_array(start["starting_deck"]).is_equal(expected)


## Plan section 8: run_start's and run_end's fields, JSON-friendly.
func test_run_start_and_run_end_fields() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(77, deck, balance, RunStock.starting(balance))
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
	# Three misses: two slips of the training week (v0.68), the third gets the cashier fired.
	for _slip: int in range(2):
		run.checkout()
		run.next_shift()
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	var end: Dictionary = RunEvents.run_end(run, 4321)
	(
		assert_dict(end)
		. is_equal(
			{
				"result": "loss",
				"shift_reached": 3,
				"last_score": 0,
				"run_ms": 4321,
				"upgrades": [],
				"write_ups": 3,
			}
		)
	)


## The `redraw` event (plan section 3.8, the basket redraw): the basket (1-based), the places
## swapped (0-based, left first) and the cards replaced and received in their order.
func test_redraw_event_fields() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(5, deck, balance, RunStock.starting(balance))
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


## #77: the machine_visit event's fields, in order, from the visit just recorded (a loyalty perk
## picked from UPGRADE on a PREMIUM visit after shift 1), JSON-friendly, with its machine state
## (#108: classic or premium), the perks' levels and no Regular levels; a bin (shift 2, CLASSIC),
## and the CLASSIC BONUS visit of the Manager's review on shift 4 naming both its inspections.
func test_machine_visit_event_fields() -> void:
	var run: RunState = _passed_run(81, [1])
	run.machine.choose(run, RewardMachine.Chute.UPGRADE)
	var odds: MachineOddsCard = run.machine.chute_info(run, RewardMachine.Chute.UPGRADE).odds
	var timeline: OfferTimeline = OfferTimeline.new(100)
	timeline.mark_presented(330)
	timeline.mark_armed(460)
	var prizes: Array[MachinePrize] = run.machine.prizes()
	var index: int = MachineSteps.register_index(run)
	assert_int(index).is_not_equal(-1)
	var perk: UpgradeDefinition = prizes[index].upgrade
	assert_object(run.machine.pick(run, index)).is_not_null()
	var viewed: Array[int] = [RewardMachine.Chute.NEW_ITEMS, RewardMachine.Chute.UPGRADE]
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
				"state",
				"inspection",
				"chute",
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
				"perk_levels",
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
	assert_str(event["chute"]).is_equal("upgrade")
	assert_str(event["state"]).is_equal("premium")
	assert_array(event["chutes_viewed"]).is_equal(["new_items", "upgrade"])
	assert_int((event["offered"] as Array).size()).is_equal(prizes.size())
	assert_str(event["offered"][index]["id"]).is_equal(String(perk.id))
	assert_str(event["offered"][index]["kind"]).is_equal("register")
	assert_int(event["offered"][index]["level"]).is_equal(1)
	assert_int(event["picked"]).is_equal(index)
	assert_bool(event["binned"]).is_false()
	assert_int(event["registers_owned"]).is_equal(1)
	assert_dict(event["perk_levels"]).is_equal({String(perk.family()): 1})
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
	assert_str(JSON.stringify(event)).contains('"chute":"upgrade"')
	assert_bool(RunEvents.odds_fields(null).is_empty()).is_true()
	var levelled: Array[UpgradeDefinition] = [
		load("res://data/upgrades/coupon_engine_lv3.tres"),
		load("res://data/upgrades/big_basket.tres")
	]
	assert_dict(RunEvents.perk_levels(levelled)).is_equal({"coupon_engine": 3, "big_basket": 1})
	# Shift 2, shift 3's inspection announced.
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
	assert_str(bin["state"]).is_equal("classic")
	assert_dict(bin["odds_shown"]).is_empty()
	assert_array(bin["fallback"]).is_empty()
	# Shift 3 is inspected: only its ticket (v0.68, Payday).
	run.next_shift()
	assert_array(run.inspections).is_not_empty()
	_pass(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	# Shift 4 is the Manager's review: its BONUS visit (v0.68, bonus_extra_shifts; CLASSIC on this
	# machine, PREMIUM only after shift 1) names both inspections.
	run.next_shift()
	assert_int(run.inspections.size()).is_equal(2)
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
	assert_str(bonus["state"]).is_equal("classic")
	assert_int(bonus["visit_index"]).is_equal(1)
	assert_str(bonus["inspection"]).is_equal(",".join(RunEvents.inspection_ids(run.inspections)))


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
## `premium`: the shifts after which the machine is PREMIUM instead of the data's, or none.
static func _passed_run(seed_value: int, premium: Array[int] = []) -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	if not premium.is_empty():
		MachineSteps.premium_on(balance, premium)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	_pass(run)
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load("res://data/cards/bread.tres")), run.row.size())
	run.checkout()
