class_name PrizeBay
extends Control
## V3's prize bay (v0.96, mock-ups docs/art/mockups/machine_relook_v2.html "V3 polished" and
## machine_relook_v3.html), right of the cabinet's middle pillar (RewardMachineView.BAY_POSITION):
## the prize tickets land here, each on its own pedestal under a spotlight, so the row reads as a
## prize counter. A steel frame (ink, steel dark, ink, a charcoal floor 8 px in; on the night face
## a row of chasing bulbs along its top), an LED header (charcoal with scanlines) whose hard pixel
## line follows the visit: "PRIZE BAY" (teal light) before the draw, "YOUR PRIZES · KEEP 1" (gold)
## once the tickets drop, "GOOD PICK" (gold) after a pick, blank while idle. Under it each ticket's
## lamp (lit mustard pale once the tickets drop) and its dithered cone of light; under each ticket
## a pedestal with a steel lip (brass once the tray turns gold, PREMIUM) and a light strip that
## turns on as its ticket is revealed (reveal_at). Before the draw each slot is a dashed
## placeholder with a "?" and the bay says how many sealed prizes drop here. The floor (a line and
## a grid of ticks) has the SKIP bin's hatch. frame(t) reads only view.plan, t, view.idle_time and
## MachineLook. Display only.

const SIZE := Vector2(500, 508)
## The frame's charcoal floor starts this far in.
const INSET := 8.0
## The night face's bulbs along the frame's top: every BULB_STEP from BULB_LEFT.
const BULB_LEFT := 12.0
const BULB_STEP := 20.0
const BULB_SIZE := Vector2(4, 2)
## The LED header and its words.
const HEADER_RECT := Rect2(8, 8, 484, 30)
const HEADER_WAIT := "PRIZE BAY"
const HEADER_DRAWN := "YOUR PRIZES · KEEP 1"
const HEADER_PICKED := "GOOD PICK"
const SCANLINE_ALPHA := 0.5
## Each slot's lamp under the header, and its cone of light (art px: width CONE_WIDTH +
## CONE_SPREAD per row, CONE_ROWS rows, dots on every other row and column).
const LAMP_SIZE := Vector2(24, 4)
const LAMP_TOP := 40.0
const CONE_TOP := 44.0
const CONE_WIDTH := 14.0
const CONE_SPREAD := 0.42
const CONE_ROWS := 156
## The pedestal under each ticket: GAP below it, PEDESTAL_GROW wider each side, its lip and its
## light strip.
const PEDESTAL_GAP := 8.0
const PEDESTAL_GROW := 6.0
const PEDESTAL_HEIGHT := 12.0
const STRIP_INSET := 8.0
## The placeholder's dashes and "?" before the draw, and the line under the slots.
const DASH := 4.0
const HINT := "%d sealed prizes drop here"
const HINT_SIZE := 12
const HINT_WEIGHT := 700
## The floor: its line (bay y), its ticks every TICK_STEP, and the SKIP bin's hatch.
const FLOOR_Y := 428.0
const TICK_STEP := 32.0
const TICK_LEFT := 20.0
const HATCH_SIZE := Vector2(56, 4)

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _header: MachineLine
var _marks: Array[MachineLine] = []
var _state: Array = []
var _strips: Array[bool] = []
var _n: int = 3
var _drawn: bool = false
var _idle: bool = true
var _gold: bool = false
var _night: bool = false
var _chase: float = 0.0
var _look: MachineLook = MachineLook.new()


func _init() -> void:
	name = "PrizeBay"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = MachineLine.make("Header", "", Palette.TEAL_LIGHT)
	add_child(_header)
	for index: int in range(3):
		var mark: MachineLine = MachineLine.make(
			"Mark%d" % index, "?", Palette.STEEL_DARK, MachineLine.clear(), 2
		)
		mark.visible = false
		add_child(mark)
		_marks.append(mark)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Pedestal `index` of `count`'s rect in the bay: under its ticket (PrizeRow.card_rect).
static func pedestal_rect(index: int, count: int) -> Rect2:
	var card: Rect2 = PrizeRow.card_rect(index, count)
	card.position -= RewardMachineView.BAY_POSITION
	return Rect2(
		card.position.x - PEDESTAL_GROW,
		card.end.y + PEDESTAL_GAP,
		card.size.x + 2.0 * PEDESTAL_GROW,
		PEDESTAL_HEIGHT
	)


## The header's words at `t` on `plan` (null: idle, blank).
static func header_text(plan: MachinePlan, t: float) -> String:
	if plan == null:
		return ""
	if not drawn_at(plan, t):
		return HEADER_WAIT
	if plan.has_landing and t >= plan.press and plan.landing != MachinePlan.Landing.BIN:
		return HEADER_PICKED
	return HEADER_DRAWN


## Whether the tickets have started to drop at `t` (the lamps and cones on).
static func drawn_at(plan: MachinePlan, t: float) -> bool:
	return plan != null and plan.has_draw and plan.n_prizes > 0 and t >= plan.drop_at[0]


## Whether ticket `index`'s pedestal strip is lit at `t`: once it is revealed.
static func strip_lit(plan: MachinePlan, t: float, index: int) -> bool:
	if not drawn_at(plan, t) or index >= plan.n_prizes:
		return false
	return t >= plan.reveal_at[index]


## The header line (hard pixel lettering), for tests.
func header() -> MachineLine:
	return _header


## Which pedestal strips are lit now.
func lit_strips() -> Array[bool]:
	return _strips


## The bay at `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var look: MachineLook = MachineLook.at(plan, t)
	var drawn: bool = drawn_at(plan, t)
	var count: int = plan.n_prizes if drawn else _slots()
	var strips: Array[bool] = []
	for index: int in range(count):
		strips.append(strip_lit(plan, t, index))
	var text: String = header_text(plan, t)
	var chase: float = view.idle_time if view != null else 0.0
	var night: bool = look.night_face()
	var state: Array = [text, drawn, count, strips, look.tray_gold(), night, plan == null]
	if state == _state and not (night and chase != _chase):
		return
	_chase = chase
	if text != _header.text():
		_header.show_text(text, Palette.GOLD if drawn else Palette.TEAL_LIGHT)
		_header.centre_in(HEADER_RECT)
	_state = state
	_drawn = drawn
	_n = count
	_strips = strips
	_gold = look.tray_gold()
	_night = night
	_look = look
	_idle = plan == null
	for index: int in range(_marks.size()):
		var mark: MachineLine = _marks[index]
		mark.visible = not drawn and index < count
		if mark.visible:
			mark.show_text(
				"?", Palette.RUBBER if _idle else Palette.STEEL_DARK, MachineLine.clear(), 2
			)
			var card: Rect2 = PrizeRow.card_rect(index, count)
			card.position -= RewardMachineView.BAY_POSITION
			mark.centre_in(card)
	queue_redraw()


## The visit's prize count before its draw (the machine's prizes_per_visit; 3 without a run).
func _slots() -> int:
	if view != null and view.run != null:
		return clampi(view.run.machine.machine.prizes_per_visit, 1, 3)
	return 3


func _draw() -> void:
	var p: float = MachineArt.PIXEL
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(rect, Palette.INK)
	draw_rect(rect.grow(-p), Palette.STEEL_DARK)
	draw_rect(Rect2(p, p, SIZE.x - 2.0 * p, p), Palette.STEEL_SHADE)
	draw_rect(rect.grow(-3.0 * p), Palette.INK)
	draw_rect(rect.grow(-INSET), Palette.CHARCOAL)
	if _night:
		_draw_bulbs()
	_draw_header()
	_draw_floor()
	for index: int in range(_n):
		var card: Rect2 = PrizeRow.card_rect(index, _n)
		card.position -= RewardMachineView.BAY_POSITION
		var middle: float = card.get_center().x
		var lamp: Rect2 = Rect2(middle - LAMP_SIZE.x / 2.0, LAMP_TOP, LAMP_SIZE.x, LAMP_SIZE.y)
		draw_rect(lamp, Palette.MUSTARD_PALE if _drawn else Palette.STEEL_DARK)
		if _drawn:
			_draw_cone(middle)
		_draw_pedestal(index)
		if not _drawn:
			_dashed(card, Palette.RUBBER if _idle else Palette.STEEL_DARK)
	if not _drawn and not _idle:
		MachineArt.centred_text(
			self,
			HINT % _n,
			Vector2(SIZE.x / 2.0, FLOOR_Y + 28.0),
			ArtStyle.bold_font(HINT_WEIGHT),
			HINT_SIZE,
			Palette.TEAL_LIGHT
		)


## The night face's bulbs along the frame's top, chasing with the marquee's.
func _draw_bulbs() -> void:
	var index: int = 0
	var x: float = BULB_LEFT
	while x + BULB_SIZE.x <= SIZE.x - BULB_LEFT:
		var lit: bool = _look.bulb_lit(index + 3, _chase)
		draw_rect(Rect2(Vector2(x, 2.0), BULB_SIZE), Palette.GOLD if lit else Palette.BRASS_DARKEST)
		x += BULB_STEP
		index += 1


func _draw_header() -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(HEADER_RECT, Palette.CHARCOAL)
	var y: float = HEADER_RECT.position.y + p
	while y < HEADER_RECT.end.y:
		draw_rect(
			Rect2(HEADER_RECT.position.x, y, HEADER_RECT.size.x, p / 2.0),
			Color(Palette.INK, SCANLINE_ALPHA)
		)
		y += 2.0 * p
	draw_rect(
		Rect2(HEADER_RECT.position.x, HEADER_RECT.end.y, HEADER_RECT.size.x, p), Palette.STEEL_DARK
	)


## A cone of light down from the lamp at `middle`: dots on every other art row and column.
func _draw_cone(middle: float) -> void:
	var p: float = MachineArt.PIXEL
	var row: int = 0
	while row < CONE_ROWS:
		var width: int = roundi(CONE_WIDTH + row * CONE_SPREAD)
		var left: float = MachineArt.snap(middle - width * p / 2.0)
		var column: int = 1 if row % 4 == 2 else 0
		while column < width:
			draw_rect(Rect2(left + column * p, CONE_TOP + row * p, p, p), Palette.RUBBER)
			column += 2
		row += 2


## Pedestal `index`: an ink block, its lip (steel, brass once gold) and its light strip.
func _draw_pedestal(index: int) -> void:
	var p: float = MachineArt.PIXEL
	var rect: Rect2 = pedestal_rect(index, _n)
	draw_rect(rect, Palette.INK)
	var lip: Rect2 = Rect2(rect.position.x + p, rect.position.y, rect.size.x - 2.0 * p, 2.0 * p)
	draw_rect(lip, Palette.MUSTARD if _gold else Palette.STEEL_PALE)
	var under: Rect2 = Rect2(lip.position.x, lip.end.y, lip.size.x, p)
	draw_rect(under, Palette.BRASS_DARK if _gold else Palette.STEEL_SHADE)
	var strip: Rect2 = Rect2(
		rect.position.x + PEDESTAL_GROW + STRIP_INSET,
		rect.position.y + 3.0 * p,
		rect.size.x - 2.0 * (PEDESTAL_GROW + STRIP_INSET),
		2.0 * p
	)
	var lit: bool = index < _strips.size() and _strips[index]
	var light: Color = Palette.GOLD if _gold else Palette.MUSTARD_LIGHT
	draw_rect(strip, light if lit else Palette.RUBBER)


## The floor's line, its ticks and the SKIP bin's hatch.
func _draw_floor() -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(Rect2(INSET, FLOOR_Y, SIZE.x - 2.0 * INSET, p), Palette.RUBBER)
	var x: float = TICK_LEFT
	while x < SIZE.x - INSET - p:
		var tick: Rect2 = Rect2(x, FLOOR_Y + p, p, SIZE.y - INSET - FLOOR_Y - 2.0 * p)
		draw_rect(tick, Palette.RUBBER_DARK)
		x += TICK_STEP
	var middle: float = PrizeRow.MIDDLE_X - RewardMachineView.BAY_POSITION.x
	draw_rect(
		Rect2(Vector2(middle - HATCH_SIZE.x / 2.0, FLOOR_Y + 2.0 * p), HATCH_SIZE),
		Palette.STEEL_DARKEST
	)


## A dashed 2 px border inside `rect`, in `colour`.
func _dashed(rect: Rect2, colour: Color) -> void:
	var p: float = MachineArt.PIXEL
	var x: float = rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, p, p), colour)
		draw_rect(Rect2(x, rect.end.y - p, p, p), colour)
		x += DASH * 2.0
	var y: float = rect.position.y
	while y < rect.end.y:
		draw_rect(Rect2(rect.position.x, y, p, p), colour)
		draw_rect(Rect2(rect.end.x - p, y, p, p), colour)
		y += DASH * 2.0
