class_name RoleTab
extends Control
## A price sticker's role tab (#128 batch polish, round 2 of 2026-11-19): the batch role a card's
## sticker starts with (CardText.sticker_tab: FIRST on Croissant, LAST on Stale doughnut), drawn
## as a small flag sitting on the ticket's top edge instead of in its text lines. Hard pixels: the
## word in the display font at its native size (ArtStyle.pixel_display_font, like a KeywordChip),
## cream on the role's family colour (GlyphText.ROLE_WORDS: the Bakery's shade, ROLE_DARKEN
## darker, the colour the role words take in the tips' text), in a BORDER px ink box with its top
## corner pixels cut. Its bottom border lies on the ticket's top outline (OVERLAP), so it reads
## as part of the ticket. It takes no pointer: the item under it keeps its hover and drag.
##
## On the belt the batch frames' band runs along the tickets' top, over the tickets: there the
## row's PriceLabelLayer (drawn after the frames) shows a twin of the tab (twin) at its place and
## hides the tab itself (set_covered), as it does a stuck price label.
##
## Broken (set_broken, the play test of 2026-11-19): the card's role did nothing at its place in
## the planned row (its WASTED step: a FIRST not first in its batch, a LAST not last). The tab
## turns grey, its word paler, with a small tomato cross (KeywordChip.CROSS_RUNS) after the word,
## and widens by the cross; the ticket's BATCH chip stays calm.

## Its height: from the rail strips' lane 0 body's foot (RailStrip.LANE_RECTS, 10 px over a
## natural row's tickets) down onto the ticket's outline.
const HEIGHT := 12.0
const BORDER := 2.0
const PADDING_X := 3.0
## The word's capitals: their top CAP_TOP under the tab's top.
const CAP_TOP := 3.0
## How far the tab comes down over the ticket: its bottom border on the ticket's outline.
const OVERLAP := 2.0
## How much darker than its family's shade the tab's face is (GlyphLabel.ROLE_DARKEN's look).
const ROLE_DARKEN := 0.3
const NAME := "RoleTab"
## A broken tab's face and word (set_broken).
const BROKEN_FACE := Palette.GREY
const BROKEN_INK := Palette.GREY_LIGHT
const CROSS_INK := Palette.TOMATO

## The role word it shows (a GlyphText.ROLE_WORDS key).
var word: String = ""
var _face: Color = Palette.INK
var _covered: bool = false
var _broken: bool = false


## The tab of `role_word`, its face in `palette`'s colour for the role's family.
func _init(role_word: String, palette: FamilyPalette) -> void:
	word = role_word
	name = NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_text_material(self)
	var families: FamilyPalette = palette if palette != null else FamilyPalette.shared()
	var style: FamilyStyle = families.style(str(GlyphText.ROLE_WORDS.get(role_word, "")))
	if style != null and style.has_ticket_colours():
		_face = style.shade.darkened(ROLE_DARKEN)
	size = Vector2(width_for(role_word), HEIGHT)


## A tab's width for `role_word` (wider by its cross when `broken`), on the art grid.
static func width_for(role_word: String, broken: bool = false) -> float:
	var text: float = (
		ArtStyle
		. pixel_display_font()
		. get_string_size(role_word, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE)
		. x
	)
	var width: float = BORDER * 2.0 + PADDING_X * 2.0 + ceilf(text)
	if broken:
		width += KeywordChip.CROSS_GAP + KeywordChip.CROSS_CELLS
	return ceilf(width / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## A copy of this tab (its word and face), for a layer that draws it over the frames.
func twin() -> RoleTab:
	var copy: RoleTab = RoleTab.new(word, null)
	copy._face = _face
	copy.set_broken(_broken)
	return copy


## Whether a layer draws its twin instead (it draws nothing then).
func set_covered(covered: bool) -> void:
	if covered != _covered:
		_covered = covered
		queue_redraw()


func is_covered() -> bool:
	return _covered


## Shows the tab broken (its role WASTED at its place) or whole again, resizing it.
func set_broken(broken: bool) -> void:
	if broken == _broken:
		return
	_broken = broken
	size = Vector2(width_for(word, broken), HEIGHT)
	queue_redraw()


func is_broken() -> bool:
	return _broken


## Its face's colour (the role's family colour, darkened; grey when broken).
func face_color() -> Color:
	return BROKEN_FACE if _broken else _face


## Its word's colour (paler grey when broken).
func ink_color() -> Color:
	return BROKEN_INK if _broken else Palette.CREAM


## The cross's cells (tab coordinates), CROSS_GAP after the word; none when whole.
func cross_rects() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	if not _broken:
		return cells
	var left: float = size.x - BORDER - PADDING_X - KeywordChip.CROSS_CELLS
	var top: float = floorf((HEIGHT - KeywordChip.CROSS_CELLS) / 2.0)
	for run: Vector3i in KeywordChip.CROSS_RUNS:
		cells.append(Rect2(left + run.x, top + run.y, run.z, 1.0))
	return cells


func _draw() -> void:
	if _covered:
		return
	# The ink box with its top corner pixels cut, then the face inside the border.
	draw_rect(Rect2(1, 0, size.x - 2.0, size.y), Palette.INK)
	draw_rect(Rect2(0, 1, size.x, size.y - 1.0), Palette.INK)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-BORDER), face_color())
	draw_string(
		ArtStyle.pixel_display_font(),
		Vector2(BORDER + PADDING_X, CAP_TOP + ArtStyle.PIXEL_CAP_HEIGHT),
		word,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ArtStyle.PIXEL_TEXT_SIZE,
		ink_color()
	)
	for cell: Rect2 in cross_rects():
		draw_rect(cell, CROSS_INK)
