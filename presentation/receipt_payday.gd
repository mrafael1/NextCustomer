class_name ReceiptPayday
extends Control
## Payday's paycheck design on the receipt (left column v2, the user's call of 2026-11-09: "payday
## should have its own color"; a gold paper would mean two things, the PREMIUM laps' and the
## payday's): not a paper colour but a design, so it stays readable on the cream, silver and gold
## papers alike. Since the user's pick of 2026-11-10 (mock-up docs/art/mockups/payday_day.html,
## round 3's "Ribbon + foot") it is the screen's payday brass (PaydayTrim's mustard ramp) and has
## no side frame at all: the paper keeps its everyday width and nothing stands beside the hero
## number's € or the "over / short" line.
##
## This node is the PAYDAY ribbon across the paper's top, over the header (in the receipt's
## column, so the header moves down under it): a brass plate (the mustard body, a lit top row, a
## dark foot row) with swallowtail notches at both ends and PAYDAY in the chunky capitals in ink.
## On the paper's own canvas, over its metal and under its ink: a brass foot band in the torn
## tail's strip (draw_foot: a lit row on the paper's foot outline, the body down to the teeth,
## which ReceiptHang.draw_tail cuts in the dark brass, teeth_colour), so the design reaches the
## very end of the paper however long it is, and a faint € watermark behind the rows
## (draw_design), only when the paper has room for it under its header (planning's stub has
## none: nothing lies behind the hero number).
##
## On a GOLD paper (`on_gold`, ReceiptGold) brass would be lost: the ribbon takes the darkest
## brass with paper words (a lit mustard top row) and the foot band and teeth go one step down
## the ramp, as the mock-up's gold sheet does. Palette colours only (the watermark faded).
## Display only.

const WORDS := "PAYDAY"
## The ribbon: its rows (art px), the notches' depth, the words' top.
const ROWS := 11
const NOTCH := 4
const WORDS_TOP := 2
## The ribbon's plate: its body, its lit top row, its foot row and its words; then on gold.
const BAND := Palette.MUSTARD
const BAND_LIT := Palette.MUSTARD_LIGHT
const BAND_FOOT := Palette.MUSTARD_DARK
const WORDS_INK := Palette.INK
const GOLD_BAND := Palette.MUSTARD_DARKEST
const GOLD_BAND_LIT := Palette.MUSTARD
const GOLD_WORDS_INK := Palette.PAPER
## The foot band: its lit row (on the paper's foot outline), its body (the tail's strip) and the
## teeth; then on gold.
const FOOT_LIT := Palette.MUSTARD_LIGHT
const FOOT := Palette.MUSTARD
const TEETH := Palette.MUSTARD_DARK
const GOLD_FOOT := Palette.MUSTARD_DARK
const GOLD_TEETH := Palette.MUSTARD_DARKEST
## The watermark: the bold digits' €, WATERMARK_CELL px a font px, in the brass at
## WATERMARK_ALPHA (the dark brass at GOLD_WATERMARK_ALPHA on gold); centred under the header
## when the paper has WATERMARK_ROOM px there, else left out.
const WATERMARK := "€"
const WATERMARK_CELL := 6.0
const WATERMARK_INK := Palette.MUSTARD
const WATERMARK_ALPHA := 0.14
const GOLD_WATERMARK_INK := Palette.MUSTARD_DARK
const GOLD_WATERMARK_ALPHA := 0.3
const WATERMARK_ROOM := 56.0

## The paper is gold (ReceiptView tells it as it draws): the ribbon's dark look.
var on_gold: bool = false:
	set(value):
		if value == on_gold:
			return
		on_gold = value
		queue_redraw()


func _init() -> void:
	name = "PaydayRibbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(0.0, ROWS * ArtStyle.ART_SCALE)


## The ribbon's height (px).
static func height() -> float:
	return ROWS * ArtStyle.ART_SCALE


## The € watermark's rect on a paper `rect` whose header ends at `header_bottom` (the paper's y):
## centred on the room under the header, on the art grid; empty when that room is under
## WATERMARK_ROOM px (planning's stub: nothing lies behind the hero number).
static func watermark_rect(rect: Rect2, header_bottom: float) -> Rect2:
	var p: float = ArtStyle.ART_SCALE
	var room: Rect2 = Rect2(rect.position.x, header_bottom, rect.size.x, rect.end.y - header_bottom)
	if room.size.y < WATERMARK_ROOM:
		return Rect2()
	var mark: Vector2 = PixelWords.text_size(WATERMARK, PixelWords.Sheet.DIGITS, WATERMARK_CELL)
	var at: Vector2 = room.get_center() - mark / 2.0
	return Rect2((at / p).round() * p, mark)


## The faint € watermark (watermark_rect) on `item`'s canvas, in the dark brass when `gold`.
static func draw_design(
	item: CanvasItem, rect: Rect2, header_bottom: float, gold: bool = false
) -> void:
	var mark: Rect2 = watermark_rect(rect, header_bottom)
	if not mark.has_area():
		return
	var ink: Color = Color(WATERMARK_INK, WATERMARK_ALPHA)
	if gold:
		ink = Color(GOLD_WATERMARK_INK, GOLD_WATERMARK_ALPHA)
	_draw_glyph(item, mark.position, ink)


## The teeth's colour for ReceiptHang.draw_tail (the dark brass; a step darker on `gold`).
static func teeth_colour(gold: bool) -> Color:
	return GOLD_TEETH if gold else TEETH


## The brass foot band's rect on a paper `paper` px large (its own canvas): from its foot's
## outline row down the tail's strip to the teeth, between the ink sides.
static func foot_rect(paper: Vector2) -> Rect2:
	var p: float = ArtStyle.ART_SCALE
	return Rect2(p, paper.y - p, paper.x - 2.0 * p, (ReceiptHang.TAIL_MARGIN + 1) * p)


## The brass foot band on `item`'s canvas, over ReceiptHang.draw_tail's strip (its teeth are
## teeth_colour's): a lit row on the foot's outline, then the body down to the teeth; one step
## down the ramp on `gold`. On a `plain` paper (no metal) the paper's shade row over the band
## (the second row above it) is painted in `face`, so the band meets the paper cleanly.
static func draw_foot(
	item: CanvasItem, paper: Vector2, face: Color, gold: bool = false, plain: bool = false
) -> void:
	var p: float = ArtStyle.ART_SCALE
	var band: Rect2 = foot_rect(paper)
	if plain:
		var shade: Rect2 = Rect2(
			band.position.x, band.position.y - 2.0 * p, band.size.x - p, 2.0 * p
		)
		item.draw_rect(shade, face)
	item.draw_rect(band, GOLD_FOOT if gold else FOOT)
	var lit: Color = GOLD_FOOT if gold else FOOT_LIT
	item.draw_rect(Rect2(band.position, Vector2(band.size.x, p)), lit)


## The whole design on `paper`'s canvas (ReceiptView's draw, over its metal `metal` and under its
## ink), its header ending at `header_bottom`: the watermark, and with `hanging` the torn tail in
## its brass foot band. The ribbon follows the paper's gold.
func draw_paper(paper: Control, header_bottom: float, metal: ReceiptGold, hanging: bool) -> void:
	on_gold = metal.is_gold()
	draw_design(paper, Rect2(Vector2.ZERO, paper.size), header_bottom, on_gold)
	if not hanging:
		return
	var face: Color = metal.face_colour()
	ReceiptHang.draw_tail(paper, paper.size, face, teeth_colour(on_gold))
	draw_foot(paper, paper.size, face, on_gold, not on_gold and not metal.is_silver())


func _draw() -> void:
	var p: float = ArtStyle.ART_SCALE
	var columns: int = floori(size.x / p)
	if columns <= NOTCH * 2:
		return
	var half: int = floori(ROWS / 2.0)
	for row: int in range(ROWS):
		# The swallowtails: each end cut in a V, deepest on the ribbon's middle row.
		var cut: int = NOTCH - floori(absi(row - half) * NOTCH / float(half))
		draw_rect(Rect2(cut * p, row * p, (columns - 2 * cut) * p, p), row_colour(row))
	var words: Vector2 = PixelWords.text_size(WORDS, PixelWords.Sheet.CHUNKY_CAPS, p)
	var left: float = roundf((size.x - words.x) / 2.0 / p) * p
	_draw_words(Vector2(left, WORDS_TOP * p))


## Ribbon row `row`'s colour (0: its lit top row; the last one its foot row, on cream and silver).
func row_colour(row: int) -> Color:
	if on_gold:
		return GOLD_BAND_LIT if row == 0 else GOLD_BAND
	if row == 0:
		return BAND_LIT
	return BAND_FOOT if row == ROWS - 1 else BAND


## The words' ink now.
func words_ink() -> Color:
	return GOLD_WORDS_INK if on_gold else WORDS_INK


func _draw_words(at: Vector2) -> void:
	var p: float = ArtStyle.ART_SCALE
	var ink: Color = words_ink()
	var x: int = 0
	for character: String in WORDS:
		var rows: Array = PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY_CAPS)
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					draw_rect(Rect2(at + Vector2(x + column, row) * p, Vector2(p, p)), ink)
		x += (rows[0] as String).length() + PixelWords.GAP


static func _draw_glyph(item: CanvasItem, at: Vector2, ink: Color) -> void:
	var rows: Array = PixelWords.glyph_of(WATERMARK, PixelWords.Sheet.DIGITS)
	for row: int in range(rows.size()):
		var line: String = rows[row]
		for column: int in range(line.length()):
			if line[column] == "#":
				var cell: Vector2 = Vector2(column, row) * WATERMARK_CELL
				item.draw_rect(Rect2(at + cell, Vector2.ONE * WATERMARK_CELL), ink)
