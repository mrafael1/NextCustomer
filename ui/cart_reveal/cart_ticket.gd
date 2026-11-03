class_name CartTicket
extends Control
## One card on the start screen's cart sheet (#107's clock-in board, mock-up start_screen.html
## layout A, 2026-11-03): an 80x118 paper ticket with the item's art (ItemView.item_art at 2/3, so
## one art pixel is two screen pixels at 1920x1080), its name in up to two lines, and a band in its
## ticket's colour (FamilyPalette: the family it works with; a plain coupon's tomato) with its
## family glyphs and its price "N€" (a coupon's band has no price). A staple wears the mustard
## padlock at its top left, a coupon its COUPON tab and the scissors line; the cart's copies of
## the card (`count`, counted over the whole cart) show as a gold "×N" at its top right when more
## than one. An empty slot (null card) is a dashed outline with a "?" (the pack not picked yet).
## lit/dimmed answer a hovered shelf (StockShelves); show_pop() pops it in. A `compact` ticket
## (70x100, a pack's card on its PackFace) has no band: its art and its name only. Display only:
## CartReveal routes the pointer, and its scan popup opens over the board on hover.

const SIZE := Vector2(80, 118)
## A compact ticket: its size, its art's place and its name's rect.
const COMPACT_SIZE := Vector2(70, 100)
const COMPACT_ART := Vector2(3, 2)
const COMPACT_NAME := Rect2(2, 66, 66, 30)
const COMPACT_FOOT := 4.0
const COUPON_FOOT := Color(Palette.TOMATO_LIGHT, 0.5)
## The art (ItemView.SPRITE_SIZE at ART_SCALE_FACTOR), its name and its band.
const ART_SCALE_FACTOR := 2.0 / 3.0
const ART_POSITION := Vector2(8, 4)
const NAME_RECT := Rect2(2, 68, 76, 26)
const NAME_SIZE := 10
const NAME_WEIGHT := 700
const NAME_LINE_SPACING := -3
const BAND_TOP := 96.0
const BAND_LINE := 2.0
const GLYPH_SIZE := 12.0
const GLYPH_LEFT := 4.0
const GLYPH_STEP := 15.0
const PRICE_SIZE := 13
const PRICE_RIGHT := 5.0
## The badges, in ticket coordinates: the padlock, the "×N" and the COUPON tab.
const LOCK_RECT := Rect2(-6, -8, 22, 22)
const COUNT_AT := Vector2(50, -9)
const COUNT_SIZE := Vector2(28, 20)
const COUNT_TEXT_SIZE := 13
## The tab's text is 10 px (15 px at 1920x1080, the board's floor); it ends before the ×N.
const TAB_RECT := Rect2(0, -10, 48, 16)
const TAB_TEXT_SIZE := 10
const CUT_INSET := Vector4(4, 4, 4, 26)
const DASH := 5.0
const EMPTY_TEXT := "?"
const EMPTY_SIZE := 28
## A lit ticket rises this many px and wears a gold ring; a dimmed one fades to DIM_ALPHA.
const LIT_RISE := 4.0
const LIT_RING := 3.0
const DIM_ALPHA := 0.35
const SHADOW_DROP := 4.0

var card: CardDefinition
var staple: bool = false
var compact: bool = false
var count: int = 1
var lit: bool = false
var dimmed: bool = false
var lock_badge: RevealChip
var count_badge: RevealChip
var tab: RevealChip
var _art: TextureRect
var _name: Label
var _price: Label
var _band: Color = Palette.CREAM_SHADE
var _band_text: Color = Palette.INK
var _glyphs: Array[TextureRect] = []
var _rest_y: float = 0.0
var _pop: float = 1.0


## A ticket for `definition` (null: an empty slot), a `is_staple` card, `copies` in the cart;
## `is_compact`: a pack's card (no band).
func _init(
	definition: CardDefinition, is_staple: bool = false, copies: int = 1, is_compact: bool = false
) -> void:
	card = definition
	staple = is_staple
	count = copies
	compact = is_compact
	name = "CartTicket_%s" % (String(definition.id) if definition != null else "empty")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = COMPACT_SIZE if compact else SIZE
	pivot_offset = Vector2(size.x / 2.0, size.y * 0.7)
	if card == null:
		var mark: Label = UiKit.number_label(EMPTY_TEXT, EMPTY_SIZE, false)
		mark.add_theme_color_override("font_color", Palette.CREAM_DARKEST)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.size = size
		add_child(mark)
		return
	_build_face()


func _build_face() -> void:
	_art = ItemView.item_art(card)
	_art.position = COMPACT_ART if compact else ART_POSITION
	_art.scale = Vector2.ONE * ART_SCALE_FACTOR
	add_child(_art)
	# A coupon whose name is printed on its slip doesn't repeat it under it (as RevealTile).
	if not card.is_coupon() or ArtStyle.coupon_icon(card) != null:
		_add_name()
	if compact:
		if card.is_coupon():
			_add_tab()
		return
	_build_band()


func _add_name() -> void:
	_name = UiKit.body_label(card.display_name, NAME_SIZE, Palette.INK)
	_name.add_theme_font_override("font", ArtStyle.bold_font(NAME_WEIGHT))
	_name.add_theme_constant_override("line_spacing", NAME_LINE_SPACING)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.max_lines_visible = 2
	var rect: Rect2 = COMPACT_NAME if compact else NAME_RECT
	_name.position = rect.position
	_name.size = rect.size
	add_child(_name)


func _build_band() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var families: PackedStringArray = palette.ticket_families(card)
	var looks: Array[FamilyStyle] = palette.styles(families)
	if not looks.is_empty() and looks[0].has_ticket_colours():
		_band = looks[0].face
		_band_text = palette.text_color(families)
	elif card.is_coupon():
		_band = Palette.TOMATO
		_band_text = Palette.PAPER
	var shown: PackedStringArray = palette.shelf_families(card.tags)
	if card.is_coupon():
		shown = PackedStringArray(["Coupon"])
	for family: String in shown.slice(0, 2):
		var style: FamilyStyle = palette.style(family)
		if style == null or style.glyph == null:
			continue
		var glyph: TextureRect = UiKit.sprite(style.glyph)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_SCALE
		glyph.size = Vector2.ONE * GLYPH_SIZE
		glyph.position = Vector2(
			GLYPH_LEFT + _glyphs.size() * GLYPH_STEP,
			BAND_TOP + BAND_LINE + (SIZE.y - BAND_TOP - BAND_LINE - GLYPH_SIZE) / 2.0
		)
		add_child(glyph)
		_glyphs.append(glyph)
	if card.is_product():
		_price = UiKit.number_label(PriceSticker.price_text(card.base), PRICE_SIZE, false)
		_price.add_theme_color_override("font_color", _band_text)
		_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_price.position = Vector2(0, BAND_TOP + BAND_LINE)
		_price.size = Vector2(SIZE.x - PRICE_RIGHT, SIZE.y - BAND_TOP - BAND_LINE)
		add_child(_price)
	if card.is_coupon():
		_add_tab()
	if staple:
		lock_badge = RevealChip.new(Palette.MUSTARD, LOCK_RECT.size, RevealTile.LOCK_ICON)
		lock_badge.position = LOCK_RECT.position
		add_child(lock_badge)
	count_badge = RevealChip.new(
		Palette.GOLD, COUNT_SIZE, null, "×%d" % count, COUNT_TEXT_SIZE, Palette.INK
	)
	count_badge.position = COUNT_AT
	count_badge.visible = count > 1
	add_child(count_badge)


func _add_tab() -> void:
	tab = RevealChip.new(
		Palette.TOMATO, TAB_RECT.size, null, "COUPON", TAB_TEXT_SIZE, Palette.PAPER
	)
	tab.position = TAB_RECT.position
	add_child(tab)


## Whether this is an empty slot (no card yet).
func is_empty() -> bool:
	return card == null


## The name label (for tests), or null for an empty slot.
func name_label() -> Label:
	return _name


## The price label (for tests), or null for a coupon or an empty slot.
func price_label() -> Label:
	return _price


## The family glyphs on the band (for tests).
func glyphs() -> Array[TextureRect]:
	return _glyphs


## The ticket's resting place in its parent (it rises from there when lit).
func set_rest(at: Vector2) -> void:
	_rest_y = at.y
	position = at
	_place()


## Lights the ticket (its shelf is hovered: it rises with a gold ring), dims it (another shelf is
## hovered), or neither.
func set_light(on: bool, dim: bool) -> void:
	if on == lit and dim == dimmed:
		return
	lit = on
	dimmed = dim
	modulate.a = DIM_ALPHA if dimmed else 1.0
	_place()
	queue_redraw()


## The pop-in's progress, 0 to 1 (1: at rest; 0: not shown yet), eased with an overshoot.
func show_pop(progress: float) -> void:
	_pop = clampf(progress, 0.0, 1.0)
	visible = _pop > 0.0
	scale = Vector2.ONE * (0.6 + 0.4 * CartReveal.ease_out_back(_pop))


func _place() -> void:
	position.y = _rest_y - (LIT_RISE if lit else 0.0)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if card == null:
		RevealSlot.dashed_rect(self, rect, Palette.CREAM_DARKEST, DASH)
		return
	draw_rect(
		Rect2(rect.position + Vector2(0, SHADOW_DROP), rect.size).grow(2), Color(0, 0, 0, 0.3)
	)
	if lit:
		draw_rect(rect.grow(2 + LIT_RING), Palette.GOLD)
	draw_rect(rect.grow(2), Palette.INK)
	draw_rect(rect, Palette.CREAM if staple else Palette.PAPER)
	var foot: float = COMPACT_FOOT
	if compact:
		var shade: Color = COUPON_FOOT if card.is_coupon() else Palette.TEAL_PALE
		draw_rect(Rect2(0, size.y - foot, size.x, foot), shade)
	else:
		foot = CUT_INSET.w
		draw_rect(Rect2(0, BAND_TOP, size.x, BAND_LINE), Palette.INK)
		draw_rect(Rect2(0, BAND_TOP + BAND_LINE, size.x, size.y - BAND_TOP - BAND_LINE), _band)
	if card.is_coupon():
		var cut: Rect2 = Rect2(
			CUT_INSET.x,
			CUT_INSET.y,
			size.x - CUT_INSET.x - CUT_INSET.z,
			size.y - CUT_INSET.y - foot - (CUT_INSET.y if compact else 0.0)
		)
		RevealSlot.dashed_rect(self, cut, Palette.TOMATO, DASH)
