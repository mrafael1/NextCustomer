class_name PaydayTrim
extends Control
## Payday's brass trim on the shift screen (the user's picks of 2026-11-10, mock-up
## docs/art/mockups/payday_day.html: round 2's plain "Brass rail"): on a payday shift
## (ReceiptGoldFlow.payday, ShiftStage.show_payday) a 3 art px mustard-brass moulding (MOULDING:
## light outside, the body, dark inside) runs round the hung monitor (MonitorView, outside its
## bezel, in a one art px ink outline), round the receipt's well on the register's tower
## (RegisterTower: a FRAME trim, inside the well's edge, behind the printer, the receipt, the bell
## and the calendar), along the register's top lip (RegisterCabinet: a ROWS trim) and on the belt's
## lip and back guard (BeltPanel). Nothing moves, lights or animates, and no part of the screen
## changes place: the trims only recolour steel and charcoal that is there every day. The brass
## is the mustard ramp, a step under the gold of a GOLDEN item's ring and of the gold medal
## (Palette.GOLD), so they stay apart where they sit close. Hidden on every other day. Display
## only: it takes no clicks.

enum Kind { FRAME, ROWS }

## The moulding's rows from its outer edge in (one art px each).
const MOULDING: Array[Color] = [Palette.MUSTARD_LIGHT, Palette.MUSTARD, Palette.MUSTARD_DARK]
## The register's top lip (its two steel rows), top down.
const LIP_ROWS: Array[Color] = [Palette.MUSTARD_LIGHT, Palette.MUSTARD]
## The belt's lip (its two lit rows and three body rows), top down.
const BELT_LIP_ROWS: Array[Color] = [
	Palette.MUSTARD_PALE,
	Palette.MUSTARD_LIGHT,
	Palette.MUSTARD,
	Palette.MUSTARD,
	Palette.MUSTARD_DARK,
]
## The belt's back guard: each steel of its art and the brass it turns.
const GUARD: Dictionary[Color, Color] = {
	Palette.STEEL_HIGHLIGHT: Palette.MUSTARD_LIGHT,
	Palette.STEEL_LIGHT: Palette.MUSTARD_LIGHT,
	Palette.STEEL: Palette.MUSTARD,
	Palette.STEEL_PALE: Palette.MUSTARD,
	Palette.STEEL_SHADE: Palette.MUSTARD_DARK,
	Palette.STEEL_DARK: Palette.MUSTARD_DARK,
}
const OUTLINE := Palette.INK

var _kind: Kind = Kind.FRAME
var _rows: Array[Color] = []


## A trim named `trim_name` over `rect` (its parent's px): a FRAME (the moulding inside the
## rect's edge) or ROWS (`rows`, one art px each, top down, across the rect). Hidden until its
## owner shows it.
func _init(
	trim_name: String = "PaydayTrim",
	kind: Kind = Kind.FRAME,
	rect: Rect2 = Rect2(),
	rows: Array[Color] = []
) -> void:
	name = trim_name
	_kind = kind
	_rows = rows
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	position = rect.position
	size = rect.size


func _draw() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	if _kind == Kind.FRAME:
		draw_inside(self, area)
	else:
		draw_rows(self, area, _rows)


## The moulding inside `rect`'s edge on `item`'s canvas: three one art px rings, light outermost.
static func draw_inside(item: CanvasItem, rect: Rect2) -> void:
	var p: float = ArtStyle.ART_SCALE
	for depth: int in range(MOULDING.size()):
		var ring: Rect2 = rect.grow(-depth * p)
		var colour: Color = MOULDING[depth]
		item.draw_rect(Rect2(ring.position, Vector2(ring.size.x, p)), colour)
		item.draw_rect(Rect2(ring.position.x, ring.end.y - p, ring.size.x, p), colour)
		item.draw_rect(Rect2(ring.position, Vector2(p, ring.size.y)), colour)
		item.draw_rect(Rect2(ring.end.x - p, ring.position.y, p, ring.size.y), colour)


## The moulding round `rect` on `item`'s canvas, to be drawn under what fills `rect`: an ink
## outline, then the three rings, dark against the rect.
static func draw_round(item: CanvasItem, rect: Rect2) -> void:
	var p: float = ArtStyle.ART_SCALE
	item.draw_rect(rect.grow(reach()), OUTLINE)
	for depth: int in range(MOULDING.size()):
		item.draw_rect(rect.grow((MOULDING.size() - depth) * p), MOULDING[depth])


## How far draw_round's moulding reaches past its rect (px): its rings and its outline.
static func reach() -> float:
	return (MOULDING.size() + 1) * ArtStyle.ART_SCALE


## `rows` (one art px each, top down) across `rect`'s width from its top, on `item`'s canvas.
static func draw_rows(item: CanvasItem, rect: Rect2, rows: Array[Color]) -> void:
	var p: float = ArtStyle.ART_SCALE
	for row: int in range(rows.size()):
		item.draw_rect(Rect2(rect.position.x, rect.position.y + row * p, rect.size.x, p), rows[row])
