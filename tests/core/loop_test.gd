extends GdUnitTestSuite
## The loop rework (v0.65, full build plan section 5.3): 12 shifts in 3 weeks of 4, each week's
## 3rd shift inspected and its 4th the Manager's review (several inspections at once), and
## write-ups: a missed quota the run goes on after, until the write_up_limit-th miss or a missed
## last shift ends it.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const BREAD := "res://data/cards/bread.tres"


## The live schedule: 12 shifts; shifts 3, 7 and 11 under one inspection, 4, 8 and 12 under two.
func test_the_live_weeks() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.quotas.size()).is_equal(12)
	var counts: Array[int] = []
	for shift_number: int in range(1, 13):
		counts.append(InspectionSchedule.count_for(balance, shift_number))
	assert_array(counts).is_equal([0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 2])
	for shift_number: int in [4, 8, 12]:
		assert_bool(InspectionSchedule.is_review_shift(balance, shift_number)).is_true()
	assert_bool(InspectionSchedule.is_review_shift(balance, 3)).is_false()
	# The final review asks the most.
	assert_int(balance.quotas[11]).is_equal(Array(balance.quotas).max())


## A review draws different inspections, the run's last ones left out while enough others remain;
## with a pool of 2 it gets both.
func test_a_review_draws_different_inspections() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var pool: Array[InspectionDefinition] = balance.inspection_pool
	for seed_value: int in range(20):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(rng, balance, 4)
		assert_int(drawn.size()).is_equal(2)
		assert_object(drawn[0]).is_not_same(drawn[1])
		assert_bool(pool.has(drawn[0]) and pool.has(drawn[1])).is_true()
	# A larger pool leaves the last inspections out.
	var wide: BalanceDefinition = balance.duplicate()
	var third: InspectionDefinition = pool[0].duplicate()
	third.id = &"third_check"
	var fourth: InspectionDefinition = pool[0].duplicate()
	fourth.id = &"fourth_check"
	var four: Array[InspectionDefinition] = [pool[0], pool[1], third, fourth]
	wide.inspection_pool = four
	var last: Array[InspectionDefinition] = [pool[0], pool[1]]
	for seed_value: int in range(20):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(rng, wide, 4, last)
		assert_array(drawn).contains_exactly_in_any_order([third, fourth])
	# Not inspected: nothing drawn, no RNG used.
	var unused: RandomNumberGenerator = RandomNumberGenerator.new()
	var state: int = unused.state
	assert_array(InspectionSchedule.draw_for(unused, balance, 1)).is_empty()
	assert_int(unused.state).is_equal(state)


## Through a run: shift 3's checkout announces the review's two inspections; shift 4 plays under
## both and its record keeps both.
func test_the_review_is_announced_and_played_under_both() -> void:
	var run: RunState = _run(11)
	for _shift: int in range(2):
		_pass(run)
		MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(2)
	assert_int(run.inspections.size()).is_equal(1)
	_pass(run)
	assert_int(run.next_inspections.size()).is_equal(2)
	MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(3)
	assert_int(run.inspections.size()).is_equal(2)
	assert_str(InspectionTag.next_notice(run.inspections)).starts_with("MANAGER'S REVIEW")
	_pass(run)
	assert_int(run.history[-1].inspections.size()).is_equal(2)
	assert_object(run.history[-1].inspection).is_same(run.history[-1].inspections[0])


## A write-up announces the next shift's inspection as a pass does, and gets no visit.
func test_a_write_up_announces_the_next_inspection() -> void:
	var run: RunState = _run(12)
	run.debug_skip_to_shift(1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_int(run.write_ups).is_equal(1)
	assert_int(run.next_inspections.size()).is_equal(1)
	assert_object(run.machine.current_visit()).is_null()
	assert_str(WriteUp.stamp_text(run)).is_equal("WRITE-UP 1/2")
	assert_bool(run.next_shift()).is_true()
	assert_int(run.inspections.size()).is_equal(1)


## A missed last shift ends the run, write-ups left or not.
func test_a_missed_last_shift_ends_the_run() -> void:
	var run: RunState = _run(13)
	run.debug_skip_to_shift(run.shift_count() - 1)
	run.checkout()
	assert_int(run.write_ups).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_str(WriteUp.stamp_text(run)).is_empty()


## A run with a write-up saves and resumes, at the next shift's planning and after the miss's
## checkout (SCORED); a history with as many misses as the limit can't be resumed.
func test_a_written_up_run_round_trips() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var run: RunState = _live_run(14)
	_pass(run)
	MachineSteps.next_shift(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	var scored: Dictionary = _json(RunSave.to_dictionary(run, "loop", 5))
	var at_scored: RunSave = RunSave.from_dictionary(scored, lookup)
	assert_object(at_scored).is_not_null()
	assert_int(at_scored.run.write_ups).is_equal(1)
	run.next_shift()
	var planning: Dictionary = _json(RunSave.to_dictionary(run, "loop", 6))
	var at_planning: RunSave = RunSave.from_dictionary(planning, lookup)
	assert_object(at_planning).is_not_null()
	assert_int(at_planning.run.write_ups).is_equal(1)
	assert_int(at_planning.run.shift_index).is_equal(2)
	# Two misses in the history: the run was over.
	var fired: Dictionary = planning.duplicate(true)
	fired["history"][0]["total"] = 0
	fired["history"][0]["passed"] = false
	assert_object(RunSave.from_dictionary(fired, lookup)).is_null()


## A format 7 save (before v0.65) names one next inspection and one per record: it reads into the
## 12-shift run as it is.
func test_a_format_7_save_reads_its_single_inspections() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var run: RunState = _live_run(15)
	_pass(run)
	MachineSteps.next_shift(run)
	_pass(run)
	assert_object(run.next_inspection).is_not_null()
	var data: Dictionary = _json(RunSave.to_dictionary(run, "old", 7))
	data["format_version"] = RunSave.BEFORE_LOOP_VERSION
	data["next_inspection"] = String(run.next_inspection.id)
	data.erase("next_inspections")
	for record: Dictionary in data["history"]:
		record.erase("inspections")
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.next_inspections).is_equal(run.next_inspections)
	assert_int(save.run.history.size()).is_equal(run.history.size())


## The live balance with every quota at 5, so two Breads pass any shift.
func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(balance.quotas.size())
	quotas.fill(5)
	balance.quotas = quotas
	var run: RunState = RunState.new(seed_value, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	return run


## The live balance itself (its quotas too), for the save, which reads it back.
func _live_run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(seed_value, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	return run


## Passes the shift with enough Breads for its quota.
static func _pass(run: RunState) -> void:
	while Scoring.score(run.row, run.upgrades, run.inspections).total < run.quota():
		if not run.place(run.debug_add_to_hand(load(BREAD)), run.row.size()):
			break
	run.checkout()


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
