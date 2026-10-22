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
## A key can carry a note beside its caption (show_caption; mock-up B2's "Redraw  1 left"): smaller,
## in the number font and ink light, NOTE_GAP right of the caption, the pair centred on the front
## face; it sinks and fades with the caption.

enum Kind { CHECKOUT, CREAM }
enum Look { NORMAL, LIT, OFF }

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
## The note's size and its gap from the caption (B2's .redraw small: 13 px, 8 px gap).
const NOTE_FONT_SIZE := 13
const NOTE_GAP := 8.0

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
## The note beside the caption (show_caption), or null before the first one.
var _note: Label


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


## Captions the key `caption_text` with `note_text` beside it (empty: no note). Screen readers
## announce `spoken`, or the caption and the note when it is empty.
func show_caption(caption_text: String, note_text: String = "", spoken: String = "") -> void:
	if _note == null and not note_text.is_empty():
		_note = UiKit.body_label("", NOTE_FONT_SIZE, Palette.INK_LIGHT)
		_note.name = "Note"
		_note.add_theme_font_override("font", ArtStyle.number_font())
		_note.add_theme_constant_override("outline_size", 0)
		_note.set_anchors_preset(Control.PRESET_FULL_RECT)
		_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_note, false, Node.INTERNAL_MODE_FRONT)
	if _note != null:
		_note.text = note_text
		_note.visible = not note_text.is_empty()
	caption = caption_text
	if spoken.is_empty():
		spoken = caption_text if note_text.is_empty() else "%s, %s" % [caption_text, note_text]
	accessibility_name = spoken
	_show_state(get_draw_mode())


## The note beside the caption ("" for none).
func note() -> String:
	return _note.text if _note != null else ""


## The note's label, or null before the first note (for layout tests).
func note_label() -> Label:
	return _note


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
	draw_rect(Rect2(offset + Vector2(0, depth), size), Color(Palette.INK, SHADOW_ALPHA))


func _show_state(_mode: DrawMode) -> void:
	if _styles.is_empty():
		return
	var current: Look = look()
	var depth: float = SINK if is_sunk() else 0.0
	if face().get_theme_stylebox("panel") != _styles[current]:
		face().add_theme_stylebox_override("panel", _styles[current])
	face().offset_top = depth
	face().offset_bottom = depth
	face().modulate = Color.WHITE
	var label: Label = caption_label()
	var bottom: float = BOTTOM_MARGIN * ArtStyle.ART_SCALE
	label.offset_top = depth + (band_height() if caption_under_band else 0.0)
	label.offset_bottom = depth - (bottom if caption_under_band else 0.0)
	label.modulate.a = OFF_CAPTION_ALPHA if current == Look.OFF else 1.0
	_place_note()
	modulate = Color.WHITE
	var off: bool = held or disabled
	mouse_default_cursor_shape = CURSOR_ARROW if off else CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_note()


## At least the base size, and wide enough for the caption and the note side by side.
func _fit_minimum_size() -> void:
	super()
	if not _has_note():
		return
	var needed: float = (
		caption_label().get_minimum_size().x
		+ NOTE_GAP
		+ _note.get_minimum_size().x
		+ 2.0 * CAPTION_PADDING.x
	)
	custom_minimum_size.x = maxf(custom_minimum_size.x, needed)


func _has_note() -> bool:
	return _note != null and not _note.text.is_empty()


## The caption and the note centred together on the face, the note right of the caption at the
## caption's height; without a note the caption is centred alone. A key that never had a note
## (CHECKOUT, with its own caption offsets) is left as it is.
func _place_note() -> void:
	if _note == null:
		return
	var label: Label = caption_label()
	if not _has_note():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.offset_left = 0.0
		label.offset_right = 0.0
		return
	var caption_width: float = label.get_minimum_size().x
	var note_width: float = _note.get_minimum_size().x
	var left: float = roundf((size.x - caption_width - NOTE_GAP - note_width) / 2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.offset_left = left
	label.offset_right = left + caption_width - size.x
	_note.offset_top = label.offset_top
	_note.offset_bottom = label.offset_bottom
	_note.offset_left = left + caption_width + NOTE_GAP
	_note.offset_right = _note.offset_left + note_width - size.x
	_note.modulate.a = label.modulate.a
