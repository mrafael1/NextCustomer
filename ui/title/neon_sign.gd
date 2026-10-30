class_name NeonSign
extends Control
## The storefront's neon sign (#56, mock-up title_premium_directions.html, direction C+): NEXT
## small in teal tubes over CUSTOMER large in tomato ones, the O a capsule-coloured price tag,
## all traced from Pixelify Sans onto the art grid (art/scenery/neon_sign_on.png, _off, and the
## baked dither halo neon_sign_halo, _halo_soft), and a small € tag hanging right of it.
##
## It is dark until light_up(), then lights letter by letter (LETTER_STEP apart; `still` lights
## it at once) and says lit_up. Lit, it lives: the halo breathes (the full halo, then the soft
## one, for SOFT_SHARE of each BREATH), the X stutters (off, on, off) every STUTTER_GAP seconds
## and the € tag swings one px either way, a step every SWING_STEP seconds. scan() is the
## hidden toy (a click on the sign): a scan line sweeps across it, then it blinks once. `still`
## (the profile's reduced motion) holds every loop: no breath, stutter, swing or sweep, but the
## blink. Drawn on the 2 px grid (ArtStyle.ART_SCALE), it takes no clicks.

## Every letter is lit (light_up() is done).
signal lit_up

const ON := preload("res://art/scenery/neon_sign_on.png")
const OFF := preload("res://art/scenery/neon_sign_off.png")
const HALO := preload("res://art/scenery/neon_sign_halo.png")
const HALO_SOFT := preload("res://art/scenery/neon_sign_halo_soft.png")
## The sprites' size and each letter's box in them (N E X T, then C U S T, the tag O, M E R), in
## art px: they light in this order.
const ART_SIZE := Vector2i(163, 48)
const LETTERS: Array[Rect2i] = [
	Rect2i(55, 4, 10, 14),
	Rect2i(69, 4, 10, 14),
	Rect2i(83, 4, 10, 14),
	Rect2i(97, 4, 10, 14),
	Rect2i(4, 23, 15, 21),
	Rect2i(22, 23, 15, 21),
	Rect2i(40, 23, 15, 21),
	Rect2i(58, 23, 15, 21),
	Rect2i(77, 23, 21, 21),
	Rect2i(102, 23, 21, 21),
	Rect2i(126, 23, 15, 21),
	Rect2i(144, 23, 15, 21),
]
## The letter that stutters (the X) and where the two lines' halos meet, in art px.
const STUTTER_LETTER := 2
const LINE_SPLIT := 20
## The sign with its € tag, in art px: the tag (TAG_SIZE) hangs on a TAG_STRING px string whose
## top is at TAG_HOOK, TAG_LEFT px in from the tag's left edge.
const SIZE_ART := Vector2i(182, 48)
const TAG_HOOK := Vector2i(173, 14)
const TAG_LEFT := 5
const TAG_STRING := 8
const TAG_SIZE := Vector2i(12, 9)
const LETTER_STEP := 0.05
const BREATH := 3.0
const SOFT_SHARE := 0.4
## The X's stutter: STUTTER_FLASH seconds off, on, then off again, every STUTTER_GAP (min, max)
## seconds.
const STUTTER_GAP := Vector2(9.0, 15.0)
const STUTTER_FLASH := 0.1
const SWING_STEP := 2.0
const SWING: Array[int] = [0, 1, 0, -1]
## The scan: a line SCAN_TIME seconds across, in 2 px steps, with a checker band SCAN_HALF px
## wide round it, SCAN_PAD px past the sign's ends; then the sign blinks off for BLINK seconds.
const SCAN_TIME := 0.6
const SCAN_HALF := 3
const SCAN_PAD := 10
const BLINK := 0.16

## Holds every loop and lights at once (the profile's reduced motion).
var still: bool = false:
	set(value):
		still = value
		queue_redraw()

## Letters lit so far (0 dark, LETTERS.size() all lit).
var _lit: int = 0
var _lighting: bool = false
var _light_clock: float = 0.0
## The loops' clock, the next stutter's start on it, and the scan's start (negative: none).
var _clock: float = 0.0
var _stutter_at: float = 0.0
var _scan_at: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(SIZE_ART) * ArtStyle.ART_SCALE
	custom_minimum_size = size
	_stutter_at = _rng.randf_range(STUTTER_GAP.x, STUTTER_GAP.y)


## Lights the sign letter by letter (at once when `still`); lit_up follows.
func light_up() -> void:
	if _lit >= LETTERS.size() or _lighting:
		return
	if still:
		_lit = LETTERS.size()
		queue_redraw()
		lit_up.emit()
		return
	_lighting = true
	_light_clock = 0.0


## Lights every letter at once (a click or key during the title's intro); lit_up follows unless
## the sign was already lit.
func light_now() -> void:
	if is_lit():
		return
	_lighting = false
	_lit = LETTERS.size()
	queue_redraw()
	lit_up.emit()


## Every letter is lit.
func is_lit() -> bool:
	return _lit >= LETTERS.size()


## How many letters are lit.
func lit_letters() -> int:
	return _lit


## The hidden toy: a scan line sweeps across the sign, then it blinks once (only the blink when
## `still`).
func scan() -> void:
	_scan_at = _clock - (SCAN_TIME if still else 0.0)
	queue_redraw()


## The X is dark for a stutter now.
func is_stuttering() -> bool:
	if still or not is_lit():
		return false
	var since: float = _clock - _stutter_at
	return since >= 0.0 and since < 3.0 * STUTTER_FLASH and int(since / STUTTER_FLASH) != 1


## The € tag's swing now, in art px.
func swing() -> int:
	if still:
		return 0
	return SWING[int(_clock / SWING_STEP) % SWING.size()]


## The halo shows its soft step now.
func halo_is_soft() -> bool:
	return not still and fmod(_clock, BREATH) >= BREATH * (1.0 - SOFT_SHARE)


## The sign is blinked off after a scan.
func is_blinking() -> bool:
	var since: float = _clock - _scan_at
	return _scan_at >= 0.0 and since >= SCAN_TIME and since < SCAN_TIME + BLINK


func _process(delta: float) -> void:
	_clock += delta
	if _lighting:
		_light_clock += delta
		var count: int = mini(int(_light_clock / LETTER_STEP) + 1, LETTERS.size())
		if count != _lit:
			_lit = count
		if _lit >= LETTERS.size():
			_lighting = false
			lit_up.emit()
	if _clock >= _stutter_at + 3.0 * STUTTER_FLASH:
		_stutter_at = _clock + _rng.randf_range(STUTTER_GAP.x, STUTTER_GAP.y)
	if _scan_at >= 0.0 and _clock - _scan_at > SCAN_TIME + BLINK:
		_scan_at = -1.0
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ArtStyle.ART_SCALE)
	var blinking: bool = is_blinking()
	var halo: Texture2D = HALO_SOFT if halo_is_soft() else HALO
	for i: int in LETTERS.size():
		var region: Rect2 = Rect2(_region(i))
		var lit: bool = i < _lit and not blinking
		if i == STUTTER_LETTER and is_stuttering():
			lit = false
		if lit:
			draw_texture_rect_region(halo, region, region)
		draw_texture_rect_region(ON if lit else OFF, region, region)
	_draw_tag(is_lit() and not blinking)
	var since: float = _clock - _scan_at
	if _scan_at >= 0.0 and since < SCAN_TIME and not still:
		var travel: float = SIZE_ART.x + SCAN_PAD * 2
		var line_x: int = -SCAN_PAD + int(since / SCAN_TIME * travel / 2.0) * 2
		for y: int in range(-2, SIZE_ART.y + 2):
			for x: int in range(line_x - SCAN_HALF, line_x + SCAN_HALF + 1):
				if posmod(x + y, 2) == 0:
					draw_rect(Rect2(x, y, 1, 1), Palette.TOMATO)
		draw_rect(Rect2(line_x, -2, 1, SIZE_ART.y + 4), Palette.TOMATO)


## A letter's share of the sprites: its column between the midpoints of the gaps to its
## neighbours on its line, and its line's band.
func _region(index: int) -> Rect2i:
	var box: Rect2i = LETTERS[index]
	var top_line: bool = box.position.y < LINE_SPLIT
	var left: int = 0
	var right: int = ART_SIZE.x
	if index > 0 and _same_line(index - 1, top_line):
		left = floori((LETTERS[index - 1].end.x + box.position.x) / 2.0)
	if index + 1 < LETTERS.size() and _same_line(index + 1, top_line):
		right = floori((box.end.x + LETTERS[index + 1].position.x) / 2.0)
	var top: int = 0 if top_line else LINE_SPLIT
	var bottom: int = LINE_SPLIT if top_line else ART_SIZE.y
	return Rect2i(left, top, right - left, bottom - top)


func _same_line(index: int, top_line: bool) -> bool:
	return (LETTERS[index].position.y < LINE_SPLIT) == top_line


## The € tag on its string, swung `swing()` px at its foot: mustard light when the sign is lit.
func _draw_tag(lit: bool) -> void:
	var sway: int = swing()
	for i: int in TAG_STRING:
		draw_rect(
			Rect2(TAG_HOOK.x + roundi(float(sway * i) / TAG_STRING), TAG_HOOK.y + i, 1, 1),
			Palette.GREY_LIGHT
		)
	var tag := Vector2i(TAG_HOOK.x - TAG_LEFT + sway, TAG_HOOK.y + TAG_STRING)
	draw_rect(Rect2(Rect2i(tag, TAG_SIZE)), Palette.INK)
	var face := Rect2i(tag + Vector2i(1, 1), TAG_SIZE - Vector2i(2, 2))
	draw_rect(Rect2(face), Palette.MUSTARD_LIGHT if lit else Palette.MUSTARD_DARK)
	var bits: String = StorefrontArt.TILL["€"]
	for i: int in 15:
		if bits[i] == "1":
			draw_rect(Rect2(tag.x + 4 + i % 3, tag.y + 2 + floori(i / 3.0), 1, 1), Palette.INK)
