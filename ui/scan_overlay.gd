class_name ScanOverlay
extends Control
## The scan's marks over the stage (#75; mock-up B2, #80): corner brackets around the scanned
## sprite (gold for the count-up's current scan, tomato for a hover) and a scan line across its
## middle. B2 has no handheld scanner, so nothing stands over the sprite. One rule serves the belt
## and the hand. The sprite rects it takes are global, so a scaled row (RowStrip's 8 slots)
## is marked where it is drawn. The marks snap into place; only a hover's scan line may pulse
## (start_beam_loop), which reduced motion leaves off.
##
## The count-up's scanner (#86 v6, the belt ride) marks the item at the scanner (pose_scanner):
## gold brackets and the scan line resting across its middle, which sweep() runs from the item's
## foot to its top once as it is scanned, a faint beam under it, then rests again.

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
## The sweep's beam: the line's colour at this alpha from the line down to the sprite's foot.
const SWEEP_BEAM_ALPHA := 0.28

var _brackets: Rect2 = Rect2()
var _color: Color = Palette.TOMATO
var _line: Rect2 = Rect2()
var _line_color: Color = Palette.TOMATO
## The marked sprite (this overlay's coordinates), which the sweep runs up.
var _sprite: Rect2 = Rect2()
var _sweep: Tween
## The scan line's share of LINE_ALPHA, which its pulse moves.
var _beam_strength: float = 1.0
var _beam_loop: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _line.size != Vector2.ZERO:
		if is_sweeping():
			var beam: Rect2 = Rect2(_line.position.x, _line.end.y, _line.size.x, 0.0)
			beam.size.y = maxf(_sprite.end.y - beam.position.y, 0.0)
			draw_rect(beam, Color(_line_color, SWEEP_BEAM_ALPHA))
		draw_rect(_line, Color(_line_color, LINE_ALPHA * _beam_strength))
	if _brackets.size != Vector2.ZERO:
		draw_brackets(self, _brackets, _color)


## Marks a hovered sprite (`sprite`, a global rect): tomato brackets and the scan line.
func pose_hover(sprite: Rect2) -> void:
	_pose(_to_local(sprite), Palette.TOMATO, true)


## Marks the count-up's current sprite (`sprite`, a global rect): gold brackets, no scan line.
func pose_scan(sprite: Rect2) -> void:
	stop_beam_loop()
	_pose(_to_local(sprite), Palette.GOLD, false)


## Marks the item at the count-up's scanner (`sprite`, a global rect): gold brackets and the scan
## line across its middle, in `color` (tomato; the count may pass another, e.g. green once the
## quota is met). sweep() runs the line up the sprite.
func pose_scanner(sprite: Rect2, color: Color = Palette.TOMATO) -> void:
	stop_beam_loop()
	_pose(_to_local(sprite), Palette.GOLD, true)
	_line_color = color


## Runs the scanner's line (pose_scanner's) once from the sprite's foot up to its top over
## `seconds`, with a faint beam under it, then rests it across the middle again; never loops.
## The tween comes from `make_tween` when it is given (the count-up's, so its hit-stops and skips
## hold and speed it), else from the overlay. Under `reduced` motion, or with no line, it does
## nothing: the line stays still across the middle.
func sweep(seconds: float, reduced: bool = false, make_tween: Callable = Callable()) -> void:
	_stop_sweep()
	if reduced or seconds <= 0.0 or _line.size == Vector2.ZERO:
		return
	if not make_tween.is_valid() and not is_inside_tree():
		return
	_set_line_y(_sprite.end.y - LINE_WIDTH)
	_sweep = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_sweep.tween_method(_sweep_to, _sprite.end.y - LINE_WIDTH, _sprite.position.y, seconds)
	_sweep.tween_callback(_end_sweep)


## Whether the scanner's line is sweeping up its sprite.
func is_sweeping() -> bool:
	return _sweep != null and _sweep.is_valid()


## The scan line's colour: tomato, or the colour pose_scanner was given.
func line_color() -> Color:
	return _line_color


## Clears the marks (as clear()): the count-up's and the scan's word for ending a scan.
func dock() -> void:
	clear()


## Clears the brackets and the scan line (stopping its pulse).
func clear() -> void:
	stop_beam_loop()
	_stop_sweep()
	_brackets = Rect2()
	_line = Rect2()
	_sprite = Rect2()
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
## line up with the lifted item. A basket item's ends at the basket's front rim
## (ItemView.BASKET_RIM_Y), so the brackets' lower arms rest on the lip, not on the slotted face.
static func lifted_sprite(item: ItemView) -> Rect2:
	var factor: Vector2 = item.get_global_transform().get_scale()
	var drawn: Vector2 = ItemView.SPRITE_SIZE * factor
	var top_left: Vector2 = item.center() - drawn / 2.0
	var sprite: Rect2 = Rect2(top_left + Vector2(0, item.scan_lift() * factor.y), drawn)
	if item.form == ItemView.Form.BASKET:
		var rim: float = (item.get_global_transform() * Vector2(0, ItemView.BASKET_RIM_Y)).y
		sprite.size.y = minf(sprite.size.y, rim - sprite.position.y)
	return sprite


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
## marked or pose_scan marks it).
func scan_line() -> Rect2:
	return _line


## Marks `sprite` (this overlay's coordinates): brackets in `color`, with the scan line across
## its middle when `line`.
func _pose(sprite: Rect2, color: Color, line: bool) -> void:
	_stop_sweep()
	_brackets = sprite.grow(BRACKET_OUTSET)
	_color = color
	_line_color = Palette.TOMATO
	_sprite = sprite
	_line = Rect2()
	if line:
		_line = Rect2(sprite.position.x, 0.0, sprite.size.x, LINE_WIDTH)
		_rest_line()
	queue_redraw()


## Puts the scan line's top edge at `y` (this overlay's coordinates).
func _set_line_y(y: float) -> void:
	_line.position.y = y
	queue_redraw()


## The sweeping line's step: at `y`, on the art grid so it moves in whole art pixels.
func _sweep_to(y: float) -> void:
	_set_line_y(snappedf(y, ArtStyle.ART_SCALE))


## Rests the scan line across the marked sprite's middle.
func _rest_line() -> void:
	_set_line_y(_sprite.get_center().y - LINE_WIDTH / 2.0)


## The sweep's end: the line back across the middle, the beam gone.
func _end_sweep() -> void:
	_sweep = null
	_rest_line()


func _stop_sweep() -> void:
	if _sweep != null:
		_sweep.kill()
		_sweep = null


func _set_beam_strength(strength: float) -> void:
	_beam_strength = strength
	queue_redraw()


## A global rect in this overlay's coordinates.
func _to_local(rect: Rect2) -> Rect2:
	return get_global_transform().affine_inverse() * rect
