class_name GlyphTip
extends Control
## A family glyph's tooltip (#105, mock-up readability v3, tipBox and tipHTML): the family's name in
## paper (the body font at ArtStyle.TIP_TEXT_WEIGHT, TIP_TEXT_SIZE px) on the glyph_tip 9-slice
## (ink outline, ink light face), HEIGHT tall and as wide as its text plus TEXT_ROOM (rounded up
## to even), with a hard ink drop shadow, and a tail pointing at the glyph. place() is the pure
## placement rule: below a rail or shelf ticket (its tail up), else above the glyph (its tail
## down). It pops in about its tail's tip (GlyphTips).
##
## A text wider than MAX_WIDTH (a keyword's meaning, #128) wraps at it: the box grows down in
## lines of the text's height, WRAP_PADDING over and under them, and an above tip grows upward
## from where a one-line tip would end, so its tail stays on the glyph.
##
## A tip whose right-click opens the staff handbook (v1.06, GlyphTips.guide_for) says so on a
## footer line under its text: GUIDE_HINT, smaller and in mustard light, HINT_ROOM taller.

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
## The widest a tip grows: a longer text wraps.
const MAX_WIDTH := 340.0
const WRAP_PADDING := 6.0
## The handbook footer: its text, size and the room it adds under the tip's text.
const GUIDE_HINT := "Right-click: open the guide"
const HINT_SIZE := 11
const HINT_ROOM := 16.0
const HINT_LIFT := 2.0

const FRAME := preload("res://art/frames/glyph_tip.png")
const TAIL := preload("res://art/frames/glyph_tip_tail.png")

## Whether it opened below its glyph's ticket.
var below: bool = false
var _label: Label
var _hint: Label
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
	_hint = UiKit.body_label(GUIDE_HINT, HINT_SIZE, Palette.MUSTARD_LIGHT)
	_hint.name = "GuideHint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint.visible = false
	add_child(_hint)
	_tail = UiKit.sprite(TAIL)
	_tail.name = "Tail"
	_tail.size = TAIL_SIZE
	add_child(_tail)


## The tip's width for `text`: its text's width plus TEXT_ROOM, rounded up to even, at most
## MAX_WIDTH.
static func width_for(text: String) -> float:
	var font: Font = ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT)
	var width: float = (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.TIP_TEXT_SIZE).x
	)
	return minf(ceilf((width + TEXT_ROOM) / 2.0) * 2.0, MAX_WIDTH)


## Whether `text` wraps (wider than MAX_WIDTH on one line).
static func wraps(text: String) -> bool:
	var font: Font = ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT)
	var width: float = (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.TIP_TEXT_SIZE).x
	)
	return ceilf((width + TEXT_ROOM) / 2.0) * 2.0 > MAX_WIDTH


## The tip's size for `text`: HEIGHT tall on one line; a wrapping text's lines plus WRAP_PADDING
## over and under them (rounded up to even).
static func size_for(text: String) -> Vector2:
	var width: float = width_for(text)
	if not wraps(text):
		return Vector2(width, HEIGHT)
	var font: Font = ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT)
	var lines: Vector2 = font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, width - TEXT_ROOM, ArtStyle.TIP_TEXT_SIZE
	)
	var height: float = maxf(HEIGHT, ceilf((lines.y + WRAP_PADDING * 2.0) / 2.0) * 2.0)
	return Vector2(width, height)


## The tip's size for `text`, with the handbook footer when `guide`: size_for's, HINT_ROOM taller
## and at least as wide as the footer's text plus TEXT_ROOM.
static func size_with(text: String, guide: bool) -> Vector2:
	var tip_size: Vector2 = size_for(text)
	if not guide:
		return tip_size
	var font: Font = ArtStyle.BODY_FONT
	var width: float = font.get_string_size(GUIDE_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
	tip_size.x = maxf(tip_size.x, ceilf((width + TEXT_ROOM) / 2.0) * 2.0)
	return tip_size + Vector2(0.0, HINT_ROOM)


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
		var grown: float = tip_size.y - HEIGHT
		at = Vector2(roundf(cx - tip_size.x / 2.0), glyph_rect.position.y - ABOVE_GAP - grown)
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
## `opens_below`) inside `screen`, all in this tip's parent's coordinates; with the handbook
## footer when `guide`.
func show_for(
	text: String,
	glyph_rect: Rect2,
	anchor_rect: Rect2,
	opens_below: bool,
	screen: Rect2,
	guide: bool = false
) -> void:
	_label.text = text
	var wrapped: bool = wraps(text)
	_label.autowrap_mode = (TextServer.AUTOWRAP_WORD_SMART if wrapped else TextServer.AUTOWRAP_OFF)
	_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if wrapped else HORIZONTAL_ALIGNMENT_CENTER
	)
	var tip_size: Vector2 = size_with(text, guide)
	var box: Rect2 = place(glyph_rect, anchor_rect, opens_below, tip_size, screen)
	below = is_below(box, glyph_rect)
	position = box.position
	size = box.size
	_shadow.size = size
	_face.size = size
	var inset: float = (TEXT_ROOM / 2.0) if wrapped else 0.0
	# The footer sits HINT_LIFT over the box's foot (clear of its shadowed outline).
	var footer: float = (HINT_ROOM + HINT_LIFT) if guide else 0.0
	_label.position = Vector2(inset, 0.0)
	_label.size = Vector2(size.x - inset * 2.0, size.y - footer)
	_hint.visible = guide
	_hint.position = Vector2(0.0, size.y - footer)
	_hint.size = Vector2(size.x, HINT_ROOM)
	_tail.flip_v = below
	var tail_y: float = TAIL_BELOW_Y if below else size.y - HEIGHT + TAIL_ABOVE_Y
	_tail.position = Vector2(tail_x(box, glyph_rect), tail_y)
	pivot_offset = Vector2(_tail.position.x + TAIL_SIZE.x / 2.0, 0.0 if below else size.y)


func tip_text() -> String:
	return _label.text


func label() -> Label:
	return _label


## The handbook footer (shown only on a tip whose right-click opens the guide).
func hint() -> Label:
	return _hint


func tail() -> TextureRect:
	return _tail


func _panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ArtStyle.frame_style(FRAME, FRAME_MARGIN))
	ArtStyle.use_pixel_material(panel)
	return panel
