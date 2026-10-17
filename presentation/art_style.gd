class_name ArtStyle
extends RefCounted
## The pixel-art style (full build plan section 6.1): fonts by role, the sharp-pixel material
## and the art textures. Presentation loads the art from a card's `art_ref`, so `core/` stays
## free of it. UiKit builds the styled controls (frame panels, framed buttons, labels by font
## role) from it.

## Titles, numbers and stamps. Pixelify Sans, SIL Open Font License (imported as MSDF, so its
## outline survives the count-up's large slams).
const DISPLAY_FONT := preload("res://fonts/PixelifySans-Variable.ttf")
## Rules, tags and tooltips. Atkinson Hyperlegible Next, SIL Open Font License.
const BODY_FONT := preload("res://fonts/AtkinsonHyperlegibleNext-Variable.ttf")
## The same Atkinson Hyperlegible Next, imported as MSDF for numbers: the count-up slams them
## at up to 3.2x, which would blur the rule text's raster import.
const NUMBER_BASE_FONT := preload("res://fonts/AtkinsonHyperlegibleNext-Variable-MSDF.ttf")
## The receipt. JetBrains Mono, SIL Open Font License.
const MONO_FONT := preload("res://fonts/JetBrainsMono-Regular.ttf")
## Numbers and money (base values, quotas, totals, the count-up's flying numbers) use the body
## font at this weight: its digits and € can't be mistaken for each other, which Pixelify Sans's
## € and 2 could (decided with the user on the style frame).
const NUMBER_WEIGHT := 750
## Every character the game prints that a font might lack.
## (− is U+2212, the minus sign.)
const REQUIRED_GLYPHS := "€×·—…−"

## The art's warm ink (art/src/palette.txt '#'), for text and outlines drawn in this style
## (Palette.INK is this colour).
const INK := Color("2b2420")
## Canvas pixels per art pixel (a 640x360 art grid on the 1280x720 canvas).
const ART_SCALE := 2
const PIXEL_SHADER := preload("res://presentation/pixel_art.gdshader")
## Items (#75, decision 3A): every item is 48x48 art drawn at 2x. A product's `art_ref` names its
## sprite; an undrawn product shows ITEM_PENDING, a dashed box that ItemView prints the name in.
## Every coupon is the shared COUPON_SLIP, and a coupon's `art_ref` names the icon drawn on it.
const ITEM_PENDING := preload("res://art/icons/art_pending_v2.png")
const COUPON_SLIP := preload("res://art/items_v2/coupon_slip.png")
## Marks the nodes that draw pixel art, so a debug A/B switch can find them.
const PIXEL_ART_META := &"pixel_art"
## An aisle's glyph (9x9 art), by the aisle's id.
const GLYPH_PATH := "res://art/icons/aisle_%s.png"

static var _material: ShaderMaterial
static var _number_font: FontVariation
static var _bold_fonts: Dictionary[int, FontVariation] = {}
static var _spaced_display_fonts: Dictionary[int, FontVariation] = {}


## Marks a node that draws pixel art (its own texture or stylebox, never text: a Label or a
## Button's text must not go through the shader) and gives it the sharp-pixel material.
static func use_pixel_material(item: CanvasItem) -> void:
	item.material = pixel_material()
	item.set_meta(PIXEL_ART_META, true)


## A/B for review (the capture scene's S key): every node under `root` that is marked as pixel
## art gets the sharp-pixel material (`sharp`), or plain nearest filtering without it.
static func set_sharp(root: Node, sharp: bool) -> void:
	var item: CanvasItem = root as CanvasItem
	if item != null and item.has_meta(PIXEL_ART_META):
		item.material = pixel_material() if sharp else null
		item.texture_filter = (
			CanvasItem.TEXTURE_FILTER_PARENT_NODE if sharp else CanvasItem.TEXTURE_FILTER_NEAREST
		)
	for child: Node in root.get_children():
		set_sharp(child, sharp)


## The shared sharp-pixel material.
static func pixel_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = PIXEL_SHADER
	return _material


## The font for numbers and money: Atkinson Hyperlegible Next at NUMBER_WEIGHT.
static func number_font() -> Font:
	if _number_font == null:
		_number_font = FontVariation.new()
		_number_font.base_font = NUMBER_BASE_FONT
		var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		_number_font.variation_opentype = {weight: NUMBER_WEIGHT}
	return _number_font


## The body font (Atkinson Hyperlegible Next) at `weight`, shared by the price stickers, the
## items, the monitor's beats and the row's cells.
static func bold_font(weight: int) -> Font:
	if not _bold_fonts.has(weight):
		var font: FontVariation = FontVariation.new()
		font.base_font = BODY_FONT
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		font.variation_opentype = {tag: weight}
		_bold_fonts[weight] = font
	return _bold_fonts[weight]


## The display font (Pixelify Sans) with its glyphs `spacing` px apart (mock-up B2's
## letter-spaced captions, such as the count-up's item name and the quota row's QUOTA).
static func spaced_display_font(spacing: int) -> Font:
	if not _spaced_display_fonts.has(spacing):
		var font: FontVariation = FontVariation.new()
		font.base_font = DISPLAY_FONT
		font.spacing_glyph = spacing
		_spaced_display_fonts[spacing] = font
	return _spaced_display_fonts[spacing]


## The glyph texture's path for an aisle.
static func glyph_path(aisle: AisleDefinition) -> String:
	return GLYPH_PATH % aisle.id


## An item's sprite (48x48 art): a product's from its `art_ref`, or ITEM_PENDING; every coupon's
## is COUPON_SLIP.
static func item_sprite(definition: CardDefinition) -> Texture2D:
	if definition.is_coupon():
		return COUPON_SLIP
	var sprite: Texture2D = _art_ref_texture(definition)
	return sprite if sprite != null else ITEM_PENDING


## A coupon's icon on its slip, from its `art_ref`, or null (a product, or an undrawn icon).
static func coupon_icon(definition: CardDefinition) -> Texture2D:
	return _art_ref_texture(definition) if definition.is_coupon() else null


## A 9-slice frame drawn from a pre-scaled frame texture; `margin` is in art pixels. Its edges
## and middle stretch, so they must be plain: a repeated (tiled) middle picks up the
## neighbouring pixels at every seam once the canvas is scaled (a dotted grid at 1080p). A
## patterned frame is drawn at its node's full size instead (the coupon).
static func frame_style(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(margin * ART_SCALE)
	return style


## The texture `art_ref` names, or null when it names none or a missing file.
static func _art_ref_texture(definition: CardDefinition) -> Texture2D:
	if definition.art_ref != "" and ResourceLoader.exists(definition.art_ref):
		return load(definition.art_ref) as Texture2D
	return null
