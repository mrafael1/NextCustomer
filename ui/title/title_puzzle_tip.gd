class_name TitlePuzzleTip
extends Node
## The puzzles' unlock tip on the title (#183 polish 5, play test 2026-11-23): the one-time tip
## T17 (data/tutorial/tips.tres, trigger TipDefinition.PUZZLES_OFFERED), shown with the tips'
## own card and ring (TutorialOverlay, as TipScheduler shows them on the shift screen: dims
## nothing, blocks nothing, GOT IT) the first time the title offers puzzles (the profile has
## finished a run), its ring on the puzzle planner (TutorialAnchors.TITLE_PUZZLES), the card
## opening left of it. It waits while `blocked` says so (the intro, a popup, G1); it is marked
## seen (TutorialFlags.mark_tip, the saved profile saved) as it shows, and closes on GOT IT or as
## soon as the title is busy (the planner pressed opens the board). Logged as tip_shown.

const TIP_ID := &"T17"

## Returns true while the tip must wait (the title's intro, a popup, G1). None: never.
var blocked: Callable = Callable()
## Callable(StringName): marks tip `id` seen on the profile and saves it (the title's).
var mark_seen: Callable = Callable()

var _title: TitleScreen
var _overlay: TutorialOverlay
var _tip: TipDefinition
var _showing: bool = false
var _done: bool = false


## The tip for `title` (mounted over it once it shows); `reduced`: Callable() -> bool.
func _init(title: TitleScreen, reduced: Callable) -> void:
	name = "TitlePuzzleTip"
	_title = title
	_tip = TipList.shared().tip(TIP_ID)
	_overlay = TutorialOverlay.new()
	_overlay.anchors = title.anchor_rect
	_overlay.reduced_motion = reduced
	_overlay.button_pressed.connect(close)
	title.add_child(self)
	title.add_child(_overlay)


## Whether the tip's card shows now.
func is_showing() -> bool:
	return _showing


func overlay() -> TutorialOverlay:
	return _overlay


## GOT IT, or the title turned busy: the tip goes for good.
func close() -> void:
	_showing = false
	_done = true
	_overlay.clear()


func _process(_delta: float) -> void:
	if _done or _tip == null:
		return
	var held: bool = blocked.is_valid() and bool(blocked.call())
	if _showing:
		if held:
			close()
		return
	if not held and _title.anchor_rect(TutorialAnchors.TITLE_PUZZLES).has_area():
		_show()


func _show() -> void:
	_showing = true
	if mark_seen.is_valid():
		mark_seen.call(_tip.id)
	var line: String = TutorialText.markup(_tip.text)
	var view: StepView = StepView.tip(_tip.title, line, "", &"")
	view.dim = false
	view.blocks = false
	var words: int = TutorialText.plain(_tip.text).split(" ", false).size()
	view.width = minf(
		TipScheduler.BASE_WIDTH + TipScheduler.WORD_WIDTH * words, TipScheduler.MAX_WIDTH
	)
	view.side = TutorialDirector._opening(_tip.side)
	for id: StringName in _tip.rings:
		view.ring(id)
	_overlay.show_view(view)
