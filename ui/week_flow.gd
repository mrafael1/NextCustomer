class_name WeekFlow
extends Node
## The time card on the shift screen (v0.70, WeekCard; mock-up docs/art/mockups/rota_card_v1.html,
## layout C) and the top bar's week and day chips. The card plays as a week's first shift opens
## (shifts 1, 5 and 9; a resume on one plays it again, a resume mid-week never does), once
## planning can take input: after the cart reveal, the glide back from the machine and the count.
## The machine's planning notices (MachineFlow) wait for it (holds_planning). Tapping the week
## chip or the day chip reopens it in planning; tapping the card closes it. After each shift's
## verdict the week chip lights today's pip, a green check or a red cross (v0.75, #119,
## light_day), before the machine or the next shift; the card keeps the day's PAID or SLIP stamp.

var card: WeekCard
var _screen: ShiftScreen
var _bar: TopBar
## The card waits to play (a week's first shift opened).
var _due: bool = false
## The card stays out of the way (skip(): the screen capture, tests): no day stamps either.
var _quiet: bool = false


## Builds the card over `screen` (added last, over the cart reveal) and wires the chips.
func _init(screen: ShiftScreen) -> void:
	name = "WeekFlow"
	_screen = screen
	_bar = screen._top_bar as TopBar
	screen.add_child(self)
	card = WeekCard.new()
	screen.add_child(card)
	_bar.week_chip.pressed.connect(reopen)
	_bar.inspection_tag.pressed.connect(reopen)
	screen._machine.week_holds = holds_planning
	screen._machine.week_started = shift_started


## A shift's planning opened (MachineFlow.shift_started): the card is due on a week's first shift.
func shift_started() -> void:
	card.clear()
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


## Lights the shift just checked out on the week chip (v0.75, #119: a green check for PAID, a red
## cross for a training week's SLIP; until then the time card popped in and stamped it) and waits
## for the light: on every shift of a run with weeks that goes on (a won or lost run goes to its
## results), unless skipped.
func light_day() -> void:
	var run: RunState = _screen.run
	if _quiet or run == null or not has_weeks(run):
		return
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		return
	var chip: WeekChip = _bar.week_chip
	chip.show_week(WeekCardModel.of(run))
	chip.flash(_screen.profile.reduced_motion())
	while chip.is_flashing():
		await get_tree().process_frame


## Whether planning's notices wait for the card: due, or open.
func holds_planning() -> bool:
	return _due or card.is_open()


func is_open() -> bool:
	return card.is_open()


## Reopens the card (a chip tapped) in planning, when nothing else covers it.
func reopen() -> void:
	var run: RunState = _screen.run
	if run == null or not has_weeks(run) or card.is_open() or not _can_show():
		return
	card.reopen(WeekCardModel.of(run), _bar.week_chip, _screen.profile.reduced_motion())


## The top bar's week chip and day chip for the run's current shift. While the shift is counted
## today's pip stays today's (v0.78): its check or cross waits for light_day().
func show_chips() -> void:
	var run: RunState = _screen.run
	var weeks: bool = has_weeks(run)
	_bar.week_chip.hold_result = _screen._counting
	if weeks:
		_bar.week_chip.show_week(WeekCardModel.of(run))
	_bar.show_weeks(weeks)
	_bar.inspection_tag.show_inspections(run.inspections, run.shift_index + 1 if weeks else 0)


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
	if _due and _can_show():
		_due = false
		var run: RunState = _screen.run
		card.play(WeekCardModel.of(run), _bar.week_chip, _screen.profile.reduced_motion())


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
