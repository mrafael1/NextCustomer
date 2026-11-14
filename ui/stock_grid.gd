class_name StockGrid
extends Control
## The Run info's MACHINE STOCK as a compact icon grid (the slim Run info, mock-up
## docs/art/mockups/cart_cards.html's RUN INFO · SLIM, approved by the user on 2026-11-13): the
## run's stock in groups side by side, STAPLES (the products of no aisle), each stocked aisle in
## data order, then COUPONS, each under a header plate in its sign's colours (its glyph, its
## name, its count) and its items as StockIcons in columns of ROWS rows (more rows when the
## groups would not fit the width). Under them a legend reads the in-cart badges. It only
## displays RunState; DeckView takes the icons' hovers (the popup with the card face) and dims
## them for the family filter (filter). Every piece stands on an even px and every glyph is drawn
## at a whole scale (crisp at 1280x720 and at 1920x1080's 1.5 scale; the user, 2026-11-13: "icon
## for family inside run info are blurry at 1920*1080p").

const ROWS := 2
const PITCH := Vector2(62, 80)
const GROUP_GAP := 26.0
const HEADER_HEIGHT := 26.0
const HEADER_GAP := 6.0
const HEADER_BORDER := 2.0
const HEADER_SHADE := 4.0
## The glyph: its 9 px art at 2x (ArtStyle.FAMILY_GLYPH_SIZE), an art px of paper round it.
const HEADER_GLYPH := float(ArtStyle.FAMILY_GLYPH_SIZE)
const HEADER_NAME_SIZE := 15
const HEADER_COUNT_SIZE := 14
const STAPLES := "STAPLES"
const COUPONS := "COUPONS"
const STAPLES_GLYPH := preload("res://art/icons/aisle_staples.png")
const COUPON_GLYPH := preload("res://art/icons/family_coupon.png")
## The legend under the grid: its gap, the gaps after a badge and after its words (even px), the
## badges' words.
const LEGEND_GAP := 10.0
const LEGEND_WORDS_GAP := 8.0
const LEGEND_KIND_GAP := 8.0
const LEGEND_SIZE := 14
const LEGEND_PLAIN := "copies in your cart"
const LEGEND_BIG := "one is BIG"
const LEGEND_GOLDEN := "one is GOLDEN"
## Node names (for tests).
const HEADER := "GroupHeader"
const LEGEND := "StockLegend"

var _icons: Array[StockIcon] = []
var _headers: Array[Control] = []
var _rows: int = ROWS


## The stock of `run` across `width` px.
func _init(run: RunState, width: float) -> void:
	name = "StockGrid"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var groups: Array[Dictionary] = groups_of(run)
	_rows = rows_for(groups, width)
	var counts: Dictionary[StringName, Vector2i] = cart_counts(run)
	var x: float = 0.0
	for group: Dictionary in groups:
		var cards: Array[CardDefinition] = group.cards
		var columns: int = ceili(cards.size() / float(_rows))
		var header: Control = _header(group, columns * PITCH.x - 4.0)
		header.position = Vector2(x, 0)
		add_child(header)
		_headers.append(header)
		for index: int in cards.size():
			var stocked: CardDefinition = cards[index]
			var held: Vector2i = counts.get(stocked.id, Vector2i.ZERO)
			var icon: StockIcon = StockIcon.new(
				stocked, run.balance.machine, held.x, held.y as CardDefinition.Tier
			)
			icon.position = Vector2(
				x + (index % columns) * PITCH.x,
				HEADER_HEIGHT + HEADER_GAP + floori(index / float(columns)) * PITCH.y
			)
			add_child(icon)
			_icons.append(icon)
		x += columns * PITCH.x + GROUP_GAP
	var legend: Control = _legend()
	legend.position = Vector2(0, grid_height() + LEGEND_GAP)
	add_child(legend)
	custom_minimum_size = Vector2(width, legend.position.y + legend.size.y + 2.0)
	size = custom_minimum_size


## The stock's groups in order, each {name, colour, shade, ink, glyph, cards}: STAPLES (products
## of no aisle), each stocked aisle in data order, COUPONS. Empty groups are left out.
static func groups_of(run: RunState) -> Array[Dictionary]:
	var staples: Array[CardDefinition] = []
	var coupons: Array[CardDefinition] = []
	var by_aisle: Dictionary[StringName, Array] = {}
	for card: CardDefinition in run.stock.cards:
		if card.is_coupon():
			coupons.append(card)
			continue
		var aisle: AisleDefinition = run.balance.aisle_of(card)
		if aisle == null:
			staples.append(card)
		else:
			if not by_aisle.has(aisle.id):
				by_aisle[aisle.id] = []
			by_aisle[aisle.id].append(card)
	var groups: Array[Dictionary] = []
	if not staples.is_empty():
		groups.append(
			_group(STAPLES, Palette.TOMATO, Palette.TOMATO_DARK, false, STAPLES_GLYPH, staples)
		)
	for aisle: AisleDefinition in run.balance.aisles:
		if not by_aisle.has(aisle.id):
			continue
		var ramp: Array[Color] = BoosterArt.ramp(aisle.id)
		var cards: Array[CardDefinition] = []
		cards.assign(by_aisle[aisle.id])
		groups.append(
			_group(
				aisle.display_name.to_upper(),
				ramp[1],
				ramp[2],
				BoosterArt.LIGHT_SIGNS.has(aisle.id),
				BoosterArt.glyph(aisle.id),
				cards
			)
		)
	if not coupons.is_empty():
		groups.append(
			_group(COUPONS, Palette.GREY_LIGHT, Palette.GREY, true, COUPON_GLYPH, coupons)
		)
	return groups


static func _group(
	group_name: String,
	colour: Color,
	shade: Color,
	ink: bool,
	glyph: Texture2D,
	cards: Array[CardDefinition]
) -> Dictionary:
	return {
		"name": group_name,
		"colour": colour,
		"shade": shade,
		"ink": ink,
		"glyph": glyph,
		"cards": cards,
	}


## The fewest rows (ROWS at least) at which `groups` fit side by side in `width`.
static func rows_for(groups: Array[Dictionary], width: float) -> int:
	var rows: int = ROWS
	while rows < 12:
		var needed: float = -GROUP_GAP
		for group: Dictionary in groups:
			needed += ceili((group.cards as Array).size() / float(rows)) * PITCH.x + GROUP_GAP
		if needed <= width:
			break
		rows += 1
	return rows


## The cart's copies of each stocked card, by the stocked card's id: (copies, highest tier). A
## BIG or GOLDEN copy counts for its plain product.
static func cart_counts(run: RunState) -> Dictionary[StringName, Vector2i]:
	var counts: Dictionary[StringName, Vector2i] = {}
	for card: CardInstance in run.deck.cards:
		var id: StringName = card.definition.product_card().id
		var held: Vector2i = counts.get(id, Vector2i.ZERO)
		counts[id] = Vector2i(held.x + 1, maxi(held.y, card.definition.tier))
	return counts


## The icons, group by group.
func icons() -> Array[StockIcon]:
	return _icons


## The group header plates, in order.
func headers() -> Array[Control]:
	return _headers


func row_count() -> int:
	return _rows


## The icons' area's height (the headers and the rows).
func grid_height() -> float:
	return HEADER_HEIGHT + HEADER_GAP + _rows * PITCH.y


## Dims every icon whose card lacks `family`'s printed tag ("": none dimmed).
func filter(family: String) -> void:
	for icon: StockIcon in _icons:
		icon.dimmed = not family.is_empty() and not icon.card.tags.has(family)


func _header(group: Dictionary, width: float) -> Control:
	var plate: Plate = Plate.new(group.colour, group.shade, group.glyph)
	plate.name = HEADER
	plate.size = Vector2(width, HEADER_HEIGHT)
	var ink: Color = Palette.INK if group.ink else Palette.PAPER
	var words: Label = UiKit.display_label(group.name, HEADER_NAME_SIZE, false)
	words.name = "GroupName"
	words.add_theme_color_override("font_color", ink)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.position = Vector2(Plate.WORDS_X, 0)
	words.size = Vector2(width - Plate.WORDS_X - 24.0, HEADER_HEIGHT - HEADER_SHADE)
	words.clip_text = true
	plate.add_child(words)
	var count: Label = UiKit.number_label(
		str((group.cards as Array).size()), HEADER_COUNT_SIZE, false
	)
	count.name = "GroupCount"
	count.add_theme_color_override("font_color", ink)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.position = Vector2(width - 30.0, 0)
	count.size = Vector2(24.0, HEADER_HEIGHT - HEADER_SHADE)
	plate.add_child(count)
	return plate


## The badges' legend: each badge kind and what it says, in a row, each badge on an even px.
func _legend() -> Control:
	var legend: Control = Control.new()
	legend.name = LEGEND
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds: Array[Array] = [
		[2, CardDefinition.Tier.PLAIN, LEGEND_PLAIN],
		[1, CardDefinition.Tier.BIG, LEGEND_BIG],
		[1, CardDefinition.Tier.GOLDEN, LEGEND_GOLDEN],
	]
	var height: float = StockIcon.Badge.HEIGHT
	var x: float = 0.0
	for kind: Array in kinds:
		var badge: StockIcon.Badge = StockIcon.Badge.new(kind[0], kind[1])
		badge.position = Vector2(x, 0)
		legend.add_child(badge)
		var words: Label = UiKit.body_label(kind[2], LEGEND_SIZE, Palette.TEAL_PALE)
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var room: float = (
			ArtStyle
			. BODY_FONT
			. get_string_size(kind[2], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE)
			. x
		)
		words.position = Vector2(x + badge.size.x + LEGEND_WORDS_GAP, 0)
		words.size = Vector2(ceilf(room), height)
		legend.add_child(words)
		x = ceilf((words.position.x + ceilf(room) + LEGEND_KIND_GAP) / 2.0) * 2.0
	legend.size = Vector2(x, height)
	return legend


## A group's header plate: its sign colour in an ink border with a shade along its foot, its
## glyph (a sharp pixel sprite at 2x on an even px, UiKit.sprite, as the hero's aisle signs) on a
## paper square at the left, an ink line after it.
class Plate:
	extends Control

	const GLYPH_AT := Vector2(4, 4)
	const PAPER := 2.0
	const WORDS_X := 30.0

	var _colour: Color
	var _shade: Color
	var _glyph: TextureRect

	func _init(colour: Color, shade: Color, art: Texture2D) -> void:
		_colour = colour
		_shade = shade
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if art != null:
			_glyph = UiKit.sprite(art)
			_glyph.name = "Glyph"
			_glyph.position = GLYPH_AT
			_glyph.size = Vector2.ONE * HEADER_GLYPH
			add_child(_glyph)

	## The glyph's sprite (null without a glyph).
	func glyph() -> TextureRect:
		return _glyph

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Palette.INK)
		var inside: Rect2 = rect.grow(-HEADER_BORDER)
		draw_rect(inside, _colour)
		draw_rect(
			Rect2(inside.position.x, inside.end.y - HEADER_SHADE, inside.size.x, HEADER_SHADE),
			_shade
		)
		var paper: Rect2 = Rect2(GLYPH_AT, Vector2.ONE * HEADER_GLYPH).grow(PAPER)
		draw_rect(Rect2(paper.end.x, paper.position.y, HEADER_BORDER, paper.size.y), Palette.INK)
		draw_rect(paper, Palette.PAPER)
