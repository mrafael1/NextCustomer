class_name WeekFlow
extends Node
## The time card on the shift screen (v0.70, WeekCard; mock-up docs/art/mockups/rota_card_v1.html,
## layout C), the top bar's day calendar (DayCalendar) and the register's week glass and medal case
## (WeekGlass, MedalCase; v1.17, in place of the week and day chips). The card plays as a week's
## first shift opens (shifts 1, 5 and 9; a resume on one plays it again, a resume mid-week never
## does), once planning can take input: after the cart reveal, the glide back from the machine and
## the count. The machine's planning notices (MachineFlow) wait for it (holds_planning). Tapping
## the week glass reopens it in planning; tapping the card closes it. Tapping the calendar pops
## today's slip up over it instead (DaySlip, 2026-10-31: today's events and where they touch the
## belt; play test 2026-11-09: above the desk calendar, over the planning receipt), and so does a
## long hover (closing as the pointer leaves, unless a tap pinned it); the card and the slip never
## show together, and the slip shows only when the card could.
## After each shift's verdict the calendar lights today's pip (v0.75, #119, light_day), before the
## machine or the next shift; the card keeps the day's PAID or SLIP stamp. A new day's page tears
## off the calendar once planning can show it and the time card has gone (DayCalendar.play_change;
## on a week's first day the card plays first), never on a resume.

var card: WeekCard
## Today's slip under the day calendar.
var slip: DaySlip
var _screen: ShiftScreen
var _calendar: DayCalendar
var _glass: WeekGlass
## The run the calendar last showed: a new one (a resume, a new run) snaps its page.
var _shown_run: RunState
## The card waits to play (a week's first shift opened).
var _due: bool = false
## The card stays out of the way (skip(): the screen capture, tests): no day stamps either.
var _quiet: bool = false


## Builds the card over `screen` (added last, over the cart reveal) and wires the calendar and
## the glass.
func _init(screen: ShiftScreen) -> void:
	name = "WeekFlow"
	_screen = screen
	_calendar = screen._stage.day_calendar
	_glass = screen._stage.week_glass
	screen.add_child(self)
	slip = DaySlip.new()
	screen.add_child(slip)
	card = WeekCard.new()
	screen.add_child(card)
	_glass.pressed.connect(reopen)
	_calendar.pressed.connect(toggle_slip)
	_calendar.long_hovered.connect(hover_slip)
	_calendar.unhovered.connect(slip.pointer_left)
	_calendar.hovered.connect(slip.pointer_back)
	screen._machine.week_holds = holds_planning
	screen._machine.week_started = shift_started


## A shift's planning opened (MachineFlow.shift_started): the card is due on a week's first shift.
func shift_started() -> void:
	card.clear()
	slip.clear()
	var run: RunState = _screen.run
	_due = run != null and has_weeks(run) and WeekCardModel.opens_at(run)


## Drops the card, due or open, with no signal, and stamps no day from now on (the screen
## capture, tests).
func skip() -> void:
	_quiet = true
	drop()


## Drops the card, due or open, with no signal (the debug panel changing today's event).
func drop() -> void:
	_due = false
	card.clear()
	slip.clear()


## Lights the shift just checked out on the calendar's pips (v0.75, #119: PAID's sound, a training
## week's SLIP its red cross; until then the time card popped in and stamped it) and waits for the
## light: on every shift of a run with weeks that goes on (a won or lost run goes to its results),
## unless skipped.
func light_day() -> void:
	var run: RunState = _screen.run
	if _quiet or run == null or not has_weeks(run):
		return
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		return
	_calendar.hold_result = false
	_calendar.show_week(WeekCardModel.of(run))
	_calendar.flash(_screen.profile.reduced_motion())
	while _calendar.is_flashing():
		await get_tree().process_frame


## Whether planning's notices wait for the card: due, or open.
func holds_planning() -> bool:
	return _due or card.is_open()


func is_open() -> bool:
	return card.is_open()


## Reopens the card (the week glass tapped) in planning, when nothing else covers it.
func reopen() -> void:
	var run: RunState = _screen.run
	if run == null or not has_weeks(run) or card.is_open() or not _can_show():
		return
	slip.clear()
	card.reopen(WeekCardModel.of(run), _glass, _screen.profile.reduced_motion())


## Pops today's slip up over the day calendar (the pad tapped), pins it when a long hover opened
## it, or closes it when it is open; only when the card could show (planning takes input), never
## over the card.
func toggle_slip() -> void:
	if slip.is_hover_open():
		slip.pin()
		return
	if slip.is_open():
		slip.close()
		return
	_open_slip(false)


## The pointer rested on the day calendar: today's slip opens, quietly, until the pointer leaves
## (not while an item is dragged).
func hover_slip() -> void:
	if slip.is_open() or _screen._drag.is_dragging():
		return
	_open_slip(true)


func _open_slip(hover: bool) -> void:
	var run: RunState = _screen.run
	if run == null or not has_weeks(run) or card.is_open() or not _can_show():
		return
	if _calendar.day() <= 0:
		return
	var week: WeekCardModel = WeekCardModel.of(run)
	var reduced: bool = _screen.profile.reduced_motion()
	var bonus: String = bonus_line(_calendar.bonus_state(), run.inspections)
	var options: Dictionary = {"above": true, "hover": hover, "bonus": bonus}
	var target: ReceiptTarget = _screen._receipt.target
	if target != null and target.is_visible_in_tree():
		options["heading"] = target.beat.get_global_rect().merge(target.caption.get_global_rect())
	slip.open(_calendar.day(), run.inspections, run.limits, _calendar, reduced, week, options)


## The day calendar, the week glass and the medal case for the run's current shift. While the
## shift is counted today's pip stays today's (v0.78): its result waits for light_day(). A new
## run (a resume) snaps the calendar's page; a next day waits for planning (_process).
func show_chips() -> void:
	var run: RunState = _screen.run
	var weeks: bool = has_weeks(run)
	if _screen._stage.gold_flow != null:
		_screen._stage.gold_flow.refresh(run, _screen._counting, _screen.profile.reduced_motion())
	# A payday's brass on the stage and PAYDAY on the calendar's page (2026-11-10).
	var payday: bool = ReceiptGoldFlow.payday(run)
	_screen._stage.show_payday(payday)
	_calendar.hold_result = _screen._counting
	_calendar.reduced_motion = _screen.profile.reduced_motion()
	var model: WeekCardModel = WeekCardModel.of(run)
	# The day first: a next day keeps the page last seen (its own pips) as the one that tears off.
	var day: int = run.shift_index + 1 if weeks else 0
	_calendar.show_inspections(day_events(run), day, event_pool(run), run.shift_count(), payday)
	if weeks:
		_calendar.show_week(model)
		show_medals(-1)
	_glass.show_week(model, weeks)
	(_screen._top_bar as TopBar).show_weeks(weeks)
	if _shown_run != run or _quiet:
		_calendar.play_change(false)
	_shown_run = run


## Every day event `run` may draw (its balance's inspection and boon pools): the calendar keeps
## room for each one's name (v1.16), so its width is the same every day.
static func event_pool(run: RunState) -> Array[InspectionDefinition]:
	return run.balance.inspection_pool + run.balance.boon_pool


## The medal case's medals as `run` stands (WeekMedals), with the totals that win them: while
## counting, the shift's own spend waits for its flight; in planning, `projected` (the preview's
## total, below 0: none) shows the medals it would spend as PENDING.
func show_medals(projected: int) -> void:
	var run: RunState = _screen.run
	if run == null or not has_weeks(run):
		return
	var states: Array[int] = WeekMedals.states(run, _screen._counting, projected)
	var flow: ReceiptGoldFlow = _screen._stage.gold_flow
	for index: int in range(states.size()):
		if _screen._counting and flow != null and flow.has_flown(index == 1):
			states[index] = WeekMedals.State.USED  # Its flight left the case: no pop back.
	var tips: PackedStringArray = PackedStringArray()
	for index: int in range(states.size()):
		tips.append(WeekMedals.tip_of(run, index == 1, states[index]))
	var medals: MedalCase = _screen._stage.medal_case
	medals.reduced_motion = _screen.profile.reduced_motion()
	medals.show_states(states, tips)
	var machine: MachineDefinition = WeekMedals.machine_data(run)
	medals.show_tags(OvertimeWords.cap_tag(machine, false), OvertimeWords.cap_tag(machine, true))
	medals.show_thresholds(WeekMedals.threshold_of(run, false), WeekMedals.threshold_of(run, true))


## Planning's preview projects `projected`: the medals it would spend shimmer (show_medals) and
## the receipt's edges glow in their metal (ReceiptGoldFlow.show_pending).
func show_pending(projected: int) -> void:
	show_medals(projected)
	var run: RunState = _screen.run
	if run != null and _screen._stage.gold_flow != null:
		var states: Array[int] = WeekMedals.states(run, false, projected)
		_screen._stage.gold_flow.show_pending(
			states[0] == WeekMedals.State.PENDING,
			states[1] == WeekMedals.State.PENDING,
			_screen.profile.reduced_motion()
		)


## The bonus ticket's line on today's slip (play test 2026-11-09: the calendar's tooltip is gone,
## so the "+1" pill's whole words read here): PASS › +1 BONUS TICKET while promised, "Spot check
## passed" once earned, empty without a ticket.
static func bonus_line(
	state: InspectionTag.Bonus, inspections: Array[InspectionDefinition]
) -> String:
	if state == InspectionTag.Bonus.EARNED:
		var passed: Array[InspectionDefinition] = InspectionDefinition.maluses(inspections)
		return DayCalendar.EARNED_TIP % ", ".join(InspectionTag.names(passed))
	return DayCalendar.PILL_TIP if state == InspectionTag.Bonus.PROMISED else ""


## The events the day calendar shows: the day's only (run.inspections). A worn pin's events
## (#132: Express lane's) are run-wide, not the day's, so it leaves them out (the belt's end marks
## show Express lane); the week event is the week glass's.
static func day_events(run: RunState) -> Array[InspectionDefinition]:
	return run.inspections.duplicate()


## Where the shift's event `index` (WeekSchedule.shift_events) is on the calendar (day_events), -1
## when it isn't there (the week event, a worn pin's event, or no event).
static func day_index(run: RunState, index: int) -> int:
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	if index < 0 or index >= events.size() or events[index].is_week() or is_pin_event(run, index):
		return -1
	return day_events(run).find(events[index])


## Whether the shift's event `index` (WeekSchedule.shift_events) is a worn pin's (#132: they come
## last, after the day's and the week's).
static func is_pin_event(run: RunState, index: int) -> bool:
	var count: int = WeekSchedule.shift_events(run).size()
	return index >= count - RunPins.pin_events(run).size() and index < count


## Whether `run`'s balance has weeks (a week list or a week length).
static func has_weeks(run: RunState) -> bool:
	return not run.balance.weeks.is_empty() or run.balance.week_length > 0


## The names of the shift's events that are no inspection (the boon day events and the week
## event): the dessert's INSPECTION PASSED leaves them out (CountUpContext.boon_names).
static func helper_names(run: RunState) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for event: InspectionDefinition in WeekSchedule.shift_events(run):
		if event.is_boon() or event.is_week():
			names.append(event.display_name)
	return names


func _process(_delta: float) -> void:
	if slip.visible and not _can_show():
		slip.clear()  # The count, the machine or the cart reveal took over.
	if _due and _can_show():
		_due = false
		slip.clear()
		var run: RunState = _screen.run
		card.play(WeekCardModel.of(run), _glass, _screen.profile.reduced_motion())
	if _calendar.is_changing() and _can_show() and not card.is_open():
		_calendar.play_change(not _quiet)  # The new day's page, once planning shows, after the card.


## Planning takes input: no count, no cart reveal, no machine visit or glide back, and the item
## upgrade swap has played (the card would cover it).
func _can_show() -> bool:
	var run: RunState = _screen.run
	if run == null or run.phase != RunState.Phase.PLANNING or _screen._counting:
		return false
	var machine: MachineFlow = _screen._machine
	return (
		not _screen._cart_reveal.is_open()
		and not machine.is_settling()
		and not machine.is_swapping()
	)
