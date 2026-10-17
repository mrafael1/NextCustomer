class_name FramedButton
extends Button
## A button in the pixel-art style (full build plan section 6.1, #55): a flat Button with a child
## face (a 9-slice frame such as button.png or sign.png, with the sharp-pixel material) and a
## child caption label in the display font (no material: the shader never touches text).
##
## Its state shows in two ways, never by colour alone: hover brightens the face; pressed sinks
## the face and caption by PRESS_DEPTH; disabled sinks them too (a flattened face that no longer
## stands on its ledge), dims the whole button and drops the pointing-hand cursor. It never takes
## keyboard focus, so Space (the count-up's fast-forward key) can't press it. Build one with
## UiKit.framed_button, which also wires the click sound and the action.

## The frame's 9-slice margin, in art pixels.
const FRAME_MARGIN := 3
## The frame's ledge (its bottom art pixels); the caption is centred on the face above it.
const LEDGE := 2
## How far a pressed or disabled face sinks, in canvas pixels (the ledge's height).
const PRESS_DEPTH := LEDGE * ArtStyle.ART_SCALE * 1.0
## Space kept around the caption, in canvas pixels, when the caption sets the minimum size.
const CAPTION_PADDING := Vector2(12, 6)
const HOVER_FACE := Color(1.12, 1.12, 1.12)
const PRESSED_FACE := Color(0.85, 0.85, 0.85)
const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 0.85)
## The space between an icon (set_icon) and the caption.
const ICON_GAP := 6.0

## The caption's text. Use this, not Button.text (which stays empty: the button draws no text of
## its own). It is also the button's accessible name, so screen readers announce the caption.
var caption: String:
	get:
		return _label.text
	set(value):
		_label.text = value
		accessibility_name = value
		_fit_minimum_size()
		if _icon != null:
			_place_icon()

var _face: PanelContainer
var _label: Label
var _requested_size: Vector2
## An icon left of the caption (set_icon), or null.
var _icon: TextureRect


func _init(
	caption_text: String = "",
	font_size: int = 20,
	frame: Texture2D = UiKit.BUTTON_FRAME,
	button_size: Vector2 = Vector2.ZERO
) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_requested_size = button_size
	_face = UiKit.frame_panel(frame, FRAME_MARGIN)
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_face, false, Node.INTERNAL_MODE_FRONT)
	_label = UiKit.display_label(caption_text, font_size, true)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	accessibility_name = caption_text
	_fit_minimum_size()
	_show_state(DRAW_NORMAL)


## Button redraws on every state change (hover, press, disabled), so the look follows it here:
## set Button.disabled as on any button.
func _draw() -> void:
	_show_state(get_draw_mode())


## The face (the frame panel) and the caption label, for tests and layout checks.
func face() -> PanelContainer:
	return _face


func caption_label() -> Label:
	return _label


## Prints the caption in the number font, for captions that carry counts (Cart n/m, Redraw):
## every number uses it (plan section 6.1).
func use_number_font() -> void:
	_label.add_theme_font_override("font", ArtStyle.number_font())
	_fit_minimum_size()


## Puts `texture` at `icon_size` left of the caption, ICON_GAP from it (the pair centred on the
## face), or alone in the middle of the face when the caption is empty (the top bar's menu).
func set_icon(texture: Texture2D, icon_size: Vector2) -> void:
	if _icon == null:
		_icon = UiKit.sprite(texture)
		add_child(_icon, false, Node.INTERNAL_MODE_FRONT)
	_icon.texture = texture
	_icon.size = icon_size
	_fit_minimum_size()
	_place_icon()


func icon_rect() -> TextureRect:
	return _icon


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _icon != null:
		_place_icon()


## Applies the look of `mode` (a BaseButton.DrawMode).
func _show_state(mode: DrawMode) -> void:
	var sunk: bool = mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED or mode == DRAW_DISABLED
	var depth: float = PRESS_DEPTH if sunk else 0.0
	_face.offset_top = depth
	_label.offset_top = depth
	_label.offset_bottom = depth - PRESS_DEPTH
	if _icon != null:
		_place_icon()
	match mode:
		DRAW_HOVER:
			_face.modulate = HOVER_FACE
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			_face.modulate = PRESSED_FACE
		_:
			_face.modulate = Color.WHITE
	var off: bool = mode == DRAW_DISABLED
	modulate = DISABLED_MODULATE if off else Color.WHITE
	mouse_default_cursor_shape = CURSOR_ARROW if off else CURSOR_POINTING_HAND


## The button is at least its requested size and big enough for its caption.
func _fit_minimum_size() -> void:
	var text_size: Vector2 = _label.get_minimum_size() + 2.0 * CAPTION_PADDING
	if _icon != null:
		text_size.x += _icon.size.x + (ICON_GAP if not _label.text.is_empty() else 0.0)
		text_size.y = maxf(text_size.y, _icon.size.y + 2.0 * CAPTION_PADDING.y)
	text_size.y += PRESS_DEPTH
	custom_minimum_size = _requested_size.max(text_size)


## The icon and the caption centred together on the face above the ledge, the caption right of
## the icon; both sink with the face.
func _place_icon() -> void:
	var text_width: float = _label.get_minimum_size().x if not _label.text.is_empty() else 0.0
	var gap: float = ICON_GAP if text_width > 0.0 else 0.0
	var left: float = roundf((size.x - _icon.size.x - gap - text_width) / 2.0)
	var face_height: float = size.y - PRESS_DEPTH
	_icon.position = Vector2(left, roundf((face_height - _icon.size.y) / 2.0) + _face.offset_top)
	_label.offset_left = left + _icon.size.x + gap
	_label.offset_right = _label.offset_left + text_width - size.x
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
