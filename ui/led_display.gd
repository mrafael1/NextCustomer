class_name LedDisplay
extends Control
## The register's LED (#55, from style frame v2's LedTotal): one set of digits for both totals,
## under a caption that says which one shows: PROJECTED (the preview's total; the shift screen no
## longer shows it since the user's play test of 2026-10-17: planning is blank, under the
## monitor's store channel, MonitorChannel), SUBTOTAL from the checkout (the count-up's running
## subtotal) and TOTAL once the verdict is shown (also on a resumed checkout); blank in planning
## and the impulse rack. With the digits, the quota line
## ("QUOTA €N") and a 10-segment bar lit in proportion to the shown amount, so the quota never
## shows by colour alone (the fb-p2 finding that players thought a lower total wins). The
## subtotal turns green when the count-up says the quota is met (its ding beat); the projected
## total is green once it reaches the quota. Display only: the amounts are the caller's (a
## ScoreResult's total or a step's subtotal), and nothing here scores.
##
## It sits on the hung monitor (#80, MonitorView), which places it, in one of two layouts that
## follow its mode. The compact one (Layout.COMPACT: CAPTION_RECT, DIGITS_RECT and QUOTA_RECT) is
## planning's and the impulse rack's: a brass-bezelled panel of dark glass that clips its
## contents, with the caption, mustard digits and the quota line. The count-up's (Layout.COUNT,
## for SUBTOTAL and TOTAL; the COUNT_ constants) is mock-up B2's count-up screen: no glass, straight
## on the monitor's paper. The caption with the beat's step line at the row's right, the digits
## big in ink over a mustard-light shadow, the beat's gain chip beside them (beat(), LedBeat), and
## the quota row: "QUOTA €N" (the chip's room; the word in the letter-spaced display font, the
## amount in the number font, as B2's), the bar and how far the quota is (from core's ShiftMargin
## of the shown amount). There the digits take the first of COUNT_DIGITS_SIZES that
## keeps their text inside COUNT_DIGITS_RECT's width, clear of the gain chip; they are
## left-aligned and their label is as wide as their text, so a punch about its centre (and the
## dessert's slam) stays on them. Nothing clips there: a punch may spill onto the paper.

## Emitted whenever the mode is set (show_projected, start_count, show_total, clear), even to the
## same mode, once the layout follows it: the monitor places the LED for it.
signal mode_changed(mode: Mode)
## Each amount shown with its quota (start_count: 0) and whether the digits show the quota met,
## for the top bar's QuotaMeter.
signal reading_changed(amount: int, quota: int, met: bool)

enum Mode { BLANK, PROJECTED, SUBTOTAL, TOTAL }
enum Layout { COMPACT, COUNT }

const PROJECTED_TEXT := "PROJECTED"
const SUBTOTAL_TEXT := "SUBTOTAL"
const TOTAL_TEXT := "TOTAL"
## The bezel's 9-slice margin, in art pixels.
const FRAME_MARGIN := 4
## The compact layout's parts in the LED's own coordinates (ShiftStage's stage rects, less the
## LED's position).
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
## The count-up's layout (Layout.COUNT, mock-up B2), in the LED's own coordinates: its size; the
## caption row (the beat's step line at its right, LedBeat.STEP_RECT); the digits' room (their
## widest; the beat's gain chip right of it, LedBeat.GAIN_RECT); the quota row with "QUOTA €N"
## right-aligned in COUNT_QUOTA_RECT (the chip's room too; the word QUOTA_WORD_GAP left of the
## amount, in the display font at COUNT_QUOTA_WORD_SIZE, its glyphs COUNT_QUOTA_WORD_SPACING px
## apart), the bar's first segment at
## COUNT_BAR_ORIGIN in an ink frame COUNT_BAR_BORDER wide, and the to-go text after it
## (LedBeat.TO_GO_RECT). The longest digits at the count-up's largest punch stay on the
## monitor's paper.
const COUNT_SIZE := Vector2(276, 138)
const COUNT_CAPTION_RECT := Rect2(0, 0, 84, 24)
const COUNT_DIGITS_RECT := Rect2(0, 38, 200, 62)
const COUNT_QUOTA_ROW := Rect2(0, 108, 276, 22)
const COUNT_QUOTA_RECT := Rect2(0, 108, 88, 22)
const COUNT_BAR_ORIGIN := Vector2(96, 112)
const COUNT_SEGMENT_SIZE := Vector2(8, 12)
const COUNT_BAR_BORDER := 2
const CAPTION_FONT_SIZE := 12
const COUNT_CAPTION_FONT_SIZE := 16
const DIGITS_FONT_SIZE := 48
## The count's digits, largest first (B2's 78 px): the first whose text fits COUNT_DIGITS_RECT's
## width. Every total up to €999 shows at the largest, and so does the simulator's largest
## (€1118, its narrow 1s); wider four-digit totals (€1000, €1234) take a smaller size. Their
## glyphs run COUNT_DIGITS_SPACING px tighter, one px tighter than B2's -1 so the widest
## three-digit total (€400) fits the room at 78 px, over a shadow COUNT_SHADOW px down and right
## (an exact copy of the glyphs, as B2's text-shadow: no shadow outline).
const COUNT_DIGITS_SIZES: Array[int] = [78, 70, 62]
const COUNT_DIGITS_SPACING := -2
const COUNT_SHADOW := 4
const QUOTA_FONT_SIZE := 14
const QUOTA_WORD := "QUOTA"
const COUNT_QUOTA_WORD_SIZE := 13
const COUNT_QUOTA_WORD_SPACING := 1
const QUOTA_WORD_GAP := 4.0
## The digits' glow on the glass: an outline of their own colour at GLOW_ALPHA.
const GLOW_SIZE := 6
const GLOW_ALPHA := 0.35
const CAPTION_COLOR := Palette.BRASS
const QUOTA_COLOR := Palette.BRASS
## The digits' colour on the glass, and theirs once the quota is met (in both layouts).
const DIGITS_COLOR := Palette.MUSTARD
const MET_COLOR := Palette.GOOD
const LIT_COLOR := Palette.GOLD
const UNLIT_COLOR := Palette.VELVET_DARK
## The count layout on the paper: ink digits over a mustard-light shadow, the caption and the
## quota text in light ink, and the bar's segments mustard with a lit top edge, or plaster when
## unlit. No tomato (#80: it is only for fizzles, CHECKOUT and CLOSED).
const COUNT_DIGITS_COLOR := Palette.INK
const COUNT_SHADOW_COLOR := Palette.MUSTARD_LIGHT
const COUNT_TEXT_COLOR := Palette.INK_LIGHT
const COUNT_LIT_COLOR := Palette.MUSTARD
const COUNT_LIT_EDGE_COLOR := Palette.MUSTARD_LIGHT
const COUNT_LIT_EDGE := 2.0
const COUNT_UNLIT_COLOR := Palette.PLASTER

const FRAME := preload("res://art/frames/led_panel.png")

var _mode: Mode = Mode.BLANK
var _layout: Layout = Layout.COMPACT
var _quota: int = 0
var _lit: int = 0
## The digits show MET_COLOR (the quota met, or the projected total reaching it).
var _met: bool = false
var _caption: Label
var _digits: Label
var _quota_label: Label
## The count layout's QUOTA word, left of _quota_label's amount (hidden in the compact layout,
## whose _quota_label says "QUOTA €N" itself).
var _quota_word: Label
## The count layout's digits font: the number font, its glyphs COUNT_DIGITS_SPACING tighter.
var _count_font: FontVariation
## The count layout's beat parts (hidden in the compact one).
var _beat: LedBeat
## The layout's bar (its first segment's top-left and each segment's size) and the chip's room.
var _bar_origin: Vector2 = BAR_ORIGIN
var _segment_size: Vector2 = SEGMENT_SIZE
var _chip_rect: Rect2 = CHIP_RECT
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
	_digits.add_theme_constant_override("shadow_outline_size", 0)
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_digits.pivot_offset = DIGITS_RECT.size / 2.0
	_place(_digits, DIGITS_RECT)
	_quota_label = UiKit.number_label("", QUOTA_FONT_SIZE, false)
	_quota_label.add_theme_color_override("font_color", QUOTA_COLOR)
	_quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quota_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_quota_label, QUOTA_RECT)
	_quota_word = UiKit.display_label(QUOTA_WORD, COUNT_QUOTA_WORD_SIZE, false)
	_quota_word.add_theme_font_override(
		"font", ArtStyle.spaced_display_font(COUNT_QUOTA_WORD_SPACING)
	)
	_quota_word.add_theme_color_override("font_color", COUNT_TEXT_COLOR)
	_quota_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quota_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quota_word.visible = false
	_place(_quota_word, COUNT_QUOTA_RECT)
	_count_font = ArtStyle.number_font().duplicate() as FontVariation
	_count_font.spacing_glyph = COUNT_DIGITS_SPACING
	_beat = LedBeat.new()
	_beat.size = COUNT_SIZE
	_beat.visible = false
	add_child(_beat)
	reset_colour()


func _ready() -> void:
	_lay_out()


func _draw() -> void:
	if _layout == Layout.COUNT:
		_draw_count_bar()
		return
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), Rect2(Vector2.ZERO, size))
	if _mode == Mode.BLANK:
		return
	for index: int in range(SEGMENTS):
		draw_rect(segment_rect(index), LIT_COLOR if index < _lit else UNLIT_COLOR)


## The preview's total against the shift's `quota`, green once it reaches it.
func show_projected(amount: int, quota: int) -> void:
	_caption.text = PROJECTED_TEXT
	_set_quota(quota)
	_set_mode(Mode.PROJECTED)
	_set_colour(amount >= quota)
	_set_amount(amount)
	reading_changed.emit(amount, quota, _met)


## A count-up starts against `quota`: the SUBTOTAL caption, in the digits' own colour. The
## amounts follow through show_subtotal().
func start_count(quota: int) -> void:
	_caption.text = SUBTOTAL_TEXT
	_set_quota(quota)
	_set_mode(Mode.SUBTOTAL)
	reset_colour()
	reading_changed.emit(0, quota, false)


## The running subtotal (`met`: the count-up has met the quota, so it shows green). The caption
## stays as it is (SUBTOTAL, or TOTAL once the verdict is shown).
func show_subtotal(amount: int, met: bool) -> void:
	_set_colour(met)
	_set_amount(amount)
	reading_changed.emit(amount, _quota, met)


## The verdict is shown: the caption says TOTAL over the amount already shown, and the last
## beat's gain and step line go.
func show_total() -> void:
	_caption.text = TOTAL_TEXT
	_set_mode(Mode.TOTAL)


## The digits' own colour (the quota not met): DIGITS_COLOR on the glass, COUNT_DIGITS_COLOR in
## the count layout.
func reset_colour() -> void:
	_set_colour(false)


## Blank: no caption, digits, quota line or lit segments (the impulse rack).
func clear() -> void:
	_caption.text = ""
	_digits.text = ""
	_quota_label.text = ""
	_lit = 0
	_set_mode(Mode.BLANK)
	reset_colour()
	queue_redraw()


func mode() -> Mode:
	return _mode


## The layout now (it follows the mode).
func layout() -> Layout:
	return _layout


func caption() -> String:
	return _caption.text


func caption_label() -> Label:
	return _caption


## The digits (their pivot at their centre, for the count-up's punches).
func digits_label() -> Label:
	return _digits


## The quota line: "QUOTA €N" in the compact layout, the amount ("€N") in the count layout, where
## quota_word_label() says QUOTA left of it.
func quota_label() -> Label:
	return _quota_label


func quota_word_label() -> Label:
	return _quota_word


## The count layout's beat parts: the gain chip, the step line and the to-go text.
func beat() -> LedBeat:
	return _beat


## Segments lit now.
func lit() -> int:
	return _lit


## Segment `index`'s rect, in the LED's coordinates.
func segment_rect(index: int) -> Rect2:
	return Rect2(_bar_origin + Vector2(index * (_segment_size.x + SEGMENT_GAP), 0), _segment_size)


## Where the quota chip sits (global): over the right-aligned "QUOTA €N" while the LED shows the
## count-up's SUBTOTAL or TOTAL (COUNT_QUOTA_RECT, the quota row's left), and an empty rect
## otherwise (blank, PROJECTED, or not shown), which hides the chip.
func quota_anchor() -> Rect2:
	if (_mode != Mode.SUBTOTAL and _mode != Mode.TOTAL) or not is_visible_in_tree():
		return Rect2()
	return Rect2(get_global_transform() * _chip_rect.position, _chip_rect.size)


## The quota text's measured width (global), in its labels' own fonts and sizes: the right-aligned
## "QUOTA €N" (in the count layout the word, QUOTA_WORD_GAP and the amount) ends at its label's
## right end, so the chip covers it when it is at least this wide. Not the labels' rects.
func quota_text_width() -> float:
	var width: float = _text_width(_quota_label)
	if _layout == Layout.COUNT:
		width += QUOTA_WORD_GAP + _text_width(_quota_word)
	return width * _quota_label.get_global_transform().get_scale().x


## The digits' ink as drawn now (global): the text's measured width and its glyphs' height
## (the digits and "€" have no descenders, so this is far less than the label's line height),
## scaled by a punch about the digits' centre. Not the label's rect; not the count layout's
## shadow either.
func digits_text_rect() -> Rect2:
	var font: Font = _digits.get_theme_font("font")
	var font_size: int = _digits.get_theme_font_size("font_size")
	var width: float = _text_width(_digits)
	var ink: Vector2 = ink_span(_digits.text, font, font_size)
	# The label centres its line box: the baseline sits `ascent` below the box's top.
	var line_top: float = (_digits.size.y - font.get_height(font_size)) / 2.0
	var baseline: float = line_top + font.get_ascent(font_size)
	var left: float = (_digits.size.x - width) / 2.0
	if _digits.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		left = 0.0
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


## The glass inside the bezel (global). The count layout has no glass: there it is the LED's own
## rect.
func interior() -> Rect2:
	if _layout == Layout.COUNT:
		return get_global_rect()
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


## The quota line for the layout: "QUOTA €N" on the glass; in the count layout "€N", with the
## word right-aligned QUOTA_WORD_GAP left of it.
func _set_quota(quota: int) -> void:
	_quota = quota
	var count: bool = _layout == Layout.COUNT
	_quota_label.text = ("€%d" if count else QUOTA_WORD + " €%d") % quota
	var room: Rect2 = COUNT_QUOTA_RECT
	room.size.x -= _text_width(_quota_label) + QUOTA_WORD_GAP
	_rects[_quota_word] = room
	_quota_word.position = room.position
	_quota_word.size = room.size


func _set_amount(amount: int) -> void:
	_digits.text = "€%d" % amount
	_lit = lit_segments(amount, _quota)
	_beat.show_to_go(LedBeat.to_go_text(ShiftMargin.of(amount, _quota)))
	_fit_digits()
	queue_redraw()


## The digits in MET_COLOR when `met`, else in the layout's own colour (on the glass with its
## glow).
func _set_colour(met: bool) -> void:
	_met = met
	var colour: Color = COUNT_DIGITS_COLOR if _layout == Layout.COUNT else DIGITS_COLOR
	if met:
		colour = MET_COLOR
	_digits.add_theme_color_override("font_color", colour)
	_digits.add_theme_color_override("font_outline_color", Color(colour, GLOW_ALPHA))


## Sets the mode, clears the last beat, lays the LED out for the mode (COUNT for the count-up's
## SUBTOTAL and TOTAL) and says so.
func _set_mode(mode_set: Mode) -> void:
	_mode = mode_set
	_beat.clear_beat()
	var counting: bool = mode_set == Mode.SUBTOTAL or mode_set == Mode.TOTAL
	_use_layout(Layout.COUNT if counting else Layout.COMPACT)
	mode_changed.emit(_mode)


## Lays the LED out as `layout` (see the class comment): its size, the clip, its parts' rects,
## and the caption's, digits' and quota text's fonts and colours.
func _use_layout(layout_set: Layout) -> void:
	if layout_set == _layout:
		return
	_layout = layout_set
	var count: bool = layout_set == Layout.COUNT
	size = COUNT_SIZE if count else ShiftStage.LED_RECT.size
	clip_contents = not count
	_rects[_caption] = COUNT_CAPTION_RECT if count else CAPTION_RECT
	_rects[_digits] = COUNT_DIGITS_RECT if count else DIGITS_RECT
	_rects[_quota_label] = COUNT_QUOTA_RECT if count else QUOTA_RECT
	_segment_size = COUNT_SEGMENT_SIZE if count else SEGMENT_SIZE
	_bar_origin = COUNT_BAR_ORIGIN if count else BAR_ORIGIN
	_chip_rect = COUNT_QUOTA_RECT if count else CHIP_RECT
	var caption_size: int = COUNT_CAPTION_FONT_SIZE if count else CAPTION_FONT_SIZE
	_caption.add_theme_font_size_override("font_size", caption_size)
	_caption.add_theme_color_override("font_color", COUNT_TEXT_COLOR if count else CAPTION_COLOR)
	_quota_label.add_theme_color_override("font_color", COUNT_TEXT_COLOR if count else QUOTA_COLOR)
	_digits.add_theme_font_override("font", _count_font if count else ArtStyle.number_font())
	_digits.add_theme_font_size_override("font_size", DIGITS_FONT_SIZE)
	_digits.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if count else HORIZONTAL_ALIGNMENT_CENTER
	)
	_digits.add_theme_constant_override("outline_size", 0 if count else GLOW_SIZE)
	var shadow: Color = COUNT_SHADOW_COLOR if count else Color(COUNT_SHADOW_COLOR, 0.0)
	_digits.add_theme_color_override("font_shadow_color", shadow)
	_digits.add_theme_constant_override("shadow_offset_x", COUNT_SHADOW if count else 0)
	_digits.add_theme_constant_override("shadow_offset_y", COUNT_SHADOW if count else 0)
	_set_colour(_met)
	_beat.visible = count
	_quota_word.visible = count
	if not _quota_label.text.is_empty():
		_set_quota(_quota)
	_lay_out()
	queue_redraw()


## Each label at its rect for the layout, the digits fitted to it (_fit_digits).
func _lay_out() -> void:
	for label: Label in _rects:
		label.position = _rects[label].position
		label.size = _rects[label].size
	_fit_digits()


## The digits' line box is taller than their rect: it stays centred on the rect's height (the ink
## is far shorter than the line), and punches scale it about its centre. In the count layout the
## digits take the first of COUNT_DIGITS_SIZES whose text fits the rect's width, and their label
## is as wide as that text, at the rect's left; on the glass it spans the rect, text centred.
func _fit_digits() -> void:
	var room: Rect2 = _rects[_digits]
	var width: float = room.size.x
	if _layout == Layout.COUNT:
		for font_size: int in COUNT_DIGITS_SIZES:
			_digits.add_theme_font_size_override("font_size", font_size)
			if _text_width(_digits) <= room.size.x:
				break
		width = _text_width(_digits)
	_digits.position = room.position
	# A label never shrinks back by itself: set the size, then let its line box's height through.
	_digits.size = Vector2(width, room.size.y)
	_digits.size = Vector2(width, maxf(room.size.y, _digits.get_minimum_size().y))
	_digits.position.y = room.get_center().y - _digits.size.y / 2.0
	_digits.pivot_offset = _digits.size / 2.0


## The count layout's bar (_draw): an ink frame COUNT_BAR_BORDER wide round the segments, each lit
## one mustard with a COUNT_LIT_EDGE light top, the others plaster.
func _draw_count_bar() -> void:
	var first: Rect2 = segment_rect(0)
	var bar: Rect2 = Rect2(first.position, segment_rect(SEGMENTS - 1).end - first.position)
	draw_rect(bar.grow(COUNT_BAR_BORDER), Palette.INK)
	for index: int in range(SEGMENTS):
		var segment: Rect2 = segment_rect(index)
		if index >= _lit:
			draw_rect(segment, COUNT_UNLIT_COLOR)
			continue
		draw_rect(segment, COUNT_LIT_COLOR)
		var edge: Rect2 = Rect2(segment.position, Vector2(segment.size.x, COUNT_LIT_EDGE))
		draw_rect(edge, COUNT_LIT_EDGE_COLOR)


func _place(label: Label, rect: Rect2) -> void:
	_rects[label] = rect
	label.position = rect.position
	label.size = rect.size
	add_child(label)


## A label's text width, in its own font and size.
static func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
