class_name BeltFootprint
extends Control
## An empty slot's footprint on the belt (#80, mock-up B2, step 6): a dashed outline on the belt's
## plane, in the same camera as the belt. Its front edge is the node's bottom edge; its back edge
## is the node's top, with both ends receding to the belt's vanishing point (BeltPanel), so the
## outline leans like the belt's slats wherever its slot stands. A faint mustard fill under a
## dashed mustard-light line, both drawn in code on the 2 px grid. Decor only: it takes no
## clicks (the slot's drop target covers it).

const FILL := Color(Palette.MUSTARD_LIGHT, 0.06)
const LINE := Color(Palette.MUSTARD_LIGHT, 0.6)
## The dashes along the outline, in canvas pixels: DASH on, then GAP off.
const DASH := 8.0
const GAP := 6.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The back edge follows the vanishing point, so a move redraws it.
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	var corners: PackedVector2Array = outline()
	draw_colored_polygon(corners, FILL)
	var pixel: float = ArtStyle.ART_SCALE
	var travelled: float = 0.0
	for index: int in range(corners.size()):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % corners.size()]
		var length: float = from.distance_to(to)
		var along: float = 0.0
		while along < length:
			if fmod(travelled + along, DASH + GAP) < DASH:
				var point: Vector2 = from.lerp(to, along / length).snappedf(pixel)
				draw_rect(Rect2(point - Vector2(pixel, pixel) / 2.0, Vector2(pixel, pixel)), LINE)
			along += pixel
		travelled += length


## The footprint's corners (this node's coordinates): back left, back right, front right, front
## left. The back corners lie on the lines from the front ones to the vanishing point.
func outline() -> PackedVector2Array:
	var vanishing: Vector2 = BeltPanel.vanishing_point(self)
	var front_left: Vector2 = Vector2(0, size.y)
	var front_right: Vector2 = size
	return PackedVector2Array(
		[
			_back(front_left, vanishing),
			_back(front_right, vanishing),
			front_right,
			front_left,
		]
	)


## Where the line from `front` to `vanishing` crosses the node's top edge.
static func _back(front: Vector2, vanishing: Vector2) -> Vector2:
	var t: float = front.y / (front.y - vanishing.y)
	return Vector2(lerpf(front.x, vanishing.x, t), 0.0)
