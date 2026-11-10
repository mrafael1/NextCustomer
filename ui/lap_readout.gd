class_name LapReadout
extends Control
## The top bar gauge's multiplier (the user's play test of 2026-11-09): from ×2 on, "×N" in the
## chunky pixel digits (PixelWords' CHUNKY sheet, the week glass's and the machine's lettering)
## with a one-cell ink shadow, at the glass's right end (GaugePanel places it on the art grid).
## It grows in three even steps (the user's play test of 2026-11-10: ×2 to ×3 jumped too far and
## nothing grew after): CELLS[0] at ×2, CELLS[1] from ×3 and CELLS[2], as tall as the bar allows,
## from ×5 (CELL_FROM), in whole px, stepped down only when the text and its shadow would not fit
## `room`. As a lap is made it pops: for the
## first half of POP_SECONDS the words stand LIFT px (one art px) higher in the lap ramp's lit
## colour (none under reduced motion; the lift is inside its box, so its rect never grows).
## Silver (QuotaLaps' lap 2 colour) at ×2, gold from ×3, like the lap lamp beside the glass.
## Hidden under ×2 (the lamp's check says the quota is met). Display only.

## The chunky cells (px per font px) and the laps made each one starts at.
const CELLS: Array[int] = [2, 3, 4]
const CELL_FROM: Array[int] = [2, 3, 5]
const FIRST_LAPS := 2
const SHEET := PixelWords.Sheet.CHUNKY
## Drawn one cell down and right under the digits.
const SHADOW := Palette.INK
## The pop's lift (px, one art px) and its length (s); lifted while more than half of it is left.
const LIFT := ArtStyle.ART_SCALE
const POP_SECONDS := 0.3
const TIMES := "×"

## Returns whether to reduce motion; an empty Callable means no.
var reduced_motion: Callable = Callable()
## The widest the readout may be (px); GaugePanel sets it.
var room: float = 64.0
## The "×N" drawn (its top LIFT px down in the box at rest, at the box's top while lifted).
var words: PixelWords

var _laps: int = 0
var _cell: int = CELLS[0]
var _pop: float = 0.0


func _init() -> void:
	name = "LapReadout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	words = PixelWords.new("", SHEET, CELLS[0], Palette.STEEL_LIGHT)
	words.name = "Words"
	words.shadow = SHADOW
	add_child(words)
	_restyle()


## Shows `laps` laps made (hidden under FIRST_LAPS), popping if `popped` and the count grew.
func show_laps(laps: int, popped: bool) -> void:
	var grew: bool = laps > _laps
	_laps = laps
	visible = laps >= FIRST_LAPS
	_cell = _cell_for(laps)
	words.text = text()
	words.cell = _cell
	words.size = words.get_combined_minimum_size()
	size = box_size()
	if popped and grew and visible and not _reduced():
		_pop = 1.0
	_restyle()


## The laps shown (0 hidden).
func shown_laps() -> int:
	return _laps if visible else 0


## The text drawn: "×N".
func text() -> String:
	return TIMES + str(_laps)


## The cell drawn now (px per font px).
func cell() -> int:
	return _cell


## Whether the pop is under way (tests).
func popping() -> bool:
	return _pop > 0.0


## Whether the words stand lifted now (the pop's first half).
func lifted() -> bool:
	return _pop > 0.5


## The digits' height at the cell drawn now (px), without the shadow.
func digits_height() -> float:
	return PixelWords.text_size(text(), SHEET, _cell).y


## The box the words need at their cell: the words, their shadow's cell, and the pop's lift.
func box_size() -> Vector2:
	return PixelWords.text_size(text(), SHEET, _cell) + Vector2(_cell, _cell + LIFT)


func _process(delta: float) -> void:
	if _pop <= 0.0:
		return
	_pop = maxf(0.0, _pop - delta / POP_SECONDS)
	_restyle()


## The words' colour (the ramp's lit colour while lifted, its body otherwise) and their lift.
func _restyle() -> void:
	var ramp: Array[Color] = QuotaLaps.backdrop_ramp(maxi(_laps, FIRST_LAPS) + 1)
	var up: bool = lifted()
	words.color = ramp[0] if up else ramp[1]
	words.position = Vector2(0.0, 0.0 if up else float(LIFT))


## The cell for `laps` laps: the last of CELLS whose CELL_FROM they reach, smaller while it would
## overflow room.
func _cell_for(laps: int) -> int:
	var index: int = 0
	for step: int in range(CELLS.size()):
		if laps >= CELL_FROM[step]:
			index = step
	while index > 0:
		var cell_px: int = CELLS[index]
		if PixelWords.text_size(TIMES + str(laps), SHEET, cell_px).x + cell_px <= room:
			break
		index -= 1
	return CELLS[index]


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
