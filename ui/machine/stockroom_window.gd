class_name StockroomWindow
extends Control
## The stockroom behind the order slip (#77, look F; build spec 4.2): the planked wall, the pin
## board, the three bays with their trapdoors, lamps and digits, the runway into the RESTOCK door
## and the mini boxes falling and riding (look_f.js paint(), at 2 px per art px). The bay that
## packs cell c stands at BAY_X + BAY_STEP x (2 - c) (cell 0's bay is the nearest the door, so its
## box goes furthest left); its box falls through the trapdoor at the box's bay pick, rides the
## runway into the door and comes out of the hatch on the belt (BoxLane). The bays refill at the
## landing's restock, with STAMP DAY's boxes when STAMP DAY comes next. It reads only view.plan and
## t: frame(t) keeps t and redraws.
##
## Also the machine parts' shared easing (the page's seg, sm and eOut), so every part eases alike.

const SIZE := Vector2(376, 150)
## Art pixels are 2 px; the window's 2 px ink border, then its half-resolution canvas.
const PIXEL := 2.0
const BORDER := 2.0
## The window's outer ring (look F: 4 px teal darkest around the border).
const RING := 4.0
## The canvas in art px (look F's 186 x 73) and its geometry: the bay frames' top (FT) and floor
## (FL), the runway's top (RW), a waiting box's top (BOX_Y), the bays' width and the runway's left.
const ART := Vector2(186, 73)
const FT := 5.0
const FL := 38.0
const RW := 41.0
const BOX_Y := FL - 30.0
const BAY_W := 38.0
const RUNWAY_X := 58.0
const PLANK_STEP := 12
## A refill drops in from REFILL_FROM over REFILL_S; the bay lamp lights LAMP_LEAD_S before the
## pick; the trapdoor stays open TRAPDOOR_S after the fall; the door is lit DOOR_LEAD_S before a
## box goes through, DOOR_TAIL_S after. Rollers move ROLLER_STEPS px per second while a box rolls.
const REFILL_FROM := -24.0
const REFILL_S := 0.3
const LAMP_LEAD_S := 0.1
const TRAPDOOR_S := 0.15
const DOOR_LEAD_S := 0.3
const DOOR_TAIL_S := 0.15
const ROLLER_STEPS := 30.0
const ROLLER_GAP := 6
## The mini box (22 x 30 art px) and its cell digit (look_f.js DIGIT, drawn in code at 15,6).
const MINI := preload("res://art/machine/mini_box.png")
const MINI_STAMP_DAY := preload("res://art/machine/mini_box_stamp_day.png")
const MINI_SIZE := Vector2(22, 30)
const MINI_DIGIT_AT := Vector2(15, 6)
## Each digit's 3 x 5 grid, row by row ("X" = ink).
const DIGITS: Array[String] = [
	"...............",
	".X.XX..X..X.XXX",
	"XX...X.X.X..XXX",
	"XX...X.X...XXX.",
]

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _t: float = 0.0


func _init() -> void:
	name = "StockroomWindow"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the stockroom at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	_t = t
	queue_redraw()


## Whether bay `cell`'s lamp is lit at `t` (from just before its pick until it is restocked).
func lamp_lit(cell: int, t: float) -> bool:
	var plan: MachinePlan = _plan()
	if plan == null or not plan.has_draw or not _used(plan, cell):
		return false
	var pick: float = _pick(plan, cell)
	return (
		t >= pick - (0.0 if plan.reduced_motion else LAMP_LEAD_S) and not _restocked(plan, cell, t)
	)


## Whether a box is riding the runway under the bays at `t` (the rollers turn then).
func rolling(t: float) -> bool:
	var plan: MachinePlan = _plan()
	if plan == null:
		return false
	for cell: int in range(MachinePlan.MAX_PRIZES):
		if _on_runway(plan, cell, t):
			return true
	return false


## Where bay `cell`'s box is at `t`, in art px from the canvas's top left: waiting in its bay,
## falling, on the runway, refilling; Vector2.INF when the bay is empty (or the box is through
## the door).
func box_at(cell: int, t: float) -> Vector2:
	var plan: MachinePlan = _plan()
	var bay: float = bay_x(cell) + MachinePlan.BAY_INSET
	if plan == null or not plan.has_draw or not _used(plan, cell):
		return Vector2(bay, BOX_Y)
	if _restocked(plan, cell, t):
		return Vector2(bay, _refill_y(plan, cell, t))
	var pick: float = _pick(plan, cell)
	if t < pick:
		return Vector2(bay, BOX_Y)
	var fall: float = 0.0 if plan.reduced_motion else plan.fall
	if t < pick + fall:
		var q: float = (t - pick) / fall
		return Vector2(bay, roundf(BOX_Y + (RW - BOX_Y) * q * q))
	if _on_runway(plan, cell, t):
		return Vector2(roundf(bay + (t - pick - fall) * plan.runway_speed), RW)
	return Vector2.INF


## The bay that packs cell `cell` (art px from the canvas's left).
static func bay_x(cell: int) -> float:
	return MachinePlan.BAY_X + MachinePlan.BAY_STEP * (2 - cell)


## The page's seg(): `t`'s progress from `a` to `b`, clamped to 0..1 (a step when b <= a).
static func seg(t: float, a: float, b: float) -> float:
	if b <= a:
		return 1.0 if t >= a else 0.0
	return clampf((t - a) / (b - a), 0.0, 1.0)


## The page's sm(): smoothstep.
static func smooth(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


## The page's eOut(): quadratic ease out.
static func ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)


## Snaps `value` to the 2 px grid.
static func snap(value: float) -> float:
	return roundf(value / PIXEL) * PIXEL


## Draws `digit` (1-3, look_f.js DIGIT, 3 x 5) on `item` at `at` (px), each art pixel `pixel`
## px, in `colour`.
static func draw_digit(
	item: CanvasItem, digit: int, at: Vector2, pixel: float, colour: Color
) -> void:
	var grid: String = DIGITS[clampi(digit, 0, DIGITS.size() - 1)]
	for index: int in range(grid.length()):
		if grid[index] == "X":
			var cell: Vector2 = Vector2(index % 3, floori(index / 3.0))
			item.draw_rect(Rect2(at + cell * pixel, Vector2(pixel, pixel)), colour)


## The region of a mini box's `texture` (in texture px: the box is built at `@scale 2`, so its
## texture is twice MINI_SIZE) drawn for a box at `at` (art px), clipped above `top` and right of
## `right` (art px); the whole texture when nothing is cut.
static func mini_region(texture: Texture2D, at: Vector2, top: float, right: float = INF) -> Rect2:
	var cut_top: float = maxf(0.0, top - at.y)
	var cut_right: float = maxf(0.0, at.x + MINI_SIZE.x - right)
	var texel: Vector2 = texture.get_size() / MINI_SIZE
	var shown: Rect2 = Rect2(Vector2(0, cut_top), MINI_SIZE - Vector2(cut_right, cut_top))
	return Rect2(shown.position * texel, shown.size * texel)


func _plan() -> MachinePlan:
	return view.plan if view != null else null


func _used(plan: MachinePlan, cell: int) -> bool:
	return _box_of(plan, cell) >= 0


## The box (prize index) packed by bay `cell`, or -1 when the draw doesn't use that cell.
func _box_of(plan: MachinePlan, cell: int) -> int:
	for index: int in range(plan.n_prizes):
		if MachinePlan.cell_of(index, plan.n_prizes) == cell:
			return index
	return -1


func _pick(plan: MachinePlan, cell: int) -> float:
	var box: int = _box_of(plan, cell)
	return plan.picks[box] if box >= 0 and box < plan.picks.size() else INF


func _exit(plan: MachinePlan, cell: int) -> float:
	var box: int = _box_of(plan, cell)
	return plan.exits[box] if box >= 0 and box < plan.exits.size() else MachinePlan.NOT_SET


func _on_runway(plan: MachinePlan, cell: int, t: float) -> bool:
	if plan.reduced_motion or not plan.has_draw or not _used(plan, cell):
		return false
	var exit: float = _exit(plan, cell)
	return exit >= 0.0 and t >= _pick(plan, cell) + plan.fall and t < exit


func _restocked(plan: MachinePlan, cell: int, t: float) -> bool:
	return plan.has_landing and cell < plan.restock.size() and t >= plan.restock[cell]


func _refill_y(plan: MachinePlan, cell: int, t: float) -> float:
	var from: float = plan.restock[cell]
	var fill: float = 1.0 if plan.reduced_motion else smooth(seg(t, from, from + REFILL_S))
	return roundf(lerpf(REFILL_FROM, BOX_Y, fill))


func _draw() -> void:
	draw_rect(Rect2(-Vector2(RING, RING), SIZE + Vector2(RING, RING) * 2.0), Palette.BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.INK)
	var plan: MachinePlan = _plan()
	var t: float = _t
	# The back wall, planked; the pin board behind the slip.
	_px(0, 0, ART.x, ART.y, Palette.SLATE_DARK)
	for x: int in range(0, int(ART.x), PLANK_STEP):
		_px(x, 0, 1, ART.y, Palette.SLATE)
	_px(3, 2, 51, 68, Palette.INK)
	_px(4, 3, 49, 66, Palette.BROWN)
	_px(4, 3, 49, 1, Palette.BROWN_LIGHT)
	_px(51, 3, 2, 66, Palette.BROWN_DARK)
	for y: int in range(7, 68, 6):
		for x: int in range(7 + (3 if y % 12 != 0 else 0), 50, 6):
			_px(x, y, 1, 1, Palette.BROWN_DARK)
	_draw_runway(plan, t)
	for cell: int in range(MachinePlan.MAX_PRIZES):
		_draw_bay(plan, cell, t)
	_draw_riding(plan, t)


func _draw_runway(plan: MachinePlan, t: float) -> void:
	_px(RUNWAY_X - 1, RW - 1, ART.x - RUNWAY_X + 1, ART.y - RW + 1, Palette.INK)
	_px(RUNWAY_X, RW, ART.x - RUNWAY_X, ART.y - RW, Palette.CHARCOAL)
	var offset: int = int(floorf(t * ROLLER_STEPS)) % ROLLER_GAP if rolling(t) else 0
	for x: int in range(int(RUNWAY_X) - offset, int(ART.x), ROLLER_GAP):
		if x >= int(RUNWAY_X):
			_px(x, ART.y - 2, 3, 1, Palette.STEEL_PALE)
	_px(RUNWAY_X, ART.y - 1, ART.x - RUNWAY_X, 1, Palette.STEEL_DARK)
	var door: float = MachinePlan.DOOR
	var lit: bool = _door_lit(plan, t)
	_px(door - 2, RW - 1, ART.x - door + 2, ART.y - RW + 1, Palette.INK)
	_px(
		door,
		RW + 1,
		ART.x - door,
		ART.y - RW - 3,
		Palette.MUSTARD_DARK if lit else Palette.RUBBER_DARK
	)
	if lit:
		_px(door, RW + 1, ART.x - door, 2, Palette.MUSTARD)


func _door_lit(plan: MachinePlan, t: float) -> bool:
	if plan == null or not plan.has_draw:
		return false
	for cell: int in range(MachinePlan.MAX_PRIZES):
		var exit: float = _exit(plan, cell)
		if exit >= 0.0 and t >= exit - DOOR_LEAD_S and t < exit + DOOR_TAIL_S:
			return true
	return false


func _draw_bay(plan: MachinePlan, cell: int, t: float) -> void:
	var bx: float = bay_x(cell)
	_px(bx - 1, FT - 1, BAY_W + 2, FL - FT + 4, Palette.INK)
	_px(bx, FT, BAY_W, FL - FT, Palette.CHARCOAL)
	_px(bx, FT, BAY_W, 2, Palette.RUBBER_DARK)
	_px(bx + BAY_W - 2, FT, 2, FL - FT, Palette.RUBBER_DARK)
	_px(bx, FL, BAY_W, 3, Palette.STEEL)
	_px(bx, FL, BAY_W, 1, Palette.STEEL_LIGHT)
	var drawn: bool = plan != null and plan.has_draw and _used(plan, cell)
	if drawn and not plan.reduced_motion:
		var pick: float = _pick(plan, cell)
		if t >= pick and t < pick + plan.fall + TRAPDOOR_S:
			_px(bx + 7, FL, 24, 3, Palette.CHARCOAL)
			_px(bx + 7, FL + 1, 2, 2, Palette.STEEL_DARK)
			_px(bx + 29, FL + 1, 2, 2, Palette.STEEL_DARK)
	var at: Vector2 = box_at(cell, t)
	if at != Vector2.INF and at.y < RW:
		var refill: bool = drawn and _restocked(plan, cell, t)
		var stamp_day: bool = plan != null and plan.kind == MachineVisit.Kind.STAMP_DAY
		if refill:
			stamp_day = plan.next_visit == MachineVisit.Kind.STAMP_DAY
		# A refill drops in from the top of the bay: clipped to the bay's recess.
		_mini(at, cell, stamp_day, FT if refill else -INF)
	var lit: bool = lamp_lit(cell, t)
	_px(bx + 30, FT + 2, 6, 4, Palette.INK)
	_px(bx + 31, FT + 3, 4, 2, Palette.GOOD if lit else Palette.GREY_DARK)
	draw_digit(
		self,
		cell + 1,
		_at(Vector2(bx + 2, FT + 3)),
		PIXEL,
		Palette.MUSTARD_LIGHT if lit else Palette.GREY_DARK
	)


func _draw_riding(plan: MachinePlan, t: float) -> void:
	if plan == null:
		return
	for cell: int in range(MachinePlan.MAX_PRIZES):
		if _on_runway(plan, cell, t):
			_mini(
				box_at(cell, t),
				cell,
				plan.kind == MachineVisit.Kind.STAMP_DAY,
				-INF,
				MachinePlan.DOOR
			)


## A mini box at `at` (art px), clipped above `top` and right of `right` (art px).
func _mini(at: Vector2, cell: int, stamp_day: bool, top: float, right: float = INF) -> void:
	var texture: Texture2D = MINI_STAMP_DAY if stamp_day else MINI
	var source: Rect2 = mini_region(texture, at, top, right)
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	var texel: Vector2 = texture.get_size() / MINI_SIZE
	var shown: Rect2 = Rect2(source.position / texel, source.size / texel)
	draw_texture_rect_region(texture, Rect2(_at(at + shown.position), shown.size * PIXEL), source)
	var digit: Vector2 = at + MINI_DIGIT_AT
	if digit.y >= top and digit.x + 3.0 <= right:
		draw_digit(self, cell + 1, _at(digit), PIXEL, Palette.BROWN_DARK)


## An art pixel position on the canvas, in px.
func _at(art: Vector2) -> Vector2:
	return Vector2(BORDER, BORDER) + art * PIXEL


func _px(x: float, y: float, w: float, h: float, colour: Color) -> void:
	var rect: Rect2 = Rect2(Vector2(x, y), Vector2(w, h)).intersection(Rect2(Vector2.ZERO, ART))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		draw_rect(Rect2(_at(rect.position), rect.size * PIXEL), colour)
