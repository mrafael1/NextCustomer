extends GdUnitTestSuite
## The week events (v0.70, plan section 3.9): a run of 12 shifts is 3 weeks of 4 (WeekSchedule),
## each with its fixed week event from the shift number (Training week, Bakery festival, Holiday
## rush). A week's day events are all drawn as its first shift starts (the time card shows them),
## with the run's RNG, and every later day of the week plays them; the week event stacks with the
## day's own events (the quota percents add up, Bakery festival's +€2 is an engine step of its own,
## Holiday rush raises the machine's odds a level), and the run save keeps the week at every save
## point, a save from before the weeks getting its week built as it loads.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const BREAD := "res://data/cards/bread.tres"
const BANANA := "res://data/cards/banana.tres"
const DAY := "res://data/inspections/%s.tres"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	# Quotas of 1: every row with a product passes, so a scripted run plays all its weeks.
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	var quotas: PackedInt32Array = PackedInt32Array()
	for _shift: int in range(_balance.quotas.size()):
		quotas.append(1)
	_balance.quotas = quotas
	_lookup = ContentLookup.new(_balance)


## Shifts 1-4 are week 1 (Training week), 5-8 week 2 (Bakery festival), 9-12 week 3 (Holiday
## rush); a week starts on shifts 1, 5 and 9.
func test_the_weeks_follow_the_shift_number() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(WeekSchedule.week_count(balance)).is_equal(3)
	var names: Array[String] = ["training_week", "bakery_festival", "holiday_rush"]
	for shift: int in range(1, 13):
		var week: int = floori((shift - 1) / 4.0)
		assert_int(WeekSchedule.week_of(balance, shift)).is_equal(week)
		assert_int(WeekSchedule.first_shift(balance, shift)).is_equal(week * 4 + 1)
		assert_bool(WeekSchedule.is_week_start(balance, shift)).is_equal((shift - 1) % 4 == 0)
		assert_int(WeekSchedule.days_in(balance, shift)).is_equal(4)
		assert_str(String(WeekSchedule.event_for(balance, shift).id)).is_equal(names[week])


## The week's 4 days are drawn as its first shift starts: each later day plays the events the
## week drew (announced after the checkout before it, never past the week's end), the review
## day holds its 2 inspections and the boon days their boon. The next week is drawn as it starts.
func test_the_week_is_drawn_when_it_starts() -> void:
	var run: RunState = _new_run(7)
	assert_object(run.week).is_null()
	run.start_shift()
	for week_start: int in [1, 5, 9]:
		assert_int(run.shift_index + 1).is_equal(week_start)
		var plan: WeekPlan = run.week
		assert_int(plan.first_shift).is_equal(week_start)
		assert_int(plan.days.size()).is_equal(4)
		for day: int in range(week_start, week_start + 4):
			var events: Array[InspectionDefinition] = plan.day(day)
			var maluses: int = InspectionDefinition.maluses(events).size()
			assert_int(maluses).is_equal(InspectionSchedule.count_for(_balance, day))
			var boons: int = InspectionDefinition.boons(events).size()
			assert_int(boons).is_equal(InspectionSchedule.boon_count_for(_balance, day))
		for day: int in range(week_start, week_start + 4):
			assert_object(run.week).is_same(plan)
			assert_array(run.inspections).is_equal(plan.day(day))
			_fill(run)
			run.checkout()
			if day == run.shift_count():
				assert_int(run.phase).is_equal(RunState.Phase.WON)
				return
			var next: Array[InspectionDefinition] = plan.day(day + 1)
			assert_array(run.next_inspections).is_equal(next)  # Empty after the week's last day.
			assert_bool(MachineSteps.next_shift(run)).is_true()


## The same seed draws the same weeks.
func test_the_weeks_are_drawn_with_the_run_rng() -> void:
	var first: Array[String] = _weeks_of(_play_through(31))
	assert_array(first).is_equal(_weeks_of(_play_through(31)))
	assert_int(first.size()).is_equal(3)


## The week event stacks with the day's events: Rush hour's +10% and Bakery festival's +10% make
## shift 5's quota +20%, Holiday rush's +15% shift 9's, and Training week changes nothing.
func test_the_week_quota_stacks_with_the_day_events() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var none: Array[UpgradeDefinition] = []
	var rush: Array[InspectionDefinition] = [load(DAY % "rush_hour")]
	var cases: Dictionary = {1: 10, 5: 20, 9: 25}
	for shift: int in cases:
		var events: Array[InspectionDefinition] = WeekSchedule.events_for(balance, shift, rush)
		var limits: ShiftLimits = ShiftLimits.for_shift(balance, none, shift - 1, events)
		var quota: int = ShiftLimits.with_percent(balance.quotas[shift - 1], cases[shift])
		assert_int(limits.quota).override_failure_message(str(shift)).is_equal(quota)
	# The run plays its shift under both.
	var run: RunState = _new_run(3)
	run.start_shift()
	run.debug_skip_to_shift(4)
	run.inspections = rush
	run.start_shift()
	assert_int(run.limits.quota).is_equal(ShiftLimits.with_percent(_balance.quotas[4], 20))


## Bakery festival's +€2 on each Bakery item is an engine step of its own (source INSPECTION,
## indexed after the day's events: the count-up plays it from the week chip), on top of a day
## event's own step (Fresh delivery's +€1 on a Fruit & veg item).
func test_the_bakery_festival_pays_an_engine_step() -> void:
	var run: RunState = _new_run(5)
	run.start_shift()
	run.debug_skip_to_shift(4)
	run.inspections = [load(DAY % "fresh_delivery")]
	run.start_shift()
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	run.place(run.debug_add_to_hand(load(BANANA)), 1)
	var result: ScoreResult = run.preview()
	var plain: ScoreResult = Scoring.score(run.row)
	assert_int(result.total).is_equal(plain.total + 2 + 1)
	var sources: Array = []
	for step: ScoreStep in result.steps:
		if step.source_kind == ScoreStep.SourceKind.INSPECTION:
			sources.append([step.source_index, step.value])
	assert_array(sources).contains_exactly_in_any_order([[0, 1], [1, 2]])
	assert_object(WeekSchedule.shift_events(run)[1]).is_same(_balance.weeks[1])
	# Week 1's shifts pay nothing more.
	run.debug_skip_to_shift(0)
	run.inspections = []
	run.start_shift()
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	assert_int(run.preview().total).is_equal(Scoring.score(run.row).total)


## Holiday rush raises the visits' odds level after its shifts by one (the machine's top level
## included: the visits after shifts 9-11 draw at level 4), and the chute info says so.
func test_holiday_rush_raises_the_machine_odds() -> void:
	var machine: MachineDefinition = _balance.machine
	assert_int(WeekSchedule.odds_delta(_balance, 0)).is_equal(0)
	assert_int(WeekSchedule.odds_delta(_balance, 8)).is_equal(0)
	for shift: int in [9, 10, 11, 12]:
		assert_int(WeekSchedule.odds_delta(_balance, shift)).is_equal(1)
	for shift: int in [8, 9]:
		var run: RunState = _new_run(9)
		run.start_shift()
		run.debug_skip_to_shift(shift - 1)
		_fill(run)
		run.checkout()
		assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
		var delta: int = 1 if shift == 9 else 0
		var level: int = machine.odds_level_after(shift) + delta
		assert_int(run.machine.odds_level(run)).is_equal(level)
		var info: MachineChuteInfo = run.machine.chute_info(run, RewardMachine.Chute.NEW_ITEMS)
		assert_int(info.week_odds).is_equal(delta)
	assert_int(machine.odds_level_after(9) + 1).is_less_equal(machine.max_level())


## The run save keeps the week at every save point (planning, the machine's choice and pick,
## scored): a run restored at each plays on exactly like one that never stopped, and every save
## point was met.
func test_the_week_round_trips_at_every_save_point() -> void:
	var met: Dictionary[int, bool] = {}
	var straight: Array[String] = _play(13, false, met)
	var resumed: Array[String] = _play(13, true, met)
	assert_array(resumed).is_equal(straight)
	for phase: RunState.Phase in [
		RunState.Phase.PLANNING,
		RunState.Phase.MACHINE_CHOOSE,
		RunState.Phase.MACHINE_PICK,
		RunState.Phase.SCORED,
	]:
		assert_bool(met.has(phase)).override_failure_message(str(phase)).is_true()


## A save whose week doesn't hold its shift, or whose current day isn't the week's, can't be
## resumed; one without a week (before the first shift's start) only in CHOOSE_START.
func test_a_save_with_a_wrong_week_reads_as_null() -> void:
	var run: RunState = _new_run(17)
	run.start_shift()
	_fill(run)
	run.checkout()
	MachineSteps.next_shift(run)
	var saved: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	assert_object(RunSave.from_dictionary(saved.duplicate(true), _lookup)).is_not_null()
	var moved: Dictionary = saved.duplicate(true)
	moved["week"]["first_shift"] = 5
	assert_object(RunSave.from_dictionary(moved, _lookup)).is_null()
	var short: Dictionary = saved.duplicate(true)
	(short["week"]["days"] as Array).pop_back()
	assert_object(RunSave.from_dictionary(short, _lookup)).is_null()
	var none: Dictionary = saved.duplicate(true)
	none["week"] = {}
	assert_object(RunSave.from_dictionary(none, _lookup)).is_null()


## A version 9 save (before the weeks) taken at shift 2's machine gets its week as it loads: shift
## 1 from its history, shift 2 its own events, shift 3 those it announced, shift 4 drawn with the
## run's RNG; it plays on into the announced shift.
func test_a_save_from_before_the_weeks_gets_its_week() -> void:
	var run: RunState = _new_run(21)
	run.start_shift()
	for _shift: int in range(2):
		_fill(run)
		run.checkout()
		if run.shift_index == 0:
			MachineSteps.next_shift(run)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var announced: Array[InspectionDefinition] = run.next_inspections
	var saved: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	saved["format_version"] = RunSave.BEFORE_WEEKS_VERSION
	saved.erase("week")
	saved.erase("pre_week_shift")
	saved["next_inspections"] = Array(RunEvents.inspection_ids(announced))
	var older: RunSave = RunSave.from_dictionary(saved, _lookup)
	assert_object(older).is_not_null()
	var restored: RunState = older.run
	assert_int(restored.pre_week_shift).is_equal(2)
	assert_int(restored.week.first_shift).is_equal(1)
	assert_array(restored.week.day(1)).is_equal(run.history[0].inspections)
	assert_array(restored.week.day(2)).is_equal(run.inspections)
	assert_array(restored.next_inspections).is_equal(announced)
	assert_int(restored.week.days.size()).is_equal(4)
	assert_bool(MachineSteps.next_shift(restored)).is_true()
	assert_array(restored.inspections).is_equal(announced)


## A version 9 save taken at shift 4's machine (the week's last day) keeps the shift-5 events
## its receipt announced: week 2 is planned as it loads, its first day those events, and a
## version 10 save of it reads back the same; shift 5 plays them.
func test_a_save_from_before_the_weeks_at_a_week_end_keeps_the_announced_events() -> void:
	var run: RunState = _new_run(23)
	run.start_shift()
	for _shift: int in range(4):
		_fill(run)
		run.checkout()
		if run.shift_index < 3:
			MachineSteps.next_shift(run)
	assert_int(run.shift_index).is_equal(3)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var announced: Array[InspectionDefinition] = [load(DAY % "quiet_morning")]
	var saved: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	saved["format_version"] = RunSave.BEFORE_WEEKS_VERSION
	saved.erase("week")
	saved.erase("pre_week_shift")
	saved["next_inspections"] = Array(RunEvents.inspection_ids(announced))
	var older: RunSave = RunSave.from_dictionary(saved, _lookup)
	assert_object(older).is_not_null()
	var restored: RunState = older.run
	assert_int(restored.week.first_shift).is_equal(5)
	assert_int(restored.week.days.size()).is_equal(4)
	assert_array(restored.next_inspections).is_equal(announced)
	# Saved again (version 10) between the weeks, it reads back the same.
	var again: Dictionary = _json(RunSave.to_dictionary(restored, "id", 0))
	var newer: RunSave = RunSave.from_dictionary(again, _lookup)
	assert_object(newer).is_not_null()
	assert_array(newer.run.next_inspections).is_equal(announced)
	assert_str(_week_text(newer.run.week)).is_equal(_week_text(restored.week))
	var plan: WeekPlan = restored.week
	assert_bool(MachineSteps.next_shift(restored)).is_true()
	assert_object(restored.week).is_same(plan)
	assert_array(restored.inspections).is_equal(announced)


## A version 9 save in planning on shift 5 (Bakery festival) keeps playing that shift without its
## week event: no +10% quota, no +€2 on Bread, and the time card and week chip don't name it.
func test_a_save_from_before_the_weeks_plays_its_shift_without_the_week_event() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var lookup: ContentLookup = ContentLookup.new(balance)
	var run: RunState = RunState.new(25, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(4)
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	var day_events: Array[InspectionDefinition] = run.inspections.duplicate()
	var none: Array[UpgradeDefinition] = []
	var day_quota: int = ShiftLimits.for_shift(balance, none, 4, day_events).quota
	assert_int(run.quota()).is_greater(day_quota)
	var saved: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	saved["format_version"] = RunSave.BEFORE_WEEKS_VERSION
	saved.erase("week")
	saved.erase("pre_week_shift")
	saved["next_inspections"] = []
	var older: RunSave = RunSave.from_dictionary(saved, lookup)
	assert_object(older).is_not_null()
	var restored: RunState = older.run
	assert_int(restored.pre_week_shift).is_equal(5)
	assert_int(restored.quota()).is_equal(day_quota)
	var plain: int = Scoring.score(restored.row, restored.upgrades, day_events).total
	assert_int(restored.preview().total).is_equal(plain)
	assert_int(restored.preview().total).is_less(run.preview().total)
	var model: WeekCardModel = WeekCardModel.of(restored)
	assert_object(model.event).is_null()
	assert_str(model.title()).is_equal("WEEK 2")
	assert_str(model.effect()).is_equal("")
	assert_str(model.chip_name()).is_equal("")
	# The run's own card names it.
	assert_str(WeekCardModel.of(run).chip_name()).is_not_empty()


func _new_run(seed_value: int) -> RunState:
	return RunState.new(seed_value, load(STARTER), _balance, RunStock.starting(_balance))


## Plays a whole run (every shift filled, every visit passed); the run at its end.
func _play_through(seed_value: int) -> Array[WeekPlan]:
	var weeks: Array[WeekPlan] = []
	var run: RunState = _new_run(seed_value)
	run.start_shift()
	while run.phase == RunState.Phase.PLANNING:
		if not weeks.has(run.week):
			weeks.append(run.week)
		_fill(run)
		run.checkout()
		MachineSteps.next_shift(run)
	return weeks


static func _weeks_of(weeks: Array[WeekPlan]) -> Array[String]:
	var found: Array[String] = []
	for plan: WeekPlan in weeks:
		found.append(_week_text(plan))
	return found


static func _week_text(plan: WeekPlan) -> String:
	if plan == null:
		return "none"
	var days: Array = []
	for day: Array in plan.days:
		var events: Array[InspectionDefinition] = []
		events.assign(day)
		days.append(RunEvents.inspection_ids(events))
	return "%d:%s" % [plan.first_shift, str(days)]


## Plays shifts 1-6 (every hand filled, the visits' first prizes taken), observing the run after
## each action; with `resume`, restored from its saved form at every save point (`met` collects
## them).
func _play(seed_value: int, resume: bool, met: Dictionary[int, bool]) -> Array[String]:
	var steps: Array[String] = []
	var run: RunState = _new_run(seed_value)
	run.start_shift()
	run = _checkpoint(run, resume, steps, met)
	while run.phase == RunState.Phase.PLANNING and run.shift_index < 6:
		_fill(run)
		run = _checkpoint(run, resume, steps, met)
		run.checkout()
		run = _checkpoint(run, resume, steps, met)
		while RunState.MACHINE_PHASES.has(run.phase):
			if run.phase == RunState.Phase.MACHINE_CHOOSE:
				MachineSteps.choose(run, MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS))
			else:
				MachineSteps.take(run, 0)
			run = _checkpoint(run, resume, steps, met)
		run.next_shift()
		run = _checkpoint(run, resume, steps, met)
	return steps


func _checkpoint(
	run: RunState, resume: bool, steps: Array[String], met: Dictionary[int, bool]
) -> RunState:
	steps.append(_observe(run))
	if not resume or not RunSave.is_save_point(run.phase):
		return run
	met[run.phase] = true
	var save: RunSave = RunSave.from_dictionary(_json(RunSave.to_dictionary(run, "id", 0)), _lookup)
	assert_object(save).override_failure_message(_observe(run)).is_not_null()
	return save.run if save != null else run


static func _observe(run: RunState) -> String:
	var state: Dictionary = {
		"phase": run.phase,
		"shift": run.shift_index,
		"quota": run.quota(),
		"week": _week_text(run.week),
		"inspections": RunEvents.inspection_ids(run.inspections),
		"next": RunEvents.inspection_ids(run.next_inspections),
		"events": RunEvents.inspection_ids(WeekSchedule.shift_events(run)),
		"preview": run.preview().total,
		"history": run.history.size(),
		"rng": str(run.rng_state),
	}
	return JSON.stringify(state)


func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
