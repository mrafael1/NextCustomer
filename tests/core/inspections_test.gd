extends GdUnitTestSuite
## Phase 2's inspections (issue #39, plan section 3.9, v0.25): Short belt (one product slot
## fewer than the run has) and Coupon slot closed (one coupon slot fewer) through the shift's
## limits, Slot engine under Short belt with and without Big basket, and the draw that never
## repeats the run's last inspection.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
const INSPECTIONS := "res://data/inspections/%s.tres"
const UPGRADES := "res://data/upgrades/%s.tres"


## Short belt closes one product slot from what the run has: 6 become 5, and with Big basket 7
## become 6.
func test_short_belt_closes_one_product_slot() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var belt: Array[InspectionDefinition] = [_inspection("short_belt")]
	var none: Array[UpgradeDefinition] = []
	var plain: ShiftLimits = ShiftLimits.for_shift(balance, none, 2, belt)
	assert_int(plain.slot_count).is_equal(balance.slot_count - 1)
	assert_int(plain.closed_slots).is_equal(1)
	assert_int(plain.coupon_slot_count).is_equal(balance.coupon_slot_count)
	assert_int(plain.closed_coupon_slots).is_equal(0)
	var basket: Array[UpgradeDefinition] = [_upgrade("big_basket")]
	var with_basket: ShiftLimits = ShiftLimits.for_shift(balance, basket, 2, belt)
	assert_int(with_basket.slot_count).is_equal(balance.slot_count)
	assert_int(with_basket.closed_slots).is_equal(1)
	# Big basket's quota raise stays.
	assert_int(with_basket.quota).is_equal(ShiftLimits.raised_quota(balance.quotas[2], 15))


## Coupon slot closed takes one coupon slot: 1 becomes 0, and with Extra coupon slot 2 become 1.
## Coupons can still use product slots.
func test_coupon_slot_closed_takes_one_coupon_slot() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var closed: Array[InspectionDefinition] = [_inspection("coupon_slot_closed")]
	var none: Array[UpgradeDefinition] = []
	var plain: ShiftLimits = ShiftLimits.for_shift(balance, none, 2, closed)
	assert_int(plain.coupon_slot_count).is_equal(0)
	assert_int(plain.closed_coupon_slots).is_equal(1)
	assert_int(plain.slot_count).is_equal(balance.slot_count)
	var extra: Array[UpgradeDefinition] = [_upgrade("extra_coupon_slot")]
	assert_int(ShiftLimits.for_shift(balance, extra, 2, closed).coupon_slot_count).is_equal(1)
	var run: RunState = _run(51, "coupon_slot_closed")
	for index: int in range(5):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	assert_bool(run.place(run.debug_add_to_hand(load(REPEAT)), 5)).is_true()
	assert_bool(run.can_place(run.debug_add_to_hand(load(REPEAT)))).is_false()


## Short belt turns an owned Slot engine off when the run has no Big basket (no 6th product can
## be placed), and Big basket counters it (decided with the user).
func test_short_belt_and_slot_engine() -> void:
	var run: RunState = _run(52, "short_belt")
	run.upgrades.append(_upgrade("slot_engine"))
	run.debug_skip_to_shift(run.shift_index)
	for index: int in range(5):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	assert_bool(run.can_place(run.debug_add_to_hand(load(BREAD)))).is_false()
	assert_int(_upgrade_multipliers(run.preview())).is_equal(0)
	run.upgrades.append(_upgrade("big_basket"))
	run.debug_skip_to_shift(run.shift_index)
	for index: int in range(6):
		assert_bool(run.place(run.debug_add_to_hand(load(BREAD)), index)).is_true()
	assert_int(_upgrade_multipliers(run.preview())).is_equal(1)
	assert_int(run.preview().payouts[5]).is_equal(6)


## The shift's inspection reaches the run save: a resumed run gets the same closed slot.
func test_a_resumed_run_keeps_the_closed_slot() -> void:
	var run: RunState = _run(53, "short_belt")
	for index: int in range(5):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	var data: Dictionary = JSON.parse_string(
		JSON.stringify(RunSave.to_dictionary(run, "0011223344556677", 1000))
	)
	var restored: RunSave = RunSave.from_dictionary(data, ContentLookup.new(run.balance))
	assert_object(restored).is_not_null()
	assert_int(restored.run.limits.slot_count).is_equal(run.balance.slot_count - 1)
	assert_int(restored.run.limits.closed_slots).is_equal(1)
	assert_int(restored.run.row.size()).is_equal(5)


## No inspection twice in a row: the draw skips the previous one (unless it is the only one),
## and every inspection still comes up.
func test_the_draw_never_repeats_the_last_inspection() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var seen: Dictionary = {}
	for previous: InspectionDefinition in balance.inspection_pool:
		for seed_value: int in range(60):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed_value
			var drawn: InspectionDefinition = InspectionSchedule.draw(rng, balance, previous)
			assert_object(drawn).is_not_same(previous)
			seen[drawn.id] = true
	assert_int(seen.size()).is_equal(balance.inspection_pool.size())
	var only: BalanceDefinition = balance.duplicate()
	var single: Array[InspectionDefinition] = [_inspection("spot_check")]
	only.inspection_pool = single
	var one: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_object(InspectionSchedule.draw(one, only, single[0])).is_same(single[0])


## Through a run: shift 5's inspection is never shift 3's.
func test_a_run_never_repeats_an_inspection_back_to_back() -> void:
	for seed_value: int in range(25):
		var run: RunState = _plain_run(seed_value)
		var drawn: Array[InspectionDefinition] = []
		while run.phase != RunState.Phase.WON and drawn.size() < 3:
			_pass(run)
			if run.next_inspection != null:
				drawn.append(run.next_inspection)
			if run.phase == RunState.Phase.REWARD:
				run.skip_reward()
			if run.phase == RunState.Phase.UPGRADE:
				run.pick_upgrade(run.upgrade_offer[0])
			run.next_shift()
		assert_int(drawn.size()).override_failure_message("seed %d" % seed_value).is_equal(3)
		assert_object(drawn[1]).is_not_same(drawn[0])
		assert_object(drawn[2]).is_not_same(drawn[1])


static func _upgrade_multipliers(result: ScoreResult) -> int:
	var count: int = 0
	for step: ScoreStep in result.steps:
		if (
			step.step_type == ScoreStep.StepType.MULTIPLIER
			and step.source_kind == ScoreStep.SourceKind.UPGRADE
		):
			count += 1
	return count


## A run on shift 3 under one inspection, with quotas of 1.
static func _run(seed_value: int, inspection_id: String) -> RunState:
	var run: RunState = _plain_run(seed_value)
	run.debug_skip_to_shift(2)
	run.inspections = [_inspection(inspection_id)]
	run.debug_skip_to_shift(2)
	return run


static func _plain_run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


static func _inspection(inspection_id: String) -> InspectionDefinition:
	return load(INSPECTIONS % inspection_id)


static func _upgrade(upgrade_id: String) -> UpgradeDefinition:
	return load(UPGRADES % upgrade_id)
