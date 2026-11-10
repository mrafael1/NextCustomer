class_name MorningPin
extends MorningMark
## A MORNING pin on the belt (v1.24, the user's picks of 2026-11-10 on the mock-up
## `docs/art/mockups/morning_mark.html`, option 4, in place of v1.06's ribbon; KeywordMarks): the
## MORNING chip's own Breakfast dot at 2x, pinned on the foot of a ticket of the MORNING. A SIDE px
## ink octagon (its corners cut in two STEP px steps), the Breakfast family's face inside its
## STEP px rim, a GLINT of light on its top left, and a soft ink shadow SHADOW down and right of
## it, as a thing stuck on the ticket has. The MORNING's chain (MorningLink) runs under the pins.
##
## As the anchor post (`post`), it stands at the row's start, where the chain begins: POST_WIDTH
## wide and SIDE tall, its corners cut one STEP, the same rim, face, glint (POST_GLINT) and
## shadow, so the line reads as starting at the first slot.

const SIDE := 18.0
const STEP := 2.0
const SHADOW := Vector2(2, 2)
## The glint's rect (the pin's coordinates).
const GLINT := Rect2(6, 4, 4, 2)
const POST_WIDTH := 8.0
const POST_GLINT := Rect2(2, 4, 2, 4)

## The anchor post at the row's start, not a pin.
var post: bool = false


func _init(as_post: bool = false) -> void:
	super()
	post = as_post
	size = Vector2(POST_WIDTH if post else SIDE, SIDE)


## The room a pin takes with its shadow.
static func footprint() -> Vector2:
	return Vector2(SIDE, SIDE) + SHADOW


func _draw() -> void:
	var shadow: Color = Color(Palette.INK, SHADOW_ALPHA)
	if post:
		_cut(SHADOW, size, shadow)
		_cut(Vector2.ZERO, size, Palette.INK)
		_cut(Vector2(STEP, STEP), size - Vector2(STEP, STEP) * 2.0, face_color())
		draw_rect(POST_GLINT, light_color())
		return
	_octagon(SHADOW, SIDE, shadow)
	_octagon(Vector2.ZERO, SIDE, Palette.INK)
	_octagon(Vector2(STEP, STEP), SIDE - STEP * 2.0, face_color())
	draw_rect(GLINT, light_color())


func _octagon(at: Vector2, side: float, colour: Color) -> void:
	var step: Vector2 = Vector2(STEP, STEP)
	draw_rect(Rect2(at + Vector2(STEP * 2.0, 0), Vector2(side - STEP * 4.0, side)), colour)
	draw_rect(Rect2(at + step, Vector2(side, side) - step * 2.0), colour)
	draw_rect(Rect2(at + Vector2(0, STEP * 2.0), Vector2(side, side - STEP * 4.0)), colour)


## A `box` sized rect at `at` with its corners cut one STEP.
func _cut(at: Vector2, box: Vector2, colour: Color) -> void:
	draw_rect(Rect2(at + Vector2(STEP, 0), Vector2(box.x - STEP * 2.0, box.y)), colour)
	draw_rect(Rect2(at + Vector2(0, STEP), Vector2(box.x, box.y - STEP * 2.0)), colour)
