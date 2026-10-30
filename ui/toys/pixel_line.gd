class_name PixelLine
extends Control
## One line of the title's hard pixel lettering (#121, direction C+): words in Pixelify
## (UiKit.pixel_label), every number in the number font as hard pixels (ArtStyle.
## pixel_number_font) and icons, all on the 2 px art grid, their baselines met, GAP art px
## apart. The control's top left is the words' cap top at the line's left; its size is the
## line's width and the words' cap height (digits stand a little taller, icons are centred on
## the capitals). A word token is any text; a token of digits, "/" and "?" is a number (split
## turns a sentence into tokens); a Texture2D token is an icon drawn at 2x.

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

## Each number glyph's ink: x its left edge from the pen (font px), y its width.
static var _number_inks: Dictionary[String, Vector2i] = {}

var _width: float = 0.0
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
	var x: float = 0.0
	var words: PackedStringArray = []
	for index: int in tokens.size():
		if index > 0:
			x += gap * art
		var token: Variant = tokens[index]
		if token is Texture2D:
			x += _add_icon(token as Texture2D, x, icon_top)
		elif is_number(str(token)):
			x += _add_number(str(token), x, number_colour)
			words.append(str(token))
		else:
			x += _add_word(str(token), x, colour)
			words.append(str(token))
	_width = x
	_text = " ".join(words)
	size = Vector2(_width, ArtStyle.PIXEL_CAP_HEIGHT * art * word_scale)


## The line's width in canvas px.
func width() -> float:
	return _width


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


## A word's ink width in canvas px at `word_scale` (its advance less the font's trailing pixel).
static func word_width(word: String, word_scale: int = 1) -> float:
	var font: Font = ArtStyle.pixel_display_font()
	var advance: float = (
		font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
	)
	return maxf(advance - 1.0, 0.0) * ArtStyle.ART_SCALE * word_scale


## A number's width in canvas px: its digits' inks, DIGIT_GAP art px apart.
static func number_width(number: String) -> float:
	var ink_width: int = 0
	for index: int in number.length():
		ink_width += _number_ink(number[index]).y + (DIGIT_GAP if index > 0 else 0)
	return ink_width * ArtStyle.ART_SCALE


## The ink of `glyph` in the number font (rendered once): its left edge from the pen and its
## width, in font px; with no ink, its advance.
static func _number_ink(glyph: String) -> Vector2i:
	if not _number_inks.has(glyph):
		var font: Font = ArtStyle.pixel_number_font()
		var server: TextServer = TextServerManager.get_primary_interface()
		var rid: RID = font.get_rids()[0]
		var font_size: int = ArtStyle.PIXEL_NUMBER_SIZE
		var key: Vector2i = Vector2i(font_size, 0)
		var index: int = server.font_get_glyph_index(rid, font_size, glyph.unicode_at(0), 0)
		server.font_render_glyph(rid, key, index)
		var advance: float = server.font_get_glyph_advance(rid, font_size, index).x
		var ink: Vector2i = Vector2i(0, ceili(advance))
		var texture_index: int = server.font_get_glyph_texture_idx(rid, key, index)
		if texture_index >= 0:
			var image: Image = server.font_get_texture_image(rid, key, texture_index)
			var uv: Rect2i = Rect2i(server.font_get_glyph_uv_rect(rid, key, index))
			var used: Rect2i = image.get_region(uv).get_used_rect()
			var offset: Vector2 = server.font_get_glyph_offset(rid, key, index)
			if used.has_area():
				ink = Vector2i(roundi(offset.x) + used.position.x, used.size.x)
		_number_inks[glyph] = ink
	return _number_inks[glyph]


func _add_word(word: String, x: float, colour: Color) -> float:
	var scale_px: int = ArtStyle.ART_SCALE * _scale_factor
	var label: Label = UiKit.pixel_label(word, scale_px, colour)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	label.position = Vector2(x - LEFT_BEARING * scale_px, -cap_top * scale_px)
	add_child(label)
	return word_width(word, _scale_factor)


## A number on the words' baseline (the cap top's PIXEL_CAP_HEIGHT rows down): one label per
## glyph, its ink at the cursor, DIGIT_GAP art px after the previous glyph's ink.
func _add_number(number: String, x: float, colour: Color) -> float:
	var art: float = ArtStyle.ART_SCALE
	var ascent: float = ArtStyle.pixel_number_font().get_ascent(ArtStyle.PIXEL_NUMBER_SIZE)
	var baseline: float = ArtStyle.PIXEL_CAP_HEIGHT * _scale_factor
	var cursor: float = x
	for index: int in number.length():
		var glyph: String = number[index]
		var ink: Vector2i = _number_ink(glyph)
		var label: Label = Label.new()
		label.text = glyph
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", ArtStyle.pixel_number_font())
		label.add_theme_font_size_override("font_size", ArtStyle.PIXEL_NUMBER_SIZE)
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_color", colour)
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		label.scale = Vector2.ONE * art
		label.position = Vector2(cursor - ink.x * art, (baseline - ascent) * art)
		add_child(label)
		cursor += (ink.y + DIGIT_GAP) * art
	return number_width(number)


func _add_icon(icon: Texture2D, x: float, icon_top: int) -> float:
	var art: float = ArtStyle.ART_SCALE
	var icon_size: Vector2 = icon.get_size()
	var top: float = icon_top
	if icon_top == CENTRED:
		top = floorf((ArtStyle.PIXEL_CAP_HEIGHT * _scale_factor - icon_size.y) / 2.0 + 0.5)
	var sprite: TextureRect = UiKit.sprite(icon)
	sprite.size = icon_size * art
	sprite.position = Vector2(x, top * art)
	add_child(sprite)
	return icon_size.x * art
