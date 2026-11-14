class_name TutorialRing
extends Control
## A tutorial step's ring (mock-up docs/art/mockups/tutorial.html, .ring): a gold border between
## two ink lines round its target, PAD out from it, pulsing gold to mustard pale in PULSE_STEPS hard
## steps every PULSE_S (the page's `pulse 1.1s steps(4)`); the move's ring (`act`) wears the gold
## "CLICK" tab on its top-right corner. Reduced motion holds it gold. Display only: it takes no
## clicks (the shade's hole under it lets them through to the target).

## The room between the target and the ring's outer edge, and the lines (canvas px).
const PAD := 8.0
const INK_LINE := 2.0
const GOLD_LINE := 4.0
const PULSE_S := 1.1
const PULSE_STEPS := 4
## Each pulse step's mix towards mustard pale (keyframes 0%, 50%, 100% sampled by steps(4)).
const PULSE_MIX: Array[float] = [0.0, 0.5, 1.0, 0.5]
## The CLICK tab: its padding round the pixel words and its border.
const TAB_PAD := Vector2(4, 3)
const TAB_BORDER := 2.0

## Whether it is the move's ring (the CLICK tab).
var act: bool = false:
	set(value):
		act = value
		_tab.visible = value
		queue_redraw()
## A Callable() -> bool; true holds the pulse (reduced motion).
var reduced_motion: Callable = Callable()
var _time: float = 0.0
var _tab: Control
var _tab_label: Label


func _init() -> void:
	name = "TutorialRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab = Control.new()
	_tab.name = "Tab"
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.visible = false
	_tab.draw.connect(_draw_tab)
	add_child(_tab)
	_tab_label = UiKit.pixel_label(StepView.RING_TAB, 1, Palette.INK)
	_tab_label.name = "TabWords"
	_tab.add_child(_tab_label)


## Rings `target` (in its parent's coordinates): the ring lies PAD outside it, on the 2 px grid.
func surround(target: Rect2) -> void:
	var rect: Rect2 = target.grow(PAD)
	var at: Vector2 = (rect.position / 2.0).floor() * 2.0
	position = at
	size = ((rect.end - at) / 2.0).ceil() * 2.0
	var words: Vector2 = TipCard.caps_size(StepView.RING_TAB)
	var tab_size: Vector2 = words + TAB_PAD * 2.0 + Vector2.ONE * TAB_BORDER * 2.0
	tab_size = (tab_size / 2.0).ceil() * 2.0
	_tab.size = tab_size
	_tab.position = Vector2(size.x - tab_size.x, -tab_size.y + INK_LINE)
	UiKit.place_pixel_label(
		_tab_label,
		Rect2(Vector2.ONE * TAB_BORDER + Vector2(TAB_PAD.x, 0), tab_size - Vector2.ONE * 4.0),
		true
	)
	queue_redraw()


## The ring's rect and its tab's (when shown), in its parent's coordinates.
func outer_rect() -> Rect2:
	var rect: Rect2 = Rect2(position, size)
	if act:
		rect = rect.merge(Rect2(position + _tab.position, _tab.size))
	return rect


func tab() -> Control:
	return _tab


## The gold line's colour now.
func gold() -> Color:
	if _reduced():
		return Palette.GOLD
	var step: int = int(fmod(_time, PULSE_S) / PULSE_S * PULSE_STEPS) % PULSE_STEPS
	return Palette.GOLD.lerp(Palette.MUSTARD_PALE, PULSE_MIX[step])


## Sets the pulse's clock (tests and captures).
func set_time(seconds: float) -> void:
	_time = seconds
	queue_redraw()
	_tab.queue_redraw()


func _process(delta: float) -> void:
	if _reduced():
		return
	var before: Color = gold()
	_time += delta
	if gold() != before:
		queue_redraw()
		_tab.queue_redraw()


func _draw() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	_frame(outer, INK_LINE, Palette.INK)
	_frame(outer.grow(-INK_LINE), GOLD_LINE, gold())
	_frame(outer.grow(-INK_LINE - GOLD_LINE), INK_LINE, Palette.INK)


func _draw_tab() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _tab.size)
	_tab.draw_rect(rect, Palette.INK)
	_tab.draw_rect(rect.grow(-TAB_BORDER), gold())


func _frame(rect: Rect2, line: float, colour: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, line)), colour)
	draw_rect(Rect2(rect.position.x, rect.end.y - line, rect.size.x, line), colour)
	draw_rect(Rect2(rect.position.x, rect.position.y, line, rect.size.y), colour)
	draw_rect(Rect2(rect.end.x - line, rect.position.y, line, rect.size.y), colour)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
