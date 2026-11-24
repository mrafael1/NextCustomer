class_name PuzzleOverlay
extends Control
## A puzzle shift's overlay (#183 polish, play test 2026-11-23: "the free space on the right"):
## a teal plate drawn on the art grid (ArtPen) in the room right of the belt's end, from the
## short belt's cut (BeltPanel.cut_of) to the stage's right edge, on the counter's front. It reads
## the puzzle's pack (teal light capitals), PUZZLE n (chunky, as big as the room takes) and the
## puzzle's title (hard Pixelify, wrapped), over its keys: BOARD as an icon key (the puzzle board
## in small, icons/puzzle_board.png) and a small RETRY (the belt back as it was checked out).
## A wide room puts the keys side by side; a narrow one (a 6-slot belt) stacks them. The words
## stand centred in the plate's height above the keys (polish 5). RETRY wears mustard (try again;
## frames/button_mustard.png). A completed pack's puzzle (polish 5) shows the plate in gold, as
## the board's gold-foil cards: a gold face over brass, brass words, the gold check, BOARD on the
## gold button; the solve that completes the pack turns it gold before the player's eyes
## (go_gold: a paper shine sweeps across in GOLD_STEP art px steps over GOLD_TIME and the plate
## turns gold behind it, its words when it passes their middle; at once when `still`). Display
## and input only: PuzzleFlow acts on the signals; after a count the big verdict keys
## (PuzzleVerdictKeys) take over RETRY.

signal retry_pressed
signal board_pressed

## The room's top and bottom on the stage (canvas px): under the store's floor line, above the
## baskets' tops; its right edge, and the gap kept from the belt's end and the stage's edge.
const ROOM_TOP := 300.0
const ROOM_BOTTOM := 536.0
const ROOM_RIGHT := 1266.0
const ROOM_GAP := 14.0
## The widest the plate grows (canvas px): a short belt's room is wider; the plate is centred.
const MAX_WIDTH := 300.0
## The plate's inner margin and its lines' tops (art px).
const PAD := 6.0
## A narrow plate's keys come closer to its sides (art px).
const STACKED_PAD := 2.0
const PACK_TOP := 7.0
const NUMBER_TOP := 16.0
const LINE_GAP := 5.0
const TITLE_LINE := 10.0
const NUMBER_TEXT := "PUZZLE %d"
## The keys (canvas px): the BOARD icon key and RETRY, KEY_GAP apart, PAD art px off the
## plate's foot.
const KEY_HEIGHT := 48.0
const BOARD_WIDTH := 64.0
## The small RETRY's widest (a wide plate centres the pair).
const RETRY_WIDTH := 112.0
const KEY_GAP := 8.0
const KEY_FONT := 16
const RETRY_TEXT := "RETRY"
const BOARD_NAME := "BOARD"
const KEY_FRAME := preload("res://art/frames/button_teal.png")
const RETRY_FRAME := preload("res://art/frames/button_mustard.png")
const GOLD_FRAME := preload("res://art/frames/button_gold.png")
const GOLD_CHECK := preload("res://art/icons/mark_check_gold.png")
const BOARD_ICON := preload("res://art/icons/puzzle_board.png")
## The words' block: the pack's capitals CAPS_HEIGHT tall, a title line's capitals TITLE_HEIGHT
## tall (art px); the block is centred between the plate's top row (BLOCK_TOP_ROW) and the keys'
## plinth (KEYS_GAP above the keys).
const CAPS_HEIGHT := 5.0
const TITLE_HEIGHT := 7.0
const BLOCK_TOP_ROW := 2.0
const KEYS_GAP := 3.0
## go_gold's sweep across the plate (art px), in GOLD_STEP steps over GOLD_TIME: a GOLD_BAND art
## px paper band leading GOLD_TRAIL art px of mustard pale.
const GOLD_TIME := 0.6
const GOLD_STEP := 4.0
const GOLD_BAND := 3.0
const GOLD_TRAIL := 2.0
const GOLD_SOUND := "ding"

var _number: int = 0
var _pack: String = ""
var _title: String = ""
var _pen: ArtPen
var _retry: FramedButton
var _board: FramedButton
## The plate is gold left of this x (art px): 0 all teal, INF all gold.
var _gold_x: float = 0.0
var _gold_tween: Tween


func _init() -> void:
	name = "PuzzleOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_pen = ArtPen.new(self)
	_board = UiKit.framed_button(self, "", board_pressed.emit, KEY_FONT, KEY_FRAME)
	_board.set_icon(BOARD_ICON, BOARD_ICON.get_size() * ArtStyle.ART_SCALE)
	_board.accessibility_name = BOARD_NAME
	_retry = UiKit.framed_button(self, RETRY_TEXT, retry_pressed.emit, KEY_FONT, RETRY_FRAME)
	fit(0.0)


## Shows puzzle `puzzle` (its place `number` in its pack, counted from 1, and the pack's name);
## `golden`: its pack is complete (the gold plate).
func show_puzzle(
	puzzle: PuzzleDefinition, number: int, pack_title: String, golden: bool = false
) -> void:
	_number = number
	_pack = pack_title
	_title = puzzle.title
	if _gold_tween != null:
		_gold_tween.kill()
	_gold_x = INF if golden else 0.0
	_board.set_frame(GOLD_FRAME if golden else KEY_FRAME)
	_lay_out()


## The pack was just completed: the plate turns gold behind a sweeping shine, with a ding (at once
## and silent when `still`). Returns the sweep's tween (null when still).
func go_gold(still: bool) -> Tween:
	if _gold_tween != null:
		_gold_tween.kill()
	_board.set_frame(GOLD_FRAME)
	if still:
		_set_gold(INF)
		return null
	_gold_tween = create_tween()
	_gold_tween.tween_callback(Sfx.play_at.bind(self, GOLD_SOUND, 0.0))
	var w: float = size.x / ArtStyle.ART_SCALE
	_gold_tween.tween_method(_set_gold, 0.0, w + GOLD_BAND + GOLD_TRAIL, GOLD_TIME)
	_gold_tween.tween_callback(_set_gold.bind(INF))
	return _gold_tween


## Whether the plate is all gold (a completed pack).
func is_golden() -> bool:
	return is_inf(_gold_x)


## Whether go_gold's sweep runs now.
func is_turning_gold() -> bool:
	return _gold_tween != null and _gold_tween.is_running()


## Fits the plate to the room right of a belt cut `cut` canvas px short (BeltPanel.cut).
func fit(cut: float) -> void:
	var left: float = ShiftStage.BELT_RECT.end.x - cut + ROOM_GAP
	var room: float = ROOM_RIGHT - ROOM_GAP - left
	var width: float = floorf(minf(room, MAX_WIDTH) / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
	var centred: float = floorf((room - width) / 2.0 / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
	position = Vector2(left + centred, ROOM_TOP)
	size = Vector2(width, ROOM_BOTTOM - ROOM_TOP)
	_lay_out()


## The keys can be pressed (not while the shift is counted); RETRY shows (planning) or not (the
## big verdict keys stand for it).
func set_keys_enabled(enabled: bool) -> void:
	for key: FramedButton in [_retry, _board]:
		key.disabled = not enabled


func show_retry(shown: bool) -> void:
	_retry.visible = shown
	_lay_out()


func retry_key() -> FramedButton:
	return _retry


func board_key() -> FramedButton:
	return _board


## The plate's lines, as drawn: the pack, PUZZLE n and the title.
func pack_text() -> String:
	return _pack


func number_text() -> String:
	return NUMBER_TEXT % _number


func title_text() -> String:
	return _title


## Whether the keys stand one above the other (a narrow room).
func is_stacked() -> bool:
	var keys: float = BOARD_WIDTH + KEY_GAP + _retry.get_combined_minimum_size().x
	return size.x < keys + PAD * 2.0 * ArtStyle.ART_SCALE


func _lay_out() -> void:
	if _retry == null:
		return
	var inner: float = size.x - PAD * 2.0 * ArtStyle.ART_SCALE
	var foot: float = size.y - PAD * ArtStyle.ART_SCALE
	var side: float = PAD * ArtStyle.ART_SCALE
	if is_stacked():
		side = STACKED_PAD * ArtStyle.ART_SCALE
		inner = size.x - side * 2.0
		_retry.size = Vector2(inner, KEY_HEIGHT)
		_retry.position = Vector2(side, foot - KEY_HEIGHT)
		_board.size = Vector2(inner, KEY_HEIGHT)
		_board.position = Vector2(side, foot - KEY_HEIGHT * 2.0 - KEY_GAP)
	else:
		var retry_width: float = minf(inner - BOARD_WIDTH - KEY_GAP, RETRY_WIDTH)
		var pair: float = BOARD_WIDTH + (KEY_GAP + retry_width if _retry.visible else 0.0)
		var left: float = side + floorf((inner - pair) / 4.0) * 2.0  # The keys centred.
		_board.size = Vector2(BOARD_WIDTH, KEY_HEIGHT)
		_board.position = Vector2(left, foot - KEY_HEIGHT)
		_retry.position = Vector2(left + BOARD_WIDTH + KEY_GAP, foot - KEY_HEIGHT)
		_retry.size = Vector2(retry_width, KEY_HEIGHT)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x / ArtStyle.ART_SCALE
	var h: float = size.y / ArtStyle.ART_SCALE
	var face_h: float = _keys_top() - KEYS_GAP
	_draw_plate(w, h, face_h, false)
	var edge: float = minf(_gold_x, w)
	if edge > 0.0:
		_draw_plate(edge, h, face_h, true)
	var middle: float = w / 2.0
	var gold_words: bool = _gold_x >= middle
	if is_golden() and _fits_check(w):
		_pen.tex(GOLD_CHECK, w - 17, 3)
	var top: float = text_top()
	var pack_ink: Color = Palette.BRASS_DARK if gold_words else Palette.TEAL_LIGHT
	_pen.caps(_pack, middle, top, pack_ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var number_ink: Color = Palette.BRASS_DARKEST if gold_words else Palette.PAPER
	var number_top: float = top + NUMBER_TOP - PACK_TOP
	var factor: float = _number_factor()
	if factor > 0.0:
		_pen.chunky(number_text(), middle, number_top, number_ink, factor, 1)
	else:
		_pen.caps(number_text(), middle, number_top, number_ink, 1.0, 1)
	var line: float = number_top + number_height() + LINE_GAP
	var title_ink: Color = Palette.INK if gold_words else Palette.PAPER
	for words: String in title_lines():
		_pen.pix(words, middle, line, title_ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		line += TITLE_LINE
	if not is_golden() and _gold_x > 0.0:
		_draw_shine(minf(_gold_x, w), face_h)


## The words' top (art px): their block (the pack, PUZZLE n, the title's lines) centred between
## the plate's top row and the keys' plinth.
func text_top() -> float:
	var room: float = _keys_top() - KEYS_GAP - BLOCK_TOP_ROW
	return BLOCK_TOP_ROW + floorf(maxf(0.0, room - block_height()) / 2.0)


## The words' block height (art px): the pack, PUZZLE n and the title's lines.
func block_height() -> float:
	var lines: int = title_lines().size()
	var height: float = NUMBER_TOP - PACK_TOP + number_height()
	if lines > 0:
		height += LINE_GAP + (lines - 1) * TITLE_LINE + TITLE_HEIGHT
	return height


## The title's wrapped lines that fit above the keys.
func title_lines() -> PackedStringArray:
	var w: float = size.x / ArtStyle.ART_SCALE
	var room: float = _keys_top() - KEYS_GAP - BLOCK_TOP_ROW - 2.0
	var used: float = NUMBER_TOP - PACK_TOP + number_height() + LINE_GAP
	var lines: PackedStringArray = PackedStringArray()
	for words: String in ArtPen.pix_wrap(_title, w - PAD * 2.0):
		if used + TITLE_HEIGHT > room:
			break
		lines.append(words)
		used += TITLE_LINE
	return lines


## PUZZLE n's height (art px): chunky capitals at twice their size when the plate takes them,
## else once, else the small capitals.
func number_height() -> float:
	var factor: float = _number_factor()
	return 8.0 * factor if factor > 0.0 else CAPS_HEIGHT


## The chunky capitals' scale PUZZLE n takes (2, 1), or 0 for the small capitals.
func _number_factor() -> float:
	var inner: float = size.x / ArtStyle.ART_SCALE - PAD * 2.0
	var chunky_width: float = ArtPen.word_texture(number_text(), Palette.PAPER, true).get_width()
	for factor: float in [2.0, 1.0]:
		if chunky_width * factor <= inner:
			return factor
	return 0.0


## The keys' top (art px from the plate's top).
func _keys_top() -> float:
	return minf(_board.position.y, _retry.position.y) / ArtStyle.ART_SCALE


## The plate from its left to `w` art px: teal, or gold (a completed pack's).
func _draw_plate(w: float, h: float, face_h: float, gold: bool) -> void:
	_pen.rn(0, 0, w, h, Palette.BRASS_DARK if gold else Palette.TEAL_BLACK)
	_pen.rn(0, 0, w, face_h, Palette.GOLD if gold else Palette.TEAL_DARK)
	var row_w: float = minf(w - 2, size.x / ArtStyle.ART_SCALE - 4)
	if row_w > 0:
		_pen.r(2, 1, row_w, 1, Palette.MUSTARD_PALE if gold else Palette.TEAL_SHADE)


## go_gold's light at `x` (art px): a paper band, a mustard pale trail behind it.
func _draw_shine(x: float, face_h: float) -> void:
	var w: float = size.x / ArtStyle.ART_SCALE
	var band_left: float = maxf(1.0, x - GOLD_BAND)
	var band_right: float = minf(w - 1, x)
	if band_right > band_left:
		_pen.r(band_left, 1, band_right - band_left, face_h - 2, Palette.PAPER)
	var trail_left: float = maxf(1.0, band_left - GOLD_TRAIL)
	if band_left > trail_left:
		_pen.r(trail_left, 1, band_left - trail_left, face_h - 2, Palette.MUSTARD_PALE)


func _set_gold(x: float) -> void:
	_gold_x = x if is_inf(x) else floorf(x / GOLD_STEP) * GOLD_STEP
	queue_redraw()


## Whether the gold check fits at the plate's top right, clear of the pack's words.
func _fits_check(w: float) -> bool:
	var words: float = ArtPen.word_texture(_pack, Palette.PAPER, false).get_width()
	return w / 2.0 + words / 2.0 + 2.0 <= w - 17
