class_name MachineBelt
extends Control
## The machine's tray belt (#77, look F; build spec 4.2): the game's rubber belt made small,
## rubber with a slat every 10 art px (charcoal and rubber dark edges), steel rails top and
## bottom, running left toward the register like the shift screen's belt. Its slats scroll by the
## plan's belt travel (MachinePlan.belt_travel, still under reduced motion). Reads only view.plan
## and t.

const SIZE := Vector2(400, 180)
## A slat every SLAT_STEP px: SLAT_EDGE px charcoal then SLAT_EDGE px rubber dark.
const SLAT_STEP := 20
const SLAT_EDGE := 2.0
const BORDER := 2.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _offset: int = 0


func _init() -> void:
	name = "MachineBelt"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the belt at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var travel: float = plan.belt_travel(t) if plan != null else 0.0
	var offset: int = int(StockroomWindow.snap(travel)) % SLAT_STEP
	if offset != _offset:
		_offset = offset
		queue_redraw()


## How far the slats are scrolled left (px, 0 .. SLAT_STEP - 2), for tests.
func scroll_offset() -> int:
	return _offset


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.INK)
	var inner: Rect2 = Rect2(Vector2(BORDER, BORDER), SIZE - Vector2(BORDER, BORDER) * 2.0)
	draw_rect(inner, Palette.RUBBER)
	var x: float = inner.position.x - _offset
	while x < inner.end.x:
		_slat(Rect2(x, inner.position.y, SLAT_EDGE, inner.size.y), Palette.CHARCOAL, inner)
		_slat(
			Rect2(x + SLAT_EDGE, inner.position.y, SLAT_EDGE, inner.size.y),
			Palette.RUBBER_DARK,
			inner
		)
		x += SLAT_STEP
	# The rails: steel top (highlight, light, ink) and bottom (ink, shade).
	var top: float = inner.position.y
	draw_rect(Rect2(inner.position.x, top, inner.size.x, 2), Palette.STEEL_HIGHLIGHT)
	draw_rect(Rect2(inner.position.x, top + 2, inner.size.x, 4), Palette.STEEL_LIGHT)
	draw_rect(Rect2(inner.position.x, top + 6, inner.size.x, 2), Palette.INK)
	var bottom: float = inner.end.y
	draw_rect(Rect2(inner.position.x, bottom - 4, inner.size.x, 2), Palette.INK)
	draw_rect(Rect2(inner.position.x, bottom - 2, inner.size.x, 2), Palette.STEEL_SHADE)


func _slat(rect: Rect2, colour: Color, inside: Rect2) -> void:
	var shown: Rect2 = rect.intersection(inside)
	if shown.size.x > 0.0:
		draw_rect(shown, colour)
