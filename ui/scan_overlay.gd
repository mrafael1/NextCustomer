class_name ScanOverlay
extends Control
## The scan's marks over the stage (#75; style frame v2's spec sections 3.3 and 3.4, delta
## section 11): corner brackets around the scanned or hovered sprite (gold for the count-up's
## current scan, tomato for a hover), the handheld scanner in its posed look (scanner_aim, its
## window lit) overhead beside the sprite, its bottom on the sprite's top, and its beam: a faint
## cone of light fanning from the scanner's window across the whole sprite, and a scan line across
## the sprite. One rule serves the belt and the hand. The overlay borrows the handheld from its
## cradle for a pose and gives it back with dock(). The sprite rects it takes are global, so a
## scaled row (RowStrip's 8 and 9 slots) is marked where it is drawn. The poses snap into place;
## only a hover's beam may pulse (start_beam_loop), which reduced motion leaves off.

## Round 3: a chunky pistol-grip scanner (28x16 art at 2x, 56x32), nose to the left, so it reads
## at 1x. It stands overhead-right of the sprite, or overhead-left (flipped) when the caller asks,
## e.g. when a hand item's popup opens on the right. 32 px tall, so over a lifted hand sprite it
## stays under the strip (Redraw, CHECKOUT, the status panel). Over a belt sprite it reaches past
## the cell, onto the next cell's plaque when that cell has one.
const SCANNER_SIZE := Vector2(56, 32)
## The scanner tucks this far over the sprite's edge.
const SCANNER_TUCK := 4.0
## The beam leaves from the lit window, art (1, 7) (mirrored when the scanner is flipped).
const NOSE := Vector2(2, 14)
## The cone ends this far inside the sprite's far edge, CONE_HALF above and below its middle.
const CONE_INSET := 4.0
const CONE_HALF := 16.0
## Fainter than the scan line: the cone lies over the whole sprite.
const BEAM_ALPHA := 0.25
const LINE_ALPHA := 0.85
## The beam's pulse (start_beam_loop): the cone fades to BEAM_PULSE_LOW of its alpha and back,
## once every BEAM_PULSE_S seconds.
const BEAM_PULSE_LOW := 0.4
const BEAM_PULSE_S := 0.8
const LINE_WIDTH := 2.0
const BRACKET_ARM := 12.0
const BRACKET_WIDTH := 2.0
const BRACKET_OUTSET := 4.0

const SCANNER_AIM := preload("res://art/scenery/scanner_aim.png")

var _brackets: Rect2 = Rect2()
var _color: Color = Palette.TOMATO
var _beam: PackedVector2Array = PackedVector2Array()
var _line: Rect2 = Rect2()
## The cone's share of BEAM_ALPHA, which the beam's pulse moves.
var _beam_strength: float = 1.0
var _beam_loop: Tween
var _handheld: TextureRect
## Where the handheld docks: its parent, its place among that parent's children and its look.
var _home: Control
var _home_index: int = -1
var _home_rect: Rect2 = Rect2()
var _home_texture: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _beam.size() == 3:
		draw_colored_polygon(_beam, Color(Palette.TOMATO, BEAM_ALPHA * _beam_strength))
		draw_rect(_line, Color(Palette.TOMATO, LINE_ALPHA))
	if _brackets.size != Vector2.ZERO:
		draw_brackets(self, _brackets, _color)


## Hands the overlay the docked handheld `scanner` (a sprite in its cradle): where it is now is
## where dock() puts it back.
func set_handheld(scanner: TextureRect) -> void:
	_handheld = scanner
	_home = scanner.get_parent() as Control
	_home_index = scanner.get_index() if _home != null else -1
	_home_rect = Rect2(scanner.position, scanner.size)
	_home_texture = scanner.texture


## The handheld scanner (docked or posed), or null before set_handheld().
func handheld() -> TextureRect:
	return _handheld


## Marks a hovered sprite (`sprite`, a global rect): tomato brackets and the posed scanner
## overhead-right of it, or overhead-left and flipped when `on_left` (e.g. when a hand item's
## popup opens on its right). The scanner takes the other side when the asked one would leave
## the overlay (the first hand item's left, the last belt cell's right).
func pose_hover(sprite: Rect2, on_left: bool) -> void:
	_pose(_to_local(sprite), Palette.TOMATO, on_left)


## Marks the count-up's current sprite (`sprite`, a global rect): gold brackets and the posed
## scanner overhead-right of it. Its beam never pulses.
func pose_scan(sprite: Rect2) -> void:
	stop_beam_loop()
	_pose(_to_local(sprite), Palette.GOLD, false)


## Clears the marks and puts the handheld back in its cradle, unflipped, in its docked look.
func dock() -> void:
	clear()
	if _handheld == null or _home == null or _handheld.get_parent() == _home:
		return
	if _handheld.get_parent() != null:
		_handheld.get_parent().remove_child(_handheld)
	_home.add_child(_handheld)
	_home.move_child(_handheld, mini(_home_index, _home.get_child_count() - 1))
	_handheld.texture = _home_texture
	_handheld.flip_h = false
	_handheld.position = _home_rect.position
	_handheld.size = _home_rect.size


## Clears the brackets and the beam (stopping its pulse); the handheld stays where it is.
func clear() -> void:
	stop_beam_loop()
	_brackets = Rect2()
	_beam = PackedVector2Array()
	_line = Rect2()
	queue_redraw()


## Pulses the beam's cone until clear() or stop_beam_loop(): a looping tween, so a caller
## honouring reduced motion never starts it.
func start_beam_loop() -> void:
	if has_beam_loop() or not is_inside_tree():
		return
	_beam_loop = create_tween().set_loops()
	_beam_loop.set_trans(Tween.TRANS_SINE)
	_beam_loop.tween_method(_set_beam_strength, 1.0, BEAM_PULSE_LOW, BEAM_PULSE_S / 2.0)
	_beam_loop.tween_method(_set_beam_strength, BEAM_PULSE_LOW, 1.0, BEAM_PULSE_S / 2.0)


## Stops the beam's pulse, the cone back at full strength.
func stop_beam_loop() -> void:
	if _beam_loop != null:
		_beam_loop.kill()
		_beam_loop = null
	_set_beam_strength(1.0)


func has_beam_loop() -> bool:
	return _beam_loop != null and _beam_loop.is_valid()


## Whether the handheld is out of its cradle.
func is_posed() -> bool:
	return _handheld != null and _handheld.get_parent() == self


## The posed scanner's rect over the lifted `sprite`: its bottom on the sprite's top, tucked
## SCANNER_TUCK over the sprite's right edge, or over its left edge when `on_left`.
static func scanner_rect(sprite: Rect2, on_left: bool) -> Rect2:
	var x: float = sprite.end.x - SCANNER_TUCK
	if on_left:
		x = sprite.position.x + SCANNER_TUCK - SCANNER_SIZE.x
	return Rect2(Vector2(x, sprite.position.y - SCANNER_SIZE.y), SCANNER_SIZE)


## `item`'s sprite as a global rect, lifted by its scan_lift() and unscaled, wherever its lift
## or punch is now: where the count-up poses the scanner as the scan starts lifting it.
static func lifted_sprite(item: ItemView) -> Rect2:
	var top_left: Vector2 = item.center() - ItemView.SPRITE_SIZE / 2.0
	return Rect2(top_left + Vector2(0, item.scan_lift()), ItemView.SPRITE_SIZE)


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


## The beam's cone in this overlay's coordinates: the nose, then the two points at the sprite's
## far edge (empty when nothing is marked).
func beam() -> PackedVector2Array:
	return _beam


## Marks `sprite` (this overlay's coordinates): brackets in `color`, and the handheld (moved
## onto this overlay and switched to its posed look) overhead-right of the sprite, or
## overhead-left and flipped when `on_left`, with its beam across the sprite.
func _pose(sprite: Rect2, color: Color, on_left: bool) -> void:
	_brackets = sprite.grow(BRACKET_OUTSET)
	_color = color
	var middle: float = sprite.get_center().y
	_line = Rect2(sprite.position.x, middle - LINE_WIDTH / 2.0, sprite.size.x, LINE_WIDTH)
	_beam = PackedVector2Array()
	queue_redraw()
	if _handheld == null:
		return
	var bounds: Rect2 = Rect2(Vector2.ZERO, size)
	if not bounds.encloses(scanner_rect(sprite, on_left)):
		if bounds.encloses(scanner_rect(sprite, not on_left)):
			on_left = not on_left
	if _handheld.get_parent() != self:
		if _handheld.get_parent() != null:
			_handheld.get_parent().remove_child(_handheld)
		add_child(_handheld)
	_handheld.texture = SCANNER_AIM
	_handheld.flip_h = on_left
	_handheld.size = SCANNER_SIZE
	_handheld.position = scanner_rect(sprite, on_left).position
	var nose: Vector2 = _handheld.position + NOSE
	if on_left:
		nose.x = _handheld.position.x + SCANNER_SIZE.x - NOSE.x
	# The cone crosses the sprite to its far edge, so it reads as light and not as a stray line.
	var edge: float = sprite.end.x - CONE_INSET if on_left else sprite.position.x + CONE_INSET
	_beam = PackedVector2Array(
		[nose, Vector2(edge, middle - CONE_HALF), Vector2(edge, middle + CONE_HALF)]
	)


func _set_beam_strength(strength: float) -> void:
	_beam_strength = strength
	queue_redraw()


## A global rect in this overlay's coordinates.
func _to_local(rect: Rect2) -> Rect2:
	return get_global_transform().affine_inverse() * rect
