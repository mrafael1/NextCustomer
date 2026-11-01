class_name PriceSticker
extends Control
## An item's price-gun ticket (#75; #105's full-colour ticket, mock-up readability v3): one size
## everywhere, always upright. On the belt it is the item's shelf ticket on the price rail (mock-up
## B2, #80 step 6). Its face is in the colour of the family the card works with (TicketFace, from
## FamilyPalette.ticket_families: the data's colours; two families make a split ticket); a coupon
## that works with no family keeps the plain coupon slip (ticket_coupon) and a family coupon gets
## its family's face with a perforated top. Its text is ink or paper, whichever reads on the face
## (FamilyPalette.text_color).
##
## Resting the pointer on the ticket (off its glyphs) says what its colour means, below it
## (ColourSpot, the child COLOUR_SPOT_NAME; FamilyPalette.colour_tip: "Breakfast colour · works
## with Breakfast").
##
## Top left, a product's family glyphs (FamilyPalette.shelf_families of its tags), alone, each with
## a paper rim, their tooltips opening below the ticket (GlyphTips); a coupon shows "COUPON"
## there. Top right, a product's price: at rest its plain tag ("€N", PayTag's LOWERED look) on the
## corner. Under them its short text (CardDefinition.sticker_summary, formatted in core from the
## card's own data) in at most 2 lines, its family names drawn as glyphs (GlyphLabel). Every
## number comes from the card's data.
##
## Planning effects (#71, #105): set_pay hides the plain tag while PlanningLayer pins the real pay
## (a die-cut PayTag) on the corner and, when the pay differs from the base, shows the struck old
## price under it (15 px, right-aligned; ink with a paper rim and a tomato strike, or the ticket's
## paper text and a paper strike on a dark ticket), keeping the text's first line clear of it (a
## text that needs its whole first line, the soups', puts the old price beside the tag instead);
## set_got rings a hovered giver's target in gold inside its outline. Neither changes a number.
## The staple padlock is never on a ticket (only on the cart reveal).
##
## An item tier (#77) is named by tier_text ("BIG", "GOLDEN") for the machine's prizes and the deck
## view; the ticket itself carries no tier tag since 2026-11-01 (the user's call).


## The struck old price (#105): its text, right-aligned in its rect, and the strike low across it.
class StruckPrice:
	extends Control

	var text: String = ""
	var dark: bool = false

	func _init(shown: String, on_dark: bool) -> void:
		name = STRUCK_NAME
		text = shown
		dark = on_dark
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width: float = ceilf(text_width(text))
		size = Vector2(width, STRUCK_HEIGHT)
		position = Vector2(STRUCK_RIGHT - width, STRUCK_TOP)

	## Its font: the number font's face at its weight, from the raster import (crisp at 15 px, where
	## the MSDF import the count-up's slams need draws soft).
	static func price_font() -> Font:
		return ArtStyle.bold_font(ArtStyle.NUMBER_WEIGHT)

	static func text_width(shown: String) -> float:
		var font: Font = StruckPrice.price_font()
		return (
			font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.STRUCK_PRICE_SIZE).x
		)

	## The strike's rect, in this control's coordinates.
	func strike_rect() -> Rect2:
		return Rect2(
			-STRIKE_OUT,
			roundf(ArtStyle.STRUCK_PRICE_SIZE * STRIKE_DROP),
			size.x + 2.0 * STRIKE_OUT,
			STRIKE_WIDTH
		)

	func strike_color() -> Color:
		return Palette.PAPER if dark else Palette.TOMATO

	func text_color() -> Color:
		return Palette.PAPER if dark else Palette.INK

	func _draw() -> void:
		var font: Font = StruckPrice.price_font()
		var font_size: int = ArtStyle.STRUCK_PRICE_SIZE
		var ascent: float = font.get_ascent(font_size)
		var height: float = ascent + font.get_descent(font_size)
		var at: Vector2 = Vector2(0.0, roundf((size.y - height) / 2.0 + ascent))
		if not dark:
			draw_string_outline(
				font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Palette.PAPER
			)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color())
		draw_rect(strike_rect(), strike_color())


## The ticket's colour as a tooltip target (#105): the whole ticket, under its glyphs (a glyph on
## it shows its own tip); its tip says what the colour means, below the ticket.
class ColourSpot:
	extends TipTarget

	func _init(text: String, ticket: Control) -> void:
		super()
		name = COLOUR_SPOT_NAME
		tip_text = text
		tip_below = true
		tip_anchor = ticket
		size = SIZE


## The gold ring of a hovered giver's target (#71), inside the ticket's outline.
class GotRing:
	extends Control

	func _init() -> void:
		name = GOT_RING_NAME
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = SIZE
		visible = false

	func _draw() -> void:
		var inner: Rect2 = Rect2(Vector2.ZERO, size).grow(-OUTLINE)
		var width: float = GOT_RING_WIDTH
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, width)), Palette.GOLD)
		draw_rect(Rect2(inner.position.x, inner.end.y - width, inner.size.x, width), Palette.GOLD)
		draw_rect(Rect2(inner.position.x, inner.position.y, width, inner.size.y), Palette.GOLD)
		draw_rect(Rect2(inner.end.x - width, inner.position.y, width, inner.size.y), Palette.GOLD)


const SIZE := Vector2(108, 64)
## The ticket's ink outline (one art pixel).
const OUTLINE := 2.0
## The glyph row: the first glyph's top-left, then one every GLYPH_STEP px (GLYPH_SQUEEZED_STEP
## when a wide pay burst needs the room: their rims touch).
const GLYPH_ROW := Vector2(4, 5)
const GLYPH_STEP := 20.0
const GLYPH_SQUEEZED_STEP := 18.0
## The plain tag at rest: on the ticket's top-right corner.
const PLAIN_TAG_AT := Vector2(60, -4)
## The struck old price: its right edge, its top and its height; the strike STRIKE_DROP of the
## size down, STRIKE_WIDTH thick, STRIKE_OUT past each end. Beside the tag (a text that needs its
## whole first line): its top STRUCK_BESIDE_TOP, its right end STRUCK_BESIDE_GAP left of the tag's
## die-cut (or plain tag), and as far clear of the glyph row's rims.
const STRUCK_RIGHT := 101.0
const STRUCK_TOP := 26.0
const STRUCK_BESIDE_TOP := 6.0
const STRUCK_BESIDE_GAP := 2.0
const STRUCK_HEIGHT := 17.0
const STRIKE_DROP := 0.62
const STRIKE_WIDTH := 2.0
const STRIKE_OUT := 2.0
## The short text's box (its top 1 px lower on a coupon, under COUPON); the first line keeps
## SUMMARY_GAP clear of a struck price.
const SUMMARY_RECT := Rect2(6, 27, 98, 35)
const COUPON_SUMMARY_TOP := 28.0
const SUMMARY_GAP := 14.0
const MAX_SUMMARY_LINES := ArtStyle.TICKET_TEXT_LINES
## "COUPON" on a coupon's ticket, in the body font at COUPON_TITLE_WEIGHT, letter-spaced. Beside a
## pinned tag (a fizzled €0) it takes the first of COUPON_TITLE_FITS (size, letter spacing) that
## ends COUPON_TAG_GAP clear of the tag's die-cut.
const COUPON_TITLE := "COUPON"
const COUPON_TITLE_AT := Vector2(8, 8)
const COUPON_TITLE_HEIGHT := 18.0
const COUPON_TITLE_SIZE := 12
const COUPON_TITLE_WEIGHT := 800
const COUPON_TITLE_SPACING := 1
const COUPON_TITLE_FITS: Array[Vector2i] = [
	Vector2i(12, 1), Vector2i(12, 0), Vector2i(11, 0), Vector2i(10, 0), Vector2i(9, 0)
]
const COUPON_TAG_GAP := 2.0
const GOT_RING_WIDTH := 2.0
## Node names (for tests).
const FACE_NAME := "Face"
const PLAIN_TAG_NAME := "PlainTag"
const STRUCK_NAME := "Struck"
const SUMMARY_NAME := "Summary"
const GOT_RING_NAME := "GotRing"
const COUPON_TITLE_NAME := "CouponTitle"
const COLOUR_SPOT_NAME := "ColourSpot"
const TIER_TEXTS: Array[String] = ["", "BIG", "GOLDEN"]

## The plain coupon slip, and a product's face when it has no family colours.
const COUPON_FRAME := preload("res://art/frames/ticket_coupon.png")
const PLAIN_FRAME := preload("res://art/frames/ticket_product.png")
const PLAIN_FRAME_MARGIN := 3
const PLAIN_FRAME_TOP_MARGIN := 4

## COUPON's fonts, by letter spacing.
static var _coupon_fonts: Dictionary[int, FontVariation] = {}

var _families: PackedStringArray = PackedStringArray()
var _text_color: Color = Palette.INK
var _face: Control
var _glyphs: Array[FamilyGlyph] = []
var _plain_tag: PayTag
var _struck_price: StruckPrice
var _summary: GlyphLabel
var _got_ring: GotRing
var _struck: bool = false
var _got: bool = false
var _squeezed: bool = false


## The ticket of `definition`, in the game's family colours (`palette`: the game's when null).
func _init(definition: CardDefinition, palette: FamilyPalette = null) -> void:
	var families: FamilyPalette = palette if palette != null else FamilyPalette.shared()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	_families = families.ticket_families(definition)
	var styles: Array[FamilyStyle] = []
	for style: FamilyStyle in families.styles(_families):
		if style.has_ticket_colours():
			styles.append(style)
	_text_color = families.text_color(_families) if not styles.is_empty() else Palette.INK
	_add_face(definition, styles)
	add_child(ColourSpot.new(families.colour_tip(definition), self))
	var coupon: bool = definition.is_coupon()
	if coupon:
		_add_coupon_title(styles.is_empty())
	else:
		for family: String in families.shelf_families(definition.tags):
			var style: FamilyStyle = families.style(family)
			if style == null or style.glyph == null:
				continue
			var glyph: FamilyGlyph = FamilyGlyph.new(style, true)
			glyph.tip_below = true
			glyph.tip_anchor = self
			add_child(glyph)
			_glyphs.append(glyph)
		_lay_out_glyphs(false)
		_plain_tag = PayTag.new(PlanningModel.Pay.LOWERED, price_text(definition.base))
		_plain_tag.name = PLAIN_TAG_NAME
		_plain_tag.position = PLAIN_TAG_AT
		add_child(_plain_tag)
		_struck_price = StruckPrice.new(price_text(definition.base), _text_color == Palette.PAPER)
		_struck_price.visible = false
		add_child(_struck_price)
	var font: Font = ArtStyle.bold_font(ArtStyle.TICKET_TEXT_WEIGHT)
	_summary = GlyphLabel.new(
		definition.sticker_summary(),
		font,
		ArtStyle.TICKET_TEXT_SIZE,
		_text_color,
		ArtStyle.TICKET_TEXT_LINE,
		SUMMARY_RECT.size.x,
		MAX_SUMMARY_LINES,
		true,
		families
	)
	_summary.name = SUMMARY_NAME
	_summary.position = Vector2(
		SUMMARY_RECT.position.x, COUPON_SUMMARY_TOP if coupon else SUMMARY_RECT.position.y
	)
	_summary.set_tip(true, self)
	add_child(_summary)
	_got_ring = GotRing.new()
	add_child(_got_ring)


## "€N": a price as tickets print it.
static func price_text(amount: int) -> String:
	return "€%d" % amount


## The planning pay on the ticket (#71, #105): with a pay tag pinned at `tag_rect` (this sticker's
## coordinates; empty: none) the plain tag hides; `struck` strikes a product's old price under it (a
## coupon has no price to strike; under a pinned tag PlanningLayer draws it on the tag,
## PayTag.show_struck, at struck_rect) and keeps the text's first line clear of it. A glyph whose
## rim would touch the tag's die-cut moves up to the one before it (the rims touch), and hides when
## it still would; a coupon's COUPON shrinks to stay clear of its tag (COUPON_TITLE_FITS). A text
## that would not fit beside the struck price keeps its first line and the old price moves beside
## the tag, at the glyph row's height (struck_rect's top STRUCK_BESIDE_TOP); with no room there
## either it is not struck (is_struck). False and an empty rect put the plain ticket back.
func set_pay(struck: bool, tag_rect: Rect2) -> void:
	var tagged: bool = tag_rect.has_area()
	var product: bool = _plain_tag != null
	if product:
		_plain_tag.visible = not tagged
	var cut: Rect2 = tag_rect.grow(ArtStyle.RIM_TEXELS * ArtStyle.ART_SCALE)
	_fit_coupon_title(cut if tagged else Rect2())
	_lay_out_glyphs(false)
	if tagged and _touches(cut):
		_lay_out_glyphs(true)
	for glyph: FamilyGlyph in _glyphs:
		glyph.visible = not tagged or not glyph.rim_rect().intersects(cut)
	_struck = struck and product
	if product:
		_struck_price.position = Vector2(STRUCK_RIGHT - _struck_price.size.x, STRUCK_TOP)
	_summary.set_first_inset(_struck_price.size.x + SUMMARY_GAP if _struck else 0.0)
	if _struck and not _summary.fits():
		# A text that only fits on the whole first line (the soups') keeps it: the old price
		# moves up beside the tag.
		_summary.set_first_inset(0.0)
		_struck = _place_struck_beside(cut if tagged else plain_tag_rect())
	if product:
		# Under a pinned tag the tag draws it (PayTag.show_struck), over the tag's shadow.
		_struck_price.visible = _struck and not tagged


## Whether the old price is struck (#71).
func is_struck() -> bool:
	return _struck


## Rings a product's ticket in gold as a hovered giver's target (#71), or takes the ring off. A
## coupon's ticket is never ringed.
func set_got(got: bool) -> void:
	_got = got and _plain_tag != null
	_got_ring.visible = _got
	_got_ring.queue_redraw()


func is_got() -> bool:
	return _got


## The ring of a hovered giver's target.
func got_ring() -> Control:
	return _got_ring


## The families its face is coloured by (none: the plain coupon slip).
func face_families() -> PackedStringArray:
	return _families


## Its text's colour: ink, or paper on a dark face.
func text_color() -> Color:
	return _text_color


## The face (a TextureRect of TicketFace's art, the coupon slip, or a plain ticket's Panel).
func face() -> Control:
	return _face


## The family glyphs in its glyph row (none on a coupon), left to right.
func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


## Whether the glyph row is squeezed for a wide pay burst.
func is_squeezed() -> bool:
	return _squeezed


## Where the glyph row ends with its rims at its full step (this sticker's coordinates), or
## GLYPH_ROW.x with none.
func glyph_row_end() -> float:
	if _glyphs.is_empty():
		return GLYPH_ROW.x
	var step: float = GLYPH_STEP
	return (
		GLYPH_ROW.x + step * (_glyphs.size() - 1) + ArtStyle.FAMILY_GLYPH_SIZE + ArtStyle.ART_SCALE
	)


## The plain tag at rest, or null for a coupon.
func plain_tag() -> PayTag:
	return _plain_tag


## The plain tag's rect (this sticker's coordinates), or an empty rect for a coupon.
func plain_tag_rect() -> Rect2:
	return Rect2(_plain_tag.position, _plain_tag.size) if _plain_tag != null else Rect2()


## The struck old price, or null for a coupon.
func struck_price() -> StruckPrice:
	return _struck_price


## The struck price's text rect and its strike's rect (this sticker's coordinates; empty for a
## coupon).
func struck_rect() -> Rect2:
	if _struck_price == null:
		return Rect2()
	return Rect2(_struck_price.position, _struck_price.size)


func strike_rect() -> Rect2:
	if _struck_price == null:
		return Rect2()
	var line: Rect2 = _struck_price.strike_rect()
	return Rect2(_struck_price.position + line.position, line.size)


## The short text.
func summary() -> GlyphLabel:
	return _summary


## Where the short text's lines are drawn (this sticker's coordinates; empty with no text).
func summary_text_rect() -> Rect2:
	var rect: Rect2 = _summary.text_rect()
	if not rect.has_area():
		return Rect2()
	return Rect2(_summary.position + rect.position, rect.size)


## The COUPON label, or null for a product.
func coupon_title() -> Label:
	return get_node_or_null(COUPON_TITLE_NAME) as Label


## A card's tier tag ("BIG", "GOLDEN"), or "" for a plain card.
static func tier_text(definition: CardDefinition) -> String:
	return TIER_TEXTS[definition.tier] if definition != null else ""


## COUPON's font: the body font at COUPON_TITLE_WEIGHT, `spacing` px letter-spaced.
static func coupon_font(spacing: int = COUPON_TITLE_SPACING) -> Font:
	if not _coupon_fonts.has(spacing):
		var font: FontVariation = FontVariation.new()
		font.base_font = ArtStyle.BODY_FONT
		var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		font.variation_opentype = {weight: COUPON_TITLE_WEIGHT}
		font.spacing_glyph = spacing
		_coupon_fonts[spacing] = font
	return _coupon_fonts[spacing]


## COUPON's width at `fit` (COUPON_TITLE_FITS' size and letter spacing).
static func coupon_title_width(fit: Vector2i) -> float:
	var font: Font = coupon_font(fit.y)
	return font.get_string_size(COUPON_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fit.x).x


func _add_face(definition: CardDefinition, styles: Array[FamilyStyle]) -> void:
	if styles.is_empty() and definition.is_product():
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxTexture = ArtStyle.frame_style(PLAIN_FRAME, PLAIN_FRAME_MARGIN)
		style.texture_margin_top = PLAIN_FRAME_TOP_MARGIN * ArtStyle.ART_SCALE
		panel.add_theme_stylebox_override("panel", style)
		ArtStyle.use_pixel_material(panel)
		_face = panel
	elif styles.is_empty():
		_face = UiKit.sprite(COUPON_FRAME)
	else:
		_face = UiKit.sprite(TicketFace.texture(styles, definition.is_coupon()))
	_face.name = FACE_NAME
	_face.size = SIZE
	add_child(_face)


func _add_coupon_title(plain: bool) -> void:
	var title: Label = UiKit.body_label(COUPON_TITLE, COUPON_TITLE_SIZE, Palette.INK)
	title.name = COUPON_TITLE_NAME
	title.add_theme_font_override("font", coupon_font())
	title.add_theme_color_override("font_color", Palette.TEAL_DARK if plain else _text_color)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = COUPON_TITLE_AT
	title.size = Vector2(SIZE.x - 2.0 * COUPON_TITLE_AT.x, COUPON_TITLE_HEIGHT)
	add_child(title)


## Fits COUPON clear of a pinned tag's die-cut `cut` (empty: none, the full look): the first of
## COUPON_TITLE_FITS that ends COUPON_TAG_GAP short of it; with none, the smallest.
func _fit_coupon_title(cut: Rect2) -> void:
	var title: Label = coupon_title()
	if title == null:
		return
	var fit: Vector2i = COUPON_TITLE_FITS[0]
	if cut.has_area():
		var room: float = cut.position.x - COUPON_TAG_GAP - title.position.x
		fit = COUPON_TITLE_FITS[-1]
		for candidate: Vector2i in COUPON_TITLE_FITS:
			if coupon_title_width(candidate) <= room:
				fit = candidate
				break
	title.add_theme_font_override("font", coupon_font(fit.y))
	title.add_theme_font_size_override("font_size", fit.x)


## Puts the struck old price beside `edge` (the tag's die-cut, or the plain tag), at the glyph row's
## height, clear of the shown glyphs; false when there is no room.
func _place_struck_beside(edge: Rect2) -> bool:
	if not edge.has_area():
		return false
	var row_end: float = GLYPH_ROW.x
	for glyph: FamilyGlyph in _glyphs:
		if glyph.visible:
			row_end = maxf(row_end, glyph.rim_rect().end.x)
	var left: float = floorf(edge.position.x - STRUCK_BESIDE_GAP - _struck_price.size.x)
	if left < row_end + STRUCK_BESIDE_GAP:
		return false
	_struck_price.position = Vector2(left, STRUCK_BESIDE_TOP)
	return true


func _lay_out_glyphs(squeezed: bool) -> void:
	_squeezed = squeezed
	var step: float = GLYPH_SQUEEZED_STEP if squeezed else GLYPH_STEP
	for index: int in _glyphs.size():
		_glyphs[index].position = GLYPH_ROW + Vector2(step * index, 0)


func _touches(cut: Rect2) -> bool:
	for glyph: FamilyGlyph in _glyphs:
		if glyph.rim_rect().intersects(cut):
			return true
	return false
