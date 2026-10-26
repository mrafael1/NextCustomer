extends GdUnitTestSuite
## Phase 2's inspections (issue #39, plan section 3.9, v0.25): Short belt (one slot fewer than
## the run has) through the shift's limits, Slot engine under Short belt with and without Big
## basket, and the draw that never repeats the run's last inspection. Since 2026-10-24 (#106
## follow-up) Slot engine keeps to slot 6 whatever the shift's slots (from #42 until then its
## product followed them). Coupon slot closed was removed in v0.56 (#106: every slot is general).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const REPEAT := "res://data/cards/repeat.tres"
const INSPECTIONS := "res://data/inspections/%s.tres"
const UPGRADES := "res://data/upgrades/%s.tres"


## Short belt closes one slot from what the run has: 7 become 6, and with Big basket 8 become 7.
func test_short_belt_closes_one_slot() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var belt: Array[InspectionDefinition] = [_inspection("short_belt")]
	var none: Array[UpgradeDefinition] = []
	var plain: ShiftLimits = ShiftLimits.for_shift(balance, none, 2, belt)
	assert_int(plain.slot_count).is_equal(balance.slot_count - 1)
	assert_int(plain.closed_slots).is_equal(1)
	var basket: Array[UpgradeDefinition] = [_upgrade("big_basket")]
	var with_basket: ShiftLimits = ShiftLimits.for_shift(balance, basket, 2, belt)
	assert_int(with_basket.slot_count).is_equal(balance.slot_count)
	assert_int(with_basket.closed_slots).is_equal(1)
	# Big basket no longer raises the quota (plan v0.46, #106).
	assert_int(with_basket.quota).is_equal(balance.quotas[2])


## Short belt leaves 6 slots, and an owned Slot engine still doubles slot 6, the last open one
## (decided with the user on 2026-10-24; from #42 until then the 5th product). With Big basket the
## row keeps 7 slots and Slot engine slot 6 still.
func test_short_belt_and_slot_engine() -> void:
	var run: RunState = _run(52, "short_belt")
	run.upgrades.append(_upgrade("slot_engine"))
	run.debug_skip_to_shift(run.shift_index)
	for index: int in range(6):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	assert_bool(run.can_place(run.debug_add_to_hand(load(BREAD)))).is_false()
	assert_int(_upgrade_multipliers(run.preview())).is_equal(1)
	assert_int(run.preview().payouts[4]).is_equal(5)
	assert_int(run.preview().payouts[5]).is_equal(10)
	run.upgrades.append(_upgrade("big_basket"))
	run.debug_skip_to_shift(run.shift_index)
	for index: int in range(7):
		assert_bool(run.place(run.debug_add_to_hand(load(BREAD)), index)).is_true()
	assert_int(_upgrade_multipliers(run.preview())).is_equal(1)
	assert_int(run.preview().payouts[5]).is_equal(10)
	assert_int(run.preview().payouts[6]).is_equal(5)


## Slot engine keeps to slot 6 whatever the shift's slots (2026-10-24): with none of them, with
## Big basket, on a Short belt shift and with both. Coupons count as cards, so a Repeat in the
## row moves no product onto it.
func test_slot_engine_keeps_to_slot_6() -> void:
	var engine: UpgradeDefinition = _upgrade("slot_engine")
	var basket: UpgradeDefinition = _upgrade("big_basket")
	var belt: Array[InspectionDefinition] = [_inspection("short_belt")]
	var none: Array[InspectionDefinition] = []
	var row: Array[CardInstance] = []
	for index: int in range(7):
		row.append(CardInstance.new(load(BREAD), index + 1))
	row.insert(2, CardInstance.new(load(REPEAT), 8))
	var cases: Array[Array] = [
		[[engine], none],
		[[engine, basket], none],
		[[engine], belt],
		[[engine, basket], belt],
	]
	for case: Array in cases:
		var upgrades: Array[UpgradeDefinition] = []
		upgrades.assign(case[0])
		var inspections: Array[InspectionDefinition] = []
		inspections.assign(case[1])
		var result: ScoreResult = Scoring.score(row, upgrades, inspections)
		var doubled: Array[int] = []
		for step: ScoreStep in result.steps:
			if (
				step.step_type == ScoreStep.StepType.MULTIPLIER
				and step.source_kind == ScoreStep.SourceKind.UPGRADE
			):
				doubled.append(step.slot)
		assert_array(doubled).override_failure_message(str(case)).is_equal([5])


## The shift's inspection reaches the run save: a resumed run gets the same closed slot.
func test_a_resumed_run_keeps_the_closed_slot() -> void:
	var run: RunState = _run(53, "short_belt")
	for index: int in range(6):
		run.place(run.debug_add_to_hand(load(BREAD)), index)
	var data: Dictionary = JSON.parse_string(
		JSON.stringify(RunSave.to_dictionary(run, "0011223344556677", 1000))
	)
	var restored: RunSave = RunSave.from_dictionary(data, ContentLookup.new(run.balance))
	assert_object(restored).is_not_null()
	assert_int(restored.run.limits.slot_count).is_equal(run.balance.slot_count - 1)
	assert_int(restored.run.limits.closed_slots).is_equal(1)
	assert_int(restored.run.row.size()).is_equal(6)


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
			MachineSteps.next_shift(run)
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
	# The run before v0.65's loop rework: shifts 3, 5 and 7 inspected, no Manager's reviews, and
	# a miss ends the run.
	balance.inspection_shifts = PackedInt32Array([3, 5, 7])
	balance.review_shifts = PackedInt32Array()
	balance.write_up_limit = 0
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
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
