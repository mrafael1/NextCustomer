class_name ArtStyle
extends RefCounted
## The pixel-art style (full build plan section 6.1): fonts by role, the sharp-pixel material
## and the art textures. Presentation loads the art from a card's `art_ref`, so `core/` stays
## free of it. Used by the style frame; the real screens adopt it in phase 3.

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
const REQUIRED_GLYPHS := "€×·—…"

## The art's warm ink (art/src/palette.txt '#'), for text and outlines drawn in this style. The
## prototype screens keep Palette.INK until they adopt the style in phase 3.
const INK := Color("2b2420")
## Canvas pixels per art pixel (a 640x360 art grid on the 1280x720 canvas).
const ART_SCALE := 2
const PIXEL_SHADER := preload("res://presentation/pixel_art.gdshader")
const ART_PENDING := preload("res://art/icons/art_pending.png")
## Marks the nodes that draw pixel art, so a debug A/B switch can find them.
const PIXEL_ART_META := &"pixel_art"

static var _material: ShaderMaterial
static var _number_font: FontVariation


## Marks a node that draws pixel art (its own texture or stylebox, never text: a Label or a
## Button's text must not go through the shader) and gives it the sharp-pixel material.
static func use_pixel_material(item: CanvasItem) -> void:
	item.material = pixel_material()
	item.set_meta(PIXEL_ART_META, true)


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


## The card's sprite from its `art_ref` (a `res://` path), or the art-pending box.
static func item_texture(definition: CardDefinition) -> Texture2D:
	if definition.art_ref != "" and ResourceLoader.exists(definition.art_ref):
		return load(definition.art_ref) as Texture2D
	return ART_PENDING


## A 9-slice frame drawn from a pre-scaled frame texture; `margin` is in art pixels. Its edges
## and middle stretch, so they must be plain: a repeated (tiled) middle picks up the
## neighbouring pixels at every seam once the canvas is scaled (a dotted grid at 1080p). A
## patterned frame is drawn at its node's full size instead (the coupon).
static func frame_style(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(margin * ART_SCALE)
	return style
