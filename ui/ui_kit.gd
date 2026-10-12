class_name UiKit
extends RefCounted
## Small helpers shared by the placeholder screens, so they look and sound alike. Buttons and
## panels play their UI sounds (#62) on the Sfx of their scene (Sfx.find): nothing when the
## scene has none. No control makes a sound on hover.

## How long a panel's pop-in lasts, in seconds of game time.
const POP_IN_SECONDS := 0.22
## The sound of a button press, unless the button names another (or "" for none).
const CLICK_SOUND := "ui_click"
## The sound of a panel popping in.
const OPEN_SOUND := "ui_open"


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
