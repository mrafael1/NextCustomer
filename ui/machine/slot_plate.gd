class_name SlotPlate
extends Control
## The machine's receipt slot (#77; redrawn front-on in v0.50; the relook's 112x60 plate in
## v0.98, mock-up machine_relook.html V2): a cream bevelled plate right of the display, on the
## same strip, with the mouth (charcoal, a steel dark lip) the receipt feeds into, the brass arrow
## under it and the red scan bar under the mouth, blinking while the receipt is fed and read
## (reduced motion: steady).
##
## The draw lamps (2026-11-06, the week medals; mock-up docs/art/mockups/week_medals.html section
## 5) replace the single read lamp: one round lamp per draw the receipt pays (MachinePlan.draws: 1,
## 2 for the SILVER medal's extra draw or a payday's two PREMIUM draws, 3 when they add up), about
## 16 px with a dark bezel, right-aligned on the plate's cream face under the scan bar (clear of its
## bevel and of the brass arrow, which stands left of them). The read lights them one by one
## (MachinePlan.lamps_on), green on the default look, gold with a dark ring on the PREMIUM look
## (MachineLook.tray_gold); after each prize the visit's lamp flashes (MachinePlan.lamp_flash) and
## goes dark. As a visit turns PREMIUM (MachineLook) the gold receipt pops up in the slot with a
## shine and is fed in (MachineLook.stub_left), gone once swallowed as a classic receipt is (v0.99:
## it used to stay half inserted for the whole visit).

const SIZE := Vector2(112, 60)
const MOUTH_RECT := Rect2(12, 18, 88, 8)
const SCAN_BAR_RECT := Rect2(12, 28, 88, 4)
## The draw lamps: LAMP_SIZE px discs (LAMP_CELLS art px of 2 px), the rightmost at LAMP_AT, each
## LAMP_STEP left of the one after it. A flashing lamp blinks LAMP_BLINK times a second.
const LAMP_AT := Vector2(90, 38)
const LAMP_SIZE := 16.0
const LAMP_CELLS := 8
const LAMP_STEP := 18.0
const LAMP_BLINK := 12.0
## The discs' rows (art px), the bezel's inset in them.
const LAMP_ROWS: Array[Vector2i] = [
	Vector2i(2, 4),
	Vector2i(1, 6),
	Vector2i(0, 8),
	Vector2i(0, 8),
	Vector2i(0, 8),
	Vector2i(0, 8),
	Vector2i(1, 6),
	Vector2i(2, 4),
]
## A lit lens's shine: its cells with x + y up to this (its top left).
const LAMP_SHINE_SUM := 5
## The draws the plate can show.
const MAX_LAMPS := 3
## The gold receipt left in the slot (it stands out above the plate).
const STUB_RECT := Rect2(40, -4, 32, 24)
const STUB_SHINE_PERIOD := 2.2
const STUB_SHINE_LENGTH := 0.5
## The arrow under the mouth's left end (the draw lamps take its right): three rows, each 2 art px
## narrower; ARROW_RECT holds them.
const ARROW_AT := Vector2(14, 36)
const ARROW_ROWS := 3
const ARROW_RECT := Rect2(14, 36, 28, 6)
## The plate's cream face, inside its ink edge and bevel.
const FACE_RECT := Rect2(4, 4, 104, 52)
## The scan bar blinks on every other eighth of a second (look F's page).
const BLINK_RATE := 8.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _lamps: int = 0
var _lit: int = 0
## The flashing lamp's blink: lit (1), dark (0), or none (-1).
var _flash: int = -1
var _scan_on: bool = false
var _gold: bool = false
var _stub: bool = false
var _stub_left: float = 0.0
var _shine: float = -1.0


func _init() -> void:
	name = "SlotPlate"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whether a draw lamp is lit (the receipt was read and a draw is left).
func lamp_on() -> bool:
	return _lit > 0


## The draw lamps shown (the draws the receipt pays) and how many are lit now.
func lamp_count() -> int:
	return _lamps


func lamps_lit() -> int:
	return _lit


## Whether the visit's lamp is flashing now (its prize is in), and whether its blink is lit.
func lamp_flashing() -> bool:
	return _flash >= 0


## Draw lamp `index`'s rect (local px; 0 the leftmost of lamp_count()).
func lamp_rect(index: int) -> Rect2:
	var from_right: int = _lamps - 1 - index
	return Rect2(LAMP_AT - Vector2(LAMP_STEP * from_right, 0.0), Vector2.ONE * LAMP_SIZE)


## Whether the red scan bar shows now.
func scan_bar_on() -> bool:
	return _scan_on


## Whether the gold receipt sticks out of the slot (a PREMIUM machine's transform).
func stub_shown() -> bool:
	return _stub


## The mouth's rect (local), where the receipt feeds in.
func mouth_rect() -> Rect2:
	return MOUTH_RECT


## The mouth's rect on screen (it follows the camera).
func mouth_global_rect() -> Rect2:
	return get_global_transform() * MOUTH_RECT


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The lamps, the scan bar and the premium dressing at time `t` (seconds) of view.plan: the bar
## shows from the paper's arrival to the read's end on the TICKET visit (blinking, steady under
## reduced motion), the lamps light from the feed's end and go out one by one after each prize.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var lamps: int = mini(plan.draws, MAX_LAMPS) if plan != null else 0
	var lit: int = mini(plan.lamps_on(t), lamps) if plan != null else 0
	var flash: int = -1
	if plan != null and plan.lamp_flash(t) >= 0.0:
		flash = 1
		if not plan.reduced_motion:
			flash = int(floorf((t - plan.lamp_out) * LAMP_BLINK)) % 2
	var reading: bool = plan != null and t >= plan.fly_end and t < plan.read_end
	reading = reading and plan.kind == MachineVisit.Kind.TICKET
	if reading and not plan.reduced_motion:
		reading = int(floorf(t * BLINK_RATE)) % 2 == 0
	var look: MachineLook = MachineLook.at(plan, t)
	var left: float = look.stub_left()
	var shine: float = -1.0
	if left > 0.0 and view != null:
		shine = fposmod(view.idle_time, STUB_SHINE_PERIOD) / STUB_SHINE_LENGTH
	var changed: bool = lamps != _lamps or lit != _lit or flash != _flash or reading != _scan_on
	changed = changed or look.tray_gold() != _gold or left != _stub_left
	if changed or shine != _shine:
		_lamps = lamps
		_lit = lit
		_flash = flash
		_scan_on = reading
		_gold = look.tray_gold()
		_stub = left > 0.0
		_stub_left = left
		_shine = shine
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	MachineArt.bevel(self, rect, Palette.CREAM, Palette.PAPER, Palette.CREAM_DARKEST)
	draw_rect(MOUTH_RECT, Palette.CHARCOAL)
	draw_rect(
		Rect2(MOUTH_RECT.position.x, MOUTH_RECT.end.y - 2, MOUTH_RECT.size.x, 2), Palette.STEEL_DARK
	)
	if _scan_on:
		draw_rect(SCAN_BAR_RECT, Palette.TOMATO)
	for row: int in range(ARROW_ROWS):
		var at: Vector2 = ARROW_AT + Vector2(4 * row, 2 * row)
		draw_rect(Rect2(at, Vector2(28 - 8 * row, 2)), Palette.BRASS_DARK)
	for index: int in range(_lamps):
		var on: bool = index < _lit
		if index == _lit - 1 and _flash >= 0:
			on = _flash == 1
		_draw_lamp(lamp_rect(index).position, on, _flash >= 0 and index == _lit - 1)
	if _stub:
		_draw_stub()


## A draw lamp at `at`: an ink edge, a dark bezel ring, and its lens lit or dark, green on the
## default look, gold with a dark ring on the PREMIUM one (a lit lens's top left shines); a dark
## lens is near black with no shine, so the draws left read at a glance; `flashing` lights it
## paper bright (its prize is in).
func _draw_lamp(at: Vector2, on: bool, flashing: bool) -> void:
	var p: float = MachineArt.PIXEL
	var lit: Color = Palette.GOLD if _gold else Palette.GOOD
	var shine: Color = Palette.MUSTARD_PALE if _gold else Palette.GREEN_LIGHT
	if flashing and on:
		lit = Palette.PAPER
		shine = Palette.PAPER
	var dark: Color = Palette.RUBBER_DARK if _gold else Palette.SLATE_DARK
	var ring: Color = Palette.BRASS_DARKEST if _gold else Palette.STEEL_DARK
	for y: int in range(LAMP_CELLS):
		for x: int in range(LAMP_CELLS):
			var layer: int = lamp_layer(x, y)
			if layer == 0:
				continue
			var colour: Color = Palette.INK
			if layer == 2:
				colour = ring
			elif layer == 3:
				colour = dark
				if on:
					colour = shine if x + y <= LAMP_SHINE_SUM else lit
			draw_rect(Rect2(at + Vector2(x, y) * p, Vector2(p, p)), colour)


## A draw lamp's cell (art px) layer: 0 outside the disc (LAMP_ROWS), 1 its edge (a side
## neighbour outside), 2 the bezel ring next to it, 3 the lens.
static func lamp_layer(x: int, y: int) -> int:
	if not _in_lamp(x, y):
		return 0
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _in_lamp(x + step.x, y + step.y):
			return 1
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var near: Vector2i = Vector2i(x, y) + step
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _in_lamp(near.x + side.x, near.y + side.y):
				return 2
	return 3


static func _in_lamp(x: int, y: int) -> bool:
	if y < 0 or y >= LAMP_CELLS:
		return false
	var span: Vector2i = LAMP_ROWS[y]
	return x >= span.x and x < span.x + span.y


## The gold receipt in the slot, `_stub_left` of it out (on the 2 px grid): its lines and its
## shine above the mouth's top line, which hides what has gone in.
func _draw_stub() -> void:
	var line: float = MOUTH_RECT.position.y + 2.0
	var travel: float = line - STUB_RECT.position.y
	var at: Vector2 = STUB_RECT.position + Vector2(0, MachineArt.snap(travel * (1.0 - _stub_left)))
	var shown: Rect2 = Rect2(at, Vector2(STUB_RECT.size.x, line - at.y))
	if shown.size.y <= 2.0:
		return
	MachineArt.box(self, shown, Palette.GOLD, Palette.BRASS_DARKEST)
	for part: Array in [
		[Rect2(at + Vector2(2, 2), Vector2(28, 2)), Palette.MUSTARD_PALE],
		[Rect2(at + Vector2(6, 8), Vector2(16, 2)), Palette.BRASS],
		[Rect2(at + Vector2(6, 12), Vector2(12, 2)), Palette.BRASS],
	]:
		var lit: Rect2 = (part[0] as Rect2).intersection(shown.grow(-2.0))
		if lit.has_area():
			draw_rect(lit, part[1] as Color)
	draw_rect(Rect2(MOUTH_RECT.position, Vector2(MOUTH_RECT.size.x, 2)), Palette.CHARCOAL)
	MachineArt.shine(self, Rect2(at, shown.size - Vector2(0, 2)), _shine, Palette.PAPER, 2.0)
