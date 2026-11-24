class_name PixelLine
extends Control
## One line of the title's hard pixel lettering (#121, direction C+): words in Pixelify
## (UiKit.pixel_label), every number in the number font as hard pixels (ArtStyle.
## pixel_number_font) and icons, all on the 2 px art grid, their baselines met, GAP art px
## apart. The control's top left is the words' cap top at the line's left; its size is the
## line's width and the words' cap height (digits stand a little taller, icons are centred on
## the capitals). A word token is any text; a token of digits, "/" and "?" is a number (split
## turns a sentence into tokens); a Texture2D token is an icon drawn at 2x; a SEPARATOR token is
## a drawn middle dot. v1.30 round 7 (the user: "non-food text has its '-' a bit weird"):
## Pixelify's hyphen has no bearing (it touched the N of NON-FOOD) and stood wide, so a word's
## hyphens are drawn by hand: DASH_WIDTH font px on the capitals' middle row (DASH_ROW), DASH_GAP
## clear of the letters each side (NON-FOOD, DAY-OLD BUNS); word_width measures the same.

## The space between tokens, in art px.
const GAP := 3
## Number tokens: digits, "/" and "?" only.
const NUMBER_PATTERN := "^[0-9/?]+$"
## Pixelify's glyphs start this many font px right of their origin (60 of 1000 units at 11 px
## round onto the next pixel): a word's label stands this far left so its ink starts at x.
const LEFT_BEARING := 1
## An icon_top that centres the icons on the capitals.
const CENTRED := -100
## A number's digits stand DIGIT_GAP art px apart, each cropped to its ink (the mock-up's).
const DIGIT_GAP := 1
## A word's hyphen (round 7), in font px: DASH_WIDTH wide, one row tall on row DASH_ROW of the
## capitals (0 their top row), DASH_GAP clear of the letters either side.
const DASH := "-"
const DASH_WIDTH := 3
const DASH_ROW := 3
const DASH_GAP := 1
## The separator token (round 7: "BREAKFAST · NON-FOOD"): a SEPARATOR_SIZE font px square, its
## top on row SEPARATOR_ROW of the capitals.
const SEPARATOR := "·"
const SEPARATOR_SIZE := 2
const SEPARATOR_ROW := 2

## Each number glyph's ink in font px: x its left edge from the pen, y its top from the baseline
## (up is negative), w and h its size (h 0: no ink).
static var _number_inks: Dictionary[String, Rect2i] = {}

var _width: float = 0.0
## The drawn ink's extent in canvas px, from the line's top left (ink_rect).
var _ink_box: Rect2 = Rect2()
var _scale_factor: int = 1
var _text: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lays out `tokens` (Strings and Texture2Ds): words in `colour`, numbers in `number_colour`, the
## words' font pixels `word_scale` art px (1, or 2 for a heading); `gap` art px between tokens;
## icons' tops `icon_top` art px under the cap top (CENTRED: centred on the capitals).
func show_tokens(
	tokens: Array,
	colour: Color,
	number_colour: Color,
	word_scale: int = 1,
	gap: int = GAP,
	icon_top: int = CENTRED
) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_scale_factor = word_scale
	var art: float = ArtStyle.ART_SCALE
	var cap: float = ArtStyle.PIXEL_CAP_HEIGHT * art * word_scale
	var x: float = 0.0
	var words: PackedStringArray = []
	var top: float = 0.0
	var bottom: float = 0.0
	for index: int in tokens.size():
		if index > 0:
			x += gap * art
		var token: Variant = tokens[index]
		if token is Texture2D:
			var icon_y: float = _icon_y(token as Texture2D, icon_top)
			top = minf(top, icon_y)
			bottom = maxf(bottom, icon_y + (token as Texture2D).get_size().y * art)
			x += _add_icon(token as Texture2D, x, icon_top)
		elif str(token) == SEPARATOR:
			x += _add_mark(x, SEPARATOR_ROW, Vector2i.ONE * SEPARATOR_SIZE, colour)
			words.append(SEPARATOR)
			bottom = maxf(bottom, cap)
		elif is_number(str(token)):
			var rows: Vector2 = number_rows(str(token), word_scale)
			top = minf(top, rows.x)
			bottom = maxf(bottom, rows.y)
			x += _add_number(str(token), x, number_colour)
			words.append(str(token))
		else:
			x += _add_word(str(token), x, colour)
			words.append(str(token))
			bottom = maxf(bottom, cap)
	_width = x
	_text = " ".join(words)
	_ink_box = Rect2(0.0, top, _width, bottom - top)
	size = Vector2(_width, cap)


## The line's width in canvas px.
func width() -> float:
	return _width


## The drawn ink's extent in canvas px from the line's top left (the words' cap top): the words'
## capitals, the numbers' digits (they stand a little taller) and the icons, so a box can centre
## what it holds (the grade card's status chip).
func ink_rect() -> Rect2:
	return _ink_box


## The line's words and numbers, space-joined (icons left out).
func text() -> String:
	return _text


## Whether `token` prints in the number font.
static func is_number(token: String) -> bool:
	var pattern: RegEx = RegEx.create_from_string(NUMBER_PATTERN)
	return pattern.search(token) != null


## `sentence` as tokens: its runs of digits apart from the words round them ("PASS SHIFT 4 PAY"
## gives "PASS SHIFT", "4", "PAY").
static func split(sentence: String) -> Array:
	var tokens: Array = []
	var pattern: RegEx = RegEx.create_from_string("\\s*\\b([0-9]+)\\b\\s*")
	var start: int = 0
	for found: RegExMatch in pattern.search_all(sentence):
		if found.get_start() > start:
			tokens.append(sentence.substr(start, found.get_start() - start))
		tokens.append(found.get_string(1))
		start = found.get_end()
	if start < sentence.length():
		tokens.append(sentence.substr(start))
	return tokens


## A word's ink width in canvas px at `word_scale` (its advance less the font's trailing pixel),
## its hyphens drawn (round 7: DASH_WIDTH, DASH_GAP clear of a letter either side).
static func word_width(word: String, word_scale: int = 1) -> float:
	var parts: PackedStringArray = word.split(DASH)
	var font_px: int = 0
	for index: int in parts.size():
		font_px += _plain_width(parts[index])
		if index > 0:
			font_px += _dash_advance(parts[index - 1], parts[index])
	return font_px * ArtStyle.ART_SCALE * word_scale


## A run of letters' ink width in font px (its advance less the font's trailing pixel).
static func _plain_width(run: String) -> int:
	if run.is_empty():
		return 0
	var font: Font = ArtStyle.pixel_display_font()
	var advance: float = (
		font.get_string_size(run, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
	)
	return maxi(roundi(advance) - 1, 0)


## A drawn hyphen's width in font px between the runs `before` and `after`: the dash, and
## DASH_GAP on each side that has a letter.
static func _dash_advance(before: String, after: String) -> int:
	var gaps: int = (0 if before.is_empty() else DASH_GAP) + (0 if after.is_empty() else DASH_GAP)
	return DASH_WIDTH + gaps


## A number's width in canvas px: its digits' inks, DIGIT_GAP art px apart.
static func number_width(number: String) -> float:
	var ink_width: int = 0
	for index: int in number.length():
		ink_width += _number_ink(number[index]).size.x + (DIGIT_GAP if index > 0 else 0)
	return ink_width * ArtStyle.ART_SCALE


## A number's ink rows in canvas px from the cap top at `word_scale`: x its top, y its bottom.
static func number_rows(number: String, word_scale: int = 1) -> Vector2:
	var baseline: int = ArtStyle.PIXEL_CAP_HEIGHT * word_scale
	var rows: Vector2 = Vector2(INF, -INF)
	for index: int in number.length():
		var ink: Rect2i = _number_ink(number[index])
		if ink.size.y > 0:
			rows.x = minf(rows.x, baseline + ink.position.y)
			rows.y = maxf(rows.y, baseline + ink.end.y)
	if rows.x > rows.y:
		return Vector2.ZERO
	return rows * ArtStyle.ART_SCALE


## The ink of `glyph` in the number font, in font px (number_ink's; the grade badge centres its
## digit on it).
static func glyph_ink(glyph: String) -> Rect2i:
	return _number_ink(glyph)


## The ink of `glyph` in the number font (rendered once), in font px: x its left edge from the
## pen, y its top from the baseline, its size; with no ink, its advance wide and 0 tall.
static func _number_ink(glyph: String) -> Rect2i:
	if not _number_inks.has(glyph):
		var font: Font = ArtStyle.pixel_number_font()
		var server: TextServer = TextServerManager.get_primary_interface()
		var rid: RID = font.get_rids()[0]
		var font_size: int = ArtStyle.PIXEL_NUMBER_SIZE
		var key: Vector2i = Vector2i(font_size, 0)
		var index: int = server.font_get_glyph_index(rid, font_size, glyph.unicode_at(0), 0)
		server.font_render_glyph(rid, key, index)
		var advance: float = server.font_get_glyph_advance(rid, font_size, index).x
		var ink: Rect2i = Rect2i(0, 0, ceili(advance), 0)
		var texture_index: int = server.font_get_glyph_texture_idx(rid, key, index)
		if texture_index >= 0:
			var image: Image = server.font_get_texture_image(rid, key, texture_index)
			var uv: Rect2i = Rect2i(server.font_get_glyph_uv_rect(rid, key, index))
			var used: Rect2i = image.get_region(uv).get_used_rect()
			var offset: Vector2 = server.font_get_glyph_offset(rid, key, index)
			if used.has_area():
				ink = Rect2i(
					roundi(offset.x) + used.position.x,
					roundi(offset.y) + used.position.y,
					used.size.x,
					used.size.y
				)
		_number_inks[glyph] = ink
	return _number_inks[glyph]


## A word: its runs of letters as labels, a drawn dash for each hyphen between them (round 7).
func _add_word(word: String, x: float, colour: Color) -> float:
	var scale_px: int = ArtStyle.ART_SCALE * _scale_factor
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var parts: PackedStringArray = word.split(DASH)
	var cursor: float = x
	for index: int in parts.size():
		if index > 0:
			var before: int = 0 if parts[index - 1].is_empty() else DASH_GAP
			_add_mark(cursor + before * scale_px, DASH_ROW, Vector2i(DASH_WIDTH, 1), colour)
			cursor += _dash_advance(parts[index - 1], parts[index]) * scale_px
		if parts[index].is_empty():
			continue
		var label: Label = UiKit.pixel_label(parts[index], scale_px, colour)
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.position = Vector2(cursor - LEFT_BEARING * scale_px, -cap_top * scale_px)
		add_child(label)
		cursor += _plain_width(parts[index]) * scale_px
	return cursor - x


## A drawn mark in `colour` at `x` (a hyphen's dash, the separator): `cells` font px, its top on
## row `row` of the capitals; its advance in canvas px.
func _add_mark(x: float, row: int, cells: Vector2i, colour: Color) -> float:
	var scale_px: int = ArtStyle.ART_SCALE * _scale_factor
	var mark: ColorRect = ColorRect.new()
	mark.name = "Mark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.color = colour
	mark.position = Vector2(x, row * scale_px)
	mark.size = Vector2(cells) * scale_px
	add_child(mark)
	return cells.x * scale_px


## A number on the words' baseline (the cap top's PIXEL_CAP_HEIGHT rows down): one label per
## glyph, its ink at the cursor, DIGIT_GAP art px after the previous glyph's ink.
func _add_number(number: String, x: float, colour: Color) -> float:
	var art: float = ArtStyle.ART_SCALE
	var ascent: float = ArtStyle.pixel_number_font().get_ascent(ArtStyle.PIXEL_NUMBER_SIZE)
	var baseline: float = ArtStyle.PIXEL_CAP_HEIGHT * _scale_factor
	var cursor: float = x
	for index: int in number.length():
		var glyph: String = number[index]
		var ink: Rect2i = _number_ink(glyph)
		var label: Label = Label.new()
		label.text = glyph
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", ArtStyle.pixel_number_font())
		label.add_theme_font_size_override("font_size", ArtStyle.PIXEL_NUMBER_SIZE)
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_color", colour)
		ArtStyle.use_pixel_text_material(label)
		label.scale = Vector2.ONE * art
		label.position = Vector2(cursor - ink.position.x * art, (baseline - ascent) * art)
		add_child(label)
		cursor += (ink.size.x + DIGIT_GAP) * art
	return number_width(number)


func _add_icon(icon: Texture2D, x: float, icon_top: int) -> float:
	var art: float = ArtStyle.ART_SCALE
	var icon_size: Vector2 = icon.get_size()
	var sprite: TextureRect = UiKit.sprite(icon)
	sprite.size = icon_size * art
	sprite.position = Vector2(x, _icon_y(icon, icon_top))
	add_child(sprite)
	return icon_size.x * art


## An icon's top in canvas px from the cap top: `icon_top` art px, or CENTRED on the capitals.
func _icon_y(icon: Texture2D, icon_top: int) -> float:
	var top: float = icon_top
	if icon_top == CENTRED:
		top = floorf((ArtStyle.PIXEL_CAP_HEIGHT * _scale_factor - icon.get_size().y) / 2.0 + 0.5)
	return top * ArtStyle.ART_SCALE
