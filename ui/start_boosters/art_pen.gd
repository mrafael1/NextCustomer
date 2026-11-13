class_name ArtPen
extends RefCounted
## Draws YOUR STORE's booster scene on a CanvasItem in art px (v1.32, mock-up
## docs/art/mockups/start_boosters_v3.html, which draws everything on the 640x360 art grid): each
## art px is `unit` stage px (2 on the 1280x720 stage), from `origin` (stage px). The mock-up's
## pixel primitives in GDScript: rect (r), outlined boxes (rb, rn), ordered dither (d), sprites
## (tex, at 1x art), the game's 2x frames as nine-slices (nine), chunky capitals and digits
## (chunky), the 3x5 capitals (caps), hard Pixelify words (pix) and Atkinson rule text (atk).
## Positions round to whole art px, so motion steps on the art grid as in the mock-up.

## Every scene pixel's stage px at scale 1 (ArtStyle.ART_SCALE).
const UNIT := 2.0
## Bayer 4x4 order for the dither tiles (the mock-up's BAYER).
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _dither: Dictionary[String, ImageTexture] = {}
static var _words: Dictionary[String, ImageTexture] = {}
static var _boxes: Dictionary[String, StyleBoxTexture] = {}
static var _silhouettes: Dictionary[String, ImageTexture] = {}

var canvas: CanvasItem
## The stage px of art (0, 0), and the stage px per art px on each axis (a flip narrows x).
var origin: Vector2 = Vector2.ZERO
var unit: Vector2 = Vector2.ONE * UNIT


func _init(target: CanvasItem) -> void:
	canvas = target


## Stage px of art point (`x`, `y`), rounded to whole art px.
func at(x: float, y: float) -> Vector2:
	return origin + Vector2(roundf(x) * unit.x, roundf(y) * unit.y)


func size_of(w: float, h: float) -> Vector2:
	return Vector2(roundf(w) * unit.x, roundf(h) * unit.y)


func r(x: float, y: float, w: float, h: float, colour: Color) -> void:
	if w <= 0 or h <= 0:
		return
	canvas.draw_rect(Rect2(at(x, y), size_of(w, h)), colour)


## A box with a 1 px `line` (ink) and `fill` inside.
func rb(x: float, y: float, w: float, h: float, fill: Color, line: Color = Palette.INK) -> void:
	r(x, y, w, h, line)
	r(x + 1, y + 1, w - 2, h - 2, fill)


## The game's plate silhouette: an outlined box with its corners notched one px.
func rn(x: float, y: float, w: float, h: float, fill: Color, line: Color = Palette.INK) -> void:
	r(x + 1, y, w - 2, h, line)
	r(x, y + 1, w, h - 2, line)
	r(x + 1, y + 1, w - 2, h - 2, fill)


## An ordered dither of `colour` at `level` of 16 (4: one px in four, 8: a checker), anchored to
## the art grid's origin so neighbouring rects keep one pattern.
func d(x: float, y: float, w: float, h: float, colour: Color, level: int) -> void:
	if level <= 0 or w <= 0 or h <= 0:
		return
	if level >= 16:
		r(x, y, w, h, colour)
		return
	var tile: ImageTexture = dither_tile(colour, level)
	var left: int = roundi(x)
	var top: int = roundi(y)
	var region: Rect2 = Rect2(posmod(left, 4), posmod(top, 4), roundf(w), roundf(h))
	canvas.draw_texture_rect_region(tile, Rect2(at(left, top), size_of(w, h)), region)


## A sprite drawn at 1x art (its texels are art px) at (`x`, `y`), `scale` art px per texel.
func tex(
	texture: Texture2D, x: float, y: float, modulate: Color = Color.WHITE, scale: float = 1.0
) -> void:
	if texture == null:
		return
	var texels: Vector2 = texture.get_size() * scale
	canvas.draw_texture_rect(texture, Rect2(at(x, y), size_of(texels.x, texels.y)), false, modulate)


## Part `region` (texels) of a 1x sprite, stretched to `w` x `h` art px at (`x`, `y`).
func tex_part(
	texture: Texture2D,
	region: Rect2,
	x: float,
	y: float,
	w: float,
	h: float,
	modulate: Color = Color.WHITE
) -> void:
	if texture == null or w <= 0 or h <= 0:
		return
	canvas.draw_texture_rect_region(texture, Rect2(at(x, y), size_of(w, h)), region, modulate)


## A sprite centred on (`cx`, `cy`).
func tex_c(texture: Texture2D, cx: float, cy: float) -> void:
	var half: Vector2 = (texture.get_size() / 2.0).floor()
	tex(texture, cx - half.x, cy - half.y)


## One of the game's 2x frames (art/frames, built with @scale 2) as a nine-slice over art rect
## (`x`, `y`, `w`, `h`), its margins `margins` art px (left, top, right, bottom).
func nine(
	frame: Texture2D,
	x: float,
	y: float,
	w: float,
	h: float,
	margins: Vector4i,
	modulate: Color = Color.WHITE
) -> void:
	if w <= 0 or h <= 0:
		return
	var box: StyleBoxTexture = frame_box(frame, margins)
	box.modulate_color = modulate
	canvas.draw_style_box(box, Rect2(at(x, y), size_of(w, h)))


## Chunky capitals and digits (art/fonts, 6x8) in `colour` at `scale`, from their top left (or
## centred / right-aligned on `x`); returns their width in art px.
func chunky(
	text: String,
	x: float,
	y: float,
	colour: Color,
	scale: float = 1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> float:
	var words: ImageTexture = word_texture(text, colour, true)
	var w: float = words.get_width() * scale
	tex(words, _aligned(x, w, align), y, Color.WHITE, scale)
	return w


## The 3x5 capitals (PixelWords CAPS) in `colour`; returns their width in art px.
func caps(
	text: String,
	x: float,
	y: float,
	colour: Color,
	scale: float = 1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> float:
	var words: ImageTexture = word_texture(text, colour, false)
	var w: float = words.get_width() * scale
	tex(words, _aligned(x, w, align), y, Color.WHITE, scale)
	return w


## Hard Pixelify words (ArtStyle.pixel_display_font at PIXEL_TEXT_SIZE, one font px an art px)
## with their capitals' top at `y`; returns their width in art px.
func pix(
	text: String,
	x: float,
	y: float,
	colour: Color,
	scale: float = 1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> float:
	var w: float = pix_width(text) * scale
	var left: Vector2 = at(_aligned(x, w, align), y)
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var k: Vector2 = unit * scale
	canvas.draw_set_transform(left, 0.0, k)
	canvas.draw_string(
		font,
		Vector2(0, font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - cap_top),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ArtStyle.PIXEL_TEXT_SIZE,
		colour
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return w


## Atkinson Hyperlegible (bold `weight`) at `art_size` art px, centred on `cx` (or from its left)
## with its baseline at `baseline` (art px): the only smooth text, as the mock-up's rule boxes.
func atk(
	text: String,
	cx: float,
	baseline: float,
	art_size: float,
	colour: Color,
	weight: int = 650,
	align: int = HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	var font: Font = ArtStyle.bold_font(weight)
	var font_size: int = maxi(1, roundi(art_size * unit.y))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left: float = origin.x + cx * unit.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		left -= width * unit.x / unit.y / 2.0
	canvas.draw_set_transform(
		Vector2(left, origin.y + baseline * unit.y), 0.0, Vector2(unit.x / unit.y, 1.0)
	)
	canvas.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A gold dashed focus ring round art rect (`x`, `y`, `w`, `h`), as the mock-up's.
func focus_ring(x: float, y: float, w: float, h: float) -> void:
	var i: float = 0.0
	while i < w + 4:
		r(x - 2 + i, y - 2, 2, 1, Palette.GOLD)
		r(x - 2 + i, y + h + 1, 2, 1, Palette.GOLD)
		i += 4
	i = 0.0
	while i < h + 4:
		r(x - 2, y - 2 + i, 1, 2, Palette.GOLD)
		r(x + w + 1, y - 2 + i, 1, 2, Palette.GOLD)
		i += 4


static func _aligned(x: float, w: float, align: int) -> float:
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		return roundf(x - w / 2.0)
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		return roundf(x - w)
	return x


## Hard Pixelify words' width in art px.
static func pix_width(text: String) -> float:
	var font: Font = ArtStyle.pixel_display_font()
	return ceilf(
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
	)


## `text` wrapped into lines no wider than `max_w` art px of hard Pixelify words.
static func pix_wrap(text: String, max_w: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var trial: String = word if line == "" else line + " " + word
		if pix_width(trial) > max_w and line != "":
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	return lines


## A 4x4 dither tile of `colour` at `level` (cached).
static func dither_tile(colour: Color, level: int) -> ImageTexture:
	var key: String = "%s|%d" % [colour.to_html(), level]
	if not _dither.has(key):
		var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		for index: int in 16:
			if BAYER[index] < level:
				image.set_pixel(index % 4, index >> 2, colour)
		_dither[key] = ImageTexture.create_from_image(image)
	return _dither[key]


## `text` in the chunky sheets (`chunky`) or the 3x5 capitals, `colour` on clear (cached): one
## texel an art px, glyphs one px apart, a ':' as two 2x2 dots (the mock-up's).
static func word_texture(text: String, colour: Color, chunky_sheet: bool) -> ImageTexture:
	var key: String = "%s|%s|%s" % [text, colour.to_html(), chunky_sheet]
	if _words.has(key):
		return _words[key]
	var glyphs: Array[Array] = []
	var width: int = 0
	var rows: int = 8 if chunky_sheet else 5
	for character: String in text.to_upper():
		var glyph: Array = _glyph(character, chunky_sheet)
		glyphs.append(glyph)
		width += (glyph[0] as String).length() + 1
	var image: Image = Image.create(maxi(1, width - 1), rows, false, Image.FORMAT_RGBA8)
	var x: int = 0
	for glyph: Array in glyphs:
		for row: int in mini(rows, glyph.size()):
			var line: String = glyph[row]
			for column: int in line.length():
				if line[column] == "#":
					image.set_pixel(x + column, row, colour)
		x += (glyph[0] as String).length() + 1
	_words[key] = ImageTexture.create_from_image(image)
	return _words[key]


static func _glyph(character: String, chunky_sheet: bool) -> Array:
	if not chunky_sheet:
		if character == "-":
			return ["...", "...", "###", "...", "..."]
		if character == "+":
			return ["...", ".#.", "###", ".#.", "..."]
		if character == "·":
			return ["...", "...", ".#.", "...", "..."]
		return PixelWords.glyph_of(character, PixelWords.Sheet.CAPS)
	if character == ":":
		return ["..", "##", "##", "..", "..", "##", "##", ".."]
	if character == " ":
		return ["...", "...", "...", "...", "...", "...", "...", "..."]
	if PixelWords.CHUNKY_ORDER.contains(character) or character == "-":
		return PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY)
	return PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY_CAPS)


## A cached StyleBoxTexture of 2x `frame` with `margins` art px.
static func frame_box(frame: Texture2D, margins: Vector4i) -> StyleBoxTexture:
	var key: String = "%s|%s" % [frame.resource_path, margins]
	if not _boxes.has(key):
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = frame
		box.texture_margin_left = margins.x * UNIT
		box.texture_margin_top = margins.y * UNIT
		box.texture_margin_right = margins.z * UNIT
		box.texture_margin_bottom = margins.w * UNIT
		_boxes[key] = box
	return _boxes[key]


## `texture` with every opaque texel in `colour` (the mock-up's tint), cached.
static func silhouette(texture: Texture2D, colour: Color) -> ImageTexture:
	var key: String = "%s|%s" % [texture.resource_path, colour.to_html()]
	if not _silhouettes.has(key):
		var image: Image = texture.get_image().duplicate() as Image
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					image.set_pixel(x, y, colour)
				else:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
		_silhouettes[key] = ImageTexture.create_from_image(image)
	return _silhouettes[key]
