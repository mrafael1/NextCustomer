extends GdUnitTestSuite
## The week 1 strip's rules (RevealList, RevealRule, data/tutorial/reveals.tres; v1.40): the data
## names known elements and triggers; a guided run's first week hides every element until one of
## its rules holds (its trigger, or its shift's planning), then keeps it; any other run, and a
## guided run from week 2 on, shows everything; the run's standing triggers (a resume) and a
## PROJECTED hook's quota and medal triggers are read from the run.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"


func test_the_data_names_known_elements_and_triggers() -> void:
	var list: RevealList = RevealList.shared()
	assert_object(list).is_not_null()
	assert_array(list.elements()).contains_exactly_in_any_order(RevealList.ELEMENTS)
	for rule: RevealRule in list.rules:
		assert_bool(TutorialAnchors.is_known(rule.element)).is_true()
		assert_bool(rule.at_shift > 0 or not rule.events.is_empty()).is_true()
		assert_int(rule.events_from_shift).is_greater_equal(1)
		for event: StringName in rule.events:
			var known: bool = TutorialEvents.is_event(event) or RevealList.OWN_TRIGGERS.has(event)
			assert_bool(known).override_failure_message(String(event)).is_true()


## A run that isn't guided is never stripped: every element shows and nothing is due.
func test_a_normal_run_shows_everything() -> void:
	var list: RevealList = RevealList.shared()
	var run: RunState = _run(false)
	assert_bool(RevealList.stripped(run)).is_false()
	assert_bool(RevealList.stripped(null)).is_false()
	for element: StringName in RevealList.ELEMENTS:
		assert_bool(list.shows(run, element)).is_true()
	assert_array(list.due(run, [TutorialEvents.MACHINE_ARMED], 2)).is_empty()


## A guided run's shift 1: everything hidden; each trigger reveals its element only.
func test_shift_one_hides_until_a_trigger() -> void:
	var list: RevealList = RevealList.shared()
	var run: RunState = _run(true)
	assert_bool(RevealList.stripped(run)).is_true()
	for element: StringName in RevealList.ELEMENTS:
		assert_bool(list.shows(run, element)).override_failure_message(element).is_false()
	assert_bool(list.shows(run, TutorialAnchors.CHECKOUT)).is_true()  # No rule names it.
	assert_array(list.due(run)).is_empty()
	assert_array(list.due(run, [TutorialEvents.MACHINE_ARMED])).is_equal([RevealList.CART])
	assert_array(list.due(run, [RevealList.SHIFT_PASSED])).is_equal([RevealList.CALENDAR])
	assert_array(list.due(run, [RevealList.DAY_EVENT])).is_equal([RevealList.CALENDAR])
	assert_array(list.due(run, [TutorialEvents.PERK_TAKEN])).is_equal([RevealList.LOYALTY])
	assert_array(list.due(run, [RevealList.MEDAL_REACHED])).is_equal([RevealList.MEDALS])
	# Reaching the quota is shift 1's whole goal: the medal case waits for shift 2 to count it.
	assert_array(list.due(run, [RevealList.QUOTA_REACHED])).is_empty()
	assert_array(list.due(run, [TutorialEvents.CARD_PLACED, TutorialEvents.MISS])).is_empty()


## Shift 2's planning reveals the calendar, the Cart button, REDRAW and the week glass by itself,
## once it takes input (`planned`), never under the glide back from the machine; a revealed
## element stays shown and is not due again.
func test_shift_two_reveals_by_itself() -> void:
	var list: RevealList = RevealList.shared()
	var run: RunState = _run(true)
	run.shift_index = 1
	var by_shift: Array[StringName] = [
		RevealList.CALENDAR, RevealList.CART, RevealList.REDRAW, RevealList.WEEK
	]
	assert_array(list.due(run, [], 1)).is_empty()  # Shift 1 was the last planning: not yet.
	assert_array(list.due(run, [], 2)).is_equal(by_shift)
	assert_array(list.due(run)).is_equal(by_shift)  # No `planned`: the run's shift.
	assert_array(list.due(run, [RevealList.QUOTA_REACHED], 1)).is_equal([RevealList.MEDALS])
	run.guide_reveals.append(RevealList.CART)
	assert_bool(list.shows(run, RevealList.CART)).is_true()
	assert_bool(list.shows(run, RevealList.REDRAW)).is_false()
	assert_array(list.due(run, [TutorialEvents.MACHINE_ARMED], 2)).not_contains([RevealList.CART])


## From week 2 on the run is no longer stripped: everything shows, whatever was revealed.
func test_week_two_shows_everything() -> void:
	var list: RevealList = RevealList.shared()
	var run: RunState = _run(true)
	run.shift_index = WeekSchedule.length(run.balance) - 1
	assert_bool(RevealList.stripped(run)).is_true()
	run.shift_index = WeekSchedule.length(run.balance)
	assert_bool(RevealList.stripped(run)).is_false()
	for element: StringName in RevealList.ELEMENTS:
		assert_bool(list.shows(run, element)).is_true()
	assert_array(list.due(run, [TutorialEvents.PERK_TAKEN])).is_empty()


## The triggers a hook stands for: itself, the run's standing ones (a passed shift, a perk owned)
## and a PROJECTED hook's quota and first medal totals.
func test_the_triggers_are_read_from_the_run() -> void:
	var run: RunState = _run(true)
	assert_array(RevealList.standing(run)).is_empty()
	var quota: int = run.quota()
	var medal: int = RevealList.medal_total(run, quota)
	assert_int(medal).is_equal(quota * run.balance.machine.overtime_ticket_laps)
	var under: Dictionary = {TutorialEvents.ARG_TOTAL: quota - 1, TutorialEvents.ARG_QUOTA: quota}
	assert_array(RevealList.triggers(TutorialEvents.PROJECTED, under, run)).is_equal(
		[TutorialEvents.PROJECTED]
	)
	var met: Dictionary = {TutorialEvents.ARG_TOTAL: quota, TutorialEvents.ARG_QUOTA: quota}
	assert_array(RevealList.triggers(TutorialEvents.PROJECTED, met, run)).is_equal(
		[TutorialEvents.PROJECTED, RevealList.QUOTA_REACHED]
	)
	var over: Dictionary = {TutorialEvents.ARG_TOTAL: medal, TutorialEvents.ARG_QUOTA: quota}
	assert_array(RevealList.triggers(TutorialEvents.PROJECTED, over, run)).contains(
		[RevealList.QUOTA_REACHED, RevealList.MEDAL_REACHED]
	)
	# Only a PROJECTED hook reads totals.
	assert_array(RevealList.triggers(TutorialEvents.CARD_PLACED, over, run)).is_equal(
		[TutorialEvents.CARD_PLACED]
	)
	run.history.append(ShiftRecord.new(1, quota, quota - 1))
	assert_array(RevealList.standing(run)).is_empty()  # A miss lights nothing.
	run.history.append(ShiftRecord.new(1, quota, quota))
	assert_array(RevealList.standing(run)).is_equal([RevealList.SHIFT_PASSED])
	run.upgrades.append(run.balance.upgrade_pool[0])
	assert_array(RevealList.standing(run)).contains([RevealList.PERK_OWNED])
	assert_array(RevealList.triggers(TutorialEvents.COUNT_FINISHED, {}, run)).contains(
		[RevealList.SHIFT_PASSED, RevealList.PERK_OWNED]
	)


## A rule alone: its shift holds from that planning on; its events from `events_from_shift`.
func test_a_rule_holds_by_its_shift_or_its_events() -> void:
	var rule: RevealRule = RevealRule.new()
	rule.element = RevealList.REDRAW
	assert_bool(rule.holds(5, 5, [&"x"])).is_false()  # No trigger at all: never.
	rule.at_shift = 2
	assert_bool(rule.holds(1, 1, [])).is_false()
	assert_bool(rule.holds(2, 1, [])).is_false()
	assert_bool(rule.holds(2, 2, [])).is_true()
	assert_bool(rule.holds(3, 3, [])).is_true()
	rule.at_shift = 0
	rule.events = [&"x"]
	rule.events_from_shift = 2
	assert_bool(rule.holds(1, 1, [&"x"])).is_false()
	assert_bool(rule.holds(2, 1, [&"y"])).is_false()
	assert_bool(rule.holds(2, 1, [&"y", &"x"])).is_true()


func _run(guided: bool) -> RunState:
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var run: RunState = RunState.new(11, load(STARTER), balance, RunStock.starting(balance))
	run.guided = guided
	run.start_shift()
	return run
