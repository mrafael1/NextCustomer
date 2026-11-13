class_name TipTitle
extends Control
## A hover tip's title (the hover tips revamp, design B): its words in the chunky capitals
## (PixelWords CHUNKY_CAPS for the letters and ! ? · ' ,, CHUNKY for the digits and € % + − × / .),
## each font px a `cell` px square, in `color`. A title wider than `width` breaks at its spaces onto
## more lines, LINE_GAP font px apart. Display only.

const ROWS := 8
const LINE_GAP := 2
## The characters the digits' sheet draws (PixelWords.CHUNKY_ORDER, and an ASCII '-').
const DIGIT_CHARS := "0123456789€%+−×/.<-"

var text: String = ""
var color: Color = Palette.INK
var cell: float = 2.0
var _lines: PackedStringArray = PackedStringArray()


func _init(words: String, ink: Color, room: float, cell_px: float = 2.0) -> void:
	name = "TipTitle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = words.to_upper()
	color = ink
	cell = cell_px
	_lines = _wrap(text, room)
	var widest: float = 0.0
	for line: String in _lines:
		widest = maxf(widest, width_of(line, cell))
	size = Vector2(widest, (_lines.size() * (ROWS + LINE_GAP) - LINE_GAP) * cell)
	custom_minimum_size = size


## `words`' width at `cell_px` (font px of its glyphs, one between each).
static func width_of(words: String, cell_px: float) -> float:
	var width: int = 0
	for character: String in words:
		width += (_glyph(character)[0] as String).length() + PixelWords.GAP
	return maxf(width - PixelWords.GAP, 0) * cell_px


func line_count() -> int:
	return _lines.size()


func _wrap(words: String, room: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in words.split(" ", false):
		var tried: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and width_of(tried, cell) > room:
			lines.append(line)
			line = word
		else:
			line = tried
	if not line.is_empty():
		lines.append(line)
	return lines


func _draw() -> void:
	for index: int in range(_lines.size()):
		var x: int = 0
		var top: float = index * (ROWS + LINE_GAP) * cell
		for character: String in _lines[index]:
			var rows: Array = _glyph(character)
			for row: int in range(rows.size()):
				var line: String = rows[row]
				for column: int in range(line.length()):
					if line[column] == "#":
						var at: Vector2 = Vector2((x + column) * cell, top + row * cell)
						draw_rect(Rect2(at, Vector2(cell, cell)), color)
			x += (rows[0] as String).length() + PixelWords.GAP


static func _glyph(character: String) -> Array:
	if DIGIT_CHARS.contains(character):
		return PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY)
	return PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY_CAPS)
