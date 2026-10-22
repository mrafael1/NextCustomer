class_name RestockHood
extends Control
## The RESTOCK hood at the belt's right end (#77, look F; build spec 4.2): the hood art (24 x 97
## art px at 2 px), its strip curtain (rubber strips and steel weights, swinging while a box comes
## through, still under reduced motion), the run lamp (lit while the belt moves; gold flashing on
## a LEGENDARY reveal, steady gold under reduced motion) and the vertical "RESTOCK". Reads only
## view.plan and t.

enum Lamp { OFF, ON, GOLD }

const SIZE := Vector2(48, 194)
const HOOD := preload("res://art/machine/restock_hood.png")
## The curtain: 4 x 91 art px at CURTAIN_AT; it swings from PUSH_LEAD_S before a box clears it.
const CURTAIN_AT := Vector2(2, 6)
const CURTAIN := Vector2(4, 91)
const PUSH_LEAD_S := 0.45
const SWING := 14.0
const SWING_FROM := 20
const SWING_ROWS := 9
const WEIGHT_STEP := 12
const WEIGHT_LENGTH := 8
const WEIGHT_SHAKE := 10.0
const WEIGHT_SHAKES := 3
## The run lamp's rect (with its ink edge) and its flash rate.
const LAMP_RECT := Rect2(22, 32, 16, 16)
const FLASH := 8.0
## A LEGENDARY reveal flashes the lamps between these points of its progress.
const LEGEND_FROM := 0.3
const LEGEND_TO := 0.9
const LABEL_TEXT := "RESTOCK"
const LABEL_RECT := Rect2(13, 60, 26, 100)
const LABEL_SIZE := 10
const BOLD_WEIGHT := 800

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _t: float = 0.0
var _lamp: int = Lamp.OFF
var _swinging: bool = false


func _init() -> void:
	name = "RestockHood"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	var label: Label = UiKit.body_label(LABEL_TEXT, LABEL_SIZE, Palette.STEEL_DARKEST)
	label.name = "Label"
	label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Read bottom to top, along the hood.
	RewardMachineView.fit(
		label,
		Rect2(
			Vector2(LABEL_RECT.position.x, LABEL_RECT.end.y),
			Vector2(LABEL_RECT.size.y, LABEL_RECT.size.x)
		)
	)
	label.rotation = -PI / 2.0
	add_child(label)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the hood at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	_t = t
	var plan: MachinePlan = view.plan if view != null else null
	_lamp = Lamp.OFF
	_swinging = false
	if plan != null:
		if legendary_playing(plan, t):
			var flash: bool = plan.reduced_motion or int(floorf(t * FLASH)) % 2 == 1
			_lamp = Lamp.GOLD if flash else Lamp.OFF
		elif plan.belt_moving(t):
			_lamp = Lamp.ON
		_swinging = curtain_pushed(plan, t)
	queue_redraw()


## The run lamp now (Lamp), for tests.
func lamp() -> int:
	return _lamp


## Whether the curtain swings now (a box is coming through it), for tests.
func swinging() -> bool:
	return _swinging


## Whether a LEGENDARY reveal is at its height at `t` (the lamps flash gold).
static func legendary_playing(plan: MachinePlan, t: float) -> bool:
	if not plan.has_draw:
		return false
	for index: int in range(plan.reveal_at.size()):
		if plan.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var p: float = plan.reveal_progress(index, t)
		if p > LEGEND_FROM and p < LEGEND_TO:
			return true
	return false


## Whether a box is pushing through the curtain at `t` (never under reduced motion).
static func curtain_pushed(plan: MachinePlan, t: float) -> bool:
	if plan.reduced_motion or not plan.has_draw:
		return false
	for index: int in range(plan.run_from.size()):
		var clears: float = plan.run_from[index]
		if clears >= 0.0 and t >= clears - PUSH_LEAD_S and t < clears:
			return true
	return false


func _draw() -> void:
	draw_texture_rect(HOOD, Rect2(Vector2.ZERO, SIZE), false)
	var pixel: float = StockroomWindow.PIXEL
	var origin: Vector2 = CURTAIN_AT
	for y: int in range(int(CURTAIN.y)):
		var colour: Color = Palette.RUBBER if y % 2 == 1 else Palette.RUBBER_DARK
		draw_rect(Rect2(origin + Vector2(0, y * pixel), Vector2(CURTAIN.x, 1) * pixel), colour)
		var swing: bool = (
			_swinging
			and y > SWING_FROM
			and int(floorf(_t * SWING + y / float(SWING_ROWS))) % 2 == 1
		)
		if swing:
			draw_rect(
				Rect2(origin + Vector2(0, y * pixel), Vector2(pixel, pixel)), Palette.CHARCOAL
			)
	var shake: int = int(floorf(_t * WEIGHT_SHAKE)) % WEIGHT_SHAKES if _swinging else 0
	for x: int in range(0, int(CURTAIN.x), 2):
		for y: int in range(0, int(CURTAIN.y), WEIGHT_STEP):
			var top: int = mini(y + shake, int(CURTAIN.y) - 1)
			var length: int = mini(WEIGHT_LENGTH, int(CURTAIN.y) - top)
			draw_rect(
				Rect2(origin + Vector2(x, top) * pixel, Vector2(1, length) * pixel),
				Palette.STEEL_DARKEST
			)
	draw_rect(LAMP_RECT, Palette.INK)
	var face: Rect2 = LAMP_RECT.grow(-2.0)
	match _lamp:
		Lamp.ON:
			draw_rect(face, Palette.MUSTARD)
			draw_rect(Rect2(face.position, Vector2(face.size.x, 2)), Palette.MUSTARD_PALE)
			draw_rect(Rect2(face.position, Vector2(2, face.size.y)), Palette.MUSTARD_PALE)
		Lamp.GOLD:
			draw_rect(face, Palette.GOLD)
			draw_rect(Rect2(face.position, Vector2(face.size.x, 2)), Palette.PAPER)
			draw_rect(Rect2(face.position, Vector2(2, face.size.y)), Palette.PAPER)
		_:
			draw_rect(face, Palette.BRASS_DARK)
