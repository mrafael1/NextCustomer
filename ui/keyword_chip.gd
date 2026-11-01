class_name KeywordChip
extends TipTarget
## A keyword on a sticker line (#128, the approved Bound strip mock-up): the word ("BATCH") boxed
## like a family glyph's chip, in the display font as hard pixels (ArtStyle.pixel_display_font at
## its native PIXEL_TEXT_SIZE), ink on the Bakery's light cream (Palette.CREAM_SHADE) in a BORDER
## px ink box with its corner pixels cut. Resting the pointer on it shows the keyword's tooltip
## (GlyphText.keyword_tip, through GlyphTips) and lights it mustard while the tip shows (and
## PlanningEffects lights its batch's frame on the belt).
##
## Wasted (set_wasted, #128 "wrong job"): the card's batch line did nothing in the planned row; the
## chip turns tomato with paper text and a crisp pixel cross after the word, and its tooltip gives
## the same reason as its WASTED step instead. It takes no clicks: the item under it keeps its
## hover, drag and clicks.

const HEIGHT := 15.0
const BORDER := 2.0
## The word's room on each side inside the border.
const PADDING_X := 3.0
## The word's capitals: their top CAP_TOP under the chip's top.
const CAP_TOP := 4.0
## The cross after a wasted chip's word: CROSS_CELLS square, one canvas px a cell, CROSS_GAP after
## the word.
const CROSS_CELLS := 6
const CROSS_GAP := 3.0
## The cross's pixels (the mock-up's 6x6 X), as [column, row, width] runs.
const CROSS_RUNS: Array[Vector3i] = [
	Vector3i(0, 0, 2),
	Vector3i(4, 0, 2),
	Vector3i(1, 1, 2),
	Vector3i(3, 1, 2),
	Vector3i(2, 2, 2),
	Vector3i(2, 3, 2),
	Vector3i(1, 4, 2),
	Vector3i(3, 4, 2),
	Vector3i(0, 5, 2),
	Vector3i(4, 5, 2),
]
const CALM_FACE := Palette.CREAM_SHADE
const LIT_FACE := Palette.MUSTARD
const WASTED_FACE := Palette.TOMATO

## The keyword it shows (a GlyphText.KEYWORD_TIPS key).
var keyword: String = ""
var _lit: bool = false
var _wasted: bool = false


## The chip of `word`, wasted (`wasted_tip`: its tooltip, the WASTED step's reason) when not empty.
func _init(word: String, wasted_tip: String = "") -> void:
	super()
	keyword = word
	name = "Keyword%s" % word.capitalize()
	_wasted = not wasted_tip.is_empty()
	tip_text = wasted_tip if _wasted else GlyphText.keyword_tip(word)
	size = Vector2(width_for(word, _wasted), HEIGHT)
	custom_minimum_size = size


## A chip's width for `word` (wider by its cross when `wasted`), on the 2 px grid.
static func width_for(word: String, wasted: bool) -> float:
	var text: float = font().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size()).x
	var width: float = BORDER * 2.0 + PADDING_X * 2.0 + ceilf(text)
	if wasted:
		width += CROSS_GAP + CROSS_CELLS
	return ceilf(width / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


static func font() -> Font:
	return ArtStyle.pixel_display_font()


static func text_size() -> int:
	return ArtStyle.PIXEL_TEXT_SIZE


## Lights the chip (its tooltip shows) or puts it back.
func set_lit(lit: bool) -> void:
	if _lit == lit:
		return
	_lit = lit
	queue_redraw()


func is_lit() -> bool:
	return _lit


## Whether its card's batch line is wasted in the planned row (tomato, with a cross).
func is_wasted() -> bool:
	return _wasted


## Its face's colour now: calm cream, lit mustard, or tomato when wasted.
func face_color() -> Color:
	if _wasted:
		return WASTED_FACE
	return LIT_FACE if _lit else CALM_FACE


## Its word's (and cross's) colour: ink, paper on a wasted chip.
func ink_color() -> Color:
	return Palette.PAPER if _wasted else Palette.INK


## The cross's rect (this chip's coordinates), or an empty rect for a chip that isn't wasted.
func cross_rect() -> Rect2:
	if not _wasted:
		return Rect2()
	var left: float = size.x - BORDER - PADDING_X - CROSS_CELLS
	var top: float = roundf((size.y - CROSS_CELLS) / 2.0)
	return Rect2(left, top, CROSS_CELLS, CROSS_CELLS)


func tip_shown(shown: bool) -> void:
	set_lit(shown)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	# The ink box with its corner pixels cut, then the face inside the border.
	draw_rect(Rect2(1, 0, rect.size.x - 2, rect.size.y), Palette.INK)
	draw_rect(Rect2(0, 1, rect.size.x, rect.size.y - 2), Palette.INK)
	draw_rect(rect.grow(-BORDER), face_color())
	var text_font: Font = font()
	var baseline: float = CAP_TOP + ArtStyle.PIXEL_CAP_HEIGHT
	draw_string(
		text_font,
		Vector2(BORDER + PADDING_X, baseline),
		keyword,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		text_size(),
		ink_color()
	)
	var cross: Rect2 = cross_rect()
	if cross.has_area():
		for run: Vector3i in CROSS_RUNS:
			draw_rect(Rect2(cross.position + Vector2(run.x, run.y), Vector2(run.z, 1)), ink_color())
