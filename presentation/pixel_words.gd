class_name PixelWords
extends Control
## Words drawn from a pixel sheet, each font pixel a `cell` px square (mock-up
## docs/art/mockups/shift_scene_polish_v4.html, its pixel sheets): the 6x8 bold digits with
## their € (DIGITS, TODAY'S TARGET's number on the receipt: 72 px tall at 1920x1080 with a 6 px
## cell, 2-art-px stems) and the 3x5 capitals (CAPS, the name badge's NEXT / CUSTOMER at a 2 px
## cell, one art px per font px). A cell that is a multiple of the art's 2 px keeps the words on
## the art's grid. Its minimum size is the words' (text_size()); it draws them from its top left,
## with no line or glyph padding. A character the sheet lacks draws as a blank. Display only.

enum Sheet { DIGITS, CAPS }

## One font pixel between two characters.
const GAP := 1
## The 6x8 bold digits and their € (the mock-up's BIG sheet), '#' ink.
const DIGIT_GLYPHS: Dictionary[String, Array] = {
	"0": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"1": [".##.", "###.", ".##.", ".##.", ".##.", ".##.", ".##.", "####"],
	"2": [".####.", "##..##", "....##", "...##.", "..##..", ".##...", "##....", "######"],
	"3": ["#####.", "....##", "....##", ".####.", "....##", "....##", "....##", "#####."],
	"4": ["...##.", "..###.", ".####.", "##.##.", "##.##.", "######", "...##.", "...##."],
	"5": ["######", "##....", "#####.", "....##", "....##", "....##", "##..##", ".####."],
	"6": [".####.", "##....", "##....", "#####.", "##..##", "##..##", "##..##", ".####."],
	"7": ["######", "....##", "...##.", "...##.", "..##..", "..##..", "..##..", "..##.."],
	"8": [".####.", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####."],
	"9": [".####.", "##..##", "##..##", "##..##", ".#####", "....##", "....##", ".####."],
	"€": ["..####", ".##...", "#####.", ".##...", "####..", ".##...", ".##...", "..####"],
	" ": ["...", "...", "...", "...", "...", "...", "...", "..."],
}
## The 3x5 capitals (the mock-up's CAPS sheet), '#' ink.
const CAPS_GLYPHS: Dictionary[String, Array] = {
	"A": [".#.", "#.#", "###", "#.#", "#.#"],
	"B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"],
	"D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"],
	"F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"],
	"H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["#", "#", "#", "#", "#"],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
	"L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."],
	"P": ["##.", "#.#", "##.", "#..", "#.."],
	"R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"],
	"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
	"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
	" ": [".", ".", ".", ".", "."],
}

## The words, the sheet they are drawn from, a font pixel's size (px) and their colour.
var text: String = "":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()
var sheet: Sheet = Sheet.DIGITS:
	set(value):
		sheet = value
		update_minimum_size()
		queue_redraw()
var cell: float = 2.0:
	set(value):
		cell = value
		update_minimum_size()
		queue_redraw()
var color: Color = Palette.INK:
	set(value):
		color = value
		queue_redraw()


func _init(
	words: String = "", from: Sheet = Sheet.DIGITS, cell_px: float = 2.0, ink: Color = Palette.INK
) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = words
	sheet = from
	cell = cell_px
	color = ink


## The words' size in font pixels: their glyphs' widths with GAP between, by the sheet's height.
static func font_size_of(words: String, from: Sheet) -> Vector2i:
	var glyphs: Dictionary[String, Array] = _glyphs(from)
	var width: int = 0
	for character: String in words:
		width += _glyph(glyphs, character)[0].length() + GAP
	var rows: int = (glyphs[" "] as Array).size()
	return Vector2i(maxi(width - GAP, 0), rows)


## The words' size in px at a `cell_px` font pixel.
static func text_size(words: String, from: Sheet, cell_px: float) -> Vector2:
	return Vector2(font_size_of(words, from)) * cell_px


func _get_minimum_size() -> Vector2:
	return text_size(text, sheet, cell)


func _draw() -> void:
	var glyphs: Dictionary[String, Array] = _glyphs(sheet)
	var x: int = 0
	for character: String in text:
		var rows: Array = _glyph(glyphs, character)
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					draw_rect(Rect2(Vector2(x + column, row) * cell, Vector2(cell, cell)), color)
		x += (rows[0] as String).length() + GAP


static func _glyphs(from: Sheet) -> Dictionary[String, Array]:
	return DIGIT_GLYPHS if from == Sheet.DIGITS else CAPS_GLYPHS


static func _glyph(glyphs: Dictionary[String, Array], character: String) -> Array:
	return glyphs.get(character, glyphs[" "])
