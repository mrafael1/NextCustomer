class_name PuzzleHint
extends Control
## A puzzle shift's tip (#183 polish, play test 2026-11-23) in the register column, where a run's
## Redraw key and week glass stand and the puzzle bar stood before its words and keys moved to the
## overlay on the right (PuzzleOverlay): a teal plate drawn on the art grid (ArtPen) as the bar
## was, reading TIP over the puzzle's hint (the one-line idea it teaches, the board clipboard's
## last line) in hard Pixelify, wrapped, at most MAX_LINES lines. The hint starts hidden (polish
## 5, play test 2026-11-23): the plate reads TIP over a SHOW TIP key (teal, pixel frame) whose
## press reveals it; each new puzzle hides it again (a RETRY of the same puzzle keeps it shown).

## The hint was revealed (SHOW TIP).
signal revealed

## Where it stands on the shift stage (canvas px): the bar's place, between the CHECKOUT key and
## the cash drawer.
const RECT := Rect2(20, 508, 296, 104)
const TIP_TEXT := "TIP"
## The words' left, TIP's top and the hint's first line (art px), LINE apart.
const LEFT := 6.0
const TIP_TOP := 6.0
const HINT_TOP := 13.0
const LINE := 9.0
const MAX_LINES := 4
## SHOW TIP (canvas px): its size and its top under the plate's top.
const SHOW_TEXT := "SHOW TIP"
const SHOW_SIZE := Vector2(152, 44)
const SHOW_TOP := 36.0
const SHOW_FONT := 16
const SHOW_FRAME := preload("res://art/frames/button_teal.png")

var _hint: String = ""
var _puzzle_id: StringName = &""
var _shown: bool = false
var _pen: ArtPen
var _show: FramedButton


func _init() -> void:
	name = "PuzzleHint"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_pen = ArtPen.new(self)
	_show = UiKit.framed_button(self, SHOW_TEXT, reveal, SHOW_FONT, SHOW_FRAME, SHOW_SIZE)
	_show.size = SHOW_SIZE
	_show.position = Vector2(floorf((RECT.size.x - SHOW_SIZE.x) / 4.0) * 2.0, SHOW_TOP)


## Shows `puzzle`'s tip plate: its hint hidden behind SHOW TIP, unless it is the puzzle shown
## (a RETRY) and its hint was revealed.
func show_puzzle(puzzle: PuzzleDefinition) -> void:
	if puzzle.id != _puzzle_id:
		_shown = false
	_puzzle_id = puzzle.id
	_hint = puzzle.hint
	_show.visible = not _shown
	queue_redraw()


## SHOW TIP: the hint shows.
func reveal() -> void:
	if _shown:
		return
	_shown = true
	_show.visible = false
	queue_redraw()
	revealed.emit()


## Whether the hint shows (SHOW TIP pressed for this puzzle).
func is_revealed() -> bool:
	return _shown


func show_key() -> FramedButton:
	return _show


## The hint's lines, as drawn.
func lines() -> PackedStringArray:
	var wrapped: PackedStringArray = ArtPen.pix_wrap(_hint, size.x / ArtStyle.ART_SCALE - LEFT * 2)
	return wrapped.slice(0, MAX_LINES)


func _draw() -> void:
	var w: float = size.x / ArtStyle.ART_SCALE
	var h: float = size.y / ArtStyle.ART_SCALE
	_pen.rn(0, 0, w, h, Palette.TEAL_BLACK)
	_pen.rn(0, 0, w, h - 2, Palette.TEAL_DARK)
	_pen.r(2, 1, w - 4, 1, Palette.TEAL_SHADE)
	_pen.caps(TIP_TEXT, LEFT, TIP_TOP, Palette.TEAL_LIGHT)
	if not _shown:
		return
	var top: float = HINT_TOP
	for words: String in lines():
		_pen.pix(words, LEFT, top, Palette.PAPER)
		top += LINE
