class_name FamilyCount
extends FamilyGlyph
## How many cards of a family a cart holds (the cart and run info polish, 2026-11-12): the
## family's glyph and the count in the number font, on paper in an ink box with its corner pixels
## cut, the family's colour along its edge. It is a family glyph (FamilyGlyph), so resting the
## pointer on it shows its tooltip (the family's name and the count) and lights that family's
## cells in the deck view (PlanningEffects.watch_glyphs: the mix highlight), and a right-click on
## the tip opens its handbook page. No words: the glyph names the family. In the deck view it is
## also the family filter's switch (DeckView.preview_family, toggle_pin): `lit` while the pointer
## previews its family (its paper turns mustard pale), `pinned` while a click holds the filter
## (mustard light, sunk: a darker edge along its top and left inside the border). Neither moves it.
##
## CHIP is the Cart page's tag line (glyph at 2x); TILE the Run info's families (glyph at 4x, the
## count big, the family's name under them, a band of its colour along the top). A family with no
## ticket colours (the coupon mark) gets the grey band.

enum Look { CHIP, TILE }

const BORDER := 2.0
## CHIP: its height, the count's size, the room inside the border and the glyph-count gap.
const CHIP_HEIGHT := 24.0
const CHIP_NUMBER_SIZE := 18
const CHIP_PADDING := 6.0
const CHIP_GAP := 5.0
## The colour bar along a chip's foot, inside the border.
const CHIP_BAR := 3.0
## TILE: its size, the glyph's scale, the count's and name's sizes, the colour band's height.
const TILE_SIZE := Vector2(88, 84)
const TILE_GLYPH_SCALE := 4
const TILE_NUMBER_SIZE := 28
const TILE_NAME_SIZE := 13
const TILE_NAME_WEIGHT := 800
const TILE_BAND := 8.0
const TILE_GAP := 4.0
## A ringed tile's gold ring (the run family's), inside its box over the ink border.
const RING := 3.0
const TIP := "%s · %d in your cart"
## The paper inside a lit (previewed) and a pinned box, and a pinned box's sunk edge (SINK px).
const LIT_FILL := Palette.MUSTARD_PALE
const PINNED_FILL := Palette.MUSTARD_LIGHT
const SINK_COLOR := Palette.MUSTARD_DARK
const SINK := 2.0
## Node names (for tests).
const COUNT_NAME := "Count"
const ICON_NAME := "FamilyIcon"
const FAMILY_NAME := "FamilyName"

## The count it shows.
var count: int = 0
var look: Look = Look.CHIP
## A gold ring round the tile (the Run info's run family).
var ringed: bool = false:
	set(value):
		ringed = value
		queue_redraw()
## The pointer previews its family's filter in the deck view (DeckView.preview_family).
var lit: bool = false:
	set(value):
		if lit != value:
			lit = value
			queue_redraw()
## A click holds its family's filter in the deck view (DeckView.toggle_pin).
var pinned: bool = false:
	set(value):
		if pinned != value:
			pinned = value
			queue_redraw()
var _band: Color
var _icon: TextureRect
var _number: Label
var _name_label: Label


## `count` cards of `style`'s family, as a CHIP or a TILE `tile_width` wide (TILE_SIZE's by
## default).
func _init(style: FamilyStyle, family_count: int, shown: Look, tile_width: float = 0.0) -> void:
	super(style)
	count = family_count
	look = shown
	name = "Count%s" % style.id
	tip_text = TIP % [style.display_name, family_count]
	_band = style.face if style.has_ticket_colours() else Palette.GREY_LIGHT
	# The glyph and the box are drawn by the children and _draw, not by this TextureRect.
	texture = null
	material = null
	var tile: bool = shown == Look.TILE
	_icon = UiKit.sprite(style.glyph)
	_icon.name = ICON_NAME
	var glyph_side: float = (
		ArtStyle.FAMILY_GLYPH_SIZE * TILE_GLYPH_SCALE / float(ArtStyle.ART_SCALE)
		if tile
		else float(ArtStyle.FAMILY_GLYPH_SIZE)
	)
	_icon.size = Vector2.ONE * glyph_side
	add_child(_icon)
	var number_size: int = TILE_NUMBER_SIZE if tile else CHIP_NUMBER_SIZE
	_number = UiKit.number_label(str(family_count), number_size, false)
	_number.name = COUNT_NAME
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)
	if tile:
		_name_label = UiKit.body_label(style.display_name, TILE_NAME_SIZE, Palette.INK_LIGHT)
		_name_label.name = FAMILY_NAME
		_name_label.add_theme_font_override("font", ArtStyle.bold_font(TILE_NAME_WEIGHT))
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.clip_text = true
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name_label)
	var width: float = tile_width if tile_width > 0.0 else TILE_SIZE.x
	var wanted: Vector2 = (
		Vector2(width, TILE_SIZE.y) if tile else Vector2(chip_width(family_count), CHIP_HEIGHT)
	)
	size = wanted
	custom_minimum_size = wanted
	_lay_out()


## A chip's width for `family_count`: the border, padding, glyph, gap and count, on the 2 px grid.
static func chip_width(family_count: int) -> float:
	var digits: float = (
		ArtStyle
		. number_font()
		. get_string_size(str(family_count), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_NUMBER_SIZE)
		. x
	)
	var width: float = (
		BORDER * 2.0 + CHIP_PADDING * 2.0 + ArtStyle.FAMILY_GLYPH_SIZE + CHIP_GAP + ceilf(digits)
	)
	return ceilf(width / 2.0) * 2.0


## The count's label, the glyph and the name (null on a chip), for tests.
func count_label() -> Label:
	return _number


func icon() -> TextureRect:
	return _icon


func name_label() -> Label:
	return _name_label


## The colour along its edge (its family's face, or grey light).
func band_color() -> Color:
	return _band


## The paper's colour inside the border: PINNED_FILL when pinned, LIT_FILL when lit, else paper.
func fill_color() -> Color:
	if pinned:
		return PINNED_FILL
	return LIT_FILL if lit else Palette.PAPER


func _notification(what: int) -> void:
	# The count's width is known for sure once its label is in the tree.
	if what == NOTIFICATION_READY or what == NOTIFICATION_THEME_CHANGED:
		_lay_out()


func _lay_out() -> void:
	var digits: Vector2 = _number.get_minimum_size()
	if look == Look.CHIP:
		_icon.position = Vector2(
			BORDER + CHIP_PADDING, roundf((size.y - CHIP_BAR - _icon.size.y) / 2.0)
		)
		_number.position = Vector2(_icon.position.x + _icon.size.x + CHIP_GAP, 0)
		_number.size = Vector2(digits.x, size.y - CHIP_BAR)
		return
	# The glyph and the count centred as one group under the band, the name under them.
	var group: float = _icon.size.x + TILE_GAP + digits.x
	var left: float = roundf((size.x - group) / 2.0)
	var top: float = BORDER + TILE_BAND + 6.0
	_icon.position = Vector2(left, top)
	_number.position = Vector2(left + _icon.size.x + TILE_GAP, top)
	_number.size = Vector2(digits.x, _icon.size.y)
	_name_label.position = Vector2(BORDER + 2.0, top + _icon.size.y + 2.0)
	_name_label.size = Vector2(size.x - BORDER * 2.0 - 4.0, size.y - top - _icon.size.y - 4.0)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	# The ink box with its corner pixels cut, paper inside, the family's colour on its edge.
	draw_rect(Rect2(1, 0, rect.size.x - 2, rect.size.y), Palette.INK)
	draw_rect(Rect2(0, 1, rect.size.x, rect.size.y - 2), Palette.INK)
	var inside: Rect2 = rect.grow(-BORDER)
	draw_rect(inside, fill_color())
	if pinned:
		# Sunk: a darker edge along the top (under a tile's band) and the left.
		var top: float = inside.position.y + (0.0 if look == Look.CHIP else TILE_BAND + 2.0)
		draw_rect(Rect2(inside.position.x, top, inside.size.x, SINK), SINK_COLOR)
		draw_rect(Rect2(inside.position.x, top, SINK, inside.end.y - top), SINK_COLOR)
	if look == Look.CHIP:
		draw_rect(Rect2(inside.position.x, inside.end.y - CHIP_BAR, inside.size.x, CHIP_BAR), _band)
	else:
		draw_rect(Rect2(inside.position, Vector2(inside.size.x, TILE_BAND)), _band)
		draw_rect(
			Rect2(inside.position + Vector2(0, TILE_BAND), Vector2(inside.size.x, 2)), Palette.INK
		)
	if ringed:
		draw_rect(rect.grow(-RING / 2.0), Palette.GOLD, false, RING)
