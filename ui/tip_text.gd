class_name TipText
extends Control
## A hover tip's text (the hover tips revamp, mock-up docs/art/mockups/hover_tips.html, design B):
## TipMarkup runs flowed into lines `width` wide, a line pitch apart, a line breaking only at a
## space. Words are drawn in the body font at `weight`; money gained bold green dark, nothing
## (0€) tomato dark, counts teal shade; a multiplier is the amber pill (ink outline, as the
## checkout's × burst); a keyword is its ticket chip (KeywordChip, tomato with a cross when it is
## not working) and a family its chip with its dot (FamilyWord), so a tip shows them exactly as the
## tickets do; a boxed word is underlined in mustard. A pill or chip is glued to what touches it
## (punctuation, no space between), so a comma never starts a line, and an amount that ends the
## text keeps to the word before it, as over a no-break space (v1.36, polish audit: "quota" then
## "+10%" alone on the last line). Its chips are out of
## the tip targets' group: hovering them inside a tip shows nothing more. Display only.

## A pill's ink border and its room each side of its text.
const PILL_BORDER := 2.0
const PILL_PADDING := 3.0
## The boxed word's underline: its thickness and its gap under the baseline.
const UNDERLINE := 2.0
const UNDERLINE_GAP := 2.0
## A chip's room each side on its line.
const CHIP_MARGIN := 1.0
const LINE_FACTOR := 1.3
## The amounts that never end the text alone on a line (see the class comment).
const AMOUNTS: Array[TipMarkup.Run] = [
	TipMarkup.Run.MONEY, TipMarkup.Run.ZERO, TipMarkup.Run.COUNT, TipMarkup.Run.PILL
]

## The markup shown.
var text: String = ""
var _font: Font
var _font_size: int
var _color: Color
var _width: float
var _pitch: float
## Each line's items: {"run", "text", "x", "w", "node"}.
var _lines: Array[Array] = []
var _chips: Array[Control] = []


func _init(markup: String, font_size: int, weight: int, color: Color, width: float) -> void:
	name = "TipText"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = markup
	_font = ArtStyle.bold_font(weight)
	_font_size = font_size
	_color = color
	_width = width
	_pitch = pitch_for(font_size)
	_lay_out()


## The line pitch at `font_size` (LINE_FACTOR of it, on the 2 px grid).
static func pitch_for(font_size: int) -> float:
	return ceilf(font_size * LINE_FACTOR / 2.0) * 2.0


func line_count() -> int:
	return _lines.size()


## The width of its widest line.
func used_width() -> float:
	var widest: float = 0.0
	for line: Array in _lines:
		widest = maxf(widest, _line_end(line))
	return widest


## Its chips (keywords and families), for checks.
func chips() -> Array[Control]:
	return _chips


## The words it reads, without the markup.
func plain_text() -> String:
	return TipMarkup.plain(text)


func _lay_out() -> void:
	for chip: Control in _chips:
		chip.queue_free()
	_chips.clear()
	_lines.clear()
	var space: float = _text_width(" ")
	var line: Array = []
	var x: float = 0.0
	for piece: Array in _pieces():
		var piece_width: float = 0.0
		for item: Dictionary in piece:
			piece_width += float(item["w"])
		var lead: float = space if not line.is_empty() else 0.0
		if not line.is_empty() and x + lead + piece_width > _width:
			_lines.append(line)
			line = []
			x = 0.0
			lead = 0.0
		x += lead
		for item: Dictionary in piece:
			var placed: Dictionary = item.duplicate()
			placed["x"] = x
			line.append(placed)
			x += float(item["w"])
	if not line.is_empty():
		_lines.append(line)
	for index: int in range(_lines.size()):
		for item: Dictionary in _lines[index]:
			_add_chip(item, index)
	size = Vector2(_width, _lines.size() * _pitch)
	custom_minimum_size = size
	queue_redraw()


## The runs cut into unbreakable pieces (see the class comment).
func _pieces() -> Array[Array]:
	var pieces: Array[Array] = []
	var spaced: bool = true
	for run: Dictionary in TipMarkup.runs(text):
		var kind: TipMarkup.Run = run["run"]
		if kind == TipMarkup.Run.TEXT:
			var parts: PackedStringArray = str(run["text"]).split(" ")
			for index: int in range(parts.size()):
				if index > 0:
					spaced = true
				var part: String = parts[index]
				if part.is_empty():
					continue
				var item: Dictionary = _item(TipMarkup.Run.TEXT, part, "")
				if spaced or pieces.is_empty():
					pieces.append([item])
				else:
					pieces[pieces.size() - 1].append(item)
				spaced = false
			continue
		var marked: Dictionary = _item(kind, str(run["text"]), str(run["key"]))
		if spaced or pieces.is_empty():
			pieces.append([marked])
		else:
			# Glued to the word it touches (no space between them).
			pieces[pieces.size() - 1].append(marked)
		spaced = false
	if pieces.size() < 2 or pieces[-1].size() != 1:
		return pieces
	var amount: Dictionary = pieces[-1][0]
	if AMOUNTS.has(amount["run"]):
		pieces.pop_back()
		pieces[-1].append(_item(TipMarkup.Run.TEXT, " ", ""))
		pieces[-1].append(amount)
	return pieces


func _item(kind: TipMarkup.Run, words: String, key: String) -> Dictionary:
	return {"run": kind, "text": words, "key": key, "w": _run_width(kind, words, key)}


func _run_width(kind: TipMarkup.Run, words: String, key: String) -> float:
	match kind:
		TipMarkup.Run.PILL:
			return _text_width(words) + (PILL_BORDER + PILL_PADDING) * 2.0
		TipMarkup.Run.KEYWORD, TipMarkup.Run.KEYWORD_BAD:
			var bad: bool = kind == TipMarkup.Run.KEYWORD_BAD
			return KeywordChip.width_for(words, bad) + CHIP_MARGIN * 2.0
		TipMarkup.Run.FAMILY:
			var style: FamilyStyle = FamilyPalette.shared().style(key)
			if style != null:
				return FamilyWord.width_for(style) + CHIP_MARGIN * 2.0
	return _text_width(words)


func _text_width(part: String) -> float:
	return ceilf(_font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x)


func _line_end(line: Array) -> float:
	if line.is_empty():
		return 0.0
	var last: Dictionary = line[line.size() - 1]
	return float(last["x"]) + float(last["w"])


func _add_chip(item: Dictionary, line: int) -> void:
	var kind: TipMarkup.Run = item["run"]
	var chip: Control = null
	if kind == TipMarkup.Run.KEYWORD or kind == TipMarkup.Run.KEYWORD_BAD:
		var bad: String = "x" if kind == TipMarkup.Run.KEYWORD_BAD else ""
		chip = KeywordChip.new(str(item["text"]), bad)
	elif kind == TipMarkup.Run.FAMILY:
		var style: FamilyStyle = FamilyPalette.shared().style(str(item["key"]))
		if style == null:
			return
		chip = FamilyWord.new(style, _font, _font_size)
	if chip == null:
		return
	# Inside a tip, a chip shows what it is and nothing more.
	chip.remove_from_group(TipTarget.GROUP)
	chip.position = Vector2(
		float(item["x"]) + CHIP_MARGIN, line * _pitch + roundf((_pitch - KeywordChip.HEIGHT) / 2.0)
	)
	add_child(chip)
	_chips.append(chip)


func _draw() -> void:
	var height: float = _font.get_ascent(_font_size) + _font.get_descent(_font_size)
	var drop: float = roundf((_pitch - height) / 2.0) + _font.get_ascent(_font_size)
	for index: int in range(_lines.size()):
		var baseline: float = index * _pitch + drop
		for item: Dictionary in _lines[index]:
			_draw_item(item, index * _pitch, baseline)


func _draw_item(item: Dictionary, top: float, baseline: float) -> void:
	var kind: TipMarkup.Run = item["run"]
	var words: String = str(item["text"])
	var x: float = float(item["x"])
	match kind:
		TipMarkup.Run.KEYWORD, TipMarkup.Run.KEYWORD_BAD:
			return  # A chip node.
		TipMarkup.Run.FAMILY:
			if FamilyPalette.shared().style(str(item["key"])) == null:
				_text(words, x, baseline, _color)
		TipMarkup.Run.PILL:
			var box: Rect2 = Rect2(x, top + 1.0, float(item["w"]), _pitch - 2.0)
			draw_rect(box, Palette.INK)
			draw_rect(box.grow(-PILL_BORDER), Palette.MUSTARD)
			_text(words, x + PILL_BORDER + PILL_PADDING, baseline, Palette.INK)
		TipMarkup.Run.MONEY:
			_text(words, x, baseline, Palette.GREEN_DARK)
		TipMarkup.Run.ZERO:
			_text(words, x, baseline, Palette.TOMATO_DARK)
		TipMarkup.Run.COUNT:
			_text(words, x, baseline, Palette.TEAL_SHADE)
		TipMarkup.Run.TERM:
			_text(words, x, baseline, _color)
			var under: float = baseline + UNDERLINE_GAP
			draw_rect(Rect2(x, under, float(item["w"]), UNDERLINE), Palette.MUSTARD)
		_:
			_text(words, x, baseline, _color)


func _text(words: String, x: float, baseline: float, color: Color) -> void:
	draw_string(
		_font, Vector2(x, baseline), words, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color
	)
