class_name MixedLabel
extends HBoxContainer
## A line of display-font text whose numbers print in the number font (#56): Pixelify's digits
## read poorly ("15" reads as "18"), so every run of a number ("13", "(13/15)", "€4") is its own
## number label between display labels, on one baseline row. Used by the deck view's title and
## its shelf headings.

## A number run: an optional "(" and sign, digits (and "/digits"), an optional ")".
const NUMBER_PATTERN := "\\(?[€+×−]?\\d+(?:/\\d+)?\\)?"

## The whole line's text.
var text: String:
	get:
		return _text

var _text: String = ""
var _font_size: int
var _light: bool
var _color: Color


## A line of `font_size` text: light with an ink outline (`light`), else plain in `color`.
func _init(line: String, font_size: int, light: bool, color: Color = Palette.INK) -> void:
	_font_size = font_size
	_light = light
	_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	set_text(line)


## Rebuilds the line for `line`.
func set_text(line: String) -> void:
	_text = line
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var pattern: RegEx = RegEx.create_from_string(NUMBER_PATTERN)
	var start: int = 0
	for found: RegExMatch in pattern.search_all(line):
		_add(line.substr(start, found.get_start() - start), false)
		_add(found.get_string(), true)
		start = found.get_end()
	_add(line.substr(start), false)


## The labels of the line, in order (for tests and layout checks).
func labels() -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in get_children():
		if child is Label:
			found.append(child as Label)
	return found


## Adds `part` (a number run when `number`). Its edge spaces become fixed gaps: a label may trim
## a trailing space from its width.
func _add(part: String, number: bool) -> void:
	if part.begins_with(" "):
		_add_space()
	if part.strip_edges().is_empty():
		return
	var label: Label = (
		UiKit.number_label(part, _font_size, _light)
		if number
		else UiKit.display_label(part, _font_size, _light)
	)
	if not _light:
		label.add_theme_color_override("font_color", _color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.text = part.strip_edges()
	add_child(label)
	if part.ends_with(" "):
		_add_space()


func _add_space() -> void:
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = ArtStyle.DISPLAY_FONT
	gap.custom_minimum_size.x = (
		font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	)
	add_child(gap)
