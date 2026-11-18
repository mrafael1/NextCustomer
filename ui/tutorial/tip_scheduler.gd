class_name TipScheduler
extends Node
## The one-time tips (T1-T16, data/tutorial/tips.tres; tutorial plan WP-10, decided with the user
## after play test 1 of 2026-11-15): each shows once per profile (TutorialFlags.tip(id), set and
## saved as it shows), the first time its trigger happens (TipTriggers), as a card that dims
## nothing and blocks nothing: "NEW · <title>", ONCE, its line, a ring on what it is about, MORE ›
## its HANDBOOK page when it has one, GOT IT. Play goes on around it.
##
## Where and when:
## - planning (min_shift and later): at most PER_PLANNING per planning, lower priority first,
##   while planning takes input; a planning tip closes when the planning ends. A miss forgiven by
##   the training week (T9), a perk (T11) or an IMPROVE (T12) taken at the machine wait for the
##   next planning;
## - the machine: a PREMIUM visit's (T8), once its keys are armed, before the draw;
## - the results: a lost run's (T14: the run's most WASTED giver card and the family it gives to,
##   else its fallback line) and a run end that pays coins (T15), one after the other;
## - the HANDBOOK (T16), on its own overlay over the book.
## Never during the guided part (the director holds the screen), and on the planning its last step
## closed only the tips whose trigger is in TutorialDirector.TIPS_AFTER_FINISH. A tip a guided
## run's planning hint stands for (PlanHint.covers_tip: T1 REDRAW, T10 MEDALS) waits out that
## run's first week, where the hint tells it when it happens (and marks it shown).

const PER_PLANNING := 2
## Tips by where they show.
const AT_MACHINE: Array[StringName] = [TipDefinition.PREMIUM_VISIT]
const AT_RESULTS: Array[StringName] = [TipDefinition.RUN_LOST, TipDefinition.COINS_PAID]
const AT_HANDBOOK: Array[StringName] = [TipDefinition.HANDBOOK_OPENED]
## Tips an event makes due for the next planning.
const LATER: Array[StringName] = [
	TipDefinition.FIRST_MISS, TipDefinition.PERK_TAKEN, TipDefinition.IMPROVE_TAKEN
]
## A card's width: as the director's (BASE_WIDTH + WORD_WIDTH per word, at most MAX_WIDTH).
const BASE_WIDTH := 230.0
const WORD_WIDTH := 5.0
const MAX_WIDTH := 380.0

var _screen: ShiftScreen
var _director: TutorialDirector
var _list: TipList
var _values: Dictionary = {}
## The overlays: the shift's (on the tutorial layer) and the HANDBOOK's (on the book).
var _overlay: TutorialOverlay
var _book_overlay: TutorialOverlay
## The tip showing (null: none), on which overlay, since when.
var _showing: TipDefinition
var _on: TutorialOverlay
## The planning (run seed, shift index) the count is for, and the tips shown on it.
var _planning: Array[int] = []
var _count: int = 0
## Triggers due by an event: the next planning's (LATER), the machine's and the results'.
var _due: Array[StringName] = []
## The run the tally is for (its seed), its WASTED cards (card id -> times), and the shift the
## guided part closed on (-1: none).
var _run_seed: int = 0
var _tally: Dictionary = {}
var _finished_shift: int = -1


## Adds the scheduler to `screen`, beside `director` (whose guided part it waits out).
func _init(screen: ShiftScreen, director: TutorialDirector) -> void:
	name = "TipScheduler"
	_screen = screen
	_director = director
	_list = TipList.shared()
	screen.add_child(self)
	screen.guide_event.connect(_on_event)
	director.finished.connect(func() -> void: _finished_shift = _screen.run.shift_index)


## The tip showing now, or null (tests).
func showing() -> TipDefinition:
	return _showing


## The overlay of the tip showing, or null (tests).
func overlay() -> TutorialOverlay:
	return _on if _showing != null and is_instance_valid(_on) else null


func _process(_delta: float) -> void:
	var run: RunState = _screen.run
	if run == null:
		return
	if run.run_seed != _run_seed:
		_run_seed = run.run_seed
		_tally.clear()
		_due.clear()
		_finished_shift = -1
	if _showing != null:
		if not _still_fits(_showing):
			_close()
		return
	if _director.is_active():
		return
	var next: TipDefinition = _next(run)
	if next != null:
		_show(next, run)


## The next tip due where the screen is now, or null.
func _next(run: RunState) -> TipDefinition:
	if _handbook_open():
		return _first_due(AT_HANDBOOK, run)
	if _screen._results.visible:
		return _first_due(AT_RESULTS, run)
	if _screen._machine.is_open():
		var armed: bool = _screen._machine.view.is_armed()
		return _first_due(AT_MACHINE, run) if armed else null
	if not _planning_free(run):
		return null
	var key: Array[int] = [run.run_seed, run.shift_index]
	if key != _planning:
		_planning = key
		_count = 0
	if _count >= PER_PLANNING:
		return null
	var found: Array[TipDefinition] = []
	for tip: TipDefinition in _list.tips:
		if _planning_due(tip, run):
			found.append(tip)
	found.sort_custom(
		func(a: TipDefinition, b: TipDefinition) -> bool: return a.priority < b.priority
	)
	return found[0] if not found.is_empty() else null


## The first tip of `triggers` an event made due and not seen yet.
func _first_due(triggers: Array[StringName], run: RunState) -> TipDefinition:
	for trigger: StringName in triggers:
		if not _due.has(trigger):
			continue
		for tip: TipDefinition in _list.for_trigger(trigger):
			if not _seen(tip) and not _held(tip, run):
				return tip
		_due.erase(trigger)
	return null


## Whether planning tip `tip` is due on the planning now.
func _planning_due(tip: TipDefinition, run: RunState) -> bool:
	if _seen(tip) or _held(tip, run) or run.shift_index + 1 < tip.min_shift:
		return false
	if LATER.has(tip.trigger):
		return _due.has(tip.trigger)
	return TipTriggers.planning_due(tip.trigger, run)


## Whether `tip` waits: on the planning the guided part closed on (all but TIPS_AFTER_FINISH), or
## in a guided run's first week while a planning hint stands for it.
func _held(tip: TipDefinition, run: RunState) -> bool:
	if not run.guided:
		return false
	var after: Array[StringName] = TutorialDirector.TIPS_AFTER_FINISH
	if run.shift_index == _finished_shift and not after.has(tip.trigger):
		return true
	if WeekSchedule.week_of(run.balance, run.shift_index + 1) > 0:
		return false
	for hint: PlanHint in TutorialScript.guided().hints:
		if hint.covers_tip == tip.id:
			return true
	return false


func _seen(tip: TipDefinition) -> bool:
	return TutorialFlags.tip_seen(_screen.profile, tip.id)


## Planning takes input: no count, glide, redraw, cart reveal, machine visit or cover.
func _planning_free(run: RunState) -> bool:
	var machine: MachineFlow = _screen._machine
	return (
		run.phase == RunState.Phase.PLANNING
		and not _screen._busy()
		and not _screen._redraw_busy
		and not _screen._cart_reveal.is_open()
		and not machine.is_open()
		and not machine.is_swapping()
		and not _screen.guide.overlay_covered()
	)


## Whether the screen `tip` shows on is still up (its planning, the machine, the results, the
## book).
func _still_fits(tip: TipDefinition) -> bool:
	if AT_HANDBOOK.has(tip.trigger):
		return _handbook_open()
	if AT_RESULTS.has(tip.trigger):
		return _screen._results.visible
	if AT_MACHINE.has(tip.trigger):
		return _screen._machine.is_open()
	var run: RunState = _screen.run
	return run.phase == RunState.Phase.PLANNING and [run.run_seed, run.shift_index] == _planning


func _show(tip: TipDefinition, run: RunState) -> void:
	if TutorialFlags.mark_tip(_screen.profile, tip.id):
		_screen.save_profile()
	_due.erase(tip.trigger)
	if not AT_HANDBOOK.has(tip.trigger) and not AT_RESULTS.has(tip.trigger):
		if not AT_MACHINE.has(tip.trigger):
			_count += 1
	if _values.is_empty():
		_values = TutorialText.values(TutorialScript.guided(), _screen._balance)
	_showing = tip
	_on = _book_overlay_now() if AT_HANDBOOK.has(tip.trigger) else _overlay_now()
	_on.show_view(_view(tip, run))
	_screen._log.log_event("tip_shown", RunEvents.tip_shown(tip.id))


func _view(tip: TipDefinition, run: RunState) -> StepView:
	var fills: Dictionary = _values.duplicate()
	var text: String = tip.text
	var rings: Array[StringName] = tip.rings.duplicate()
	match tip.trigger:
		TipDefinition.COUPON_IN_HAND:
			rings = [TutorialAnchors.indexed(TutorialAnchors.HAND, TipTriggers.coupon_place(run))]
		TipDefinition.FAMILY_RULE:
			var slot: int = TipTriggers.family_rule_slot(run)
			rings = [
				TutorialAnchors.indexed(TutorialAnchors.FAMILIES, slot),
				TutorialAnchors.indexed(TutorialAnchors.RULE, slot),
			]
		TipDefinition.MORNING_IN_ROW:
			var slots: PackedInt32Array = TipTriggers.morning_slots(run)
			fills.merge(
				TutorialText.morning_values(TipTriggers.names_at(run, slots.slice(1))), true
			)
			# The MORNING ZONE's spots on the belt (MorningBand's print).
			rings = []
			for slot: int in range(MorningBand.tiles(_screen._row_strip).size()):
				rings.append(TutorialAnchors.indexed(TutorialAnchors.SPOT, slot))
		TipDefinition.RUN_LOST:
			var fix: PackedStringArray = TipTriggers.lost_fix(
				_tally, ContentLookup.new(run.balance)
			)
			if fix.is_empty():
				text = tip.fallback_text
			else:
				fills[TutorialText.WASTED_CARD] = fix[0]
				fills[TutorialText.WASTED_FAMILY] = fix[1]
	var line: String = TutorialText.fill(text, fills)
	var page_name: String = _page_name(tip.more_page)
	var page: StringName = tip.more_page if not page_name.is_empty() else &""
	var view: StepView = StepView.tip(tip.title, TutorialText.markup(line), page_name, page)
	view.dim = false
	view.blocks = false
	var words: int = TutorialText.plain(line).split(" ", false).size()
	view.width = minf(BASE_WIDTH + WORD_WIDTH * words, MAX_WIDTH)
	view.side = TutorialDirector._opening(tip.side)
	for id: StringName in rings:
		view.ring(id)
	view.target = mini(tip.point, rings.size() - 1)
	return view


## A HANDBOOK page's title for MORE › (none for a toys book page or a page that is gone).
static func _page_name(page: StringName) -> String:
	if page.is_empty() or String(page).begins_with(TipDefinition.TOYS_PREFIX):
		return ""
	var entry: HandbookEntry = HandbookBook.shared().entry(page)
	return entry.title if entry != null else ""


func _close() -> void:
	_showing = null
	if is_instance_valid(_on):
		_on.clear()
	_on = null


func _overlay_now() -> TutorialOverlay:
	if not is_instance_valid(_overlay):
		_overlay = _new_overlay(_screen.anchor_rect)
		_screen.guide.mount_overlay(_overlay)
	return _overlay


## The HANDBOOK's own overlay (the shift's layer hides under the book).
func _book_overlay_now() -> TutorialOverlay:
	var book: HandbookPage = _screen.guide.watched_handbook()
	if not is_instance_valid(_book_overlay):
		_book_overlay = _new_overlay(book.anchor_rect)
		book.add_child(_book_overlay)
		_book_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _book_overlay


func _new_overlay(anchors: Callable) -> TutorialOverlay:
	var made: TutorialOverlay = TutorialOverlay.new()
	made.anchors = anchors
	made.reduced_motion = func() -> bool: return _screen.profile.reduced_motion()
	made.button_pressed.connect(_close)
	made.more_pressed.connect(_open_page)
	return made


## MORE ›: the tip closes and the HANDBOOK opens at its page.
func _open_page(page: StringName) -> void:
	_close()
	var book: HandbookPage = _screen.guide.watched_handbook()
	if book != null:
		book.open_at(page)


func _handbook_open() -> bool:
	var book: HandbookPage = _screen.guide.watched_handbook()
	return book != null and book.is_open()


## The screen's hooks: a checkout's WASTED cards tallied; the events that make a tip due.
func _on_event(event: StringName, args: Dictionary) -> void:
	var run: RunState = _screen.run
	if run == null:
		return
	match event:
		TutorialEvents.COUNT_FINISHED:
			if not run.history.is_empty():
				var played: Array[CardDefinition] = run.history[-1].played
				for card: CardDefinition in TipTriggers.wasted(run.last_result, played):
					_tally[card.id] = int(_tally.get(card.id, 0)) + 1
		TutorialEvents.MISS:
			if run.phase != RunState.Phase.LOST:
				_add(TipDefinition.FIRST_MISS)
		TutorialEvents.PERK_TAKEN:
			_add(TipDefinition.PERK_TAKEN)
		TutorialEvents.IMPROVE_TAKEN:
			_add(TipDefinition.IMPROVE_TAKEN)
		TutorialEvents.MACHINE_ARMED:
			if run.machine != null and run.machine.is_premium():
				_add(TipDefinition.PREMIUM_VISIT)
		TutorialEvents.RESULTS:
			if not bool(args.get(TutorialEvents.ARG_WON, false)):
				_add(TipDefinition.RUN_LOST)
			if int(args.get(TutorialEvents.ARG_COINS, 0)) > 0:
				_add(TipDefinition.COINS_PAID)
		TutorialEvents.HANDBOOK_OPENED:
			_add(TipDefinition.HANDBOOK_OPENED)


func _add(trigger: StringName) -> void:
	if not _due.has(trigger):
		_due.append(trigger)
