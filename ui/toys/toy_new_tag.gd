class_name ToyNewTag
extends Control
## The FIGURINE BOOK button's NEW tag (v1.26, the user: "when a new item is unlocked, show a new
## tag on figurine shelf button"): a tomato price tag (icons/new_tag.png at 2x, pointed left with
## its string hole) with NEW in paper hard pixel words, hung over the button's top right corner.
## It shows while the profile has figurines not yet seen in the book (ProfileState.
## new_figurines); the screen turns it on once the drawn figurine has joined its lineup card and
## off when the book opens. Turned on with motion, it drops in DROP_ART art px over DROP_S,
## eased, in whole art px (the reveal's drop); then, so it is not missed, it swings on its string
## every SWING_EVERY_S (review fix: it went still), one art px each way over SWING_S. Under
## reduced motion it is simply there and still. It takes no clicks. Sizes in canvas px.

const ART := preload("res://art/icons/new_tag.png")
const TEXT := "NEW"
## The tag's body (right of its point and hole), in art px: the word is centred across it.
const BODY_LEFT := 7
const BODY_RIGHT := 28
## Where the tag hangs on the button (its top left, canvas px from the button's): over the
## plate's top right corner, sticking out above it and past its right edge.
const ON_BUTTON := Vector2(192, -14)
const DROP_ART := 4
const DROP_S := 0.15
const SWING_EVERY_S := 2.0
const SWING_S := 0.4
## The swing's steps (art px right of rest), SWING_S over them.
const SWING_STEPS: Array[int] = [1, 0, -1, 0]

var _sprite: TextureRect
var _word: PixelLine
## Seconds since it was turned on with motion; -1 at rest.
var _dropping: float = -1.0
## Seconds since it last swung (it swings again at SWING_EVERY_S); reduced motion: still.
var _idle: float = 0.0
var _still: bool = true


func _init() -> void:
	name = "NewTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var art: float = ArtStyle.ART_SCALE
	size = Vector2(ART.get_size()) * art
	_sprite = UiKit.sprite(ART)
	_sprite.size = size
	add_child(_sprite)
	_word = PixelLine.new()
	_word.show_tokens([TEXT], Palette.PAPER, Palette.PAPER)
	var body_centre: float = (BODY_LEFT + BODY_RIGHT + 1) / 2.0
	var cap_top: int = floori((ART.get_height() - ArtStyle.PIXEL_CAP_HEIGHT) / 2.0)
	_word.position = Vector2(roundf(body_centre - _word.width() / art / 2.0) * art, cap_top * art)
	_sprite.add_child(_word)


## Shows (with a drop in, unless `still`) or hides the tag.
func set_shown(on: bool, still: bool) -> void:
	if on == visible:
		return
	visible = on
	_still = still
	_idle = 0.0
	_dropping = 0.0 if on and not still else -1.0
	_place()


## The word on the tag, for tests.
func word() -> PixelLine:
	return _word


## The swing's offset now (art px right of rest), for tests.
func swing() -> int:
	return roundi(_sprite.position.x / ArtStyle.ART_SCALE)


## Advances its motion `seconds` (the swing's clock too), for tests and the screen capture.
func advance(seconds: float) -> void:
	_process(seconds)


func _process(delta: float) -> void:
	if not visible or _still:
		return
	if _dropping >= 0.0:
		_dropping += delta
		if _dropping >= DROP_S:
			_dropping = -1.0
	else:
		_idle = fmod(_idle + delta, SWING_EVERY_S)
	_place()


func _place() -> void:
	var rise: int = 0
	var sway: int = 0
	if _dropping >= 0.0:
		var p: float = clampf(_dropping / DROP_S, 0.0, 1.0)
		rise = roundi(DROP_ART * pow(1.0 - p, 3.0))
	elif not _still and _idle >= SWING_EVERY_S - SWING_S:
		var step: float = (_idle - (SWING_EVERY_S - SWING_S)) / SWING_S * SWING_STEPS.size()
		sway = SWING_STEPS[clampi(floori(step), 0, SWING_STEPS.size() - 1)]
	_sprite.position = Vector2(sway, -rise) * ArtStyle.ART_SCALE
