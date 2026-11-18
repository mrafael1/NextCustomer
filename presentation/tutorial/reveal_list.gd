class_name RevealList
extends Resource
## The week 1 strip's rules (v1.40, data/tutorial/reveals.tres; play tests of 2026-11-16 and
## 2026-11-18: "a lot of information, maybe even too much"): on a new profile's first run (a
## guided run, RunState.guided) the shift screen shows an element only from the first time it can
## change the player's decision or does something, and keeps it from then on. Only visibility:
## nothing is gated, and no rule reads it. Every other run shows everything, as before.
##
## The strip holds through the guided run's first week (stripped); from week 2 on every element
## shows. What was revealed is kept on the run (RunState.guide_reveals, saved with it). Pure and
## static but for the data: the UI's Week1Strip applies it to the screen's controls.

const PATH := "res://data/tutorial/reveals.tres"
## The elements (the TutorialAnchors ids of their controls): the top bar's LOYALTY chip and Cart
## button, the register's Redraw key and week glass, the desk calendar and the medal case.
const LOYALTY := &"loyalty"
const CART := &"cart"
const REDRAW := &"redraw"
const WEEK := &"week"
const CALENDAR := &"cal"
const MEDALS := &"medals"
const ELEMENTS: Array[StringName] = [LOYALTY, CART, REDRAW, WEEK, CALENDAR, MEDALS]
## Triggers read from the run (triggers, standing): a shift that met its quota, a shift under a
## day event, a loyalty perk owned; and from a PROJECTED hook, the planning's row reaching the
## quota or the first medal's total.
const SHIFT_PASSED := &"shift_passed"
const QUOTA_REACHED := &"quota_reached"
const MEDAL_REACHED := &"medal_reached"
const DAY_EVENT := &"day_event"
const PERK_OWNED := &"perk_owned"
const OWN_TRIGGERS: Array[StringName] = [
	SHIFT_PASSED, QUOTA_REACHED, MEDAL_REACHED, DAY_EVENT, PERK_OWNED
]

@export var rules: Array[RevealRule] = []


## The week 1 strip's rules (data/tutorial/reveals.tres).
static func shared() -> RevealList:
	return load(PATH) as RevealList


## Whether `run` is stripped now: a guided run in its first week.
static func stripped(run: RunState) -> bool:
	if run == null or not run.guided:
		return false
	return WeekSchedule.week_of(run.balance, run.shift_index + 1) == 0


## Whether `element` shows on `run`: always on a run that isn't stripped, and an element no rule
## names is never hidden.
func shows(run: RunState, element: StringName) -> bool:
	if not stripped(run) or run.guide_reveals.has(element):
		return true
	return not elements().has(element)


## The elements the rules name, in data order.
func elements() -> Array[StringName]:
	var found: Array[StringName] = []
	for rule: RevealRule in rules:
		if not found.has(rule.element):
			found.append(rule.element)
	return found


## The hidden elements of a stripped `run` that the triggers `happened` (or the shift alone)
## reveal now, in data order; empty on a run that isn't stripped. `planned` is the last shift
## (1-based) whose planning took input (0: the run's shift).
func due(run: RunState, happened: Array[StringName] = [], planned: int = 0) -> Array[StringName]:
	var found: Array[StringName] = []
	if not stripped(run):
		return found
	var shift: int = run.shift_index + 1
	for rule: RevealRule in rules:
		if run.guide_reveals.has(rule.element) or found.has(rule.element):
			continue
		if rule.holds(shift, planned if planned > 0 else shift, happened):
			found.append(rule.element)
	return found


## The triggers a hook stands for on `run`: the TutorialEvents `event` itself, the run's standing
## ones, and a PROJECTED hook's QUOTA_REACHED and MEDAL_REACHED.
static func triggers(event: StringName, args: Dictionary, run: RunState) -> Array[StringName]:
	var found: Array[StringName] = [event]
	found.append_array(standing(run))
	if event == TutorialEvents.PROJECTED:
		var total: int = int(args.get(TutorialEvents.ARG_TOTAL, 0))
		var quota: int = int(args.get(TutorialEvents.ARG_QUOTA, 0))
		if quota > 0 and total >= quota:
			found.append(QUOTA_REACHED)
		if quota > 0 and total >= medal_total(run, quota):
			found.append(MEDAL_REACHED)
	return found


## The triggers that hold from `run`'s state alone (a resume reads them too): a shift met its
## quota (SHIFT_PASSED), the shift has a day event (DAY_EVENT), a loyalty perk is owned
## (PERK_OWNED).
static func standing(run: RunState) -> Array[StringName]:
	var found: Array[StringName] = []
	if run.history.any(func(record: ShiftRecord) -> bool: return record.passed):
		found.append(SHIFT_PASSED)
	if not run.inspections.is_empty():
		found.append(DAY_EVENT)
	if not run.upgrades.is_empty():
		found.append(PERK_OWNED)
	return found


## The total the first medal asks for on a shift whose quota is `quota` (the machine's laps of
## it); never reached (a huge total) on a run whose machine gives no medal.
static func medal_total(run: RunState, quota: int) -> int:
	var machine: MachineDefinition = run.balance.machine
	if machine == null or machine.overtime_ticket_laps <= 0:
		return 1 << 30
	return quota * machine.overtime_ticket_laps
