class_name UiKit
extends RefCounted
## Small helpers shared by the screens, so they look and sound alike. Buttons and panels play
## their UI sounds (#62) on the Sfx of their scene (Sfx.find): nothing when the scene has none.
## No control makes a sound on hover.
##
## The pixel-art kit (full build plan section 6.1, #55; moved here from the style frame): frame
## panels, sprites, framed buttons (FramedButton) and labels by font role. Signs, buttons and
## titles use the display font (Pixelify Sans); rules, tag lines, notices, the CLOSED caption and
## hints the body font (Atkinson Hyperlegible Next); numbers and prices ArtStyle.number_font();
## the receipt the mono font (JetBrains Mono). Art gets the sharp-pixel material; text never
## does.

## How long a panel's pop-in lasts, in seconds of game time.
const POP_IN_SECONDS := 0.22
## The sound of a button press, unless the button names another (or "" for none).
const CLICK_SOUND := "ui_click"
## The sound of a panel popping in.
const OPEN_SOUND := "ui_open"
## The framed buttons' default face: a chunky tomato button with a ledge.
const BUTTON_FRAME := preload("res://art/frames/button.png")
## The lighter face for secondary buttons (a shop sign).
const SIGN_FRAME := preload("res://art/frames/sign.png")
## The outline of light display and number text (on signs and the wall), in canvas pixels.
const LIGHT_OUTLINE := 6
## The notices' body-font size.
const NOTICE_FONT_SIZE := 16


static func paper_panel(border: int = 4) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func label(text: String, font_size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


## A button that calls `action` when pressed, after playing `sound` (CLICK_SOUND by default; a
## button whose action plays its own sound passes "").
static func button(
	parent: Control, text: String, action: Callable, font_size: int, sound: String = CLICK_SOUND
) -> Button:
	var result: Button = Button.new()
	result.text = text
	# Mouse-only buttons: keyboard focus would let Space (the fast-forward key) press them.
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", font_size)
	if not sound.is_empty():
		result.pressed.connect(func() -> void: Sfx.play_at(result, sound))
	result.pressed.connect(action)
	parent.add_child(result)
	return result


## Centers a panel on the screen and pops it in with OPEN_SOUND. Returns the pop-in's tween: the
## panel is fully shown when it finishes (an offer's presented_ms, OfferTimeline).
static func pop_in(panel: Control) -> Tween:
	panel.visible = true
	Sfx.play_at(panel, OPEN_SOUND)
	# Size the panel to its content first, then center it with that size.
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.pivot_offset = panel.get_combined_minimum_size() / 2.0
	panel.scale = Vector2(0.7, 0.7)
	var tween: Tween = panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, POP_IN_SECONDS)
	return tween


## The theme for the pixel-art parts of a screen (the shift screen's stage and overlay): text
## without its own font (the count-up's flying numbers, stamps and verdict) uses the number font.
static func screen_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = ArtStyle.number_font()
	return theme


## A pixel-art TextureRect at the texture's own size (frames are pre-scaled; sprites are 1x).
static func sprite(texture: Texture2D) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	result.texture = texture
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(result)
	return result


## A pixel-art TextureRect that repeats its texture over its size (the wall's tiles).
static func tiled(texture: Texture2D) -> TextureRect:
	var result: TextureRect = sprite(texture)
	result.stretch_mode = TextureRect.STRETCH_TILE
	result.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return result


## A panel drawn with a 9-slice frame. `margin` is the frame's margin in art pixels; `padding`
## is left, top, right, bottom in canvas pixels (defaults to the frame margin).
static func frame_panel(
	texture: Texture2D, margin: int, padding: Vector4 = Vector4(-1, -1, -1, -1)
) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxTexture = ArtStyle.frame_style(texture, margin)
	if padding.x >= 0:
		style.content_margin_left = padding.x
		style.content_margin_top = padding.y
		style.content_margin_right = padding.z
		style.content_margin_bottom = padding.w
	panel.add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(panel)
	return panel


## A FramedButton added to `parent` (when not null) that calls `action` when pressed, after
## playing `sound` (CLICK_SOUND by default; a button whose action plays its own sound passes
## ""). `button_size` is its minimum size; it grows to fit its caption.
static func framed_button(
	parent: Control,
	text: String,
	action: Callable,
	font_size: int,
	frame: Texture2D = BUTTON_FRAME,
	button_size: Vector2 = Vector2.ZERO,
	sound: String = CLICK_SOUND
) -> FramedButton:
	var result: FramedButton = FramedButton.new(text, font_size, frame, button_size)
	if not sound.is_empty():
		result.pressed.connect(func() -> void: Sfx.play_at(result, sound))
	result.pressed.connect(action)
	if parent != null:
		parent.add_child(result)
	return result


## Display-font text (signs, buttons, titles): light with an ink outline (on signs and the
## wall), or plain ink.
static func display_label(text: String, font_size: int, light: bool) -> Label:
	var result: Label = _text_label(text, ArtStyle.DISPLAY_FONT, font_size)
	result.add_theme_color_override("font_color", Palette.PAPER if light else Palette.INK)
	result.add_theme_constant_override("line_spacing", 0)
	if light:
		result.add_theme_constant_override("outline_size", LIGHT_OUTLINE)
		result.add_theme_color_override("font_outline_color", Palette.INK)
	return result


## Numbers and money: the number font, light with an ink outline or plain ink.
static func number_label(text: String, font_size: int, light: bool) -> Label:
	var result: Label = display_label(text, font_size, light)
	result.add_theme_font_override("font", ArtStyle.number_font())
	return result


## Body-font text: rules, tag lines, notices and hints.
static func body_label(text: String, font_size: int, color: Color = Palette.PAPER) -> Label:
	var result: Label = _text_label(text, ArtStyle.BODY_FONT, font_size)
	result.add_theme_color_override("font_color", color)
	return result


## Receipt text in the mono font. Kept for the kit's font roles (plan 6.1 item 5): ReceiptView
## still builds its own lines, and #56's print-outs and results are its first callers.
static func receipt_label(text: String, font_size: int, color: Color = Palette.INK) -> Label:
	var result: Label = _text_label(text, ArtStyle.MONO_FONT, font_size)
	result.add_theme_color_override("font_color", color)
	return result


## Gives a label the notice style: tomato body-font text (every NoticeLabel has it).
static func style_notice(notice: Label) -> void:
	notice.add_theme_font_override("font", ArtStyle.BODY_FONT)
	notice.add_theme_font_size_override("font_size", NOTICE_FONT_SIZE)
	notice.add_theme_color_override("font_color", Palette.TOMATO)


static func _text_label(text: String, font: Font, font_size: int) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", font_size)
	return result
