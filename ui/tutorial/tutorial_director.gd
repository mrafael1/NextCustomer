class_name TutorialDirector
extends Node
## The guided first run's director (tutorial plan sections 1.5 and 1.6, WP-8; mock-up
## docs/art/mockups/tutorial.html, its GUIDED steps; reworked after play test 1, 2026-11-15): a
## part of the shift screen that plays the guided script (data/tutorial/guided.tres, G2..G14; G1
## is the title's, TitleGuide) on a run
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
## - shift 1's free step (TutorialStep.is_free) shows no line: the player builds the row as they
##   like. After each placement a reactive hint may pop over an item (PlanHint.pick, a
##   HintBubble, each once per run: RunState.guide_hints). A CHECKOUT under the quota there is a
##   rehearsal (rehearses): the count plays, then the shift screen puts planning back as it was
##   and calls retry, which shows the script's retry line, or from the ANSWER_AFTER-th miss on
##   its answer line, the row back in the baskets as dealt (any redraw undone) and the answer's
##   ghosts on the belt (AnswerGhosts). REDRAW is allowed, its first use pops a hint too; the
##   row's total reaching the quota, then the SILVER and GOLD medals' totals, pops theirs. The
##   hints stay live on every planning of the run's first week once the guided part is over
##   (play test feedback, 2026-11-15): one not reached yet (a redraw, SILVER, GOLD) pops the
##   first time it is;
## - the game's state moves it on too (a resume, a booster opened with OPEN ALL): page 2 shown, a
##   pack picked, the machine's phases, the next shift.
##
## A step shows once its screen does (the board's page with nothing playing on it, planning
## taking input, the machine's keys or prizes armed, shift 2's planning) and one of its rings is
## on screen; it hides while it can't (a booster opening, the count-up, the machine's glide). The
## time card waits through shift 1 (WeekFlow.hold) and opens for G13 on shift 2; planning's
## notices and the calendar's page change wait until G14 closes. After G14 the run plays on as
## any other, `finished` goes out, and the one-time tips (WP-10) may follow: only
## TIPS_AFTER_FINISH on that planning (decided with the user, 2026-11-14).

## The guided run's last step closed (G14): the done flag is set, the run plays on.
signal finished

## The guide_step of a guided run whose guided part is over (G14 closed).
const DONE := &"done"
## The one-time tips that may follow G14 on the same planning (WP-10's scheduler reads it).
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
## What a click always reaches through the dim, on every guided step (no ring, still dimmed): the
## shift screen's menu (the pause, the options, QUIT TO TITLE) and the opening board's ‹ TITLE,
## so a mouse can pause or leave as Esc can.
const PASSES: Array[StringName] = [TutorialAnchors.MENU]
const BOARD_PASSES: Array[StringName] = [TutorialAnchors.TITLE]
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
## The free planning's extra line showing over the free step (the script's retry or answer
## step; null: none) and the rehearsals missed, kept for the run `_rehearsed` (its seed: a
## rehearsal's restore attaches the same run again).
var _extra: TutorialStep
var _misses: int = 0
var _rehearsed: int = 0
## A move left hints to check once the bubble is gone (one waiting behind the one shown).
var _waiting: bool = false
## The free planning as dealt (its first free frame: the row empty, no redraw yet; RunSave form):
## the answer puts it back, so a redraw never strands the answer's cards.
var _dealt: Dictionary = {}
## The reactive hints' bubble and the answer's ghosts (made on first use, on the guide layer).
var _bubble: HintBubble
var _ghosts: AnswerGhosts


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
	if _rehearsed != _run.run_seed:
		_rehearsed = _run.run_seed
		_misses = 0
		_dealt = {}
		_began_ms = Time.get_ticks_msec()
	_set_active(true)
	_go(_resume_index(), false)


## Whether the guided part of the screen's run is on.
func is_active() -> bool:
	return _active


## The current step's id (&"" when the guided part isn't on).
func step_id() -> StringName:
	return _step().id if _active and _step() != null else &""


## The id of the line showing or due now: the free planning's retry or answer line over its
## step, else the step's (&"" when the guided part isn't on).
func line_id() -> StringName:
	return _extra.id if _active and _extra != null else step_id()


## The overlay showing the step now, or null (tests, captures).
func overlay() -> TutorialOverlay:
	return _showing if is_instance_valid(_showing) and _showing.is_showing() else null


## Whether a CHECKOUT now is a rehearsal: the guided shift's free step, where a miss puts
## planning back (the shift screen asks before it checks out).
func rehearses() -> bool:
	var step: TutorialStep = _step()
	if not _active or step == null or not step.is_free():
		return false
	return _run.phase == RunState.Phase.PLANNING and _run.shift_index == 0


## A rehearsal missed with `total`: planning is back (the shift screen restored it and attached).
## The retry line shows, or from the ANSWER_AFTER-th miss the answer's, its row back in the
## baskets and the answer's ghosts on the belt.
func retry(total: int) -> void:
	_misses += 1
	_values[TutorialText.MISSED] = str(total)
	var free: int = _guided.free_index()
	if free >= 0:
		_go(free, false)
	var answer: bool = _misses >= TutorialScript.ANSWER_AFTER and not _guided.answer.is_empty()
	if answer and (_dealt.is_empty() or not _restore(_dealt)):
		for card: CardInstance in _run.row.duplicate():
			_run.remove(card)  # No dealt planning to put back (a resume): the row empties.
	if answer and free >= 0:
		_go(free, false)
	_extra = _guided.answer_step if answer else _guided.retry
	if answer:
		_show_ghosts()
	_screen._log.log_event("tutorial_retry", RunEvents.tutorial_retry(total, _misses, answer))


## The run now in its saved form (RunSave), to put back if the rehearsal misses.
func snapshot() -> Dictionary:
	var played: int = Time.get_ticks_msec() - _screen._run_started_ms
	return RunSave.to_dictionary(_run, _screen._log.run_id, played)


## A missed rehearsal counted: planning comes back as it was before the CHECKOUT (`saved`, read
## back as a save is) and the retry line shows (retry). False when it can't be read back (the
## shift then goes on as any miss).
func put_back(saved: Dictionary, total: int) -> bool:
	if not _restore(saved):
		return false
	_screen._cabinet.set_total_down(false)
	_screen._stage.dim_hand(false)
	retry(total)
	_screen._refresh()
	_screen._save_run()
	return true


## Puts the run `saved` (RunSave form) on the screen and plays it; false when it can't be read
## back or isn't planning.
func _restore(saved: Dictionary) -> bool:
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	if not parsed is Dictionary:
		return false
	var lookup: ContentLookup = ContentLookup.new(_screen._balance)
	var restored: RunSave = RunSave.from_dictionary(parsed as Dictionary, lookup)
	if restored == null or restored.run.phase != RunState.Phase.PLANNING:
		return false
	restored.run.guide_hints = _run.guide_hints.duplicate()  # A hint shown stays shown.
	_screen._close_overlays()
	_screen.run = restored.run
	attach()
	return true


## The rehearsals missed this run (tests, captures).
func misses() -> int:
	return _misses


## The hint bubble, or null before its first hint (tests, captures).
func bubble() -> HintBubble:
	return _bubble


## The answer's ghosts, or null before the answer (tests, captures).
func ghosts() -> AnswerGhosts:
	return _ghosts


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
		if _run != null:
			_follow_free(null)  # The first week's hints after the guided part.
		return
	_watch_board()
	_sync()
	if not _active:
		return
	var step: TutorialStep = _step()
	_open_card(step)
	_follow_free(step)
	var shown: TutorialStep = _extra if _extra != null else step
	if _ready_for(shown):
		if _shown_index != _index or overlay() == null:
			_show(shown)
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
	_extra = null
	_heard = 0
	_shown_ms = -1
	_card_opened = false
	_run.guide_step = _step().id
	_hide()
	if _run.phase == RunState.Phase.PLANNING:
		_screen._refresh_buttons()  # CHECKOUT's key follows the gate.


## The step's key (NEXT ›, GOT IT) moves it on when it may.
func _on_button() -> void:
	if _extra != null:
		_extra = null  # The retry or answer line read: the free planning goes on.
		_hide()
		return
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
	_clear_free()
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
	if _hinting() and event == TutorialEvents.CARD_PLACED:
		_hint_after(int(args.get(TutorialEvents.ARG_INSTANCE, 0)))
	if _hinting() and event == TutorialEvents.REDRAW_DONE:
		_pop(PlanHint.pick_redrawn(_guided.hints, _run.guide_hints))
	var step: TutorialStep = _step()
	if not _active or step == null:
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


# --- The state ----------------------------------------------------------------------------


## The step a resumed (or newly attached) run plays from: its saved step, or the first one the
## game's state allows when that is later.
func _resume_index() -> int:
	var saved: int = _guided.index_of(_run.guide_step)
	var least: int = _least_index()
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


# --- The free planning (shift 1) and the first week's hints --------------------------------


## Whether the reactive hints are live: the guided run's planning in its first week, on shift 1's
## free step or once the guided part is over (no line of it to show).
func _hinting() -> bool:
	if _run == null or not _run.guided or _run.phase != RunState.Phase.PLANNING:
		return false
	if WeekSchedule.week_of(_run.balance, _run.shift_index + 1) > 0:
		return false
	if _active:
		var step: TutorialStep = _step()
		return step != null and step.is_free()
	return _run.guide_step == DONE


## After `instance` was placed on the free step (0: none, a waiting hint's check): the hint
## PlanHint.pick finds, in the bubble; another may wait behind it (_waiting).
func _hint_after(instance: int) -> void:
	var placed: CardInstance = null
	for card: CardInstance in _run.row:
		if card.instance_id == instance:
			placed = card
	_waiting = false
	var full: bool = (
		_run.row.size() >= RowCapacity.card_limit(_run.limits) and not _run.hand().is_empty()
	)
	var found: PlanHint.Pick = PlanHint.pick(
		_guided.hints, _run.row, _run.preview(), placed, _totals(), full, _run.guide_hints
	)
	_pop(found)
	_waiting = found != null


## The quota, then the SILVER and GOLD medals' totals (the machine's laps times the quota).
func _totals() -> Array[int]:
	var quota: int = _run.quota()
	var machine: MachineDefinition = _run.balance.machine
	if machine == null:
		return [quota]
	return [quota, quota * machine.overtime_ticket_laps, quota * machine.overtime_premium_laps]


## Shows `found` (null: nothing) in the bubble, once, and logs it.
func _pop(found: PlanHint.Pick) -> void:
	if found == null:
		return
	_run.guide_hints.append(found.hint.id)
	var slot: int = found.slot
	var anchor: StringName = found.anchor
	var target: Callable = func() -> Rect2: return _hint_target(slot, anchor)
	var body: String = TutorialText.markup(TutorialText.fill(found.hint.text, _values))
	_bubble_now().pop(found.hint.title, body, target, _screen.profile.reduced_motion())
	_screen._log.log_event("tutorial_hint", RunEvents.tutorial_hint(found.hint.id))
	if not _screen._busy():
		_screen._save_run()  # A resume never shows it twice.


## A hint's target: the row slot's whole spot, or its anchor (PlanHint.NO_SLOT).
func _hint_target(slot: int, anchor: StringName) -> Rect2:
	if slot == PlanHint.NO_SLOT:
		return _screen.anchor_rect(anchor)
	return _screen.anchor_rect(StringName(TutorialAnchors.SPOT + str(slot)))


## Slot `slot`'s belt cell, for its answer ghost (null when the row has no such slot).
func _slot_cell(slot: int) -> Control:
	return _screen._slots[slot] if slot < _screen._slots.size() else null


## The bubble shows only while the hints are live (_hinting) and planning takes input; the ghosts
## only on the free step.
func _follow_free(step: TutorialStep) -> void:
	var hinting: bool = _hinting()
	var free: bool = hinting and _planning_free() and not _screen.guide.overlay_covered()
	# The bubble stays through a redraw's motion (its hint is about it), not through the count.
	if is_instance_valid(_bubble) and not (hinting and not _screen._busy()):
		_bubble.clear()
	var on_free: bool = free and step != null and step.is_free()
	if on_free and _dealt.is_empty() and _run.row.is_empty() and _run.redraws_used == 0:
		_dealt = snapshot()
	if free and _waiting and _extra == null and not _bubble_now().visible:
		_hint_after(0)
	if not is_instance_valid(_ghosts):
		return
	_ghosts.visible = on_free and _misses >= TutorialScript.ANSWER_AFTER
	if _ghosts.visible:
		_ghosts.follow(_slot_cell, _run.row)


func _show_ghosts() -> void:
	var cards: Array[CardDefinition] = []
	var lookup: ContentLookup = ContentLookup.new(_screen._balance)
	for card_id: StringName in _guided.answer:
		var card: CardDefinition = lookup.card(String(card_id))
		if card != null:
			cards.append(card)
	if not is_instance_valid(_ghosts):
		_ghosts = AnswerGhosts.new()
		_mount(_ghosts)
	_ghosts.show_answer(cards, _screen._balance)


func _bubble_now() -> HintBubble:
	if not is_instance_valid(_bubble):
		_bubble = HintBubble.new()
		_mount(_bubble)
	return _bubble


## Puts `part` on the shift screen's tutorial layer (made with the overlay), over the overlay.
func _mount(part: Control) -> void:
	if _overlay == null:
		_overlay = _new_overlay()
		_screen.guide.mount_overlay(_overlay)
	_screen.guide.layer().add_child(part)


func _clear_free() -> void:
	_extra = null
	if is_instance_valid(_bubble):
		_bubble.clear()
	if is_instance_valid(_ghosts):
		_ghosts.visible = false


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
			shown = planning and run.shift_index == 0 and not step.is_free()
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
	for id: StringName in step.keep_clear:
		view.keep_clear(id)
	for id: StringName in BOARD_PASSES if _on_board(step) else PASSES:
		view.pass_through(id)
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
		_clear_free()
		_hide()
