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
	# The words (and the check when chosen) centred on the face above the ledge, on the 2 px grid.
	var text_width: float = OptionChip.pixel_width(_caption.text, 2)
	var content_width: float = text_width + (CHECK_GAP + CHECK_WIDTH if chosen else 0.0)
	var left: float = 2.0 * floorf((w - content_width) / 4.0)
	var face_top: float = dy + 2.0
	var face_height: float = h - 4.0 - ledge_h
	UiKit.place_pixel_label(_caption, Rect2(left, face_top, text_width, face_height), true)
	if chosen:
		var check_x: float = left + text_width + CHECK_GAP
		var check_top: float = face_top + 2.0 * floorf((face_height - CHECK.size() * 2.0) / 4.0)
		for row: int in CHECK.size():
			for column: int in CHECK[row].length():
				if CHECK[row][column] == "#":
					draw_rect(Rect2(check_x + column * 2, check_top + row * 2, 2, 2), Palette.INK)


## `text`'s width in hard pixel words drawn `scale_factor` times larger, in canvas px.
static func pixel_width(text: String, scale_factor: int) -> float:
	var font: Font = ArtStyle.pixel_display_font()
	return (
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
		* scale_factor
	)


## Gives `key` (an options key: a volume's - / +, REDUCED MOTION's OFF / ON) hard pixel words
## `text` centred on its front face under the top band, as the chips' words, in place of its
## display-font caption; they sink with the face. Returns the words (set_key_caption changes them).
static func pixel_caption(key: RegisterKey, text: String) -> Label:
	key.caption = ""
	var words: Label = UiKit.pixel_label(text, 2, Palette.INK)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(words)
	key.draw.connect(OptionChip.place_key_caption.bind(key, words))
	OptionChip.place_key_caption(key, words)
	return words


## Shows `text` as `key`'s pixel caption (pixel_caption's `words`).
static func set_key_caption(key: RegisterKey, words: Label, text: String) -> void:
	words.text = text
	OptionChip.place_key_caption(key, words)


## Centres `words` on `key`'s front face (the band RegisterKey leaves its own caption), on the
## 2 px grid.
static func place_key_caption(key: RegisterKey, words: Label) -> void:
	var face_rect: Rect2 = key.face_rect()
	var depth: float = RegisterKey.SINK if key.is_sunk() else 0.0
	var top: float = depth + key.band_height()
	var bottom: float = (
		key.size.y + depth - RegisterKey.BOTTOM_MARGIN * ArtStyle.ART_SCALE - RegisterKey.SINK
	)
	var width: float = UiKit.pixel_text_size(words).x
	var left: float = face_rect.position.x + 2.0 * floorf((face_rect.size.x - width) / 4.0)
	UiKit.place_pixel_label(words, Rect2(left, top, width, bottom - top), true)


## A box with its corners cut, in a 2 px ink outline (the mock-up's cutBox).
static func cut_box(item: CanvasItem, rect: Rect2, face: Color, ink: Color = Palette.INK) -> void:
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	item.draw_rect(Rect2(p.x + 2, p.y, s.x - 4, s.y), ink)
	item.draw_rect(Rect2(p.x, p.y + 2, s.x, s.y - 4), ink)
	item.draw_rect(Rect2(p.x + 2, p.y + 2, s.x - 4, s.y - 4), face)
