class_name SlotPlate
extends Control
## The machine's receipt slot (#77; redrawn front-on in v0.50, mock-up premium_machine_v1.html):
## a cream bevelled plate right of the display, on the same strip, with the mouth (charcoal, a
## steel dark lip) the receipt feeds into, the mustard arrow under it, the status lamp at the
## right (mustard dark, green once the receipt is read) and the red scan bar under the mouth,
## blinking while the receipt is fed and read (reduced motion: steady). Once a BOOSTED visit turns
## PREMIUM (MachineLook) the plate goes gold and the gold receipt stays in the slot for the whole
## visit, sticking out of the mouth with a shine every STUB_SHINE_PERIOD seconds.

const SIZE := Vector2(108, 52)
const MOUTH_RECT := Rect2(20, 14, 68, 8)
const SCAN_BAR_RECT := Rect2(20, 24, 68, 4)
const LAMP_RECT := Rect2(90, 30, 12, 12)
## The gold receipt left in the slot (it stands out above the plate).
const STUB_RECT := Rect2(40, -4, 30, 22)
const STUB_SHINE_PERIOD := 2.2
const STUB_SHINE_LENGTH := 0.5
## The arrow under the mouth: three rows, each 2 art px narrower.
const ARROW_AT := Vector2(48, 30)
const ARROW_ROWS := 3
## The scan bar blinks on every other eighth of a second (look F's page).
const BLINK_RATE := 8.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _lamp_on: bool = false
var _scan_on: bool = false
var _gold: bool = false
var _stub: bool = false
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


## Whether the gold receipt stands in the slot (a PREMIUM machine).
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
	var shine: float = -1.0
	if look.premium() and view != null:
		shine = fposmod(view.idle_time, STUB_SHINE_PERIOD) / STUB_SHINE_LENGTH
	var changed: bool = lamp != _lamp_on or reading != _scan_on
	changed = changed or look.tray_gold() != _gold or look.premium() != _stub
	if changed or shine != _shine:
		_lamp_on = lamp
		_scan_on = reading
		_gold = look.tray_gold()
		_stub = look.premium()
		_shine = shine
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	if _gold:
		MachineArt.bevel(
			self,
			rect,
			Palette.MUSTARD_LIGHT,
			Palette.MUSTARD_PALE,
			Palette.BRASS,
			Palette.BRASS_DARKEST
		)
	else:
		MachineArt.bevel(self, rect, Palette.CREAM, Palette.PAPER, Palette.CREAM_SHADE)
	draw_rect(MOUTH_RECT, Palette.CHARCOAL)
	draw_rect(
		Rect2(MOUTH_RECT.position.x, MOUTH_RECT.end.y - 2, MOUTH_RECT.size.x, 2), Palette.STEEL_DARK
	)
	if _scan_on:
		draw_rect(SCAN_BAR_RECT, Palette.TOMATO)
	var arrow: Color = Palette.BRASS_DARK if _gold else Palette.MUSTARD_DARK
	for row: int in range(ARROW_ROWS):
		var at: Vector2 = ARROW_AT + Vector2(2 * row, 2 * row)
		draw_rect(Rect2(at, Vector2(14 - 4 * row, 2)), arrow)
	MachineArt.box(self, LAMP_RECT, Palette.GOOD if _lamp_on else Palette.MUSTARD_DARK, Palette.INK)
	if _stub:
		_draw_stub()


## The gold receipt in the slot: its lines, the mouth's top line over it, its shine.
func _draw_stub() -> void:
	MachineArt.box(self, STUB_RECT, Palette.GOLD, Palette.BRASS_DARKEST)
	var at: Vector2 = STUB_RECT.position
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(26, 2)), Palette.MUSTARD_PALE)
	draw_rect(Rect2(at + Vector2(6, 8), Vector2(16, 2)), Palette.BRASS)
	draw_rect(Rect2(at + Vector2(6, 12), Vector2(12, 2)), Palette.BRASS)
	draw_rect(Rect2(MOUTH_RECT.position, Vector2(MOUTH_RECT.size.x, 2)), Palette.CHARCOAL)
	MachineArt.shine(
		self, Rect2(STUB_RECT.position, STUB_RECT.size - Vector2(0, 2)), _shine, Palette.PAPER, 2.0
	)
