class_name BeltPanel
extends Control
## The shift screen's conveyor belt (#80, mock-up B2, step 6): the belt's top face in perspective
## (belt_top, baked by tools/belt_art.py: the steel guard at its back with its end caps, the hood,
## the steel frame and the slatted rubber the items stand on), then its front (belt_front, a
## 3-slice: the steel lip, the apron with a bolt between each two of the 7-slot row's tickets,
## and the price rail the tickets clip onto), with the rail's shadow on the counter drawn in code,
## and on the apron under each of the 7-slot row's tickets the chevrons that point the belt's way,
## left toward the register (#83), and on the top face under the row's first cell the scanner's
## glass plate (#86 v6, scanner_plate): the scanner is that cell, so it shows in planning too.
## Its size is fixed (ShiftStage.BELT_RECT); the row of slots stands on it as its child. Decor
## only: it takes no clicks.
##
## Every receding edge leans to mock-up B2's one vanishing point (VANISHING_POINT, stage pixels);
## vanishing_point() gives it in any node's coordinates, so the slots' footprints follow it too.
##
## The belt runs left, toward the register, while the shift is counted (#83, #86 v6): the belt
## ride moves its slats on (scroll) as the row slides one cell toward the scanner, and the top
## face shows the matching baked frame (TOP_FRAMES, one per 2 px step, wrapping after
## SLAT_PITCH). In planning it stands on the frame it stopped on.
##
## A shorter row (#122, a Double checkout's rows of 4) gets a shorter belt (set_cells): its
## right end, end cap and roller come CELL_PITCH px in for each cell under the 7-slot row's
## (the short art tools/belt_art.py bakes, belt_top_c<n>), with the front, the rail's shadow,
## the bolts and the chevrons cut to match; the counter shows past it.

## The vanishing point far above the stage's centre (stage pixels).
const VANISHING_POINT := Vector2(640, -1600)
## The bands, in the belt's coordinates (ShiftStage.BELT_RECT starts at the guard's top): the
## rubber the items stand on (its front width), and the lip overhanging the apron and the rail by
## 2 art px at each end.
const TOP_FACE := Rect2(12, 12, 894, 74)
const LIP := Rect2(0, 86, 918, 14)
const APRON := Rect2(4, 100, 910, 8)
const RAIL := Rect2(4, 108, 910, 80)
const RAIL_SHADOW := Rect2(6, 188, 910, 4)
const RAIL_SHADOW_ALPHA := 0.35
## The guard's lit face (belt_top's rows 4 to 7, where a standee's shadow lies, CheerShadow),
## and the columns the belt's art covers on the counter's top line (ShiftStage.COUNTER_TOP), its
## end caps included: a shadow beside the guard but over them has no floor to fall on.
const GUARD_FACE := Rect2(12, 4, 880, 4)
const FOOT_SPAN := Vector2(10, 896)
## The art: the top face over the guard's top to the lip, and the front from the lip down.
const TOP_RECT := Rect2(0, 0, 918, 86)
const FRONT_RECT := Rect2(0, 86, 918, 102)
const FRONT_MARGIN := 3
## A bolt head in each gap between two tickets of the 7-slot row (the mirrored mock-up B2: 8 px
## before each cell's left edge), on the apron. A wider row (8 or 9 cells: Big basket, Extra
## till) closes its gaps and scales to the 7-slot width (RowStrip), so its bolts and chevrons
## follow its own cells (v1.00, the user's play test of 2026-11-05: at 9 slots they stood at the
## 7-slot places, out of line with the tickets): a bolt centred on each cell's left edge, the
## chevrons centred under each ticket, at the row's pitch (cue_pitch). BOLT_COUNT is the widest
## row's cells.
const BOLT_FIRST := Vector2(8, 102)
const BOLT_PITCH := 128.0
const BOLT_COUNT := 9
## The row's first cell's left edge in the belt's coordinates.
const CELLS_LEFT := ShiftStage.ROW_POSITION.x - ShiftStage.BELT_RECT.position.x
## The 7-slot row's cells, and the shortest belt baked (a shorter row keeps it).
const FULL_CELLS := 7
const MIN_CELLS := 4
const SHORT_TOP := "res://art/scenery/belt_top_c%d.png"
const SHORT_FRAME := "res://art/scenery/belt_top_c%d_scroll/belt_top_c%d_%02d.png"
## The belt's direction cue (the mirrored mock-up B2): three light-steel chevrons pointing left,
## centred under each ticket of the 7-slot row, on the apron, at the bolts' pitch.
const CHEVRONS_FIRST := Vector2(64, 102)
## The scanner's glass plate on the top face under the 7-slot row's first cell (scanner_plate's
## art at its size): its front edge (stage x 356..484 at y 398) and its sides lean to the
## vanishing point; SCANNER_CENTER_X is the cell's middle from the plate's left edge, so a scaled
## row's plate (place_scanner) sits under its own first cell, snapped to the art grid.
const SCANNER_RECT := Rect2(8, 16, 134, 68)
const SCANNER_CENTER_X := 66.0
const SCANNER_NAME := &"ScannerPlate"
const TOP_NAME := &"BeltTop"
const FRONT_NAME := &"BeltFront"

const BELT_TOP := preload("res://art/scenery/belt_top.png")
## The top face's frames as its slats run left (tools/belt_art.py): frame k has them 2k px left
## of BELT_TOP's along the front edge.
const TOP_FRAMES: Array[Texture2D] = [
	BELT_TOP,
	preload("res://art/scenery/belt_top_scroll/belt_top_02.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_04.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_06.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_08.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_10.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_12.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_14.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_16.png"),
	preload("res://art/scenery/belt_top_scroll/belt_top_18.png"),
]
## The slats' pitch along the front edge (tools/belt_art.py's SLAT_PITCH): after it, the frames
## wrap.
const SLAT_PITCH := 20.0
## The most the slats move in one call, under half the pitch, so a fast count never makes them
## seem to run backwards.
const MAX_STEP_PX := 8.0
const BELT_FRONT := preload("res://art/scenery/belt_front.png")
const BELT_BOLT := preload("res://art/scenery/belt_bolt.png")
const BELT_CHEVRONS := preload("res://art/scenery/belt_chevrons.png")
const SCANNER_PLATE := preload("res://art/scenery/scanner_plate.png")

## The top face's sprite, showing TOP_FRAMES[frame()].
var _top: TextureRect
## How far the slats have run left since frame 0 (px along the front edge, within SLAT_PITCH).
var _scrolled: float = 0.0
var _scanner: TextureRect
var _front: NinePatchRect
## The top face's frames for the belt's length (TOP_FRAMES on the full belt).
var _frames: Array[Texture2D] = TOP_FRAMES
var _cells: int = FULL_CELLS


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = UiKit.sprite(BELT_TOP)
	_top.name = TOP_NAME
	_place(_top, TOP_RECT)
	_front = NinePatchRect.new()
	_front.name = FRONT_NAME
	_front.texture = BELT_FRONT
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.patch_margin_left = FRONT_MARGIN * ArtStyle.ART_SCALE
	_front.patch_margin_right = FRONT_MARGIN * ArtStyle.ART_SCALE
	ArtStyle.use_pixel_material(_front)
	_place(_front, FRONT_RECT)
	for index: int in range(BOLT_COUNT):
		var bolt: TextureRect = UiKit.sprite(BELT_BOLT)
		bolt.name = "Bolt%d" % index
		_place(bolt, Rect2(Vector2.ZERO, BELT_BOLT.get_size()))
		var chevrons: TextureRect = UiKit.sprite(BELT_CHEVRONS)
		chevrons.name = "Chevrons%d" % index
		_place(chevrons, Rect2(Vector2.ZERO, BELT_CHEVRONS.get_size()))
	_place_cues(FULL_CELLS)
	_scanner = UiKit.sprite(SCANNER_PLATE)
	_scanner.name = SCANNER_NAME
	_place(_scanner, SCANNER_RECT)


func _draw() -> void:
	var shadow: Rect2 = RAIL_SHADOW
	shadow.size.x -= cut()
	draw_rect(shadow, Color(Palette.INK, RAIL_SHADOW_ALPHA))


## Fits the belt to a row of `cells` cells (at least MIN_CELLS, at most FULL_CELLS): the short
## art, the front, the rail's shadow, and the bolts and chevrons under its tickets only. A wider
## row (up to BOLT_COUNT cells) keeps the full belt, its bolts and chevrons at its own cells.
func set_cells(cells: int) -> void:
	_place_cues(clampi(cells, MIN_CELLS, BOLT_COUNT))
	var fitted: int = clampi(cells, MIN_CELLS, FULL_CELLS)
	if fitted == _cells:
		return
	_cells = fitted
	_frames = TOP_FRAMES if fitted == FULL_CELLS else short_frames(fitted)
	_top.texture = _frames[frame()]
	_front.size.x = FRONT_RECT.size.x - cut()
	queue_redraw()


## Shows the first `shown` bolts and chevrons at a `shown`-cell row's places; the hidden ones wait
## at the widest row's places, on the belt.
func _place_cues(shown: int) -> void:
	for index: int in range(BOLT_COUNT):
		var cells: int = shown if index < shown else BOLT_COUNT
		var bolt: Control = get_node("Bolt%d" % index) as Control
		bolt.position = bolt_at(index, cells)
		bolt.visible = index < shown
		var chevrons: Control = get_node("Chevrons%d" % index) as Control
		chevrons.position = chevrons_at(index, cells)
		chevrons.visible = index < shown


## The distance between two cells' left edges in a row of `cells` cells, in the belt's
## coordinates: BOLT_PITCH up to FULL_CELLS; a wider row's own pitch, scaled as RowStrip scales
## it to the laid-out row's width.
static func cue_pitch(cells: int) -> float:
	if cells <= FULL_CELLS:
		return BOLT_PITCH
	var separation: int = RowStrip.separation_for(cells)
	var natural: float = RowStrip.row_width(cells, separation)
	var factor: float = minf(1.0, RowStrip.row_width(RowStrip.LAID_OUT_SLOTS) / natural)
	return (RowStrip.CELL_SIZE.x + separation) * factor


## Bolt `index`'s top left in a row of `cells` cells (whole pixels): BOLT_FIRST's place before
## its cell up to FULL_CELLS, else centred on its cell's left edge.
static func bolt_at(index: int, cells: int) -> Vector2:
	if cells <= FULL_CELLS:
		return BOLT_FIRST + Vector2(index * BOLT_PITCH, 0)
	var left: float = CELLS_LEFT + index * cue_pitch(cells)
	return Vector2(roundf(left - BELT_BOLT.get_width() / 2.0), BOLT_FIRST.y)


## Chevrons `index`'s top left in a row of `cells` cells (whole pixels): centred under its
## cell's ticket.
static func chevrons_at(index: int, cells: int) -> Vector2:
	if cells <= FULL_CELLS:
		return CHEVRONS_FIRST + Vector2(index * BOLT_PITCH, 0)
	var factor: float = cue_pitch(cells) / (RowStrip.CELL_SIZE.x + RowStrip.separation_for(cells))
	var centre: float = (
		CELLS_LEFT + (index * cue_pitch(cells)) + RowStrip.CELL_SIZE.x * factor / 2.0
	)
	return Vector2(roundf(centre - BELT_CHEVRONS.get_width() / 2.0), CHEVRONS_FIRST.y)


## The cells the belt is fitted to (set_cells).
func cell_count() -> int:
	return _cells


## How far in (px) the belt's right end is from the full belt's.
func cut() -> float:
	return cut_of(_cells)


static func cut_of(cells: int) -> float:
	return (FULL_CELLS - clampi(cells, MIN_CELLS, FULL_CELLS)) * BOLT_PITCH


## The short belt's top face frames for a row of `cells` cells (tools/belt_art.py).
static func short_frames(cells: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = [load(SHORT_TOP % cells) as Texture2D]
	for index: int in range(1, TOP_FRAMES.size()):
		frames.append(load(SHORT_FRAME % [cells, cells, index * ArtStyle.ART_SCALE]) as Texture2D)
	return frames


## Runs the slats `px` further left (at most MAX_STEP_PX; never back) and shows their frame.
func scroll(px: float) -> void:
	_scrolled = fposmod(_scrolled + clampf(px, 0.0, MAX_STEP_PX), SLAT_PITCH)
	_top.texture = _frames[slat_frame(_scrolled)]


## The top face's frame (an index into TOP_FRAMES): 0 on a belt that never ran.
func frame() -> int:
	return slat_frame(_scrolled)


## The frame for slats that have run `scrolled_px` left: one per 2 px step, wrapping after
## SLAT_PITCH.
static func slat_frame(scrolled_px: float) -> int:
	return posmod(floori(scrolled_px / ArtStyle.ART_SCALE), TOP_FRAMES.size())


## The rubber top face the items stand on, in the belt's coordinates.
func top_face() -> Rect2:
	return Rect2(TOP_FACE.position, TOP_FACE.size - Vector2(cut(), 0))


## The price rail the tickets clip onto, in the belt's coordinates.
func rail() -> Rect2:
	return Rect2(RAIL.position, RAIL.size - Vector2(cut(), 0))


## Puts the scanner's plate under the row's first cell, whose middle is at `cell_center_x` (the
## belt's coordinates, the row at rest): snapped to the art grid, never past the belt's left end.
func place_scanner(cell_center_x: float) -> void:
	var left: float = snappedf(cell_center_x - SCANNER_CENTER_X, ArtStyle.ART_SCALE)
	_scanner.position.x = maxf(left, 0.0)


## The scanner's plate in the belt's coordinates.
func scanner_rect() -> Rect2:
	return Rect2(_scanner.position, _scanner.size)


## The art's parts (the top face, the front, the bolts and the chevrons, then the scanner's
## plate), in drawing order.
func art() -> Array[Control]:
	var parts: Array[Control] = []
	for child: Node in get_children():
		if child.has_meta(ArtStyle.PIXEL_ART_META):
			parts.append(child as Control)
	return parts


## The vanishing point in `item`'s coordinates: through the belt it stands on, or, off a belt
## (a row built alone), as if its row stood at ShiftStage.ROW_POSITION.
static func vanishing_point(item: CanvasItem) -> Vector2:
	var node: Node = item
	while node != null and not node is BeltPanel:
		node = node.get_parent()
	var belt: BeltPanel = node as BeltPanel
	if belt != null:
		var to_belt: Transform2D = (
			belt.get_global_transform().affine_inverse() * item.get_global_transform()
		)
		return to_belt.affine_inverse() * (VANISHING_POINT - ShiftStage.BELT_RECT.position)
	var row: Control = item as Control
	var origin: Vector2 = ShiftStage.ROW_POSITION
	while row != null and not row is RowStrip:
		row = row.get_parent() as Control
	var to_row: Transform2D = Transform2D.IDENTITY
	if row != null:
		to_row = row.get_global_transform().affine_inverse() * item.get_global_transform()
	return to_row.affine_inverse() * (VANISHING_POINT - origin)


func _place(part: Control, rect: Rect2) -> void:
	part.position = rect.position
	part.size = rect.size
	add_child(part)
