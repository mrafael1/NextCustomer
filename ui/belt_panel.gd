class_name BeltPanel
extends Control
## The shift screen's conveyor belt (#55, from style frame v2's belt): grey rubber with
## horizontal treads between a brass top and bottom rail, and a brass roller at each end with
## its turned rings. Its size is fixed (ShiftStage.BELT_RECT); the row of slots stands on it as
## its child. The treads and the rings are code-drawn, so their rhythm holds at any belt size (a
## stretched 9-slice middle turns them into bars). Decor only: it takes no clicks.

## The frame's rollers (left and right) and rails (top and bottom), in art pixels.
const MARGIN_H := 8
const MARGIN_V := 4
## The rubber's treads, from the rubber's top: a groove, then a lit lip under it (the first lip
## is the sheen, the light coming from the top).
const TREAD_FIRST := 4.0
const TREAD_EVERY := 12.0
const TREAD_GROOVE := 2.0
const TREAD_LIP := 2.0
## The end rollers' turned rings: a brass-darkest groove every 8 art rows across each roller,
## ROLLER_INSET in from the belt's ends.
const ROLLER_INSET := 2.0
const ROLLER_WIDTH := 12.0
const RING_FIRST := 6.0
const RING_EVERY := 16.0
const RING_HEIGHT := 2.0
const GROOVE_COLOR := Palette.INK_LIGHT
const SHEEN_COLOR := Palette.GREY_LIGHT
const LIP_COLOR := Palette.GREY
const RING_COLOR := Palette.BRASS_DARKEST

const FRAME := preload("res://art/frames/belt_v3.png")

var _frame_style: StyleBoxTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_frame_style = ArtStyle.frame_style(FRAME, MARGIN_V)
	_frame_style.texture_margin_left = MARGIN_H * ArtStyle.ART_SCALE
	_frame_style.texture_margin_right = MARGIN_H * ArtStyle.ART_SCALE


func _draw() -> void:
	draw_style_box(_frame_style, Rect2(Vector2.ZERO, size))
	var treads: Array[Rect2] = tread_rects()
	for tread: int in range(treads.size()):
		var groove: Rect2 = treads[tread]
		groove.size.y = TREAD_GROOVE
		draw_rect(groove, GROOVE_COLOR)
		var lip: Rect2 = Rect2(
			groove.position + Vector2(0, TREAD_GROOVE), Vector2(groove.size.x, TREAD_LIP)
		)
		draw_rect(lip, SHEEN_COLOR if tread == 0 else LIP_COLOR)
	for ring: Rect2 in ring_rects():
		draw_rect(ring, RING_COLOR)


## The belt frame's 9-slice: its rails' and rollers' margins around the plain rubber middle.
func frame_style() -> StyleBoxTexture:
	return _frame_style


## The rubber between the rails and the rollers, in the belt's coordinates.
func interior() -> Rect2:
	var margin: Vector2 = Vector2(MARGIN_H, MARGIN_V) * ArtStyle.ART_SCALE
	return Rect2(margin, size - 2.0 * margin)


## The rubber's treads (each a groove and its lip), in the belt's coordinates: every TREAD_EVERY
## down the rubber, each one inside it.
func tread_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var rubber: Rect2 = interior()
	var y: float = rubber.position.y + TREAD_FIRST
	while y + TREAD_GROOVE + TREAD_LIP <= rubber.end.y:
		rects.append(Rect2(rubber.position.x, y, rubber.size.x, TREAD_GROOVE + TREAD_LIP))
		y += TREAD_EVERY
	return rects


## The end rollers' rings, in the belt's coordinates: every RING_EVERY down each roller, inside
## the rubber's height.
func ring_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var rubber: Rect2 = interior()
	var xs: Array[float] = [ROLLER_INSET, size.x - ROLLER_INSET - ROLLER_WIDTH]
	var y: float = rubber.position.y + RING_FIRST
	while y + RING_HEIGHT <= rubber.end.y:
		for x: float in xs:
			rects.append(Rect2(x, y, ROLLER_WIDTH, RING_HEIGHT))
		y += RING_EVERY
	return rects
