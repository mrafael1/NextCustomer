class_name FamilyWord
extends TipTarget
## A family written in a ticket's rule (tickets v5, the mock-up's works-with chip): the family's
## name on a chip. It says what the item works with, so it differs from the icon label's glyphs
## (what the item is). Its tip says so ("Works with Breakfast"); on the belt PlanningEffects adds
## what the rule counts there (RuleReach: "counts Cereal (4)", or that nothing matches) and lights
## only those items. It takes no clicks.
##
## One chip style everywhere (main scene v2, 2026-11-08): drawn as a keyword chip (KeywordChip),
## an ink box with its corner pixels cut, paper inside, a round dot in the family's colour (its
## FamilyStyle face) after the left border, then the name in capitals in the chips' pixel display
## font, KeywordChip.HEIGHT tall. (`font` and `font_size`, the rule's own, are kept for the
## callers' run layout but no longer draw the name.)

## The name's room after it inside the border, and the chip's height (a keyword chip's).
const PADDING_X := KeywordChip.PADDING_X
const HEIGHT := KeywordChip.HEIGHT
const WORKS_WITH := "Works with %s"

## The family it names (a FamilyStyle id).
var family: String = ""
var _style: FamilyStyle
var _baseline: float = 0.0


## The chip of `style`'s name in `font` at `font_size`.
func _init(style: FamilyStyle, font: Font, font_size: int) -> void:
	super()
	_style = style
	family = style.id
	name = "Word%s" % style.id
	# The name is hard pixel text drawn at 1x, as a keyword chip's.
	ArtStyle.use_pixel_text_material(self)
	tip_text = WORKS_WITH % style.display_name
	size = Vector2(width_for(style, font, font_size), HEIGHT)
	custom_minimum_size = size
	_baseline = baseline_for(font, font_size)


## The chip's width for `style`'s name: a keyword chip's with its dot, on the 2 px grid.
static func width_for(
	style: FamilyStyle, _font_unused: Font = null, _size_unused: int = 0
) -> float:
	var text: float = (
		KeywordChip
		. font()
		. get_string_size(_name_of(style), HORIZONTAL_ALIGNMENT_LEFT, -1, KeywordChip.text_size())
		. x
	)
	var width: float = (
		KeywordChip.BORDER * 2.0 + KeywordChip.DOT_LEAD + KeywordChip.DOT + KeywordChip.DOT_GAP
	)
	width += ceilf(text) + PADDING_X
	return ceilf(width / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## The family's name as the chip writes it.
func display_name() -> String:
	return _name_of(_style)


## The name's colour: ink on the paper face.
func ink_color() -> Color:
	return Palette.INK


## The chip's face (paper, as every chip's), and its dot's colour (the family's face).
func face_color() -> Color:
	return KeywordChip.CALM_FACE


func dot_color() -> Color:
	return _style.face


## The dot's rect (this chip's coordinates).
func dot_rect() -> Rect2:
	var at: Vector2 = Vector2(KeywordChip.BORDER + KeywordChip.DOT_LEAD, KeywordChip.DOT_TOP)
	return Rect2(at, Vector2.ONE * KeywordChip.DOT)


## The name's baseline in a chip (its coordinates): a keyword chip's (KeywordChip.CAP_TOP).
static func baseline_for(_font_unused: Font = null, _size_unused: int = 0) -> float:
	return KeywordChip.CAP_TOP + ArtStyle.PIXEL_CAP_HEIGHT


## The name's baseline (this chip's coordinates).
func baseline() -> float:
	return _baseline


func _draw() -> void:
	draw_rect(Rect2(1, 0, size.x - 2, size.y), Palette.INK)
	draw_rect(Rect2(0, 1, size.x, size.y - 2), Palette.INK)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-KeywordChip.BORDER), face_color())
	var dot: Rect2 = dot_rect()
	KeywordChip.draw_dot(self, dot.position, dot_color())
	draw_string(
		KeywordChip.font(),
		Vector2(dot.end.x + KeywordChip.DOT_GAP, _baseline),
		_name_of(_style),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		KeywordChip.text_size(),
		ink_color()
	)


static func _name_of(style: FamilyStyle) -> String:
	return (style.display_name if not style.display_name.is_empty() else style.id).to_upper()
