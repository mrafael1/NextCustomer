class_name FamilyGlyph
extends TipTarget
## One family's glyph (#105, mock-up readability v3), shown alone: its 9x9 art at 2x
## (ArtStyle.FAMILY_GLYPH_SIZE), with no tile and no word. On a ticket it has a paper rim (one art
## pixel round its art, ArtStyle.glyph_rim_material), so a green apple reads on a green ticket.
## Resting the pointer on it shows its family's name (a TipTarget, GlyphTips): below `tip_anchor`
## (its ticket) when `tip_below`, else above the glyph. It takes no clicks: the item under it
## keeps its hover, its drag and its clicks.

const RIM_NAME := "Rim"

## The family it shows (a FamilyStyle id, as cards write it).
var family: String = ""
var _rim: TextureRect


## The glyph of `style`, with a paper rim when `rimmed`.
func _init(style: FamilyStyle, rimmed: bool = false) -> void:
	super()
	family = style.id
	tip_text = style.display_name
	name = "Glyph%s" % style.id
	texture = style.glyph
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(self)
	size = Vector2.ONE * ArtStyle.FAMILY_GLYPH_SIZE
	custom_minimum_size = size
	if rimmed:
		_rim = TextureRect.new()
		_rim.name = RIM_NAME
		_rim.texture = style.glyph
		_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rim.stretch_mode = TextureRect.STRETCH_SCALE
		_rim.show_behind_parent = true
		var grow: float = ArtStyle.RIM_TEXELS * ArtStyle.ART_SCALE
		_rim.position = -Vector2.ONE * grow
		_rim.size = size + Vector2.ONE * 2.0 * grow
		ArtStyle.set_look(_rim, ArtStyle.glyph_rim_material())
		add_child(_rim)


## The paper rim, or null for a glyph without one.
func rim() -> TextureRect:
	return _rim


## The glyph's drawn rect with its rim (its paper ring is one art pixel wide), in its parent's
## coordinates.
func rim_rect() -> Rect2:
	var rect: Rect2 = Rect2(position, size)
	return rect.grow(ArtStyle.ART_SCALE) if _rim != null else rect
