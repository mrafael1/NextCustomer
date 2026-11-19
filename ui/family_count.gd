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
## It is a chip of the Cart page's tag line (glyph at 2x; the Run info's big TILE look went with
## the Run info page, 2026-11-19). A family with no ticket colours (the coupon mark) gets the grey
## bar.

const BORDER := 2.0
## The chip's height, the count's size, the room inside the border and the glyph-count gap.
const CHIP_HEIGHT := 24.0
const CHIP_NUMBER_SIZE := 18
const CHIP_PADDING := 6.0
const CHIP_GAP := 5.0
## The colour bar along a chip's foot, inside the border.
const CHIP_BAR := 3.0
const TIP := "%s · %d in your cart"
## The paper inside a lit (previewed) and a pinned box, and a pinned box's sunk edge (SINK px).
const LIT_FILL := Palette.MUSTARD_PALE
const PINNED_FILL := Palette.MUSTARD_LIGHT
const SINK_COLOR := Palette.MUSTARD_DARK
const SINK := 2.0
## Node names (for tests).
const COUNT_NAME := "Count"
const ICON_NAME := "FamilyIcon"

## The count it shows.
var count: int = 0
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


## A chip for `count` cards of `style`'s family.
func _init(style: FamilyStyle, family_count: int) -> void:
	super(style)
	count = family_count
	name = "Count%s" % style.id
	tip_text = TIP % [style.display_name, family_count]
	_band = style.face if style.has_ticket_colours() else Palette.GREY_LIGHT
	# The glyph and the box are drawn by the children and _draw, not by this TextureRect.
	texture = null
	material = null
	_icon = UiKit.sprite(style.glyph)
	_icon.name = ICON_NAME
	_icon.size = Vector2.ONE * float(ArtStyle.FAMILY_GLYPH_SIZE)
	add_child(_icon)
	_number = UiKit.number_label(str(family_count), CHIP_NUMBER_SIZE, false)
	_number.name = COUNT_NAME
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)
	var wanted: Vector2 = Vector2(chip_width(family_count), CHIP_HEIGHT)
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


## The count's label and the glyph, for tests.
func count_label() -> Label:
	return _number


func icon() -> TextureRect:
	return _icon


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
	_icon.position = Vector2(
		BORDER + CHIP_PADDING, roundf((size.y - CHIP_BAR - _icon.size.y) / 2.0)
	)
	_number.position = Vector2(_icon.position.x + _icon.size.x + CHIP_GAP, 0)
	_number.size = Vector2(digits.x, size.y - CHIP_BAR)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	# The ink box with its corner pixels cut, paper inside, the family's colour on its edge.
	draw_rect(Rect2(1, 0, rect.size.x - 2, rect.size.y), Palette.INK)
	draw_rect(Rect2(0, 1, rect.size.x, rect.size.y - 2), Palette.INK)
	var inside: Rect2 = rect.grow(-BORDER)
	draw_rect(inside, fill_color())
	if pinned:
		# Sunk: a darker edge along the top and the left.
		draw_rect(Rect2(inside.position, Vector2(inside.size.x, SINK)), SINK_COLOR)
		draw_rect(Rect2(inside.position, Vector2(SINK, inside.size.y)), SINK_COLOR)
	draw_rect(Rect2(inside.position.x, inside.end.y - CHIP_BAR, inside.size.x, CHIP_BAR), _band)
