class_name SlotPlate
extends Control
## The machine's receipt slot (#77, look F; build spec 4.2): the cream plate with its "INSERT
## RECEIPT" label, the mouth (144,18 104x10, charcoal) the receipt feeds into, the lamp at the
## right (16x16: brass dark, green once the receipt is read) and the red scan bar under the mouth,
## blinking while the receipt flies in, feeds and is read (reduced motion: steady). Machine v2
## (#77, Q2 = 2): the dock right of the mouth (DOCK_RECT, a dashed cream-shade border and "BONUS
## TICKET HERE") shows while a bonus ticket is on its way: through a TICKET visit with a stub (its
## border turns mustard as the receipt reaches the slot, and its caption goes MachineTuning's
## dock_label_ms later) and a BONUS visit until its ticket reaches the slot (mustard, no caption).

const SIZE := Vector2(392, 42)
const LABEL_RECT := Rect2(10, 11, 130, 16)
const LABEL_SIZE := 10
const BOLD_WEIGHT := 800
const MOUTH_RECT := Rect2(144, 18, 104, 10)
const SCAN_BAR_RECT := Rect2(144, 30, 104, 4)
const LAMP_RECT := Rect2(362, 11, 16, 16)
const DOCK_RECT := Rect2(254, 6, 104, 30)
const DOCK_TEXT := "BONUS TICKET HERE"
const DOCK_LABEL_SIZE := 8
const DOCK_LABEL_WEIGHT := 700
## The dock's dashed border: DOCK_DASH long, DOCK_DASH apart.
const DOCK_DASH := 4.0
const BORDER := 2.0
## The scan bar blinks on every other eighth of a second (look F's page).
const BLINK_RATE := 8.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _lamp_on: bool = false
var _scan_on: bool = false
var _dock_on: bool = false
var _dock_lit: bool = false
var _dock_label: Label


func _init() -> void:
	name = "SlotPlate"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insert: Label = UiKit.body_label("INSERT RECEIPT", LABEL_SIZE, Palette.INK_LIGHT)
	insert.name = "InsertLabel"
	insert.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	insert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(insert, LABEL_RECT)
	insert.clip_text = true
	add_child(insert)
	_dock_label = UiKit.body_label(DOCK_TEXT, DOCK_LABEL_SIZE, Palette.INK_LIGHT)
	_dock_label.name = "DockLabel"
	_dock_label.add_theme_font_override("font", ArtStyle.bold_font(DOCK_LABEL_WEIGHT))
	_dock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dock_label.clip_text = true
	RewardMachineView.fit(_dock_label, DOCK_RECT)
	_dock_label.visible = false
	add_child(_dock_label)


## Whether the lamp is lit (green: the receipt was read).
func lamp_on() -> bool:
	return _lamp_on


## Whether the red scan bar shows now.
func scan_bar_on() -> bool:
	return _scan_on


## The mouth's rect (local), where the receipt feeds in.
func mouth_rect() -> Rect2:
	return MOUTH_RECT


## The mouth's rect on screen (it follows the camera).
func mouth_global_rect() -> Rect2:
	return get_global_transform() * MOUTH_RECT


## The dock's rect on screen, where the bonus ticket waits.
func dock_global_rect() -> Rect2:
	return get_global_transform() * DOCK_RECT


## Whether the dock shows, whether its border is mustard, whether its caption shows.
func dock_state() -> Array[bool]:
	return [_dock_on, _dock_lit, _dock_label.visible]


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The lamp and the scan bar at time `t` (seconds) of view.plan: the bar shows from the paper's
## arrival to the read's end (blinking, steady under reduced motion), the lamp lights at the
## feed's end (a STAMP DAY visit has no feed: lit from its start).
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var lamp: bool = plan != null and t >= plan.feed_end
	var reading: bool = plan != null and t >= plan.fly_end and t < plan.read_end
	if reading and not plan.reduced_motion:
		reading = int(floorf(t * BLINK_RATE)) % 2 == 0
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
	if lamp != _lamp_on or reading != _scan_on or dock != _dock_on or dock_lit != _dock_lit:
		_lamp_on = lamp
		_scan_on = reading
		_dock_on = dock
		_dock_lit = dock_lit
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.CREAM)
	_frame_rect(Rect2(Vector2.ZERO, SIZE))
	draw_rect(MOUTH_RECT, Palette.CHARCOAL)
	_frame_rect(MOUTH_RECT)
	if _scan_on:
		draw_rect(SCAN_BAR_RECT, Palette.TOMATO)
	draw_rect(LAMP_RECT, Palette.GOOD if _lamp_on else Palette.BRASS_DARK)
	if _lamp_on:
		var inner: Rect2 = LAMP_RECT.grow(-BORDER)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, BORDER)), Palette.GREEN_LIGHT)
		draw_rect(Rect2(inner.position, Vector2(BORDER, inner.size.y)), Palette.GREEN_LIGHT)
	_frame_rect(LAMP_RECT)
	if _dock_on:
		_dashed_rect(DOCK_RECT, Palette.MUSTARD if _dock_lit else Palette.CREAM_SHADE)


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


## A 2 px ink border inside `rect`.
func _frame_rect(rect: Rect2) -> void:
	draw_rect(rect.grow(-BORDER / 2.0), Palette.INK, false, BORDER)
