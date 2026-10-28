class_name WeekChip
extends PanelContainer
## The top bar's week chip (v0.70, mock-up docs/art/mockups/rota_card_v1.html): the chip frame
## tinted in the week's colour (WeekCard.colour_of), "W2" in the number font, the week event's
## short name ("BAKERY", hidden when the bar has no room: TopBar.fit_inspection) and one pip per
## day of the week (paper once played, gold for today, faint for the days to come; hidden too
## when even that leaves the day's effects too little room). Tapping it reopens the time card
## (`pressed`); hovering shows the week event's name and effect. The count-up plays a week
## event's steps from it (TopBar.event_sources), and the planning effects ring it
## when the hovered item's effect is the week event's (set_relation).

signal pressed

const WEEK_TEXT := "W%d"
const NUMBER_SIZE := 20
const NAME_SIZE := 13
## The pips: 6 px squares, 2 px apart (the mock-up's); today's has an ink ring. The chip's
## padding is narrower than the other chips' (PADDING): the bar has little room left.
const PIP_SIZE := 6.0
const PIP_GAP := 2.0
const PADDING := 8
const SEPARATION := 6
const RING_WIDTH := 2.0
const TIP := "%s · %s\nTap to open the time card"
const CHIP_FRAME := preload("res://art/frames/chip_warn.png")

var _number: Label
var _name: Label
var _pips_view: Control
var _pips: Array[WeekCardModel.Pip] = []
var _ringed: bool = false


func _init() -> void:
	name = "WeekChip"
	var style: StyleBoxTexture = ArtStyle.frame_style(CHIP_FRAME, FramedButton.FRAME_MARGIN)
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.y = TopBar.ROW_SIZE.y
	ArtStyle.use_pixel_material(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SEPARATION)
	add_child(row)
	_number = UiKit.number_label("", NUMBER_SIZE, false)
	_number.add_theme_color_override("font_color", Palette.PAPER)
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_number)
	_name = TopBar.key_label("")
	_name.add_theme_font_size_override("font_size", NAME_SIZE)
	_name.add_theme_color_override("font_color", Palette.PAPER)
	row.add_child(_name)
	_pips_view = Control.new()
	_pips_view.name = "Pips"
	_pips_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips_view.draw.connect(_draw_pips)
	row.add_child(_pips_view)
	visible = false


## Shows `model`'s week: its number, its short name, its pips, tinted in its colour. Hidden for a
## run without weeks (a model of one week with no event).
func show_week(model: WeekCardModel) -> void:
	visible = model.event != null or model.week_count > 1
	_number.text = WEEK_TEXT % model.week_number
	_name.text = model.chip_name()
	_name.visible = not _name.text.is_empty()
	_pips = model.pips()
	_pips_view.custom_minimum_size = Vector2(
		_pips.size() * PIP_SIZE + maxi(_pips.size() - 1, 0) * PIP_GAP, PIP_SIZE
	)
	_pips_view.queue_redraw()
	var colour: Color = WeekCard.colour_of(model.week_number)
	var paper: Color = Palette.PAPER
	self_modulate = Color(colour.r / paper.r, colour.g / paper.g, colour.b / paper.b)
	tooltip_text = TIP % [model.title(), model.effect()] if model.event != null else ""


## Shows the short name, or hides it when the bar has no room (TopBar.fit_inspection).
func show_name(shown: bool) -> void:
	_name.visible = shown and not _name.text.is_empty()


func name_shown() -> bool:
	return _name.visible


## Shows the pips, or hides them when the bar has no room even without the name
## (TopBar.fit_inspection: the day's effects come first).
func show_pips(shown: bool) -> void:
	_pips_view.visible = shown


func pips_shown() -> bool:
	return _pips_view.visible


## The labels and the pips (for layout tests).
func number_label() -> Label:
	return _number


func name_label() -> Label:
	return _name


func pips_view() -> Control:
	return _pips_view


## The pips shown, in order.
func pips() -> Array[WeekCardModel.Pip]:
	return _pips.duplicate()


## Rings the chip in gold while the hovered item's effect is the week event's (#71's rings).
func set_relation(related: bool) -> void:
	_ringed = related
	queue_redraw()


func has_relation() -> bool:
	return _ringed


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	if _ringed:
		draw_rect(
			Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0), Palette.GOLD, false, RING_WIDTH
		)


func _draw_pips() -> void:
	for index: int in range(_pips.size()):
		var at: Rect2 = Rect2(
			Vector2(index * (PIP_SIZE + PIP_GAP), 0.0), Vector2(PIP_SIZE, PIP_SIZE)
		)
		match _pips[index]:
			WeekCardModel.Pip.DONE:
				_pips_view.draw_rect(at, Palette.PAPER)
			WeekCardModel.Pip.NOW:
				_pips_view.draw_rect(at, Palette.GOLD)
				_pips_view.draw_rect(at.grow(-1.0), Palette.GOLD)
				_pips_view.draw_rect(at, Palette.INK, false, 1.0)
			_:
				_pips_view.draw_rect(at, Color(Palette.PAPER, 0.3))
