class_name OptionChip
extends BaseButton
## A selector chip of the OPTIONS popup (mock-up options_pause.html, KeywordChip's language at
## 2x): a paper chip with a ledge, mustard and sat down with the lamp's check when chosen, pale
## mustard under the mouse. Drawn in code on the 2 px grid.

const HEIGHT := 30.0
const PAD := 12.0
const CHECK_GAP := 8.0
const CHECK_WIDTH := 14.0
## The check (7x5 cells of 2 px).
const CHECK: Array[String] = ["......#", ".....#.", "#...#..", ".#.#...", "..#...."]

## The chip is the setting's value.
var chosen: bool = false:
	set(value):
		chosen = value
		queue_redraw()

var _caption: Label


func _init(text: String) -> void:
	focus_mode = Control.FOCUS_NONE
	_caption = UiKit.pixel_label(text, 2, Palette.INK)
	add_child(_caption)
	var text_width: float = OptionChip.pixel_width(text, 2)
	size = Vector2(PAD + text_width + CHECK_GAP + CHECK_WIDTH + PAD, HEIGHT)
	custom_minimum_size = size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var hot: bool = is_hovered()
	var down: bool = chosen or button_pressed
	var dy: float = 2.0 if down else 0.0
	var h: float = 28.0 if down else 30.0
	var face: Color = (
		Palette.MUSTARD if chosen else (Palette.MUSTARD_PALE if hot else Palette.PAPER)
	)
	var ledge: Color = (
		Palette.MUSTARD_DARK if chosen else (Palette.MUSTARD_LIGHT if hot else Palette.CREAM_SHADE)
	)
	var w: float = size.x
	OptionChip.cut_box(self, Rect2(0, dy, w, h), face)
	if chosen:
		draw_rect(Rect2(2, dy + 2, w - 4, 2), Palette.MUSTARD_LIGHT)
	var ledge_h: float = 2.0 if down else 4.0
	draw_rect(Rect2(2, dy + h - 2 - ledge_h, w - 4, ledge_h), ledge)
	_caption.position = Vector2(PAD, dy + 6)
	if chosen:
		var check_x: float = PAD + OptionChip.pixel_width(_caption.text, 2) + CHECK_GAP
		for row: int in CHECK.size():
			for column: int in CHECK[row].length():
				if CHECK[row][column] == "#":
					draw_rect(Rect2(check_x + column * 2, dy + 10 + row * 2, 2, 2), Palette.INK)


## `text`'s width in hard pixel words drawn `scale_factor` times larger, in canvas px.
static func pixel_width(text: String, scale_factor: int) -> float:
	var font: Font = ArtStyle.pixel_display_font()
	return (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
		* scale_factor
	)


## A box with its corners cut, in a 2 px ink outline (the mock-up's cutBox).
static func cut_box(item: CanvasItem, rect: Rect2, face: Color, ink: Color = Palette.INK) -> void:
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	item.draw_rect(Rect2(p.x + 2, p.y, s.x - 4, s.y), ink)
	item.draw_rect(Rect2(p.x, p.y + 2, s.x, s.y - 4), ink)
	item.draw_rect(Rect2(p.x + 2, p.y + 2, s.x - 4, s.y - 4), face)
