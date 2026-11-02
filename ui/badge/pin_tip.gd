class_name PinTip
extends Control
## A worn badge pin's card on the shift screen (mock-up shift_scene_polish_v2 section 3, variant
## C, drawPinTip; approved 2026-11-02): a paper card (the pin_card 9-slice: an ink outline, a
## cream shade foot) with its hard ink drop shadow and its tail (pin_card_tail) up at the pin.
## On it the pin's face (PinFace) and its name in hard pixel words in ink, its rule in the body
## font in ink, the charges it has left (`charges`, e.g. "1 relabel left this shift") in teal
## shade after a dot, and a muted foot saying a click keeps it open (or closes it, once kept).
## WIDTH is narrower than the mock-up's 260 px so the card fits between the receipt and the
## monitor's screen: it opens under its pin, centred on it as far as `area` (PinLanyard's room
## for it) lets. Display only: it takes no clicks (PinLanyard opens, keeps and closes it).

const WIDTH := 200.0
## The face's place and size, the name's left (right of the face), the text's left and the
## gap under the pin to the card's top (the tail fills it).
const FACE_AT := Vector2(10, 8)
const FACE_SIZE := 28.0
const NAME_X := 46.0
const TEXT_X := 12.0
const RULE_TOP := 42.0
const LINE_GAP := 2.0
const FOOT_GAP := 4.0
## Under the foot's text: room for the cream shade foot and the outline.
const BOTTOM := 8.0
const GAP := 12.0
const RULE_SIZE := 14
const RULE_WEIGHT := 700
const CHARGES_SIZE := 13
const CHARGES_WEIGHT := 750
const FOOT_SIZE := 12
const FOOT_WEIGHT := 600
const CHARGES_MARK := "● "
const FOOT_HINT := "Badge pin · click to keep it open"
const FOOT_KEPT := "Badge pin · click again to close"
const FRAME := preload("res://art/frames/pin_card.png")
const FRAME_MARGIN := 3
const TAIL := preload("res://art/frames/pin_card_tail.png")
const TAIL_SIZE := Vector2(14, 8)
## The tail's top above the card (its bottom row lies on the card's top outline).
const TAIL_Y := -6.0
## The tail keeps this far from the card's sides.
const TAIL_INSET := 8.0
const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW_ALPHA := 0.4
const PX := 2.0

var _shadow: ColorRect
var _card: Panel
var _face: PinFace
var _name: Label
var _rule: Label
var _charges: Label
var _foot: Label
var _tail: TextureRect


func _init() -> void:
	name = "PinTip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = ColorRect.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.position = SHADOW_OFFSET
	_shadow.color = Color(Palette.INK, SHADOW_ALPHA)
	add_child(_shadow)
	_card = Panel.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", ArtStyle.frame_style(FRAME, FRAME_MARGIN))
	ArtStyle.use_pixel_material(_card)
	add_child(_card)
	_face = PinFace.new(FACE_SIZE)
	_face.position = FACE_AT
	add_child(_face)
	_name = UiKit.pixel_label("", 2, Palette.INK)
	_name.name = "PinName"
	add_child(_name)
	_rule = _text("Rule", RULE_SIZE, RULE_WEIGHT, Palette.INK)
	_charges = _text("Charges", CHARGES_SIZE, CHARGES_WEIGHT, Palette.TEAL_SHADE)
	_foot = _text("Foot", FOOT_SIZE, FOOT_WEIGHT, Palette.MUTED_INK)
	_tail = UiKit.sprite(TAIL)
	_tail.name = "Tail"
	_tail.size = TAIL_SIZE
	add_child(_tail)


## Shows `pin` (the `index`-th of the catalogue, for its colour) with `charges` ("" for none),
## `kept` (open on a click), under its pin at `pin_rect`, inside `area` (shadow included): all in
## this card's parent's coordinates.
func show_for(
	pin: PinDefinition, index: int, charges: String, kept: bool, pin_rect: Rect2, area: Rect2
) -> void:
	_face.show_pin(pin, index)
	_name.text = pin.display_name
	UiKit.place_pixel_label(
		_name, Rect2(NAME_X, FACE_AT.y, WIDTH - NAME_X - TEXT_X, FACE_SIZE), true
	)
	var inner: float = WIDTH - TEXT_X * 2.0
	var y: float = _put(_rule, pin.rule_text, RULE_TOP, inner)
	_charges.visible = not charges.is_empty()
	if _charges.visible:
		y = _put(_charges, CHARGES_MARK + charges, y + LINE_GAP, inner)
	y = _put(_foot, FOOT_KEPT if kept else FOOT_HINT, y + FOOT_GAP, inner)
	size = Vector2(WIDTH, ceilf((y + BOTTOM) / PX) * PX)
	var middle: float = pin_rect.get_center().x
	var left: float = roundf((middle - WIDTH / 2.0) / PX) * PX
	var right_most: float = area.end.x - SHADOW_OFFSET.x - WIDTH
	position = Vector2(clampf(left, area.position.x, right_most), pin_rect.end.y + GAP)
	_shadow.size = size
	_card.size = size
	var tail_left: float = roundf((middle - TAIL_SIZE.x / 2.0 - position.x) / PX) * PX
	tail_left = clampf(tail_left, TAIL_INSET, WIDTH - TAIL_INSET - TAIL_SIZE.x)
	_tail.position = Vector2(tail_left, TAIL_Y)
	pivot_offset = Vector2(tail_left + TAIL_SIZE.x / 2.0, TAIL_Y)


func pin_name() -> String:
	return _name.text


func rule_text() -> String:
	return _rule.text


## The charges shown, without the dot ("" for none).
func charges_text() -> String:
	return _charges.text.trim_prefix(CHARGES_MARK) if _charges.visible else ""


func foot_text() -> String:
	return _foot.text


func face() -> PinFace:
	return _face


## Sets `label` to `text` wrapped at `width`, its top at `y`; returns its foot (on the 2 px grid).
func _put(label: Label, text: String, y: float, width: float) -> float:
	label.text = text
	label.position = Vector2(TEXT_X, y)
	label.size = Vector2(width, 0.0)
	var height: float = ceilf(label.get_minimum_size().y / PX) * PX
	label.size = Vector2(width, height)
	return y + height


func _text(label_name: String, font_size: int, weight: int, colour: Color) -> Label:
	var label: Label = UiKit.body_label("", font_size, colour)
	label.name = label_name
	label.add_theme_font_override("font", ArtStyle.bold_font(weight))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
