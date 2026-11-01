class_name PinFace
extends Control
## A badge pin's round face (#122, full build plan 7.4), drawn on the 2 px art grid: an ink rim, a
## RIM px band in the pin's dark colour, the face in its colour with a light glint top left, and
## the pin's few letters (PinDefinition.face_text) in the number font, centred. A locked pin is
## grey with "?"; an empty slot is a dashed ring (show_empty). Its own UI object: the badge, the
## badge screen's rows and the REWARDS card all show pins with it. Display only.

## The pins' colours, by their place in the catalogue (wrapping): face, dark band, glint.
const COLOURS: Array[Array] = [
	[Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT],
	[Palette.TEAL, Palette.TEAL_DARK, Palette.TEAL_LIGHT],
	[Palette.MUSTARD, Palette.MUSTARD_DARK, Palette.MUSTARD_LIGHT],
	[Palette.VELVET, Palette.VELVET_DARK, Palette.VELVET_SHEEN],
]
const LOCKED_COLOURS: Array[Color] = [Palette.GREY_LIGHT, Palette.GREY, Palette.CREAM]
## The art px: the grid, the rim, the glint's size.
const PX := 2.0
const RIM := 2
const FONT_SIZE := 16
const LOCKED_TEXT := "?"
## The empty slot's ring: a dash every DASH art px.
const DASH := 3

var _colours: Array = []
var _empty: bool = false
var _label: Label


## A face `diameter` canvas px wide (a multiple of 4).
func _init(diameter: float = 48.0) -> void:
	name = "PinFace"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(diameter, diameter)
	custom_minimum_size = size
	_label = UiKit.number_label("", FONT_SIZE, true)
	_label.name = "Letters"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2.ZERO
	_label.size = size
	add_child(_label)
	show_empty()


## Shows `pin`, the `index`-th pin of the catalogue (its colour), or its locked face.
func show_pin(pin: PinDefinition, index: int, locked: bool = false) -> void:
	_empty = false
	_colours = LOCKED_COLOURS if locked else COLOURS[posmod(index, COLOURS.size())]
	_label.text = LOCKED_TEXT if locked else pin.face_text
	_label.add_theme_color_override("font_color", Palette.INK if locked else Palette.PAPER)
	_label.add_theme_color_override("font_outline_color", _colours[1])
	_label.visible = true
	queue_redraw()


## An empty slot: a dashed ring.
func show_empty() -> void:
	_empty = true
	_label.visible = false
	queue_redraw()


func is_empty() -> bool:
	return _empty


## The letters shown ("" for an empty slot).
func letters() -> String:
	return "" if _empty else _label.text


func _draw() -> void:
	var cells: int = int(size.x / PX)
	var radius: float = cells / 2.0
	for row: int in cells:
		var y: float = row + 0.5 - radius
		var half: int = int(roundf(sqrt(maxf(radius * radius - y * y, 0.0))))
		var from: int = int(radius) - half
		var to: int = int(radius) + half
		if _empty:
			for column: int in [from, to - 1]:
				if row % DASH != 0:
					_cell(column, row, Palette.GREY)
			continue
		for column: int in range(from, to):
			_cell(column, row, _colour_at(column, row, radius))


## The cell's colour: the ink outline, the dark band, the glint, or the face.
func _colour_at(column: int, row: int, radius: float) -> Color:
	var distance: float = Vector2(column + 0.5 - radius, row + 0.5 - radius).length()
	if distance > radius - 1.0:
		return Palette.INK
	if distance > radius - 1.0 - RIM:
		return _colours[1]
	var glint: Vector2 = Vector2(radius * 0.55, radius * 0.55)
	if Vector2(column + 0.5, row + 0.5).distance_to(glint) < radius * 0.22:
		return _colours[2]
	return _colours[0]


func _cell(column: int, row: int, colour: Color) -> void:
	draw_rect(Rect2(column * PX, row * PX, PX, PX), colour)
