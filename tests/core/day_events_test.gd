extends GdUnitTestSuite
## Day events (v0.69, plan section 3.9): inspections are the MALUS day events; boons help. The
## shift's limits take every event's slots, redraws, hand items and quota percent (ShiftLimits);
## the schedule draws a boon on the boon days (never moving the run's RNG), one inspection on the
## inspected shifts and two different ones on the Manager's reviews, with no event twice in a row;
## a boon is never an inspection (no INSPECTION PASSED, no bonus ticket); and a save from before
## the boon days gets its next boon as it loads.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const BREAD := "res://data/cards/bread.tres"
const DIR := "res://data/inspections/%s.tres"


func test_the_limits_take_every_event() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var none: Array[UpgradeDefinition] = []
	var plain: ShiftLimits = ShiftLimits.for_shift(balance, none, 1)
	var cases: Dictionary = {
		"extra_till": [1, 0, 0, plain.quota],
		"regulars_day": [0, 1, 0, plain.quota],
		"big_trolleys": [0, 0, 1, plain.quota],
		"quiet_morning": [0, 0, 0, roundi(plain.quota * 0.9)],
		"short_belt": [-1, 0, 0, plain.quota],
		"till_jam": [0, -1, 0, plain.quota],
		"small_baskets": [0, 0, -1, plain.quota],
		"rush_hour": [0, 0, 0, roundi(plain.quota * 1.1)],
	}
	for id: String in cases:
		var expected: Array = cases[id]
		var events: Array[InspectionDefinition] = [load(DIR % id)]
		var limits: ShiftLimits = ShiftLimits.for_shift(balance, none, 1, events)
		assert_int(limits.slot_count).override_failure_message(id).is_equal(
			plain.slot_count + int(expected[0])
		)
		assert_int(limits.redraws).override_failure_message(id).is_equal(
			plain.redraws + int(expected[1])
		)
		assert_int(limits.own_redraws).override_failure_message(id).is_equal(limits.redraws)
		assert_int(limits.hand_size).override_failure_message(id).is_equal(
			balance.hand_size + int(expected[2])
		)
		assert_int(limits.quota).override_failure_message(id).is_equal(int(expected[3]))


## An upgrade's redraw is not the shift's own (Extra redraw's credit), an event's is.
func test_an_upgrades_redraw_is_never_the_shifts_own() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var upgrades: Array[UpgradeDefinition] = [load("res://data/upgrades/extra_redraw.tres")]
	var events: Array[InspectionDefinition] = [load(DIR % "regulars_day")]
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, upgrades, 1, events)
	assert_int(limits.redraws).is_equal(balance.base_redraws + 2)
	assert_int(limits.own_redraws).is_equal(balance.base_redraws + 1)


func test_a_quota_percent_rounds_and_keeps_a_zero_quota() -> void:
	assert_int(ShiftLimits.with_percent(35, -10)).is_equal(32)
	assert_int(ShiftLimits.with_percent(29, 10)).is_equal(32)
	assert_int(ShiftLimits.with_percent(35, 0)).is_equal(35)
	assert_int(ShiftLimits.with_percent(0, 10)).is_equal(0)
	assert_int(ShiftLimits.with_percent(1, -90)).is_equal(1)


func test_the_hand_never_drops_below_one_item() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.hand_size = 1
	var none: Array[UpgradeDefinition] = []
	var events: Array[InspectionDefinition] = [load(DIR % "small_baskets")]
	assert_int(ShiftLimits.for_shift(balance, none, 1, events).hand_size).is_equal(1)


## The live schedule: shift 1 none, boon days 2, 5, 6, 9 and 10 one boon, shifts 3, 7 and 11 one
## inspection, the reviews 4, 8 and 12 two different inspections; never the same event on two
## shifts in a row (back to back across a review, and boon day to boon day).
func test_the_schedule_draws_the_right_events_without_repeats() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for seed_value: int in range(40):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var history: Array[ShiftRecord] = []
		var current: Array[InspectionDefinition] = []
		for shift_number: int in range(2, balance.quotas.size() + 1):
			var previous: Array[InspectionDefinition] = InspectionSchedule.last_of(current, history)
			var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(
				rng, balance, shift_number, previous
			)
			var maluses: Array[InspectionDefinition] = InspectionDefinition.maluses(drawn)
			var boons: Array[InspectionDefinition] = InspectionDefinition.boons(drawn)
			var message: String = "seed %d shift %d" % [seed_value, shift_number]
			var expected_boons: int = 1 if balance.boon_shifts.has(shift_number) else 0
			assert_int(boons.size()).override_failure_message(message).is_equal(expected_boons)
			assert_int(maluses.size()).override_failure_message(message).is_equal(
				InspectionSchedule.count_for(balance, shift_number)
			)
			# Inspections first, then the boon; all different, none from the last ones.
			assert_array(drawn).override_failure_message(message).is_equal(maluses + boons)
			for event: InspectionDefinition in drawn:
				assert_int(drawn.count(event)).override_failure_message(message).is_equal(1)
				assert_bool(previous.has(event)).override_failure_message(message).is_false()
			var record: ShiftRecord = ShiftRecord.new(shift_number - 1, 1, 1)
			record.inspections = current
			history.append(record)
			current = drawn
	assert_int(InspectionSchedule.count_for(balance, 1)).is_equal(0)
	assert_int(InspectionSchedule.boon_count_for(balance, 1)).is_equal(0)


## A boon day's boon is drawn with the run's RNG (core/AGENTS.md: no seed made in core/): the
## same state draws the same boon.
func test_a_boon_is_drawn_with_the_run_rng() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var state: int = rng.state
	var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(rng, balance, 2)
	assert_int(drawn.size()).is_equal(1)
	assert_bool(drawn[0].is_boon()).is_true()
	assert_int(rng.state).is_not_equal(state)
	rng.state = state
	assert_array(InspectionSchedule.draw_for(rng, balance, 2)).is_equal(drawn)


## A boon is never an inspection: a boon day's record has no inspection, earns no bonus ticket
## and is not left out of the next shift's inspection draw.
func test_a_boon_is_never_an_inspection() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	balance.machine = balance.machine.duplicate() as MachineDefinition
	balance.machine.bonus_after_inspection = true
	balance.machine.bonus_extra_shifts = PackedInt32Array()
	var run: RunState = RunState.new(3, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	_pass(run)
	MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.inspections.size()).is_equal(1)
	assert_bool(run.inspections[0].is_boon()).is_true()
	assert_bool(run.machine.bonus_if_passed(run)).is_false()
	_pass(run)
	var record: ShiftRecord = run.history[-1]
	assert_object(record.inspection).is_null()
	assert_array(record.inspections).is_equal(run.inspections)
	assert_bool(run.machine.bonus_earned(run)).is_false()
	assert_array(run.machine.pending_kinds()).not_contains([MachineVisit.Kind.BONUS])
	# Shift 3's inspection is announced, and passing it would earn the bonus.
	assert_int(InspectionDefinition.maluses(run.next_inspections).size()).is_equal(1)
	MachineSteps.next_shift(run)
	assert_bool(run.machine.bonus_if_passed(run)).is_true()


## A boon day deals its hand from the shift's limits (Big trolleys: one item more), and a redraw
## a boon gave is the shift's own: no Extra redraw credit.
func test_a_boon_day_deals_and_redraws_by_its_limits() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	var trolleys: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	trolleys.inspections = [load(DIR % "big_trolleys")]
	trolleys.start_shift()
	assert_int(trolleys.hand().size()).is_equal(balance.hand_size + 1)
	var run: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	run.inspections = [load(DIR % "regulars_day")]
	run.start_shift()
	assert_int(run.hand().size()).is_equal(balance.hand_size)
	assert_int(run.redraws_allowed).is_equal(balance.base_redraws + 1)
	for basket: int in range(run.redraws_allowed):
		assert_array(run.redraw_basket(basket)).is_not_empty()
	assert_int(run.redraws_used).is_equal(balance.base_redraws + 1)
	assert_array(Array(run.redrawn_in)).is_empty()


## A version 8 save (before the boon days) taken after a checkout whose next shift is a boon day
## gets its boon as it loads; a version 9 save keeps the boons it names.
func test_an_older_save_gets_the_next_boon() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var balance: BalanceDefinition = lookup.balance
	var run: RunState = RunState.new(11, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	for id: String in ["milk", "milk", "milk", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var boon: Array[InspectionDefinition] = InspectionDefinition.boons(run.next_inspections)
	assert_int(boon.size()).is_equal(1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 1)))
	var kept: RunSave = RunSave.from_dictionary(saved, lookup)
	assert_array(kept.run.next_inspections).is_equal(run.next_inspections)
	saved["format_version"] = RunSave.BEFORE_DAY_EVENTS_VERSION
	saved["next_inspections"] = []
	var older: RunSave = RunSave.from_dictionary(saved, lookup)
	assert_object(older).is_not_null()
	assert_int(InspectionDefinition.boons(older.run.next_inspections).size()).is_equal(1)
	# Drawn with the run's RNG, from the saved state: the run's RNG moves on past it.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = run.rng_state
	var previous: Array[InspectionDefinition] = InspectionSchedule.last_of(
		run.inspections, run.history
	)
	var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(
		rng, balance, run.shift_index + 2, previous
	)
	assert_array(InspectionDefinition.boons(older.run.next_inspections)).is_equal(
		InspectionDefinition.boons(drawn)
	)
	assert_int(older.run.rng_state).is_equal(rng.state)


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()
