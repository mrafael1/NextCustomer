class_name LedBeat
extends Control
## The count-up beat's parts on the LED's count layout (#80, mock-up B2; LedDisplay.Layout.COUNT,
## on the monitor's paper): the beat's gain on a mustard chip ("+€N") beside the digits, its step
## line at the right of the caption row (as the caller words it, a fizzle's in dark tomato,
## right-aligned, in the largest of STEP_SIZES that shows it whole inside STEP_RECT) and how far
## the quota is ("€N to go", "On quota" or "€N over") after the bar. The LED owns it and shows it
## in its count layout only. Display only: the gain and the line are the caller's, the to-go text
## the LED's from core's ShiftMargin.

## In the LED's coordinates: the gain chip's room (the chip right-aligned in it less its
## GAIN_SHADOW, centred on the digits' ink, its widest realistic "+€999" and its shadow filling
## it), the step line's room (one line centred
## on the caption row's STEP_ROW_HEIGHT, more lines from the row's top, all above the digits'
## ink) and the to-go text.
const GAIN_RECT := Rect2(206, 54, 70, 28)
const STEP_RECT := Rect2(84, 0, 192, 36)
const STEP_ROW_HEIGHT := 24.0
const TO_GO_RECT := Rect2(202, 108, 74, 22)
const GAIN_FONT_SIZE := 18
const TEXT_FONT_SIZE := 12
## The step line's and the to-go text's weights (B2's 650 and 700).
const STEP_WEIGHT := 650
const TO_GO_WEIGHT := 700
## The step line wraps inside STEP_RECT in the first of STEP_SIZES that shows it whole; past the
## smallest, its end is trimmed with an ellipsis on the lines that fit.
const STEP_SIZES: Array[int] = [12, 11, 10]
const STEP_LINE_SPACING := -3
## The gain chip's face (GainFace), B2's raised key as the belt's chips: mustard with an ink
## border, a GAIN_BAND mustard-light band under its top border and a brass one over its bottom
## border, over an ink shadow GAIN_SHADOW px down and right at GAIN_SHADOW_ALPHA; its text this
## far in from its sides. B2's chip is 20 px with 8 px sides; "+€999" at that size and its shadow
## would overrun GAIN_RECT, so the chip keeps 18 px and 6 px.
const GAIN_BORDER := 2
const GAIN_PADDING := 6
const GAIN_BAND := 2
const GAIN_SHADOW := 3
const GAIN_SHADOW_ALPHA := 0.3
## The gain chip pops in from this scale, over this long (not under reduced motion).
const GAIN_POP := 1.3
const GAIN_POP_SECONDS := 0.12
## The to-go text: short of the quota, on it and past it (ShiftMargin's kinds).
const TO_GO_TEXT := "€%d to go"
const ON_QUOTA_TEXT := "On quota"
const OVER_TEXT := "€%d over"
## The step line and the to-go text in light ink on the paper; a fizzle's step line in dark
## tomato (tomato is only for fizzles, CHECKOUT and CLOSED).
const TEXT_COLOR := Palette.INK_LIGHT
const FIZZLE_COLOR := Palette.TOMATO_DARK

## Returns a new tween for the gain chip's pop: CountUp sets its own, so the pop follows the
## count-up's speed (taps, holds) and freezes in its hit-stops. None means the LED's own tween.
var make_tween: Callable = Callable()

var _gain: Label
var _step: Label
var _to_go: Label
## The gain chip's pop-in, while it runs.
var _pop: Tween


func _init() -> void:
	name = "Beat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gain = UiKit.number_label("", GAIN_FONT_SIZE, false)
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var face: GainFace = GainFace.new()
	face.content_margin_left = GAIN_PADDING
	face.content_margin_right = GAIN_PADDING
	face.content_margin_top = GAIN_BORDER
	face.content_margin_bottom = GAIN_BORDER
	_gain.add_theme_stylebox_override("normal", face)
	_gain.visible = false
	add_child(_gain)
	_step = UiKit.body_label("", TEXT_FONT_SIZE, TEXT_COLOR)
	_step.add_theme_font_override("font", ArtStyle.bold_font(STEP_WEIGHT))
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.add_theme_constant_override("line_spacing", STEP_LINE_SPACING)
	_step.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_step)
	_to_go = UiKit.body_label("", TEXT_FONT_SIZE, TEXT_COLOR)
	_to_go.add_theme_font_override("font", ArtStyle.bold_font(TO_GO_WEIGHT))
	_to_go.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_to_go)
	_lay_out()


func _ready() -> void:
	_lay_out()


## The beat's `gain` on the chip ("+€N"; negative hides it) and its step `line` (empty for none; a
## `fizzle`'s in dark tomato). With `pop` the chip pops in (GAIN_POP to 1 over
## GAIN_POP_SECONDS, on make_tween's tween); without it (reduced motion) it shows at its size.
func show_beat(gain: int, line: String, fizzle: bool, pop: bool) -> void:
	_gain.text = "+€%d" % gain if gain >= 0 else ""
	_step.text = line
	_step.add_theme_color_override("font_color", FIZZLE_COLOR if fizzle else TEXT_COLOR)
	_stop_pop()
	_lay_out()
	if not pop or not _gain.visible or not is_inside_tree():
		return
	_gain.scale = Vector2(GAIN_POP, GAIN_POP)
	_pop = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_gain, "scale", Vector2.ONE, GAIN_POP_SECONDS)


## No gain and no step line (a new count, the total, planning).
func clear_beat() -> void:
	show_beat(-1, "", false, false)


## The to-go text (to_go_text of the shown amount's margin).
func show_to_go(text: String) -> void:
	_to_go.text = text


func gain_label() -> Label:
	return _gain


func step_label() -> Label:
	return _step


func to_go_label() -> Label:
	return _to_go


## Whether the gain chip is popping in now.
func is_popping() -> bool:
	return _pop != null and _pop.is_valid() and _pop.is_running()


## The to-go text for `margin`, core's ShiftMargin of the shown amount against the quota: "€N to
## go" short of it, "On quota" on it, "€N over" past it.
static func to_go_text(margin: ShiftMargin) -> String:
	match margin.kind():
		ShiftMargin.Kind.SHORT:
			return TO_GO_TEXT % margin.amount()
		ShiftMargin.Kind.ON:
			return ON_QUOTA_TEXT
	return OVER_TEXT % margin.amount()


func _stop_pop() -> void:
	if _pop != null:
		_pop.kill()
		_pop = null
	_gain.scale = Vector2.ONE


## The parts at their rects (measured in the tree: out of it a label measures with the default
## font size), each shown while it says something: the step line in the first of STEP_SIZES whose
## wrapped lines fit STEP_RECT's height (trimmed to the lines that fit past the smallest), as tall
## as its lines and centred on the caption row while it is one row high; the chip at its text's
## width at its room's right, less its shadow.
func _lay_out() -> void:
	_step.visible = not _step.text.is_empty()
	_step.max_lines_visible = -1
	_step.position = STEP_RECT.position
	_step.size = Vector2(STEP_RECT.size.x, STEP_RECT.size.y)
	for step_size: int in STEP_SIZES:
		_step.add_theme_font_size_override("font_size", step_size)
		if _lines_height(_step, _step.get_line_count()) <= STEP_RECT.size.y:
			break
	var lines: int = _step.get_line_count()
	while lines > 1 and _lines_height(_step, lines) > STEP_RECT.size.y:
		lines -= 1
	if lines < _step.get_line_count():
		_step.max_lines_visible = lines
	var height: float = _lines_height(_step, lines)
	_step.size = Vector2(STEP_RECT.size.x, height)
	_step.position.y = STEP_RECT.position.y + maxf(0.0, (STEP_ROW_HEIGHT - height) / 2.0)
	_to_go.position = TO_GO_RECT.position
	_to_go.size = TO_GO_RECT.size
	_gain.visible = not _gain.text.is_empty()
	var width: float = _gain.get_minimum_size().x
	_gain.size = Vector2(width, GAIN_RECT.size.y)
	_gain.position = Vector2(GAIN_RECT.end.x - GAIN_SHADOW - width, GAIN_RECT.position.y)
	_gain.pivot_offset = _gain.size / 2.0


## The height of `lines` wrapped lines in `label`'s font and size, its line spacing between them
## (an autowrapped label's minimum size does not say).
static func _lines_height(label: Label, lines: int) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var spacing: int = label.get_theme_constant("line_spacing")
	return lines * font.get_height(font_size) + (lines - 1) * spacing


## The gain chip's face (see GAIN_BORDER): its shadow drawn outside the chip's rect, down and
## right, so it scales with the chip's pop.
class GainFace:
	extends StyleBox

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var item: RID = to_canvas_item
		var shadow: Rect2 = Rect2(rect.position + Vector2.ONE * GAIN_SHADOW, rect.size)
		RenderingServer.canvas_item_add_rect(item, shadow, Color(Palette.INK, GAIN_SHADOW_ALPHA))
		RenderingServer.canvas_item_add_rect(item, rect, Palette.INK)
		var face: Rect2 = rect.grow(-GAIN_BORDER)
		RenderingServer.canvas_item_add_rect(item, face, Palette.MUSTARD)
		var band: Vector2 = Vector2(face.size.x, GAIN_BAND)
		RenderingServer.canvas_item_add_rect(
			item, Rect2(face.position, band), Palette.MUSTARD_LIGHT
		)
		var bottom: Vector2 = Vector2(face.position.x, face.end.y - GAIN_BAND)
		RenderingServer.canvas_item_add_rect(item, Rect2(bottom, band), Palette.BRASS)
