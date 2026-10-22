class_name LedDisplay
extends Control
## The register's LED (#55, from style frame v2's LedTotal): one set of digits for both totals,
## under a caption that says which one shows: PROJECTED (the preview's total; the shift screen no
## longer shows it since the user's play test of 2026-10-17: planning is blank, under the
## monitor's store channel, MonitorChannel), SUBTOTAL from the checkout (the count-up's running
## subtotal) and TOTAL once the verdict is shown (also on a resumed checkout); blank in planning
## and the impulse rack. On the glass, with the digits, the quota line ("SPEND €N+", #86: players
## read the quota as an amount to spend) and a 10-segment bar of the shown amount, so the quota
## never shows by colour alone (the fb-p2 finding that players thought a lower total wins); the
## projected total is green once it reaches the quota. Display only: the amounts are the caller's
## (a ScoreResult's total or a step's subtotal), and nothing here scores.
##
## It sits on the hung monitor (#80, MonitorView), which places it, in one of two layouts that
## follow its mode. The compact one (Layout.COMPACT: CAPTION_RECT, DIGITS_RECT and QUOTA_RECT) is
## planning's and the impulse rack's: a brass-bezelled panel of dark glass that clips its
## contents, with the caption, mustard digits and the quota line. The count-up's (Layout.COUNT,
## for SUBTOTAL and TOTAL; the COUNT_ constants) is the number column of #86 v6's scan count-up
## (mock-up count_up_86_v6_scan.html), straight on the monitor's paper between the scanner bay and
## the € tank: the digits alone (no €: the tank is the €), big and gold with an ink outline over a
## mustard-dark shadow, the same gold met or not (the stamp, the sunburst and the tank say met),
## and under them the line saying how far the quota is (beat(), LedBeat: "€N to go" from core's
## ShiftMargin of the shown amount), which the SPEND MET stamp replaces at the quota. The caption
## and the quota line keep their text there but are hidden. The digits take the first of
## COUNT_DIGITS_SIZES that keeps their text inside COUNT_DIGITS_RECT's width; their label is as
## wide as their text, centred in the rect, so a punch about its centre (and the dessert's slam)
## stays on them. Nothing clips there: a punch may spill onto the paper.

## Emitted whenever the mode is set (show_projected, start_count, show_total, clear), even to the
## same mode, once the layout follows it: the monitor places the LED for it.
signal mode_changed(mode: Mode)
## Each amount shown with its quota (start_count: 0) and whether the quota is met (the count-up's
## ding, or the projected total reaching it), for the top bar's QuotaMeter and the € tank.
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
## The count-up's layout (Layout.COUNT, #86 v6), in the LED's own coordinates: its size, the
## digits' room (the whole box) and, under it, the to-go line's (LedBeat, with the SPEND MET stamp
## over it). The longest digits at the count-up's largest punch stay on the monitor's paper.
const COUNT_SIZE := Vector2(160, 86)
const COUNT_DIGITS_RECT := Rect2(0, 0, 160, 86)
const COUNT_TO_GO_RECT := Rect2(0, 92, 160, 24)
const CAPTION_FONT_SIZE := 12
const DIGITS_FONT_SIZE := 48
## The count's digits, largest first (the mock-up's 80 px): the first whose text fits
## COUNT_DIGITS_RECT's width. Every total up to 999 and the simulator's largest (1118, its narrow
## 1s) show at the largest; wider four-digit totals (1000, 9999) take a smaller size. Their glyphs
## run COUNT_DIGITS_SPACING px tighter, with an ink outline COUNT_OUTLINE px wide, over a shadow
## COUNT_SHADOW px down and right that carries the outline too (shadow_outline_size), so it lies
## under the whole outlined glyph.
const COUNT_DIGITS_SIZES: Array[int] = [80, 72, 64, 56]
const COUNT_DIGITS_SPACING := -2
const COUNT_OUTLINE := 2
const COUNT_SHADOW := 5
const QUOTA_FONT_SIZE := 14
## The quota's player-facing word and amount (#86: "SPEND €73+"); code and data keep "quota".
const QUOTA_WORD := "SPEND"
const QUOTA_AMOUNT := "€%d+"
## The digits' glow on the glass: an outline of their own colour at GLOW_ALPHA.
const GLOW_SIZE := 6
const GLOW_ALPHA := 0.35
const CAPTION_COLOR := Palette.BRASS
const QUOTA_COLOR := Palette.BRASS
## The digits' colour on the glass, and theirs once the projected total reaches the quota.
const DIGITS_COLOR := Palette.MUSTARD
const MET_COLOR := Palette.GOOD
const LIT_COLOR := Palette.GOLD
const UNLIT_COLOR := Palette.VELVET_DARK
## The count layout on the paper: gold digits (the mock-up's #ffcf3f is the palette's gold) with
## an ink outline over a mustard-dark shadow.
const COUNT_DIGITS_COLOR := Palette.GOLD
const COUNT_OUTLINE_COLOR := Palette.INK
const COUNT_SHADOW_COLOR := Palette.MUSTARD_DARK

const FRAME := preload("res://art/frames/led_panel.png")

var _mode: Mode = Mode.BLANK
var _layout: Layout = Layout.COMPACT
var _quota: int = 0
var _lit: int = 0
## The quota is met (the count-up's ding, or the projected total reaching it).
var _met: bool = false
var _caption: Label
var _digits: Label
var _quota_label: Label
## The count layout's digits font: the number font, its glyphs COUNT_DIGITS_SPACING tighter.
var _count_font: FontVariation
## The count layout's to-go line and SPEND MET stamp (hidden in the compact one).
var _beat: LedBeat
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
	_count_font = ArtStyle.number_font().duplicate() as FontVariation
	_count_font.spacing_glyph = COUNT_DIGITS_SPACING
	_beat = LedBeat.new()
	_beat.position = COUNT_TO_GO_RECT.position
	_beat.size = COUNT_TO_GO_RECT.size
	_beat.visible = false
	add_child(_beat)
	reset_colour()


func _ready() -> void:
	_lay_out()


func _draw() -> void:
	if _layout == Layout.COUNT:
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


## A count-up starts against `quota`: the SUBTOTAL caption (hidden in the count layout), the
## stamp off. The amounts follow through show_subtotal().
func start_count(quota: int) -> void:
	_caption.text = SUBTOTAL_TEXT
	_set_quota(quota)
	_set_mode(Mode.SUBTOTAL)
	reset_colour()
	_beat.clear_beat()
	reading_changed.emit(0, quota, false)


## The running subtotal (`met`: the count-up has met the quota; the digits stay gold, the reading
## says so). The caption stays as it is (SUBTOTAL, or TOTAL once the verdict is shown).
func show_subtotal(amount: int, met: bool) -> void:
	_set_colour(met)
	_set_amount(amount)
	reading_changed.emit(amount, _quota, met)


## The verdict is shown: the caption says TOTAL over the amount already shown (the count layout
## stays as it is).
func show_total() -> void:
	_caption.text = TOTAL_TEXT
	_set_mode(Mode.TOTAL)


## The digits' own colour (the quota not met): DIGITS_COLOR on the glass, COUNT_DIGITS_COLOR in
## the count layout (always gold there).
func reset_colour() -> void:
	_set_colour(false)


## Blank: no caption, digits, quota line or lit segments (the impulse rack).
func clear() -> void:
	_caption.text = ""
	_digits.text = ""
	_quota_label.text = ""
	_lit = 0
	_beat.clear_beat()
	_set_mode(Mode.BLANK)
	reset_colour()
	queue_redraw()


func mode() -> Mode:
	return _mode


## The layout now (it follows the mode).
func layout() -> Layout:
	return _layout


func caption_label() -> Label:
	return _caption


## The digits (their pivot at their centre, for the count-up's punches).
func digits_label() -> Label:
	return _digits


## The quota line: "SPEND €N+" (hidden in the count layout).
func quota_label() -> Label:
	return _quota_label


## The count layout's to-go line and its SPEND MET stamp.
func beat() -> LedBeat:
	return _beat


## Segments lit now.
func lit() -> int:
	return _lit


## Segment `index`'s rect on the glass (the compact layout's bar), in the LED's coordinates.
func segment_rect(index: int) -> Rect2:
	return Rect2(BAR_ORIGIN + Vector2(index * (SEGMENT_SIZE.x + SEGMENT_GAP), 0), SEGMENT_SIZE)


## The digits' ink as drawn now (global): the text's measured width and its glyphs' height
## (the digits and "€" have no descenders, so this is far less than the label's line height),
## scaled by a punch about the digits' centre. Not the label's rect; not the count layout's
## outline or shadow either.
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


## The quota line, "SPEND €N+" (shown on the glass only).
func _set_quota(quota: int) -> void:
	_quota = quota
	_quota_label.text = (QUOTA_WORD + " " + QUOTA_AMOUNT) % quota


## The digits: "€N" on the glass, the bare number in the count layout (the tank is the €).
func _set_amount(amount: int) -> void:
	_digits.text = ("%d" if _layout == Layout.COUNT else "€%d") % amount
	_lit = lit_segments(amount, _quota)
	_beat.show_to_go(ShiftMargin.of(amount, _quota), _quota)
	_fit_digits()
	queue_redraw()


## The digits' colour: on the glass MET_COLOR when `met`, else DIGITS_COLOR (with its glow); in
## the count layout always COUNT_DIGITS_COLOR over its ink outline.
func _set_colour(met: bool) -> void:
	_met = met
	_beat.set_met(met)
	if _layout == Layout.COUNT:
		_digits.add_theme_color_override("font_color", COUNT_DIGITS_COLOR)
		_digits.add_theme_color_override("font_outline_color", COUNT_OUTLINE_COLOR)
		return
	var colour: Color = MET_COLOR if met else DIGITS_COLOR
	_digits.add_theme_color_override("font_color", colour)
	_digits.add_theme_color_override("font_outline_color", Color(colour, GLOW_ALPHA))


## Sets the mode, lays the LED out for the mode (COUNT for the count-up's SUBTOTAL and TOTAL) and
## says so.
func _set_mode(mode_set: Mode) -> void:
	_mode = mode_set
	var counting: bool = mode_set == Mode.SUBTOTAL or mode_set == Mode.TOTAL
	_use_layout(Layout.COUNT if counting else Layout.COMPACT)
	mode_changed.emit(_mode)


## Lays the LED out as `layout` (see the class comment): its size, the clip, the parts shown,
## and the digits' font, outline and shadow.
func _use_layout(layout_set: Layout) -> void:
	if layout_set == _layout:
		return
	_layout = layout_set
	var count: bool = layout_set == Layout.COUNT
	size = COUNT_SIZE if count else ShiftStage.LED_RECT.size
	clip_contents = not count
	_rects[_digits] = COUNT_DIGITS_RECT if count else DIGITS_RECT
	_caption.visible = not count
	_quota_label.visible = not count
	_digits.add_theme_font_override("font", _count_font if count else ArtStyle.number_font())
	_digits.add_theme_font_size_override("font_size", DIGITS_FONT_SIZE)
	_digits.add_theme_constant_override("outline_size", COUNT_OUTLINE if count else GLOW_SIZE)
	_digits.add_theme_constant_override("shadow_outline_size", COUNT_OUTLINE if count else 0)
	var shadow: Color = COUNT_SHADOW_COLOR if count else Color(COUNT_SHADOW_COLOR, 0.0)
	_digits.add_theme_color_override("font_shadow_color", shadow)
	_digits.add_theme_constant_override("shadow_offset_x", COUNT_SHADOW if count else 0)
	_digits.add_theme_constant_override("shadow_offset_y", COUNT_SHADOW if count else 0)
	_set_colour(_met)
	_beat.visible = count
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
## is as wide as that text, centred in the rect (on whole pixels); on the glass it spans the rect,
## text centred.
func _fit_digits() -> void:
	var room: Rect2 = _rects[_digits]
	var width: float = room.size.x
	if _layout == Layout.COUNT:
		for font_size: int in COUNT_DIGITS_SIZES:
			_digits.add_theme_font_size_override("font_size", font_size)
			if _text_width(_digits) <= room.size.x:
				break
		width = _text_width(_digits)
	_digits.position = Vector2(roundf(room.get_center().x - width / 2.0), room.position.y)
	# A label never shrinks back by itself: set the size, then let its line box's height through.
	_digits.size = Vector2(width, room.size.y)
	_digits.size = Vector2(width, maxf(room.size.y, _digits.get_minimum_size().y))
	_digits.position.y = room.get_center().y - _digits.size.y / 2.0
	_digits.pivot_offset = _digits.size / 2.0


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
