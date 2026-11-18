class_name Week1Strip
extends Node
## The week 1 strip on the shift screen (v1.40; play tests of 2026-11-16 and 2026-11-18: "a lot of
## information, maybe even too much"): a part of the shift screen (made by its TutorialDirector)
## that hides the HUD elements a new player doesn't need yet and pops each one in the first time it
## matters. What is hidden and what reveals it is data (RevealList, data/tutorial/reveals.tres);
## what was revealed is kept on the run (RunState.guide_reveals, saved with it). It only sets
## visibility: nothing is gated, and a run that isn't stripped (every run but a guided run's first
## week) shows everything, as before.
##
## The elements and their controls: the top bar's LOYALTY chip and Cart button, the register's
## Redraw key, its week glass (the keypad shows in its place), the desk calendar and the drawer's
## medal case. An element is revealed by its rules as the screen's hooks come in (guide_event), by
## a callout that rings it (reveal_rings: the director's steps and the one-time tips), and all of
## them from week 2 on. A reveal pops the control in (a short scale and fade; none under reduced
## motion); a resume shows what was revealed at once.

## `element` was revealed (not sent for a resume's or week 2's).
signal revealed(element: StringName)

## The pop: the control starts POP_SCALE times its size and clear, and settles in POP_S.
const POP_S := 0.3
const POP_SCALE := 1.25

var _screen: ShiftScreen
var _list: RevealList
## The run and the strip's state last applied (a new run, a resume, week 2: applied again).
var _run: RunState
var _stripped: bool = false
## The last shift (1-based) whose planning took input (PLANNING_READY): a rule's at_shift waits
## for it, so its element pops in on the planning, never under the glide back from the machine.
var _planned: int = 0


## Adds the strip to `screen` (after its stage and WeekFlow are built).
func _init(screen: ShiftScreen) -> void:
	name = "Week1Strip"
	_screen = screen
	_list = RevealList.shared()
	screen.add_child(self)
	screen.guide_event.connect(_on_event)


## Whether `element` (a RevealList element id) shows now.
func shows(element: StringName) -> bool:
	return _list.shows(_screen.run, element)


## The hidden elements now, in RevealList.ELEMENTS' order (tests, captures).
func hidden() -> Array[StringName]:
	var found: Array[StringName] = []
	for element: StringName in RevealList.ELEMENTS:
		if not shows(element):
			found.append(element)
	return found


## Reveals `element` for the rest of the run, popping it in (`pop`); false when it shows already.
func reveal(element: StringName, pop: bool = true) -> bool:
	var run: RunState = _screen.run
	if run == null or _list.shows(run, element):
		return false
	run.guide_reveals.append(element)
	_apply(element, true, pop)
	revealed.emit(element)
	return true


## Reveals every hidden element among `ids` (a callout's rings: what it points at must show).
func reveal_rings(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		reveal(id)


## Shows and hides every element for the screen's run as it is now, with no pop (a new run, a
## resume, week 2). The reveals the run's state alone asks for are taken first.
func refresh() -> void:
	var run: RunState = _screen.run
	_run = run
	_stripped = RevealList.stripped(run)
	if run == null:
		return
	_planned = run.shift_index + (1 if run.phase == RunState.Phase.PLANNING else 0)
	for element: StringName in _list.due(run, RevealList.standing(run), maxi(_planned, 1)):
		run.guide_reveals.append(element)
	for element: StringName in RevealList.ELEMENTS:
		_apply(element, _list.shows(run, element), false)


func _process(_delta: float) -> void:
	var run: RunState = _screen.run
	if run != _run or (run != null and RevealList.stripped(run) != _stripped):
		refresh()


## A hook from the screen: the rules it makes hold reveal their elements.
func _on_event(event: StringName, args: Dictionary) -> void:
	var run: RunState = _screen.run
	if run == null or not RevealList.stripped(run):
		return
	if run != _run:
		refresh()
	if event == TutorialEvents.PLANNING_READY:
		_planned = run.shift_index + 1
	var happened: Array[StringName] = RevealList.triggers(event, args, run)
	var found: Array[StringName] = _list.due(run, happened, maxi(_planned, 1))
	for element: StringName in found:
		reveal(element)
	# Kept with the run's next save point; planning saves now, so a resume never pops it twice.
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _screen._busy()
	if not found.is_empty() and planning:
		_screen._save_run()


## Shows or hides `element`'s control; a shown one pops in when `pop` (never under reduced motion).
func _apply(element: StringName, shown: bool, pop: bool) -> void:
	var stage: ShiftStage = _screen._stage
	var control: Control = null
	match element:
		RevealList.LOYALTY:
			control = stage.loyalty_card
		RevealList.CART:
			control = stage.deck_button
		RevealList.REDRAW:
			control = stage.redraw_button
		RevealList.MEDALS:
			control = stage.medal_case
		RevealList.WEEK:
			stage.week_glass.stripped = not shown  # It keeps its own rule (weeks, Cancel).
			control = stage.week_glass
		RevealList.CALENDAR:
			stage.day_calendar.stripped = not shown  # It keeps its own rule (a day to show).
			control = stage.day_calendar
	if control == null:
		return
	if not element in [RevealList.WEEK, RevealList.CALENDAR]:
		control.visible = shown
	if shown and pop and control.visible and not _screen.profile.reduced_motion():
		_pop(control)


## Pops `control` in: from POP_SCALE and clear to its own size and alpha, about its centre.
func _pop(control: Control) -> void:
	var pivot: Vector2 = control.pivot_offset
	var alpha: float = control.modulate.a
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * POP_SCALE
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, POP_S).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(control, "modulate:a", alpha, POP_S / 2.0)
	tween.chain().tween_callback(func() -> void: control.pivot_offset = pivot)
