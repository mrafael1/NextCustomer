class_name BayTag
extends Control
## The scanner bay's price tag (#86 round 7, mock-up count_up_86_v7_bay.html's TALLY): a swing tag
## hung off the bay's top right, toward the number (POSITION), on a short ink string. It shows the
## item's worth: what the beat's step says the item is worth after it (ScoreStep.value_after; the
## bay hands it over, the tag does no sums), on paper until the item pays, then gold. Each change
## counts over COUNT_S from the shown value, popping (POP, about the string's hole) and swinging
## (SWING_DEG, fading over SWING_S). It grows to the right with its text on the 2 px grid
## (width_for), so its string never moves, and leaves with the item (follow_out).
##
## Drawn in code at ArtStyle.ART_SCALE: a ROWS art px high tag with a chamfered left end, an
## ink edge, a light top-left rim and a shaded bottom-right one, the string's hole and a
## SHADOW_ALPHA ink shadow one art px down and right. Its count, pop and swing run on
## make_tween's tweens (the count-up's); under reduced motion (`reduced_motion`) every change shows
## at once. Display only.

## The tag's place at rest (stage coordinates) and height (its shadow's row included).
const POSITION := Vector2(565, 102)
const HEIGHT := 24.0
const ROWS := 11
## The width: at least MIN_WIDTH, else the text's with TEXT_LEFT before it and TEXT_RIGHT after,
## rounded up to the 2 px grid. The text is centred from TEXT_LEFT to LABEL_RIGHT px off the
## right end, TEXT_HEIGHT high.
const MIN_WIDTH := 52.0
const TEXT_LEFT := 15.0
const TEXT_RIGHT := 7.0
const LABEL_RIGHT := 5.0
const TEXT_HEIGHT := 22.0
const FONT_SIZE := 17
const WEIGHT := 800
## The pop and the swing turn about the string's hole; the string hangs at STRING_RECT; the hole
## is HOLE (art px).
const PIVOT := Vector2(10, 10)
const STRING_RECT := Rect2(9, -6, 2, 10)
const HOLE := Rect2i(4, 4, 2, 2)
const SHADOW_ALPHA := 0.38
## A chip leaves from SEND_INSET px left of the right end and down from the top.
const SEND_INSET := Vector2(6, 9)
const COUNT_S := 0.14
const POP := 0.3
const POP_S := 0.25
const SWING_DEG := 14.0
const SWING_RATE := 13.0
const SWING_S := 0.9
## The face's light rim, body and shade, paid and unpaid (the mock-up's #fffdf6 rim is off the
## palette: paper).
const PAID_COLOURS: Array[Color] = [Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD]
const UNPAID_COLOURS: Array[Color] = [Palette.PAPER, Palette.PAPER, Palette.CREAM_SHADE]
const INK_COLOR := Palette.INK
const PAID_TEXT_COLOR := Palette.INK
const UNPAID_TEXT_COLOR := Palette.INK_LIGHT

## Returns a new tween on the count-up's clock; none means the tag's own.
var make_tween: Callable = Callable()
## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _label: Label
var _value: int = 0
var _paid: bool = false
## pay() ran for this item: a count still waiting to start keeps the gold (only a DENIED count,
## which asks for paper, or a new value takes it away).
var _paid_by_rise: bool = false
## The count under way: from, to.
var _from: int = 0
var _to: int = 0
## The pop's and the swing's time (negative: none), the slide-out's pose and the place at rest.
var _pop_t: float = -1.0
var _swing_t: float = -1.0
var _out: BayBed.BayPose = BayBed.BayPose.new()
var _rest: Vector2 = Vector2.ZERO
var _count: Tween
var _pop: Tween


func _init() -> void:
	name = "BayTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = PIVOT
	_label = Label.new()
	_label.name = "Value"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", ArtStyle.bold_font(WEIGHT))
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_constant_override("outline_size", 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = false
	add_child(_label)
	visible = false
	_show_text()


func _draw() -> void:
	var colours: Array[Color] = face_colours()
	var across: int = roundi(size.x / ArtStyle.ART_SCALE)
	var shadow: Color = Color(INK_COLOR, SHADOW_ALPHA)
	for row: int in range(ROWS + 1):
		for column: int in range(across + 1):
			if not _in(column, row, across):
				if _in(column - 1, row - 1, across):
					_cell(Rect2i(column, row, 1, 1), shadow)
				continue
			_cell(Rect2i(column, row, 1, 1), _shade(column, row, across, colours))
	_cell(HOLE, INK_COLOR)
	draw_rect(STRING_RECT, INK_COLOR)


## The rest place (the parent's coordinates).
func place(at: Vector2) -> void:
	_rest = at
	_apply()


## Shows `worth` at once, paid (gold) or not (paper).
func show_value(worth: int, paid: bool) -> void:
	_stop_count()
	_paid_by_rise = false
	_value = worth
	_to = worth
	_paid = paid
	visible = true
	_show_text()


## Counts from the shown value to `worth` over COUNT_S, `delay` s from now (on the count's clock),
## turning paid (gold) or not as it starts, popping and swinging. At once under reduced motion.
func count_to(worth: int, paid: bool, delay: float = 0.0) -> void:
	if not visible or _reduced() or not is_inside_tree():
		show_value(worth, paid)
		return
	_stop_count()
	if not paid:
		_paid_by_rise = false
	_to = worth
	_count = _new_tween().set_parallel(true)
	_count.tween_callback(_begin.bind(worth, paid)).set_delay(delay)
	_count.tween_method(_count_step, 0.0, 1.0, COUNT_S).set_delay(delay)
	_count.tween_method(_set_pop_t, 0.0, POP_S, POP_S).set_delay(delay)
	_count.tween_method(_set_swing_t, 0.0, SWING_S, SWING_S).set_delay(delay)


## The payout's rise: gold (if it was paper), with a pop; the value stays.
func pay() -> void:
	if not visible:
		return
	_paid_by_rise = true
	if not _paid:
		_paid = true
		_show_text()
	if _reduced() or not is_inside_tree():
		return
	if _pop != null:
		_pop.kill()
	_pop = _new_tween()
	_pop.tween_method(_set_pop_t, 0.0, POP_S, POP_S)


## Leaves with the item: its slide-out's offset, turn and alpha (BayBed.out_offset).
func follow_out(pose: BayBed.BayPose) -> void:
	_out = pose
	_apply()


## Gone (the bay empty, a new count).
func hide_tag() -> void:
	_stop_count()
	_paid_by_rise = false
	if _pop != null:
		_pop.kill()
		_pop = null
	_pop_t = -1.0
	_swing_t = -1.0
	_out = BayBed.BayPose.new()
	visible = false
	_apply()


## The value shown, whether it is paid (gold) and its text.
func value() -> int:
	return _value


func is_paid() -> bool:
	return _paid


func text() -> String:
	return _label.text


## The face's light rim, body and shade now.
func face_colours() -> Array[Color]:
	return PAID_COLOURS if _paid else UNPAID_COLOURS


## Where a chip leaves from (global): near the tag's right end, by its middle.
func send_point() -> Vector2:
	return get_global_transform() * Vector2(size.x - SEND_INSET.x, SEND_INSET.y)


## The tag's width for `text` (px): at least MIN_WIDTH, on the 2 px grid.
static func width_for(text_shown: String) -> float:
	var font: Font = ArtStyle.bold_font(WEIGHT)
	var text_width: float = (
		font.get_string_size(text_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	)
	var grid: float = ArtStyle.ART_SCALE
	return maxf(MIN_WIDTH, ceilf((TEXT_LEFT + text_width + TEXT_RIGHT) / grid) * grid)


## Whether art cell (`column`, `row`) is inside a tag `across` art px wide: a chamfered left end.
static func _in(column: int, row: int, across: int) -> bool:
	if column < 0 or row < 0 or column >= across or row >= ROWS:
		return false
	return column >= 3 or (row >= 3 - column and row <= 7 + column)


## An inside cell's colour: ink on the edge, the light rim by an outside cell 2 up or left, the
## shade by one 2 down or right, else the body.
static func _shade(column: int, row: int, across: int, colours: Array[Color]) -> Color:
	var edge: bool = (
		not _in(column - 1, row, across)
		or not _in(column + 1, row, across)
		or not _in(column, row - 1, across)
		or not _in(column, row + 1, across)
	)
	if edge:
		return INK_COLOR
	if not _in(column, row - 2, across) or not _in(column - 2, row, across):
		return colours[0]
	if not _in(column, row + 2, across) or not _in(column + 2, row, across):
		return colours[2]
	return colours[1]


func _cell(cells: Rect2i, colour: Color) -> void:
	var scale_px: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(Vector2(cells.position) * scale_px, Vector2(cells.size) * scale_px), colour)


## A count starts: its paid look and where it counts from.
func _begin(target: int, paid: bool) -> void:
	_from = _value
	_to = target
	_paid = paid or _paid_by_rise
	_show_text()


func _count_step(progress: float) -> void:
	_value = roundi(lerpf(_from, _to, progress))
	_show_text()


func _set_pop_t(seconds: float) -> void:
	_pop_t = seconds
	_apply()


func _set_swing_t(seconds: float) -> void:
	_swing_t = seconds
	_apply()


## The text, the width and the colours for the value now.
func _show_text() -> void:
	_label.text = "€%d" % _value
	_label.add_theme_color_override("font_color", PAID_TEXT_COLOR if _paid else UNPAID_TEXT_COLOR)
	var width: float = width_for(_label.text)
	size = Vector2(width, HEIGHT)
	_label.position = Vector2(TEXT_LEFT, 0.0)
	_label.size = Vector2(width - TEXT_LEFT - LABEL_RIGHT, TEXT_HEIGHT)
	queue_redraw()


## The place, pop, swing and slide-out now.
func _apply() -> void:
	var pop: float = 1.0
	if _pop_t >= 0.0 and _pop_t < POP_S:
		var left: float = 1.0 - _pop_t / POP_S
		pop += POP * left * left
	var swing: float = 0.0
	if _swing_t >= 0.0 and _swing_t < SWING_S:
		var fade: float = 1.0 - _swing_t / SWING_S
		swing = sin(_swing_t * SWING_RATE) * SWING_DEG * fade * fade
	scale = Vector2.ONE * pop
	rotation_degrees = swing + _out.rotation_deg
	position = _rest + _out.offset
	modulate.a = _out.alpha


func _stop_count() -> void:
	if _count != null:
		_count.kill()
		_count = null


func _new_tween() -> Tween:
	return make_tween.call() as Tween if make_tween.is_valid() else create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
