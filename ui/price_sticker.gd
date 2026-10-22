class_name PriceSticker
extends Control
## An item's price-gun sticker (#75; style frame v2's spec section 4.2): one size everywhere,
## always upright. On the belt it is the item's shelf ticket on the price rail (mock-up B2, #80
## step 6). A product's sticker is the ticket_product 9-slice (paper face, a mustard-light band)
## with its base in the number font, its aisle glyph (products of an aisle only) and its summary
## (CardDefinition.sticker_summary, formatted in core from the card's own data) in at most 2
## lines of bold Atkinson. A coupon's is the full-size ticket_coupon (a band of teal dashes) with
## "COUPON" in Pixelify teal and no glyph. Every number comes from the card's data.
##
## Planning effects (#71, mock-up h1): set_pay strikes a product's base through when the item pays
## something else (the real pay is PlanningLayer's PayTag on the ticket's top band) and moves the
## aisle glyph clear of that tag; set_got gives a hovered giver's target the mustard face
## (ticket_got). Neither changes a number.
##
## An item tier (#77): a BIG or GOLDEN copy's sticker carries its tier tag (tier_text) under its
## left end: a cream "BIG" price-gun label, or a gold "GOLDEN" one. It only reads the card's tier.

const SIZE := Vector2(108, 64)
const BASE_RECT := Rect2(8, 6, 74, 24)
const GLYPH_RECT := Rect2(84, 8, 18, 18)
const SUMMARY_RECT := Rect2(6, 28, 96, 34)
const BASE_SIZE := 22
const COUPON_TITLE_SIZE := 13
const SUMMARY_SIZE := 13
## The summary's weight (a FontVariation of the body font) and line spacing. A deliberate change
## from spec 4.2 (y+30, h 32, spacing -1): Atkinson at 13 px is 18 px tall (13 ascent + 5
## descent), not 16, so two lines at -1 need 35 px and the second would be cut. At y+28 with -2
## they take 34 px and end at y+62, above the sticker's bottom outline.
const SUMMARY_WEIGHT := 700
const SUMMARY_LINE_SPACING := -2
const MAX_SUMMARY_LINES := 2
## ticket_product's 9-slice margins in art pixels: the band's top, then the sides and bottom.
const FRAME_TOP_MARGIN := 4
const FRAME_MARGIN := 3
const COUPON_TITLE := "COUPON"
## A struck base (#71): its size when a pay tag needs the room, the line across its text
## (STRIKE_WIDTH thick, STRIKE_OUT past each end), and the glyph's gap after the base's text and
## round the tag.
const BASE_STRUCK_SIZE := 18
const STRIKE_WIDTH := 2.0
const STRIKE_OUT := 3.0
const GLYPH_GAP := 4.0
const TAG_CLEARANCE := 2.0
const STRIKE_NAME := "Strike"
## The tier tag (#77): under the ticket's left end, bold Atkinson.
const TIER_TAG_NAME := "TierTag"
const TIER_TAG_RECT := Rect2(4, 62, 60, 16)
const TIER_TAG_SIZE := 11
const TIER_TEXTS: Array[String] = ["", "BIG", "GOLDEN"]

const FRAME := preload("res://art/frames/ticket_product.png")
const COUPON_FRAME := preload("res://art/frames/ticket_coupon.png")
const GOT_FRAME := preload("res://art/effects/ticket_got.png")

var _base: Label
var _summary: Label
var _glyph: TextureRect
## A product's face (a coupon's is its slip) and the struck base's line (#71).
var _face: Panel
var _strike: ColorRect
var _struck: bool = false
var _got: bool = false


## The sticker of `definition`, with the glyph of its `aisle` (null for a staple or a coupon).
func _init(definition: CardDefinition, aisle: AisleDefinition) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	if definition.is_coupon():
		var face: TextureRect = UiKit.sprite(COUPON_FRAME)
		face.size = SIZE
		add_child(face)
		_base = UiKit.display_label(COUPON_TITLE, COUPON_TITLE_SIZE, false)
		_base.add_theme_color_override("font_color", Palette.PANEL)
	else:
		_face = Panel.new()
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.add_theme_stylebox_override("panel", frame_style())
		ArtStyle.use_pixel_material(_face)
		_face.size = SIZE
		add_child(_face)
		_base = UiKit.number_label("€%d" % definition.base, BASE_SIZE, false)
	_base.position = BASE_RECT.position
	_base.size = BASE_RECT.size
	_base.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_base)
	_strike = ColorRect.new()
	_strike.name = STRIKE_NAME
	_strike.color = Palette.INK
	_strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike.visible = false
	add_child(_strike)
	if aisle != null:
		_glyph = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
		_glyph.position = GLYPH_RECT.position
		_glyph.size = GLYPH_RECT.size
		add_child(_glyph)
	_summary = UiKit.body_label(definition.sticker_summary(), SUMMARY_SIZE, Palette.INK)
	_summary.add_theme_font_override("font", ArtStyle.bold_font(SUMMARY_WEIGHT))
	_summary.add_theme_constant_override("line_spacing", SUMMARY_LINE_SPACING)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_summary.position = SUMMARY_RECT.position
	_summary.size = SUMMARY_RECT.size
	add_child(_summary)
	if not tier_text(definition).is_empty():
		_add_tier_tag(definition)


## The base value ("€2") or COUPON label.
func base_label() -> Label:
	return _base


## The summary label (at most MAX_SUMMARY_LINES lines, measured with the real font).
func summary_label() -> Label:
	return _summary


## The aisle glyph, or null for a staple or a coupon.
func glyph() -> TextureRect:
	return _glyph


## The planning pay on the ticket (#71): `struck` strikes a product's base through (ink light,
## an ink line across its text; a coupon's COUPON is never struck), and the base shrinks to
## BASE_STRUCK_SIZE when the pay tag at `tag_rect` (this sticker's coordinates; empty: no tag)
## starts before the base's text at full size ends. With a tag, the aisle glyph moves to just
## after the base's text and hides when it would touch the tag. Neither false nor an empty rect
## puts the plain ticket back.
func set_pay(struck: bool, tag_rect: Rect2) -> void:
	var tagged: bool = tag_rect.has_area()
	var small: bool = tagged and tag_rect.position.x < base_text_end(BASE_SIZE) + GLYPH_GAP
	var product: bool = _face != null
	if product:
		_base.add_theme_font_size_override("font_size", BASE_STRUCK_SIZE if small else BASE_SIZE)
	_struck = struck and product
	if product:
		_base.add_theme_color_override("font_color", Palette.INK_LIGHT if _struck else Palette.INK)
	var text: Rect2 = base_text_rect()
	_strike.visible = _struck
	if _struck:
		var y: float = snappedf(text.get_center().y - STRIKE_WIDTH / 2.0, 1.0)
		_strike.position = Vector2(text.position.x - STRIKE_OUT, y)
		_strike.size = Vector2(text.size.x + 2.0 * STRIKE_OUT, STRIKE_WIDTH)
	if _glyph == null:
		return
	if not tagged and not _struck:
		_glyph.position = GLYPH_RECT.position
		_glyph.visible = true
		return
	_glyph.position = Vector2(snappedf(text.end.x + GLYPH_GAP, 1.0), GLYPH_RECT.position.y)
	var glyph_rect: Rect2 = Rect2(_glyph.position, GLYPH_RECT.size)
	var face: Rect2 = Rect2(Vector2.ZERO, SIZE)
	_glyph.visible = (
		face.encloses(glyph_rect)
		and not (tagged and glyph_rect.intersects(tag_rect.grow(TAG_CLEARANCE)))
	)


## Whether the base is struck through (#71).
func is_struck() -> bool:
	return _struck


## Gives a product's ticket the mustard face of a hovered giver's target (#71), or its own back.
## A coupon's slip keeps its face.
func set_got(got: bool) -> void:
	_got = got and _face != null
	if _face != null:
		_face.add_theme_stylebox_override("panel", got_style() if _got else frame_style())


func is_got() -> bool:
	return _got


## Where the base's (or COUPON's) text ends, in this sticker's coordinates, at `font_size` (a
## coupon's at its own size).
func base_text_end(font_size: int) -> float:
	var shown: int = font_size if _face != null else COUPON_TITLE_SIZE
	return BASE_RECT.position.x + _text_width(_base, shown)


## Where the base's (or COUPON's) text is drawn now, in this sticker's coordinates.
func base_text_rect() -> Rect2:
	var font_size: int = _base.get_theme_font_size("font_size")
	var font: Font = _base.get_theme_font("font")
	var height: float = font.get_height(font_size)
	var top: float = BASE_RECT.position.y + (BASE_RECT.size.y - height) / 2.0
	return Rect2(BASE_RECT.position.x, top, _text_width(_base, font_size), height)


## Where the summary's lines are drawn, in this sticker's coordinates (empty with no summary).
func summary_text_rect() -> Rect2:
	if _summary.text.is_empty():
		return Rect2()
	var height: float = minf(_summary.get_minimum_size().y, SUMMARY_RECT.size.y)
	return Rect2(SUMMARY_RECT.position, Vector2(SUMMARY_RECT.size.x, height))


## A card's tier tag ("BIG", "GOLDEN"), or "" for a plain card.
static func tier_text(definition: CardDefinition) -> String:
	return TIER_TEXTS[definition.tier] if definition != null else ""


## The tier tag, or null for a plain card.
func tier_tag() -> Label:
	return get_node_or_null(TIER_TAG_NAME) as Label


func _add_tier_tag(definition: CardDefinition) -> void:
	var golden: bool = definition.tier == CardDefinition.Tier.GOLDEN
	var tag: Label = UiKit.body_label(tier_text(definition), TIER_TAG_SIZE, Palette.INK)
	tag.name = TIER_TAG_NAME
	tag.add_theme_font_override("font", ArtStyle.bold_font(SUMMARY_WEIGHT))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.GOLD if golden else Palette.CREAM
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	tag.add_theme_stylebox_override("normal", style)
	tag.position = TIER_TAG_RECT.position
	tag.size = TIER_TAG_RECT.size
	add_child(tag)


## The product sticker's 9-slice: a tall top margin for the band, its plain edges and middle
## stretched (a tiled plain middle shows seam dots at 1080p).
static func frame_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = ArtStyle.frame_style(FRAME, FRAME_MARGIN)
	style.texture_margin_top = FRAME_TOP_MARGIN * ArtStyle.ART_SCALE
	return style


## A hovered giver's target's face (#71): ticket_got with the product sticker's margins.
static func got_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = ArtStyle.frame_style(GOT_FRAME, FRAME_MARGIN)
	style.texture_margin_top = FRAME_TOP_MARGIN * ArtStyle.ART_SCALE
	return style


static func _text_width(label: Label, font_size: int) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
