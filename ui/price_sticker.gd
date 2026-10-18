class_name PriceSticker
extends Control
## An item's price-gun sticker (#75; style frame v2's spec section 4.2): one size everywhere,
## always upright. On the belt it is the item's shelf ticket on the price rail (mock-up B2, #80
## step 6). A product's sticker is the ticket_product 9-slice (paper face, a mustard-light band)
## with its base in the number font, its aisle glyph (products of an aisle only) and its summary
## (CardDefinition.sticker_summary, formatted in core from the card's own data) in at most 2
## lines of bold Atkinson. A coupon's is the full-size ticket_coupon (a band of teal dashes) with
## "COUPON" in Pixelify teal and no glyph. Every number comes from the card's data.

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

const FRAME := preload("res://art/frames/ticket_product.png")
const COUPON_FRAME := preload("res://art/frames/ticket_coupon.png")

var _base: Label
var _summary: Label
var _glyph: TextureRect


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
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", frame_style())
		ArtStyle.use_pixel_material(panel)
		panel.size = SIZE
		add_child(panel)
		_base = UiKit.number_label("€%d" % definition.base, BASE_SIZE, false)
	_base.position = BASE_RECT.position
	_base.size = BASE_RECT.size
	_base.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_base)
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


## The base value ("€2") or COUPON label.
func base_label() -> Label:
	return _base


## The summary label (at most MAX_SUMMARY_LINES lines, measured with the real font).
func summary_label() -> Label:
	return _summary


## The aisle glyph, or null for a staple or a coupon.
func glyph() -> TextureRect:
	return _glyph


## The product sticker's 9-slice: a tall top margin for the band, its plain edges and middle
## stretched (a tiled plain middle shows seam dots at 1080p).
static func frame_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = ArtStyle.frame_style(FRAME, FRAME_MARGIN)
	style.texture_margin_top = FRAME_TOP_MARGIN * ArtStyle.ART_SCALE
	return style
