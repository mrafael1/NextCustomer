class_name SlipSign
extends Node2D
## The training week's slip counter (2026-11-01, in place of v0.68's hint in the SHIFT chip): a
## small paper sign hanging on two cords under the week chip's right end (under its day pips, clear
## of the PREMIUM NEXT tag that hangs from the gauge's end), reading the slips the
## training week still forgives ("2 SLIPS", WriteUp.hint_text's short form). It swings gently
## (SWING_DEG each way every SWING_SECONDS) and punches when its count changes; reduced motion
## (`reduced_motion`) keeps it still. A Node2D, so the top bar's row never lays it out; decor only,
## it takes no clicks.

const FONT_SIZE := 11
const WEIGHT := 750
## The text's room inside the border (x each side, y above and below).
const PADDING := Vector2(5, 1)
const BORDER := 2.0
## The cords: this long, this far in from the sign's ends.
const CORD := 4.0
const CORD_INSET := 6.0
## Its right end this far left of the week chip's, its cords from this far up the chip's foot.
const INSET := 8.0
const TUCK := 2.0
const SWING_DEG := 3.0
const SWING_SECONDS := 2.6
## A new count punches the sign from PUNCH back to 1 over PUNCH_SECONDS.
const PUNCH := 1.3
const PUNCH_SECONDS := 0.3
const SHADOW := Vector2(2, 2)

## Returns whether to reduce motion; an empty Callable means no.
var reduced_motion: Callable = Callable()
var text: String = ""
var _chip: Control
var _time: float = 0.0
var _punch: float = 0.0


func _init() -> void:
	name = "SlipSign"
	visible = false


## Hangs under `chip` (a sibling in the top bar's row).
func follow(chip: Control) -> void:
	_chip = chip


## Shows `value` (hidden when empty); a changed count punches.
func show_text(value: String) -> void:
	if not value.is_empty() and not text.is_empty() and value != text and not _reduced():
		_punch = 1.0
	text = value
	visible = not value.is_empty()
	_place()
	queue_redraw()


## The sign's size (its paper, border included), without the cords.
func sign_size() -> Vector2:
	var font: Font = ArtStyle.bold_font(WEIGHT)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var height: float = font.get_height(FONT_SIZE)
	return (Vector2(width, height) + 2.0 * (PADDING + Vector2(BORDER, BORDER))).ceil()


## The sign's paper at rest (no swing, no punch), in global coordinates as Control's
## get_global_rect (for tests).
func sign_rect() -> Rect2:
	var hang: Vector2 = global_position
	return Rect2(hang + Vector2(0.0, CORD), sign_size())


func _process(delta: float) -> void:
	if not visible:
		return
	_place()
	if _reduced():
		rotation = 0.0
		scale = Vector2.ONE
		return
	_time += delta
	rotation = deg_to_rad(SWING_DEG) * sin(TAU * _time / SWING_SECONDS)
	_punch = maxf(0.0, _punch - delta / PUNCH_SECONDS)
	scale = Vector2.ONE * lerpf(1.0, PUNCH, _punch)


func _draw() -> void:
	if text.is_empty():
		return
	var size: Vector2 = sign_size()
	var paper: Rect2 = Rect2(Vector2(0.0, CORD), size)
	for x: float in [CORD_INSET, size.x - CORD_INSET - 2.0]:
		draw_rect(Rect2(x, -TUCK, 2.0, CORD + TUCK), Palette.INK)
	draw_rect(Rect2(paper.position + SHADOW, paper.size), Color(Palette.INK, 0.3))
	draw_rect(paper, Palette.INK)
	draw_rect(paper.grow(-BORDER), Palette.PAPER)
	var font: Font = ArtStyle.bold_font(WEIGHT)
	var baseline: Vector2 = (
		paper.position
		+ Vector2(BORDER, BORDER)
		+ PADDING
		+ Vector2(0.0, font.get_ascent(FONT_SIZE))
	)
	draw_string(
		font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.TOMATO_DARK
	)


## Hangs from the week chip's foot, INSET in from its right.
func _place() -> void:
	if _chip == null:
		return
	var right: float = _chip.position.x + _chip.size.x - INSET - sign_size().x
	position = Vector2(right, _chip.position.y + _chip.size.y).round()
	visible = visible and _chip.visible


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
