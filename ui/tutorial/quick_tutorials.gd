class_name QuickTutorials
extends Node
## The quick tutorials (SWAP, RESTOCK, BADGE PINS; tutorial plan WP-9, reworked after play test 1
## of 2026-11-15): on the opening board of any run that isn't in its guided part, the first time a
## mechanic is due (StartGuide: swap_due, restock_due, pins_due) and its flag isn't set
## (TutorialFlags.quick), its one callout shows over the board: "NEW · <title>", ONCE, its line,
## a ring on what unlocked, GOT IT. The flag is set and the profile saved as it shows. It closes
## on GOT IT or when the player makes the ringed move (its step's advance_on); a reveal or a slide
## hides it until the board is free again. Nothing is gated: the player then does it freely, and
## the tutorial's hints (QuickHint) pop in a HintBubble the first time each moment comes on that
## board. One callout at a time, in play order (SWAP, RESTOCK, BADGE PINS). Each closed callout
## logs a quick_step, as the plan's.

## A callout's width: as the director's (BASE_WIDTH + WORD_WIDTH per word, at most MAX_WIDTH).
const BASE_WIDTH := 230.0
const WORD_WIDTH := 5.0
const MAX_WIDTH := 380.0

var _screen: ShiftScreen
## Whether the guided run's director holds the board now (no quick tutorial then).
var _guided: Callable
var _values: Dictionary = {}
## The board shown now, and what was made on it (freed with it).
var _board: StartBoard
var _overlay: TutorialOverlay
var _tips: Control
var _bubble: HintBubble
## The tutorial whose callout shows (null: none), since when (msec).
var _showing: QuickTutorial
var _shown_ms: int = 0
## The tutorials whose callout showed on this board: their hints are live.
var _live: Array[QuickTutorial] = []
var _hints_shown: Array[StringName] = []


## Adds the quick tutorials to `screen`; `guided` (Callable() -> bool) says whether the guided
## run's director holds the board.
func _init(screen: ShiftScreen, guided: Callable) -> void:
	name = "QuickTutorials"
	_screen = screen
	_guided = guided
	screen.add_child(self)


## The tutorial whose callout shows now, or null (tests).
func showing() -> QuickTutorial:
	return _showing if _overlay != null and is_instance_valid(_overlay) else null


## The callout's overlay, or null before the first (tests).
func overlay() -> TutorialOverlay:
	return _overlay if is_instance_valid(_overlay) else null


## The hints' bubble, or null before the first hint (tests).
func bubble() -> HintBubble:
	return _bubble if is_instance_valid(_bubble) else null


func _process(_delta: float) -> void:
	var board: StartBoard = _board_now()
	if board != _board:
		_watch(board)
	if board == null:
		return
	if bool(_guided.call()):
		_clear()
		return
	var guide: StartGuide = StartGuide.new(board)
	if _showing != null:
		if _blocked(guide, _showing):
			_overlay.clear()  # A reveal or the slide: back when the board is free.
		elif not _overlay.is_showing():
			_show(_showing)
		return
	for each: QuickTutorial in QuickTutorial.all():
		if TutorialFlags.quick_seen(_screen.profile, each.id) or _blocked(guide, each):
			continue
		if _due(guide, each):
			_start(each)
			return


func _board_now() -> StartBoard:
	var reveal: CartReveal = _screen._cart_reveal
	var board: StartBoard = reveal.board if reveal.is_open() else null
	return board if board != null and is_instance_valid(board) else null


## A new board (or none): what was made on the old one went with it.
func _watch(board: StartBoard) -> void:
	_board = board
	_overlay = null
	_tips = null
	_bubble = null
	_showing = null
	_live.clear()
	_hints_shown.clear()
	if board != null:
		board.guide_event.connect(_on_event)


## Whether `tutorial`'s callout must wait (BADGE PINS has its own rule: StartGuide.pins_blocked).
static func _blocked(guide: StartGuide, tutorial: QuickTutorial) -> bool:
	if tutorial.trigger == QuickTutorial.PINS_EARNED:
		return guide.pins_blocked()
	return guide.blocked()


static func _due(guide: StartGuide, tutorial: QuickTutorial) -> bool:
	match tutorial.trigger:
		QuickTutorial.SWAP_UNLOCKED:
			return guide.swap_due()
		QuickTutorial.RESTOCK_UNLOCKED:
			return guide.restock_due()
		QuickTutorial.PINS_EARNED:
			return guide.pins_due()
	return false


## Shows `tutorial`'s callout for the first time: its flag set, the profile saved.
func _start(tutorial: QuickTutorial) -> void:
	if TutorialFlags.mark_quick(_screen.profile, tutorial.id):
		_screen.save_profile()
	if _values.is_empty():
		_values = TutorialText.values(TutorialScript.guided(), _screen._balance)
	_showing = tutorial
	_shown_ms = Time.get_ticks_msec()
	_live.append(tutorial)
	_show(tutorial)


func _show(tutorial: QuickTutorial) -> void:
	if not is_instance_valid(_overlay):
		_overlay = TutorialOverlay.new()
		_overlay.reduced_motion = func() -> bool: return _screen.profile.reduced_motion()
		_overlay.button_pressed.connect(_close)
		_board.mount_overlay(_overlay)
	_overlay.anchors = _board.anchor_rect
	_overlay.show_view(_view(tutorial, tutorial.steps[0]))


func _view(tutorial: QuickTutorial, step: TutorialStep) -> StepView:
	var line: String = TutorialText.fill(step.text, _values)
	var view: StepView = StepView.tip(tutorial.title, TutorialText.markup(line), "", &"")
	var words: int = TutorialText.plain(line).split(" ", false).size()
	view.width = minf(BASE_WIDTH + WORD_WIDTH * words, MAX_WIDTH)
	view.side = TutorialDirector._opening(step.side)
	for index: int in step.rings.size():
		view.ring(step.rings[index], Rect2(), index == step.act)
	view.target = mini(step.point, step.rings.size() - 1)
	view.pass_through(TutorialAnchors.TITLE)
	return view


## The callout closes (GOT IT, or its move made): logged; its hints stay live.
func _close() -> void:
	if _showing == null:
		return
	var seconds: float = (Time.get_ticks_msec() - _shown_ms) / 1000.0
	var step: TutorialStep = _showing.steps[0]
	_screen._log.log_event("quick_step", RunEvents.quick_step(_showing.id, step.id, seconds))
	_showing = null
	if is_instance_valid(_overlay):
		_overlay.clear()


## A board hook: the callout's move closes it; a live tutorial's hint pops (each once).
func _on_event(event: StringName, args: Dictionary) -> void:
	if _showing != null and _showing.steps[0].advance_on == event:
		_close()
	for tutorial: QuickTutorial in _live:
		for hint: QuickHint in tutorial.hints:
			if not _hints_shown.has(hint.id) and hint.fires_on(event, args):
				_pop(hint, hint.anchor_for(args))
				return


func _pop(hint: QuickHint, anchor: StringName) -> void:
	_hints_shown.append(hint.id)
	if not is_instance_valid(_tips):
		_tips = Control.new()
		_tips.name = "QuickTips"
		_tips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.mount_overlay(_tips)
		_bubble = HintBubble.new()
		_tips.add_child(_bubble)
	var board: StartBoard = _board
	var target: Callable = func() -> Rect2: return board.anchor_rect(anchor)
	var body: String = TutorialText.markup(TutorialText.fill(hint.text, _values))
	_bubble.pop(hint.title, body, target, _screen.profile.reduced_motion())
	_screen._log.log_event("tutorial_hint", RunEvents.tutorial_hint(hint.id))


## The guided run holds the board: nothing of ours shows.
func _clear() -> void:
	if is_instance_valid(_overlay):
		_overlay.clear()
	if is_instance_valid(_bubble):
		_bubble.clear()
