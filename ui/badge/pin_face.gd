class_name PinFace
extends Control
## A badge pin's round face (#122, full build plan 7.4), drawn on the 2 px art grid: an ink rim, a
## RIM px band in the pin's dark colour, the face in its colour with a light glint top left, and
## the pin's icon centred at the art's scale (PinDefinition.icon, or icon_big from BIG_FACE up;
## sharp-pixel material, on the 2 px grid) or, without one, its few letters
## (PinDefinition.face_text) in the number font, centred (a face under 48 px a smaller size). A
## locked pin is
## grey with "?"; an empty slot is a dashed ring (show_empty). Its own UI object: the badge, the
## badge screen's rows and the start screen's pins card all show pins with it. Display only.

## The pins' colours: face, dark band, glint. A pin picks one (PinDefinition.face_colour), else
## it goes by its place in the catalogue (wrapping).
const COLOURS: Array[Array] = [
	[Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT],
	[Palette.TEAL, Palette.TEAL_DARK, Palette.TEAL_LIGHT],
	[Palette.MUSTARD, Palette.MUSTARD_DARK, Palette.MUSTARD_LIGHT],
	[Palette.VELVET, Palette.VELVET_DARK, Palette.VELVET_SHEEN],
	[Palette.GOOD, Palette.GREEN_DARK, Palette.GREEN_LIGHT],
	[Palette.GOLD, Palette.BRASS_DARK, Palette.MUSTARD_PALE],
	[Palette.BROWN, Palette.BROWN_DARKEST, Palette.BROWN_LIGHT],
	[Palette.SLATE, Palette.TEAL_BLACK, Palette.TEAL_SHADE],
]
const LOCKED_COLOURS: Array[Color] = [Palette.GREY_LIGHT, Palette.GREY, Palette.CREAM]
## The art px: the grid, the rim, the glint's size.
const PX := 2.0
const RIM := 2
const FONT_SIZE := 16
## The face FONT_SIZE is for: a smaller face gets letters in proportion.
const FONT_FACE := 48.0
const LOCKED_TEXT := "?"
## The smallest face (canvas px) that shows the large icon (PinDefinition.icon_big): the name
## badge's 44 px; the lanyard's and the tip's 32 px faces show the small one.
const BIG_FACE := 44.0
## The empty slot's ring: a dash every DASH art px.
const DASH := 3

var _colours: Array = []
var _empty: bool = false
var _label: Label
var _icon: TextureRect


## A face `diameter` canvas px wide (a multiple of 4).
func _init(diameter: float = 48.0) -> void:
	name = "PinFace"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(diameter, diameter)
	custom_minimum_size = size
	var font_size: int = FONT_SIZE
	if diameter < FONT_FACE:
		font_size = roundi(FONT_SIZE * diameter / FONT_FACE)
	_label = UiKit.number_label("", font_size, true)
	_label.name = "Letters"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2.ZERO
	_label.size = size
	add_child(_label)
	_icon = UiKit.sprite(null)
	_icon.name = "Icon"
	_icon.visible = false
	add_child(_icon)
	show_empty()


## Shows `pin`, the `index`-th pin of the catalogue, in its colour (colour_index), or its locked
## face.
func show_pin(pin: PinDefinition, index: int, locked: bool = false) -> void:
	_empty = false
	_colours = LOCKED_COLOURS if locked else COLOURS[colour_index(pin, index)]
	_label.text = LOCKED_TEXT if locked else pin.face_text
	_label.add_theme_color_override("font_color", Palette.INK if locked else Palette.PAPER)
	_label.add_theme_color_override("font_outline_color", _colours[1])
	_icon.texture = null if locked else icon_for(pin, size.x)
	_icon.visible = _icon.texture != null
	_label.visible = not _icon.visible
	_place_icon()
	queue_redraw()


## Scales the face `factor` about its pivot (a pop) while its icon keeps the art's whole scale
## and its resting place on the 2 px grid, so the icon stays crisp through the pop.
func set_pop_scale(factor: float) -> void:
	scale = Vector2.ONE * factor
	_place_icon()


## The icon a `diameter` face of `pin` shows: the large one (PinDefinition.icon_big) from
## `big_from` (BIG_FACE, canvas px) up, else the small one (either falls back to the other); null
## when it has none.
static func icon_for(pin: PinDefinition, diameter: float, big_from: float = BIG_FACE) -> Texture2D:
	if diameter >= big_from and pin.icon_big != null:
		return pin.icon_big
	return pin.icon if pin.icon != null else pin.icon_big


## The COLOURS entry of `pin`, the `index`-th pin of the catalogue: its face_colour, else its
## place (wrapping).
static func colour_index(pin: PinDefinition, index: int) -> int:
	if pin.face_colour > 0 and pin.face_colour <= COLOURS.size():
		return pin.face_colour - 1
	return posmod(index, COLOURS.size())


## An empty slot: a dashed ring.
func show_empty() -> void:
	_empty = true
	_label.visible = false
	_icon.visible = false
	queue_redraw()


func is_empty() -> bool:
	return _empty


## The icon at the art's whole scale, centred on the 2 px grid; under a pop (set_pop_scale) it
## undoes the face's scale and stays where it rests: pivot + (p - pivot) * s = rest.
func _place_icon() -> void:
	if not _icon.visible:
		return
	_icon.size = _icon.texture.get_size() * ArtStyle.ART_SCALE
	var rest: Vector2 = ((size - _icon.size) / 2.0 / PX).floor() * PX
	if scale.x <= 0.0 or is_equal_approx(scale.x, 1.0):
		_icon.scale = Vector2.ONE
		_icon.position = rest
		return
	_icon.scale = Vector2.ONE / scale.x
	_icon.position = pivot_offset + (rest - pivot_offset) / scale.x


## The letters shown ("" for an empty slot or a face showing its icon).
func letters() -> String:
	return "" if _empty or not _label.visible else _label.text


## The icon shown, or null (letters or an empty slot).
func icon() -> Texture2D:
	return _icon.texture if _icon.visible else null


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
