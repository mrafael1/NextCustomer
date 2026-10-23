class_name PrizeRow
extends Control
## The prize tickets' stage (v0.50, mock-up premium_machine_v1.html; R1 "drop"), on the machine's
## stage layer: as the tickets fly out of the tray a teal-black veil (VEIL_ALPHA) darkens the store
## below the top bar, so the row reads first, and "KEEP ONE" shows under the row once they are all
## face up; both go at the pick (or the bin). The tickets themselves stand on the machine's card
## layer, over it, in a row centred on the machine (card_rect), and leave the tray's mouth from
## LAUNCH. frame(t) reads only view.plan and t.

## The veil: under the top bar to the stage's foot, in stage coordinates.
const VEIL_RECT := Rect2(0, 56, 1280, 664)
const VEIL_ALPHA := 0.62
const VEIL_IN := 0.2
const VEIL_LEAD := 0.05
const VEIL_OUT := 0.2
## The tickets' row, in machine coordinates: their top, their gap, the machine's middle.
const ROW_TOP := 140.0
const ROW_GAP := 12.0
const MIDDLE_X := 224.0
## A ticket's top-left (at 1x) as it leaves the tray's mouth.
const LAUNCH := Vector2(124, 176)
const KEEP_TEXT := "KEEP ONE"
const KEEP_SIZE := 20
const KEEP_MIDDLE_Y := 468.0
const KEEP_AFTER := 0.6
const BOLD_WEIGHT := 800

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _veil: float = 0.0
var _keep: Label


func _init() -> void:
	name = "PrizeRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	# No size: the veil is drawn (VEIL_RECT, unclipped), so the part takes no room of its own.
	size = Vector2.ZERO
	_keep = UiKit.body_label(KEEP_TEXT, KEEP_SIZE, Palette.PAPER)
	_keep.name = "KeepOne"
	_keep.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	_keep.add_theme_color_override("font_shadow_color", Palette.INK)
	_keep.add_theme_constant_override("shadow_offset_x", 0)
	_keep.add_theme_constant_override("shadow_offset_y", 2)
	_keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keep.visible = false


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2). KEEP ONE stands on the card layer, with the tickets.
func setup(machine: RewardMachineView) -> void:
	view = machine


## The KEEP ONE label (it lives on the machine's card layer).
func keep_label() -> Label:
	return _keep


## Ticket `index` of `count`'s rect, in machine coordinates: the row centred on the machine.
static func card_rect(index: int, count: int) -> Rect2:
	var width: float = count * PrizeTicket.SIZE.x + maxf(0.0, count - 1.0) * ROW_GAP
	var x: float = MIDDLE_X - width / 2.0 + index * (PrizeTicket.SIZE.x + ROW_GAP)
	return Rect2(Vector2(MachineArt.snap(x), ROW_TOP), PrizeTicket.SIZE)


## How dark the veil is now (0 .. VEIL_ALPHA).
func veil_alpha() -> float:
	return _veil


## The veil and KEEP ONE at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var veil: float = 0.0
	var keep: bool = false
	if plan != null and plan.has_draw and plan.n_prizes > 0:
		var from: float = plan.drop_at[0] - VEIL_LEAD
		veil = MachineArt.seg(t, from, from + VEIL_IN)
		if plan.reduced_motion:
			veil = 1.0 if t >= plan.reveal_at[0] else 0.0
		var last: int = plan.n_prizes - 1
		keep = t >= minf(plan.pick_at, plan.reveal_at[last] + KEEP_AFTER)
		if plan.has_landing and t >= plan.press:
			var out: float = MachineArt.seg(t, plan.press, plan.press + VEIL_OUT)
			veil *= 0.0 if plan.reduced_motion else 1.0 - out
			keep = false
	veil *= VEIL_ALPHA
	_keep.visible = keep
	_keep.text = KEEP_TEXT
	if veil != _veil:
		_veil = veil
		queue_redraw()


## Places KEEP ONE under the row (the card layer's coordinates are the machine's).
func place_keep() -> void:
	RewardMachineView.fit(
		_keep, Rect2(MIDDLE_X - 160.0, KEEP_MIDDLE_Y - KEEP_SIZE, 320.0, KEEP_SIZE * 2.0)
	)


func _draw() -> void:
	if _veil > 0.0:
		draw_rect(VEIL_RECT, Color(Palette.TEAL_BLACK, _veil))
