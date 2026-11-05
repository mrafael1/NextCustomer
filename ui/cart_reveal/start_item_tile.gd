class_name StartItemTile
extends Control
## A regular on its shelf (v1.08): the item art standing straight on the plank (no card backing),
## and one small paper sticker on the shelf's edge under its base, the family glyphs and the price
## side by side. The tile's rect covers the art and the sticker, so both stay one hit area.

## The tile: the art's box on top (ART px square, standing on SHELF_Y), the sticker under it.
const SIZE := Vector2(108, 132)
const ART := 104.0
const SHELF_Y := 104.0
## The sticker's top (on the plank's front, under its light top edge), its height, a glyph's size
## and the price's font size.
const STICKER_Y := 108.0
const STICKER_HEIGHT := 24.0
const GLYPH := 18.0
const PRICE_SIZE := 22

## The item art (a hover or an open swap shelf lifts it off the plank; the sticker stays).
var art: Control
var sticker: Panel


func _init(card: CardDefinition) -> void:
	size = SIZE
	# The tile, not its art, carries the card: hovering the art or the sticker shows its popup.
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_meta("card", card)
	art = StartBoardKit.item(self, card, Vector2((SIZE.x - ART) / 2, SHELF_Y - ART), ART)
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.remove_meta("card")
	var palette: FamilyPalette = FamilyPalette.shared()
	var glyphs: Array[Texture2D] = []
	for family: String in palette.shelf_families(card.tags):
		var style: FamilyStyle = palette.style(family)
		if style != null and style.glyph != null and glyphs.size() < 2:
			glyphs.append(style.glyph)
	var price: String = "%d€" % card.base
	var font: Font = ArtStyle.pixel_number_font()
	var price_width: float = ceilf(
		font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
	)
	var width: float = 2.0 * ceilf((16 + glyphs.size() * (GLYPH + 2) + price_width) / 2.0)
	var left: float = 2.0 * floorf((SIZE.x - width) / 4.0)
	sticker = StartBoardKit.panel(
		self, Rect2(left, STICKER_Y, width, STICKER_HEIGHT), Palette.PAPER, Palette.INK
	)
	sticker.name = "Sticker"
	var x: float = 6
	for glyph_texture: Texture2D in glyphs:
		var glyph: TextureRect = UiKit.sprite(glyph_texture)
		glyph.position = Vector2(x, 3)
		glyph.size = Vector2.ONE * GLYPH
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sticker.add_child(glyph)
		x += GLYPH + 2
	var number: Label = StartBoardKit.number(
		sticker, price, Rect2(x + 2, -1, price_width + 4, STICKER_HEIGHT), Palette.INK, PRICE_SIZE
	)
	number.name = "Price"


## The item art's visible (opaque) box in tile px, where the art stands now.
func art_bounds() -> Rect2:
	var sprite: TextureRect = art.get_child(0) as TextureRect
	var box: Rect2i = ContactShadow.opaque_rect(sprite.texture)
	var texel: Vector2 = Vector2.ONE * ART / Vector2(sprite.texture.get_size())
	return Rect2(art.position + Vector2(box.position) * texel, Vector2(box.size) * texel)


## The art's highest opaque pixel over tile columns `from_x` to `to_x`, in tile px where the art
## stands now (SHELF_Y when none of its pixels lies in them).
func art_top_over(from_x: float, to_x: float) -> float:
	var sprite: TextureRect = art.get_child(0) as TextureRect
	var image: Image = sprite.texture.get_image()
	if image == null:
		return art_bounds().position.y
	var texel: Vector2 = Vector2.ONE * ART / Vector2(sprite.texture.get_size())
	var first: int = maxi(0, floori((from_x - art.position.x) / texel.x))
	var last: int = mini(image.get_width() - 1, floori((to_x - art.position.x) / texel.x))
	for row: int in image.get_height():
		for column: int in range(first, last + 1):
			if image.get_pixel(column, row).a > 0.0:
				return art.position.y + row * texel.y
	return SHELF_Y
