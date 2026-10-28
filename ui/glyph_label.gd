class_name GlyphLabel
extends Control
## Sticker text with its family names drawn as glyphs (#105, mock-up readability v3, rich()): the
## text's pieces (GlyphText.pieces) flow into lines `width` wide, a line pitch apart, a line
## breaking only between pieces (a glyph never starts a line alone). Text runs are drawn in
## `font`; each family glyph is a FamilyGlyph, ArtStyle.FAMILY_GLYPH_SIZE square with
## GLYPH_MARGIN on each side, its foot GLYPH_DROP under the line's baseline (the mock-up's
## vertical-align -4px), with a paper rim on a ticket (`rimmed`). The first line can keep clear of
## something at its right (set_first_inset: the ticket's struck price). At most `max_lines` lines
## show (0: any number); fits() says whether every piece did. Display only.

## A glyph's room on its line: its margin each side.
const GLYPH_MARGIN := 1.0
## How far a glyph's foot sits under the line's baseline.
const GLYPH_DROP := 4.0

var text: String = ""
var _font: Font
var _font_size: int
var _color: Color
var _pitch: float
var _width: float
var _max_lines: int
var _rimmed: bool
var _first_inset: float = 0.0
var _palette: FamilyPalette
## Each shown line's runs: {"text", "family", "x"} (x from the line's left).
var _lines: Array[Array] = []
var _needed_lines: int = 0
var _glyphs: Array[FamilyGlyph] = []
var _tip_below: bool = false
var _tip_anchor: Control


## `line` in `font` at `text_size` and `text_color`, `line_pitch` px a line, wrapped at `width`.
## `palette` names the glyphs (the game's when null).
func _init(
	line: String,
	font: Font,
	text_size: int,
	text_color: Color,
	line_pitch: float,
	width: float,
	max_lines: int = 0,
	rimmed: bool = false,
	palette: FamilyPalette = null
) -> void:
	text = line
	_font = font
	_font_size = text_size
	_color = text_color
	_pitch = line_pitch
	_width = width
	_max_lines = max_lines
	_rimmed = rimmed
	_palette = palette if palette != null else FamilyPalette.shared()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay_out()


## Keeps the first line `inset` px clear of the right edge (0: the full width).
func set_first_inset(inset: float) -> void:
	if is_equal_approx(inset, _first_inset):
		return
	_first_inset = inset
	_lay_out()


## The glyphs' tooltips open below `anchor` (a ticket) when `below`, else above each glyph.
func set_tip(below: bool, anchor: Control) -> void:
	_tip_below = below
	_tip_anchor = anchor
	for glyph: FamilyGlyph in _glyphs:
		glyph.tip_below = below
		glyph.tip_anchor = anchor


## The text's colour (a ticket's ink or paper).
func set_color(new_color: Color) -> void:
	_color = new_color
	queue_redraw()


func color() -> Color:
	return _color


func font_size() -> int:
	return _font_size


func pitch() -> float:
	return _pitch


## How many lines show (at most max_lines).
func line_count() -> int:
	return _lines.size()


## Whether every piece of the text shows (none cut by max_lines).
func fits() -> bool:
	return _needed_lines <= _lines.size()


## Where the text is drawn, in this label's coordinates: its lines' height, as wide as its
## widest line (empty with no text).
func text_rect() -> Rect2:
	if _lines.is_empty():
		return Rect2()
	var widest: float = 0.0
	for index: int in _lines.size():
		widest = maxf(widest, _line_end(_lines[index]))
	return Rect2(Vector2.ZERO, Vector2(ceilf(widest), _lines.size() * _pitch))


## The rect of the first line's text, in this label's coordinates (empty with no text).
func first_line_rect() -> Rect2:
	if _lines.is_empty():
		return Rect2()
	return Rect2(Vector2.ZERO, Vector2(ceilf(_line_end(_lines[0])), _pitch))


## The family glyphs drawn in the text, in order.
func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


func _draw() -> void:
	var ascent: float = _font.get_ascent(_font_size)
	var height: float = ascent + _font.get_descent(_font_size)
	for index: int in _lines.size():
		var baseline: float = roundf(index * _pitch + (_pitch - height) / 2.0 + ascent)
		for run: Dictionary in _lines[index]:
			if str(run["family"]).is_empty():
				draw_string(
					_font,
					Vector2(float(run["x"]), baseline),
					str(run["text"]),
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					_font_size,
					_color
				)


func _lay_out() -> void:
	for glyph: FamilyGlyph in _glyphs:
		remove_child(glyph)
		glyph.free()
	_glyphs.clear()
	_lines.clear()
	var space: float = _text_width(" ")
	var lines: Array[Array] = []
	var line: Array = []
	var x: float = 0.0
	for piece: Array in GlyphText.pieces(text, _palette):
		var piece_width: float = _piece_width(piece)
		var room: float = _width - (_first_inset if lines.is_empty() else 0.0)
		var start: float = x + (space if not line.is_empty() else 0.0)
		if not line.is_empty() and start + piece_width > room:
			lines.append(line)
			line = []
			start = 0.0
		for run: Dictionary in piece:
			var placed: Dictionary = run.duplicate()
			placed["x"] = roundf(start)
			line.append(placed)
			start += _run_width(run)
		x = start
	if not line.is_empty():
		lines.append(line)
	_needed_lines = lines.size()
	var shown: int = lines.size() if _max_lines <= 0 else mini(lines.size(), _max_lines)
	for index: int in shown:
		_lines.append(lines[index])
	size = Vector2(_width, _lines.size() * _pitch)
	custom_minimum_size = size
	_add_glyphs()
	queue_redraw()


func _add_glyphs() -> void:
	var ascent: float = _font.get_ascent(_font_size)
	var height: float = ascent + _font.get_descent(_font_size)
	for index: int in _lines.size():
		var baseline: float = roundf(index * _pitch + (_pitch - height) / 2.0 + ascent)
		for run: Dictionary in _lines[index]:
			var family: String = str(run["family"])
			if family.is_empty():
				continue
			var style: FamilyStyle = _palette.style(family)
			if style == null or style.glyph == null:
				continue
			var glyph: FamilyGlyph = FamilyGlyph.new(style, _rimmed)
			glyph.position = Vector2(
				float(run["x"]) + GLYPH_MARGIN, baseline + GLYPH_DROP - ArtStyle.FAMILY_GLYPH_SIZE
			)
			glyph.tip_below = _tip_below
			glyph.tip_anchor = _tip_anchor
			add_child(glyph)
			_glyphs.append(glyph)


func _line_end(line: Array) -> float:
	if line.is_empty():
		return 0.0
	var last: Dictionary = line[line.size() - 1]
	return float(last["x"]) + _run_width(last)


func _piece_width(piece: Array) -> float:
	var width: float = 0.0
	for run: Dictionary in piece:
		width += _run_width(run)
	return width


func _run_width(run: Dictionary) -> float:
	if str(run["family"]).is_empty():
		return _text_width(str(run["text"]))
	return ArtStyle.FAMILY_GLYPH_SIZE + 2.0 * GLYPH_MARGIN


func _text_width(part: String) -> float:
	return _font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
