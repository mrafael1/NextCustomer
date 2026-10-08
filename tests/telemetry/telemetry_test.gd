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
				"impulse_offer",
				"impulse_pick",
				"impulse_replaced",
				"impulse_decide_ms",
				"impulse_presented_ms",
				"impulse_armed_ms",
				"impulse_presentation_skipped",
				"impulse_deck_view_opened",
			]
		)
	)
	assert_int(start["seed"]).is_equal(77)
	assert_int((start["starting_deck"] as Array).size()).is_equal(13)
	# Without a rack: no offer, no pick.
	assert_array(start["impulse_offer"]).is_empty()
	assert_str(start["impulse_pick"]).is_empty()
	assert_str(start["impulse_replaced"]).is_empty()
	assert_int(start["impulse_decide_ms"]).is_equal(0)
	assert_int(start["impulse_presented_ms"]).is_equal(0)
	assert_int(start["impulse_armed_ms"]).is_equal(0)
	assert_bool(start["impulse_presentation_skipped"]).is_false()
	assert_bool(start["impulse_deck_view_opened"]).is_false()
	assert_str(JSON.stringify(start)).contains(
		'"listed_aisles":["cold_cases","pantry","household"]'
	)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	var end: Dictionary = RunEvents.run_end(run, 4321)
	assert_dict(end).is_equal(
		{"result": "loss", "shift_reached": 1, "last_score": 0, "run_ms": 4321, "upgrades": []}
	)


## Full build plan section 4: run_start is logged after the impulse rack, with its offer (ids in
## offer order), the pick and the replaced card; starting_deck is the deck before the rack.
func test_run_start_logs_the_impulse_rack() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		78, EventLogService.IMPULSE_RACK_STREAM
	)
	var run: RunState = RunState.new(78, deck, balance, RunStock.starting(deck, balance), stream)
	var offered: Array = run.impulse_offer.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	while not run.deck_is_full():
		run.deck.add_card(load("res://data/cards/soup.tres"))
	var replaced: CardInstance = run.deck.cards[0]
	assert_bool(run.take_reward(run.impulse_offer[2], replaced)).is_true()
	var rack: OfferTimeline = OfferTimeline.new(1000)
	rack.mark_presented(1230)
	rack.mark_armed(1360)
	var start: Dictionary = RunEvents.run_start(run, rack.fields(3500), true)
	assert_array(start["impulse_offer"]).is_equal(offered)
	assert_int(start["impulse_decide_ms"]).is_equal(2500)
	assert_int(start["impulse_presented_ms"]).is_equal(230)
	assert_int(start["impulse_armed_ms"]).is_equal(360)
	assert_bool(start["impulse_presentation_skipped"]).is_false()
	assert_bool(start["impulse_deck_view_opened"]).is_true()
	assert_int(offered.size()).is_equal(3)
	assert_str(start["impulse_pick"]).is_equal(offered[2])
	assert_str(start["impulse_replaced"]).is_equal(String(replaced.definition.id))
	assert_int((start["starting_deck"] as Array).size()).is_equal(13)
	assert_str(JSON.stringify(start)).contains('"impulse_pick":"%s"' % offered[2])


## Plan section 8: the upgrade event's fields, and upgrade ids in pick order (run_end).
func test_upgrade_event_fields() -> void:
	var coupon_engine: UpgradeDefinition = load("res://data/upgrades/coupon_engine.tres")
	var category_engine: UpgradeDefinition = load("res://data/upgrades/category_engine.tres")
	var offered: Array[UpgradeDefinition] = [category_engine, coupon_engine]
	var tickets: OfferTimeline = OfferTimeline.new(100)
	tickets.mark_presented(330)
	tickets.mark_armed(460)
	tickets.presentation_skipped = true
	var event: Dictionary = RunEvents.upgrade_pick(4, offered, coupon_engine, tickets.fields(1334))
	assert_array(event.keys()).is_equal(
		[
			"shift",
			"offered",
			"picked",
			"decide_ms",
			"presented_ms",
			"armed_ms",
			"presentation_skipped"
		]
	)
	assert_int(event["shift"]).is_equal(4)
	assert_array(event["offered"]).is_equal(["category_engine", "coupon_engine"])
	assert_str(event["picked"]).is_equal("coupon_engine")
	assert_int(event["decide_ms"]).is_equal(1234)
	assert_int(event["presented_ms"]).is_equal(230)
	assert_int(event["armed_ms"]).is_equal(360)
	assert_bool(event["presentation_skipped"]).is_true()
	# JSON-friendly: plain strings, not StringNames.
	assert_str(JSON.stringify(event)).contains('"picked":"coupon_engine"')
	assert_array(RunEvents.upgrade_ids([])).is_empty()


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
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		79, EventLogService.IMPULSE_RACK_STREAM
	)
	var run: RunState = RunState.new(79, deck, balance, RunStock.starting(deck, balance), stream)
	assert_dict(RunEvents.run_resume(run, 1500)).is_equal(
		{"shift": 1, "phase": "impulse_rack", "run_ms": 1500}
	)
	assert_dict(RunEvents.run_abandon(run, 1500)).is_equal(
		{"shift": 1, "phase": "impulse_rack", "run_ms": 1500}
	)
	run.skip_reward()
	run.start_shift()
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
