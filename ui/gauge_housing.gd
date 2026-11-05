class_name GaugeHousing
extends Control
## The quota gauge's steel housing and the brass plate under it (mock-up
## docs/art/mockups/shift_scene_polish_v4.html, A1), in the register tower's left margin, so the
## column reads as one machine: at ShiftStage.HOUSING_RECT an ink-outlined steel case, lit on its
## left and shaded on its right, with a riveted cap at its top and its foot and a soft shadow down
## its right, holding the gauge's glass (QuotaMeter at ShiftStage.TUBE_RECT, drawn over it; the
## lap lamp stands over its top cap); at ShiftStage.PLATE_RECT a brass plate with corner rivets and
## an engraved €, which a Double checkout's row pips cover instead (`pips`). It spans the tower's
## left margin from its top (RegisterTower places it at the tower's origin) and draws on the art
## grid. Decor only: it takes no clicks.

## The case's shadow: ink at this alpha, 1 art px right of and under it.
const SHADOW_ALPHA := 0.35
## The caps: the top one CAP_ROWS art px (its first row the steel highlight) over an ink row, the
## foot's FOOT_ROWS art px (lit top row, shaded bottom row) under one.
const CAP_ROWS := 3
const FOOT_ROWS := 4
## The case's rivets, RIVET_INSET art px in from its sides and CAP_RIVET_ROW art px down its
## caps.
const RIVET_INSET := 3
const CAP_RIVET_ROW := 2
## The plate's engraved € (5x7 art px, brass darkest with a mustard-light catch under it).
const EURO: Array[String] = ["..###", ".#...", "####.", ".#...", "###..", ".#...", "..###"]

## A Double checkout's row pips (RowPips on the plate): the € hides while they show.
var pips: RowPips:
	set(value):
		pips = value
		if pips != null and not pips.visibility_changed.is_connected(queue_redraw):
			pips.visibility_changed.connect(queue_redraw)
		queue_redraw()


func _init() -> void:
	name = "GaugeHousing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)


## The case's rect in this control's art px.
func case_rect() -> Rect2i:
	return _art_rect(ShiftStage.HOUSING_RECT)


## The plate's rect in this control's art px.
func plate_rect() -> Rect2i:
	return _art_rect(ShiftStage.PLATE_RECT)


## The plate shows its € (no Double checkout's pips over it).
func shows_euro() -> bool:
	return pips == null or not pips.visible


func _draw() -> void:
	_draw_case(case_rect())
	_draw_plate(plate_rect())


func _draw_case(case: Rect2i) -> void:
	var x: int = case.position.x
	var top: int = case.position.y
	var width: int = case.size.x
	var height: int = case.size.y
	var bottom: int = case.end.y
	_cell(x + 1, top + 1, width, height, Color(Palette.INK, SHADOW_ALPHA))
	_cell(x, top, width, height, Palette.INK)
	# The sides: lit on the left, shaded on the right.
	_cell(x + 1, top + 1, 1, height - 2, Palette.STEEL_LIGHT)
	_cell(x + 2, top + 1, 1, height - 2, Palette.STEEL_PALE)
	_cell(x + width - 3, top + 1, 1, height - 2, Palette.STEEL_SHADE)
	_cell(x + width - 2, top + 1, 1, height - 2, Palette.STEEL_DARK)
	# The top cap, its ink row over the glass.
	_cell(x + 1, top + 1, width - 2, CAP_ROWS, Palette.STEEL_PALE)
	_cell(x + 1, top + 1, width - 2, 1, Palette.STEEL_HIGHLIGHT)
	_cell(x + 1, top + 1 + CAP_ROWS, width - 2, 1, Palette.INK)
	# The foot's cap, under the glass's ink row.
	var foot: int = bottom - 1 - FOOT_ROWS
	_cell(x + 1, foot - 1, width - 2, 1, Palette.INK)
	_cell(x + 1, foot, width - 2, FOOT_ROWS, Palette.STEEL)
	_cell(x + 1, foot, width - 2, 1, Palette.STEEL_LIGHT)
	_cell(x + 1, foot + FOOT_ROWS - 1, width - 2, 1, Palette.STEEL_SHADE)
	for rivet_x: int in [x + RIVET_INSET, x + width - 1 - RIVET_INSET - 1]:
		_rivet(rivet_x, top + CAP_RIVET_ROW)
		_rivet(rivet_x, foot + 1)


func _draw_plate(plate: Rect2i) -> void:
	var x: int = plate.position.x
	var y: int = plate.position.y
	var width: int = plate.size.x
	var height: int = plate.size.y
	_cell(x, y, width, height, Palette.INK)
	_cell(x + 1, y + 1, width - 2, height - 2, Palette.BRASS)
	_cell(x + 1, y + 1, width - 2, 1, Palette.MUSTARD_LIGHT)
	_cell(x + 1, y + 1, 1, height - 2, Palette.MUSTARD)
	_cell(x + 1, y + height - 2, width - 2, 1, Palette.BRASS_DARK)
	_cell(x + width - 2, y + 1, 1, height - 2, Palette.BRASS_DARK)
	for corner: Vector2i in [
		Vector2i(x + 2, y + 2),
		Vector2i(x + width - 3, y + 2),
		Vector2i(x + 2, y + height - 3),
		Vector2i(x + width - 3, y + height - 3),
	]:
		_cell(corner.x, corner.y, 1, 1, Palette.MUSTARD_PALE)
	if not shows_euro():
		return
	var at: Vector2i = Vector2i(
		x + roundi((width - EURO[0].length()) / 2.0), y + roundi((height - EURO.size()) / 2.0)
	)
	_pattern(at + Vector2i.DOWN, Palette.MUSTARD_LIGHT)
	_pattern(at, Palette.BRASS_DARKEST)


## A 2x2 art px rivet: its lit corner top left, its dark one bottom right.
func _rivet(x: int, y: int) -> void:
	_cell(x, y, 2, 2, Palette.STEEL_DARK)
	_cell(x, y, 1, 1, Palette.STEEL_PALE)
	_cell(x + 1, y + 1, 1, 1, Palette.RUBBER_DARK)


func _pattern(at: Vector2i, colour: Color) -> void:
	for row: int in range(EURO.size()):
		for column: int in range(EURO[row].length()):
			if EURO[row][column] == "#":
				_cell(at.x + column, at.y + row, 1, 1, colour)


## `stage_rect` (stage px) in this control's art px.
func _art_rect(stage_rect: Rect2) -> Rect2i:
	var local: Rect2 = Rect2(stage_rect.position - position, stage_rect.size)
	var cell: float = ArtStyle.ART_SCALE
	return Rect2i(Vector2i((local.position / cell).round()), Vector2i((local.size / cell).round()))


func _cell(x: int, y: int, width: int, height: int, colour: Color) -> void:
	if width <= 0 or height <= 0:
		return
	var cell: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(x * cell, y * cell, width * cell, height * cell), colour)
