class_name BoxLane
extends Control
## The boxes riding the belt to their cells and the three gates (#77, look F; build spec 4.2).
## Box i (prize i, reveal order) comes out of the RESTOCK hatch at the lane's right end and rides
## left to its cell (MachinePlan.box_x; cell MachinePlan.cell_of(i, n)), where its prize ticket
## takes over (PrizeTicket shows the box until it opens); the main box or STAMP DAY's tomato-taped
## one, its cell's digit printed on it. Each cell's gate (a mustard pop-up, top and bottom rail)
## goes up once the box before has passed it, so each box stops in its own cell; an unused cell's
## gate stays down (a short draw). The boxes ride in a clipped lane, the gates over it. Reads only
## view.plan and t.

const SIZE := Vector2(388, 176)
## The lane's left edge and top in machine px (RewardMachineView.LANE_POSITION).
const ORIGIN := Vector2(12, 446)
## A box: 54 x 84 art px at 2 px, BOX_TOP px down the lane, its hard shadow SHADOW px.
const BOX := preload("res://art/machine/box.png")
const BOX_STAMP_DAY := preload("res://art/machine/box_stamp_day.png")
const BOX_SIZE := Vector2(108, 168)
const BOX_TOP := 6.0
const SHADOW := 3.0
## The box's cell digit (look_f.js GLYPH5, 5 x 7 art px at 41,14), brown dark.
const DIGIT_AT := Vector2(41, 14)
const GLYPHS: Array[String] = [
	"",
	"..X...XX....X....X....X....X...XXX.",
	".XXX.X...X....X...X...X...X...XXXXX",
	"XXXX.....X....X.XXX.....X....XXXXX.",
]
## A gate stands GATE_LEFT px left of its cell: down, a 6 x 4 stub on each rail; up, a 12 x 20
## pop-up on each rail (top at GATE_UP_TOP, bottom at GATE_BOTTOM_TOP, machine px).
const GATE_LEFT := 9.0
const GATE_DOWN := Vector2(6, 4)
const GATE_UP := Vector2(12, 20)
const GATE_TOP := 446.0
const GATE_DOWN_BOTTOM := 616.0
const GATE_UP_TOP := 444.0
const GATE_UP_BOTTOM := 602.0
## A gate goes up GATE_EARLY_S before the first box clears the curtain; STAMP DAY's stay up until
## STAMP_DAY_HOLD_S after its landing.
const GATE_EARLY_S := 0.3
const STAMP_DAY_HOLD_S := 0.2

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _t: float = 0.0
var _boxes: Control
var _gates: Control


func _init() -> void:
	name = "BoxLane"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boxes = Control.new()
	_boxes.name = "Boxes"
	_boxes.size = SIZE
	_boxes.clip_contents = true
	_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(_boxes)
	_boxes.draw.connect(_draw_boxes)
	add_child(_boxes)
	_gates = Control.new()
	_gates.name = "Gates"
	_gates.size = SIZE
	_gates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gates.draw.connect(_draw_gates)
	add_child(_gates)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the lane at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	_t = t
	_boxes.queue_redraw()
	_gates.queue_redraw()


## The boxes riding at `t`: [prize index, left edge in lane px], for tests.
func riding(t: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var plan: MachinePlan = _plan()
	if plan == null or not plan.has_draw:
		return found
	for index: int in range(plan.n_prizes):
		var x: float = plan.box_x(index, t)
		if x != MachinePlan.NOT_SET:
			found.append(Vector2(index, StockroomWindow.snap(x) - ORIGIN.x))
	return found


## Whether cell `cell`'s gate is up at `t`.
func gate_up(cell: int, t: float) -> bool:
	var plan: MachinePlan = _plan()
	if plan == null or not plan.has_draw:
		return false
	var box: int = -1
	for index: int in range(plan.n_prizes):
		if MachinePlan.cell_of(index, plan.n_prizes) == cell:
			box = index
	if box < 0:
		return false
	var stamp_day: bool = plan.kind == MachineVisit.Kind.STAMP_DAY
	var until: float = INF
	if stamp_day and plan.has_landing:
		until = plan.land + STAMP_DAY_HOLD_S
	elif plan.has_landing:
		until = plan.punch
	if t >= until:
		return false
	if plan.reduced_motion or plan.run_from[0] < 0.0:
		return t >= (0.0 if stamp_day else plan.draw_end)
	var opens: float = plan.run_from[0] - GATE_EARLY_S
	if box > 0 and plan.belt_speed > 0.0:
		var gate_x: float = MachinePlan.CELL_X[cell] - GATE_LEFT
		opens = plan.run_from[box - 1] + (MachinePlan.ENTRY - gate_x + BOX_SIZE.x) / plan.belt_speed
	return t >= opens and t >= plan.draw


## Draws `digit`'s 5 x 7 glyph (GLYPHS) on `item` at `at`, each art pixel `pixel` px.
static func draw_glyph(
	item: CanvasItem, digit: int, at: Vector2, pixel: float, colour: Color
) -> void:
	var grid: String = GLYPHS[clampi(digit, 0, GLYPHS.size() - 1)]
	for index: int in range(grid.length()):
		if grid[index] == "X":
			var cell: Vector2 = Vector2(index % 5, floori(index / 5.0))
			item.draw_rect(Rect2(at + cell * pixel, Vector2(pixel, pixel)), colour)


## Draws a box (main or STAMP DAY's) with cell `cell`'s digit and its hard shadow on `item`, its
## top left at `at`.
static func draw_box(item: CanvasItem, at: Vector2, cell: int, stamp_day: bool) -> void:
	item.draw_rect(Rect2(at + Vector2(SHADOW, SHADOW), BOX_SIZE), Palette.TEAL_BLACK)
	item.draw_texture_rect(BOX_STAMP_DAY if stamp_day else BOX, Rect2(at, BOX_SIZE), false)
	draw_glyph(
		item,
		cell + 1,
		at + DIGIT_AT * StockroomWindow.PIXEL,
		StockroomWindow.PIXEL,
		Palette.BROWN_DARK
	)


func _plan() -> MachinePlan:
	return view.plan if view != null else null


func _draw_boxes() -> void:
	var plan: MachinePlan = _plan()
	if plan == null:
		return
	var stamp_day: bool = plan.kind == MachineVisit.Kind.STAMP_DAY
	for box: Vector2 in riding(_t):
		var cell: int = MachinePlan.cell_of(int(box.x), plan.n_prizes)
		draw_box(_boxes, Vector2(box.y, BOX_TOP), cell, stamp_day)


func _draw_gates() -> void:
	for cell: int in range(MachinePlan.MAX_PRIZES):
		var left: float = MachinePlan.CELL_X[cell] - GATE_LEFT - ORIGIN.x
		if gate_up(cell, _t):
			_gate(Rect2(Vector2(left, GATE_UP_TOP - ORIGIN.y), GATE_UP), true)
			_gate(Rect2(Vector2(left, GATE_UP_BOTTOM - ORIGIN.y), GATE_UP), false)
		else:
			_gates.draw_rect(
				Rect2(Vector2(left, GATE_TOP - ORIGIN.y), GATE_DOWN), Palette.STEEL_DARKEST
			)
			_gates.draw_rect(
				Rect2(Vector2(left, GATE_DOWN_BOTTOM - ORIGIN.y), GATE_DOWN), Palette.STEEL_DARKEST
			)


## A raised gate: mustard with an ink edge and its shade on the rail side (`top`: the bottom).
func _gate(rect: Rect2, top: bool) -> void:
	_gates.draw_rect(rect, Palette.INK)
	var inner: Rect2 = rect.grow(-2.0)
	_gates.draw_rect(inner, Palette.MUSTARD)
	var shade_y: float = inner.end.y - 4.0 if top else inner.position.y
	_gates.draw_rect(Rect2(inner.position.x, shade_y, inner.size.x, 4), Palette.MUSTARD_DARK)
