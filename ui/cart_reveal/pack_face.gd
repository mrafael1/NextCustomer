class_name PackFace
extends Control
## One starter pack on the start screen (#107, mock-up starter_choice_107.html layout A, v0.63;
## redrawn for the clock-in board, mock-up start_screen.html layout A, 2026-11-03): a face in the
## colour and glyph of the family its cards boost (FamilyPalette), its name and its key number (1 to
## 3), its three cards as compact cart tickets (their scan popup opens on hover) and its one line. A
## click picks it (set_raised: it lifts, takes a gold frame and a green PICKED tab); hovering
## lights its frame (and previews it in the cart sheet). The good first pick (Q3 B, until the
## profile's first win) wears a mustard GOOD FIRST PICK ribbon. Pure display: CartReveal routes the
## pointer and keys.

const SIZE := Vector2(248, 194)
const HEADER_HEIGHT := 38.0
const GLYPH_RECT := Rect2(10, 10, 18, 18)
const NAME_POSITION := Vector2(34, 4)
const NAME_SIZE := 20
## The cards: compact cart tickets, TILE_LEFT from the face's left, TILE_STEP apart.
const TILE_LEFT := 11.0
const TILE_TOP := 48.0
const TILE_STEP := 78.0
const HINT_RECT := Rect2(10, 154, 228, 36)
const HINT_SIZE := 12
const FRAME := 3.0
const RAISED_FRAME := 4.0
const SHADOW_DROP := 6.0
const RIBBON_TEXT := "GOOD FIRST PICK"
const RIBBON_SIZE := 11
const RIBBON_RECT := Rect2(120, -12, 122, 20)
## The PICKED tab (green, over the face's top left) and the key number (top right).
const PICKED_TEXT := "✓ PICKED"
const PICKED_RECT := Rect2(8, -12, 76, 20)
const KEY_RECT := Rect2(214, 9, 22, 20)
const KEY_SIZE := 14

var pack: StarterPackDefinition
var tiles: Array[CartTicket] = []
var raised: bool = false
var hovered: bool = false
var first_pick: bool = false
var picked_tab: RevealChip
var _style: FamilyStyle
var _name: Label
## The ribbon: its mustard tab, holding its label.
var _ribbon: Control


func _init(starter_pack: StarterPackDefinition, is_first_pick: bool = false, key: int = 0) -> void:
	pack = starter_pack
	first_pick = is_first_pick
	name = "PackFace_%s" % pack.id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_style = FamilyPalette.shared().style(pack.family)
	var glyph: TextureRect = null
	if _style != null and _style.glyph != null:
		glyph = UiKit.sprite(_style.glyph)
		glyph.position = GLYPH_RECT.position
		glyph.size = GLYPH_RECT.size
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(glyph)
	_name = UiKit.display_label(pack.display_name, NAME_SIZE, _paper_text())
	_name.position = NAME_POSITION
	_name.size = Vector2(KEY_RECT.position.x - NAME_POSITION.x - 4.0, HEADER_HEIGHT - 4.0)
	_name.clip_text = true
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name)
	for index: int in pack.cards.size():
		var tile: CartTicket = CartTicket.new(pack.cards[index], false, 1, true)
		tile.set_rest(Vector2(TILE_LEFT + index * TILE_STEP, TILE_TOP))
		add_child(tile)
		tiles.append(tile)
	var hint: Label = UiKit.body_label(pack.hint_text, HINT_SIZE, Palette.INK)
	hint.add_theme_font_override("font", CartReveal.font(700))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = HINT_RECT.position
	hint.size = HINT_RECT.size
	add_child(hint)
	_ribbon = Control.new()
	_ribbon.name = "Ribbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.position = RIBBON_RECT.position
	_ribbon.size = RIBBON_RECT.size
	_ribbon.visible = first_pick
	_ribbon.draw.connect(_draw_ribbon)
	add_child(_ribbon)
	var ribbon_text: Label = UiKit.body_label(RIBBON_TEXT, RIBBON_SIZE, Palette.INK)
	ribbon_text.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	ribbon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon_text.size = RIBBON_RECT.size
	_ribbon.add_child(ribbon_text)
	if key > 0:
		var key_chip: RevealChip = RevealChip.new(
			Palette.PAPER, KEY_RECT.size, null, str(key), KEY_SIZE, Palette.INK
		)
		key_chip.name = "Key"
		key_chip.position = KEY_RECT.position
		add_child(key_chip)
	picked_tab = RevealChip.new(
		Palette.GOOD, PICKED_RECT.size, null, PICKED_TEXT, RIBBON_SIZE, Palette.INK
	)
	picked_tab.name = "Picked"
	picked_tab.position = PICKED_RECT.position
	picked_tab.visible = false
	add_child(picked_tab)


## The face's colour: its family's ticket colour, or the coupon's tomato for a family with none
## (the Coupon family keeps the plain coupon look).
func face_color() -> Color:
	return _style.face if _has_colours() else Palette.TOMATO


func _has_colours() -> bool:
	return _style != null and _style.has_ticket_colours()


## A pack's colours (its face, then its light) and glyph, as its face shows them: its family's
## ticket colours, or the coupon's tomato for a family with none (the Coupon family).
static func pack_look(starter_pack: StarterPackDefinition) -> Array:
	var style: FamilyStyle = FamilyPalette.shared().style(starter_pack.family)
	var glyph: Texture2D = style.glyph if style != null else null
	if style == null or not style.has_ticket_colours():
		return [Palette.TOMATO, Palette.TOMATO_LIGHT, glyph]
	return [style.face, style.light, glyph]


## Whether the ribbon shows (the good first pick).
func has_ribbon() -> bool:
	return _ribbon.visible


func set_raised(on: bool) -> void:
	if on != raised:
		raised = on
		picked_tab.visible = on
		queue_redraw()


func set_hovered(on: bool) -> void:
	if on != hovered:
		hovered = on
		queue_redraw()


## The face's name (for tests).
func name_text() -> String:
	return _name.text


## Paper text on a dark face (the family's own choice, or a face too dark for ink).
func _paper_text() -> bool:
	if not _has_colours():
		return true
	return _style.paper_text or _style.face.get_luminance() < 0.4


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(Rect2(rect.position + Vector2(0, SHADOW_DROP), rect.size), Color(0, 0, 0, 0.3))
	var frame_colour: Color = face_color()
	var frame: float = FRAME
	if raised:
		frame_colour = Palette.GOLD
		frame = RAISED_FRAME
	elif hovered:
		frame_colour = _style.light if _has_colours() else Palette.TOMATO_LIGHT
	draw_rect(rect, Palette.INK)
	draw_rect(rect.grow(-2.0), frame_colour)
	var body: Rect2 = rect.grow(-2.0 - frame)
	draw_rect(Rect2(body.position, Vector2(body.size.x, HEADER_HEIGHT - 2.0 - frame)), face_color())
	var paper: Rect2 = Rect2(
		Vector2(body.position.x, HEADER_HEIGHT), Vector2(body.size.x, body.end.y - HEADER_HEIGHT)
	)
	draw_rect(paper, Palette.PAPER)


func _draw_ribbon() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _ribbon.size)
	_ribbon.draw_rect(rect, Palette.INK)
	_ribbon.draw_rect(rect.grow(-2.0), Palette.MUSTARD)
