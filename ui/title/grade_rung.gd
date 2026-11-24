class_name GradeRung
extends Control
## One rung of the grade card's ladder (#182, GradeCard; polished after the user's play test of
## 2026-11-23: "picking a number should light precedent box"): the 28x28 art plate
## (frames/grade_rung*: brass when beaten, teal when open, slate when locked) with the grade's
## number in the machine's chunky digits (PixelWords CHUNKY, an ink shadow under them) centred
## on it, and a beaten rung's tick or a locked one's padlock hung on its bottom right corner,
## clear of the number (the user's 2026-11-23 polish), drawn at 2x. A LIT rung (the picked
## grade and every grade under it: their rules stack) wears the gold ring
## (frames/grade_rung_marked) and full colour; an unlit one is dimmed. The picked rung stands
## PICK_LIFT px up; the mouse over a rung lifts it HOVER_LIFT px; a press sinks it. pop()
## bounces its face up and back in whole art px (the ladder lighting up rung by rung). Its
## clicks go to the card (gui_input); the cursor is the pointing hand.

const RUNG := preload("res://art/frames/grade_rung.png")
const RUNG_BEATEN := preload("res://art/frames/grade_rung_beaten.png")
const RUNG_LOCKED := preload("res://art/frames/grade_rung_locked.png")
const RING := preload("res://art/frames/grade_rung_marked.png")
const TICK := preload("res://art/frames/grade_rung_tick.png")
const PADLOCK := preload("res://art/frames/grade_rung_padlock.png")
## The rung's size and the ring's reach round it, canvas px.
const SIZE := Vector2(56, 56)
const RING_OUT := 4.0
## The number: chunky digits, a CELL px font pixel, its ink shadow one font pixel down and right.
const CELL := 4.0
## The tick's or padlock's top left on the plate, canvas px: one art px clear of the widest
## number's shadow, hanging two art px over the plate's edge.
const MARK_AT := Vector2(44, 44)
## An unlit rung's colour: the ladder above the pick stays dim.
const DIM := Color(0.62, 0.62, 0.66)
## How far the picked rung stands up, the mouse lifts a rung and a press sinks it, canvas px.
const PICK_LIFT := 4.0
const HOVER_LIFT := 2.0
const PRESS_SINK := 2.0
## pop(): the face's rise in art px, one step every POP_STEP s.
const POP_STEPS: Array[int] = [3, 4, 2, 0]
const POP_STEP := 0.04

## The grade on the rung.
var grade: int = 0
var beaten: bool = false
var locked: bool = false

var _face: Control
var _ring: TextureRect
var _number: PixelWords
var _mark: TextureRect
var _lit: bool = false
var _picked: bool = false
var _hover: bool = false
var _pressed: bool = false
var _pop_rise: int = 0
var _popping: Tween


func _init(rung_grade: int, is_beaten: bool, is_locked: bool) -> void:
	grade = rung_grade
	beaten = is_beaten
	locked = is_locked
	name = "Rung%d" % rung_grade
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = SIZE
	add_child(_face)
	_ring = UiKit.sprite(RING)
	_ring.size = SIZE + Vector2.ONE * RING_OUT * 2.0
	_ring.position = -Vector2.ONE * RING_OUT
	_ring.visible = false
	_face.add_child(_ring)
	var art: TextureRect = UiKit.sprite(
		RUNG_LOCKED if locked else (RUNG_BEATEN if beaten else RUNG)
	)
	art.size = SIZE
	_face.add_child(art)
	var digits: String = str(rung_grade)
	_number = PixelWords.new(
		digits, PixelWords.Sheet.CHUNKY, CELL, Palette.GREY_LIGHT if locked else Palette.PAPER
	)
	_number.shadow = Palette.SLATE_DARK if locked else Palette.INK
	var shown: Vector2 = PixelWords.text_size(digits, PixelWords.Sheet.CHUNKY, CELL)
	_number.size = shown
	# The digits and their shadow centred on the plate (every digit's lands on the art grid).
	_number.position = GradeCard.centred_on_grid(
		Rect2(Vector2.ZERO, shown + Vector2.ONE * CELL), SIZE
	)
	_face.add_child(_number)
	if locked or beaten:
		_mark = UiKit.sprite(PADLOCK if locked else TICK)
		_mark.size = _mark.texture.get_size() * ArtStyle.ART_SCALE
		_mark.position = MARK_AT
		_face.add_child(_mark)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_show()


## Lights the rung (`lit`: the picked grade or one under it) and stands it up when `picked`.
func set_state(lit: bool, picked: bool) -> void:
	_lit = lit
	_picked = picked
	_show()


func is_lit() -> bool:
	return _lit


func is_picked() -> bool:
	return _picked


## The gold ring (tests read whether it shows and where).
func ring() -> TextureRect:
	return _ring


## The number (tests read where its ink sits).
func number() -> PixelWords:
	return _number


## The number's drawn ink, its shadow with it, in the face's px.
func number_rect() -> Rect2:
	return Rect2(_number.position, _number.size + Vector2.ONE * CELL)


## The tick or padlock on the corner (null on an open rung).
func mark() -> TextureRect:
	return _mark


## The face: the plate, its ring and its number, moved by the lifts (tests read its place).
func face() -> Control:
	return _face


## Bounces the face up and back over POP_STEPS (the ladder lighting up); `delay` s first.
## `still` (reduced motion): nothing moves.
func pop(delay: float, still: bool) -> void:
	if _popping != null:
		_popping.kill()
		_popping = null
	_pop_rise = 0
	_show()
	if still:
		return
	_popping = create_tween()
	if delay > 0.0:
		_popping.tween_interval(delay)
	for rise: int in POP_STEPS:
		_popping.tween_callback(_set_pop.bind(rise))
		_popping.tween_interval(POP_STEP)


## A press sinks the rung until the button is let go (the card picks on the press).
func set_pressed(on: bool) -> void:
	_pressed = on
	_show()


func _set_pop(rise: int) -> void:
	_pop_rise = rise
	_show()


func _set_hover(on: bool) -> void:
	_hover = on
	if not on:
		_pressed = false
	_show()


func _show() -> void:
	_ring.visible = _lit
	_face.modulate = Color.WHITE if _lit or _hover else DIM
	var lift: float = PICK_LIFT if _picked else (HOVER_LIFT if _hover else 0.0)
	if _pressed:
		lift = -PRESS_SINK
	_face.position.y = -lift - _pop_rise * ArtStyle.ART_SCALE
