class_name PrizeRow
extends Control
## The prize tickets' stage (v0.50, mock-up premium_machine_v1.html; R1 "drop"; the relook in
## v0.98, mock-up machine_relook.html V2; V3 in v0.98, machine_relook_v3.html: no veil, the
## vitrine's odds stay readable while picking), on the machine's stage layer: "KEEP ONE" lights on
## the tray's push bar once the tickets are all face up (keep_at) and goes at the pick (or the
## bin). The tickets themselves stand on the machine's card layer, over it, in a row centred on the
## prize bay (card_rect), and leave the tray's mouth from LAUNCH. frame(t) reads only view.plan
## and t.

## The tickets' row, in machine coordinates: their top, their gap, the prize bay's middle (V3,
## v0.98: they stand on the bay's pedestals, PrizeBay).
const ROW_TOP := 76.0
const ROW_GAP := 20.0
const MIDDLE_X := 762.0
## A ticket's top-left (at 1x) as it leaves the tray's mouth (its foot's middle, the pivot, just
## inside the mouth).
const LAUNCH := Vector2(182, 218)
const KEEP_TEXT := "KEEP ONE"
const KEEP_AFTER := 0.6

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _keep: MachineLine


func _init() -> void:
	name = "PrizeRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2.ZERO
	_keep = MachineLine.make("KeepOne", KEEP_TEXT, Palette.BRASS_DARKEST)
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


## KEEP ONE at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	_keep.visible = keep_at(plan, t)


## Places KEEP ONE on the tray's push bar (the card layer's coordinates are the machine's).
func place_keep() -> void:
	var bar: Rect2 = MachineTray.BAR_RECT
	bar.position += RewardMachineView.TRAY_POSITION
	_keep.centre_in(bar)
