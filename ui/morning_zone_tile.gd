class_name MorningZoneTile
extends BeltFootprint
## One slot's patch of the MORNING ZONE's print on the belt (2026-11-18, MorningBand; in place of
## v1.24's pins and chain): the belt's first slots (MorningZone.slots, balance data) are the zone,
## and a Breakfast item standing there is a MORNING item. The patch lies on its cell's belt, under
## the footprint, the item and the lane, from the cell's left gap's middle to its right gap's, so
## the zone's patches join into one band; its sides lean to the belt's vanishing point as the
## footprints do (BeltFootprint.outline). A sunrise: a painted mustard strip along the belt's
## front edge, in front of the items' feet (it shows with an item on the slot too), an orange glow
## over it fading into a faint warm wash up the belt; the zone's ends and back are closed by a
## thin line (`first`, `last`). `counts` (a MORNING item stands on the slot) turns its strip gold
## and its wash warmer; `hot` (a MORNING tooltip shows) the whole band's strip gold.
## Everything is drawn in code on the 2 px art grid. Decor only: it takes no clicks.

## The patch in its cell (RowStrip.CELL_SIZE): from behind the footprint to the belt's front lip.
const TOP := 74.0
const BOTTOM := 142.0
## The painted strip along the front, and the glow's steps over it (each: height, colour).
const STRIP := 16.0
const STRIP_COLOR := Palette.MUSTARD_DARK
const STRIP_COUNTS := Palette.GOLD
const STRIP_HOT := Palette.MUSTARD_PALE
const GLOW_STEPS: Array[float] = [6.0, 8.0, 10.0]
const GLOW_COLORS: Array[Color] = [
	Color(Palette.ORANGE_LIGHT, 0.4),
	Color(Palette.ORANGE_LIGHT, 0.24),
	Color(Palette.MUSTARD, 0.16)
]
const WASH := Color(Palette.MUSTARD_LIGHT, 0.08)
## A counting slot's glow and wash are this much stronger.
const COUNTS_BOOST := 1.6
const EDGE := Color(Palette.MUSTARD, 0.75)
const EDGE_HOT := Palette.GOLD

## The slot it lies on (0-based), and whether it is the zone's first or last patch.
var slot: int = -1
var first: bool = false
var last: bool = false
var _counts: bool = false
var _hot: bool = false


func _init(tile_slot: int) -> void:
	super()
	slot = tile_slot
	name = "MorningZoneTile"


## The patch's rect in its cell, the cells `separation` px apart.
static func cell_rect(separation: float) -> Rect2:
	var half: float = separation / 2.0
	return Rect2(-half, TOP, RowStrip.CELL_SIZE.x + separation, BOTTOM - TOP)


## A MORNING item stands on the slot (or left it).
func set_counts(counting: bool) -> void:
	if _counts != counting:
		_counts = counting
		queue_redraw()


func counts() -> bool:
	return _counts


## A MORNING tooltip shows (or went).
func set_hot(hot: bool) -> void:
	if _hot != hot:
		_hot = hot
		queue_redraw()


func is_hot() -> bool:
	return _hot


## The strip's colour now.
func strip_color() -> Color:
	if _hot:
		return STRIP_HOT
	return STRIP_COUNTS if _counts else STRIP_COLOR


## The painted strip (global rect): the patch's front STRIP px.
func strip_rect() -> Rect2:
	return get_global_transform() * Rect2(0, size.y - STRIP, size.x, STRIP)


func _draw() -> void:
	var boost: float = COUNTS_BOOST if _counts else 1.0
	draw_colored_polygon(_slice(0.0, size.y - STRIP), _boosted(WASH, boost))
	var bottom: float = size.y - STRIP
	for step: int in range(GLOW_STEPS.size()):
		var top: float = maxf(bottom - GLOW_STEPS[step], 0.0)
		draw_colored_polygon(_slice(top, bottom), _boosted(GLOW_COLORS[step], boost))
		bottom = top
	draw_colored_polygon(_slice(size.y - STRIP, size.y), strip_color())
	var line: Color = EDGE_HOT if _hot else EDGE
	var corners: PackedVector2Array = outline()
	_dots(corners[0], corners[1], line)
	if first:
		_dots(corners[3], corners[0], line)
	if last:
		_dots(corners[1], corners[2], line)


## The patch between the heights `top` and `bottom` (this node's y), its sides on the outline's.
func _slice(top: float, bottom: float) -> PackedVector2Array:
	var corners: PackedVector2Array = outline()
	var high: float = 1.0 - top / size.y
	var low: float = 1.0 - bottom / size.y
	return PackedVector2Array(
		[
			corners[3].lerp(corners[0], high),
			corners[2].lerp(corners[1], high),
			corners[2].lerp(corners[1], low),
			corners[3].lerp(corners[0], low),
		]
	)


## A line of art pixels from `from` to `to`.
func _dots(from: Vector2, to: Vector2, color: Color) -> void:
	var pixel: float = ArtStyle.ART_SCALE
	var length: float = from.distance_to(to)
	var along: float = 0.0
	while along < length:
		var point: Vector2 = from.lerp(to, along / length).snappedf(pixel)
		draw_rect(Rect2(point, Vector2(pixel, pixel)), color)
		along += pixel


static func _boosted(color: Color, boost: float) -> Color:
	return Color(color, minf(color.a * boost, 1.0))
