class_name RegisterKey
extends FramedButton
## A physical key on the register column (#80, step 9, mock-up B2): CHECKOUT's tomato bar key
## (tomato is the fizzle's, CHECKOUT's and CLOSED's colour) or a cream key (Redraw, Cancel). Its
## face is a 9-slice seen from slightly above: a lit top face band (the frame's top margin) over
## the front face, in a 2-texel ink outline, with the caption centred on the front face.
##
## It has three frames: NORMAL, LIT for hover, press and `lit`, and OFF for disabled and held.
## Pressed, disabled or held, the face sits SINK px lower and its hard shadow (drawn here, ink at
## SHADOW_ALPHA) shrinks from SHADOW_UP to SHADOW_DOWN, so a state never shows by colour alone;
## an OFF caption fades to OFF_CAPTION_ALPHA. CHECKOUT is held down while the shift is counted
## (`held`, set through RegisterCabinet.set_total_down). Like every FramedButton it stays a
## BaseButton (PressReader reads a press on it the same way) and never takes focus.
##
## A key can carry a count (show_caption; Redraw's redraws left). The PR #138 left UI made the
## count its own part ("the number is its own part and not just on the redraw button"): the key's
## footprint splits into a counter window on its left (Counter, COUNTER_WIDTH px, a display: it
## never sinks, lights or fades, and takes no clicks) and, COUNTER_GAP px right of it, the
## pressable key face with the caption centred on it. Every state (hover, press, lit, disabled,
## held) shows on the face only, its shadow included. Without a count the face takes the whole
## footprint.


## The counter window left of a key's face (the PR #138 left UI): a recessed display framed like
## the register's windows (a 2 px ink outline, a CREAM_SHADE recess along its top and left, a
## PAPER pane) showing the count in the register's 6x8 pixel digits (PixelWords.Sheet.DIGITS at
## COUNTER_CELL; two digits in the 4x7 ones) in the count's colour, over a small LEFT in the 3x5
## capitals. An ALERT count (Redraw's 0) reads "none left" without its colour: the pane goes unlit
## (CREAM_SHADE) and the digit is struck through. Everything on the 2 px art grid.
class CounterWindow:
	extends Control

	var colour: Color = Palette.GREEN_DARK
	var alert: bool = false
	var digits: PixelWords
	var word: PixelWords

	func _init() -> void:
		name = "Counter"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		digits = PixelWords.new("", PixelWords.Sheet.DIGITS, COUNTER_CELL)
		digits.name = "Digits"
		add_child(digits)
		word = PixelWords.new(COUNTER_WORD, PixelWords.Sheet.CAPS, COUNTER_WORD_CELL)
		word.name = "Word"
		word.color = COUNTER_WORD_COLOUR
		add_child(word)
		resized.connect(_place)

	## Shows `count` (its digits) in `count_colour`; `is_alert`: the unlit pane and the strike.
	func show_count(count_text: String, count_colour: Color, is_alert: bool) -> void:
		colour = count_colour
		alert = is_alert
		var one: bool = count_text.length() <= 1
		digits.sheet = PixelWords.Sheet.DIGITS if one else PixelWords.Sheet.SMALL_DIGITS
		digits.text = count_text
		digits.color = count_colour
		_place()
		queue_redraw()

	## The count's digits ("" for none).
	func count() -> String:
		return digits.text

	## The pane inside the outline (in the window's own coordinates).
	func pane() -> Rect2:
		var edge: float = COUNTER_OUTLINE
		return Rect2(Vector2(edge, edge), size - Vector2(edge, edge) * 2.0)

	## The digits and LEFT stacked and centred on the pane, on even px.
	func _place() -> void:
		var area: Rect2 = pane()
		var digits_size: Vector2 = digits.get_combined_minimum_size()
		var word_size: Vector2 = word.get_combined_minimum_size()
		var stack: float = digits_size.y + COUNTER_WORD_GAP + word_size.y
		var top: float = _even(area.position.y + (area.size.y - stack) / 2.0)
		digits.size = digits_size
		digits.position = Vector2(_even(area.get_center().x - digits_size.x / 2.0), top)
		word.size = word_size
		word.position = Vector2(
			_even(area.get_center().x - word_size.x / 2.0), top + digits_size.y + COUNTER_WORD_GAP
		)

	static func _even(value: float) -> float:
		return roundf(value / 2.0) * 2.0

	func _draw() -> void:
		var px: float = ArtStyle.ART_SCALE
		draw_rect(Rect2(Vector2.ZERO, size), ArtStyle.INK)
		var inner: Rect2 = pane()
		draw_rect(inner, Palette.CREAM_SHADE if alert else Palette.PAPER)
		# The recess: the pane's top and left edges in shade (the window sits in the deck).
		var recess: Color = Palette.GREY_LIGHT if alert else Palette.CREAM_SHADE
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, COUNTER_RECESS)), recess)
		draw_rect(Rect2(inner.position, Vector2(COUNTER_RECESS, inner.size.y)), recess)
		if not alert or digits.text.is_empty():
			return
		# The strike: a stepped slash from the digits' foot-left to their top-right, past their
		# sides and top by one art px (not their foot: LEFT is under it), two art px thick.
		var rect: Rect2 = Rect2(digits.position, digits.size).grow_individual(px, px, px, 0.0)
		var steps: int = int(rect.size.y / px)
		for step: int in range(steps):
			var x: float = rect.position.x + floorf(step * rect.size.x / steps / px) * px
			var y: float = rect.end.y - (step + 1) * px
			draw_rect(Rect2(x, y, px * 2.0, px), colour)


enum Kind { CHECKOUT, CREAM }
enum Look { NORMAL, LIT, OFF }
## A count's look (show_caption): a plain count, or one that says "none left" (Redraw's 0).
enum NoteLook { COUNT, ALERT }

## Each kind's frames, in Look order.
const FRAMES: Dictionary[Kind, Array] = {
	Kind.CHECKOUT:
	[
		preload("res://art/frames/key_checkout.png"),
		preload("res://art/frames/key_checkout_lit.png"),
		preload("res://art/frames/key_checkout_off.png"),
	],
	Kind.CREAM:
	[
		preload("res://art/frames/key_cream.png"),
		preload("res://art/frames/key_cream_lit.png"),
		preload("res://art/frames/key_cream_off.png"),
	],
}
## The frames' 9-slice margins in art pixels: the top one holds the outline, the top face band
## and its arris (5 band rows on CHECKOUT, 4 on a cream key); the bottom one the front face's
## shaded rows and the outline.
const TOP_MARGINS: Dictionary[Kind, int] = {Kind.CHECKOUT: 8, Kind.CREAM: 7}
const SIDE_MARGIN := 3
const BOTTOM_MARGIN := 4
## How far a pressed, disabled or held key sits lower, in canvas pixels (mock-up B2's .off).
const SINK := 4.0
## The key's hard shadow on the key deck, down and right of the face: up, then down.
const SHADOW_UP := Vector2(6, 6)
const SHADOW_DOWN := Vector2(2, 2)
const SHADOW_ALPHA := 0.45
const OFF_CAPTION_ALPHA := 0.42
## The counter window (CounterWindow): its width and its gap to the face, its outline and recess
## (px), the count's font pixel (6x8 digits: 24 x 32 px), and LEFT under it in the 3x5 capitals at
## COUNTER_WORD_CELL, COUNTER_WORD_GAP px under the digits, in COUNTER_WORD_COLOUR.
const COUNTER_WIDTH := 48.0
const COUNTER_GAP := 4.0
const COUNTER_OUTLINE := 2.0
const COUNTER_RECESS := 2.0
const COUNTER_CELL := 4.0
const COUNTER_WORD := "LEFT"
const COUNTER_WORD_CELL := 2.0
const COUNTER_WORD_GAP := 2.0
const COUNTER_WORD_COLOUR := Palette.GREY_DARK

## Held down (CHECKOUT while the shift is counted): the OFF look, sunk, whatever the mouse does.
var held: bool = false:
	set(value):
		held = value
		queue_redraw()
## Shown pressed (the LIT look, sunk) whatever the mouse does: the machine's CONFIRM › during its
## down state (#77 machine v2).
var down: bool = false:
	set(value):
		down = value
		_show_state(get_draw_mode())
		queue_redraw()
## Held lit (Redraw while redraw mode is armed, plan section 3.8): the LIT look, whatever the
## mouse does (unless held or disabled).
var lit: bool = false:
	set(value):
		lit = value
		_show_state(get_draw_mode())

## Whether the caption is centred on the front face under the top band (the register's keys) or
## on the whole face (a key too short for its caption under the band: the machine's CONFIRM ›).
var caption_under_band: bool = true:
	set(value):
		caption_under_band = value
		_show_state(get_draw_mode())
var _kind: Kind = Kind.CREAM
var _styles: Array[StyleBoxTexture] = []
## The counter window (show_caption), or null before the first count.
var _counter: CounterWindow


func _init(
	kind: Kind = Kind.CREAM,
	caption_text: String = "",
	font_size: int = 16,
	button_size: Vector2 = Vector2.ZERO
) -> void:
	_kind = kind
	var frames: Array = FRAMES[kind]
	super(caption_text, font_size, frames[Look.NORMAL] as Texture2D, button_size)
	for frame: Texture2D in frames:
		var style: StyleBoxTexture = ArtStyle.frame_style(frame, SIDE_MARGIN)
		style.texture_margin_top = TOP_MARGINS[kind] * ArtStyle.ART_SCALE
		style.texture_margin_bottom = BOTTOM_MARGIN * ArtStyle.ART_SCALE
		_styles.append(style)
	_show_state(get_draw_mode())


## Captions the key `caption_text`, with `count_text` in the counter window left of the face
## (empty: no counter, the face takes the whole key) in `count_color`, looking `count_look`.
## Screen readers announce `spoken`, or the caption and the count when it is empty.
func show_caption(
	caption_text: String,
	count_text: String = "",
	spoken: String = "",
	count_color: Color = Palette.INK,
	count_look: NoteLook = NoteLook.COUNT
) -> void:
	if _counter == null and not count_text.is_empty():
		_counter = CounterWindow.new()
		add_child(_counter, false, Node.INTERNAL_MODE_FRONT)
	if _counter != null:
		_counter.visible = not count_text.is_empty()
		_counter.show_count(count_text, count_color, count_look == NoteLook.ALERT)
	caption = caption_text
	if spoken.is_empty():
		spoken = caption_text if count_text.is_empty() else "%s, %s" % [caption_text, count_text]
	accessibility_name = spoken
	queue_redraw()
	_show_state(get_draw_mode())


## The count in the counter window ("" for none).
func note() -> String:
	return _counter.count() if _has_counter() else ""


## The counter window, or null before the first count (for layout tests).
func counter() -> CounterWindow:
	return _counter


## The key face's part of the key, in its own coordinates: right of the counter window when a
## count shows, else the whole key. Only this part takes clicks.
func face_rect() -> Rect2:
	var left: float = COUNTER_WIDTH + COUNTER_GAP if _has_counter() else 0.0
	return Rect2(left, 0.0, size.x - left, size.y)


## The key's look now: NORMAL, LIT (hover or press) or OFF (disabled or held).
func look() -> Look:
	if held or disabled:
		return Look.OFF
	if lit:
		return Look.LIT
	var mode: DrawMode = get_draw_mode()
	if down or mode == DRAW_HOVER or mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED:
		return Look.LIT
	return Look.NORMAL


## The face sits lower (pressed, disabled or held).
func is_sunk() -> bool:
	if held or disabled or down:
		return true
	var mode: DrawMode = get_draw_mode()
	return mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED


## The canvas height of the face's top band (its outline, lit top face and arris): the caption
## is centred on the front face under it.
func band_height() -> float:
	return TOP_MARGINS[_kind] * ArtStyle.ART_SCALE * 1.0


## The hard shadow under the face, then the face (a child) over it.
func _draw() -> void:
	super()
	if _styles.is_empty():
		return
	var offset: Vector2 = SHADOW_DOWN if is_sunk() else SHADOW_UP
	var depth: float = SINK if is_sunk() else 0.0
	var face_part: Rect2 = face_rect()
	face_part.position += offset + Vector2(0, depth)
	draw_rect(face_part, Color(Palette.INK, SHADOW_ALPHA))


## Only the face takes clicks and hovers: the counter window is a display.
func _has_point(point: Vector2) -> bool:
	return face_rect().has_point(point)


func _show_state(_mode: DrawMode) -> void:
	if _styles.is_empty():
		return
	var current: Look = look()
	var depth: float = SINK if is_sunk() else 0.0
	if face().get_theme_stylebox("panel") != _styles[current]:
		face().add_theme_stylebox_override("panel", _styles[current])
	var left: float = face_rect().position.x
	face().offset_left = left
	face().offset_top = depth
	face().offset_bottom = depth
	face().modulate = Color.WHITE
	var label: Label = caption_label()
	var bottom: float = BOTTOM_MARGIN * ArtStyle.ART_SCALE
	label.offset_left = left
	label.offset_top = depth + (band_height() if caption_under_band else 0.0)
	label.offset_bottom = depth - (bottom if caption_under_band else 0.0)
	label.modulate.a = OFF_CAPTION_ALPHA if current == Look.OFF else 1.0
	_place_counter()
	modulate = Color.WHITE
	var off: bool = held or disabled
	mouse_default_cursor_shape = CURSOR_ARROW if off else CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_counter()


## At least the base size, and wide enough for the counter window and the caption on the face.
func _fit_minimum_size() -> void:
	super()
	if not _has_counter():
		return
	var needed: float = (
		COUNTER_WIDTH + COUNTER_GAP + caption_label().get_minimum_size().x + 2.0 * CAPTION_PADDING.x
	)
	custom_minimum_size.x = maxf(custom_minimum_size.x, needed)


func _has_counter() -> bool:
	return _counter != null and _counter.visible


## The counter window at the key's left, as tall as the key; it never moves with the face.
func _place_counter() -> void:
	if _counter == null:
		return
	_counter.position = Vector2.ZERO
	_counter.size = Vector2(COUNTER_WIDTH, size.y)
