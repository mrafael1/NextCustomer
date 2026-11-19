class_name ReceiptPrizeTags
extends Control
## The receipt's prize tags (v1.40, the user's verdict of 2026-11-18 on mock-up
## docs/art/mockups/medal_prizes.html, variant A): when a checkout wins a week medal, a small tag
## naming its prize is stapled ON the paper's foot (PrizeTagArt: "+1 DRAW" for the SILVER,
## "PREMIUM" for the GOLD, each with its medal embossed), inside the paper, never beside it (the
## user's 2026-11-06 removal of the foot's overtime ticket and of the slips beside the receipt).
## The paper still turns silver or gold (ReceiptGold); the tag says what that metal pays, and
## rides the paper into the prize machine, where it comes off (take(); MachineTags).
##
## The tags own a BAND px band at the paper's foot, under its lines: while a tag is on, the paper's
## bottom content margin grows by it (so a short paper is that much longer and a full one scrolls
## its lines above it), and the tags stand in it from the right, the +1 DRAW first, GAP apart. A
## stapled tag pops in from POP_FROM of its size over POP_SECONDS after its `delay` (the metal's
## wipe reaching the foot); `instant` (reduced motion, a resume) shows it at rest. A child of the
## paper (a PanelContainer fits it to its content), drawn over its lines. Display only.

## A tag's state: not there, stapled on, or taken off by the machine (its band stays).
enum State { OFF, ON, TAKEN }

## Px per art px (the receipt's).
const CELL := float(ArtStyle.ART_SCALE)
## The foot band the tags stand in (px): a tag, its staple's rise and a gap over it.
const BAND := 24.0
## A tag's foot stands this far over the band's (px).
const FOOT_GAP := 2.0
## The tags' gap from the paper's right content edge and between two tags (px).
const SIDE := 2.0
const GAP := 6.0
## The pop: from POP_FROM of its size past 1 and back (a back ease, overshoot POP_BACK).
const POP_SECONDS := 0.22
const POP_FROM := 1.7
const POP_BACK := 1.7
## The paper's own bottom margin, kept on its stylebox while the band is added to it.
const BASE_META := &"prize_tags_base"

var _paper: PanelContainer
## [SILVER's +1 DRAW, GOLD's PREMIUM].
var _states: Array[int] = [State.OFF, State.OFF]
## Each tag's pop clock (s): below 0 while it waits its delay, POP_SECONDS and more at rest.
var _pops: Array[float] = [POP_SECONDS, POP_SECONDS]


## The tags of `paper` (a ReceiptView; its child).
func _init(paper: PanelContainer) -> void:
	name = "PrizeTags"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper = paper
	_paper.resized.connect(queue_redraw)
	set_process(false)


## Staples medal `gold`'s tag on: it pops in after `delay` s (`instant`: at rest at once).
func staple(gold: bool, instant: bool, delay: float = 0.0) -> void:
	var index: int = 1 if gold else 0
	if _states[index] == State.ON:
		return
	_states[index] = State.ON
	_pops[index] = POP_SECONDS if instant else -maxf(delay, 0.0)
	_refresh()


## Shows the tags as a checked-out shift left them, at rest: the +1 DRAW (`extra`) and the
## PREMIUM (`premium`). A tag the machine took stays off the paper.
func show_tags(extra: bool, premium: bool) -> void:
	var wanted: Array[bool] = [extra, premium]
	for index: int in range(2):
		if not wanted[index]:
			_states[index] = State.OFF
		elif _states[index] == State.OFF:
			_states[index] = State.ON
		_pops[index] = POP_SECONDS
	_refresh()


## The machine takes medal `gold`'s tag off the paper (its place in the band stays empty).
func take(gold: bool) -> void:
	var index: int = 1 if gold else 0
	if _states[index] == State.ON:
		_states[index] = State.TAKEN
		_refresh()


## Medal `gold`'s tag's state (State).
func state_of(gold: bool) -> int:
	return _states[1 if gold else 0]


## Whether medal `gold`'s tag shows on the paper now (stapled, its delay over).
func is_on(gold: bool) -> bool:
	var index: int = 1 if gold else 0
	return _states[index] == State.ON and _pops[index] >= 0.0


## Whether a stapled tag still waits or pops.
func is_popping() -> bool:
	for index: int in range(2):
		if _states[index] == State.ON and _pops[index] < POP_SECONDS:
			return true
	return false


## The band's height at the paper's foot now (0 with no tag).
func band() -> float:
	return BAND if _states.any(func(state: int) -> bool: return state != State.OFF) else 0.0


## Medal `gold`'s tag's rect at rest, in the paper's coordinates (empty while OFF): in the foot
## band, inside the paper's content, the tags standing from the right.
func tag_rect(gold: bool) -> Rect2:
	var index: int = 1 if gold else 0
	if _states[index] == State.OFF:
		return Rect2()
	var box: StyleBox = _paper.get_theme_stylebox("panel")
	var foot: float = _paper.size.y - _base_margin(box)
	var right: float = _paper.size.x - box.get_margin(SIDE_RIGHT) - SIDE
	if gold and _states[0] != State.OFF:
		right -= PrizeTagArt.size_of(false, CELL).x + GAP
	var tag: Vector2 = PrizeTagArt.size_of(gold, CELL)
	var cell: float = CELL
	var corner: Vector2 = Vector2(right - tag.x, foot - FOOT_GAP - tag.y)
	return Rect2((corner / cell).floor() * cell, tag)


## Moves the pops on by `seconds` (tests; _process by the frame's).
func advance(seconds: float) -> void:
	for index: int in range(2):
		if _states[index] == State.ON and _pops[index] < POP_SECONDS:
			var before: float = _pops[index]
			_pops[index] = minf(_pops[index] + seconds, POP_SECONDS)
			if before < 0.0 and _pops[index] >= 0.0:
				_pops[index] = minf(_pops[index], seconds)
	set_process(is_popping())
	queue_redraw()


## Shows `other`'s tags at rest (a copy of its receipt).
func copy_from(other: ReceiptPrizeTags) -> void:
	_states = other._states.duplicate()
	_pops = [POP_SECONDS, POP_SECONDS]
	_refresh()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for index: int in range(2):
		if not is_on(index == 1):
			continue
		var rect: Rect2 = tag_rect(index == 1)
		rect.position -= position
		var grow: float = _pop_scale(_pops[index])
		if is_equal_approx(grow, 1.0):
			draw_set_transform(Vector2.ZERO)
			PrizeTagArt.draw(self, rect.position, index == 1, CELL)
			continue
		var centre: Vector2 = rect.get_center()
		draw_set_transform(centre, 0.0, Vector2(grow, grow))
		PrizeTagArt.draw(self, rect.position - centre, index == 1, CELL)
	draw_set_transform(Vector2.ZERO)


## A tag's scale `clock` s into its pop: POP_FROM, past 1 and back to 1.
static func _pop_scale(clock: float) -> float:
	if clock >= POP_SECONDS:
		return 1.0
	var p: float = clampf(clock / POP_SECONDS, 0.0, 1.0) - 1.0
	var eased: float = 1.0 + (POP_BACK + 1.0) * p * p * p + POP_BACK * p * p
	return lerpf(POP_FROM, 1.0, eased)


## The paper's own bottom margin (without the band).
func _base_margin(box: StyleBox) -> float:
	if box.has_meta(BASE_META):
		return float(box.get_meta(BASE_META))
	return box.get_margin(SIDE_BOTTOM)


## The band joins or leaves the paper's foot (its bottom content margin), the paper fits its new
## length, and the pops run.
func _refresh() -> void:
	if _paper.has_theme_stylebox_override("panel"):
		var box: StyleBox = _paper.get_theme_stylebox("panel")
		var base: float = _base_margin(box)
		var wanted: float = base + band()
		if not is_equal_approx(box.get_margin(SIDE_BOTTOM), wanted):
			box.set_meta(BASE_META, base)
			box.content_margin_bottom = wanted
			if _paper.has_method(&"fit_height"):
				_paper.call(&"fit_height")
	set_process(is_popping())
	queue_redraw()
