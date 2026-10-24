class_name ArtStyle
extends RefCounted
## The pixel-art style (full build plan section 6.1): fonts by role, the sharp-pixel material
## and the art textures. Presentation loads the art from a card's `art_ref`, so `core/` stays
## free of it. UiKit builds the styled controls (frame panels, framed buttons, labels by font
## role) from it.

## The greyed sharp-pixel looks (#71, mock-up h1): a denied item's sprite, and a drained sticker
## (stepped back while another item is hovered, or on a denied item).
enum Grey { DENIED, DRAINED }

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
## The sharp-pixel material greyed (#71): grey_material's looks.
const GREY_SHADER := preload("res://presentation/pixel_art_grey.gdshader")
## A boosted item's stepped halo (#71): halo_material's rings.
const HALO_SHADER := preload("res://presentation/halo_outline.gdshader")
## A die-cut rim (#105): rim_material's bands.
const RIM_SHADER := preload("res://presentation/rim_outline.gdshader")
## Each Grey look's (brightness, contrast), the mock-up's CSS filters: a denied sprite's
## grayscale(1) brightness(.78) contrast(.9), a drained sticker's brightness(.62) contrast(.55).
const GREY_LOOKS: Dictionary[Grey, Vector2] = {
	Grey.DENIED: Vector2(0.78, 0.9),
	Grey.DRAINED: Vector2(0.62, 0.55),
}
## A halo has 1 to HALO_MAX_RINGS rings.
const HALO_MAX_RINGS := 3
## Items (#75, decision 3A): every item is 48x48 art drawn at 2x. A product's `art_ref` names its
## sprite; an undrawn product shows ITEM_PENDING, a dashed box that ItemView prints the name in.
## Every coupon is the shared COUPON_SLIP, and a coupon's `art_ref` names the icon drawn on it.
const ITEM_PENDING := preload("res://art/icons/art_pending_v2.png")
const COUPON_SLIP := preload("res://art/items_v2/coupon_slip.png")
## Marks the nodes that draw pixel art, so a debug A/B switch can find them.
const PIXEL_ART_META := &"pixel_art"
## A pixel-art node's own look material (a grey or a halo, set_look), which set_sharp keeps
## instead of resetting it to the plain sharp-pixel material.
const LOOK_META := &"pixel_art_look"
## An aisle's glyph (9x9 art), by the aisle's id.
const GLYPH_PATH := "res://art/icons/aisle_%s.png"
## The readability pass (#105, mock-up readability v3). Item names (ItemName) are Pixelify Sans
## (DISPLAY_FONT, its regular weight: the variable font's default) at its native size (one font
## pixel = 2 canvas px, the art's grid), and never smaller: a name too long for its row falls back
## to the body font at NAME_FALLBACK_WEIGHT (as the Cart prints it). Pixelify never prints numbers
## (its 5 and S differ by one font pixel): the number font does.
const ITEM_NAME_SIZE := 22
const NAME_FALLBACK_WEIGHT := 700
## A family glyph's size on screen: its 9x9 art at 2x (a ticket's adds a one-texel paper rim).
const FAMILY_GLYPH_SIZE := 18
## A ticket's short text (the sticker summary): the body font at TICKET_TEXT_WEIGHT,
## TICKET_TEXT_SIZE px on a TICKET_TEXT_LINE px pitch, at most TICKET_TEXT_LINES lines.
const TICKET_TEXT_WEIGHT := 800
const TICKET_TEXT_SIZE := 13
const TICKET_TEXT_LINE := 15
const TICKET_TEXT_LINES := 2
## The stacked price: the new price's digits in the burst (BURST_PRICE_SIZE, or
## BURST_PRICE_SIZE_3 for three characters such as "€10"), the struck old price under it.
const BURST_PRICE_SIZE := 22
const BURST_PRICE_SIZE_3 := 21
const STRUCK_PRICE_SIZE := 15
## A glyph tooltip's text: the body font at TIP_TEXT_WEIGHT, TIP_TEXT_SIZE px.
const TIP_TEXT_WEIGHT := 800
const TIP_TEXT_SIZE := 13
## A rim_material's art: grown by this many art pixels on every side (its ring and outline).
const RIM_TEXELS := 2

static var _material: ShaderMaterial
static var _grey_materials: Dictionary[Grey, ShaderMaterial] = {}
static var _halo_materials: Dictionary[int, ShaderMaterial] = {}
static var _number_font: FontVariation
static var _bold_fonts: Dictionary[int, FontVariation] = {}
static var _spaced_display_fonts: Dictionary[int, FontVariation] = {}
static var _rim_materials: Dictionary[String, ShaderMaterial] = {}


## Marks a node that draws pixel art (its own texture or stylebox, never text: a Label or a
## Button's text must not go through the shader) and gives it the sharp-pixel material.
static func use_pixel_material(item: CanvasItem) -> void:
	item.material = pixel_material()
	item.set_meta(PIXEL_ART_META, true)


## A/B for review (the capture scene's S key): every node under `root` that is marked as pixel
## art gets the sharp-pixel material (`sharp`), or plain nearest filtering without it.
static func set_sharp(root: Node, sharp: bool) -> void:
	var item: CanvasItem = root as CanvasItem
	if item != null and item.has_meta(LOOK_META):
		# A grey or a halo is the node's look, not only its sampling: kept in both modes.
		item.material = item.get_meta(LOOK_META) as ShaderMaterial
		item.texture_filter = (
			CanvasItem.TEXTURE_FILTER_PARENT_NODE if sharp else CanvasItem.TEXTURE_FILTER_NEAREST
		)
	elif item != null and item.has_meta(PIXEL_ART_META):
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


## Gives a pixel-art node a look material (grey_material or halo_material), which set_sharp
## keeps; null puts the plain sharp-pixel material back.
static func set_look(item: CanvasItem, look: ShaderMaterial) -> void:
	item.set_meta(PIXEL_ART_META, true)
	if look == null:
		item.remove_meta(LOOK_META)
		item.material = pixel_material()
	else:
		item.set_meta(LOOK_META, look)
		item.material = look


## The shared greyed sharp-pixel material of `look` (#71): a denied item's sprite or a drained
## sticker's frame, shadow and badge.
static func grey_material(look: Grey) -> ShaderMaterial:
	if not _grey_materials.has(look):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GREY_SHADER
		material.set_shader_parameter(&"brightness", GREY_LOOKS[look].x)
		material.set_shader_parameter(&"contrast", GREY_LOOKS[look].y)
		_grey_materials[look] = material
	return _grey_materials[look]


## The shared halo material with `rings` rings (1 to HALO_MAX_RINGS, clamped), for an ItemHalo
## drawn over the sprite's rect grown by (rings + 1) art pixels (halo_outline.gdshader). The
## bands, inside out: 1 ring mustard light; 2 mustard pale, mustard; 3 paper, mustard light,
## mustard; then the ink outline.
static func halo_material(rings: int) -> ShaderMaterial:
	var count: int = clampi(rings, 1, HALO_MAX_RINGS)
	if not _halo_materials.has(count):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = HALO_SHADER
		material.set_shader_parameter(&"rings", count)
		material.set_shader_parameter(&"bands", halo_bands(count))
		_halo_materials[count] = material
	return _halo_materials[count]


## The halo's band colours for `rings` rings, inside out, then the ink (4 colours, padded with
## ink).
static func halo_bands(rings: int) -> PackedColorArray:
	var bands: PackedColorArray
	match clampi(rings, 1, HALO_MAX_RINGS):
		1:
			bands = PackedColorArray([Palette.MUSTARD_LIGHT])
		2:
			bands = PackedColorArray([Palette.MUSTARD_PALE, Palette.MUSTARD])
		_:
			bands = PackedColorArray([Palette.PAPER, Palette.MUSTARD_LIGHT, Palette.MUSTARD])
	while bands.size() < HALO_MAX_RINGS + 1:
		bands.append(INK)
	return bands


## A shared die-cut rim material (#105, mock-up readability v3's chained 2 px drop-shadows): the
## rim shader with its two bands, `bands` (the first art pixel round the art, then the second; a
## transparent colour draws nothing). Drawn on a TextureRect showing the art's own texture over
## its rect grown by RIM_TEXELS art pixels on every side, behind the art.
static func rim_material(bands: PackedColorArray) -> ShaderMaterial:
	var key: String = ",".join(
		Array(bands).map(func(colour: Color) -> String: return colour.to_html())
	)
	if not _rim_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = RIM_SHADER
		material.set_shader_parameter(&"bands", bands)
		_rim_materials[key] = material
	return _rim_materials[key]


## A changed price's die-cut (#105): a paper texel, then an ink one, round the tag's art.
static func cut_material() -> ShaderMaterial:
	return rim_material(PackedColorArray([Palette.PAPER, INK]))


## A family glyph's paper rim on a ticket (#105): one paper texel round the glyph's art.
static func glyph_rim_material() -> ShaderMaterial:
	return rim_material(PackedColorArray([Palette.PAPER, Color(0, 0, 0, 0)]))


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
