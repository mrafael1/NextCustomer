class_name MachineDim
extends Control
## The idle machine's look on the back wall (#77 machine v2, Q1 = A; the approved page's filter),
## kept out of RewardMachineView so it stays under gdlint's file length: the veil over the machine
## (its last child) desaturates what is drawn under it (presentation/machine_dim.gdshader) while
## the machine's modulate darkens it; set_lit eases both from dim (0) to lit (1). The veil follows
## the machine's silhouette (v0.50: the marquee with its bulbs, the cabinet, the plinth), one
## piece each, so the wall and the floor round it keep their colour. Its statics put the machine's
## parts at rest and stop it taking clicks between visits.

## The idle machine's brightness and saturation.
const DIM_BRIGHTNESS := 0.62
const DIM_SATURATION := 0.55
## The veil's pieces in the machine: the marquee and its bulb ring (RewardMachineView's
## HEAD_POSITION, MachineHead's bulbs 10 px round it), the cabinet (MachineCabinet.SIZE, under the
## marquee) and its plinth (MachineCabinet.PLINTH_RECT). The floor shadow is left out.
const VEIL_RECTS: Array[Rect2] = [
	Rect2(-30, -66, 506, 72),
	Rect2(0, 6, 448, 562),
	Rect2(-8, 568, 464, 16),
]
const SHADER := preload("res://presentation/machine_dim.gdshader")

## How lit the machine is (0 dim .. 1 lit).
var lit: float = 1.0
var _look: ShaderMaterial


func _init() -> void:
	name = "DimVeil"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	for index: int in range(VEIL_RECTS.size()):
		var piece: ColorRect = ColorRect.new()
		piece.name = "Piece%d" % index
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.position = VEIL_RECTS[index].position
		piece.size = VEIL_RECTS[index].size
		piece.material = _look
		add_child(piece)


## `machine` lit by `p` (0 dim .. 1 lit): its brightness through its modulate, its saturation
## through the veil (hidden once lit).
func set_lit(machine: CanvasItem, p: float) -> void:
	lit = clampf(p, 0.0, 1.0)
	var brightness: float = lerpf(DIM_BRIGHTNESS, 1.0, lit)
	machine.modulate = Color(brightness, brightness, brightness)
	visible = lit < 1.0
	_look.set_shader_parameter("saturation", lerpf(DIM_SATURATION, 1.0, lit))


## The veil's pieces' rects in the machine, for layout tests.
func piece_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for piece: Node in get_children():
		var rect: ColorRect = piece as ColorRect
		if rect != null:
			rects.append(Rect2(rect.position, rect.size))
	return rects


## While idle `machine` and every part of it take no click (a click reaches the wall).
static func idle_mouse(machine: Control, idle: bool) -> void:
	machine.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED if idle else Control.MOUSE_BEHAVIOR_INHERITED
	)


## The machine's parts at rest: its head plain, its keys cream and unlit with nothing pressed,
## its display blank, its stock window shut (`_run_state`: the run it showed, or null).
static func rest_parts(view: RewardMachineView, _run_state: RunState) -> void:
	view.head.set_stamp("", "")
	for key: ChuteKey in view.keys:
		key.show_state(RewardMachine.ChuteState.OPEN, false)
		key.set_pressed(false)
	view.display.set_bin(false, false)
	view.display.show_message("", "")
	view.stock.show_chutes([], -1)
