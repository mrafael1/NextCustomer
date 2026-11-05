class_name SlotPlate
extends Control
## The machine's receipt slot (#77; redrawn front-on in v0.50; the relook's 112x60 plate in
## v0.86, mock-up machine_relook.html V2): a cream bevelled plate right of the display, on the
## same strip, with the mouth (charcoal, a steel dark lip) the receipt feeds into, the brass arrow
## under it, the status lamp at the bottom right (green dark, green once the receipt is read) and
## the red scan bar under the mouth, blinking while the receipt is fed and read (reduced motion:
## steady). As a visit turns PREMIUM (MachineLook) the gold receipt pops up in the slot with a
## shine and is fed in (MachineLook.stub_left), gone once swallowed as a classic receipt is (v0.97:
## it used to stay half inserted for the whole visit).

const SIZE := Vector2(112, 60)
const MOUTH_RECT := Rect2(12, 18, 88, 8)
const SCAN_BAR_RECT := Rect2(12, 28, 88, 4)
const LAMP_RECT := Rect2(96, 44, 10, 10)
## The gold receipt left in the slot (it stands out above the plate).
const STUB_RECT := Rect2(40, -4, 32, 24)
const STUB_SHINE_PERIOD := 2.2
const STUB_SHINE_LENGTH := 0.5
## The arrow under the mouth: three rows, each 2 art px narrower.
const ARROW_AT := Vector2(42, 36)
const ARROW_ROWS := 3
## The scan bar blinks on every other eighth of a second (look F's page).
const BLINK_RATE := 8.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _lamp_on: bool = false
var _scan_on: bool = false
var _gold: bool = false
var _stub: bool = false
var _stub_left: float = 0.0
var _shine: float = -1.0


func _init() -> void:
	name = "SlotPlate"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whether the lamp is lit (green: the receipt was read).
func lamp_on() -> bool:
	return _lamp_on


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


## The lamp, the scan bar and the premium dressing at time `t` (seconds) of view.plan: the bar
## shows from the paper's arrival to the read's end (blinking, steady under reduced motion), the
## lamp lights at the feed's end (a STAMP DAY visit has no feed: lit from its start).
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var lamp: bool = plan != null and t >= plan.feed_end
	var reading: bool = plan != null and t >= plan.fly_end and t < plan.read_end
	if reading and not plan.reduced_motion:
		reading = int(floorf(t * BLINK_RATE)) % 2 == 0
	var look: MachineLook = MachineLook.at(plan, t)
	var left: float = look.stub_left()
	var shine: float = -1.0
	if left > 0.0 and view != null:
		shine = fposmod(view.idle_time, STUB_SHINE_PERIOD) / STUB_SHINE_LENGTH
	var changed: bool = lamp != _lamp_on or reading != _scan_on
	changed = changed or look.tray_gold() != _gold or left != _stub_left
	if changed or shine != _shine:
		_lamp_on = lamp
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
	MachineArt.box(self, LAMP_RECT, Palette.GOOD if _lamp_on else Palette.GREEN_DARK, Palette.INK)
	if _stub:
		_draw_stub()


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
