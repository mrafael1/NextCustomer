class_name WeekChip
extends PanelContainer
## The top bar's week chip (v0.70, mock-up docs/art/mockups/rota_card_v1.html): the chip frame
## tinted in the week's colour (WeekCard.colour_of), "W : 2/4" in the number font, the week event's
## short name ("BAKERY", hidden when the bar has no room: TopBar.fit_inspection) and one pip per
## day of the week (paper once played, gold for today, faint for the days to come; hidden too
## when even that leaves the day's effects too little room). Tapping it reopens the time card
## (`pressed`); hovering shows the week event's name and effect. A played day's pip shows its
## result (v0.75, #119): a green check for PAID, a red cross for a SLIP; after a shift's verdict
## flash() lights today's: the pip pops from 3x with a glow and the chip rings in its colour.
## Until then (hold_result, v0.78) today's pip stays gold, so the checkout doesn't spoil the light.
## The count-up plays a week event's steps from it (TopBar.event_sources), and the planning
## effects ring it when the hovered item's effect is the week event's (set_relation).
## Run info (v1.02, mock-up run_info_clarity.html; the user's play review of 2026-11-05): the chip
## reads "W : 2/4", the week's number in its own colour (number_ink: the quota tube's colours, met
## green for week 1, then the laps' gold, orange, velvet), outlined in ink as the monitor's big
## total, so the run's length and where today sits read at a glance. The other weeks show no
## boxes (the review found the narrow bars odd, and all of the run's 16 boxes leave the day chip
## no room on crowded days): "/4" says the run's length. The pips are drawn in whole screen pixels
## (pip_metrics): at the 1920x1080 window's 1.5x stretch each is 13 px with a 3 px gap and its
## glyph's pixels one screen pixel each, so every pip, gap and stroke is the same size.

signal pressed

## "W :", the week's number and "/4" (the run's week count), KEY_GAP px apart (clear of the
## number's ink outline).
## The number is the chip's big one (NUMBER_SIZE), "W :" and "/4" smaller (SMALL_SIZE), so the
## chip stays as narrow as v1.02's "W2/4" bar a few px and the review day's chip keeps its words.
const KEY_TEXT := "W :"
const KEY_GAP := 3
const WEEK_TEXT := "%d"
const NUMBER_SIZE := 20
const SMALL_SIZE := 15
## The week's number's inks by week (the quota tube's, in lap order: QuotaMeter.MET_RAMP's lit
## green for week 1, then QuotaLaps.LAP_RAMPS' gold, orange light, velvet sheen and violet light;
## the gold lap's body, as its pale reads as the paper around it), a week past them the last. Each
## is outlined in ink (NUMBER_OUTLINE px, with an ink drop NUMBER_DROP px down), as TotalNumber's
## gold, so it reads on every week's chip colour.
const NUMBER_INKS: Array[Color] = [
	Palette.GREEN_LIGHT,
	Palette.GOLD,
	Palette.ORANGE_LIGHT,
	Palette.VELVET_SHEEN,
	Palette.VIOLET_LIGHT
]
const NUMBER_OUTLINE := 8
const NUMBER_DROP := 2
## An ink too dark on the ink outline (WCAG contrast under DARK_INK_CONTRAST: the velvet's 4,
## v1.02 review) is outlined in paper instead, a sticker on the chip, its drop still ink.
const DARK_INK_CONTRAST := 3.0
## The week's name in the display font's hard pixels (UiKit.pixel_label), NAME_SCALE px per font
## px: on the art's grid, 3 screen px per font px and 21 px capitals at 1920x1080 (mock-up
## shift_scene_polish_v4 D; Pixelify Sans at 13 or 15 px put a font pixel on 1.8 or 2.1 screen
## pixels, so its strokes thinned and wobbled).
const NAME_SCALE := 2
## The pips: 9 px squares (v0.83: 1.5x the mock-up's 6 px, easier to read), 2 px apart, on whole
## pixels; today's has an ink ring. The chip's padding is narrower than the other chips'
## (PADDING): the bar has little room left (v4's D: 8 to 6, and its gaps 6 to 4, for the bigger
## name). A result's glyph is GLYPH_CELLS pixels square (CHECK_PIXELS, CROSS_PIXELS).
const PIP_SIZE := 9.0
const PIP_GAP := 2.0
const GLYPH_CELLS := 9
const PADDING := 6
const SEPARATION := 4
const RING_WIDTH := 2.0
const TIP := "%s\nTap to open the time card"
const TIP_EVENT := "%s · %s · %s"
## A day to come's pip: faint paper.
const TODO_ALPHA := 0.3
## flash(): how long the light lasts (s), the pip's pop from 3x (in whole steps, on the pixel
## grid), and the glow's widest reach (px) and opacity.
const FLASH := 0.8
const FLASH_SCALE := 3
const GLOW_REACH := 12.0
const GLOW_ALPHA := 0.6
## A result pip's glyph, pixels on the 9x9 pip: the check (a two-pixel stroke) and the cross
## (corner to corner, two pixels at its middle row).
const CHECK_PIXELS: Array[Vector2i] = [
	Vector2i(7, 2),
	Vector2i(6, 3),
	Vector2i(7, 3),
	Vector2i(1, 4),
	Vector2i(5, 4),
	Vector2i(6, 4),
	Vector2i(1, 5),
	Vector2i(2, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(2, 6),
	Vector2i(3, 6),
	Vector2i(4, 6),
	Vector2i(3, 7)
]
const CROSS_PIXELS: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(6, 2),
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(5, 3),
	Vector2i(6, 3),
	Vector2i(3, 4),
	Vector2i(4, 4),
	Vector2i(5, 4),
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(2, 6),
	Vector2i(6, 6)
]
const CHIP_FRAME := preload("res://art/frames/chip_warn.png")

## Today's result waits for flash(): its pip shows as today's (WeekFlow.show_chips, counting).
var hold_result: bool = false

## "W :", the week's number and the run's week count ("/4", hidden for a run of one week).
var _key: Label
var _number: Label
var _count: Label
## The name's hard pixel label, in a box as big as its words (the label is drawn scaled).
var _name: Label
var _name_box: Control
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
	var number_row: HBoxContainer = HBoxContainer.new()
	number_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_row.add_theme_constant_override("separation", KEY_GAP)
	row.add_child(number_row)
	_key = _paper_number(KEY_TEXT, SMALL_SIZE)
	_key.name = "Key"
	number_row.add_child(_key)
	_number = _paper_number("", NUMBER_SIZE)
	_number.name = "Number"
	_number.add_theme_constant_override("outline_size", NUMBER_OUTLINE)
	_number.add_theme_color_override("font_outline_color", Palette.INK)
	_number.add_theme_constant_override("shadow_outline_size", NUMBER_OUTLINE)
	_number.add_theme_constant_override("shadow_offset_x", 0)
	_number.add_theme_constant_override("shadow_offset_y", NUMBER_DROP)
	_number.add_theme_color_override("font_shadow_color", Palette.INK)
	number_row.add_child(_number)
	_count = _paper_number("", SMALL_SIZE)
	_count.name = "Count"
	number_row.add_child(_count)
	_name_box = Control.new()
	_name_box.name = "NameBox"
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_box.resized.connect(_place_name)
	row.add_child(_name_box)
	_name = UiKit.pixel_label("", NAME_SCALE, Palette.PAPER)
	_name.name = "Name"
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_box.add_child(_name)
	_pips_view = Control.new()
	_pips_view.name = "Pips"
	_pips_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips_view.draw.connect(_draw_pips)
	# The pips snap to the screen's pixels: a moved chip redraws them.
	item_rect_changed.connect(_pips_view.queue_redraw)
	row.add_child(_pips_view)
	visible = false
	set_process(false)


static func _paper_number(text: String, font_size: int) -> Label:
	var label: Label = UiKit.number_label(text, font_size, false)
	label.add_theme_color_override("font_color", Palette.PAPER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Week `week`'s number's ink (1-based; NUMBER_INKS, a week past them the last).
static func number_ink(week: int) -> Color:
	return NUMBER_INKS[clampi(week - 1, 0, NUMBER_INKS.size() - 1)]


## Week `week`'s number's outline: ink, or paper for an ink too dark on it (DARK_INK_CONTRAST).
static func number_outline(week: int) -> Color:
	var ink: Color = number_ink(week)
	return Palette.PAPER if contrast(ink, Palette.INK) < DARK_INK_CONTRAST else Palette.INK


## WCAG's contrast ratio of `a` and `b` (their relative luminance, on the linear colour).
static func contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance() + 0.05
	var lb: float = b.srgb_to_linear().get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)


## Shows `model`'s week: its number, its short name, its pips, tinted in its colour. Hidden for a
## run without weeks (a model of one week with no event).
func show_week(model: WeekCardModel) -> void:
	visible = model.event != null or model.week_count > 1
	_number.text = WEEK_TEXT % model.week_number
	_number.add_theme_color_override("font_color", number_ink(model.week_number))
	_number.add_theme_color_override("font_outline_color", number_outline(model.week_number))
	_count.text = model.count_text()
	_count.visible = model.week_count > 1
	_name.text = model.chip_name()
	_name_box.custom_minimum_size.x = UiKit.pixel_text_size(_name).x
	_name_box.visible = not _name.text.is_empty()
	_place_name()
	_pips = model.pips()
	if hold_result:
		_hold_last_result()
	_size_pips()
	var colour: Color = WeekCard.colour_of(model.week_number)
	var paper: Color = Palette.PAPER
	self_modulate = Color(colour.r / paper.r, colour.g / paper.g, colour.b / paper.b)
	var head: String = model.head()
	if model.event != null:
		head = TIP_EVENT % [head, model.title(), model.effect()]
	tooltip_text = TIP % head


## Shows the short name, or hides it when the bar has no room (TopBar.fit_inspection).
func show_name(shown: bool) -> void:
	_name_box.visible = shown and not _name.text.is_empty()


func name_shown() -> bool:
	return _name_box.visible


## Shows the pips, or hides them when the bar has no room even without the name
## (TopBar.fit_inspection: the day's effects come first).
func show_pips(shown: bool) -> void:
	_pips_view.visible = shown


func pips_shown() -> bool:
	return _pips_view.visible


## The pips view's size: the week's pips at PIP_SIZE, PIP_GAP apart (pip_metrics' whole screen
## pixels never take more).
func _size_pips() -> void:
	var width: float = _pips.size() * PIP_SIZE + maxi(_pips.size() - 1, 0) * PIP_GAP
	_pips_view.custom_minimum_size = Vector2(width, PIP_SIZE)
	_pips_view.queue_redraw()


## The labels and the pips (for layout tests).
func key_label() -> Label:
	return _key


func number_label() -> Label:
	return _number


func count_label() -> Label:
	return _count


func name_label() -> Label:
	return _name


func pips_view() -> Control:
	return _pips_view


## The pips shown, in order.
func pips() -> Array[WeekCardModel.Pip]:
	return _pips.duplicate()


## The name's capitals centred on the chip's height, on the art's grid.
func _place_name() -> void:
	UiKit.place_pixel_label(_name, Rect2(Vector2.ZERO, _name_box.size), true)


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


## Pip `index`'s square in the pips view (pip_screen_rect's, back on the canvas).
func pip_rect(index: int) -> Rect2:
	return _to_screen().affine_inverse() * pip_screen_rect(index)


## Pip `index`'s square in whole pixels of the screen (the row centres the view, which can leave
## it on a half pixel, and the window's stretch scales the canvas: 1.5x at 1920x1080): every pip
## pip_metrics' side, its gap apart, centred in the pips view.
func pip_screen_rect(index: int) -> Rect2:
	var screen: Transform2D = _to_screen()
	var metrics: Vector3i = pip_metrics(screen.get_scale().x)
	var side: int = metrics.y
	var count: int = _pips.size()
	var used: int = count * side + maxi(count - 1, 0) * metrics.z
	var view: Rect2 = screen * Rect2(Vector2.ZERO, _pips_view.custom_minimum_size)
	var corner: Vector2 = (view.position + (view.size - Vector2(used, side)) / 2.0).round()
	return Rect2(corner + Vector2(index * (side + metrics.z), 0.0), Vector2(side, side))


## The pips at `scale_x` screen pixels per canvas pixel, in whole screen pixels: x the glyph's
## pixel (the scale's whole part), y the pip's side (PIP_SIZE scaled, down to the glyph plus an
## even margin, so the glyph sits centred), z the gap (PIP_GAP scaled, down). None is more than
## the canvas size scaled, so the pips fit the view: 1, 9, 2 at 1x; 1, 13, 3 at 1.5x; 2, 18, 4 at
## 2x.
static func pip_metrics(scale_x: float) -> Vector3i:
	var cell: int = maxi(1, floori(scale_x + 0.001))
	var margin: int = maxi(0, floori((PIP_SIZE * scale_x - GLYPH_CELLS * cell) / 2.0 + 0.001))
	var gap: int = maxi(1, floori(PIP_GAP * scale_x + 0.001))
	return Vector3i(cell, GLYPH_CELLS * cell + 2 * margin, gap)


## The pips view's transform to the screen's pixels (none out of the tree).
func _to_screen() -> Transform2D:
	return screen_transform(_pips_view) if _pips_view.is_inside_tree() else Transform2D.IDENTITY


## `item`'s transform to the window's pixels: its canvas's, then the stretch's. A window smaller
## than the canvas (its pixels coarser than the canvas's) keeps the canvas's pixels.
static func screen_transform(item: CanvasItem) -> Transform2D:
	var canvas: Transform2D = item.get_global_transform_with_canvas()
	var stretch: Transform2D = item.get_viewport().get_final_transform()
	return stretch * canvas if stretch.get_scale().x >= 1.0 else canvas


## The pixels of `pip`'s glyph on its 9x9 square: the check for PAID, the cross for SLIP, none
## for the others.
static func glyph_pixels(pip: WeekCardModel.Pip) -> Array[Vector2i]:
	match pip:
		WeekCardModel.Pip.PAID:
			return CHECK_PIXELS
		WeekCardModel.Pip.SLIP:
			return CROSS_PIXELS
	return []


## Draws in the screen's pixels (pip_screen_rect), so every pip, gap and glyph pixel is whole.
func _draw_pips() -> void:
	var screen: Transform2D = _to_screen()
	_pips_view.draw_set_transform_matrix(screen.affine_inverse())
	var cell: int = pip_metrics(screen.get_scale().x).x
	for index: int in range(_pips.size()):
		var at: Rect2 = pip_screen_rect(index)
		match _pips[index]:
			WeekCardModel.Pip.DONE:
				_pips_view.draw_rect(at, Palette.PAPER)
			WeekCardModel.Pip.NOW:
				_pips_view.draw_rect(at, Palette.INK)
				_pips_view.draw_rect(at.grow(-cell), Palette.GOLD)
			WeekCardModel.Pip.PAID, WeekCardModel.Pip.SLIP:
				if index != _flash_index or _flash_t < 0.0:
					_draw_result(at, _pips[index], cell)
			_:
				_pips_view.draw_rect(at, Color(Palette.PAPER, TODO_ALPHA))
	if _flash_t >= 0.0 and _flash_index >= 0:
		_draw_light(screen.get_scale().x, cell)
	_pips_view.draw_set_transform_matrix(Transform2D.IDENTITY)


## The lit pip, in screen pixels (`scale_x` of them per canvas pixel, the glyph's `cell` wide): a
## square glow that widens and fades, under the pip popping from 3x to 1x in whole steps.
func _draw_light(scale_x: float, cell: int) -> void:
	var k: float = _flash_t / FLASH
	var pip: Rect2 = pip_screen_rect(_flash_index)
	var reach: float = roundf(GLOW_REACH * scale_x * k)
	var glow: Color = Color(_light_of(_pips[_flash_index]), GLOW_ALPHA * (1.0 - k))
	_pips_view.draw_rect(pip.grow(reach), glow)
	var step: int = maxi(1, FLASH_SCALE - floori(k * 2.0 * FLASH_SCALE))
	var side: float = pip.size.x * step
	var corner: Vector2 = (pip.get_center() - Vector2(side, side) / 2.0).round()
	_draw_result(Rect2(corner, Vector2(side, side)), _pips[_flash_index], cell * step)


## A result pip in `at` (screen pixels), its glyph's pixels `cell` px wide and centred: a green
## light with an ink check, or a tomato one with a paper cross.
func _draw_result(at: Rect2, pip: WeekCardModel.Pip, cell: int) -> void:
	var paid: bool = pip == WeekCardModel.Pip.PAID
	_pips_view.draw_rect(at, _light_of(pip))
	var ink: Color = Palette.INK if paid else Palette.PAPER
	var margin: float = floorf((at.size.x - GLYPH_CELLS * cell) / 2.0)
	var origin: Vector2 = at.position + Vector2(margin, margin)
	for pixel: Vector2i in glyph_pixels(pip):
		_pips_view.draw_rect(Rect2(origin + Vector2(pixel * cell), Vector2(cell, cell)), ink)


static func _light_of(pip: WeekCardModel.Pip) -> Color:
	return Palette.GREEN_LIGHT if pip == WeekCardModel.Pip.PAID else Palette.TOMATO
