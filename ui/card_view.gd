class_name CardView
extends Control
## A placeholder card: a coloured rectangle with the name, base value, tags and rule text
## (plan section 2). Containers lay out the CardView itself; animations move and scale `body`
## inside it, so they never fight the layout.

signal clicked(view: CardView)

enum Highlight { NONE, SELECTED, REDRAW }

const CARD_SIZE := Vector2(120, 168)
## Where the value badge sits, above the card.
const BADGE_Y := -40.0

var card: CardInstance
## The visible card. The count-up animates its position, scale, rotation and modulate.
var body: PanelContainer
## A value shown above the card: the projected payout while planning, the running value
## during the count-up.
var badge: Label
var _style: StyleBoxFlat
var _redraw_mark: Label
var _tags_label: Label


func _init(card_instance: CardInstance) -> void:
	card = card_instance
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()


func _ready() -> void:
	_fit_body.call_deferred()


func set_highlight(highlight: Highlight) -> void:
	_style.border_color = Palette.TOMATO if highlight == Highlight.SELECTED else Palette.INK
	_style.set_border_width_all(5 if highlight == Highlight.SELECTED else 2)
	body.position.y = -10.0 if highlight == Highlight.SELECTED else 0.0
	body.modulate = Color(1, 1, 1, 0.55) if highlight == Highlight.REDRAW else Color.WHITE
	_redraw_mark.visible = highlight == Highlight.REDRAW


## Shows a value above the card. `strong` is for the count-up, otherwise it is a quiet preview.
func show_badge(value: int, strong: bool) -> void:
	badge.text = str(value)
	badge.visible = true
	badge.add_theme_font_size_override("font_size", 30 if strong else 18)
	badge.add_theme_color_override("font_color", Palette.MUSTARD if strong else Palette.CREAM)


## Shows the tags after the context pass (e.g. Breakfast from a sticker). Products only.
func set_tags(tags: PackedStringArray) -> void:
	if card.definition.is_product():
		_tags_label.text = " · ".join(tags)


func add_tag(tag: String) -> void:
	if card.definition.is_product() and not _tags_label.text.contains(tag):
		_tags_label.text += " · " + tag


func hide_badge() -> void:
	badge.visible = false


func reset_motion() -> void:
	body.position = Vector2.ZERO
	body.scale = Vector2.ONE
	body.rotation = 0.0
	body.modulate = Color.WHITE
	badge.scale = Vector2.ONE
	badge.position.y = BADGE_Y


func _fit_body() -> void:
	body.size = CARD_SIZE


func center() -> Vector2:
	return get_global_rect().get_center()


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func _build() -> void:
	var definition: CardDefinition = card.definition
	var coupon: bool = definition.is_coupon()
	body = PanelContainer.new()
	body.size = CARD_SIZE
	body.pivot_offset = CARD_SIZE / 2.0
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.MUSTARD if coupon else Palette.CREAM
	_style.border_color = Palette.INK
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(7)
	body.add_theme_stylebox_override("panel", _style)
	add_child(body)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed width from the start: wrapped text measured at width 0 would make the card
	# think it is very tall, and a Control never shrinks back by itself.
	column.custom_minimum_size = Vector2(CARD_SIZE.x - 14.0, 0)
	column.add_theme_constant_override("separation", 2)
	body.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title: Label = _label(definition.display_name, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	if definition.is_product():
		header.add_child(_label(str(definition.base), 22))

	var kind_text: String = "COUPON" if coupon else " · ".join(definition.tags)
	_tags_label = _label(kind_text, 10)
	_tags_label.modulate = Color(1, 1, 1, 0.7)
	_tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tags_label)

	var rule: Label = _label(definition.rule_text, 11)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(rule)

	_redraw_mark = _label("REDRAW", 16)
	_redraw_mark.add_theme_color_override("font_color", Palette.TOMATO)
	_redraw_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_redraw_mark.position = Vector2(0, CARD_SIZE.y / 2.0 - 12)
	_redraw_mark.size = Vector2(CARD_SIZE.x, 24)
	_redraw_mark.visible = false
	add_child(_redraw_mark)

	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size = Vector2(CARD_SIZE.x, 36)
	badge.position = Vector2(0, BADGE_Y)
	badge.pivot_offset = badge.size / 2.0
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_color_override("font_outline_color", Palette.INK)
	badge.visible = false
	add_child(badge)


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.INK)
	return label
