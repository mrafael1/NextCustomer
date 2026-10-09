extends GdUnitTestSuite
## Inspections in a run (plan section 3.9): the shifts in inspection_shifts are played under an
## inspection drawn from inspection_pool with the run's RNG at the previous passed checkout
## (after the reward and upgrade offers), announced through the REWARD and UPGRADE phases, and
## applied to the preview and checkout of that shift only.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"


func test_balance_inspection_data_fits_the_run() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_array(Array(balance.inspection_shifts)).is_equal([3, 5, 7])
	for shift_number: int in balance.inspection_shifts:
		# Announced on the previous shift's receipt, so never shift 1.
		assert_int(shift_number).is_between(2, balance.quotas.size())
	assert_array(RunEvents.inspection_ids(balance.inspection_pool)).is_equal(
		["spot_check", "short_belt", "coupon_slot_closed"]
	)


func test_the_inspection_is_announced_at_the_previous_checkout() -> void:
	var run: RunState = _run(41)
	_pass(run)
	# Shift 2 is not inspected: nothing is announced after shift 1.
	assert_object(run.next_inspection).is_null()
	run.skip_reward()
	run.next_shift()
	assert_array(run.inspections).is_empty()
	_pass(run)
	# Shift 3 is: announced at shift 2's checkout, kept through the reward and the kiosk.
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	assert_array(run.inspections).is_empty()
	run.skip_reward()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	run.pick_upgrade(run.upgrade_offer[0])
	assert_object(run.next_inspection).is_same(load(SPOT_CHECK))
	run.next_shift()
	assert_array(run.inspections).is_equal([load(SPOT_CHECK)])
	assert_object(run.next_inspection).is_null()
	# Shift 4 is not inspected.
	_pass(run)
	assert_object(run.next_inspection).is_null()
	run.skip_reward()
	run.next_shift()
	assert_array(run.inspections).is_empty()


func test_the_inspected_shift_scores_and_records_it() -> void:
	var run: RunState = _run(42)
	run.debug_skip_to_shift(2)
	assert_array(run.inspections).is_equal([load(SPOT_CHECK)])
	for _index: int in range(3):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	# Three Breads: the 3rd pays 0, in the preview and at checkout.
	assert_array(Array(run.preview().payouts)).is_equal([3, 3, 0])
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(6)
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
	var run: RunState = RunState.new(44, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	run.debug_skip_to_shift(balance.quotas.size() - 1)
	assert_bool(InspectionSchedule.is_inspection_shift(balance, run.shift_index + 2)).is_true()
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_object(run.next_inspection).is_null()


## Plan section 3.9: the draw comes after the reward and upgrade offers. With two inspections
## in the pool every draw uses the RNG, so drawing earlier would change shift 2's offers.
func test_the_inspection_is_drawn_after_the_offers() -> void:
	var plain: RunState = _two_inspection_run(48, PackedInt32Array())
	var inspected: RunState = _two_inspection_run(48, PackedInt32Array([3]))
	for run: RunState in [plain, inspected]:
		_pass(run)
		run.skip_reward()
		run.next_shift()
		_pass(run)
	assert_array(_definition_ids(inspected.offer)).is_equal(_definition_ids(plain.offer))
	assert_array(_definition_ids(inspected.upgrade_offer)).is_equal(
		_definition_ids(plain.upgrade_offer)
	)
	assert_object(plain.next_inspection).is_null()
	assert_bool(inspected.balance.inspection_pool.has(inspected.next_inspection)).is_true()


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
	var run: RunState = RunState.new(46, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	run.debug_skip_to_shift(1)
	_pass(run)
	assert_object(run.next_inspection).is_null()
	run.skip_reward()
	run.pick_upgrade(run.upgrade_offer[0])
	run.next_shift()
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
		run.skip_reward()
		if run.phase == RunState.Phase.UPGRADE:
			run.pick_upgrade(run.upgrade_offer[0])
		run.next_shift()
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
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _definition_ids(definitions: Array) -> Array:
	return definitions.map(
		func(definition: Resource) -> String: return String(definition.get("id"))
	)


## Quotas all 5, and a pool holding only Spot check: these tests follow Spot check through the
## run. The other inspections are tested in inspections_test.
static func _low_quotas() -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	var pool: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	balance.inspection_pool = pool
	return balance


## A run whose quotas are all 5, so two Breads (6) pass any shift, inspected or not.
static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
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
