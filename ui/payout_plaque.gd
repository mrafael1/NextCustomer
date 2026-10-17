class_name PayoutPlaque
extends Label
## A belt item's paid chip (#80, step 7; mock-up B2's count-up; it was #55's brass "pays €N"
## plaque): "€N" over the item's art, shown only in the count-up (and on a run resumed after its
## checkout), never in planning. Two faces: the current item's, big mustard with an inset lit top,
## a dark foot and a 4 px hard shadow, and an earlier item's, small paper in an ink edge with a
## 2 px shadow; earlier chips stay. A current chip that pops in shows one mustard echo frame
## ECHO_GAP outside it (shadow included) that fades over ECHO_TIME (none under reduced motion). A
## value of €0, or one a denied beat wiped, shows the muted face (cream shade, grey-dark edge and
## text) at either size. The chip is the item's badge: the count-up punches it, so it stays a
## Label (in the number font, B2's Atkinson, sharp at any punch), and the face is a child drawn
## behind its text. The value comes from the caller (the ScoreResult); the chip never scores.

const SYMBOL := "€"
const CURRENT_FONT_SIZE := 24
const SETTLED_FONT_SIZE := 16
## The faces' heights and the room between their sides and the text, edge included.
const CURRENT_HEIGHT := 34.0
const SETTLED_HEIGHT := 24.0
const CURRENT_PADDING := 12.0
const SETTLED_PADDING := 8.0
const CURRENT_MIN_WIDTH := 52.0
const SETTLED_MIN_WIDTH := 36.0
## The ink edge, the current face's lit top and dark foot, in canvas pixels.
const EDGE := 2.0
const BAND := 2.0
## The hard shadows, down and right.
const CURRENT_SHADOW := 4.0
const SETTLED_SHADOW := 2.0
const CURRENT_SHADOW_ALPHA := 0.45
const SETTLED_SHADOW_ALPHA := 0.4
## The pop's echo: a frame ECHO_WIDTH wide, ECHO_GAP outside the chip and its shadow.
const ECHO_GAP := 4.0
const ECHO_WIDTH := 2.0
const ECHO_TIME := 0.18

## Where the chip goes, in its parent's coordinates: centred on `centre_x`, its face and shadow
## kept between `left_limit` and `right_limit` (the left one wins).
var centre_x: float = 0.0
var left_limit: float = -INF
var right_limit: float = INF
var _face: Control
var _echo: Control
var _current: bool = true
var _muted: bool = false
var _echo_next: bool = false
## The running echo's fade, killed when a new echo starts.
var _echo_fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_override("font", ArtStyle.number_font())
	add_theme_constant_override("outline_size", 0)
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.show_behind_parent = true
	_face.draw.connect(_draw_face)
	add_child(_face)
	_echo = Control.new()
	_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo.show_behind_parent = true
	_echo.visible = false
	_echo.draw.connect(_draw_echo)
	add_child(_echo)
	show_value(0, false)
	visible = false


## Shows "€`value`" on the current or the settled face, muted when `muted` (€0, or a value a
## denied beat wiped). Its y is left alone: the count-up's scan may be lifting it. A current chip
## that pops in (set_current's `with_echo`) shows its echo.
func show_value(value: int, muted: bool) -> void:
	text = text_for(value)
	visible = true
	_muted = muted
	_lay_out()
	if _echo_next and _current:
		_echo_next = false
		_play_echo()


## Makes the chip the current item's (big mustard) or an earlier one's (small paper), in place.
## `with_echo`: the next show_value of the current chip pops with its echo frame.
func set_current(current: bool, with_echo: bool = false) -> void:
	_current = current
	_echo_next = current and with_echo
	if not current:
		_echo.visible = false
	_lay_out()


func is_current() -> bool:
	return _current


func is_muted() -> bool:
	return _muted


## The visible face behind the text, its shadow not included (for tests and layout checks).
func face() -> Control:
	return _face


## The pop's echo frame (for tests).
func echo_frame() -> Control:
	return _echo


## The face's shadow depth, down and right.
func shadow() -> float:
	return CURRENT_SHADOW if _current else SETTLED_SHADOW


## The chip's text for a value.
static func text_for(value: int) -> String:
	return "%s%d" % [SYMBOL, value]


## The face's height, current or settled.
static func height_for(current: bool) -> float:
	return CURRENT_HEIGHT if current else SETTLED_HEIGHT


## Sizes the chip for its text and face and places it between its limits.
func _lay_out() -> void:
	add_theme_font_size_override("font_size", CURRENT_FONT_SIZE if _current else SETTLED_FONT_SIZE)
	var ink: Color = Palette.GREY_DARK if _muted else Palette.INK
	add_theme_color_override("font_color", ink)
	var padding: float = CURRENT_PADDING if _current else SETTLED_PADDING
	var least: float = CURRENT_MIN_WIDTH if _current else SETTLED_MIN_WIDTH
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width: float = snappedf(maxf(least, text_width + 2.0 * padding), ArtStyle.ART_SCALE)
	var chip: Vector2 = Vector2(width, height_for(_current))
	size = chip
	var x: float = minf(centre_x - width / 2.0, right_limit - width - shadow())
	position.x = snappedf(maxf(x, left_limit), ArtStyle.ART_SCALE)
	pivot_offset = chip / 2.0
	_face.position = Vector2.ZERO
	_face.size = chip
	var outside: float = ECHO_GAP + ECHO_WIDTH
	_echo.position = Vector2(-outside, -outside)
	_echo.size = chip + Vector2.ONE * (shadow() + 2.0 * outside)
	_face.queue_redraw()
	_echo.queue_redraw()


func _play_echo() -> void:
	if _echo_fade != null:
		_echo_fade.kill()
	_echo.visible = true
	_echo.modulate.a = 1.0
	_echo_fade = _echo.create_tween()
	_echo_fade.tween_property(_echo, "modulate:a", 0.0, ECHO_TIME)
	_echo_fade.tween_callback(_echo.hide)


## The face: its hard shadow, the edge, the fill and (current, not muted) the lit top and dark
## foot (brass, B2's #c39228 snapped as the monitor's gain chip snaps it).
func _draw_face() -> void:
	var chip: Rect2 = Rect2(Vector2.ZERO, _face.size)
	var depth: float = shadow()
	var alpha: float = CURRENT_SHADOW_ALPHA if _current else SETTLED_SHADOW_ALPHA
	_face.draw_rect(
		Rect2(chip.position + Vector2(depth, depth), chip.size), Color(Palette.INK, alpha)
	)
	var fill: Color = Palette.MUSTARD if _current else Palette.PAPER
	var edge: Color = Palette.INK
	if _muted:
		fill = Palette.CREAM_SHADE
		edge = Palette.GREY_DARK
	_face.draw_rect(chip, edge)
	var inside: Rect2 = chip.grow(-EDGE)
	_face.draw_rect(inside, fill)
	if _current and not _muted:
		_face.draw_rect(Rect2(inside.position, Vector2(inside.size.x, BAND)), Palette.MUSTARD_LIGHT)
		var foot: Vector2 = Vector2(inside.position.x, inside.end.y - BAND)
		_face.draw_rect(Rect2(foot, Vector2(inside.size.x, BAND)), Palette.BRASS)


## The echo: a mustard frame ECHO_WIDTH wide around the chip and its shadow.
func _draw_echo() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, _echo.size)
	var band: float = ECHO_WIDTH
	var colour: Color = Palette.MUSTARD
	_echo.draw_rect(Rect2(frame.position, Vector2(frame.size.x, band)), colour)
	_echo.draw_rect(Rect2(0, frame.end.y - band, frame.size.x, band), colour)
	_echo.draw_rect(Rect2(0, band, band, frame.size.y - 2.0 * band), colour)
	_echo.draw_rect(Rect2(frame.end.x - band, band, band, frame.size.y - 2.0 * band), colour)
