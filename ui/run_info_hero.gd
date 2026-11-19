class_name RunInfoHero
extends HBoxContainer
## The top of the deck view's Run info page (the cart and run info polish, 2026-11-12): the run's
## identity, readable at a glance: the AISLES IN STOCK plates (each aisle's own sign,
## frames/aisle_sign_<id>, with its glyph and name: the run's two aisles since v1.32, both its
## boosters' and its stock's) and, beside them, the staples' line ("+ the 6 staples, in every run",
## the count from data: the slim Run info of mock-up cart_cards.html, 2026-11-13), then IN YOUR
## CART: one FamilyCount tile per printed tag in the cart, most common first
## (DeckSummary.tag_counts), the run family's tile ringed in gold; the tiles filter the stock below
## (DeckView's family filter, family_tiles). (The RUN FAMILY card of the starter pack went with the
## packs in v1.41.) It only displays RunState.

const GAP := 10.0
const HEADING_SCALE := 2
const AISLES := "AISLES IN STOCK"
const IN_CART := "IN YOUR CART"
## An aisle's plate: its height, the glyph's scale, the name's size, the status chips.
const PLATE_HEIGHT := 48.0
const PLATE_GAP := 8.0
const PLATE_GLYPH_SCALE := 4
const PLATE_NAME_SIZE := 20
## The widest plate, and the staples' line beside the plates: its words, size and room.
const PLATE_MAX_WIDTH := 258.0
const STAPLES_NOTE := "+ the %d staples, in every run"
const STAPLES_SIZE := 15
const STAPLES_ROOM := 230.0
const STAPLES_NAME := "StaplesNote"
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
const BASE_SIGN := preload("res://art/frames/aisle_sign.png")
const TILE_GAP := 6.0
const TILE_MIN_WIDTH := 72.0
## Node names (for tests).
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
	var right_width: float = width
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	var aisles: Array[AisleDefinition] = aisle_rows(run)
	if not aisles.is_empty():
		right.add_child(pixel_heading(AISLES, Palette.MUSTARD))
		right.add_child(_plates(aisles, right_width, RunStock.staples(run.balance).size()))
		right.add_child(_spacer(4))
	right.add_child(pixel_heading(IN_CART, Palette.MUSTARD))
	right.add_child(_tiles(run, right_width, ""))


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


## The aisles' plates side by side, then the staples' line (`staples` of them; none for 0).
func _plates(rows: Array[AisleDefinition], width: float, staples: int) -> HBoxContainer:
	var plates: HBoxContainer = HBoxContainer.new()
	plates.name = PLATES
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.add_theme_constant_override("separation", int(PLATE_GAP))
	var room: float = width - (STAPLES_ROOM + PLATE_GAP if staples > 0 else 0.0)
	var plate_width: float = floorf((room - PLATE_GAP * (rows.size() - 1)) / maxf(1, rows.size()))
	plate_width = minf(plate_width, PLATE_MAX_WIDTH)
	for aisle: AisleDefinition in rows:
		plates.add_child(_plate(aisle, plate_width))
	if staples > 0:
		var note: Label = UiKit.body_label(STAPLES_NOTE % staples, STAPLES_SIZE, Palette.TEAL_PALE)
		note.name = STAPLES_NAME
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.size_flags_vertical = Control.SIZE_FILL
		plates.add_child(note)
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
