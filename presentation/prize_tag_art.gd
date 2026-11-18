class_name PrizeTagArt
extends RefCounted
## A week medal's prize tag (v1.40, the user's verdict of 2026-11-18 on mock-up
## docs/art/mockups/medal_prizes.html, variant A): the small tag stapled to the receipt's foot when
## a checkout wins a medal, naming what the medal pays ("+1 DRAW" for the SILVER, "PREMIUM" for the
## GOLD: OvertimeWords). It is cut from the medal's own metal (MedalArt's ramps: steel, or gold)
## with the medal itself embossed on its left (MedalArt.draw_medal at MEDAL_CELLS), so the medal in
## the case, the tag and the receipt's metal read as one thing; an ink edge with clipped top
## corners, a lit top row and a shaded foot row, the prize in ink 3x5 capitals, and a steel staple
## over its top edge. Drawn on a grid of art px, `cell` px each (the receipt at ArtStyle.ART_SCALE;
## the machine's flying tag scales it). Palette colours only. Display only.

## The tag's height, the embossed medal's size and the gaps round the words (art px).
const HIGH := 9
const MEDAL_CELLS := 7
const EDGE := 1
const WORDS_GAP := 2
const WORDS_PAD := 2
## The staple: its ink bar over the tag's top edge (STAPLE_UP art px above it), its steel wire in
## the edge's row.
const STAPLE_SIZE := Vector2i(6, 2)
const STAPLE_UP := 1
## The shaded foot row's colours, [SILVER, GOLD] (the face is the metal's lit colour, MedalArt's,
## under a paper top row).
const FOOT: Array[Color] = [Palette.STEEL_LIGHT, Palette.GOLD]


## The prize medal `gold` pays, as the tag names it.
static func words(gold: bool) -> String:
	return OvertimeWords.GOLD_NAME if gold else OvertimeWords.SILVER_NAME


## The tag's size in art px (its staple's rise not counted).
static func cells(gold: bool) -> Vector2i:
	var wide: int = PixelWords.font_size_of(words(gold), PixelWords.Sheet.CAPS).x
	return Vector2i(EDGE + MEDAL_CELLS + WORDS_GAP + wide + WORDS_PAD + EDGE, HIGH)


## The tag's size in px at a `cell` px art px.
static func size_of(gold: bool, cell: float) -> Vector2:
	return Vector2(cells(gold)) * cell


## The embossed medal's rect in the tag (px from its top left).
static func medal_rect(cell: float) -> Rect2:
	return Rect2(Vector2(EDGE, EDGE) * cell, Vector2.ONE * MEDAL_CELLS * cell)


## The words' rect in the tag (px from its top left).
static func words_rect(gold: bool, cell: float) -> Rect2:
	var font: Vector2i = PixelWords.font_size_of(words(gold), PixelWords.Sheet.CAPS)
	var at: Vector2 = Vector2(EDGE + MEDAL_CELLS + WORDS_GAP, (HIGH - font.y) / 2.0)
	return Rect2(at * cell, Vector2(font) * cell)


## Draws medal `gold`'s tag on `item`, its top left at `origin`, `cell` px per art px; `stapled`
## adds the staple over its top edge.
static func draw(
	item: CanvasItem, origin: Vector2, gold: bool, cell: float, stapled: bool = true
) -> void:
	var metal: Array[Color] = MedalArt.metal(gold)
	var grid: Vector2i = cells(gold)
	var size: Vector2 = Vector2(grid) * cell
	# The ink edge with its top corners clipped, then the face inside it.
	item.draw_rect(
		Rect2(origin + Vector2(cell, 0), Vector2(size.x - 2.0 * cell, cell)), Palette.INK
	)
	item.draw_rect(Rect2(origin + Vector2(0, cell), Vector2(size.x, size.y - cell)), Palette.INK)
	var face: Rect2 = Rect2(origin + Vector2.ONE * cell, size - Vector2.ONE * 2.0 * cell)
	item.draw_rect(face, metal[0])
	item.draw_rect(Rect2(face.position, Vector2(face.size.x, cell)), Palette.PAPER)
	item.draw_rect(
		Rect2(face.position + Vector2(0, face.size.y - cell), Vector2(face.size.x, cell)),
		FOOT[1 if gold else 0]
	)
	MedalArt.draw_medal(item, origin + medal_rect(cell).position, MEDAL_CELLS, cell, gold)
	_draw_words(item, origin + words_rect(gold, cell).position, words(gold), cell)
	if stapled:
		var staple: Vector2 = Vector2(STAPLE_SIZE) * cell
		var at: Vector2 = (
			origin + Vector2(roundf((grid.x - STAPLE_SIZE.x) / 2.0), -STAPLE_UP) * cell
		)
		item.draw_rect(Rect2(at, staple), Palette.INK)
		item.draw_rect(
			Rect2(at + Vector2.ONE * cell, staple - Vector2(2.0, 1.0) * cell), Palette.STEEL_LIGHT
		)


## `text` in ink 3x5 capitals from `at`, a font px `cell` px.
static func _draw_words(item: CanvasItem, at: Vector2, text: String, cell: float) -> void:
	var x: int = 0
	for character: String in text:
		var rows: Array = PixelWords.glyph_of(character, PixelWords.Sheet.CAPS)
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					var pixel: Vector2 = at + Vector2(x + column, row) * cell
					item.draw_rect(Rect2(pixel, Vector2(cell, cell)), Palette.INK)
		x += (rows[0] as String).length() + PixelWords.GAP
