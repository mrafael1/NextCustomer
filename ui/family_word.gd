class_name FamilyWord
extends TipTarget
## A family written in a ticket's rule (tickets v5, the mock-up's works-with chip): the family's
## name on a chip in its ticket colours (FamilyStyle: its light top row, its face, its shade foot
## row, corners cut), in the rule's own font and size, paper or ink as the family reads. It says
## what the item works with, so it differs from the icon label's glyphs (what the item is). Its
## tip says so ("Works with Breakfast"), and while it shows PlanningEffects lights the family's
## items, as a glyph's tip does. It takes no clicks.

## The name's room inside the chip on each side, and the chip's height (7 art px).
const PADDING_X := 3.0
const HEIGHT := 14.0
const WORKS_WITH := "Works with %s"

## The family it names (a FamilyStyle id).
var family: String = ""
var _style: FamilyStyle
var _font: Font
var _font_size: int
var _baseline: float = 11.0


## The chip of `style`'s name in `font` at `font_size`.
func _init(style: FamilyStyle, font: Font, font_size: int) -> void:
	super()
	_style = style
	family = style.id
	_font = font
	_font_size = font_size
	name = "Word%s" % style.id
	tip_text = WORKS_WITH % style.display_name
	size = Vector2(width_for(style, font, font_size), HEIGHT)
	custom_minimum_size = size


## The chip's width for `style`'s name: the name plus PADDING_X on each side, on the 2 px grid.
static func width_for(style: FamilyStyle, font: Font, font_size: int) -> float:
	var text: float = (
		font.get_string_size(_name_of(style), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	return ceilf((text + 2.0 * PADDING_X) / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## The name's colour: paper on a dark family's face, else ink.
func ink_color() -> Color:
	return Palette.PAPER if _style.paper_text else Palette.INK


func face_color() -> Color:
	return _style.face


## Draws the chip with the name's baseline at `baseline` (this chip's coordinates).
func draw_at(baseline: float) -> void:
	_baseline = baseline
	queue_redraw()


func _draw() -> void:
	var px: float = ArtStyle.ART_SCALE
	var face: Color = _style.face if _style.has_ticket_colours() else Palette.CREAM_SHADE
	var light: Color = _style.light if _style.has_ticket_colours() else Palette.PAPER
	var shade: Color = _style.shade if _style.has_ticket_colours() else Palette.CREAM_DARKEST
	draw_rect(Rect2(px, 0, size.x - 2.0 * px, px), light)
	draw_rect(Rect2(0, px, size.x, size.y - 2.0 * px), face)
	draw_rect(Rect2(px, size.y - px, size.x - 2.0 * px, px), shade)
	draw_string(
		_font,
		Vector2(PADDING_X, _baseline),
		_name_of(_style),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size,
		ink_color()
	)


static func _name_of(style: FamilyStyle) -> String:
	return style.display_name if not style.display_name.is_empty() else style.id
