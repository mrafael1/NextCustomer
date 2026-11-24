class_name PuzzlePlanner
extends TextureRect
## The title's puzzle planner (#183 polish, play test 2026-11-23: the PUZZLES plate became a
## thing in the scene): a paper planner taped inside the storefront's right window, under its
## tube (art/scenery/puzzle_planner.png, 40x48 art at 2x: PUZZLES on a tomato header over eight
## puzzle cards). The storefront shows it once the title offers puzzles (the profile has
## finished a run) and places it at `home` (canvas px on the stage).
##
## At night it wears HAZE; `hot` (PUZZLES under the mouse or the keys' marker) lifts it LIFT art
## px off the glass in its full colours and jiggles it once (one art px either way, as the bay's
## machine); press() dips it PRESS art px onto the glass for PRESS_TIME. `still` (reduced
## motion) keeps the lift and the colours, never the jiggle or the dip. Display only: the title
## routes the clicks (Storefront.planner_rect).

const ART := preload("res://art/scenery/puzzle_planner.png")
const HAZE := Color(0.84, 0.86, 0.86)
const LIFT := 1
const PRESS := 1
const PRESS_TIME := 0.12
## The jiggle (the bay machine's: Storefront.JIGGLE_STEP and JIGGLE_TIME).
const JIGGLE_STEP := 0.06
const JIGGLE_TIME := 0.3

## Its resting top left on the stage (canvas px).
var home: Vector2 = Vector2.ZERO:
	set(value):
		home = value
		_place()
var still: bool = false
## PUZZLES is marked: lifted, lit, one jiggle.
var hot: bool = false:
	set(value):
		if value and not hot and not still:
			_jiggle_at = _clock
		hot = value
		modulate = Color.WHITE if value else HAZE
		_place()

var _clock: float = 0.0
var _jiggle_at: float = -1.0
var _press_at: float = -1.0


func _init() -> void:
	name = "PuzzlePlanner"
	texture = ART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(self)
	size = ART.get_size() * ArtStyle.ART_SCALE
	modulate = HAZE
	visible = false


## A press (a click on it, or PUZZLES from the keys): it dips onto the glass for a moment.
func press() -> void:
	if not still:
		_press_at = _clock
	_place()


## Its offset from home now (art px): lifted while hot, jiggling after it turned hot, dipped just
## after a press.
func offset() -> Vector2i:
	var shift: Vector2i = Vector2i(0, -LIFT if hot else 0)
	if still:
		return shift
	var since_jiggle: float = _clock - _jiggle_at
	if _jiggle_at >= 0.0 and since_jiggle < JIGGLE_TIME:
		shift.x = 1 if int(since_jiggle / JIGGLE_STEP) % 2 else -1
	if _press_at >= 0.0 and _clock - _press_at < PRESS_TIME:
		shift.y = PRESS
	return shift


func _process(delta: float) -> void:
	_clock += delta
	_place()


func _place() -> void:
	position = home + Vector2(offset()) * ArtStyle.ART_SCALE
