class_name WeekChip
extends PanelContainer
## The top bar's week chip (v0.70, mock-up docs/art/mockups/rota_card_v1.html): the chip frame
## tinted in the week's colour (WeekCard.colour_of), "W2" in the number font, the week event's
## short name ("BAKERY", hidden when the bar has no room: TopBar.fit_inspection) and one pip per
## day of the week (paper once played, gold for today, faint for the days to come; hidden too
## when even that leaves the day's effects too little room). Tapping it reopens the time card
## (`pressed`); hovering shows the week event's name and effect. A played day's pip shows its
## result (v0.75, #119): a green check for PAID, a red cross for a SLIP; after a shift's verdict
## flash() lights today's: the pip pops from 3x with a glow and the chip rings in its colour.
## Until then (hold_result, v0.78) today's pip stays gold, so the checkout doesn't spoil the light.
## The count-up plays a week event's steps from it (TopBar.event_sources), and the planning
## effects ring it when the hovered item's effect is the week event's (set_relation).

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
## flash(): how long the light lasts (s), the pip's pop from 3x (in whole steps, on the pixel
## grid), and the glow's widest reach (px) and opacity.
const FLASH := 0.8
const FLASH_SCALE := 3
const GLOW_REACH := 12.0
const GLOW_ALPHA := 0.6
## A result pip's glyph, pixels on the 6x6 pip: the check and the cross.
const CHECK_PIXELS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 1)
]
const CROSS_PIXELS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(4, 1),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(1, 4),
	Vector2i(4, 4)
]
const CHIP_FRAME := preload("res://art/frames/chip_warn.png")

## Today's result waits for flash(): its pip shows as today's (WeekFlow.show_chips, counting).
var hold_result: bool = false

var _number: Label
var _name: Label
var _pips_view: Control
var _pips: Array[WeekCardModel.Pip] = []
var _ringed: bool = false
## Seconds into flash() (-1: none), and the pip it lights.
var _flash_t: float = -1.0
var _flash_index: int = -1


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
	set_process(false)


## Shows `model`'s week: its number, its short name, its pips, tinted in its colour. Hidden for a
## run without weeks (a model of one week with no event).
func show_week(model: WeekCardModel) -> void:
	visible = model.event != null or model.week_count > 1
	_number.text = WEEK_TEXT % model.week_number
	_name.text = model.chip_name()
	_name.visible = not _name.text.is_empty()
	_pips = model.pips()
	if hold_result:
		_hold_last_result()
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


## Shows the last result pip, today's, as today's until flash() lights it.
func _hold_last_result() -> void:
	for index: int in range(_pips.size() - 1, -1, -1):
		if _pips[index] == WeekCardModel.Pip.PAID or _pips[index] == WeekCardModel.Pip.SLIP:
			_pips[index] = WeekCardModel.Pip.NOW
			return


## Lights today's result pip (a shift's verdict, #119) with its sound: PAID's, or a SLIP's
## denied. With reduced motion only the sound plays. Nothing for a week with no result today.
func flash(reduced: bool) -> void:
	_flash_index = -1
	for index: int in range(_pips.size()):
		if _pips[index] == WeekCardModel.Pip.PAID or _pips[index] == WeekCardModel.Pip.SLIP:
			_flash_index = index  # The last result is today's.
	if _flash_index < 0:
		return
	Sfx.play_at(self, "stamp_paid" if _pips[_flash_index] == WeekCardModel.Pip.PAID else "denied")
	if reduced:
		return
	_flash_t = 0.0
	set_process(true)
	queue_redraw()
	_pips_view.queue_redraw()


func is_flashing() -> bool:
	return _flash_t >= 0.0


## Moves the light on by `seconds` (tests; _process moves it by the frame's).
func advance(seconds: float) -> void:
	if _flash_t < 0.0:
		return
	_flash_t += seconds
	if _flash_t >= FLASH:
		_flash_t = -1.0
		set_process(false)
	queue_redraw()
	_pips_view.queue_redraw()


## Ends the light at once (tests).
func finish_flash() -> void:
	advance(FLASH)


func _process(delta: float) -> void:
	advance(delta)


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
	var ring: Rect2 = Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0)
	if _flash_t >= 0.0:
		var light: Color = _light_of(_pips[_flash_index])
		draw_rect(ring, Color(light, 1.0 - _flash_t / FLASH), false, RING_WIDTH)
	elif _ringed:
		draw_rect(ring, Palette.GOLD, false, RING_WIDTH)


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
			WeekCardModel.Pip.PAID, WeekCardModel.Pip.SLIP:
				if index != _flash_index or _flash_t < 0.0:
					_draw_result(at, _pips[index], 1)
			_:
				_pips_view.draw_rect(at, Color(Palette.PAPER, 0.3))
	if _flash_t >= 0.0 and _flash_index >= 0:
		_draw_light()


## The lit pip: a square glow that widens and fades, under the pip popping from 3x to 1x in whole
## steps.
func _draw_light() -> void:
	var k: float = _flash_t / FLASH
	var centre: Vector2 = Vector2(
		_flash_index * (PIP_SIZE + PIP_GAP) + PIP_SIZE / 2.0, PIP_SIZE / 2.0
	)
	var reach: float = roundf(GLOW_REACH * k)
	var glow: Color = Color(_light_of(_pips[_flash_index]), GLOW_ALPHA * (1.0 - k))
	var half: float = PIP_SIZE / 2.0 + reach
	_pips_view.draw_rect(Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), glow)
	var step: int = maxi(1, FLASH_SCALE - floori(k * 2.0 * FLASH_SCALE))
	var side: float = PIP_SIZE * step
	_draw_result(
		Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side)), _pips[_flash_index], step
	)


## A result pip in `at`, its glyph's pixels `step` px wide: a green light with an ink check, or a
## tomato one with a paper cross.
func _draw_result(at: Rect2, pip: WeekCardModel.Pip, step: int) -> void:
	var paid: bool = pip == WeekCardModel.Pip.PAID
	_pips_view.draw_rect(at, _light_of(pip))
	var ink: Color = Palette.INK if paid else Palette.PAPER
	for pixel: Vector2i in CHECK_PIXELS if paid else CROSS_PIXELS:
		_pips_view.draw_rect(Rect2(at.position + Vector2(pixel) * step, Vector2(step, step)), ink)


static func _light_of(pip: WeekCardModel.Pip) -> Color:
	return Palette.GREEN_LIGHT if pip == WeekCardModel.Pip.PAID else Palette.TOMATO
