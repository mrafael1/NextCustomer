extends GdUnitTestSuite
## The loop rework (v0.65, full build plan section 5.3): 12 shifts in 3 weeks of 4, each week's
## 3rd shift inspected and its 4th the Manager's review (several inspections at once); v0.68's
## Payday (a passed review pays two PREMIUM tickets, an inspection only the ticket) and training
## week (a miss on shifts 1-4 is a slip the run forgives, at most 2; any other miss ends the run),
## and the review fixes (both of a review's inspections everywhere, legacy saves).

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


## A slip announces the next shift's inspection as a pass does, and gets no visit.
func test_a_slip_announces_the_next_inspection() -> void:
	var run: RunState = _run(12)
	run.debug_skip_to_shift(1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_int(run.write_ups).is_equal(1)
	assert_int(run.next_inspections.size()).is_equal(1)
	assert_object(run.machine.current_visit()).is_null()
	assert_str(WriteUp.stamp_text(run)).is_equal("SLIP 1/2")
	assert_bool(run.next_shift()).is_true()
	assert_int(run.inspections.size()).is_equal(1)
	assert_str(WriteUp.shift_notice(run)).is_equal("Slip 1/2 — training week")


## The training week: misses on shifts 1-4 are slips, at most 2 (the 2nd's notice warns); the 3rd
## miss ends the run. The hint counts the slips left, and is gone after shift 4.
func test_the_training_week_forgives_two_slips() -> void:
	var run: RunState = _run(16)
	assert_str(WriteUp.hint_text(run)).is_equal("TRAINING WEEK · 2 SLIPS")
	assert_bool(TrainingWeek.forgives_miss(run)).is_true()
	run.checkout()
	run.next_shift()
	assert_str(WriteUp.hint_text(run)).is_equal("TRAINING WEEK · 1 SLIP")
	run.checkout()
	assert_str(WriteUp.stamp_text(run)).is_equal("SLIP 2/2")
	run.next_shift()
	assert_str(WriteUp.shift_notice(run)).contains("the next miss ends the run")
	assert_str(WriteUp.hint_text(run)).is_equal("TRAINING WEEK · 0 SLIPS")
	assert_bool(TrainingWeek.forgives_miss(run)).is_false()
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_str(WriteUp.stamp_text(run)).is_empty()
	# Shift 4 is the training week's last: a miss there is a slip, a miss on shift 5 ends the run.
	var late: RunState = _run(17)
	late.debug_skip_to_shift(3)
	assert_bool(TrainingWeek.covers(late.balance, 4)).is_true()
	late.checkout()
	assert_int(late.phase).is_equal(RunState.Phase.SCORED)
	late.next_shift()
	assert_str(WriteUp.hint_text(late)).is_empty()
	assert_bool(TrainingWeek.just_ended(late)).is_true()
	assert_str(WriteUp.shift_notice(late)).is_equal(WriteUp.OVER_NOTICE)
	assert_int(TrainingWeek.slips_left(late)).is_equal(0)
	late.checkout()
	assert_int(late.phase).is_equal(RunState.Phase.LOST)


## Shift 5 opens with "Training is over" after a clean week; other shifts open with no notice.
func test_training_is_over_on_shift_5() -> void:
	var run: RunState = _run(18)
	var notices: Array[String] = []
	for _shift: int in range(5):
		notices.append(WriteUp.shift_notice(run))
		_pass(run)
		MachineSteps.next_shift(run)
	assert_array(notices).is_equal(["", "", "", "", WriteUp.OVER_NOTICE])
	assert_str(WriteUp.shift_notice(run)).is_empty()


## A missed last shift ends the run, slips left or not.
func test_a_missed_last_shift_ends_the_run() -> void:
	var run: RunState = _run(13)
	run.debug_skip_to_shift(run.shift_count() - 1)
	run.checkout()
	assert_int(run.write_ups).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_str(WriteUp.stamp_text(run)).is_empty()


## Payday: a passed inspection shift (3) gets only its ticket; a passed review (4) two PREMIUM
## visits, the BONUS one naming both inspections; a missed review none.
func test_a_passed_review_pays_two_premium_tickets() -> void:
	var run: RunState = _run(19)
	for _shift: int in range(2):
		_pass(run)
		MachineSteps.next_shift(run)
	assert_bool(Payday.if_passed(run)).is_false()
	_pass(run)
	assert_object(run.machine.current_visit()).is_not_null()
	assert_bool(run.machine.is_premium()).is_false()
	assert_array(run.machine.pending_kinds()).is_empty()
	assert_bool(run.machine.is_payday(run)).is_false()
	MachineSteps.next_shift(run)
	assert_bool(Payday.if_passed(run)).is_true()
	_pass(run)
	assert_bool(run.machine.is_premium()).is_true()
	assert_bool(run.machine.is_payday(run)).is_true()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.BONUS])
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	var bonus: MachineVisit = run.machine.current_visit()
	assert_int(bonus.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(bonus.premium).is_true()
	assert_bool(run.machine.is_payday(run)).is_true()
	var ids: Array = RunEvents.inspection_ids(run.history[-1].inspections)
	assert_int(ids.size()).is_equal(2)
	assert_str(bonus.why).is_equal(",".join(ids))
	# A missed review pays nothing.
	var missed: RunState = _run(20)
	missed.debug_skip_to_shift(3)
	missed.checkout()
	assert_object(missed.machine.current_visit()).is_null()
	assert_array(missed.machine.pending_kinds()).is_empty()


## After a review, a single inspection leaves out both of the review's (no back-to-back repeat):
## with a pool of 3, shift 7's is the third one.
func test_a_single_draw_after_a_review_leaves_both_out() -> void:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	var pool: Array[InspectionDefinition] = balance.inspection_pool
	var third: InspectionDefinition = pool[0].duplicate()
	third.id = &"third_check"
	var three: Array[InspectionDefinition] = [pool[0], pool[1], third]
	balance.inspection_pool = three
	var review: Array[InspectionDefinition] = [pool[1], pool[0]]
	for seed_value: int in range(20):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(
			rng, balance, 7, review
		)
		assert_array(drawn).is_equal([third])
	# One previous inspection: the same draw as draw() makes, from the same RNG.
	for seed_value: int in range(20):
		var a: RandomNumberGenerator = RandomNumberGenerator.new()
		a.seed = seed_value
		var b: RandomNumberGenerator = RandomNumberGenerator.new()
		b.seed = seed_value
		var last: Array[InspectionDefinition] = [pool[0]]
		var drawn: Array[InspectionDefinition] = InspectionSchedule.draw_for(a, balance, 7, last)
		assert_array(drawn).is_equal([InspectionSchedule.draw(b, balance, pool[0])])
		assert_int(a.state).is_equal(b.state)


## PrizeWin rescores a review's row with both of its inspections, as the checkout scored it.
func test_prize_win_rescores_a_review_with_both() -> void:
	var run: RunState = _run(21)
	run.debug_skip_to_shift(3)
	_pass(run)
	var record: ShiftRecord = run.history[-1]
	assert_int(record.inspections.size()).is_equal(2)
	assert_array(PrizeWin._checks(record)).is_equal(record.inspections)


## A run with a slip saves and resumes, at the next shift's planning and after the miss's
## checkout (SCORED); a history with more misses than the limit can't be resumed.
func test_a_slipped_run_round_trips() -> void:
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
	# Two misses in the history: the limit, still going.
	var two: Dictionary = planning.duplicate(true)
	two["history"][0]["total"] = 0
	two["history"][0]["passed"] = false
	assert_object(RunSave.from_dictionary(two, lookup)).is_not_null()
	# Three: the run was over.
	run.checkout()
	var three: Dictionary = _json(RunSave.to_dictionary(run, "loop", 7))
	three["history"][0]["total"] = 0
	three["history"][0]["passed"] = false
	assert_object(RunSave.from_dictionary(three, lookup)).is_null()


## A format 7 save (before v0.65) names one next inspection and one per record: it reads into the
## 12-shift run, its next shift's inspections by today's schedule.
func test_a_format_7_save_reads_its_single_inspections() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var run: RunState = _live_run(15)
	_pass(run)
	MachineSteps.next_shift(run)
	_pass(run)
	assert_object(run.next_inspection).is_not_null()
	var data: Dictionary = _old_save(run)
	data["next_inspection"] = String(run.next_inspection.id)
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.next_inspections).is_equal(run.next_inspections)
	assert_int(save.run.history.size()).is_equal(run.history.size())


## A format 7 save at a PREMIUM visit after old premium shift 3 resumes (its premium flag kept),
## and, saved after shift 3 with no next inspection (old shift 4 had none), draws the review's two.
## Today's save in the same state is refused.
func test_a_format_7_save_at_an_old_premium_visit_resumes() -> void:
	var run: RunState = _run(22)
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	for _shift: int in range(2):
		_pass(run)
		MachineSteps.next_shift(run)
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var data: Dictionary = _old_save(run)
	data["machine"]["visit"]["premium"] = true
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	assert_bool(save.run.machine.is_premium()).is_true()
	assert_int(save.run.next_inspections.size()).is_equal(2)
	var today: Dictionary = _json(RunSave.to_dictionary(run, "now", 9))
	today["machine"]["visit"]["premium"] = true
	assert_object(RunSave.from_dictionary(today, lookup)).is_null()


## A format 7 save at the PREMIUM ticket of old premium shift 3 with its BONUS visit queued (shift
## 3 was inspected then): the BONUS visit is PREMIUM too, by the save's rules, and a save taken
## during it (today's format) resumes.
func test_a_format_7_save_carries_its_premium_to_the_bonus_visit() -> void:
	var run: RunState = _run(23)
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	for _shift: int in range(2):
		_pass(run)
		MachineSteps.next_shift(run)
	_pass(run)
	var data: Dictionary = _old_save(run)
	data["machine"]["visit"]["premium"] = true
	data["machine"]["queue"] = ["bonus"]
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	var resumed: RunState = save.run
	MachineSteps.choose(resumed, RewardMachine.Chute.NEW_ITEMS)
	assert_object(MachineSteps.take(resumed, 0)).is_not_null()
	var bonus: MachineVisit = resumed.machine.current_visit()
	assert_int(bonus.kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(bonus.premium).is_true()
	var again: Dictionary = _json(RunSave.to_dictionary(resumed, "again", 10))
	var later: RunSave = RunSave.from_dictionary(again, lookup)
	assert_object(later).is_not_null()
	assert_bool(later.run.machine.is_premium()).is_true()
	# The next checkout follows today's premium shifts again.
	MachineSteps.choose(later.run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(later.run, 0)
	assert_bool(later.run.machine.keeps_legacy_premium).is_true()
	MachineSteps.next_shift(later.run)
	_pass(later.run)
	assert_bool(later.run.machine.keeps_legacy_premium).is_false()
	assert_bool(later.run.machine.is_premium()).is_true()


## A format 7 save in planning on shift 4 (uninspected then) draws today's review's two
## inspections for it, and the shift's limits follow them.
func test_a_format_7_save_in_planning_draws_the_review() -> void:
	var run: RunState = _run(24)
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	for _shift: int in range(3):
		_pass(run)
		MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(3)
	var data: Dictionary = _old_save(run)
	data["inspections"] = []
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	assert_int(save.run.inspections.size()).is_equal(2)
	var limits: ShiftLimits = ShiftLimits.for_shift(
		save.run.balance, save.run.upgrades, 3, save.run.inspections
	)
	assert_int(save.run.limits.slot_count).is_equal(limits.slot_count)
	assert_int(save.run.limits.closed_slots).is_equal(limits.closed_slots)
	assert_int(save.run.limits.quota).is_equal(limits.quota)
	# Saved with today's count: kept as it is.
	var kept: RunSave = RunSave.from_dictionary(_old_save(run), lookup)
	assert_array(kept.run.inspections).is_equal(run.inspections)


## A format 7 form of `run`'s save: no next inspection, one inspection per record.
static func _old_save(run: RunState) -> Dictionary:
	var data: Dictionary = _json(RunSave.to_dictionary(run, "old", 7))
	data["format_version"] = RunSave.BEFORE_LOOP_VERSION
	data["next_inspection"] = ""
	data.erase("next_inspections")
	for record: Dictionary in data["history"]:
		var ids: Array = record["inspections"]
		record.erase("inspections")
		record["inspection"] = ids[0] if not ids.is_empty() else ""
	return data


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
