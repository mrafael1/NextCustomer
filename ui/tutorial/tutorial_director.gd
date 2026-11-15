class_name TutorialDirector
extends Node
## The guided first run's director (tutorial plan sections 1.5 and 1.6, WP-8; mock-up
## docs/art/mockups/tutorial.html, its GUIDED steps): a part of the shift screen that plays the
## guided script (data/tutorial/guided.tres, G2..G26; G1 is the title's, TitleGuide) on a run
## started guided (RunState.guided). It owns the current step, hears the screens' hooks
## (ShiftScreen.guide_event, StartBoard.guide_event), answers their gate (allows: the shift
## screen's ShiftGuide.gate, the opening board's StartChoice.guide_gate and guide_locks), shows
## each step on a TutorialOverlay (over the opening board while it shows, else on the shift
## screen's tutorial layer), writes the step to the run (RunState.guide_step, saved with the run's
## next save point), sets the profile's done flag at the end and logs every step.
##
## How a step moves on:
## - its footer key (NEXT ›, GOT IT) or its `advance_on` event (`advance_count` times); an event a
##   later step waits for skips ahead to it (CHECKOUT pressed on G21 goes on to the machine);
## - a planning step of shift 1 follows the row (TutorialStep.row_before): after any move the
##   step to play is the first later one the row fits, else the latest earlier one (a card moved
##   back to its basket re-shows the step that placed it). A step that asks for a move also fits
##   the row half way (one of two Bananas placed). Picking a placed card back up is allowed only
##   when the row left behind fits a step, so the row never strands the run;
## - the game's state moves it on too (a resume, a booster opened with OPEN ALL): page 2 shown, a
##   pack picked, the machine's phases, the next shift.
##
## A step shows once its screen does (the board's page with nothing playing on it, planning
## taking input, the machine's keys or prizes armed, shift 2's planning) and one of its rings is
## on screen; it hides while it can't (a booster opening, the count-up, the machine's glide). The
## time card waits through shift 1 (WeekFlow.hold) and opens for G25 on shift 2; planning's
## notices and the calendar's page change wait until G26 closes. After G26 the run plays on as
## any other, `finished` goes out, and the one-time tips (WP-10) may follow: only
## TIPS_AFTER_FINISH on that planning (decided with the user, 2026-11-14).

## The guided run's last step closed (G26): the done flag is set, the run plays on.
signal finished

## The guide_step of a guided run whose guided part is over (G26 closed).
const DONE := &"done"
## The one-time tips that may follow G26 on the same planning (WP-10's scheduler reads it).
const TIPS_AFTER_FINISH: Array[StringName] = [&"day_event"]
## Events that move a later step on when they come early (its step skipped).
const SKIP_AHEAD: Array[StringName] = [
	TutorialEvents.BOOSTERS_ALL_OPEN,
	TutorialEvents.PACK_PICKED,
	TutorialEvents.STORE_OPENED,
	TutorialEvents.CHECKOUT_STARTED,
	TutorialEvents.CHUTE_CHOSEN,
	TutorialEvents.MACHINE_RETURNED,
]
## A callout's width in canvas px: BASE_WIDTH plus WORD_WIDTH per word of its line, at most
## MAX_WIDTH (the mock-up's 400-560 px boxes at 1920, x1.25).
const BASE_WIDTH := 230.0
const WORD_WIDTH := 5.0
const MAX_WIDTH := 380.0

var _screen: ShiftScreen
var _guided: TutorialScript
## The figures the lines name (TutorialText.values), filled once.
var _values: Dictionary = {}
## The run the director plays on (attach), and whether its guided part is on.
var _run: RunState
var _active: bool = false
## Whether the run was asked for by PLAY THE GUIDED SHIFT (tutorial_done's `replay`).
var _replay: bool = false
var _index: int = -1
## The step's `advance_on` events heard so far.
var _heard: int = 0
## When the step first showed (Time.get_ticks_msec), -1 before; when the guided part began.
var _shown_ms: int = -1
var _began_ms: int = 0
## The time card was opened for the step that shows on it.
var _card_opened: bool = false
## The overlay on the shift screen, and the one on the opening board (rebuilt with each board).
var _overlay: TutorialOverlay
var _board: StartBoard
var _board_overlay: TutorialOverlay
## The overlay showing the step now (null: none), and the step it shows.
var _showing: TutorialOverlay
var _shown_index: int = -1


## Adds the director to `screen` (after its ShiftGuide and WeekFlow are built).
func _init(screen: ShiftScreen) -> void:
	name = "TutorialDirector"
	_screen = screen
	_guided = TutorialScript.guided()
	screen.add_child(self)
	screen.guide_event.connect(_on_event)
	screen.guide.refused.connect(func(_action: StringName, _args: Dictionary) -> void: _refuse())


## Plays the screen's run from its step (a new run, a resume): a guided run whose guided part
## isn't over takes the gates and holds; any other run lets them go.
func attach() -> void:
	_run = _screen.run
	_hide()
	var guided: bool = _run != null and _run.guided and _run.guide_step != DONE
	if not guided:
		_set_active(false)
		return
	if _values.is_empty():
		_values = TutorialText.values(_guided, _screen._balance)
	_replay = TutorialFlags.has_seen(_screen.profile, TutorialFlags.GUIDE_REPLAY)
	_began_ms = Time.get_ticks_msec()
	_set_active(true)
	_go(_resume_index(), false)


## Whether the guided part of the screen's run is on.
func is_active() -> bool:
	return _active


## The current step's id (&"" when the guided part isn't on).
func step_id() -> StringName:
	return _step().id if _active and _step() != null else &""


## The overlay showing the step now, or null (tests, captures).
func overlay() -> TutorialOverlay:
	return _showing if is_instance_valid(_showing) and _showing.is_showing() else null


## The gate (TutorialActions): whether the current step lets the player do `action` with `args`.
func allows(action: StringName, args: Dictionary) -> bool:
	var step: TutorialStep = _step()
	if not _active or step == null:
		return true
	if action == TutorialActions.HIT and args.get(TutorialActions.ARG_ID) == TutorialAnchors.ROLLUP:
		return true  # The shutter rolls up on a click as ever (on the web it waits for one).
	var allowed: bool = step.allows(action, args)
	if step.gate == TutorialStep.Gate.OPEN:
		return allowed
	match action:
		TutorialActions.PICK_CARD:
			allowed = _may_pick(step, args)
		TutorialActions.PLACE_CARD:
			allowed = _may_place(step, args)
		TutorialActions.CHECKOUT:
			allowed = _may_checkout(step)
	if _on_board(step) and not allowed:
		_refuse.call_deferred()  # The board's clicks and keys: refused, with the shake.
	return allowed


## Whether the opening board draws its part `id` LOCKED (the start steps' locks).
func locks(id: StringName) -> bool:
	if not _active:
		return false
	for step: TutorialStep in _guided.steps:
		if _on_board(step) and step.locks.has(id):
			return true
	return false


func _process(_delta: float) -> void:
	if _screen.run != _run:
		attach()
	if not _active:
		return
	_watch_board()
	_sync()
	if not _active:
		return
	var step: TutorialStep = _step()
	_open_card(step)
	if _ready_for(step):
		if _shown_index != _index or overlay() == null:
			_show(step)
	elif overlay() != null:
		_hide()


# --- Steps ---------------------------------------------------------------------------------


func _step() -> TutorialStep:
	return _guided.steps[_index] if _index >= 0 and _index < _guided.steps.size() else null


## Goes to step `index` (`done`: the step before it was done, logged with its time).
func _go(index: int, done: bool) -> void:
	if done and _step() != null:
		var seconds: float = _seconds_shown()
		_screen._log.log_event("tutorial_step", RunEvents.tutorial_step(_step().id, seconds))
	if index >= _guided.steps.size():
		_finish()
		return
	_index = maxi(index, 0)
	_heard = 0
	_shown_ms = -1
	_card_opened = false
	_run.guide_step = _step().id
	_hide()
	if _run.phase == RunState.Phase.PLANNING:
		_screen._refresh_buttons()  # CHECKOUT's key follows the gate.


## The step's key (NEXT ›, GOT IT) moves it on when it may.
func _on_button() -> void:
	var step: TutorialStep = _step()
	if not _active or step == null or not step.button_advances():
		return
	_go(_index + 1, true)
	if step.rings.has(TutorialAnchors.WEEK_CARD) and _screen._week.is_open():
		_screen._week.card.close()  # G25 read through NEXT: the card flies home before G26.
	if _active and _run.phase == RunState.Phase.PLANNING and not _screen._busy():
		_screen._save_run()


## G26 closed: the done flag (and no replay asked any more), the profile saved, the log; the
## gates and holds let go.
func _finish() -> void:
	var seconds: float = (Time.get_ticks_msec() - _began_ms) / 1000.0
	_run.guide_step = DONE
	_set_active(false)
	if TutorialFlags.finish_guide(_screen.profile):
		_screen.save_profile()
	_screen._log.log_event("tutorial_done", RunEvents.tutorial_done(seconds, _replay))
	if _run.phase == RunState.Phase.PLANNING and not _screen._busy():
		_screen._save_run()
	finished.emit()


func _seconds_shown() -> float:
	return 0.0 if _shown_ms < 0 else (Time.get_ticks_msec() - _shown_ms) / 1000.0


## A hook from the shift screen or the opening board.
func _on_event(event: StringName, args: Dictionary) -> void:
	var step: TutorialStep = _step()
	if not _active or step == null:
		return
	if _follows_row(step) and _row_event(step, event, args):
		_follow_row()
		return
	if event == TutorialEvents.WEEK_CARD_CLOSED and step.rings.has(TutorialAnchors.WEEK_CARD):
		_go(_index + 1, true)  # The card was tapped shut: the step it showed is read.
		return
	if step.advance_on == event and _fits_page(step, event, args):
		_heard += 1
		if _heard >= step.advance_count:
			_go(_index + 1, true)
		return
	if SKIP_AHEAD.has(event):
		for later: int in range(_index + 1, _guided.steps.size()):
			if _guided.steps[later].advance_on == event:
				_go(later + 1, true)
				return


## PAGE_SHOWN moves a step on only to the page its next step shows on.
func _fits_page(step: TutorialStep, event: StringName, args: Dictionary) -> bool:
	if event != TutorialEvents.PAGE_SHOWN or _index + 1 >= _guided.steps.size():
		return true
	var next: TutorialStep = _guided.steps[_index + 1]
	var page: int = 1 if next.screen == TutorialStep.Screen.START_BUILD else 0
	return step.screen != next.screen and int(args.get(TutorialEvents.ARG_PAGE, -1)) == page


## Whether `event` is a row move the row-following step answers: a card placed or put back, or
## a placed card picked up that isn't the step's own move (G15's Eggs).
func _row_event(step: TutorialStep, event: StringName, args: Dictionary) -> bool:
	if event in [TutorialEvents.CARD_PLACED, TutorialEvents.CARD_REMOVED]:
		return true
	if event != TutorialEvents.CARD_PICKED or not bool(args.get(TutorialEvents.ARG_FROM_ROW)):
		return false
	return not _moves(step, StringName(str(args.get(TutorialEvents.ARG_CARD, ""))))


# --- The state ----------------------------------------------------------------------------


## The step a resumed (or newly attached) run plays from: its saved step when the game's state
## still fits it, else the first one the state allows.
func _resume_index() -> int:
	var saved: int = _guided.index_of(_run.guide_step)
	var least: int = _least_index()
	if _run.phase == RunState.Phase.PLANNING and _run.shift_index == 0:
		var row: Array[StringName] = _row_ids()
		if saved >= 0 and _fits(saved, row):
			return saved
		for k: int in range(least, _guided.steps.size()):
			if _fits(k, row):
				return k
		return least
	return maxi(saved, least)


## The first step the game's state allows: the board's page and boosters, the run's phase and
## shift (a guided run never goes back before them).
func _least_index() -> int:
	var phase: RunState.Phase = _run.phase
	if phase == RunState.Phase.CHOOSE_START:
		return _least_on_board()
	if phase == RunState.Phase.MACHINE_CHOOSE:
		return _first(TutorialStep.Screen.MACHINE_CHOOSE)
	if phase == RunState.Phase.MACHINE_PICK:
		return _first(TutorialStep.Screen.MACHINE_PICK)
	if phase == RunState.Phase.PLANNING and _run.shift_index == 0:
		return _first(TutorialStep.Screen.PLANNING)
	return _first(TutorialStep.Screen.WEEK_CARD)


func _least_on_board() -> int:
	var board: StartBoard = _board_now()
	var stock: int = _first(TutorialStep.Screen.START_STOCK)
	if board == null:
		return stock
	if board.page == 2:
		var picked: bool = board.selected() >= 0
		return _waiting_for(TutorialEvents.STORE_OPENED) if picked else _first_build()
	if board.store.page_done():
		return _waiting_for(TutorialEvents.PAGE_SHOWN)
	for opening: BoosterOpening in board.store.boosters:
		if opening.state != BoosterOpening.State.SEALED:
			return _waiting_for(TutorialEvents.BOOSTERS_ALL_OPEN)
	return stock


func _first_build() -> int:
	return _first(TutorialStep.Screen.START_BUILD)


## The game's state moved past the step (a resume, OPEN ALL, the next shift): it goes on.
func _sync() -> void:
	var least: int = _least_index()
	if least > _index:
		_go(least, true)


## The first step on `screen` (the last step when none is).
func _first(screen: TutorialStep.Screen) -> int:
	for k: int in _guided.steps.size():
		if _guided.steps[k].screen == screen:
			return k
	return _guided.steps.size() - 1


## The step that waits for `event` (-1: none).
func _waiting_for(event: StringName) -> int:
	for k: int in _guided.steps.size():
		if _guided.steps[k].advance_on == event:
			return k
	return -1


# --- The row (shift 1's planning) ---------------------------------------------------------


func _follows_row(step: TutorialStep) -> bool:
	return step.screen == TutorialStep.Screen.PLANNING and step.checks_row


## The row now, as card definition ids in slot order.
func _row_ids(leaving: int = 0) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in _run.row:
		if card.instance_id != leaving or leaving == 0:
			ids.append(card.definition.id)
	return ids


## After a move: the first later step the row fits, else the latest earlier one; the step stays
## when it fits, or when none does.
func _follow_row() -> void:
	var row: Array[StringName] = _row_ids()
	if _fits(_index, row):
		return
	for later: int in range(_index + 1, _guided.steps.size()):
		if _fits(later, row):
			_go(later, true)
			return
	for earlier: int in range(_index - 1, -1, -1):
		if _fits(earlier, row):
			_go(earlier, false)
			return


## Whether step `k` plays on `row`: its row_before, or (a step that places cards) a row on the
## way from it to the next step's.
func _fits(k: int, row: Array[StringName]) -> bool:
	var step: TutorialStep = _guided.steps[k]
	if not _follows_row(step):
		return false
	if step.row_before == row:
		return true
	if not step.allow.has(TutorialActions.PLACE_CARD):
		return false
	var target: Array[StringName] = _target(k)
	return (
		row.size() > step.row_before.size()
		and row.size() < target.size()
		and _starts(row, step.row_before)
		and _starts(target, row)
	)


## The row step `k`'s move makes: the next step's row_before that differs from its own.
func _target(k: int) -> Array[StringName]:
	var own: Array[StringName] = _guided.steps[k].row_before
	for later: int in range(k + 1, _guided.steps.size()):
		var step: TutorialStep = _guided.steps[later]
		if not _follows_row(step):
			break
		if step.row_before != own:
			return step.row_before
	return own


## Whether `row` begins with `head`.
static func _starts(row: Array[StringName], head: Array[StringName]) -> bool:
	return row.size() >= head.size() and row.slice(0, head.size()) == head


## Whether the step's move is picking up `card` (its allow_cards).
static func _moves(step: TutorialStep, card: StringName) -> bool:
	if not step.allow.has(TutorialActions.PICK_CARD):
		return false
	return step.allow_cards.is_empty() or step.allow_cards.has(card)


## A pick: from a basket, the step's card; from the row, the step's card or one whose leaving
## leaves a row some step plays on.
func _may_pick(step: TutorialStep, args: Dictionary) -> bool:
	var card: StringName = StringName(str(args.get(TutorialEvents.ARG_CARD, "")))
	if not bool(args.get(TutorialEvents.ARG_FROM_ROW, false)):
		return step.allows(TutorialActions.PICK_CARD, args)
	if _moves(step, card) or not _follows_row(step):
		return true
	var left: Array[StringName] = _row_ids(int(args.get(TutorialEvents.ARG_INSTANCE, 0)))
	for k: int in range(_index, -1, -1):
		if _fits(k, left):
			return true
	return false


## A drop: the step's card at its slot, making the row its move makes (in the right order).
func _may_place(step: TutorialStep, args: Dictionary) -> bool:
	if not step.allows(TutorialActions.PLACE_CARD, args):
		return false
	if not _follows_row(step):
		return true
	var after: Array[StringName] = _row_ids()
	var slot: int = clampi(int(args.get(TutorialEvents.ARG_SLOT, 0)), 0, after.size())
	after.insert(slot, StringName(str(args.get(TutorialEvents.ARG_CARD, ""))))
	return _starts(_target(_index), after)


## CHECKOUT: from the step that no longer locks it (G21), once the row reaches the quota.
func _may_checkout(step: TutorialStep) -> bool:
	var unlocked: bool = (
		step.allows(TutorialActions.CHECKOUT)
		or (_follows_row(step) and not step.locks.has(TutorialAnchors.CHECKOUT))
	)
	return unlocked and _run.preview().total >= _run.quota()


# --- Showing --------------------------------------------------------------------------------


## Whether `step` can show now: its screen shows and takes input, and one of its rings is on it.
func _ready_for(step: TutorialStep) -> bool:
	var run: RunState = _run
	var planning: bool = run.phase == RunState.Phase.PLANNING and _planning_free()
	var machine: RewardMachineView = _screen._machine.view
	var armed: bool = _screen._machine.is_open() and machine.is_armed()
	var shown: bool = false
	match step.screen:
		TutorialStep.Screen.START_STOCK, TutorialStep.Screen.START_BUILD:
			var board: StartBoard = _board_now()
			var page: int = 1 if step.screen == TutorialStep.Screen.START_STOCK else 2
			shown = board != null and board.page == page and not board.tips_blocked()
		TutorialStep.Screen.PLANNING:
			shown = planning and run.shift_index == 0
		TutorialStep.Screen.MACHINE_CHOOSE:
			shown = run.phase == RunState.Phase.MACHINE_CHOOSE and armed
		TutorialStep.Screen.MACHINE_PICK:
			shown = run.phase == RunState.Phase.MACHINE_PICK and armed
		TutorialStep.Screen.WEEK_CARD:
			var card: WeekCard = _screen._week.card
			shown = planning and run.shift_index >= 1 and not card.is_shrinking()
	return shown and _ring_on_screen(step)


## Planning takes input: no count, glide, redraw, cart reveal or machine visit.
func _planning_free() -> bool:
	var machine: MachineFlow = _screen._machine
	return (
		not _screen._busy()
		and not _screen._redraw_busy
		and not _screen._cart_reveal.is_open()
		and not machine.is_open()
		and not machine.is_swapping()
	)


func _ring_on_screen(step: TutorialStep) -> bool:
	if step.rings.is_empty():
		return true
	var anchors: Callable = _anchors(step)
	for id: StringName in _rings_of(step):
		if (anchors.call(id) as Rect2).has_area():
			return true
	return false


## G25's time card: opened once its step's planning shows (it waits through shift 1).
func _open_card(step: TutorialStep) -> void:
	if _card_opened or not step.rings.has(TutorialAnchors.WEEK_CARD):
		return
	var week: WeekFlow = _screen._week
	if week.is_open():
		_card_opened = true
		return
	if _run.phase == RunState.Phase.PLANNING and _run.shift_index >= 1 and _planning_free():
		week.reopen()
		_card_opened = week.is_open()


## The step's rings now (a booster already opened drops out of a sealed_only step's).
func _rings_of(step: TutorialStep) -> Array[StringName]:
	var kept: Array[StringName] = []
	var board: StartBoard = _board_now()
	for id: StringName in step.rings:
		var booster: int = TutorialAnchors.index_of(id, TutorialAnchors.BOOSTER)
		if step.sealed_only and booster >= 0 and board != null:
			var boosters: Array[BoosterOpening] = board.store.boosters
			if booster < boosters.size() and boosters[booster].state != BoosterOpening.State.SEALED:
				continue
		kept.append(id)
	return kept


## Shows `step` on its screen's overlay.
func _show(step: TutorialStep) -> void:
	var on: TutorialOverlay = _overlay_for(step)
	if is_instance_valid(_showing) and _showing != on:
		_showing.clear()
	_showing = on
	_shown_index = _index
	if _shown_ms < 0:
		_shown_ms = Time.get_ticks_msec()
	on.anchors = _anchors(step)
	on.show_view(_view(step))


func _hide() -> void:
	# One at a time: the board's overlay is freed with its board, and a freed object can't enter a
	# typed array.
	if is_instance_valid(_overlay):
		_overlay.clear()
	if is_instance_valid(_board_overlay):
		_board_overlay.clear()
	_showing = null
	_shown_index = -1


## The step's view: its filled line, its rings (the act's CLICK tab), its locks (on the shift
## screen: the board draws its own), its side and its width.
func _view(step: TutorialStep) -> StepView:
	var line: String = TutorialText.fill(step.text, _values)
	var number: int = _index + 1
	var asks: bool = step.footer == TutorialStep.Footer.RING
	var view: StepView = StepView.guided(number, _guided.steps.size(), "", asks)
	view.body = TutorialText.markup(line)
	if step.footer == TutorialStep.Footer.GOT_IT:
		view.button = StepView.Action.GOT_IT
	var words: int = TutorialText.plain(line).split(" ", false).size()
	view.width = minf(BASE_WIDTH + WORD_WIDTH * words, MAX_WIDTH)
	view.side = _opening(step.side)
	var act: StringName = step.rings[step.act] if step.act >= 0 else &""
	var point: StringName = step.rings[step.point] if step.point < step.rings.size() else &""
	var rings: Array[StringName] = _rings_of(step)
	if not act.is_empty() and not rings.has(act) and not rings.is_empty():
		act = rings[0]  # The move's ring dropped out (G4's opened booster): the next one is it.
	for id: StringName in rings:
		view.ring(id, Rect2(), id == act)
	view.target = rings.find(point)
	if not _on_board(step):
		for id: StringName in step.locks:
			view.lock(id)
	return view


static func _opening(side: TutorialStep.CalloutSide) -> StepView.Opening:
	match side:
		TutorialStep.CalloutSide.LEFT:
			return StepView.Opening.LEFT
		TutorialStep.CalloutSide.RIGHT:
			return StepView.Opening.RIGHT
		TutorialStep.CalloutSide.ABOVE:
			return StepView.Opening.ABOVE
		TutorialStep.CalloutSide.BELOW:
			return StepView.Opening.BELOW
	return StepView.Opening.AUTO


func _anchors(step: TutorialStep) -> Callable:
	var board: StartBoard = _board_now()
	if _on_board(step) and board != null:
		return board.anchor_rect
	return _screen.anchor_rect


static func _on_board(step: TutorialStep) -> bool:
	return step.screen in [TutorialStep.Screen.START_STOCK, TutorialStep.Screen.START_BUILD]


## The shift screen's overlay, or the opening board's (each made on first use).
func _overlay_for(step: TutorialStep) -> TutorialOverlay:
	if _on_board(step) and _board_now() != null:
		if _board_overlay == null or not is_instance_valid(_board_overlay):
			_board_overlay = _new_overlay()
			_board.mount_overlay(_board_overlay)
		return _board_overlay
	if _overlay == null:
		_overlay = _new_overlay()
		_screen.guide.mount_overlay(_overlay)
	return _overlay


func _new_overlay() -> TutorialOverlay:
	var made: TutorialOverlay = TutorialOverlay.new()
	made.reduced_motion = func() -> bool: return _screen.profile.reduced_motion()
	made.button_pressed.connect(_on_button)
	return made


## A refused move: the callout's soft shake (its line stays).
func _refuse() -> void:
	if overlay() != null:
		overlay().refuse()


# --- Wiring -------------------------------------------------------------------------------


## The opening board shown now, or null.
func _board_now() -> StartBoard:
	var reveal: CartReveal = _screen._cart_reveal
	var board: StartBoard = reveal.board if reveal.is_open() else null
	return board if board != null and is_instance_valid(board) else null


## A new opening board: its hooks heard (its overlay is made when a step shows on it).
func _watch_board() -> void:
	var board: StartBoard = _board_now()
	if board == _board:
		return
	_board = board
	_board_overlay = null
	if board != null:
		board.guide_event.connect(_on_event)


## Takes (or lets go of) the gates and the holds: the shift screen's, the board's, the time
## card's and planning's notices'.
func _set_active(on: bool) -> void:
	if not on and not _active:
		return  # Never took them: a test's or a quick tutorial's gate stays.
	_active = on
	var gate: Callable = allows if on else Callable()
	_screen.guide.gate = gate
	_screen.guide.showing = (func() -> bool: return _active) if on else Callable()
	_screen._week.hold = (func() -> bool: return _active) if on else Callable()
	var choice: StartChoice = _screen._start_choice
	if choice != null:
		choice.guide_gate = gate
		choice.guide_locks = locks if on else Callable()
	if not on:
		_index = -1
		_hide()
