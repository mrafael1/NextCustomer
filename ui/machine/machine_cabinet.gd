class_name MachineCabinet
extends Control
## The machine's cabinet, front-on (v0.50, mock-up premium_machine_v1.html), drawn first under
## every other part: its plinth and shadow, the teal body lit from the upper left, the kick panel's
## vents and, once a PREMIUM visit turns PREMIUM (MachineLook), the 3 px gold trim (highlight,
## gold, shadow) running down both edges with a spark at its tip, then two sparks gliding on it.
##
## The bonus ticket's dock (#77 machine v2, Q2 = 2) is on the kick panel (DOCK_RECT, a dashed
## cream-shade border and "BONUS TICKET HERE"): it shows while a bonus ticket is on its way,
## through a TICKET visit with a stub (its border turns mustard as the receipt reaches the slot,
## and its caption goes MachineTuning's dock_label_ms later) and a BONUS visit until its ticket
## reaches the slot (mustard, no caption).

const SIZE := Vector2(448, 568)
## The stock window's steel frame and the key plate (dark teal; dark night with a brass ring once
## PREMIUM) the keys stand on.
const WINDOW_FRAME_RECT := Rect2(16, 72, 416, 216)
const PLATE_RECT := Rect2(12, 296, 424, 112)
const PLINTH_RECT := Rect2(-8, 568, 464, 16)
const SHADOW_RECT := Rect2(-20, 584, 488, 6)
const SHADOW_ALPHA := 0.35
## The kick panel's vents: VENTS slots VENT_STEP apart from VENT_AT, two rows.
const VENT_AT := Vector2(48, 534)
const VENT_SIZE := Vector2(24, 4)
const VENT_STEP := 36.0
const VENT_ROW := 10.0
const VENTS := 10
const DOCK_RECT := Rect2(172, 524, 104, 34)
const DOCK_TEXT := "BONUS TICKET HERE"
const DOCK_LABEL_SIZE := 8
const DOCK_LABEL_WEIGHT := 700
## The dock's dashed border: DOCK_DASH long, DOCK_DASH apart.
const DOCK_DASH := 4.0
const BORDER := 2.0
## The trim's two sparks once it has run (one each side), gliding down in this many seconds.
const SPARK_PERIOD := 2.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _trim: float = 0.0
var _night_plate: bool = false
var _spark: float = 0.0
var _dock_on: bool = false
var _dock_lit: bool = false
var _dock_label: Label


func _init() -> void:
	name = "MachineCabinet"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_label = UiKit.body_label(DOCK_TEXT, DOCK_LABEL_SIZE, Palette.CREAM)
	_dock_label.name = "DockLabel"
	_dock_label.add_theme_font_override("font", ArtStyle.bold_font(DOCK_LABEL_WEIGHT))
	_dock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dock_label.clip_text = true
	RewardMachineView.fit(_dock_label, DOCK_RECT)
	_dock_label.visible = false
	add_child(_dock_label)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The dock's rect on screen, where the bonus ticket waits.
func dock_global_rect() -> Rect2:
	return get_global_transform() * DOCK_RECT


## Whether the dock shows, whether its border is mustard, whether its caption shows.
func dock_state() -> Array[bool]:
	return [_dock_on, _dock_lit, _dock_label.visible]


## How far the gold trim has run down (0 .. 1).
func trim_shown() -> float:
	return _trim


## Whether the key plate shows its PREMIUM night face.
func night_plate() -> bool:
	return _night_plate


## The trim, the key plate and the dock at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var dock: bool = false
	var dock_lit: bool = false
	var caption: bool = false
	if plan != null and plan.kind == MachineVisit.Kind.TICKET and plan.stub:
		dock = true
		dock_lit = t >= plan.fly_end
		caption = t < plan.fly_end + MachineTuning.sec(view.tuning.dock_label_ms)
	elif plan != null and plan.kind == MachineVisit.Kind.BONUS and t < plan.fly_end:
		dock = true
		dock_lit = true
	_dock_label.visible = caption
	var look: MachineLook = MachineLook.at(plan, t)
	var trim: float = look.trim()
	var night: bool = look.night_plate()
	var spark: float = fposmod(view.idle_time, SPARK_PERIOD) / SPARK_PERIOD if view != null else 0.0
	var changed: bool = trim != _trim or dock != _dock_on or dock_lit != _dock_lit
	if changed or night != _night_plate or (trim >= 1.0 and spark != _spark):
		_trim = trim
		_night_plate = night
		_spark = spark
		_dock_on = dock
		_dock_lit = dock_lit
		queue_redraw()


func _draw() -> void:
	draw_rect(PLINTH_RECT, Palette.STEEL_DARK)
	draw_rect(Rect2(PLINTH_RECT.position, Vector2(PLINTH_RECT.size.x, 2)), Palette.STEEL)
	draw_rect(SHADOW_RECT, Color(Palette.INK, SHADOW_ALPHA))
	MachineArt.box(self, Rect2(Vector2.ZERO, SIZE), Palette.PANEL, Palette.INK)
	draw_rect(Rect2(2, 2, 6, SIZE.y - 4), Palette.TEAL_SHADE)
	draw_rect(Rect2(SIZE.x - 8, 2, 6, SIZE.y - 4), Palette.TEAL_BLACK)
	draw_rect(Rect2(8, 2, SIZE.x - 16, 2), Palette.TEAL_SHADE)
	MachineArt.box(self, WINDOW_FRAME_RECT, Palette.STEEL, Palette.INK)
	draw_rect(
		Rect2(WINDOW_FRAME_RECT.position + Vector2(2, 2), Vector2(WINDOW_FRAME_RECT.size.x - 4, 2)),
		Palette.STEEL_HIGHLIGHT
	)
	if _night_plate:
		MachineArt.box(self, PLATE_RECT, Palette.CHARCOAL, Palette.BRASS_DARKEST)
		MachineArt.ring(self, PLATE_RECT.grow(-2.0), Palette.BRASS)
	else:
		MachineArt.box(self, PLATE_RECT, Palette.TEAL_BLACK, Palette.INK)
	for row: int in range(2):
		for index: int in range(VENTS):
			var vent: Rect2 = Rect2(VENT_AT + Vector2(index * VENT_STEP, row * VENT_ROW), VENT_SIZE)
			if _dock_on and vent.intersects(DOCK_RECT.grow(4.0)):
				continue
			draw_rect(vent, Palette.TEAL_BLACK)
	if _dock_on:
		draw_rect(DOCK_RECT, Palette.TEAL_BLACK)
		_dashed_rect(DOCK_RECT, Palette.MUSTARD if _dock_lit else Palette.CREAM_SHADE)
	_draw_trim()


## The gold trim down both edges, `_trim` of the way; done, a gold line along the foot too.
func _draw_trim() -> void:
	if _trim <= 0.0:
		return
	var length: float = MachineArt.snap((SIZE.y - 4.0) * _trim)
	for x: float in [2.0, SIZE.x - 8.0]:
		draw_rect(Rect2(x, 2, 2, length), Palette.MUSTARD_PALE)
		draw_rect(Rect2(x + 2, 2, 2, length), Palette.GOLD)
		draw_rect(Rect2(x + 4, 2, 2, length), Palette.BRASS_DARK)
	if _trim < 1.0:
		MachineArt.sparkle(self, Vector2(4, 2 + length), 2.0, 1.0)
		MachineArt.sparkle(self, Vector2(SIZE.x - 6, 2 + length), 2.0, 1.0)
		return
	draw_rect(Rect2(8, SIZE.y - 6, SIZE.x - 16, 2), Palette.MUSTARD_PALE)
	draw_rect(Rect2(8, SIZE.y - 4, SIZE.x - 16, 2), Palette.BRASS)
	for side: int in range(2):
		var phase: float = fposmod(_spark + side * 0.5, 1.0)
		var x: float = SIZE.x - 6.0 if side == 1 else 4.0
		MachineArt.sparkle(self, Vector2(x, 24.0 + phase * (SIZE.y - 48.0)), 1.0, sin(phase * PI))


## A dashed 2 px border inside `rect`, in `colour`.
func _dashed_rect(rect: Rect2, colour: Color) -> void:
	var x: float = rect.position.x
	while x < rect.end.x:
		var w: float = minf(DOCK_DASH, rect.end.x - x)
		draw_rect(Rect2(x, rect.position.y, w, BORDER), colour)
		draw_rect(Rect2(x, rect.end.y - BORDER, w, BORDER), colour)
		x += DOCK_DASH * 2.0
	var y: float = rect.position.y
	while y < rect.end.y:
		var h: float = minf(DOCK_DASH, rect.end.y - y)
		draw_rect(Rect2(rect.position.x, y, BORDER, h), colour)
		draw_rect(Rect2(rect.end.x - BORDER, y, BORDER, h), colour)
		y += DOCK_DASH * 2.0
