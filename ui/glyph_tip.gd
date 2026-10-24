class_name GlyphTip
extends Control
## A family glyph's tooltip (#105, mock-up readability v3, tipBox and tipHTML): the family's name in
## paper (the body font at ArtStyle.TIP_TEXT_WEIGHT, TIP_TEXT_SIZE px) on the glyph_tip 9-slice
## (ink outline, ink light face), HEIGHT tall and as wide as its text plus TEXT_ROOM (rounded up
## to even), with a hard ink drop shadow, and a tail pointing at the glyph. place() is the pure
## placement rule: below a rail or shelf ticket (its tail up), else above the glyph (its tail
## down). It pops in about its tail's tip (GlyphTips).

const HEIGHT := 26.0
## The text's room: the frame's 2 art px border and PADDING on each side.
const TEXT_ROOM := 26.0
const PADDING := 9.0
const FRAME_MARGIN := 2
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.45
const TAIL_SIZE := Vector2(14, 8)
## Below a ticket: the box's top BELOW_GAP under the ticket's foot, its right end BELOW_RIGHT past
## the glyph's middle, the tail's top TAIL_BELOW_Y over the box's (it covers the outline).
const BELOW_GAP := 12.0
const BELOW_RIGHT := 14.0
const TAIL_BELOW_Y := -6.0
## Above a glyph: the box's top ABOVE_GAP over the glyph's top, the tail at TAIL_ABOVE_Y.
const ABOVE_GAP := 36.0
const TAIL_ABOVE_Y := 24.0
## The tail stays this far inside the box's ends.
const TAIL_INSET := 4.0
## The least room from the screen's edges.
const SCREEN_MARGIN := 16.0

const FRAME := preload("res://art/frames/glyph_tip.png")
const TAIL := preload("res://art/frames/glyph_tip_tail.png")

## Whether it opened below its glyph's ticket.
var below: bool = false
var _label: Label
var _tail: TextureRect
var _shadow: Panel
var _face: Panel


func _init() -> void:
	name = "GlyphTip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = _panel()
	_shadow.name = "Shadow"
	_shadow.position = SHADOW_OFFSET
	_shadow.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
	add_child(_shadow)
	_face = _panel()
	_face.name = "Face"
	add_child(_face)
	_label = UiKit.body_label("", ArtStyle.TIP_TEXT_SIZE, Palette.PAPER)
	_label.name = "Text"
	_label.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_tail = UiKit.sprite(TAIL)
	_tail.name = "Tail"
	_tail.size = TAIL_SIZE
	add_child(_tail)


## The tip's width for `text`: its text's width plus TEXT_ROOM, rounded up to even.
static func width_for(text: String) -> float:
	var font: Font = ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT)
	var width: float = (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.TIP_TEXT_SIZE).x
	)
	return ceilf((width + TEXT_ROOM) / 2.0) * 2.0


## The tip's box for a glyph at `glyph_rect` on a ticket at `anchor_rect` (opening `below` it, else
## above the glyph), `tip_size` big, inside `screen` (all in one set of coordinates). Below: its
## top BELOW_GAP under the ticket's foot, its right end BELOW_RIGHT past the glyph's middle; above:
## centred on the glyph, its top ABOVE_GAP over the glyph's. A tip below that would leave the
## screen opens above; it is kept SCREEN_MARGIN inside the screen's sides.
static func place(
	glyph_rect: Rect2, anchor_rect: Rect2, opens_below: bool, tip_size: Vector2, screen: Rect2
) -> Rect2:
	var cx: float = glyph_rect.get_center().x
	var at: Vector2
	if opens_below:
		at = Vector2(roundf(cx + BELOW_RIGHT - tip_size.x), anchor_rect.end.y + BELOW_GAP)
		if at.y + tip_size.y > screen.end.y - SCREEN_MARGIN:
			opens_below = false
	if not opens_below:
		at = Vector2(roundf(cx - tip_size.x / 2.0), glyph_rect.position.y - ABOVE_GAP)
	at.x = clampf(
		at.x, screen.position.x + SCREEN_MARGIN, screen.end.x - SCREEN_MARGIN - tip_size.x
	)
	at.y = maxf(at.y, screen.position.y)
	return Rect2(at, tip_size)


## Whether a box from place() opened below its glyph (its top under the glyph's).
static func is_below(box: Rect2, glyph_rect: Rect2) -> bool:
	return box.position.y > glyph_rect.position.y


## The tail's left in a `box` from place() for a glyph at `glyph_rect`: under (or over) the
## glyph's middle, kept TAIL_INSET inside the box.
static func tail_x(box: Rect2, glyph_rect: Rect2) -> float:
	var x: float = roundf(glyph_rect.get_center().x - box.position.x - TAIL_SIZE.x / 2.0)
	return clampf(x, TAIL_INSET, box.size.x - TAIL_INSET - TAIL_SIZE.x)


## Shows `text` for a glyph at `glyph_rect` (its ticket at `anchor_rect`, opening below it when
## `opens_below`) inside `screen`, all in this tip's parent's coordinates.
func show_for(
	text: String, glyph_rect: Rect2, anchor_rect: Rect2, opens_below: bool, screen: Rect2
) -> void:
	_label.text = text
	var tip_size: Vector2 = Vector2(width_for(text), HEIGHT)
	var box: Rect2 = place(glyph_rect, anchor_rect, opens_below, tip_size, screen)
	below = is_below(box, glyph_rect)
	position = box.position
	size = box.size
	_shadow.size = size
	_face.size = size
	_label.position = Vector2.ZERO
	_label.size = size
	_tail.flip_v = below
	_tail.position = Vector2(tail_x(box, glyph_rect), TAIL_BELOW_Y if below else TAIL_ABOVE_Y)
	pivot_offset = Vector2(_tail.position.x + TAIL_SIZE.x / 2.0, 0.0 if below else HEIGHT)


func tip_text() -> String:
	return _label.text


func label() -> Label:
	return _label


func tail() -> TextureRect:
	return _tail


func _panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ArtStyle.frame_style(FRAME, FRAME_MARGIN))
	ArtStyle.use_pixel_material(panel)
	return panel
