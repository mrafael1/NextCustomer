extends GdUnitTestSuite
## Inspections in a run (plan section 3.9): the shifts in inspection_shifts are played under an
## inspection drawn from inspection_pool with the run's RNG at the previous passed checkout
## (before the RECEIPT REWARDS machine's visits draw, #77), announced through the visits, and
## applied to the preview and checkout of that shift only.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"


func test_balance_inspection_data_fits_the_run() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	# v0.65: each week's 3rd shift, and its 4th the Manager's review (2 inspections at once).
	assert_array(Array(balance.inspection_shifts)).is_equal([3, 7, 11])
	assert_array(Array(balance.review_shifts)).is_equal([4, 8, 12])
	for shift_number: int in balance.inspection_shifts + balance.review_shifts:
		# Announced on the previous shift's receipt, so never shift 1.
		assert_int(shift_number).is_between(2, balance.quotas.size())
	assert_int(balance.review_inspection_count).is_between(2, balance.inspection_pool.size())
	# Coupon slot closed left in v0.56 (#106): every slot is general. v0.69's day events: 6
	# inspections (maluses), and 6 boons for the boon days (never shift 1, nor an inspected one).
	assert_array(RunEvents.inspection_ids(balance.inspection_pool)).is_equal(
		["spot_check", "short_belt", "till_jam", "small_baskets", "rush_hour", "late_delivery"]
	)
	for inspection: InspectionDefinition in balance.inspection_pool:
		assert_bool(inspection.is_boon()).is_false()
	assert_array(Array(balance.boon_shifts)).is_equal([2, 5, 6, 9, 10])
	(
		assert_array(RunEvents.inspection_ids(balance.boon_pool))
		. is_equal(
			[
				"quiet_morning",
				"extra_till",
				"regulars_day",
				"fresh_delivery",
				"free_samples",
				"happy_hour",
			]
		)
	)
	for boon: InspectionDefinition in balance.boon_pool:
		assert_bool(boon.is_boon()).is_true()
	for shift_number: int in balance.boon_shifts:
		assert_bool(InspectionSchedule.is_inspection_shift(balance, shift_number)).is_false()
		assert_int(shift_number).is_between(2, balance.quotas.size())


func test_the_inspection_is_announced_at_the_previous_checkout() -> void:
	var run: RunState = _run(41)
	_pass(run)
	# Shift 2 is not inspected: nothing is announced after shift 1.
	assert_object(run.next_inspection).is_null()
	MachineSteps.next_shift(run)
	assert_array(run.inspections).is_empty()
	_pass(run)
	# Shift 3 is: announced at shift 2's checkout, kept through the machine's visits.
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	assert_array(run.inspections).is_empty()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	MachineSteps.pass_visits(run)
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	run.next_shift()
	assert_array(run.inspections).is_equal([load(SPOT_CHECK)])
	assert_object(run.next_inspection).is_null()
	# Shift 4 is not inspected.
	_pass(run)
	assert_object(run.next_inspection).is_null()
	MachineSteps.next_shift(run)
	assert_array(run.inspections).is_empty()


func test_the_inspected_shift_scores_and_records_it() -> void:
	var run: RunState = _run(42)
	run.debug_skip_to_shift(2)
	assert_array(run.inspections).is_equal([load(SPOT_CHECK)])
	for _index: int in range(3):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	# Three Breads: the 3rd pays 0, in the preview and at checkout.
	assert_array(Array(run.preview().payouts)).is_equal([5, 5, 0])
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(10)
	var inspection_steps: Array = result.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.INSPECTION
	)
	assert_int(inspection_steps.size()).is_equal(1)
	assert_object(run.history[-1].inspection).is_same(load(SPOT_CHECK))
	assert_str(run.history[-1].to_dictionary()["inspection"]).is_equal("spot_check")


func test_a_lost_shift_announces_nothing() -> void:
	var run: RunState = _run(43)
	run.debug_skip_to_shift(1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_object(run.next_inspection).is_null()


func test_the_last_shift_announces_nothing() -> void:
	var balance: BalanceDefinition = _low_quotas()
	# The shift after the last one doesn't exist: listing it means only the last-shift rule
	# stops the draw.
	balance.inspection_shifts = PackedInt32Array([3, 5, 7, balance.quotas.size() + 1])
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(44, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(balance.quotas.size() - 1)
	assert_bool(InspectionSchedule.is_inspection_shift(balance, run.shift_index + 2)).is_true()
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_object(run.next_inspection).is_null()


## v0.70: a week's day events are drawn as its first shift starts (shift 1's after its hand), so
## two runs that differ only in their inspected shifts deal the same first hand, and a checkout
## draws no event: the machine waiting for its chute has drawn nothing either.
func test_the_week_is_drawn_as_it_starts_not_at_checkout() -> void:
	var plain: RunState = _two_inspection_run(48, PackedInt32Array())
	var inspected: RunState = _two_inspection_run(48, PackedInt32Array([3]))
	assert_array(_ids(inspected.hand())).is_equal(_ids(plain.hand()))
	assert_array(plain.week.day(3)).is_empty()
	assert_int(inspected.week.day(3).size()).is_equal(1)
	for run: RunState in [plain, inspected]:
		_pass(run)
		MachineSteps.next_shift(run)
		var state: int = run.rng_state
		_pass(run)
		assert_int(run.rng_state).is_equal(state)
		assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_object(plain.next_inspection).is_null()
	assert_object(inspected.next_inspection).is_same(inspected.week.day(3)[0])


func test_the_same_seed_gives_the_same_run() -> void:
	assert_array(_hands_through_shift_three(45)).is_equal(_hands_through_shift_three(45))


func test_an_empty_pool_draws_nothing_and_uses_no_rng() -> void:
	var balance: BalanceDefinition = _low_quotas()
	balance.inspection_pool = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 46
	var state: int = rng.state
	assert_object(InspectionSchedule.draw(rng, balance)).is_null()
	assert_int(rng.state).is_equal(state)
	# A run with no pool plays its inspected shifts without an inspection.
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(46, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(1)
	_pass(run)
	assert_object(run.next_inspection).is_null()
	MachineSteps.next_shift(run)
	assert_array(run.inspections).is_empty()


func test_debug_restart_keeps_the_inspections() -> void:
	var run: RunState = _run(47)
	run.debug_skip_to_shift(4)
	assert_array(run.inspections).is_equal([load(SPOT_CHECK)])
	run.inspections = []
	run.debug_skip_to_shift(4)
	assert_array(run.inspections).is_empty()
	run.debug_skip_to_shift(5)
	assert_array(run.inspections).is_empty()


static func _hands_through_shift_three(seed_value: int) -> Array:
	var run: RunState = _run(seed_value)
	var hands: Array = []
	for _shift: int in range(3):
		hands.append(_ids(run.hand()))
		_pass(run)
		MachineSteps.next_shift(run)
	hands.append(RunEvents.inspection_ids(run.inspections))
	return hands


## A low-quota run whose pool holds two inspections, inspected on `inspection_shifts`.
static func _two_inspection_run(seed_value: int, inspection_shifts: PackedInt32Array) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var other: InspectionDefinition = (load(SPOT_CHECK) as InspectionDefinition).duplicate()
	other.id = &"other_check"
	var pool: Array[InspectionDefinition] = [load(SPOT_CHECK), other]
	balance.inspection_pool = pool
	balance.inspection_shifts = inspection_shifts
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run


## Quotas all 5, and a pool holding only Spot check: these tests follow Spot check through the
## run. The other inspections are tested in inspections_test.
static func _low_quotas() -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	# The run before v0.65's loop rework (these runs are scripted around it).
	EightShiftLoop.apply(balance)
	var pool: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	balance.inspection_pool = pool
	return balance


## A run whose quotas are all 5, so two Breads (6) pass any shift, inspected or not.
static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


static func _ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(String(card.definition.id))
	return ids
