class_name ScanOverlay
extends Control
## The scan's marks in style frame v2 (#75, spec sections 3.3 and 3.4; round 2, delta section 11):
## corner brackets around the scanned or hovered sprite (gold for the current scan, tomato for a
## hover), the handheld scanner in its posed (scanner_aim, its window lit) look overhead beside
## the sprite, its bottom on the lifted sprite's top, and its beam: a faint cone of light fanning
## from the scanner's window across the whole sprite, and a scan line across the sprite. One rule
## serves the belt and the hand. The poses are mocked (nothing animates).

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
const LINE_WIDTH := 2.0
const BRACKET_ARM := 12.0
const BRACKET_WIDTH := 2.0
const BRACKET_OUTSET := 4.0

const SCANNER_AIM := preload("res://art/scenery/scanner_aim.png")

var _brackets: Rect2 = Rect2()
var _color: Color = Color.WHITE
var _beam: PackedVector2Array = PackedVector2Array()
var _line: Rect2 = Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _beam.size() == 3:
		draw_colored_polygon(_beam, Color(StyleFrameV2.TOMATO, BEAM_ALPHA))
		draw_rect(_line, Color(StyleFrameV2.TOMATO, LINE_ALPHA))
	if _brackets.size == Vector2.ZERO:
		return
	var centre: Vector2 = _brackets.get_center()
	var corners: Array[Vector2] = [
		_brackets.position,
		Vector2(_brackets.end.x, _brackets.position.y),
		Vector2(_brackets.position.x, _brackets.end.y),
		_brackets.end,
	]
	for corner: Vector2 in corners:
		var right: bool = corner.x > centre.x
		var down: bool = corner.y > centre.y
		var x: float = corner.x - (BRACKET_ARM if right else 0.0)
		var y: float = corner.y - (BRACKET_WIDTH if down else 0.0)
		draw_rect(Rect2(x, y, BRACKET_ARM, BRACKET_WIDTH), _color)
		x = corner.x - (BRACKET_WIDTH if right else 0.0)
		y = corner.y - (BRACKET_ARM if down else 0.0)
		draw_rect(Rect2(x, y, BRACKET_WIDTH, BRACKET_ARM), _color)


## Marks the sprite at `sprite` (this overlay's coordinates, lifted): brackets in `color`, and the
## `scanner` (moved onto this overlay and switched to its posed look) overhead-right of the sprite,
## or overhead-left and flipped when `on_left`, with its beam across the sprite.
func pose(scanner: TextureRect, sprite: Rect2, color: Color, on_left: bool) -> void:
	_brackets = sprite.grow(BRACKET_OUTSET)
	_color = color
	if scanner.get_parent() != null:
		scanner.get_parent().remove_child(scanner)
	add_child(scanner)
	scanner.texture = SCANNER_AIM
	scanner.flip_h = on_left
	scanner.size = SCANNER_SIZE
	scanner.position = scanner_rect(sprite, on_left).position
	var nose: Vector2 = scanner.position + NOSE
	if on_left:
		nose.x = scanner.position.x + SCANNER_SIZE.x - NOSE.x
	var middle: float = sprite.get_center().y
	# The cone crosses the sprite to its far edge, so it reads as light and not as a stray line.
	var edge: float = sprite.end.x - CONE_INSET if on_left else sprite.position.x + CONE_INSET
	_beam = PackedVector2Array(
		[nose, Vector2(edge, middle - CONE_HALF), Vector2(edge, middle + CONE_HALF)]
	)
	_line = Rect2(sprite.position.x, middle - LINE_WIDTH / 2.0, sprite.size.x, LINE_WIDTH)
	queue_redraw()


## The posed scanner's rect over the lifted `sprite`: its bottom on the sprite's top, tucked
## SCANNER_TUCK over the sprite's right edge, or over its left edge when `on_left`.
static func scanner_rect(sprite: Rect2, on_left: bool) -> Rect2:
	var x: float = sprite.end.x - SCANNER_TUCK
	if on_left:
		x = sprite.position.x + SCANNER_TUCK - SCANNER_SIZE.x
	return Rect2(Vector2(x, sprite.position.y - SCANNER_SIZE.y), SCANNER_SIZE)


## The brackets' outer rect (empty when nothing is marked).
func brackets() -> Rect2:
	return _brackets


## The beam's cone: the nose, then the two points at the sprite's far edge.
func beam() -> PackedVector2Array:
	return _beam
