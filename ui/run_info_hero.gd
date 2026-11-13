class_name RunInfoHero
extends HBoxContainer
## The top of the deck view's Run info page (the cart and run info polish, 2026-11-12): the run's
## identity, readable at a glance. Left, the RUN FAMILY card (the popup's gold-trimmed paper): the
## starter pack's family as a big glyph (a FamilyGlyph at PACK_GLYPH_SCALE: its tooltip names it
## and lights its cells), its name, the pack's name and its hint (how the pack plays, its terms in
## the handbook's colours: PackHintMarkup, HandbookText), as tall as its words. Right, the
## AISLES IN STOCK plates (each aisle's own sign, frames/aisle_sign_<id>, with its glyph and name:
## the run's two aisles since v1.32, both its boosters' and its stock's), then IN YOUR CART: one
## FamilyCount tile per printed tag in the cart, most common first (DeckSummary.tag_counts), the
## run family's tile ringed in gold; the tiles filter the stock below (DeckView's family filter,
## family_tiles). A run with no starter pack (the fixed starter deck) has no
## card. It only displays RunState.

const GAP := 10.0
const PACK_WIDTH := 380.0
const PACK_FRAME := preload("res://art/frames/popup.png")
const PACK_FRAME_MARGIN := 4
const PACK_PADDING := Vector4(16, 12, 16, 12)
const PACK_GLYPH_SCALE := 6
const FAMILY_SIZE := 30
const PACK_NAME_SIZE := 16
const PACK_NAME_WEIGHT := 800
const HINT_SIZE := 16
const HINT_WEIGHT := 600
const HEADING_SCALE := 2
const RUN_FAMILY := "RUN FAMILY"
const AISLES := "AISLES IN STOCK"
const IN_CART := "IN YOUR CART"
const PACK_SUFFIX := "%s pack"
## An aisle's plate: its height, the glyph's scale, the name's size, the status chips.
const PLATE_HEIGHT := 48.0
const PLATE_GAP := 8.0
const PLATE_GLYPH_SCALE := 4
const PLATE_NAME_SIZE := 20
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
const BASE_SIGN := preload("res://art/frames/aisle_sign.png")
const TILE_GAP := 6.0
const TILE_MIN_WIDTH := 72.0
## Node names (for tests).
const PACK_CARD := "RunFamily"
const FAMILY_GLYPH := "RunFamilyGlyph"
const HINT := "Hint"
const PLATES := "Aisles"
const TILES := "Families"

var _width: float
var _family_tiles: Array[FamilyCount] = []


## The hero of `run` across `width` px.
func _init(run: RunState, width: float) -> void:
	name = "RunInfoHero"
	_width = width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(GAP))
	var pack: StarterPackDefinition = run.starter.starter_pack if run.starter != null else null
	var right_width: float = width
	if pack != null:
		add_child(_pack_card(pack))
		right_width -= PACK_WIDTH + GAP
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	var aisles: Array[AisleDefinition] = aisle_rows(run)
	if not aisles.is_empty():
		right.add_child(pixel_heading(AISLES, Palette.MUSTARD))
		right.add_child(_plates(aisles, right_width))
		right.add_child(_spacer(4))
	right.add_child(pixel_heading(IN_CART, Palette.MUSTARD))
	right.add_child(_tiles(run, right_width, pack.family if pack != null else ""))


## The cart's family tiles, in order (the deck view's family filter switches, DeckView).
func family_tiles() -> Array[FamilyCount]:
	return _family_tiles


## The stocked aisles to show: the stock's aisles in data order.
static func aisle_rows(run: RunState) -> Array[AisleDefinition]:
	var rows: Array[AisleDefinition] = []
	for aisle: AisleDefinition in run.balance.aisles:
		if run.stock.aisle_ids.has(aisle.id):
			rows.append(aisle)
	return rows


## Hard pixel words (UiKit.pixel_label at HEADING_SCALE) in a box of their size, so a container
## lays them out.
static func pixel_heading(text: String, color: Color) -> Control:
	var box: Control = Control.new()
	box.name = "Heading%s" % text.capitalize().replace(" ", "")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words: Label = UiKit.pixel_label(text, HEADING_SCALE, color)
	words.name = "Words"
	box.add_child(words)
	# The capitals' box: the words' advance, the cap height and a pixel row under it.
	var font: Font = ArtStyle.pixel_display_font()
	var width: float = (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
		* HEADING_SCALE
	)
	box.custom_minimum_size = Vector2(ceilf(width), (ArtStyle.PIXEL_CAP_HEIGHT + 1) * HEADING_SCALE)
	UiKit.place_pixel_label(words, Rect2(Vector2.ZERO, box.custom_minimum_size), true)
	return box


func _pack_card(pack: StarterPackDefinition) -> PanelContainer:
	var card: PanelContainer = UiKit.frame_panel(PACK_FRAME, PACK_FRAME_MARGIN, PACK_PADDING)
	card.name = PACK_CARD
	card.custom_minimum_size = Vector2(PACK_WIDTH, 0)
	# As tall as its words, not the aisles and tiles beside it: no slab of empty paper.
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	column.add_child(pixel_heading(RUN_FAMILY, Palette.MUSTARD_DARK))
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)
	# A local palette, not FamilyPalette.shared().style(...) (see PackCrate._init).
	var palette: FamilyPalette = FamilyPalette.shared()
	var style: FamilyStyle = palette.style(pack.family)
	if style != null and style.glyph != null:
		var glyph: FamilyGlyph = FamilyGlyph.new(style)
		glyph.name = FAMILY_GLYPH
		var side: float = ArtStyle.FAMILY_GLYPH_SIZE * PACK_GLYPH_SCALE / float(ArtStyle.ART_SCALE)
		glyph.custom_minimum_size = Vector2.ONE * side
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(glyph)
	var names: VBoxContainer = VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	var family_name: String = style.display_name if style != null else pack.family
	var family: Label = UiKit.display_label(family_name, FAMILY_SIZE, false)
	family.name = "FamilyName"
	names.add_child(family)
	var pack_name: Label = UiKit.body_label(
		PACK_SUFFIX % pack.display_name, PACK_NAME_SIZE, Palette.INK_LIGHT
	)
	pack_name.name = "PackName"
	pack_name.add_theme_font_override("font", ArtStyle.bold_font(PACK_NAME_WEIGHT))
	names.add_child(pack_name)
	if not pack.hint_text.is_empty():
		var hint: RichTextLabel = HandbookText.label(
			hint_markup(pack),
			HINT_SIZE,
			Palette.INK,
			PACK_WIDTH - PACK_PADDING.x - PACK_PADDING.z,
			HINT_WEIGHT
		)
		hint.name = HINT
		column.add_child(hint)
	return card


## `pack`'s hint as HandbookMarkup (PackHintMarkup): its keywords, its cards' names and the
## families' names marked, so the card draws them in the handbook's colours.
static func hint_markup(pack: StarterPackDefinition) -> String:
	# A local palette, not FamilyPalette.shared().families (see PackCrate._init).
	var palette: FamilyPalette = FamilyPalette.shared()
	return PackHintMarkup.of(pack.hint_text, pack.cards + pack.example_cards, palette.families)


func _plates(rows: Array[AisleDefinition], width: float) -> HBoxContainer:
	var plates: HBoxContainer = HBoxContainer.new()
	plates.name = PLATES
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.add_theme_constant_override("separation", int(PLATE_GAP))
	var plate_width: float = floorf((width - PLATE_GAP * (rows.size() - 1)) / maxf(1, rows.size()))
	for aisle: AisleDefinition in rows:
		plates.add_child(_plate(aisle, plate_width))
	return plates


## An aisle's sign: its glyph and name.
func _plate(aisle: AisleDefinition, width: float) -> PanelContainer:
	var path: String = SIGN_PATH % aisle.id
	var frame: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else BASE_SIGN
	var plate: PanelContainer = UiKit.frame_panel(frame, 3, Vector4(10, 0, 10, 4))
	plate.name = "Aisle%s" % String(aisle.id).to_pascal_case()
	plate.custom_minimum_size = Vector2(width, PLATE_HEIGHT)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)
	var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
	glyph.name = "Glyph"
	var side: float = ArtStyle.FAMILY_GLYPH_SIZE * PLATE_GLYPH_SCALE / float(ArtStyle.ART_SCALE)
	glyph.custom_minimum_size = Vector2.ONE * side
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var label: Label = UiKit.display_label(aisle.display_name, PLATE_NAME_SIZE, true)
	label.name = "AisleName"
	label.add_theme_constant_override("outline_size", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	return plate


## One FamilyCount tile per printed tag in the cart, most common first; `ringed` (the run
## family) in a gold ring. The tiles share the width, TILE_SIZE wide at most.
func _tiles(run: RunState, width: float, ringed: String) -> HFlowContainer:
	var tiles: HFlowContainer = HFlowContainer.new()
	tiles.name = TILES
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiles.add_theme_constant_override("h_separation", int(TILE_GAP))
	tiles.add_theme_constant_override("v_separation", int(TILE_GAP))
	tiles.custom_minimum_size = Vector2(width, 0)
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(run.deck.cards)
	var palette: FamilyPalette = FamilyPalette.shared()
	var styles: Array[FamilyStyle] = []
	for tag: String in counts:
		var style: FamilyStyle = palette.style(tag)
		if style != null and style.glyph != null:
			styles.append(style)
	var shown: int = maxi(1, styles.size())
	var tile_width: float = floorf((width - TILE_GAP * (shown - 1)) / shown)
	tile_width = clampf(tile_width, TILE_MIN_WIDTH, FamilyCount.TILE_SIZE.x)
	for style: FamilyStyle in styles:
		var tile: FamilyCount = FamilyCount.new(
			style, counts[style.id], FamilyCount.Look.TILE, tile_width
		)
		tile.ringed = style.id == ringed
		tiles.add_child(tile)
		_family_tiles.append(tile)
	return tiles


static func _spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
