class_name BeltPanel
extends Control
## The shift screen's conveyor belt (#80, mock-up B2, step 6): the belt's top face in perspective
## (belt_top, baked by tools/belt_art.py: the steel guard at its back with its end caps, the hood,
## the steel frame and the slatted rubber the items stand on), then its front (belt_front, a
## 3-slice: the steel lip, the apron with a bolt between each two of the 7-slot row's tickets,
## and the price rail the tickets clip onto), with the rail's shadow on the counter drawn in code.
## Its size is fixed (ShiftStage.BELT_RECT); the row of slots stands on it as its child. Decor
## only: it takes no clicks.
##
## Every receding edge leans to mock-up B2's one vanishing point (VANISHING_POINT, stage pixels);
## vanishing_point() gives it in any node's coordinates, so the slots' footprints follow it too.

## The vanishing point far above the stage's centre (stage pixels).
const VANISHING_POINT := Vector2(640, -1600)
## The bands, in the belt's coordinates (ShiftStage.BELT_RECT starts at the guard's top): the
## rubber the items stand on (its front width), and the lip overhanging the apron and the rail by
## 2 art px at each end.
const TOP_FACE := Rect2(12, 12, 894, 74)
const LIP := Rect2(0, 86, 918, 14)
const APRON := Rect2(4, 100, 910, 8)
const RAIL := Rect2(4, 108, 910, 68)
const RAIL_SHADOW := Rect2(6, 176, 910, 4)
const RAIL_SHADOW_ALPHA := 0.35
## The art: the top face over the guard's top to the lip, and the front from the lip down.
const TOP_RECT := Rect2(0, 0, 918, 86)
const FRONT_RECT := Rect2(0, 86, 918, 90)
const FRONT_MARGIN := 3
## A bolt head in each gap between two tickets of the 7-slot row (mock-up B2: 118 px past each
## cell's left edge), on the apron.
const BOLT_FIRST := Vector2(136, 102)
const BOLT_PITCH := 128.0
const BOLT_COUNT := 7
const TOP_NAME := &"BeltTop"
const FRONT_NAME := &"BeltFront"

const BELT_TOP := preload("res://art/scenery/belt_top.png")
const BELT_FRONT := preload("res://art/scenery/belt_front.png")
const BELT_BOLT := preload("res://art/scenery/belt_bolt.png")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: TextureRect = UiKit.sprite(BELT_TOP)
	top.name = TOP_NAME
	_place(top, TOP_RECT)
	var front: NinePatchRect = NinePatchRect.new()
	front.name = FRONT_NAME
	front.texture = BELT_FRONT
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.patch_margin_left = FRONT_MARGIN * ArtStyle.ART_SCALE
	front.patch_margin_right = FRONT_MARGIN * ArtStyle.ART_SCALE
	ArtStyle.use_pixel_material(front)
	_place(front, FRONT_RECT)
	for index: int in range(BOLT_COUNT):
		var bolt: TextureRect = UiKit.sprite(BELT_BOLT)
		bolt.name = "Bolt%d" % index
		_place(bolt, Rect2(BOLT_FIRST + Vector2(index * BOLT_PITCH, 0), BELT_BOLT.get_size()))


func _draw() -> void:
	draw_rect(RAIL_SHADOW, Color(Palette.INK, RAIL_SHADOW_ALPHA))


## The rubber top face the items stand on, in the belt's coordinates.
func top_face() -> Rect2:
	return TOP_FACE


## The price rail the tickets clip onto, in the belt's coordinates.
func rail() -> Rect2:
	return RAIL


## The art's parts (the top face, the front and the bolts), in drawing order.
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
