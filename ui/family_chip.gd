class_name FamilyChip
extends TipTarget
## The scanner bay's plate under the item (#105 piece 2, mock-up readability_v3.html's aisleChip):
## a chip in the item's ticket colour (FamilyPalette.ticket_families; a split ticket in its first
## family's) naming what the item works with, the way its ticket's colour does: a family (its
## glyph, then its name), a card ("Milk"), the item itself ("Banana"), both halves of a split
## ticket ("Snack + Bakery") or COUPON for the plain coupon ticket. Its tooltip is the colour's
## (FamilyPalette.colour_tip). Between items and at the count's end it shows a word on paper
## (show_text: "–", "THANK YOU"), with no tooltip. Upper case, the body font at TEXT_WEIGHT,
## TEXT_SIZE px, on a BORDER px ink edge with a BORDER px lit row inside it.

const SIZE := Vector2(100, 20)
const BORDER := 2.0
const GLYPH_AT := Vector2(4, 1)
const TEXT_WITH_GLYPH := Rect2(24, 0, 74, 20)
const TEXT_ALONE := Rect2(6, 0, 88, 20)
const TEXT_SIZE := 11
const TEXT_WEIGHT := 800
const TEXT_SPACING := 0
const COUPON_TEXT := "COUPON"
const SPLIT_TEXT := "%s + %s"

var _face: Color = Palette.PAPER
var _light: Color = Palette.PAPER
var _glyph: TextureRect
var _label: Label


func _init() -> void:
	super()
	name = "FamilyChip"
	size = SIZE
	custom_minimum_size = SIZE
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_SCALE
	_glyph.position = GLYPH_AT
	_glyph.size = Vector2.ONE * ArtStyle.FAMILY_GLYPH_SIZE
	ArtStyle.use_pixel_material(_glyph)
	_glyph.visible = false
	add_child(_glyph)
	_label = UiKit.body_label("", TEXT_SIZE, Palette.INK)
	_label.name = "Text"
	_label.add_theme_font_override("font", ArtStyle.bold_font(TEXT_WEIGHT))
	_label.add_theme_constant_override("outline_size", 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_label)
	_place_text(TEXT_ALONE, HORIZONTAL_ALIGNMENT_CENTER)


func _ready() -> void:
	_place_text(
		TEXT_WITH_GLYPH if _glyph.visible else TEXT_ALONE,
		HORIZONTAL_ALIGNMENT_LEFT if _glyph.visible else HORIZONTAL_ALIGNMENT_CENTER
	)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.INK)
	var inside: Rect2 = rect.grow(-BORDER)
	draw_rect(inside, _face)
	draw_rect(Rect2(inside.position, Vector2(inside.size.x, BORDER)), _light)


## `definition`'s chip (see the class comment).
func show_item(definition: CardDefinition) -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var ids: PackedStringArray = palette.ticket_families(definition)
	var first: FamilyStyle = palette.style(ids[0]) if not ids.is_empty() else null
	_face = first.face if first != null and first.has_ticket_colours() else Palette.PAPER
	_light = first.light if first != null and first.has_ticket_colours() else Palette.PAPER
	var ink: Color = palette.text_color(ids) if not ids.is_empty() else Palette.INK
	var art: Texture2D = first.glyph if ids.size() == 1 and first != null else null
	_glyph.texture = art
	_glyph.visible = art != null
	_label.text = item_text(definition)
	_label.add_theme_color_override("font_color", ink)
	tip_text = palette.colour_tip(definition)
	_place_text(
		TEXT_WITH_GLYPH if _glyph.visible else TEXT_ALONE,
		HORIZONTAL_ALIGNMENT_LEFT if _glyph.visible else HORIZONTAL_ALIGNMENT_CENTER
	)
	queue_redraw()


## A word on paper ("–", "THANK YOU"; "" for a blank chip), with no tooltip.
func show_text(text: String) -> void:
	_face = Palette.PAPER
	_light = Palette.PAPER
	_glyph.texture = null
	_glyph.visible = false
	_label.text = text
	_label.add_theme_color_override("font_color", Palette.INK)
	tip_text = ""
	_place_text(TEXT_ALONE, HORIZONTAL_ALIGNMENT_CENTER)
	queue_redraw()


## The text shown, the glyph (hidden without one) and the face's colour, for checks.
func chip_text() -> String:
	return _label.text


func text_label() -> Label:
	return _label


func glyph_sprite() -> TextureRect:
	return _glyph


func face_color() -> Color:
	return _face


## What `definition`'s chip says (see the class comment), upper case. Pure (the palette's data).
static func item_text(definition: CardDefinition) -> String:
	var palette: FamilyPalette = FamilyPalette.shared()
	var ids: PackedStringArray = palette.ticket_families(definition)
	if ids.is_empty():
		return COUPON_TEXT
	if ids.size() > 1:
		return (
			(SPLIT_TEXT % [palette.display_name(ids[0]), palette.display_name(ids[1])]).to_upper()
		)
	var why: CardFamilies.Why = palette.colour_reason(definition)
	match why.reason:
		CardFamilies.Reason.CARD, CardFamilies.Reason.SAME:
			return why.subject.to_upper()
	return palette.display_name(ids[0]).to_upper()


func _place_text(rect: Rect2, align: HorizontalAlignment) -> void:
	_label.horizontal_alignment = align
	_label.position = rect.position
	_label.size = rect.size
