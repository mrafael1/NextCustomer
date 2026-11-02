class_name SlotLane
extends Control
## The express lane on a slot (#132, the 2026-11-02 review of Express lane: a visual "on the
## slot, not only the item"): Express lane pays its factor on the row's first and last open
## slots, so RowStrip marks those slots themselves, beside their express SlotMark. It spans its
## cell (RowStrip.CELL_SIZE, the cell's coordinates) on the cell's talker layer, behind the
## ticket and the item: a light green plate round the ticket on the rail (PLATE_GROW past the
## ticket, an ink edge outside, so the ticket sits in a green frame that never covers its text or
## price), and on the belt a painted lane on the slot's patch (BELT_RECT, leaning to the belt's
## vanishing point like the slot's footprint): a faint green fill inside a solid green line, and
## a row of chevrons along its front, in front of the item's foot, pointing down the belt to the
## scanner. Everything is drawn in code on the 2 px art grid. It rides with its cell in the
## count; fire flashes it when the slot's ×N lands. Decor only: it takes no clicks.

## How far the plate reaches past the ticket on its sides and top, and below it (where the tag
## hangs); its ink edge's width, inside that.
const PLATE_GROW := 6.0
const PLATE_GROW_BOTTOM := 4.0
const PLATE_EDGE := 2.0
const PLATE_COLOR := Palette.GREEN_LIGHT
const PLATE_SHADE := Palette.GREEN_DARK
const EDGE_COLOR := Palette.INK
## The slot's belt patch (cell coordinates): the footprint's, carried to the belt's front lip.
const BELT_RECT := Rect2(6, 84, 104, 58)
const BELT_FILL := Color(Palette.GREEN_LIGHT, 0.2)
const BELT_LINE := Color(Palette.GREEN_LIGHT, 0.85)
## The chevrons along the patch's front: CHEVRONS of them, each CHEVRON_ROWS art px tall, from
## CHEVRON_FRONT px above the patch's front edge, CHEVRON_STEP px apart, centred.
const CHEVRONS := 4
const CHEVRON_ROWS := 7
const CHEVRON_FRONT := 2.0
const CHEVRON_STEP := 22.0
const CHEVRON_COLOR := Palette.GREEN_LIGHT
const CHEVRON_SHADOW := Color(Palette.INK, 0.55)
## The fire: brightened by FLASH, fading back over FIRE_S.
const FLASH := 1.7
const FIRE_S := 0.45
const PAINT_NAME := &"LanePaint"

## The slot it marks (0-based).
var slot: int = -1
var _paint: LanePaint
var _fire_tween: Tween
var _fired: int = 0


func _init(lane_slot: int) -> void:
	slot = lane_slot
	name = "SlotLane%d" % slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = RowStrip.CELL_SIZE
	_paint = LanePaint.new()
	_paint.name = PAINT_NAME
	_paint.position = BELT_RECT.position
	_paint.size = BELT_RECT.size
	add_child(_paint)


## The plate round the ticket (this node's coordinates, its ink edge included).
static func plate_rect() -> Rect2:
	var ticket: Rect2 = RowStrip.TICKET_RECT
	return Rect2(
		ticket.position - Vector2(PLATE_GROW, PLATE_GROW),
		ticket.size + Vector2(PLATE_GROW * 2.0, PLATE_GROW + PLATE_GROW_BOTTOM)
	)


## The painted lane on the belt (this node's coordinates).
static func belt_rect() -> Rect2:
	return BELT_RECT


## The slot's ×N landed (BeltRide): a flash fading back on `make_tween`'s tween when given; none
## under `reduced_motion` or out of the tree.
func fire(reduced_motion: bool, make_tween: Callable = Callable()) -> void:
	_fired += 1
	if _fire_tween != null:
		_fire_tween.kill()
		_fire_tween = null
	_flash(1.0)
	if reduced_motion or not is_inside_tree():
		return
	_fire_tween = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_fire_tween.tween_method(_flash, 0.0, 1.0, FIRE_S)


## How many times it fired (for tests).
func fired_count() -> int:
	return _fired


func _flash(progress: float) -> void:
	var bright: float = lerpf(FLASH, 1.0, progress)
	modulate = Color(bright, bright, bright)


func _draw() -> void:
	# The plate: an ink edge, then the green, shaded on the right and bottom; its corners cut by
	# one art pixel, like the tags'.
	var plate: Rect2 = plate_rect()
	var pixel: float = ArtStyle.ART_SCALE
	_cut_rect(plate, pixel, EDGE_COLOR)
	var face: Rect2 = plate.grow(-PLATE_EDGE)
	_cut_rect(face, pixel, PLATE_SHADE)
	_cut_rect(Rect2(face.position, face.size - Vector2(pixel, pixel)), pixel, PLATE_COLOR)


## A rect with its four corner pixels cut, in `color`.
func _cut_rect(rect: Rect2, pixel: float, color: Color) -> void:
	draw_rect(rect.grow_individual(-pixel, 0.0, -pixel, 0.0), color)
	draw_rect(rect.grow_individual(0.0, -pixel, 0.0, -pixel), color)


## The lane painted on the belt: the footprint's leaning outline (BeltFootprint.outline) filled
## faintly and drawn solid, and the chevrons along its front edge.
class LanePaint:
	extends BeltFootprint

	func _draw() -> void:
		var corners: PackedVector2Array = outline()
		draw_colored_polygon(corners, BELT_FILL)
		var pixel: float = ArtStyle.ART_SCALE
		for index: int in range(corners.size()):
			var from: Vector2 = corners[index]
			var to: Vector2 = corners[(index + 1) % corners.size()]
			var length: float = from.distance_to(to)
			var along: float = 0.0
			while along < length:
				var point: Vector2 = from.lerp(to, along / length).snappedf(pixel)
				draw_rect(
					Rect2(point - Vector2(pixel, pixel) / 2.0, Vector2(pixel, pixel)), BELT_LINE
				)
				along += pixel
		var rows: int = CHEVRON_ROWS
		var top: float = size.y - CHEVRON_FRONT - rows * pixel
		var span: float = CHEVRON_STEP * (CHEVRONS - 1)
		var first: float = snappedf((size.x - span) / 2.0, pixel)
		for chevron: int in range(CHEVRONS):
			var tip: float = first + chevron * CHEVRON_STEP - pixel * 2.0
			for row: int in range(rows):
				# A < three art px thick: its tip in the middle row.
				var lean: float = absf(row - (rows - 1) / 2.0) * pixel
				var at: Vector2 = Vector2(tip + lean, top + row * pixel)
				var stroke: Rect2 = Rect2(at, Vector2(pixel * 3.0, pixel))
				draw_rect(Rect2(stroke.position + Vector2(0, pixel), stroke.size), CHEVRON_SHADOW)
				draw_rect(stroke, CHEVRON_COLOR)
