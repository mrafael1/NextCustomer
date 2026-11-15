class_name StepView
extends RefCounted
## What the tutorial overlay shows for one step (tutorial plan section 2, WP-2; mock-up
## docs/art/mockups/tutorial.html): the callout's header, count, body and footer, the rings, the
## locked plates and the side the callout opens on. The director (or a quick tutorial, or the tip
## scheduler) fills one from a step's data; TutorialOverlay draws it. It knows nothing of the game:
## each ring and lock names a TutorialAnchors id, resolved through the overlay's `anchors`
## Callable (a screen's `anchor_rect`), or carries a fixed global rect.
##
## - kind: GUIDED (mustard band, "YOUR MOVE" on a step that asks for a move, "TIP" otherwise,
##   "n/26"), TIP (a one-time tip: mustard band, "NEW · TITLE", "ONCE") or QUICK (a quick
##   tutorial: teal-light band, "NEW · TITLE", "n/total").
## - body: TipMarkup (chips, money, terms), already filled (TutorialText).
## - button: the callout's key (NEXT ›, GOT IT) or none; a step with an act ring and no key shows
##   the cream "CLICK THE RING" hint in its place.
## - more: the MORE › link's words (a handbook page's name) and its page id; never on a guided step.
## - rings: the highlights (each a hole in the dim that lets clicks through); `act` is the ring of
##   the move (its "CLICK" tab), -1 for none; `target` is the ring the callout's tail points at
##   (-1: the act ring, else the first).
## - locks: LOCKED plates (a grey veil, a padlock and its label) over what the step blocks.
## - clear: what the callout keeps clear besides the rings (the belt items a line is about); the
##   callout covers it only when no side clears it.
## - passes: what a click reaches through the dim with no ring (still dimmed): the shift screen's
##   menu, the opening board's ‹ TITLE, so a mouse can always pause or leave.
## - side: where the callout opens from its target (AUTO: below, else above, else beside).
## - width: the callout's width in canvas px before the text size (0: DEFAULT_WIDTH).
## - dim: whether the screen is dimmed around the rings (the shade takes the clicks either way).

enum Kind { GUIDED, TIP, QUICK }
enum Action { NONE, NEXT, GOT_IT }
enum Opening { AUTO, BELOW, ABOVE, RIGHT, LEFT }

## The callout's chrome words (tutorial plan section 9).
const YOUR_MOVE := "YOUR MOVE"
const TIP_HEAD := "TIP"
const NEW_HEAD := "NEW · %s"
const ONCE := "ONCE"
const COUNT := "%d/%d"
const NEXT_CAPTION := "NEXT ›"
const GOT_IT_CAPTION := "GOT IT"
const CLICK_HINT := "CLICK THE RING"
const MORE_LINK := "MORE › %s"
const LOCKED := "LOCKED"
const RING_TAB := "CLICK"
const DEFAULT_WIDTH := 320.0

var kind: Kind = Kind.GUIDED
var header: String = ""
var count: String = ""
var body: String = ""
var button: Action = Action.NEXT
var more_label: String = ""
var more_page: StringName = &""
var rings: Array[Mark] = []
var act: int = -1
var target: int = -1
var locks: Array[Mark] = []
var clear: Array[Mark] = []
var passes: Array[Mark] = []
var side: Opening = Opening.AUTO
var width: float = 0.0
var dim: bool = true


## A ring or a lock: a TutorialAnchors id (resolved live) or a fixed global rect, and a lock's
## label.
class Mark:
	extends RefCounted
	var id: StringName = &""
	var rect: Rect2 = Rect2()
	var label: String = ""

	func _init(mark_id: StringName, mark_rect: Rect2, mark_label: String) -> void:
		id = mark_id
		rect = mark_rect
		label = mark_label


## Guided step `number` of `total` (1-based): YOUR MOVE when it asks for a move (no key: the
## ring is the move), else TIP with NEXT ›, or GOT IT on the last step.
static func guided(number: int, total: int, text: String, asks_move: bool) -> StepView:
	var view: StepView = StepView.new()
	view.kind = Kind.GUIDED
	view.header = YOUR_MOVE if asks_move else TIP_HEAD
	view.count = COUNT % [number, total]
	view.body = text
	if asks_move:
		view.button = Action.NONE
	else:
		view.button = Action.GOT_IT if number >= total else Action.NEXT
	return view


## A one-time tip: NEW · TITLE, ONCE, GOT IT, and MORE › `page_name` when it has a page.
static func tip(title: String, text: String, page_name: String, page: StringName) -> StepView:
	var view: StepView = StepView.new()
	view.kind = Kind.TIP
	view.header = NEW_HEAD % title.to_upper()
	view.count = ONCE
	view.body = text
	view.button = Action.GOT_IT
	view.more_label = page_name
	view.more_page = page
	return view


## Quick tutorial step `number` of `total`: NEW · TITLE, n/total, MORE › its page; no key when it
## asks for a move, else NEXT › or GOT IT on the last.
static func quick(
	title: String,
	number: int,
	total: int,
	text: String,
	asks_move: bool,
	page_name: String,
	page: StringName
) -> StepView:
	var view: StepView = tip(title, text, page_name, page)
	view.kind = Kind.QUICK
	view.count = COUNT % [number, total]
	if asks_move:
		view.button = Action.NONE
	else:
		view.button = Action.GOT_IT if number >= total else Action.NEXT
	return view


## Adds a ring on anchor `id` (or at the global `rect` when the id is empty or not shown); `is_act`
## makes it the move's ring. Returns the view, to chain.
func ring(id: StringName, rect: Rect2 = Rect2(), is_act: bool = false) -> StepView:
	if is_act:
		act = rings.size()
	rings.append(Mark.new(id, rect, ""))
	return self


## Adds a LOCKED plate (`label`) on anchor `id` (or at the global `rect`). Returns the view.
func lock(id: StringName, rect: Rect2 = Rect2(), label: String = LOCKED) -> StepView:
	locks.append(Mark.new(id, rect, label))
	return self


## Keeps the callout off anchor `id` (or the global `rect`). Returns the view.
func keep_clear(id: StringName, rect: Rect2 = Rect2()) -> StepView:
	clear.append(Mark.new(id, rect, ""))
	return self


## Lets clicks through the dim to anchor `id` (or the global `rect`), with no ring. Returns the
## view.
func pass_through(id: StringName, rect: Rect2 = Rect2()) -> StepView:
	passes.append(Mark.new(id, rect, ""))
	return self


## The callout's key caption ("" for none).
func button_caption() -> String:
	match button:
		Action.NEXT:
			return NEXT_CAPTION
		Action.GOT_IT:
			return GOT_IT_CAPTION
	return ""


## The footer hint: CLICK THE RING on a step with an act ring and no key, else "".
func hint() -> String:
	return CLICK_HINT if button == Action.NONE and act >= 0 else ""


## The MORE › link's words, or "" (never on a guided step).
func more_text() -> String:
	if kind == Kind.GUIDED or more_label.is_empty():
		return ""
	return MORE_LINK % more_label.to_upper()


## The index of the ring the tail points at (-1: none).
func target_index() -> int:
	if rings.is_empty():
		return -1
	if target >= 0 and target < rings.size():
		return target
	return act if act >= 0 and act < rings.size() else 0


## The global rect of `mark` now: its anchor's through `anchors` (a Callable(StringName) ->
## Rect2, may be null) when that is shown, else its fixed rect.
static func resolve(mark: Mark, anchors: Callable) -> Rect2:
	if not mark.id.is_empty() and anchors.is_valid():
		var found: Variant = anchors.call(mark.id)
		if found is Rect2 and (found as Rect2).has_area():
			return found
	return mark.rect
