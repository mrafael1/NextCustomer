class_name ScanOverlay
extends Control
## The scan's marks over the stage (#75; mock-up B2, #80): corner brackets around the scanned
## sprite (gold for the count-up's current scan, tomato for a hover) and a scan line across its
## middle. B2 has no handheld scanner, so nothing stands over the sprite. One rule serves the belt
## and the hand. The sprite rects it takes are global, so a scaled row (RowStrip's 8 and 9 slots)
## is marked where it is drawn. The marks snap into place; only a hover's scan line may pulse
## (start_beam_loop), which reduced motion leaves off.

## The scan line, and its pulse (start_beam_loop): it fades to BEAM_PULSE_LOW of its alpha and
## back, once every BEAM_PULSE_S seconds.
const LINE_ALPHA := 0.85
const BEAM_PULSE_LOW := 0.4
const BEAM_PULSE_S := 0.8
const LINE_WIDTH := 2.0
const BRACKET_ARM := 12.0
const BRACKET_WIDTH := 2.0
const BRACKET_OUTSET := 4.0
## The count-up's brackets' top edge this far over the art's visible top (mock-up B2), never above
## the sprite's own brackets.
const SCAN_ART_GAP := 12.0

var _brackets: Rect2 = Rect2()
var _color: Color = Palette.TOMATO
var _line: Rect2 = Rect2()
## The scan line's share of LINE_ALPHA, which its pulse moves.
var _beam_strength: float = 1.0
var _beam_loop: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _line.size != Vector2.ZERO:
		draw_rect(_line, Color(Palette.TOMATO, LINE_ALPHA * _beam_strength))
	if _brackets.size != Vector2.ZERO:
		draw_brackets(self, _brackets, _color)


## Marks a hovered sprite (`sprite`, a global rect): tomato brackets and the scan line.
func pose_hover(sprite: Rect2) -> void:
	_pose(_to_local(sprite), Palette.TOMATO, true)


## Marks the count-up's current sprite (`sprite`, a global rect): gold brackets, no scan line.
func pose_scan(sprite: Rect2) -> void:
	stop_beam_loop()
	_pose(_to_local(sprite), Palette.GOLD, false)


## Clears the marks (as clear()): the count-up's and the scan's word for ending a scan.
func dock() -> void:
	clear()


## Clears the brackets and the scan line (stopping its pulse).
func clear() -> void:
	stop_beam_loop()
	_brackets = Rect2()
	_line = Rect2()
	queue_redraw()


## Pulses the scan line until clear() or stop_beam_loop(): a looping tween, so a caller
## honouring reduced motion never starts it.
func start_beam_loop() -> void:
	if has_beam_loop() or not is_inside_tree():
		return
	_beam_loop = create_tween().set_loops()
	_beam_loop.set_trans(Tween.TRANS_SINE)
	_beam_loop.tween_method(_set_beam_strength, 1.0, BEAM_PULSE_LOW, BEAM_PULSE_S / 2.0)
	_beam_loop.tween_method(_set_beam_strength, BEAM_PULSE_LOW, 1.0, BEAM_PULSE_S / 2.0)


## Stops the scan line's pulse, back at full strength.
func stop_beam_loop() -> void:
	if _beam_loop != null:
		_beam_loop.kill()
		_beam_loop = null
	_set_beam_strength(1.0)


func has_beam_loop() -> bool:
	return _beam_loop != null and _beam_loop.is_valid()


## Whether a sprite is marked.
func is_posed() -> bool:
	return _brackets.size != Vector2.ZERO


## `item`'s sprite as a global rect, lifted by its scan_lift(), wherever its lift or punch is
## now, and scaled as the item is drawn (a wide row is scaled down): where the count-up marks it
## as the scan starts lifting it, and where the full scan's popup and marks are placed, so they
## line up with the lifted item.
static func lifted_sprite(item: ItemView) -> Rect2:
	var factor: Vector2 = item.get_global_transform().get_scale()
	var drawn: Vector2 = ItemView.SPRITE_SIZE * factor
	var top_left: Vector2 = item.center() - drawn / 2.0
	return Rect2(top_left + Vector2(0, item.scan_lift() * factor.y), drawn)


## The count-up's frame for `item` (global, for pose_scan): its lifted sprite (lifted_sprite)
## with the top brought down to SCAN_ART_GAP - BRACKET_OUTSET over the art's visible top, so the
## brackets hug the art as B2's do and the current paid chip pops above them; a tall item's frame
## is the sprite's.
static func scan_frame(item: ItemView) -> Rect2:
	var sprite: Rect2 = lifted_sprite(item)
	var factor: float = item.get_global_transform().get_scale().y
	var texture: Texture2D = item.sprite().texture
	var inset: float = ContactShadow.opaque_rect(texture).position.y * sprite.size.y
	var art: float = sprite.position.y + inset / texture.get_height()
	var top: float = maxf(sprite.position.y, art - (SCAN_ART_GAP - BRACKET_OUTSET) * factor)
	return Rect2(sprite.position.x, top, sprite.size.x, sprite.end.y - top)


## Draws corner brackets in `color` on `canvas`, their outer edges on `rect` (the sprite's rect
## grown by BRACKET_OUTSET). A selected item draws its gold ones the same way.
static func draw_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var centre: Vector2 = rect.get_center()
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		rect.end
	]
	for corner: Vector2 in corners:
		var right: bool = corner.x > centre.x
		var down: bool = corner.y > centre.y
		var x: float = corner.x - (BRACKET_ARM if right else 0.0)
		var y: float = corner.y - (BRACKET_WIDTH if down else 0.0)
		canvas.draw_rect(Rect2(x, y, BRACKET_ARM, BRACKET_WIDTH), color)
		x = corner.x - (BRACKET_WIDTH if right else 0.0)
		y = corner.y - (BRACKET_ARM if down else 0.0)
		canvas.draw_rect(Rect2(x, y, BRACKET_WIDTH, BRACKET_ARM), color)


## The brackets' outer rect in this overlay's coordinates (empty when nothing is marked).
func brackets() -> Rect2:
	return _brackets


## The brackets' colour: gold for the count-up's scan, tomato for a hover.
func bracket_color() -> Color:
	return _color


## The scan line across the marked sprite in this overlay's coordinates (empty when nothing is
## marked or the count-up marks it).
func scan_line() -> Rect2:
	return _line


## Marks `sprite` (this overlay's coordinates): brackets in `color`, with the scan line across
## its middle when `line`.
func _pose(sprite: Rect2, color: Color, line: bool) -> void:
	_brackets = sprite.grow(BRACKET_OUTSET)
	_color = color
	var middle: float = sprite.get_center().y
	_line = Rect2()
	if line:
		_line = Rect2(sprite.position.x, middle - LINE_WIDTH / 2.0, sprite.size.x, LINE_WIDTH)
	queue_redraw()


func _set_beam_strength(strength: float) -> void:
	_beam_strength = strength
	queue_redraw()


## A global rect in this overlay's coordinates.
func _to_local(rect: Rect2) -> Rect2:
	return get_global_transform().affine_inverse() * rect
