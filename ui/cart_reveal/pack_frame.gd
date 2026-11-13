class_name PackFrame
extends Control
## The staff room's pack highlight (start v4 B): an optional pale fill, an optional BAR px left
## bar and an optional outline, all in one colour, solid for a picked pack and dashed while it is
## only previewed (or still waiting for the pick). The order sheet's pack lines and the trolley's
## PACK group both use it. Display only.

## The left bar's width and the outline's, in canvas px; the dashes' length.
const BAR := 4.0
const LINE := 2.0
const DASH := 4.0

var color: Color = Palette.TOMATO
var fill: Color = Color.TRANSPARENT
var bar: bool = false
var outline: bool = false
var dashed: bool = false
var line_width: float = LINE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A frame on `parent` over `rect`, in `tint`, solid or `dashed`.
static func add(parent: Control, rect: Rect2, tint: Color, dashed_line: bool) -> PackFrame:
	var frame: PackFrame = PackFrame.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.color = tint
	frame.dashed = dashed_line
	parent.add_child(frame)
	return frame


## The colour of `pack`: its family's face (data/families), else tomato.
static func pack_colour(pack: StarterPackDefinition) -> Color:
	# A local palette, not FamilyPalette.shared().style(...): a chained call has crashed Godot 4.7.
	var palette: FamilyPalette = FamilyPalette.shared()
	var family_style: FamilyStyle = palette.style(pack.family)
	if family_style != null and family_style.has_ticket_colours():
		return family_style.face
	return Palette.TOMATO


## A pale version of `tint` for a highlighted line's fill.
static func pale(tint: Color) -> Color:
	return tint.lerp(Palette.PAPER, 0.72)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if fill.a > 0.0:
		draw_rect(rect, fill)
	if bar:
		if dashed:
			var y: float = 0.0
			while y < size.y:
				draw_rect(Rect2(0, y, BAR, minf(DASH, size.y - y)), color)
				y += DASH * 2.0
		else:
			draw_rect(Rect2(0, 0, BAR, size.y), color)
	if not outline:
		return
	if dashed:
		var inner: Rect2 = rect.grow(-line_width / 2.0)
		var corners: Array[Vector2] = [
			inner.position,
			Vector2(inner.end.x, inner.position.y),
			inner.end,
			Vector2(inner.position.x, inner.end.y),
		]
		for side: int in corners.size():
			draw_dashed_line(
				corners[side], corners[(side + 1) % corners.size()], color, line_width, DASH, false
			)
	else:
		draw_rect(rect.grow(-line_width / 2.0), color, false, line_width)
