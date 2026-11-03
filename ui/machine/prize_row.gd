class_name PrizeRow
extends Control
## The prize tickets' stage (v0.50, mock-up premium_machine_v1.html; R1 "drop"; the relook in
## v0.86, mock-up machine_relook.html V2), on the machine's stage layer: as the tickets fly out of
## the tray a teal-black veil (VEIL_ALPHA) darkens the machine's face behind them (VEIL_RECT: the
## display, the vitrine and the keys, never the store round it), so the row reads first, and "KEEP
## ONE" lights on the tray's push bar once they are all face up (keep_at); both go at the pick (or
## the bin). The tickets themselves stand on the machine's card layer, over it, in a row centred on
## the machine (card_rect), and leave the tray's mouth from LAUNCH. frame(t) reads only view.plan
## and t.

## The veil: behind the tickets, over the cabinet's face (under the marquee down to the key
## plate), in stage coordinates (ShiftStage.MACHINE_RECT + its place in the cabinet).
const VEIL_IN_CABINET := Rect2(24, 8, 512, 400)
const VEIL_RECT := Rect2(
	ShiftStage.MACHINE_RECT.position + VEIL_IN_CABINET.position, VEIL_IN_CABINET.size
)
const VEIL_ALPHA := 0.62
const VEIL_IN := 0.2
const VEIL_LEAD := 0.05
const VEIL_OUT := 0.2
## The tickets' row, in machine coordinates: their top, their gap, the machine's middle.
const ROW_TOP := 92.0
const ROW_GAP := 20.0
const MIDDLE_X := 280.0
## A ticket's top-left (at 1x) as it leaves the tray's mouth (its foot's middle, the pivot, just
## inside the mouth).
const LAUNCH := Vector2(196, 214)
const KEEP_TEXT := "KEEP ONE"
const KEEP_AFTER := 0.6
## KEEP ONE's ink on the push bar.
const KEEP_INK := Palette.BRASS_DARKEST

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _veil: float = 0.0
var _keep: MachineLine


func _init() -> void:
	name = "PrizeRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	# No size: the veil is drawn (VEIL_RECT, unclipped), so the part takes no room of its own.
	size = Vector2.ZERO
	_keep = MachineLine.make("KeepOne", KEEP_TEXT, KEEP_INK)
	_keep.visible = false


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2). KEEP ONE stands on the card layer, with the tickets.
func setup(machine: RewardMachineView) -> void:
	view = machine


## The KEEP ONE line (it lives on the machine's card layer, over the tray's push bar).
func keep_label() -> MachineLine:
	return _keep


## Ticket `index` of `count`'s rect, in machine coordinates: the row centred on the machine.
static func card_rect(index: int, count: int) -> Rect2:
	var width: float = count * PrizeTicket.SIZE.x + maxf(0.0, count - 1.0) * ROW_GAP
	var x: float = MIDDLE_X - width / 2.0 + index * (PrizeTicket.SIZE.x + ROW_GAP)
	return Rect2(Vector2(MachineArt.snap(x), ROW_TOP), PrizeTicket.SIZE)


## Whether KEEP ONE shows at `t` on `plan`: once every ticket is face up (or the pick waits),
## until the pick or the bin.
static func keep_at(plan: MachinePlan, t: float) -> bool:
	if plan == null or not plan.has_draw or plan.n_prizes <= 0:
		return false
	if plan.has_landing and t >= plan.press:
		return false
	var last: int = plan.n_prizes - 1
	return t >= minf(plan.pick_at, plan.reveal_at[last] + KEEP_AFTER)


## How dark the veil is now (0 .. VEIL_ALPHA).
func veil_alpha() -> float:
	return _veil


## The veil and KEEP ONE at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var veil: float = 0.0
	if plan != null and plan.has_draw and plan.n_prizes > 0:
		var from: float = plan.drop_at[0] - VEIL_LEAD
		veil = MachineArt.seg(t, from, from + VEIL_IN)
		if plan.reduced_motion:
			veil = 1.0 if t >= plan.reveal_at[0] else 0.0
		if plan.has_landing and t >= plan.press:
			var out: float = MachineArt.seg(t, plan.press, plan.press + VEIL_OUT)
			veil *= 0.0 if plan.reduced_motion else 1.0 - out
	veil *= VEIL_ALPHA
	_keep.visible = keep_at(plan, t)
	if veil != _veil:
		_veil = veil
		queue_redraw()


## Places KEEP ONE on the tray's push bar (the card layer's coordinates are the machine's).
func place_keep() -> void:
	var bar: Rect2 = MachineTray.BAR_RECT
	bar.position += RewardMachineView.TRAY_POSITION
	_keep.centre_in(bar)


func _draw() -> void:
	if _veil > 0.0:
		draw_rect(VEIL_RECT, Color(Palette.TEAL_BLACK, _veil))
