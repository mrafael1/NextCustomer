class_name ToyLed
extends Control
## An LED at the TOY MACHINES (#121): a wall-mounted readout (v0.78, ToyExitArt.housing: a
## screwed steel rim round a slate face dotted like an LED matrix) sized round its rows of pixel
## lettering (PixelLine). The COINS and FIGURINES readouts are one-row LEDs; the strip over the
## floor holds the hint, the notices and COLLECTION COMPLETE. Every row is centred between the
## paddings; the LED is as wide as its widest row and the paddings. Sizes are in art px.

var _housing: TextureRect
var _rows: Array[PixelLine] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_housing = UiKit.sprite(null)
	add_child(_housing)


## Shows `lines` (one PixelLine per row, their cap tops at `cap_tops` art px from the LED's top),
## `height` art px tall, with `padding` art px (left, right) round the widest row. Returns the
## LED's width in canvas px.
func show_rows(
	lines: Array[PixelLine], cap_tops: Array[int], height: int, padding: Vector2i
) -> float:
	for row: PixelLine in _rows:
		remove_child(row)
		row.free()
	_rows = lines
	var art: float = ArtStyle.ART_SCALE
	var widest: float = 0.0
	for row: PixelLine in lines:
		widest = maxf(widest, row.width())
	var width: float = ceilf(widest / art) * art + (padding.x + padding.y) * art
	size = Vector2(width, height * art)
	_housing.texture = ToyExitArt.housing(Vector2i(roundi(width / art), height))
	_housing.size = size
	for index: int in lines.size():
		var row: PixelLine = lines[index]
		var left: float = padding.x * art + floorf((widest - row.width()) / 2.0 / art) * art
		row.position = Vector2(left, cap_tops[index] * art)
		add_child(row)
	return width


func rows() -> Array[PixelLine]:
	return _rows


## The rows' text, one row a line.
func text() -> String:
	var lines: PackedStringArray = []
	for row: PixelLine in _rows:
		lines.append(row.text())
	return "\n".join(lines)
