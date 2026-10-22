class_name StoreCamera
extends Control
## The store's camera (#77 machine v2, Q1 = A; docs/art/mockups/machine_77_v2.html, cameraA): a
## full-window layer at the back of the shift screen that holds the zoomed world: the backdrop's
## wall, counter and floor bands, the store sections (StoreShelves) and the stage's world layer
## (ShiftStage.world: the monitor, the machine on the back wall, the fore). set_view(progress)
## glides it from the store at 1x (0) to the machine at ShiftStage.CAMERA_ZOOM (1), on the
## mock-up's quadratic ease: stage point p shows at stage_origin + offset + p x zoom, where the
## offset runs from 0 to ShiftStage.CAMERA_OFFSET. At 1 the position is rounded to whole pixels,
## so the machine (half size on the wall) shows at a net scale of exactly 1, crisp.
##
## Over the world (and under the top band and the hud, which never zoom) it holds the reduced
## motion cut's charcoal fade (set_fade). The LEGENDARY reveal's jolt shakes the world too
## (set_shake, screen px). Decor only: it takes no click itself (the wall in it does).

## The fade's colour (its alpha is set_fade's).
const FADE_COLOUR := Palette.CHARCOAL

## The zoomed layer: the backdrop's parts and the stage's world, in window coordinates at 1x.
var content: Control
var fade: ColorRect
var _world: Control
var _progress: float = 0.0
var _shake: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "StoreCamera"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = FADE_COLOUR
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	fade.visible = false
	add_child(fade)
	resized.connect(_apply)


## Takes the stage's world layer (centred in the window as the stage is) into the zoomed content,
## over the backdrop's parts already in it.
func adopt(world: Control) -> void:
	_world = world
	if world.get_parent() != null:
		world.get_parent().remove_child(world)
	content.add_child(world)


## The camera at `share` (0 the store at 1x .. 1 the machine at 2x), eased.
func set_view(share: float) -> void:
	var clamped: float = clampf(share, 0.0, 1.0)
	if clamped == _progress and content.scale.x == zoom_at(clamped):
		return
	_progress = clamped
	_apply()


## The reduced-motion cut's fade over the world (0: none).
func set_fade(alpha: float) -> void:
	fade.visible = alpha > 0.0
	fade.modulate.a = alpha


## The LEGENDARY jolt on the world, in screen px (zero puts it back).
func set_shake(shake: Vector2) -> void:
	if shake == _shake:
		return
	_shake = shake
	_apply()


## The camera's progress (0 .. 1, not eased).
func progress() -> float:
	return _progress


## Whether the camera is at the machine.
func is_zoomed() -> bool:
	return _progress >= 1.0


## The world's zoom now.
func zoom() -> float:
	return content.scale.x


## Where `rect_on_stage` (stage coordinates, at 1x) shows on screen now (global).
func zoomed_rect(rect_on_stage: Rect2) -> Rect2:
	var world: Control = _world if is_instance_valid(_world) else content
	return world.get_global_transform() * rect_on_stage


## The zoom at `share` on the ease.
static func zoom_at(share: float) -> float:
	return lerpf(1.0, ShiftStage.CAMERA_ZOOM, ease_in_out(share))


## The mock-up's ease (quadratic in-out).
static func ease_in_out(p: float) -> float:
	var x: float = clampf(p, 0.0, 1.0)
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


func _apply() -> void:
	var e: float = ease_in_out(_progress)
	var zoomed: float = lerpf(1.0, ShiftStage.CAMERA_ZOOM, e)
	var origin: Vector2 = (size - ShiftStage.SIZE) / 2.0
	var at: Vector2 = origin * (1.0 - zoomed) + ShiftStage.CAMERA_OFFSET * e
	if _progress >= 1.0 or _progress <= 0.0:
		at = at.round()
	content.scale = Vector2(zoomed, zoomed)
	content.position = at + _shake
