class_name RegisterKey
extends FramedButton
## A physical key on the register column (#80, step 9, mock-up B2): CHECKOUT's tomato bar key
## (tomato is the fizzle's, CHECKOUT's and CLOSED's colour) or a cream key (Redraw, Cancel). Its
## face is a 9-slice seen from slightly above: a lit top face band (the frame's top margin) over
## the front face, in a 2-texel ink outline, with the caption centred on the front face.
##
## It has three frames: NORMAL, LIT for hover and press, and OFF for disabled and held. Pressed,
## disabled or held, the face sits SINK px lower and its hard shadow (drawn here, ink at
## SHADOW_ALPHA) shrinks from SHADOW_UP to SHADOW_DOWN, so a state never shows by colour alone;
## an OFF caption fades to OFF_CAPTION_ALPHA. CHECKOUT is held down while the shift is counted
## (`held`, set through RegisterCabinet.set_total_down). Like every FramedButton it stays a
## BaseButton (PressReader reads a press on it the same way) and never takes focus.

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

## Held down (CHECKOUT while the shift is counted): the OFF look, sunk, whatever the mouse does.
var held: bool = false:
	set(value):
		held = value
		queue_redraw()

var _kind: Kind = Kind.CREAM
var _styles: Array[StyleBoxTexture] = []


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


## The key's look now: NORMAL, LIT (hover or press) or OFF (disabled or held).
func look() -> Look:
	if held or disabled:
		return Look.OFF
	var mode: DrawMode = get_draw_mode()
	if mode == DRAW_HOVER or mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED:
		return Look.LIT
	return Look.NORMAL


## The face sits lower (pressed, disabled or held).
func is_sunk() -> bool:
	if held or disabled:
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
	label.offset_top = depth + band_height()
	label.offset_bottom = depth - BOTTOM_MARGIN * ArtStyle.ART_SCALE
	label.modulate.a = OFF_CAPTION_ALPHA if current == Look.OFF else 1.0
	modulate = Color.WHITE
	var off: bool = held or disabled
	mouse_default_cursor_shape = CURSOR_ARROW if off else CURSOR_POINTING_HAND
