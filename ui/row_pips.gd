class_name RowPips
extends Control
## A Double checkout's rows by the quota gauge (#122 part 2, the user's choice of 2026-11-02; under
## the tube since the shift scene polish, stacked from the foot up: `vertical`): one pip per row,
## gold once its row is counted, paper for the row being planned, dim for a row still to come. A
## pip that fills flashes a gold ring for FLASH_SECONDS (none with reduced motion). Hidden on a
## shift of one row (show_rows). Display only.

## A pip: PIP_SIZE px with a BORDER px ink rim, GAP px apart, drawn on the GRID.
const PIP_SIZE := 12.0
const BORDER := 2.0
const GAP := 4.0
const GRID := 2.0
const DONE_COLOR := Palette.GOLD
const CURRENT_COLOR := Palette.PAPER
const LATER_ALPHA := 0.3
const FLASH_SECONDS := 0.45
const FLASH_RING := 4.0

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The pips stand in a column, row 1 at the foot, instead of a row.
var vertical: bool = false

var _rows: int = 0
var _done: int = 0
## Seconds left of the latest filled pip's flash, -1 while none.
var _flash_left: float = -1.0


func _init() -> void:
	name = "RowPips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visible = false
	set_process(false)


## Shows `rows` pips (hidden under 2), the first `done` gold: a newly filled one flashes.
func show_rows(done: int, rows: int) -> void:
	visible = rows >= 2
	var filled: bool = rows == _rows and done > _done
	_rows = rows
	_done = clampi(done, 0, rows)
	var length: float = rows * PIP_SIZE + maxi(rows - 1, 0) * GAP
	custom_minimum_size = Vector2(PIP_SIZE, length) if vertical else Vector2(length, PIP_SIZE)
	var reduced: bool = reduced_motion.is_valid() and bool(reduced_motion.call())
	if filled and not reduced:
		_flash_left = FLASH_SECONDS
		set_process(true)
	queue_redraw()


## The rows counted so far.
func done_count() -> int:
	return _done


func row_count() -> int:
	return _rows


func _process(delta: float) -> void:
	if _flash_left < 0.0:
		set_process(false)
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var top: float = snappedf((size.y - PIP_SIZE) / 2.0, GRID)
	for index: int in range(_rows):
		var pip := Rect2(index * (PIP_SIZE + GAP), top, PIP_SIZE, PIP_SIZE)
		if vertical:
			pip.position = Vector2(0.0, (_rows - 1 - index) * (PIP_SIZE + GAP))
		if index == _done - 1 and _flash_left > 0.0:
			var ring: Rect2 = pip.grow(snappedf(FLASH_RING * _flash_left / FLASH_SECONDS, GRID))
			draw_rect(ring, Color(DONE_COLOR, _flash_left / FLASH_SECONDS))
		draw_rect(pip, Palette.INK)
		var face: Color = Color(CURRENT_COLOR, LATER_ALPHA)
		if index < _done:
			face = DONE_COLOR
		elif index == _done:
			face = CURRENT_COLOR
		draw_rect(pip.grow(-BORDER), face)
