class_name SlipSign
extends Node2D
## The training week's slip counter (2026-11-01, in place of v0.68's hint in the SHIFT chip): a
## small paper sign hanging on two cords under the week chip's right end (under its day pips, clear
## of the PREMIUM NEXT tag that hangs from the gauge's end), reading the slips the training week
## has used of its limit ("SLIPS 0/2", WriteUp.hint_text's short form). It swings gently
## (SWING_DEG each way every SWING_SECONDS). A new count rolls in: the part of the text that
## changed ("0" to "1") slides up and out as the new one slides up into its place over
## ROLL_SECONDS, then the sign punches. Hidden, it falls (it drops, turns and fades over
## FALL_SECONDS: the training week is over). Reduced motion (`reduced_motion`) keeps it still: no
## swing, no roll, no punch, no fall. A Node2D, so the top bar's row never lays it out; decor
## only, it takes no clicks.

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
## A new count rolls in over ROLL_SECONDS (its old part rising ROLL_RISE of a line out), then
## punches the sign from PUNCH back to 1 over PUNCH_SECONDS.
const ROLL_SECONDS := 0.4
const ROLL_RISE := 0.8
const PUNCH := 1.3
const PUNCH_SECONDS := 0.3
## The fall: FALL_DROP px down, turning FALL_DEG, fading, over FALL_SECONDS.
const FALL_SECONDS := 0.6
const FALL_DROP := 26.0
const FALL_DEG := 28.0
const SHADOW := Vector2(2, 2)

## Returns whether to reduce motion; an empty Callable means no.
var reduced_motion: Callable = Callable()
var text: String = ""
var _chip: Control
var _time: float = 0.0
var _punch: float = 0.0
## The text it rolls from, and the roll's progress (1: done).
var _old_text: String = ""
var _roll: float = 1.0
## The fall's progress (0: not falling, up to 1: gone).
var _fall: float = 0.0


func _init() -> void:
	name = "SlipSign"
	visible = false


## Hangs under `chip` (a sibling in the top bar's row).
func follow(chip: Control) -> void:
	_chip = chip


## Shows `value`: a changed count rolls in, then punches; an empty one makes it fall.
func show_text(value: String) -> void:
	if value == text and (_fall == 0.0 or value.is_empty()):
		return
	var animate: bool = not _reduced() and is_visible_in_tree()
	if value.is_empty():
		if animate:
			_fall = maxf(_fall, 0.001)  # It falls, then hides (_process).
		else:
			_hide()
		return
	_fall = 0.0
	modulate.a = 1.0
	if animate and not text.is_empty():
		_old_text = text
		_roll = 0.0
	else:
		_roll = 1.0
	text = value
	visible = true
	_place()
	queue_redraw()


## Whether it is falling away.
func is_falling() -> bool:
	return _fall > 0.0


## Whether a new count is rolling in.
func is_rolling() -> bool:
	return _roll < 1.0


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
		if _fall > 0.0:
			_hide()
		return
	_time += delta
	rotation = deg_to_rad(SWING_DEG) * sin(TAU * _time / SWING_SECONDS)
	if _roll < 1.0:
		_roll = minf(1.0, _roll + delta / ROLL_SECONDS)
		if _roll >= 1.0:
			_punch = 1.0
		queue_redraw()
	_punch = maxf(0.0, _punch - delta / PUNCH_SECONDS)
	scale = Vector2.ONE * lerpf(1.0, PUNCH, _punch)
	if _fall > 0.0:
		_fall = minf(1.0, _fall + delta / FALL_SECONDS)
		var eased: float = _fall * _fall
		position.y += FALL_DROP * eased
		rotation += deg_to_rad(FALL_DEG) * eased
		modulate.a = 1.0 - _fall
		if _fall >= 1.0:
			_hide()


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
	if _roll >= 1.0:
		_write(font, baseline, text, Palette.TOMATO_DARK)
		return
	# The roll: the text the old and the new share stays; the part that changed slides up.
	var shared: int = mini(text.length(), _old_text.length())
	var same: int = 0
	while same < shared and text[same] == _old_text[same]:
		same += 1
	var tail: int = 0
	while (
		tail < shared - same
		and text[text.length() - 1 - tail] == _old_text[_old_text.length() - 1 - tail]
	):
		tail += 1
	var head: String = text.substr(0, same)
	var middle: String = text.substr(same, text.length() - same - tail)
	var old_middle: String = _old_text.substr(same, _old_text.length() - same - tail)
	var at: float = _width(font, head)
	var line: float = font.get_height(FONT_SIZE) * ROLL_RISE
	_write(font, baseline, head, Palette.TOMATO_DARK)
	var out: Color = Color(Palette.TOMATO_DARK, 1.0 - _roll)
	_write(font, baseline + Vector2(at, -line * _roll), old_middle, out)
	var into: Color = Color(Palette.TOMATO_DARK, _roll)
	_write(font, baseline + Vector2(at, line * (1.0 - _roll)), middle, into)
	var rest: Vector2 = baseline + Vector2(at + _width(font, middle), 0.0)
	_write(font, rest, text.substr(text.length() - tail), Palette.TOMATO_DARK)


static func _width(font: Font, words: String) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


func _write(font: Font, at: Vector2, words: String, colour: Color) -> void:
	if not words.is_empty():
		draw_string(font, at.round(), words, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


func _hide() -> void:
	text = ""
	_fall = 0.0
	_roll = 1.0
	modulate.a = 1.0
	visible = false
	queue_redraw()


## Hangs from the week chip's foot, INSET in from its right.
func _place() -> void:
	if _chip == null:
		return
	var right: float = _chip.position.x + _chip.size.x - INSET - sign_size().x
	position = Vector2(right, _chip.position.y + _chip.size.y).round()
	visible = visible and _chip.visible


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
