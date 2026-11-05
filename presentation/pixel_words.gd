class_name PixelWords
extends Control
## Words drawn from a pixel sheet, each font pixel a `cell` px square (mock-up
## docs/art/mockups/shift_scene_polish_v4.html, its pixel sheets): the 6x8 bold digits with
## their € (DIGITS, TODAY'S TARGET's number on the receipt: 72 px tall at 1920x1080 with a 6 px
## cell, 2-art-px stems) and the 3x5 capitals (CAPS, the name badge's NEXT / CUSTOMER at a 2 px
## cell, one art px per font px), and the machine's chunky price-gun digits (CHUNKY, v0.98, A2 of
## mock-up docs/art/mockups/machine_relook_v2.html: 6x8, 2 px strokes, with € % + − × / . <,
## read from art/fonts/chunky_digits.png, built from art/src/fonts/chunky_digits.txt; an ASCII
## '-' prints as its −). A cell that is a multiple of the art's 2 px keeps the words on the art's
## grid. CHUNKY_CAPS (v0.99) are the chunky digits' capitals for the machine's display and prize
## bay header words (6x8, 2 px stems: A to Z, ! ? ·, read from art/fonts/chunky_caps.png, built
## from art/src/fonts/chunky_caps.txt; a small letter prints as its capital). Its minimum size
## is the words' (text_size()); it draws them from its top left, with no line or glyph padding,
## and an optional `shadow` colour one font px down and right under them. A character the sheet
## lacks draws as a blank. Display only.
## The 4x7 digits (SMALL_DIGITS, mock-up shift_scene_polish_v5_tickets.html's MID sheet) and the
## "k" of DIGITS and SMALL_DIGITS print a ticket's price window when a 6x8 price would not fit it
## (PriceWindow).

enum Sheet { DIGITS, CAPS, CHUNKY, CHUNKY_CAPS, SMALL_DIGITS }

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
	"k": ["##....", "##....", "##..##", "##.##.", "####..", "##.##.", "##..##", "##..##"],
	" ": ["...", "...", "...", "...", "...", "...", "...", "..."],
}
## The chunky digits' sheet: one CHUNKY_CELL-wide cell per character of CHUNKY_ORDER, each
## glyph's ink left-aligned in its cell (cropped to its ink); a space advances CHUNKY_SPACE.
const CHUNKY_SHEET := preload("res://art/fonts/chunky_digits.png")
const CHUNKY_ORDER := "0123456789€%+−×/.<"
const CHUNKY_CELL := 8
const CHUNKY_SPACE := 3
## The chunky capitals' sheet, read as the digits' (CHUNKY_CELL-wide cells, CHUNKY_SPACE spaces).
const CHUNKY_CAPS_SHEET := preload("res://art/fonts/chunky_caps.png")
const CHUNKY_CAPS_ORDER := "ABCDEFGHIJKLMNOPQRSTUVWXYZ!?·"
## The 4x7 digits, their € and "k" (the v5 mock-up's MID sheet), '#' ink.
const SMALL_DIGIT_GLYPHS: Dictionary[String, Array] = {
	"0": [".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
	"1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
	"2": [".##.", "#..#", "...#", "..#.", ".#..", "#...", "####"],
	"3": ["###.", "...#", "...#", ".##.", "...#", "...#", "###."],
	"4": ["..#.", ".##.", "#.#.", "#.#.", "####", "..#.", "..#."],
	"5": ["####", "#...", "###.", "...#", "...#", "#..#", ".##."],
	"6": [".##.", "#...", "###.", "#..#", "#..#", "#..#", ".##."],
	"7": ["####", "...#", "..#.", "..#.", ".#..", ".#..", ".#.."],
	"8": [".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##."],
	"9": [".##.", "#..#", "#..#", ".###", "...#", "...#", ".##."],
	"€": ["..##", ".#..", "####", ".#..", "###.", ".#..", "..##"],
	"k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"],
	" ": ["..", "..", "..", "..", "..", "..", ".."],
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

static var _chunky: Dictionary[String, Array] = {}
static var _chunky_caps: Dictionary[String, Array] = {}

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
## Drawn one font px down and right under the words (clear: none).
var shadow: Color = Color(0, 0, 0, 0):
	set(value):
		shadow = value
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
	if shadow.a > 0.0:
		_draw_words(Vector2.ONE * cell, shadow)
	_draw_words(Vector2.ZERO, color)


func _draw_words(offset: Vector2, ink: Color) -> void:
	var glyphs: Dictionary[String, Array] = _glyphs(sheet)
	var x: int = 0
	for character: String in text:
		var rows: Array = _glyph(glyphs, character)
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					var at: Vector2 = Vector2(x + column, row) * cell + offset
					draw_rect(Rect2(at, Vector2(cell, cell)), ink)
		x += (rows[0] as String).length() + GAP


static func _glyphs(from: Sheet) -> Dictionary[String, Array]:
	match from:
		Sheet.DIGITS:
			return DIGIT_GLYPHS
		Sheet.CHUNKY:
			return chunky_glyphs()
		Sheet.CHUNKY_CAPS:
			return chunky_caps_glyphs()
		Sheet.SMALL_DIGITS:
			return SMALL_DIGIT_GLYPHS
	return CAPS_GLYPHS


## The chunky digits' glyphs ('#' ink), read once from CHUNKY_SHEET: each cell cropped to its ink.
static func chunky_glyphs() -> Dictionary[String, Array]:
	if _chunky.is_empty():
		_read_sheet(CHUNKY_SHEET, CHUNKY_ORDER, _chunky)
	return _chunky


## The chunky capitals' glyphs ('#' ink), read once from CHUNKY_CAPS_SHEET, as the digits'.
static func chunky_caps_glyphs() -> Dictionary[String, Array]:
	if _chunky_caps.is_empty():
		_read_sheet(CHUNKY_CAPS_SHEET, CHUNKY_CAPS_ORDER, _chunky_caps)
	return _chunky_caps


## Fills `into` with `sheet`'s glyphs, one CHUNKY_CELL-wide cell per character of `order`, each
## cropped to its ink, and a CHUNKY_SPACE blank for the space.
static func _read_sheet(
	sheet_texture: Texture2D, order: String, into: Dictionary[String, Array]
) -> void:
	var image: Image = sheet_texture.get_image()
	if image.is_compressed():
		image.decompress()
	var rows: int = image.get_height()
	for index: int in range(order.length()):
		var left: int = index * CHUNKY_CELL
		var width: int = 0
		var glyph: Array[String] = []
		for y: int in range(rows):
			var line: String = ""
			for x: int in range(CHUNKY_CELL):
				var inked: bool = image.get_pixel(left + x, y).a > 0.5
				line += "#" if inked else "."
				if inked:
					width = maxi(width, x + 1)
			glyph.append(line)
		for y: int in range(rows):
			glyph[y] = glyph[y].left(width)
		into[order[index]] = glyph
	var blank: Array[String] = []
	for y: int in range(rows):
		blank.append(".".repeat(CHUNKY_SPACE))
	into[" "] = blank


static func _glyph(glyphs: Dictionary[String, Array], character: String) -> Array:
	if character == "-" and glyphs.has("−"):
		return glyphs["−"]
	if not glyphs.has(character) and glyphs.has(character.to_upper()):
		return glyphs[character.to_upper()]
	return glyphs.get(character, glyphs[" "])
