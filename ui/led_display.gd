class_name LedDisplay
extends Control
## The register's LED (#55, from style frame v2's LedTotal): a brass-bezelled panel of dark glass
## with one set of digits for both totals, under a caption that says which one shows:
## PROJECTED in planning (the preview's total), SUBTOTAL from the checkout (the count-up's
## running subtotal) and TOTAL once the verdict is shown (also on a resumed checkout); blank in
## the impulse rack. Under the digits, the quota line ("QUOTA €N") and a 10-segment bar lit in
## proportion to the shown amount, so the quota never shows by colour alone (the fb-p2 finding
## that players thought a lower total wins). The subtotal turns from mustard to green when the
## count-up says the quota is met (its ding beat); the projected total is green once it reaches
## the quota. Display only: the amounts are the caller's (a ScoreResult's total or a step's
## subtotal), and nothing here scores. Its glass clips its contents, so a punch never spills.

enum Mode { BLANK, PROJECTED, SUBTOTAL, TOTAL }

const PROJECTED_TEXT := "PROJECTED"
const SUBTOTAL_TEXT := "SUBTOTAL"
const TOTAL_TEXT := "TOTAL"
## The bezel's 9-slice margin, in art pixels.
const FRAME_MARGIN := 4
## The parts' rects in the LED's own coordinates (ShiftStage's stage rects, less the LED's
## position).
const CAPTION_RECT := Rect2(
	ShiftStage.LED_CAPTION_RECT.position - ShiftStage.LED_RECT.position,
	ShiftStage.LED_CAPTION_RECT.size
)
const DIGITS_RECT := Rect2(
	ShiftStage.LED_DIGITS_RECT.position - ShiftStage.LED_RECT.position,
	ShiftStage.LED_DIGITS_RECT.size
)
const QUOTA_RECT := Rect2(
	ShiftStage.LED_QUOTA_RECT.position - ShiftStage.LED_RECT.position,
	ShiftStage.LED_QUOTA_RECT.size
)
## The bar: SEGMENTS segments from the quota line's left, centred on it.
const SEGMENTS := 10
const SEGMENT_SIZE := Vector2(10, 12)
const SEGMENT_GAP := 2.0
## The bar's top below the quota line's: centred on it, on the 2 px art grid.
const BAR_DROP := 4.0
const BAR_ORIGIN := Vector2(QUOTA_RECT.position.x, QUOTA_RECT.position.y + BAR_DROP)
## The bar's right end.
const BAR_END_X := BAR_ORIGIN.x + SEGMENTS * (SEGMENT_SIZE.x + SEGMENT_GAP) - SEGMENT_GAP
## The quota chip's room on the quota line: from CHIP_GAP past the bar to the line's right end,
## over the right-aligned "QUOTA €N".
const CHIP_GAP := 10.0
const CHIP_RECT := Rect2(
	BAR_END_X + CHIP_GAP,
	QUOTA_RECT.position.y,
	QUOTA_RECT.end.x - BAR_END_X - CHIP_GAP,
	QUOTA_RECT.size.y
)
const CAPTION_FONT_SIZE := 12
const DIGITS_FONT_SIZE := 48
const QUOTA_FONT_SIZE := 14
## The digits' glow: an outline of their own colour at GLOW_ALPHA.
const GLOW_SIZE := 6
const GLOW_ALPHA := 0.35
const CAPTION_COLOR := Palette.BRASS
const QUOTA_COLOR := Palette.BRASS
## The digits' colour, and theirs once the quota is met.
const DIGITS_COLOR := Palette.MUSTARD
const MET_COLOR := Palette.GOOD
const LIT_COLOR := Palette.GOLD
const UNLIT_COLOR := Palette.VELVET_DARK

const FRAME := preload("res://art/frames/led_panel.png")

var _mode: Mode = Mode.BLANK
var _quota: int = 0
var _lit: int = 0
var _caption: Label
var _digits: Label
var _quota_label: Label
## Each label's rect, set again once in the tree (a label never shrinks back by itself).
var _rects: Dictionary[Label, Rect2] = {}


func _init() -> void:
	name = "Led"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size = ShiftStage.LED_RECT.size
	ArtStyle.use_pixel_material(self)
	_caption = UiKit.display_label("", CAPTION_FONT_SIZE, false)
	_caption.add_theme_color_override("font_color", CAPTION_COLOR)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_caption, CAPTION_RECT)
	_digits = UiKit.number_label("", DIGITS_FONT_SIZE, false)
	_digits.add_theme_constant_override("outline_size", GLOW_SIZE)
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_digits.pivot_offset = DIGITS_RECT.size / 2.0
	_place(_digits, DIGITS_RECT)
	_quota_label = UiKit.number_label("", QUOTA_FONT_SIZE, false)
	_quota_label.add_theme_color_override("font_color", QUOTA_COLOR)
	_quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quota_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_quota_label, QUOTA_RECT)
	reset_colour()


func _ready() -> void:
	for label: Label in _rects:
		label.position = _rects[label].position
		label.size = _rects[label].size
	# The digits' line box is taller than their rect: it stays centred on the rect (the ink is
	# far shorter than the line), and punches scale it about its centre.
	_digits.position.y = DIGITS_RECT.get_center().y - _digits.size.y / 2.0
	_digits.pivot_offset = _digits.size / 2.0


func _draw() -> void:
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), Rect2(Vector2.ZERO, size))
	if _mode == Mode.BLANK:
		return
	for index: int in range(SEGMENTS):
		draw_rect(segment_rect(index), LIT_COLOR if index < _lit else UNLIT_COLOR)


## The preview's total against the shift's `quota`, green once it reaches it.
func show_projected(amount: int, quota: int) -> void:
	_mode = Mode.PROJECTED
	_caption.text = PROJECTED_TEXT
	_set_quota(quota)
	_set_colour(MET_COLOR if amount >= quota else DIGITS_COLOR)
	_set_amount(amount)


## A count-up starts against `quota`: the SUBTOTAL caption, in the digits' own colour. The
## amounts follow through show_subtotal().
func start_count(quota: int) -> void:
	_mode = Mode.SUBTOTAL
	_caption.text = SUBTOTAL_TEXT
	_set_quota(quota)
	reset_colour()


## The running subtotal (`met`: the count-up has met the quota, so it shows green). The caption
## stays as it is (SUBTOTAL, or TOTAL once the verdict is shown).
func show_subtotal(amount: int, met: bool) -> void:
	_set_colour(MET_COLOR if met else DIGITS_COLOR)
	_set_amount(amount)


## The verdict is shown: the caption says TOTAL over the amount already shown.
func show_total() -> void:
	_mode = Mode.TOTAL
	_caption.text = TOTAL_TEXT


## The digits' own colour (the quota not met).
func reset_colour() -> void:
	_set_colour(DIGITS_COLOR)


## Blank: no caption, digits, quota line or lit segments (the impulse rack).
func clear() -> void:
	_mode = Mode.BLANK
	_caption.text = ""
	_digits.text = ""
	_quota_label.text = ""
	_lit = 0
	reset_colour()
	queue_redraw()


func mode() -> Mode:
	return _mode


func caption() -> String:
	return _caption.text


func caption_label() -> Label:
	return _caption


## The digits (their pivot at their centre, for the count-up's punches).
func digits_label() -> Label:
	return _digits


func quota_label() -> Label:
	return _quota_label


## Segments lit now.
func lit() -> int:
	return _lit


## Segment `index`'s rect, in the LED's coordinates.
func segment_rect(index: int) -> Rect2:
	return Rect2(BAR_ORIGIN + Vector2(index * (SEGMENT_SIZE.x + SEGMENT_GAP), 0), SEGMENT_SIZE)


## Where the quota chip sits (global): the quota line's right part while the LED shows the
## count-up's SUBTOTAL or TOTAL, and an empty rect otherwise (blank, PROJECTED, or not shown),
## which hides the chip.
func quota_anchor() -> Rect2:
	if (_mode != Mode.SUBTOTAL and _mode != Mode.TOTAL) or not is_visible_in_tree():
		return Rect2()
	return Rect2(get_global_transform() * CHIP_RECT.position, CHIP_RECT.size)


## The quota text's measured width (global), in the label's own font and size: the right-aligned
## "QUOTA €N" ends at the quota line's right end, so the chip covers it when it is at least this
## wide. Not the label's rect, which spans the whole line.
func quota_text_width() -> float:
	var font: Font = _quota_label.get_theme_font("font")
	var font_size: int = _quota_label.get_theme_font_size("font_size")
	var width: float = (
		font.get_string_size(_quota_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	return width * _quota_label.get_global_transform().get_scale().x


## The digits' ink as drawn now (global): the text's measured width and its glyphs' height
## (the digits and "€" have no descenders, so this is far less than the label's line height),
## scaled by a punch about the digits' centre. Not the label's rect.
func digits_text_rect() -> Rect2:
	var font: Font = _digits.get_theme_font("font")
	var font_size: int = _digits.get_theme_font_size("font_size")
	var width: float = (
		font.get_string_size(_digits.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	var ink: Vector2 = ink_span(_digits.text, font, font_size)
	# The label centres its line box: the baseline sits `ascent` below the box's top.
	var line_top: float = (_digits.size.y - font.get_height(font_size)) / 2.0
	var baseline: float = line_top + font.get_ascent(font_size)
	var left: float = (_digits.size.x - width) / 2.0
	var local: Rect2 = Rect2(left, baseline + ink.x, width, ink.y - ink.x)
	var transform: Transform2D = _digits.get_global_transform()
	return Rect2(transform * local.position, local.size * transform.get_scale())


## The ink's top and bottom of `text`'s glyphs, from the baseline (down is positive): their
## outlines' extent, as a glyph's bitmap rect carries padding (and an MSDF font's its range).
static func ink_span(text: String, font: Font, font_size: int) -> Vector2:
	var server: TextServer = TextServerManager.get_primary_interface()
	var line: TextLine = TextLine.new()
	line.add_string(text, font, font_size)
	var span: Vector2 = Vector2(INF, -INF)
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var font_rid: RID = glyph["font_rid"]
		var index: int = glyph["index"]
		var contours: Dictionary = server.font_get_glyph_contours(font_rid, font_size, index)
		var points: PackedVector3Array = contours.get("points", PackedVector3Array())
		for point: Vector3 in points:
			span.x = minf(span.x, point.y)
			span.y = maxf(span.y, point.y)
	return span if span.x <= span.y else Vector2.ZERO


## The glass inside the bezel (global).
func interior() -> Rect2:
	var margin: float = FRAME_MARGIN * ArtStyle.ART_SCALE
	return Rect2(
		get_global_transform() * Vector2(margin, margin), size - 2.0 * Vector2(margin, margin)
	)


## The bar's lit segments for `amount` against `quota`: floor(10 x min(1, amount / quota)), all
## of them for a quota of 0. Display arithmetic only.
static func lit_segments(amount: int, quota: int) -> int:
	if quota <= 0:
		return SEGMENTS
	return floori(SEGMENTS * minf(1.0, float(maxi(amount, 0)) / quota))


func _set_quota(quota: int) -> void:
	_quota = quota
	_quota_label.text = "QUOTA €%d" % quota


func _set_amount(amount: int) -> void:
	_digits.text = "€%d" % amount
	_lit = lit_segments(amount, _quota)
	queue_redraw()


func _set_colour(colour: Color) -> void:
	_digits.add_theme_color_override("font_color", colour)
	_digits.add_theme_color_override("font_outline_color", Color(colour, GLOW_ALPHA))


func _place(label: Label, rect: Rect2) -> void:
	_rects[label] = rect
	label.position = rect.position
	label.size = rect.size
	add_child(label)
