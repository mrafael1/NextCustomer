extends GdUnitTestSuite
## The run save (full build plan section 4; format 2 since #77): RunSave's saved form at every
## save point (PLANNING, the machine's MACHINE_CHOOSE and MACHINE_PICK, SCORED), read back
## through JSON text, gives the same run, and a run saved and restored after every action plays
## exactly like one that never stopped. A save that can't be resumed (a version 1 save from
## before the machine among them) reads as null and prints nothing.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const UNSTOCKED := &"test_unstocked"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	# Quotas of 1: every row with a product passes, so a scripted run reaches its end.
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	_lookup = ContentLookup.new(_balance)


func test_only_the_four_stable_phases_are_saved() -> void:
	var saved: Array[String] = []
	for phase: RunState.Phase in RunState.Phase.values():
		var run: RunState = _planning_run(1)
		run.phase = phase
		if RunSave.is_save_point(phase):
			assert_bool(RunSave.to_dictionary(run, "id", 0).is_empty()).is_false()
			saved.append(RunSave.phase_name(phase))
		else:
			assert_dict(RunSave.to_dictionary(run, "id", 0)).is_empty()
			assert_str(RunSave.phase_name(phase)).is_empty()
	assert_array(saved).is_equal(["planning", "machine", "machine_pick", "scored"])


func test_a_fresh_shift_round_trips() -> void:
	var run: RunState = _planning_run(12)
	var restored: RunState = _round_trip(run)
	assert_int(restored.hand().size()).is_equal(8)
	# Hand cards are the deck's own instances.
	for card: CardInstance in restored.hand():
		assert_bool(restored.deck.cards.has(card)).is_true()


func test_a_shift_after_places_removes_and_redraws_round_trips() -> void:
	var run: RunState = _planning_run(13)
	var hand: Array[CardInstance] = run.hand()
	assert_bool(run.place(hand[0], 0)).is_true()
	assert_bool(run.place(hand[1], 0)).is_true()
	assert_bool(run.place(hand[2], 1)).is_true()
	assert_bool(run.remove(hand[1])).is_true()
	var set_aside: Array[CardInstance] = [hand[4], hand[5]]
	assert_array(run.redraw_basket(2)).is_equal([4, 5])
	var debug_card: CardInstance = run.debug_add_to_hand(load(BREAD))
	assert_bool(run.place(debug_card, 0)).is_true()
	var restored: RunState = _round_trip(run)
	assert_array(_instance_ids(restored.row)).is_equal(_instance_ids(run.row))
	assert_int(restored.redraws_used).is_equal(1)
	assert_int(restored.redraws_allowed).is_equal(2)
	# The second of the shift's two redraws is left.
	assert_bool(restored.can_redraw_basket(3)).is_true()
	# Every card is back at its hand place, with the row cards' places empty.
	assert_array(_place_ids(restored)).is_equal(_place_ids(run))
	# The redraw's set-aside cards stay out of the hand and the draw pile.
	var restored_pile: Array = _instance_ids(restored.deck.draw_pile())
	for card: CardInstance in set_aside:
		assert_bool(restored_pile.has(card.instance_id)).is_false()
		assert_bool(_instance_ids(restored.hand()).has(card.instance_id)).is_false()
	# The debug copy is in the hand and the row, but not in the deck.
	assert_bool(_instance_ids(restored.deck.cards).has(debug_card.instance_id)).is_false()
	assert_int(restored.row[0].instance_id).is_equal(debug_card.instance_id)
	assert_int(restored.preview().total).is_equal(run.preview().total)


## The checkout click saves at MACHINE_CHOOSE: the restored machine draws the same prizes.
func test_a_visit_waiting_for_its_chute_round_trips() -> void:
	var run: RunState = _planning_run(14)
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var restored: RunState = _round_trip(run)
	assert_int(restored.last_result.total).is_equal(run.last_result.total)
	assert_bool(restored.passed()).is_true()
	assert_bool(MachineSteps.choose(restored, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))


## The draw saves at MACHINE_PICK: the prizes come back as drawn, the first COUPONS flag stays
## spent, and the pick does the same.
func test_drawn_prizes_round_trip() -> void:
	var run: RunState = _planning_run(15)
	_fill(run)
	run.checkout()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	var restored: RunState = _round_trip(run)
	assert_bool(restored.machine.coupons_first_done).is_true()
	assert_object(MachineSteps.take(restored, 0)).is_not_null()
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	assert_str(_observe(restored)).is_equal(_observe(run))


## Shift 2 is a STAMP DAY shift (no register yet) and shift 3 is inspected: the ticket's visit,
## then STAMP DAY's drawn prizes, round trip with the next inspection; a Big basket taken there
## changes only the next shift's quota.
func test_stamp_day_round_trips_with_the_next_inspection() -> void:
	var run: RunState = _run_at_shift_two_checkout(16)
	assert_object(run.next_inspection).is_not_null()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.STAMP_DAY])
	_round_trip(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	var restored: RunState = _round_trip(run)
	assert_object(restored.next_inspection).is_same(run.next_inspection)
	assert_bool(restored.machine.can_bin()).is_false()
	assert_object(MachineSteps.take(restored, 0)).is_not_null()
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	assert_int(restored.phase).is_equal(RunState.Phase.SCORED)
	assert_int(restored.limits.quota).is_equal(run.limits.quota)
	_round_trip(run)
	assert_bool(restored.next_shift()).is_true()
	assert_bool(run.next_shift()).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))
	assert_array(restored.inspections).is_not_empty()


## The bonus ticket's visit (an inspected shift passed, the ticket's pick done) round-trips at
## MACHINE_CHOOSE and, once its chute is chosen, at MACHINE_PICK; the pick then plays the same.
func test_a_bonus_visit_round_trips_at_both_save_points() -> void:
	var run: RunState = _run_at_bonus_visit(5)
	var restored: RunState = _round_trip(run)
	assert_int(restored.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.COUPONS)
	assert_bool(MachineSteps.choose(restored, chute)).is_true()
	assert_bool(MachineSteps.choose(run, chute)).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	restored = _round_trip(run)
	assert_int(restored.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_object(MachineSteps.take(restored, 0)).is_not_null()
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	assert_str(_observe(restored)).is_equal(_observe(run))
	assert_int(run.history[-1].visits.size()).is_equal(2)


## Quitting during the last landing resumes at SCORED: into the next shift, and the visit
## already picked can't be picked again.
func test_scored_round_trips_into_the_next_shift() -> void:
	var run: RunState = _planning_run(17)
	_fill(run)
	run.checkout()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	var restored: RunState = _round_trip(run)
	assert_array(restored.machine.prizes()).is_empty()
	assert_object(MachineSteps.take(restored, 0)).is_null()
	assert_int(restored.history[-1].visits.size()).is_equal(1)
	assert_bool(restored.next_shift()).is_true()
	assert_bool(run.next_shift()).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))


## An UPGRADES pick upgrades a deck copy that the scored row may hold: the hand keeps the saved
## (scored) instance, so the restored receipt scores the same total.
func test_an_upgrades_pick_round_trips_with_the_scored_row() -> void:
	var run: RunState = _run_at_shift_three(18)
	_fill(run)
	run.checkout()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.UPGRADES)).is_true()
	var landing: MachineLanding = MachineSteps.take(run, 0)
	assert_object(landing).is_not_null()
	assert_array(landing.upgraded).is_not_empty()
	var restored: RunState = _round_trip(run)
	assert_int(restored.last_result.total).is_equal(run.last_result.total)
	MachineSteps.pass_visits(restored)
	MachineSteps.pass_visits(run)
	assert_bool(restored.next_shift()).is_true()
	assert_bool(run.next_shift()).is_true()
	assert_str(_observe(restored)).is_equal(_observe(run))


func test_a_debug_jump_round_trips() -> void:
	var run: RunState = _planning_run(19)
	run.debug_skip_to_shift(4)
	assert_bool(run.debug_jumped).is_true()
	var restored: RunState = _round_trip(run)
	assert_int(restored.shift_index).is_equal(4)
	assert_array(restored.history).is_empty()


## The debug shift jump to the shift on its own machine visit restarts it but keeps its record,
## so it counts as a jump too and its save still resumes.
func test_a_debug_restart_after_a_checkout_round_trips() -> void:
	var run: RunState = _planning_run(20)
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	run.debug_skip_to_shift(run.shift_index)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(run.debug_jumped).is_true()
	var restored: RunState = _round_trip(run)
	assert_int(restored.history.size()).is_equal(1)
	# A restart of a shift that hasn't been checked out is no jump.
	var fresh: RunState = _planning_run(19)
	fresh.debug_skip_to_shift(0)
	assert_bool(fresh.debug_jumped).is_false()


## A resumed run continues exactly as if it had never stopped: the same scripted run, saved and
## restored through JSON text after every action, gives every same hand, prize, visit,
## inspection and total.
func test_a_run_restored_after_every_action_plays_like_one_that_never_stopped() -> void:
	for seed_value: int in [5, 99, 4242]:
		var straight: Array[String] = _play(seed_value, false)
		var resumed: Array[String] = _play(seed_value, true)
		assert_int(resumed.size()).is_equal(straight.size())
		assert_array(resumed).is_equal(straight)
		assert_str(straight[-1]).contains('"phase":%d' % RunState.Phase.WON)


func test_large_seeds_and_rng_states_survive_json() -> void:
	var int64_min: int = -9223372036854775807 - 1
	for value: int in [int64_min, -7046029254386353131, 9007199254740993, 9223372036854775807]:
		var run: RunState = _planning_run(value)
		run.rng_state = value
		var restored: RunState = _round_trip(run)
		assert_int(restored.run_seed).is_equal(value)
		assert_int(restored.rng_state).is_equal(value)
		# The same state draws the same numbers.
		restored.debug_skip_to_shift(1)
		run.debug_skip_to_shift(1)
		assert_array(_instance_ids(restored.hand())).is_equal(_instance_ids(run.hand()))


func test_the_run_id_and_played_time_are_kept() -> void:
	var data: Dictionary = _json(RunSave.to_dictionary(_planning_run(3), "abc123", 98765))
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_str(save.run_id).is_equal("abc123")
	assert_int(save.run_ms).is_equal(98765)
	assert_int(int(data["format_version"])).is_equal(RunSave.FORMAT_VERSION)
	assert_int(RunSave.FORMAT_VERSION).is_equal(4)
	# v0.47: the machine saves no Regular levels.
	assert_bool((data["machine"] as Dictionary).has("levels")).is_false()


## v0.47: a run at a BOOSTED visit's pick (after shift 3) round-trips with the visit's state and no
## Regular levels; the restored machine lights the same chutes.
func test_a_boosted_visit_round_trips_without_levels() -> void:
	var run: RunState = _run_at_shift_three(18)
	_fill(run)
	run.checkout()
	assert_bool(run.machine.is_boosted()).is_true()
	var at_choose: RunState = _round_trip(run)
	assert_bool(at_choose.machine.is_boosted()).is_true()
	for chute: int in RewardMachine.CHUTES:
		assert_int(at_choose.machine.chute_info(at_choose, chute).state).is_equal(
			run.machine.chute_info(run, chute).state
		)
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.REGISTER)).is_true()
	var data: Dictionary = _json(_save(run))
	assert_bool((data["machine"] as Dictionary).has("levels")).is_false()
	assert_bool(data["machine"]["visit"]["boosted"]).is_true()
	var restored: RunState = _round_trip(run)
	assert_bool(restored.machine.is_boosted()).is_true()
	assert_int(restored.phase).is_equal(RunState.Phase.MACHINE_PICK)
	var key: Callable = func(prize: MachinePrize) -> String: return prize.key()
	assert_array(restored.machine.prizes().map(key)).is_equal(run.machine.prizes().map(key))


func test_a_save_that_cant_be_resumed_reads_as_null() -> void:
	var planning: Dictionary = _json(_save(_planning_run(21)))
	var choose_run: RunState = _planning_run(22)
	_fill(choose_run)
	choose_run.checkout()
	var choose: Dictionary = _json(_save(choose_run))
	MachineSteps.choose(choose_run, RewardMachine.Chute.NEW_ITEMS)
	var pick: Dictionary = _json(_save(choose_run))
	choose_run.machine.bin(choose_run)
	var scored: Dictionary = _json(_save(choose_run))
	# A card that resolves but isn't in the stock.
	var unstocked: CardDefinition = CardDefinition.new()
	unstocked.id = UNSTOCKED
	unstocked.kind = CardDefinition.Kind.PRODUCT
	_lookup.add(unstocked)
	var cases: Dictionary[String, Array] = {
		"no format version": [planning, func(d: Dictionary) -> void: d.erase("format_version")],
		"version 1": [planning, func(d: Dictionary) -> void: d["format_version"] = 1],
		"version 2 (Regular levels)":
		[planning, func(d: Dictionary) -> void: d["format_version"] = 2],
		"version 3, before the dealt starting deck":
		[planning, func(d: Dictionary) -> void: d["format_version"] = 3],
		"newer format": [planning, func(d: Dictionary) -> void: d["format_version"] = 5],
		"format as text": [planning, func(d: Dictionary) -> void: d["format_version"] = "4"],
		"starting deck missing": [planning, func(d: Dictionary) -> void: d.erase("starting_deck")],
		"seed as a number": [planning, func(d: Dictionary) -> void: d["seed"] = 12],
		"seed not a number": [planning, func(d: Dictionary) -> void: d["seed"] = "12a"],
		"seed too big": [planning, func(d: Dictionary) -> void: d["seed"] = "9223372036854775808"],
		"no rng state": [planning, func(d: Dictionary) -> void: d.erase("rng_state")],
		"phase scored": [planning, func(d: Dictionary) -> void: d["phase"] = "scored"],
		"phase won": [planning, func(d: Dictionary) -> void: d["phase"] = "won"],
		"old phase reward": [choose, func(d: Dictionary) -> void: d["phase"] = "reward"],
		"shift past quotas": [planning, func(d: Dictionary) -> void: d["shift_index"] = 8],
		"negative shift": [planning, func(d: Dictionary) -> void: d["shift_index"] = -1],
		"fractional shift": [planning, func(d: Dictionary) -> void: d["shift_index"] = 0.5],
		"unknown starter": [planning, func(d: Dictionary) -> void: d["starter"] = "gone"],
		"unknown deck card": [planning, func(d: Dictionary) -> void: d["deck"][0][1] = "gone"],
		"deck pair too short": [planning, func(d: Dictionary) -> void: d["deck"][0] = [1]],
		"instance id zero": [planning, func(d: Dictionary) -> void: d["deck"][0][0] = 0],
		"unknown hand card": [planning, func(d: Dictionary) -> void: d["hand"][0][1] = "gone"],
		"unknown upgrade": [planning, func(d: Dictionary) -> void: d["upgrades"] = ["gone"]],
		"id as path": [planning, func(d: Dictionary) -> void: d["starter"] = "../decks/starter"],
		"unknown aisle": [planning, func(d: Dictionary) -> void: d["listed_aisles"] = ["gone"]],
		"unknown stock card": [planning, func(d: Dictionary) -> void: d["stock"].append("gone")],
		"arrival not stocked":
		[planning, func(d: Dictionary) -> void: d["new_arrivals"] = [String(UNSTOCKED)]],
		"stock not a list": [planning, func(d: Dictionary) -> void: d["stock"] = "banana"],
		"run id a number": [planning, func(d: Dictionary) -> void: d["run_id"] = 7],
		"negative run time": [planning, func(d: Dictionary) -> void: d["run_ms"] = -1],
		"flag as text": [planning, func(d: Dictionary) -> void: d["list_skipped"] = "true"],
		"history too long": [planning, func(d: Dictionary) -> void: d["history"].append(_record())],
		"no machine": [planning, func(d: Dictionary) -> void: d.erase("machine")],
		"planning with a visit":
		[planning, func(d: Dictionary) -> void: d["machine"] = choose["machine"]],
		"history too short": [choose, func(d: Dictionary) -> void: d["history"].pop_back()],
		"record shift wrong": [choose, func(d: Dictionary) -> void: d["history"][0]["shift"] = 2],
		"record passed wrong":
		[choose, func(d: Dictionary) -> void: d["history"][0]["passed"] = false],
		"record without total":
		[choose, func(d: Dictionary) -> void: d["history"][0].erase("total")],
		"record without visits":
		[choose, func(d: Dictionary) -> void: d["history"][0].erase("visits")],
		"total not the row's":
		[choose, func(d: Dictionary) -> void: d["history"][-1]["total"] += 1],
		"machine stage idle": [choose, func(d: Dictionary) -> void: d["machine"]["stage"] = "idle"],
		"machine without its visit":
		[choose, func(d: Dictionary) -> void: d["machine"]["visit"] = {}],
		"pick with the choose stage": [pick, func(d: Dictionary) -> void: d["phase"] = "machine"],
		"pick without prizes":
		[pick, func(d: Dictionary) -> void: d["machine"]["visit"]["prizes"] = []],
		"boosted after a normal shift":
		[pick, func(d: Dictionary) -> void: d["machine"]["visit"]["boosted"] = true],
		"scored with a visit":
		[scored, func(d: Dictionary) -> void: d["machine"] = pick["machine"]],
		"ticket visit already recorded":
		[scored, func(d: Dictionary) -> void: d["machine"] = choose["machine"]],
		"row card not in hand": [choose, func(d: Dictionary) -> void: d["row"].append(999)],
		"row card twice": [choose, func(d: Dictionary) -> void: d["row"].append(d["row"][0])],
		"pile card not in deck":
		[planning, func(d: Dictionary) -> void: d["draw_pile"].append(999)],
		"pile card in hand":
		[planning, func(d: Dictionary) -> void: d["draw_pile"].append(d["hand"][0][0])],
		"deck ids repeat":
		[planning, func(d: Dictionary) -> void: d["deck"][1][0] = d["deck"][0][0]],
		"hand ids repeat": [planning, func(d: Dictionary) -> void: d["hand"][1] = d["hand"][0]],
		"hand card not the deck's":
		[planning, func(d: Dictionary) -> void: d["hand"][0][1] = _other_card(d["hand"][0][1])],
		"next id too low": [planning, func(d: Dictionary) -> void: d["next_instance_id"] = 2],
		"redraws over the limit": [planning, func(d: Dictionary) -> void: d["redraws_used"] = 5],
		"row over the card limit":
		[planning, func(d: Dictionary) -> void: d["row"] = d["hand"].map(_first)],
		"row over the product limit": [planning, _over_products],
	}
	for case_name: String in cases:
		var data: Dictionary = (cases[case_name][0] as Dictionary).duplicate(true)
		(cases[case_name][1] as Callable).call(data)
		var save: RunSave = RunSave.from_dictionary(data, _lookup)
		assert_object(save).override_failure_message(case_name).is_null()
	# Every base save is itself readable.
	for data: Dictionary in [planning, choose, pick, scored]:
		assert_object(RunSave.from_dictionary(data, _lookup)).is_not_null()


## A save made with a full row, read with a balance that has fewer product slots (tuned between
## sessions), can't be resumed: the row would no longer fit.
func test_a_save_whose_row_no_longer_fits_the_balance_reads_as_null() -> void:
	var planning: RunState = _planning_run(25)
	_fill(planning)
	var visit: RunState = _run_at_shift_two_checkout(26)
	var fewer_slots: BalanceDefinition = _balance.duplicate()
	fewer_slots.slot_count -= 1
	for run: RunState in [planning, visit]:
		assert_int(RowCapacity.product_count(run.row)).is_equal(_balance.slot_count)
		var data: Dictionary = _json(_save(run))
		assert_object(RunSave.from_dictionary(data, _lookup)).is_not_null()
		var stale: RunSave = RunSave.from_dictionary(data, ContentLookup.new(fewer_slots))
		assert_object(stale).override_failure_message(RunSave.phase_name(run.phase)).is_null()


## Plan section 3.8: places are saved, a redraw mode never is. A card from basket 1 on the belt,
## basket 2 redrawn, then the card taken back: every card resumes at its own place, the empty
## spot included while the card is on the belt.
func test_hand_places_round_trip_through_a_basket_redraw() -> void:
	var run: RunState = _planning_run(19)
	var hand: Array[CardInstance] = run.hand()
	assert_bool(run.place(hand[1], 0)).is_true()
	assert_array(run.redraw_basket(1)).is_equal([2, 3])
	var on_belt: RunState = _round_trip(run)
	assert_array(_place_ids(on_belt)).is_equal(_place_ids(run))
	assert_object(on_belt.hand_places()[1]).is_null()
	assert_bool(on_belt.remove(on_belt.row[0])).is_true()
	assert_int(on_belt.hand_places()[1].instance_id).is_equal(hand[1].instance_id)
	assert_bool(run.remove(hand[1])).is_true()
	var taken_back: RunState = _round_trip(run)
	assert_array(_place_ids(taken_back)).is_equal(_place_ids(run))
	assert_array(_place_ids(taken_back)).is_equal(_place_ids(on_belt))
	assert_array(taken_back.basket_places(0)).is_equal([0, 1])


## A save made while shifts allowed 1 redraw (before base_redraws became 2) still resumes: the
## shift keeps the redraws it started with, and the next shift to start has the balance's 2.
func test_a_save_from_one_redraw_per_shift_resumes_with_its_redraws() -> void:
	var run: RunState = _planning_run(27)
	run.redraw_basket(0)
	var data: Dictionary = _json(_save(run))
	data["redraws_allowed"] = 1
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	var restored: RunState = save.run
	assert_int(restored.redraws_used).is_equal(1)
	assert_int(restored.redraws_allowed).is_equal(1)
	assert_bool(restored.can_redraw_basket(1)).is_false()
	restored.start_shift()
	assert_int(restored.redraws_used).is_equal(0)
	assert_int(restored.redraws_allowed).is_equal(_balance.base_redraws)
	assert_int(restored.redraws_allowed).is_equal(2)


## Plays a scripted run: each shift a redraw of the first basket, every card that fits placed at the
## end, the first row card removed and placed back, the checkout, then every machine visit: a
## chute that rotates with the shift (the first lit one from there), its first prize taken (at
## the deck limit swapping a deck card out), or binned on even shifts. Each step's observed state
## is logged; with `resume`, the run is saved and restored through JSON text at every save point.
func _play(seed_value: int, resume: bool) -> Array[String]:
	var steps: Array[String] = []
	var run: RunState = _checkpoint(_planning_run(seed_value), resume, steps)
	while run.phase == RunState.Phase.PLANNING:
		run.redraw_basket(0)
		run = _checkpoint(run, resume, steps)
		var placed: bool = true
		while placed:
			placed = false
			for card: CardInstance in run.hand():
				if run.place(card, run.row.size()):
					placed = true
					run = _checkpoint(run, resume, steps)
					break
		var first: CardInstance = run.row[0]
		run.remove(first)
		run = _checkpoint(run, resume, steps)
		run.place(_by_instance_id(run.hand(), first.instance_id), 0)
		run = _checkpoint(run, resume, steps)
		run.checkout()
		run = _checkpoint(run, resume, steps)
		while RunState.MACHINE_PHASES.has(run.phase):
			if run.phase == RunState.Phase.MACHINE_CHOOSE:
				var preferred: int = RewardMachine.CHUTES[
					run.shift_index % RewardMachine.CHUTES.size()
				]
				(
					assert_bool(MachineSteps.choose(run, MachineSteps.first_lit(run, preferred)))
					. is_true()
				)
			elif run.machine.can_bin() and run.shift_index % 2 == 1:
				run.machine.bin(run)
			else:
				var replaced: CardInstance = null
				if run.machine.needs_replace(run, 0):
					replaced = run.deck.cards[run.shift_index % run.deck.size()]
				assert_object(run.machine.pick(run, 0, replaced)).is_not_null()
			run = _checkpoint(run, resume, steps)
		run.next_shift()
		run = _checkpoint(run, resume, steps)
	return steps


## Logs the run's observed state; with `resume` at a save point, returns the run restored from
## its saved form through JSON text.
func _checkpoint(run: RunState, resume: bool, steps: Array[String]) -> RunState:
	steps.append(_observe(run))
	if not resume or not RunSave.is_save_point(run.phase):
		return run
	var save: RunSave = RunSave.from_dictionary(_json(_save(run)), _lookup)
	assert_object(save).is_not_null()
	return save.run


## Saves, reads back through JSON text, checks the saved form is unchanged and the observed state
## matches, and returns the restored run.
func _round_trip(run: RunState) -> RunState:
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 4321)
	assert_dict(data).is_not_empty()
	var save: RunSave = RunSave.from_dictionary(_json(data), _lookup)
	assert_object(save).is_not_null()
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	assert_bool(again == data).is_true()
	assert_str(_observe(save.run)).is_equal(_observe(run))
	return save.run


## What a player or the UI can see of the run, as JSON text.
func _observe(run: RunState) -> String:
	var hand: Array[CardInstance] = run.hand()
	var state: Dictionary = {
		"phase": run.phase,
		"shift": run.shift_index,
		"quota": run.quota(),
		"hand": _pairs(hand),
		"row": _pairs(run.row),
		"deck": _pairs(run.deck.cards),
		"deck_size": run.deck.size(),
		"deck_is_full": run.deck_is_full(),
		"places": _place_ids(run),
		"can_redraw": run.can_redraw_basket(0),
		"redraws": [run.redraws_used, run.redraws_allowed],
		"machine": run.machine.to_dictionary(),
		"prizes": run.machine.prizes().map(func(prize: MachinePrize) -> String: return prize.key()),
		"can_bin": run.machine.can_bin(),
		"upgrades": _ids(run.upgrades),
		"inspections": _ids(run.inspections),
		"next_inspection": _ids([run.next_inspection] if run.next_inspection != null else []),
		"history":
		run.history.map(func(record: ShiftRecord) -> Dictionary: return record.to_dictionary()),
		"last_total": run.last_result.total if run.last_result != null else -1,
		"preview": run.preview().total,
	}
	return JSON.stringify(state)


func _new_run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	return RunState.new(seed_value, deck, _balance, RunStock.starting(_balance))


## Shift 1, planning.
func _planning_run(seed_value: int) -> RunState:
	var run: RunState = _new_run(seed_value)
	run.start_shift()
	return run


## Shift 2's checkout, after shift 1's NEW ITEMS pick (the deck holds 14 of 15): shift 3 is
## inspected and STAMP DAY waits after the ticket (no register yet).
func _run_at_shift_two_checkout(seed_value: int) -> RunState:
	var run: RunState = _planning_run(seed_value)
	_fill(run)
	run.checkout()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	run.next_shift()
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	return run


## The first passed inspected shift's bonus visit, waiting for its chute (MACHINE_CHOOSE): each
## shift checks out Milk, Multipack and Milk x5 (what the row takes of it), the ticket chooses
## NEW ITEMS and bins it (a BOOSTED ticket, v0.47: takes the first lit chute's first prize); the
## other visits pass (MachineSteps).
func _run_at_bonus_visit(seed_value: int) -> RunState:
	var run: RunState = _planning_run(seed_value)
	for _shift: int in range(run.shift_count() - 1):
		for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
			var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % id))
			run.place(card, run.row.size())
		run.checkout()
		assert_bool(RunState.MACHINE_PHASES.has(run.phase)).is_true()
		MachineSteps.choose(run, MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS))
		if run.machine.can_bin():
			run.machine.bin(run)
		else:
			MachineSteps.take(run, 0)
		if (
			run.phase == RunState.Phase.MACHINE_CHOOSE
			and run.machine.current_visit().kind == MachineVisit.Kind.BONUS
		):
			assert_str(run.machine.current_visit().why).is_not_empty()
			return run
		MachineSteps.next_shift(run)
	assert_bool(false).override_failure_message("no bonus visit").is_true()
	return run


## Shift 3 planning, every visit before it passed (MachineSteps).
func _run_at_shift_three(seed_value: int) -> RunState:
	var run: RunState = _planning_run(seed_value)
	for _shift: int in range(2):
		_fill(run)
		run.checkout()
		MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(2)
	return run


func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


func _save(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


## Fills the row with one product more than the product slots, and no more cards than the row
## holds: extra Banana copies join the hand, as the debug panel adds them.
func _over_products(data: Dictionary) -> void:
	assert_int(_balance.slot_count + 1).is_less_equal(RowCapacity.card_limit(_no_upgrade_limits()))
	var products: Array = []
	for pair: Array in data["hand"]:
		if not _lookup.card(pair[1]).is_coupon():
			products.append(pair[0])
	var next_id: int = int(data["next_instance_id"])
	while products.size() <= _balance.slot_count:
		data["hand"].append([next_id, "banana"])
		products.append(next_id)
		next_id += 1
	data["next_instance_id"] = next_id
	data["row"] = products.slice(0, _balance.slot_count + 1)


static func _first(pair: Array) -> Variant:
	return pair[0]


static func _record() -> Dictionary:
	return ShiftRecord.new(1, 1, 5).to_dictionary()


## A card id other than `id`.
static func _other_card(id: String) -> String:
	return "bread" if id != "bread" else "banana"


static func _by_instance_id(cards: Array[CardInstance], id: int) -> CardInstance:
	for card: CardInstance in cards:
		if card.instance_id == id:
			return card
	return null


static func _pairs(cards: Array[CardInstance]) -> Array:
	var pairs: Array = []
	for card: CardInstance in cards:
		pairs.append([card.instance_id, String(card.definition.id)])
	return pairs


static func _instance_ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


static func _ids(resources: Array) -> Array:
	var ids: Array = []
	for resource: Resource in resources:
		ids.append(str(resource.get("id")))
	return ids


## The row's limits with no upgrades, as a new run's shift starts.
func _no_upgrade_limits() -> ShiftLimits:
	var none: Array[UpgradeDefinition] = []
	return ShiftLimits.for_shift(_balance, none, 0)


## Each hand place's instance id, -1 where the card is in the row.
static func _place_ids(run: RunState) -> Array:
	return run.hand_places().map(
		func(card: CardInstance) -> int: return -1 if card == null else card.instance_id
	)
