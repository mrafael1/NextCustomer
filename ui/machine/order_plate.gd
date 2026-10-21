class_name OrderPlate
extends Control
## The YOUR ORDER plate between the stockroom and the belt (#77, look F; build spec 4.2): five
## chevrons pointing the belt's way (left), lit while the belt runs (one at a time goes dark,
## running left; all lit under reduced motion); the plate hides from the reveals while any rarity
## tab sits over it (so look F's gold LEGENDARY flash, which falls in a reveal, is left to
## the hood's lamp). Reads only view.plan and t.

enum Lamp { OFF, ON }

const SIZE := Vector2(180, 14)
const CHEVRONS := 5
const CHEVRON_X := 10.0
const CHEVRON_STEP := 14.0
const LABEL_TEXT := "YOUR ORDER"
const LABEL_X := 86.0
const LABEL_SIZE := 7
const BOLD_WEIGHT := 800
## The running chevron steps CHASE times a second.
const CHASE := 4.0
## The plate shows again HIDE_TAIL_S after a bin, or after a lone prize's flight.
const HIDE_TAIL_S := 0.4

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _lamps: Array[int] = []


func _init() -> void:
	name = "OrderPlate"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = UiKit.body_label(LABEL_TEXT, LABEL_SIZE, Palette.TEAL_LIGHT)
	label.name = "Label"
	label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	RewardMachineView.fit(label, Rect2(LABEL_X, 0, SIZE.x - LABEL_X - 2.0, SIZE.y))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	for index: int in range(CHEVRONS):
		_lamps.append(Lamp.OFF)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the plate at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		return
	visible = not hidden_at(plan, t)
	var moving: bool = plan.belt_moving(t)
	for index: int in range(CHEVRONS):
		var lamp: int = Lamp.OFF
		if moving:
			var dark: bool = int(floorf(t * CHASE)) % CHEVRONS == CHEVRONS - 1 - index
			lamp = Lamp.ON if plan.reduced_motion or not dark else Lamp.OFF
		_lamps[index] = lamp
	queue_redraw()


## The chevrons' states (Lamp), left to right, for tests.
func lamps() -> Array[int]:
	return _lamps.duplicate()


## Whether the plate hides at `t`: from the first reveal while any rarity tab is up over it,
## until just after a bin drops the tickets, or after the picked prize, the only one, flies;
## the prizes left after a pick keep their tabs up to the visit's end, so the plate stays hidden.
static func hidden_at(plan: MachinePlan, t: float) -> bool:
	if not plan.has_draw or plan.reveal_at.is_empty() or t < plan.reveal_at[0]:
		return false
	if not plan.has_landing:
		return true
	if plan.landing == MachinePlan.Landing.BIN:
		return t < plan.press + HIDE_TAIL_S
	if plan.n_prizes > 1:
		return true
	return t < plan.fly_out + HIDE_TAIL_S


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.INK)
	draw_rect(Rect2(Vector2(2, 2), SIZE - Vector2(4, 4)), Palette.BACKGROUND)
	var colours: Array[Color] = [Palette.GREY_DARK, Palette.STEEL_LIGHT]
	for index: int in range(CHEVRONS):
		var x: float = CHEVRON_X + CHEVRON_STEP * index
		var colour: Color = colours[_lamps[index]]
		# "<": 2 px steps up and down from its point.
		for step: int in range(3):
			draw_rect(Rect2(x + step * 2.0, 6.0 - step * 2.0, 2, 2), colour)
			draw_rect(Rect2(x + step * 2.0, 6.0 + step * 2.0, 2, 2), colour)
