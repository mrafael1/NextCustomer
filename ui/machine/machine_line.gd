class_name MachineLine
extends PixelLine
## One line of the machine's hard pixel lettering (the relook, mock-up
## docs/art/mockups/machine_relook.html V2): PixelLine's words (Pixelify's 11 px raster at 2x or
## 4x) and numbers (the number font's raster at 2x), from plain text. show_text() splits a line
## into runs: a number run is digits with the signs that go with them (€, %, +, −, <, ×), drawn in
## the number font (the € and the 2 never mistaken for each other); a mark (✓ ✕ ● ◆ ★, which
## Pixelify lacks) is a small pixel pattern; the rest are words. The runs follow each other one
## art px apart, a space keeping its own advance, so "SPEND 109€ ✓ THANK YOU!" reads as one line.
## `big` numbers use PixelWords' 6x8 bold digits instead (the display's amounts). The control's
## top left is the words' cap top at the line's left; its size is the line's width and the
## capitals' height. Display only.

## The number runs: digits and the signs printed with them.
const NUMBER_RUN := "[+−<×]?[0-9]+(?:[.,][0-9]+)?[€%]?"
## The marks drawn as patterns ('#' ink), centred on the capitals.
const MARKS: Dictionary[String, Array] = {
	"✓": ["....#", "...##", "#.##.", "###..", ".#..."],
	"✕": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"●": [".#.", "###", ".#."],
	"◆": [".#.", "###", ".#."],
	"★": ["..#..", "#####", ".###.", ".#.#."],
}
## Between two runs, in art px.
const RUN_GAP := 1

static var _mark_textures: Dictionary[String, ImageTexture] = {}

var _runs: Array[String] = []
var _ink: Color = Palette.INK


## Lays out `line`: words in `colour` at `word_scale` (1: 2x, 2: 4x), numbers and marks in
## `number_colour` (the words' colour when left clear); `big` numbers in PixelWords' 6x8 digits.
func show_text(
	line: String,
	colour: Color,
	number_colour: Color = Color(0, 0, 0, 0),
	word_scale: int = 1,
	big: bool = false
) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_scale_factor = word_scale
	var numbers: Color = number_colour if number_colour.a > 0.0 else colour
	var art: float = ArtStyle.ART_SCALE
	var x: float = 0.0
	_runs = runs_of(line)
	for index: int in _runs.size():
		var run: String = _runs[index]
		if index > 0:
			x += RUN_GAP * art
		if MARKS.has(run):
			x += _add_icon(mark_texture(run, numbers), x, CENTRED)
		elif _is_number_run(run):
			x += _add_big(run, x, numbers) if big else _add_number(run, x, numbers)
		else:
			x += _add_word(run, x, colour)
	_width = x
	_text = line
	_ink = colour
	size = Vector2(_width, ArtStyle.PIXEL_CAP_HEIGHT * art * word_scale)


## A new line showing `line` (show_text's arguments), named `line_name`.
static func make(
	line_name: String,
	line: String,
	colour: Color,
	number_colour: Color = Color(0, 0, 0, 0),
	word_scale: int = 1,
	big: bool = false
) -> MachineLine:
	var made: MachineLine = MachineLine.new()
	made.name = line_name
	made.show_text(line, colour, number_colour, word_scale, big)
	return made


## The words' colour (show_text's `colour`).
func ink() -> Color:
	return _ink


## Centres the line in `rect` (its parent's px) on the 2 px grid: its ink across, its capitals
## down.
func centre_in(rect: Rect2) -> void:
	position = MachineArt.snap_point(rect.get_center() - size / 2.0)


## The runs `line` is drawn in: number runs, marks and the words between them.
static func runs_of(line: String) -> Array[String]:
	var runs: Array[String] = []
	var pattern: RegEx = RegEx.create_from_string(NUMBER_RUN)
	var word: String = ""
	var at: int = 0
	while at < line.length():
		var found: RegExMatch = pattern.search(line, at)
		var mark_at: int = _next_mark(line, at)
		var next: int = found.get_start() if found != null else line.length()
		if mark_at >= 0 and mark_at < next:
			word += line.substr(at, mark_at - at)
			_push(runs, word)
			word = ""
			runs.append(line[mark_at])
			at = mark_at + 1
			continue
		if found == null:
			word += line.substr(at)
			break
		word += line.substr(at, next - at)
		_push(runs, word)
		word = ""
		runs.append(found.get_string())
		at = found.get_end()
	_push(runs, word)
	return runs


## `line`'s width in canvas px at `word_scale` (as show_text lays it out).
static func width_of(line: String, word_scale: int = 1, big: bool = false) -> float:
	var art: float = ArtStyle.ART_SCALE
	var total: float = 0.0
	var runs: Array[String] = runs_of(line)
	for index: int in runs.size():
		var run: String = runs[index]
		if index > 0:
			total += RUN_GAP * art
		if MARKS.has(run):
			total += (MARKS[run][0] as String).length() * art
		elif _is_number_run(run):
			if big:
				total += PixelWords.text_size(run, PixelWords.Sheet.DIGITS, art).x
			else:
				total += number_width(run)
		else:
			total += word_width(run, word_scale)
	return total


## Mark `mark`'s pattern as a texture in `colour` (cached).
static func mark_texture(mark: String, colour: Color) -> ImageTexture:
	var key: String = "%s:%s" % [mark, colour.to_html()]
	if not _mark_textures.has(key):
		var rows: Array = MARKS[mark]
		var image: Image = Image.create_empty(
			(rows[0] as String).length(), rows.size(), false, Image.FORMAT_RGBA8
		)
		for y: int in rows.size():
			var row: String = rows[y]
			for x: int in row.length():
				if row[x] == "#":
					image.set_pixel(x, y, colour)
		_mark_textures[key] = ImageTexture.create_from_image(image)
	return _mark_textures[key]


## The line's runs, for tests.
func run_list() -> Array[String]:
	return _runs


static func _is_number_run(run: String) -> bool:
	var pattern: RegEx = RegEx.create_from_string("^(?:%s)$" % NUMBER_RUN)
	return pattern.search(run) != null


static func _next_mark(line: String, from: int) -> int:
	var best: int = -1
	for mark: String in MARKS:
		var at: int = line.find(mark, from)
		if at >= 0 and (best < 0 or at < best):
			best = at
	return best


## Adds `word` to `runs` unless it is blank (a lone space still separates its neighbours: it is
## kept when it falls between two runs).
static func _push(runs: Array[String], word: String) -> void:
	if word.is_empty():
		return
	if word.strip_edges().is_empty() and runs.is_empty():
		return
	runs.append(word)


## A number in PixelWords' 6x8 digits, its foot on the words' baseline.
func _add_big(number: String, x: float, colour: Color) -> float:
	var art: float = ArtStyle.ART_SCALE
	var digits: PixelWords = PixelWords.new(number, PixelWords.Sheet.DIGITS, art, colour)
	var rows: int = PixelWords.font_size_of(number, PixelWords.Sheet.DIGITS).y
	digits.position = Vector2(x, (ArtStyle.PIXEL_CAP_HEIGHT * _scale_factor - rows) * art)
	add_child(digits)
	return PixelWords.text_size(number, PixelWords.Sheet.DIGITS, art).x
