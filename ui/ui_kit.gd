class_name UiKit
extends RefCounted
## Small helpers shared by the placeholder screens, so they look alike.

## How long a panel's pop-in lasts, in seconds of game time.
const POP_IN_SECONDS := 0.22


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


static func button(parent: Control, text: String, action: Callable, font_size: int) -> Button:
	var result: Button = Button.new()
	result.text = text
	# Mouse-only buttons: keyboard focus would let Space (the fast-forward key) press them.
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", font_size)
	result.pressed.connect(action)
	parent.add_child(result)
	return result


## Centers a panel on the screen and pops it in. Returns the pop-in's tween: the panel is fully
## shown when it finishes (an offer's presented_ms, OfferTimeline).
static func pop_in(panel: Control) -> Tween:
	panel.visible = true
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
