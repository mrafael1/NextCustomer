class_name PinTip
extends Control
## A worn badge pin's card on the shift screen (mock-up shift_scene_polish_v2 section 3, variant
## C): the glyph tooltip's look (GlyphTip: the glyph_tip 9-slice, its hard ink drop shadow and its
## tail) grown into a card WIDTH wide. The pin's face (PinFace) and its name in pixel words on top,
## its rule in the tooltip's text under them, the charges it has left (`charges`, e.g. "1 relabel
## left this shift") in teal light, and a muted foot saying a click keeps it open (or closes it,
## once kept). It opens under its pin (GlyphTip.place's below rule: its right end past the pin's
## middle, so it grows left, away from the monitor), its tail up at the pin. Display only: it takes
## no clicks (PinLanyard opens, keeps and closes it).

const WIDTH := 260.0
const PADDING := 10.0
const FACE_SIZE := 28.0
## The name's left (right of the face) and the gap under the face to the rule.
const NAME_X := 46.0
const RULE_GAP := 8.0
const LINE_GAP := 4.0
const FOOT_SIZE := 11
const FOOT_HINT := "Badge pin · click to keep it open"
const FOOT_KEPT := "Badge pin · click again to close"

var _shadow: Panel
var _face_panel: Panel
var _face: PinFace
var _name: Label
var _rule: Label
var _charges: Label
var _foot: Label
var _tail: TextureRect


func _init() -> void:
	name = "PinTip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = _panel()
	_shadow.name = "Shadow"
	_shadow.position = GlyphTip.SHADOW_OFFSET
	_shadow.self_modulate = Color(Palette.INK, GlyphTip.SHADOW_ALPHA)
	add_child(_shadow)
	_face_panel = _panel()
	_face_panel.name = "Face"
	add_child(_face_panel)
	_face = PinFace.new(FACE_SIZE)
	_face.position = Vector2(PADDING, PADDING)
	add_child(_face)
	_name = UiKit.pixel_label("", 2, Palette.PAPER)
	_name.name = "PinName"
	add_child(_name)
	_rule = _text("Rule", ArtStyle.TIP_TEXT_SIZE, Palette.PAPER)
	_charges = _text("Charges", ArtStyle.TIP_TEXT_SIZE, Palette.TEAL_LIGHT)
	_foot = _text("Foot", FOOT_SIZE, Palette.GREY_LIGHT)
	_tail = UiKit.sprite(GlyphTip.TAIL)
	_tail.name = "Tail"
	_tail.size = GlyphTip.TAIL_SIZE
	_tail.flip_v = true
	add_child(_tail)


## Shows `pin` (the `index`-th of the catalogue, for its colour) with `charges` ("" for none),
## `kept` (open on a click), under its pin at `pin_rect` on the badge at `badge_rect`, inside
## `screen`: all in this card's parent's coordinates.
func show_for(
	pin: PinDefinition,
	index: int,
	charges: String,
	kept: bool,
	pin_rect: Rect2,
	badge_rect: Rect2,
	screen: Rect2
) -> void:
	_face.show_pin(pin, index)
	_name.text = pin.display_name.to_upper()
	UiKit.place_pixel_label(
		_name, Rect2(NAME_X, PADDING, WIDTH - NAME_X - PADDING, FACE_SIZE), true
	)
	var inner: float = WIDTH - PADDING * 2.0
	var y: float = PADDING + FACE_SIZE + RULE_GAP
	y = _put(_rule, pin.rule_text, y, inner)
	_charges.visible = not charges.is_empty()
	if _charges.visible:
		y = _put(_charges, charges, y + LINE_GAP, inner)
	y = _put(_foot, FOOT_KEPT if kept else FOOT_HINT, y + LINE_GAP, inner)
	var card_size: Vector2 = Vector2(WIDTH, ceilf((y + PADDING) / 2.0) * 2.0)
	var box: Rect2 = GlyphTip.place(pin_rect, badge_rect, true, card_size, screen)
	position = box.position
	size = box.size
	_shadow.size = size
	_face_panel.size = size
	var below: bool = GlyphTip.is_below(box, pin_rect)
	_tail.flip_v = below
	var tail_y: float = GlyphTip.TAIL_BELOW_Y if below else size.y - 2.0
	_tail.position = Vector2(GlyphTip.tail_x(box, pin_rect), tail_y)
	pivot_offset = Vector2(_tail.position.x + GlyphTip.TAIL_SIZE.x / 2.0, 0.0 if below else size.y)


func pin_name() -> String:
	return _name.text


func rule_text() -> String:
	return _rule.text


## The charges line shown ("" for none).
func charges_text() -> String:
	return _charges.text if _charges.visible else ""


func foot_text() -> String:
	return _foot.text


func face() -> PinFace:
	return _face


## Sets `label` to `text` wrapped at `width`, its top at `y`; returns its foot (on the 2 px grid).
func _put(label: Label, text: String, y: float, width: float) -> float:
	label.text = text
	label.position = Vector2(PADDING, y)
	label.size = Vector2(width, 0.0)
	var height: float = ceilf(label.get_minimum_size().y / 2.0) * 2.0
	label.size = Vector2(width, height)
	return y + height


func _text(label_name: String, font_size: int, colour: Color) -> Label:
	var label: Label = UiKit.body_label("", font_size, colour)
	label.name = label_name
	label.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", ArtStyle.frame_style(GlyphTip.FRAME, GlyphTip.FRAME_MARGIN)
	)
	ArtStyle.use_pixel_material(panel)
	return panel
