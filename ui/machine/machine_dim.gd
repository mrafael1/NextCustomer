class_name MachineDim
extends ColorRect
## The idle machine's look on the back wall (#77 machine v2, Q1 = A; the approved page's filter),
## kept out of RewardMachineView so it stays under gdlint's file length: the veil over the machine
## (its last child) desaturates what is drawn under it (presentation/machine_dim.gdshader) while
## the machine's modulate darkens it; set_lit eases both from dim (0) to lit (1). Its statics put
## the machine's parts at rest and stop it taking clicks between visits.

## The idle machine's brightness and saturation.
const DIM_BRIGHTNESS := 0.62
const DIM_SATURATION := 0.55
## The veil's rect in the machine: over the cabinet, its head and its hood, with their shadows.
const VEIL_RECT := Rect2(-10, -8, 456, 646)
const SHADER := preload("res://presentation/machine_dim.gdshader")

## How lit the machine is (0 dim .. 1 lit).
var lit: float = 1.0


func _init() -> void:
	name = "DimVeil"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = VEIL_RECT.position
	size = VEIL_RECT.size
	var dim: ShaderMaterial = ShaderMaterial.new()
	dim.shader = SHADER
	material = dim


## `machine` lit by `p` (0 dim .. 1 lit): its brightness through its modulate, its saturation
## through the veil (hidden once lit).
func set_lit(machine: CanvasItem, p: float) -> void:
	lit = clampf(p, 0.0, 1.0)
	var brightness: float = lerpf(DIM_BRIGHTNESS, 1.0, lit)
	machine.modulate = Color(brightness, brightness, brightness)
	visible = lit < 1.0
	(material as ShaderMaterial).set_shader_parameter("saturation", lerpf(DIM_SATURATION, 1.0, lit))


## While idle `machine` and every part of it take no click (a click reaches the wall).
static func idle_mouse(machine: Control, idle: bool) -> void:
	machine.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED if idle else Control.MOUSE_BEHAVIOR_INHERITED
	)


## The machine's parts at rest: its head plain, its keys cream and unlit with nothing pressed,
## its display blank, its slip put away (`_run_state`: the run it showed, or null).
static func rest_parts(view: RewardMachineView, _run_state: RunState) -> void:
	view.head.set_stamp("", "")
	for key: ChuteKey in view.keys:
		key.show_state(RewardMachine.ChuteState.OPEN, 0, false)
		key.set_tab(false)
		key.set_pressed(false)
	view.display.set_bin(false, false)
	view.display.show_message("", "")
	view.slip.rest()
