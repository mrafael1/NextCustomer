class_name MonitorPager
extends Control
## The item column's page cue (v1.15, the user's "make the page affordance discoverable enough
## that 2/2 isn't the only clue"): at the payout zone's left, on the total's line, one pip a page
## (PIP px squares, the page shown in INK, the others filled OTHER), then, while later pages follow,
## the subtotal the page reached (its last running value, the score's: set_subtotals; none when the
## page moved nothing), SEPARATOR, WORD_MORE and a right chevron; on the last page a left chevron
## and WORD_FIRST (the next turn wraps to the first page, sliding in from the left). The subtotal
## makes a page's visible maths end on a number before "= total" (the review's "page 1 still
## doesn't add up"). It is a button: a click turns the page (MonitorStepPages.turn), the pointing
## hand over it; at rest its ground is REST, while the pointer is on the monitor (the pages held,
## `lit`) LIT, under the pointer HOT. Each page shown nudges the chevron NUDGE px along its way
## twice (none under reduced motion). Drawn in code on the 2 px grid; its words in the monitor's
## bold body font. widest() is its width on its widest page, which the payout keeps clear so the
## cue never changes the total's size as the pages turn; `compact` (a total too wide beside it)
## leaves the pips and the chevron only. Display only: the pages are
## MonitorStepPages', the subtotals the score's.

signal pressed

const WORD_MORE := "MORE"
const WORD_FIRST := "FIRST"
const SEPARATOR := "·"
const WORD_SIZE := 12
const WORD_WEIGHT := 800
const HEIGHT := 16.0
const PAD := 4.0
const PIP := 6.0
const PIP_GAP := 2.0
const WORD_GAP := 5.0
## The chevron: three 2 px columns, CHEVRON.y tall, then 2 px shorter each end, to its point
## (▸ or ◂), on the 2 px grid.
const CHEVRON := Vector2(6, 10)
const CHEVRON_GAP := 3.0
const INK := Palette.TEAL_DARK
const OTHER := Palette.CREAM_DARKEST
const SUBTOTAL_INK := Palette.INK
const SEPARATOR_INK := Palette.INK_LIGHT
const REST := Palette.CREAM
const LIT := Palette.MUSTARD_PALE
const HOT := Palette.MUSTARD_LIGHT
const NUDGE := 2.0
const NUDGE_S := 0.14

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Whether the pointer is on the monitor (the pages held): the ground lights.
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()
## Only the pips and the chevron (no subtotal, no word): the total needs the room.
var compact: bool = false:
	set(value):
		compact = value
		show_page(_page, _count, false)
## The chevron's nudge now (0 at rest, NUDGE at its furthest), for the draw.
var nudge: float = 0.0:
	set(value):
		nudge = value
		queue_redraw()

var _page: int = 0
var _count: int = 1
var _subtotals: PackedInt32Array = PackedInt32Array()
var _hot: bool = false
var _subtotal: Label
var _separator: Label
var _word: Label
var _chevron_left: float = 0.0
var _nudging: Tween


func _init() -> void:
	name = "Pager"
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_subtotal = _label("Subtotal", SUBTOTAL_INK)
	_separator = _label("Separator", SEPARATOR_INK)
	_separator.text = SEPARATOR
	_word = _label("Word", INK)
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))


## Each page's subtotal (the running value at its end; -1 for none), shown on the pages before
## the last.
func set_subtotals(subtotals: PackedInt32Array) -> void:
	_subtotals = subtotals
	show_page(_page, _count, false)


## Shows page `shown` (from 0) of `pages`, and nudges its chevron (`animate`).
func show_page(shown: int, pages: int, animate: bool = true) -> void:
	_page = shown
	_count = maxi(pages, 1)
	_lay_out(_page)
	queue_redraw()
	if animate:
		_nudge()


## The page shown (from 0), how many, and whether it is the last (its word WORD_FIRST).
func page() -> int:
	return _page


func count() -> int:
	return _count


func is_last() -> bool:
	return _page >= _count - 1


## The word shown (WORD_MORE or WORD_FIRST), and the subtotal shown (hidden with none), for checks.
func word() -> Label:
	return _word


func subtotal() -> Label:
	return _subtotal


## The cue's width on its widest page.
func widest() -> float:
	var width: float = 0.0
	for index: int in range(_count):
		_lay_out(index)
		width = maxf(width, size.x)
	_lay_out(_page)
	return width


## Whether the pointer is on the cue (its ground HOT).
func is_hot() -> bool:
	return _hot


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var ground: Color = REST
	if _hot:
		ground = HOT
	elif lit:
		ground = LIT
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	var top: float = roundf((HEIGHT - PIP) / 2.0)
	for index: int in range(_count):
		var pip: Rect2 = Rect2(PAD + index * (PIP + PIP_GAP), top, PIP, PIP)
		draw_rect(pip, INK if index == _page else OTHER)
	var forward: bool = not is_last()
	var left: float = _chevron_left + roundf(nudge) * (1.0 if forward else -1.0)
	var chevron_top: float = roundf((HEIGHT - CHEVRON.y) / 2.0)
	# Columns narrowing to the point: ▸ going on, ◂ going back to the first.
	for step: int in range(3):
		var x: float = left + 2.0 * (step if forward else 2 - step)
		var tall: float = CHEVRON.y - 4.0 * step
		draw_rect(Rect2(x, chevron_top + 2.0 * step, 2.0, tall), INK)


## The parts for page `index`: pips, then the subtotal and separator (a page before the last with
## one), the word and the chevron (on the last page the chevron before the word); its size.
func _lay_out(index: int) -> void:
	var last: bool = index >= _count - 1
	var value: int = _subtotals[index] if index < _subtotals.size() else -1
	var at: float = PAD + _count * PIP + (_count - 1) * PIP_GAP + WORD_GAP
	_subtotal.visible = not last and value >= 0 and not compact
	_separator.visible = _subtotal.visible
	_word.visible = not compact
	if _subtotal.visible:
		_subtotal.text = MonitorText.euros(value)
		at = _place(_subtotal, at) + WORD_GAP
		at = _place(_separator, at) + WORD_GAP
	_word.text = WORD_FIRST if last else WORD_MORE
	if compact:
		_chevron_left = at - WORD_GAP + CHEVRON_GAP
		at = _chevron_left + CHEVRON.x
	elif last:
		_chevron_left = at
		at = _place(_word, at + CHEVRON.x + CHEVRON_GAP)
	else:
		at = _place(_word, at)
		_chevron_left = at + CHEVRON_GAP
		at = _chevron_left + CHEVRON.x
	size = Vector2(ceilf(at + PAD), HEIGHT)


## `label` at `left`, centred on the cue's height; its right edge.
func _place(label: Label, left: float) -> float:
	label.size = Vector2.ZERO
	var measured: Vector2 = label.get_combined_minimum_size()
	label.position = Vector2(left, roundf((HEIGHT - measured.y) / 2.0))
	label.size = Vector2(ceilf(measured.x), measured.y)
	return label.position.x + label.size.x


func _label(label_name: String, ink: Color) -> Label:
	var label: Label = MonitorKit.bold("", WORD_SIZE, WORD_WEIGHT, ink, HEIGHT)
	label.name = label_name
	label.custom_minimum_size = Vector2.ZERO
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _set_hot(hot: bool) -> void:
	_hot = hot
	queue_redraw()


## The chevron nudges NUDGE px along its way and back, twice (none under reduced motion).
func _nudge() -> void:
	if _nudging != null and _nudging.is_valid():
		_nudging.kill()
	nudge = 0.0
	if not is_inside_tree() or (reduced_motion.is_valid() and bool(reduced_motion.call())):
		return
	_nudging = create_tween()
	for _beat: int in range(2):
		_nudging.tween_property(self, "nudge", NUDGE, NUDGE_S)
		_nudging.tween_property(self, "nudge", 0.0, NUDGE_S)
