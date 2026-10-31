class_name ToyPlate
extends Control
## A shelf label at the TOY MACHINES (#121, the title's direction C+): the menu plate's cream
## frames without their aisle stripe (frames/toy_plate, its lit and off twins, v0.78) as a label
## that takes no clicks, for a machine's sign and its floor plate. A price-gun tick
## (MenuPlate.TICK) can mark it on the left. Its text is a PixelLine added to `content()`.
##
## Its size is in art px: `plate_size` wide and a face `plate_size.y` rows tall, plus the frame's
## three-row brass ledge (the mock-up's plate(x, y, w, h)).

enum Mode { NORMAL, LIT, OFF }

const LEDGE_ROWS := 3
## The frames (normal, lit, off): 9-slices with MenuPlate.PLATE_MARGIN art px margins.
const FRAMES: Array[Texture2D] = [
	preload("res://art/frames/toy_plate.png"),
	preload("res://art/frames/toy_plate_lit.png"),
	preload("res://art/frames/toy_plate_off.png"),
]
## The price-gun tick's top left from the plate's, in art px.
const TICK_AT := Vector2i(-7, 4)

var _art_size: Vector2i
var _face: Panel
var _styles: Array[StyleBoxTexture] = []
var _tick: TextureRect
var _content: Control
var _mode: Mode = Mode.NORMAL


func _init(plate_size: Vector2i) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_size = plate_size
	var art: float = ArtStyle.ART_SCALE
	size = Vector2(plate_size.x, plate_size.y + LEDGE_ROWS) * art
	for frame: Texture2D in FRAMES:
		_styles.append(ArtStyle.frame_style(frame, MenuPlate.PLATE_MARGIN))
	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = size
	ArtStyle.use_pixel_material(_face)
	add_child(_face)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = size
	add_child(_content)
	_tick = UiKit.sprite(MenuPlate.TICK)
	_tick.size = MenuPlate.TICK_SIZE
	_tick.position = Vector2(TICK_AT) * art
	_tick.visible = false
	add_child(_tick)
	set_mode(Mode.NORMAL)


## The plate's look: NORMAL, LIT (paper face, gold ledge) or OFF (cream-shade face).
func set_mode(shown: Mode) -> void:
	_mode = shown
	_face.add_theme_stylebox_override("panel", _styles[shown])


func mode() -> Mode:
	return _mode


## Shows the price-gun tick left of the plate (the hovered machine's floor plate).
func show_tick(on: bool) -> void:
	_tick.visible = on


func tick() -> TextureRect:
	return _tick


## The plate's size in art px (its face; the ledge is under it).
func art_size() -> Vector2i:
	return _art_size


## Where the plate's text goes (a PixelLine, placed in canvas px from the plate's top left).
func content() -> Control:
	return _content
