class_name ToyPlate
extends Control
## A shelf label at the TOY MACHINES (#121, the title's direction C+): MenuPlate's cream plate
## frames (menu_plate, its lit and off twins) as a label that takes no clicks, for a machine's
## sign, its floor plate and the lineup strip. Its stripe can take an aisle's sign colour and a
## width (the COLLECTED plate's 8 px green stripe, with a paper tick in it); a price-gun tick
## (MenuPlate.TICK) can mark it on the left. Its text is a PixelLine added to `content()`.
##
## Its size is in art px: `plate_size` wide and a face `plate_size.y` rows tall, plus the frame's
## three-row brass ledge (the mock-up's plate(x, y, w, h)).

enum Mode { NORMAL, LIT, OFF }

## The stripe's place on the face, in art px: right of the outline, under the paper top row,
## down to the cream-shade row.
const STRIPE_AT := Vector2i(1, 2)
const LEDGE_ROWS := 3
## The COLLECTED tick (paper, in the green stripe) and its top left on the plate, in art px.
const CHECK_ROWS: Array[String] = ["......#", ".....##", "#...##.", "##.##..", ".###..."]
const CHECK_AT := Vector2i(1, 5)
## The price-gun tick's top left from the plate's, in art px.
const TICK_AT := Vector2i(-7, 4)

var _art_size: Vector2i
var _face: Panel
var _styles: Array[StyleBoxTexture] = []
var _stripe: ColorRect
var _check: Control
var _tick: TextureRect
var _content: Control
var _mode: Mode = Mode.NORMAL


func _init(plate_size: Vector2i) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_size = plate_size
	var art: float = ArtStyle.ART_SCALE
	size = Vector2(plate_size.x, plate_size.y + LEDGE_ROWS) * art
	for frame: Texture2D in [
		MenuPlate.PLATE_FRAME, MenuPlate.PLATE_LIT_FRAME, MenuPlate.PLATE_OFF_FRAME
	]:
		_styles.append(ArtStyle.frame_style(frame, MenuPlate.PLATE_MARGIN))
	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = size
	ArtStyle.use_pixel_material(_face)
	add_child(_face)
	_stripe = ColorRect.new()
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stripe.position = Vector2(STRIPE_AT) * art
	_stripe.visible = false
	add_child(_stripe)
	_check = Control.new()
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.position = Vector2(CHECK_AT) * art
	_check.size = Vector2(CHECK_ROWS[0].length(), CHECK_ROWS.size()) * art
	_check.visible = false
	_check.draw.connect(_draw_check)
	add_child(_check)
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


## Paints the stripe `colour`, `width` art px wide (a transparent colour keeps the frame's own).
func set_stripe(colour: Color, width: int = 3) -> void:
	_stripe.visible = colour.a > 0.0
	_stripe.color = colour
	_stripe.size = Vector2(width, _art_size.y - LEDGE_ROWS) * ArtStyle.ART_SCALE


## Shows the paper tick in the stripe (the COLLECTED plate).
func show_check(on: bool) -> void:
	_check.visible = on


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


func _draw_check() -> void:
	var art: float = ArtStyle.ART_SCALE
	for row: int in CHECK_ROWS.size():
		for column: int in CHECK_ROWS[row].length():
			if CHECK_ROWS[row][column] == "#":
				_check.draw_rect(
					Rect2(Vector2(column, row) * art, Vector2.ONE * art), Palette.PAPER
				)
