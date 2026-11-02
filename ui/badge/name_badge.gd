class_name NameBadge
extends Control
## The cashier's name badge (#122, full build plan 7.4; decided with the user on 2026-10-31): the
## badge the pins are worn on, drawn here on the 2 px art grid as its own UI object, never part of
## the cashier's art (the shift screen's backdrop and cashier will be redrawn, #123). A steel clip
## on top, a brass plate with a gold glint and an ink outline, a teal band with NEXT CUSTOMER in
## paper, CASHIER on a paper face with a ruled name line, and one PinFace per badge slot along its
## foot (an empty slot: a dashed ring). Display only: show_pins says what is worn.

## The badge's size in canvas px (its art px at 2x).
const SIZE := Vector2(240, 152)
const PX := 2.0
const CLIP := Rect2(104, 0, 32, 12)
const PLATE := Rect2(0, 8, 240, 144)
const BAND_HEIGHT := 28.0
const BAND_TEXT := "NEXT CUSTOMER"
const NAME_TEXT := "CASHIER"
const NAME_AT := Vector2(20, 48)
const LINE_Y := 76.0
const PIN_SIZE := 44.0
const PIN_TOP := 92.0
const PIN_STEP := 56.0
const SHADOW := Vector2(4, 4)

var _pins: Array[PinFace] = []
var _band: Label
var _name: Label


func _init() -> void:
	name = "NameBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	_band = UiKit.pixel_label(BAND_TEXT, 2, Palette.PAPER)
	add_child(_band)
	UiKit.place_pixel_label(
		_band,
		Rect2(PLATE.position + Vector2(0, 2 * PX), Vector2(PLATE.size.x, BAND_HEIGHT - 4)),
		true
	)
	_band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name = UiKit.pixel_label(NAME_TEXT, 2, Palette.INK_LIGHT)
	_name.position = NAME_AT
	add_child(_name)
	show_pins([], 1)


## Shows `pins` worn (in slot order, with their catalogue places `indexes`) in `slots` slots,
## the rest empty.
func show_pins(pins: Array[PinDefinition], slots: int, indexes: Array[int] = []) -> void:
	for face: PinFace in _pins:
		remove_child(face)
		face.free()
	_pins = []
	var count: int = maxi(slots, 1)
	var left: float = roundf((SIZE.x - (count - 1) * PIN_STEP - PIN_SIZE) / 2.0)
	for slot: int in count:
		var face: PinFace = PinFace.new(PIN_SIZE)
		face.name = "Slot%d" % slot
		face.position = Vector2(left + slot * PIN_STEP, PIN_TOP)
		if slot < pins.size():
			face.show_pin(pins[slot], indexes[slot] if slot < indexes.size() else slot)
		add_child(face)
		_pins.append(face)


## The slots' faces, left first.
func slot_faces() -> Array[PinFace]:
	return _pins


func _draw() -> void:
	draw_rect(Rect2(PLATE.position + SHADOW, PLATE.size), Color(Palette.INK, 0.45))
	draw_rect(CLIP, Palette.INK)
	draw_rect(CLIP.grow(-PX), Palette.STEEL_LIGHT)
	draw_rect(
		Rect2(CLIP.position + Vector2(PX, PX), Vector2(CLIP.size.x - 2 * PX, PX)),
		Palette.STEEL_HIGHLIGHT
	)
	draw_rect(PLATE, Palette.INK)
	var brass: Rect2 = PLATE.grow(-PX)
	draw_rect(brass, Palette.BRASS)
	draw_rect(Rect2(brass.position, Vector2(brass.size.x, PX)), Palette.GOLD)
	draw_rect(Rect2(brass.position.x, brass.end.y - PX, brass.size.x, PX), Palette.BRASS_DARK)
	var face: Rect2 = brass.grow(-2 * PX)
	draw_rect(face, Palette.PAPER)
	draw_rect(Rect2(face.position, Vector2(face.size.x, BAND_HEIGHT - 4)), Palette.TEAL)
	draw_rect(
		Rect2(face.position.x, face.position.y + BAND_HEIGHT - 4 - PX, face.size.x, PX),
		Palette.TEAL_DARK
	)
	for x: float in range(int(NAME_AT.x), int(SIZE.x - NAME_AT.x), int(2 * PX)):
		draw_rect(Rect2(x, LINE_Y, PX, PX), Palette.GREY_LIGHT)
