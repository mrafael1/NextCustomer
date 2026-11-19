class_name GlyphLabel
extends Control
## Sticker text with its family names drawn as glyphs (#105, mock-up readability v3, rich()): the
## text's pieces (GlyphText.pieces) flow into lines `width` wide, a line pitch apart, a line
## breaking only between pieces (a glyph never starts a line alone). Text runs are drawn in
## `font`; each family glyph is a FamilyGlyph, ArtStyle.FAMILY_GLYPH_SIZE square with
## GLYPH_MARGIN on each side, its foot GLYPH_DROP under the line's baseline (the mock-up's
## vertical-align -4px), with a paper rim when `rimmed`. At most `max_lines` lines show (0: any
## number); fits() says whether every piece did, each inside its line, and the last allowed line
## can keep clear of something at its right (set_end_inset: a ticket's MORE chip). Display only.
##
## Written (tickets v5, a ticket's rule plate): a family named by its id is a FamilyWord, its name
## on a chip in its colours (what the item works with), not a glyph, HEIGHT tall, centred on its
## line; a family's other words ("coupon") stay text, and nothing is glued to a family, so a chip
## may start a line.
##
## A keyword run (#128, GlyphText: BATCH) is a KeywordChip, CHIP_MARGIN clear of its neighbours
## (set_chip_room: the monitor's roomier chips, PR #138 round 2), centred on its line;
## set_wasted greys the text (WASTED_INK, role runs too) while the ticket's effect does nothing
## (its card's WASTED step, the play test of 2026-11-19); its chips, glyphs and written families
## stay as they are, and the ticket's tip says why.
##
## A role run (#128 batch polish, GlyphText: FIRST, LAST) is text drawn in its family's colour
## (_role_color): the family's shade, darkened, on light text's paper, its light on a dark plate's.
## An effect amount ("+4€", "×2"; v1.43, the user's "+x in green, ×Y the monitor's colour") is
## drawn in the monitor's ink for it (_amount_color), on light paper only (_segments).

## A glyph's room on its line: its margin each side.
const GLYPH_MARGIN := 1.0
## How far a glyph's foot sits under the line's baseline.
const GLYPH_DROP := 4.0
## A keyword chip's room on its line: its margin each side.
const CHIP_MARGIN := 1.0
## How much darker than its family's shade a role run is drawn on light paper (#128 batch polish:
## the Bakery shade alone read faint on the tickets).
const ROLE_DARKEN := 0.3
## How far a piece may pass its line's room (rounding) before the text no longer fits.
const OVERFLOW_SLACK := 0.5
## The text's ink while wasted (set_wasted).
const WASTED_INK := Palette.GREY

var text: String = ""
var _font: Font
var _font_size: int
var _color: Color
var _pitch: float
var _width: float
var _max_lines: int
var _rimmed: bool
var _end_inset: float = 0.0
var _written: bool = false
var _palette: FamilyPalette
## Each shown line's runs: {"text", "family", "x"} (x from the line's left).
var _lines: Array[Array] = []
var _needed_lines: int = 0
## Whether a piece is wider than its line's room (fits() is then false).
var _overflow: bool = false
var _glyphs: Array[FamilyGlyph] = []
var _words: Array[FamilyWord] = []
var _chips: Array[KeywordChip] = []
## The WASTED reason greying the text (set_wasted), or "" for live text.
var _wasted: String = ""
## Live words and their tooltips (set_live, #128 v3: Stale popcorn's ×N), drawn as value chips.
var _live: Dictionary = {}
var _tip_below: bool = false
var _tip_anchor: Control
## A chip's (a keyword's, a written family's) margin each side and a keyword chip's padding.
var _chip_margin: float = CHIP_MARGIN
var _chip_padding: float = KeywordChip.PADDING_X
## Each line centred in the width (set_centred: a cart card's rule), else from the left.
var _centred: bool = false


## `line` in `font` at `text_size` and `text_color`, `line_pitch` px a line, wrapped at `width`.
## `palette` names the glyphs (the game's when null); `written` writes the families (see above).
func _init(
	line: String,
	font: Font,
	text_size: int,
	text_color: Color,
	line_pitch: float,
	width: float,
	max_lines: int = 0,
	rimmed: bool = false,
	palette: FamilyPalette = null,
	written: bool = false
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
	_written = written
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay_out()


## Keeps the last allowed line (max_lines') `inset` px clear of the right edge (0: the full
## width).
func set_end_inset(inset: float) -> void:
	if is_equal_approx(inset, _end_inset):
		return
	_end_inset = inset
	_lay_out()


## Gives the chips `margin` px clear of their neighbours each side and a keyword chip's word
## `padding` px each side inside its box, laying the text out again.
func set_chip_room(margin: float, padding: float) -> void:
	if is_equal_approx(margin, _chip_margin) and is_equal_approx(padding, _chip_padding):
		return
	_chip_margin = margin
	_chip_padding = padding
	_lay_out()


## Centres each line in the width (`centred`), or puts it back at the left, laying the text out
## again.
func set_centred(centred: bool) -> void:
	if centred == _centred:
		return
	_centred = centred
	_lay_out()


## The glyphs' tooltips open below `anchor` (a ticket) when `below`, else above each glyph.
func set_tip(below: bool, anchor: Control) -> void:
	_tip_below = below
	_tip_anchor = anchor
	for glyph: FamilyGlyph in _glyphs:
		glyph.tip_below = below
		glyph.tip_anchor = anchor
	for chip: KeywordChip in _chips:
		chip.tip_below = below
		chip.tip_anchor = anchor
	for word: FamilyWord in _words:
		word.tip_below = below
		word.tip_anchor = anchor


## Greys the text while `reason` (the WASTED step's) is not empty, or inks it again (""). The
## layout never changes.
func set_wasted(reason: String) -> void:
	if reason == _wasted:
		return
	_wasted = reason
	queue_redraw()


func wasted() -> String:
	return _wasted


## Shows `line` with its `live` words (word: tooltip, GlyphText.pieces) as value chips, laying
## the text out again when either changes (#128 v3: Stale popcorn's ×N as the redraws go).
func set_live(line: String, live: Dictionary) -> void:
	if line == text and live == _live:
		return
	text = line
	_live = live.duplicate()
	_lay_out()


## The keyword chips drawn in the text, in order.
func keywords() -> Array[KeywordChip]:
	return _chips


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


## Whether every piece of the text shows (none cut by max_lines) inside its line's room.
func fits() -> bool:
	return _needed_lines <= _lines.size() and not _overflow


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


## The written families' chips (written mode), in order.
func words() -> Array[FamilyWord]:
	return _words


## Where the last shown line's text ends, in this label's coordinates (0 with no text).
func last_line_end() -> float:
	return _line_end(_lines[_lines.size() - 1]) if not _lines.is_empty() else 0.0


func _draw() -> void:
	var ascent: float = _font.get_ascent(_font_size)
	var height: float = ascent + _font.get_descent(_font_size)
	for index: int in _lines.size():
		var baseline: float = roundf(index * _pitch + (_pitch - height) / 2.0 + ascent)
		for run: Dictionary in _lines[index]:
			if not GlyphText.is_text(run):
				continue
			var at: float = float(run["x"])
			var base: Color = _role_color(GlyphText.role_family(run))
			var parts: Array[Array] = [[str(run["text"]), base]]
			if not GlyphText.is_role(run):
				parts = _segments(str(run["text"]))
			for part: Array in parts:
				var piece: String = part[0]
				var ink: Color = part[1] if (part[1] as Color).a > 0.0 else base
				var step: int = MonitorStepRow.factor_step(piece) if ink != base else -1
				var shadow: Color = (
					MonitorStepRow.factor_shadow(step) if step >= 0 else Color.TRANSPARENT
				)
				if shadow.a > 0.0:
					draw_string(
						_font,
						Vector2(at, baseline) + Vector2(MonitorStepRow.FACTOR_SHADOW),
						piece,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						_font_size,
						shadow
					)
				draw_string(
					_font,
					Vector2(at, baseline),
					piece,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					_font_size,
					ink
				)
				at += _text_width(piece)


## `line` cut into its pieces, each [text, ink]: an effect amount ("+4€", "+3", "×2"; its trailing
## punctuation apart) in the monitor's ink for it (MonitorStepRow.amount_colour_of: a bonus green,
## a factor its strength's ink), the rest transparent (the text's own colour). Live text on light
## paper only: wasted text stays WASTED_INK and a dark plate's light text keeps its colour (the
## monitor's inks are dark), so neither is cut.
func _segments(line: String) -> Array[Array]:
	if not _wasted.is_empty() or _color.get_luminance() >= 0.5:
		var whole: Array[Array] = [[line, Color.TRANSPARENT]]
		return whole
	var found: Array[Array] = []
	var plain: String = ""
	var parts: PackedStringArray = line.split(" ")
	for index: int in parts.size():
		var word: String = parts[index]
		var stem: String = word.rstrip(GlyphText.TRAILING)
		var ink: Color = _amount_color(stem)
		if ink.a > 0.0:
			if not plain.is_empty():
				found.append([plain, Color.TRANSPARENT])
			found.append([stem, ink])
			plain = word.substr(stem.length())
		else:
			plain += word
		if index < parts.size() - 1:
			plain += " "
	if not plain.is_empty():
		found.append([plain, Color.TRANSPARENT])
	return found


## The monitor's ink for an effect amount `word` ("+4€", "+3", "×2": MonitorStepRow's
## amount_colour_of), or transparent for any other word (a price, a count, "+" alone).
static func _amount_color(word: String) -> Color:
	var sign_at: int = 1 if word.begins_with("+") else 0
	if sign_at == 0 and word.begins_with(MonitorStepRow.FACTOR_SIGN):
		sign_at = MonitorStepRow.FACTOR_SIGN.length()
	if sign_at == 0 or word.length() <= sign_at or not word[sign_at].is_valid_int():
		return Color.TRANSPARENT
	return MonitorStepRow.amount_colour_of(word, MonitorStepRow.Tone.PLAIN)


## The effect amounts drawn in the text (role_runs(true)), in order: each {"text", "color"}
## (WASTED_INK while wasted, the text's colour on a dark plate).
func _amount_runs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line: Array in _lines:
		for run: Dictionary in line:
			if not GlyphText.is_text(run) or GlyphText.is_role(run):
				continue
			for word: String in str(run["text"]).split(" ", false):
				var stem: String = word.rstrip(GlyphText.TRAILING)
				if _amount_color(stem).a <= 0.0:
					continue
				var ink: Color = _amount_color(stem) if _color.get_luminance() < 0.5 else _color
				found.append({"text": stem, "color": WASTED_INK if not _wasted.is_empty() else ink})
	return found


## The colour a role run of `family` is drawn in: its shade (ROLE_DARKEN darker) under dark ink
## (light paper), its light under light ink (a dark plate); the text's own colour for "" or an
## unknown family.
func _role_color(family: String) -> Color:
	if not _wasted.is_empty():
		return WASTED_INK
	var style: FamilyStyle = _palette.style(family) if not family.is_empty() else null
	if style == null or not style.has_ticket_colours():
		return _color
	return style.shade.darkened(ROLE_DARKEN) if _color.get_luminance() < 0.5 else style.light


## The role runs drawn in the text, in order: copies, each with its "x" and the "color" it is
## drawn in; with `amounts`, its effect amounts instead (_amount_runs).
func role_runs(amounts: bool = false) -> Array[Dictionary]:
	if amounts:
		return _amount_runs()
	var found: Array[Dictionary] = []
	for line: Array in _lines:
		for run: Dictionary in line:
			if GlyphText.is_role(run):
				var drawn: Dictionary = run.duplicate()
				drawn["color"] = _role_color(GlyphText.role_family(run))
				found.append(drawn)
	return found


func _lay_out() -> void:
	for glyph: FamilyGlyph in _glyphs:
		remove_child(glyph)
		glyph.free()
	_glyphs.clear()
	for chip: KeywordChip in _chips:
		remove_child(chip)
		chip.free()
	_chips.clear()
	for word: FamilyWord in _words:
		remove_child(word)
		word.free()
	_words.clear()
	_lines.clear()
	_overflow = false
	var space: float = _text_width(" ")
	var lines: Array[Array] = []
	var line: Array = []
	var x: float = 0.0
	for piece: Array in _pieces():
		var piece_width: float = _piece_width(piece)
		var start: float = x + (space if not line.is_empty() else 0.0)
		if not line.is_empty() and start + piece_width > _room(lines.size()):
			lines.append(line)
			line = []
			start = 0.0
		# A piece wider than its line's room (a long word beside a MORE chip) overflows.
		if start + piece_width > _room(lines.size()) + OVERFLOW_SLACK:
			_overflow = true
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
	if _centred:
		for placed: Array in _lines:
			var shift: float = floorf((_width - _line_end(placed)) / 2.0)
			for run: Dictionary in placed:
				run["x"] = float(run["x"]) + maxf(0.0, shift)
	size = Vector2(_width, _lines.size() * _pitch)
	custom_minimum_size = size
	_add_glyphs()
	queue_redraw()


## A line's room: the width, less the end inset on the last allowed line.
func _room(line: int) -> float:
	return _width - (_end_inset if _max_lines > 0 and line == _max_lines - 1 else 0.0)


## The text's pieces; written, every family run and its trailing punctuation a piece of its own
## (the words glued to it split off), and a family's other words plain text.
func _pieces() -> Array[Array]:
	var found: Array[Array] = GlyphText.pieces(text, _palette, _live)
	if not _written:
		return found
	var split: Array[Array] = []
	for piece: Array in found:
		var rest: Array = []
		for run: Dictionary in piece:
			if GlyphText.is_glyph(run) and str(run["text"]) != str(run["family"]):
				rest.append(GlyphText.text_run(str(run["text"])))
			elif GlyphText.is_glyph(run) and not rest.is_empty():
				for word: String in _joined(rest).split(" ", false):
					split.append([GlyphText.text_run(word)])
				rest = [run]
			else:
				rest.append(run)
		if not rest.all(GlyphText.is_text) or rest.any(GlyphText.is_role):
			split.append(rest)
			continue
		for word: String in _joined(rest).split(" ", false):
			split.append([GlyphText.text_run(word)])
	return _split_at_spaces(split)


## `pieces` with every text run that starts with a space (a keyword chip's next word, "CHAIN
## middle:") split off into its own words, so a line may break after a chip.
static func _split_at_spaces(pieces: Array[Array]) -> Array[Array]:
	var out: Array[Array] = []
	for piece: Array in pieces:
		var kept: Array = []
		for run: Dictionary in piece:
			var spaced: bool = GlyphText.is_text(run) and str(run["text"]).begins_with(" ")
			if not spaced or kept.is_empty():
				kept.append(run)
				continue
			out.append(kept)
			kept = []
			for word: String in str(run["text"]).split(" ", false):
				out.append([GlyphText.text_run(word)])
		if not kept.is_empty():
			out.append(kept)
	return out


static func _joined(runs: Array) -> String:
	var joined: String = ""
	for run: Dictionary in runs:
		joined += str(run["text"])
	return joined


func _add_glyphs() -> void:
	var ascent: float = _font.get_ascent(_font_size)
	var height: float = ascent + _font.get_descent(_font_size)
	for index: int in _lines.size():
		var baseline: float = roundf(index * _pitch + (_pitch - height) / 2.0 + ascent)
		for run: Dictionary in _lines[index]:
			if GlyphText.is_keyword(run):
				_add_chip(run, index)
				continue
			var family: String = str(run["family"])
			if family.is_empty():
				continue
			var style: FamilyStyle = _palette.style(family)
			if _written and style != null:
				_add_word(style, float(run["x"]), index)
				continue
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


func _add_chip(run: Dictionary, line: int) -> void:
	var live_tip: String = GlyphText.run_tip(run) if GlyphText.is_live(run) else ""
	var chip: KeywordChip = KeywordChip.new(str(run["keyword"]), "", live_tip, _chip_padding)
	var top: float = line * _pitch + floorf((_pitch - KeywordChip.HEIGHT) / 2.0)
	chip.position = Vector2(float(run["x"]) + _chip_margin, top)
	chip.tip_below = _tip_below
	chip.tip_anchor = _tip_anchor
	add_child(chip)
	_chips.append(chip)


## A written family's chip, centred down its line on the art's grid (its name centred in it).
func _add_word(style: FamilyStyle, x: float, line: int) -> void:
	var word: FamilyWord = FamilyWord.new(style, _font, _font_size)
	var top: float = (
		line * _pitch + snappedf((_pitch - FamilyWord.HEIGHT) / 2.0, ArtStyle.ART_SCALE)
	)
	word.position = Vector2(x + _chip_margin, top)
	word.tip_below = _tip_below
	word.tip_anchor = _tip_anchor
	word.set_rule_line(text)
	add_child(word)
	_words.append(word)


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
	if GlyphText.is_keyword(run):
		var live: bool = GlyphText.is_live(run)
		var chip: float = KeywordChip.width_for(str(run["keyword"]), false, live, _chip_padding)
		return chip + 2.0 * _chip_margin
	if str(run["family"]).is_empty():
		return _text_width(str(run["text"]))
	var style: FamilyStyle = _palette.style(str(run["family"])) if _written else null
	if style != null:
		return FamilyWord.width_for(style, _font, _font_size) + 2.0 * _chip_margin
	return ArtStyle.FAMILY_GLYPH_SIZE + 2.0 * GLYPH_MARGIN


func _text_width(part: String) -> float:
	return _font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
