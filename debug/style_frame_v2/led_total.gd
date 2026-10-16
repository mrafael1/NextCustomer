class_name LedTotal
extends Control
## The register's LED panel in style frame v2 (#75, spec section 3.1): a brass-bezelled panel of
## dark glass showing the projected total (planning) or the running subtotal (the count-up) in
## gold digits with a glow, framed against the shift's quota: the quota line and a 10-segment
## bar lit in proportion to the shown amount (a framing aid for the fb-p2 finding that players
## thought a lower total wins). The amount is the caller's (a ScoreResult's total or a step's
## subtotal); the panel never scores.

const SIZE := Vector2(288, 100)
const FRAME_MARGIN := 4
const CAPTION_RECT := Rect2(12, 6, 160, 14)
const DIGITS_RECT := Rect2(12, 18, 264, 52)
const QUOTA_RECT := Rect2(12, 74, 140, 18)
const BAR_ORIGIN := Vector2(156, 76)
const SEGMENTS := 10
const SEGMENT_SIZE := Vector2(10, 12)
const SEGMENT_GAP := 2.0
const CAPTION_SIZE := 12
const DIGITS_SIZE := 48
const QUOTA_SIZE := 14
const GLOW_SIZE := 6
const GLOW_ALPHA := 0.35

const FRAME := preload("res://art/frames/led_panel.png")

var _caption: Label
var _digits: Label
var _quota: Label
var _lit: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	ArtStyle.use_pixel_material(self)
	_caption = UiKit.display_label("", CAPTION_SIZE, false)
	_caption.add_theme_color_override("font_color", StyleFrameV2.BRASS)
	_place(_caption, CAPTION_RECT)
	_digits = UiKit.number_label("", DIGITS_SIZE, false)
	_digits.add_theme_color_override("font_color", StyleFrameV2.GOLD)
	_digits.add_theme_constant_override("outline_size", GLOW_SIZE)
	_digits.add_theme_color_override("font_outline_color", Color(StyleFrameV2.GOLD, GLOW_ALPHA))
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_digits, DIGITS_RECT)
	_quota = UiKit.number_label("", QUOTA_SIZE, false)
	_quota.add_theme_color_override("font_color", StyleFrameV2.BRASS)
	_quota.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_quota, QUOTA_RECT)


func _draw() -> void:
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), Rect2(Vector2.ZERO, size))
	for index: int in range(SEGMENTS):
		var x: float = BAR_ORIGIN.x + index * (SEGMENT_SIZE.x + SEGMENT_GAP)
		var color: Color = StyleFrameV2.GOLD if index < _lit else StyleFrameV2.VELVET_DARK
		draw_rect(Rect2(Vector2(x, BAR_ORIGIN.y), SEGMENT_SIZE), color)


## Shows `amount` under `caption` ("PROJECTED" or "SUBTOTAL") against the shift's `quota`.
func show_amount(caption: String, amount: int, quota: int) -> void:
	_caption.text = caption
	_digits.text = "€%d" % amount
	_quota.text = "QUOTA €%d" % quota
	_lit = lit_segments(amount, quota)
	queue_redraw()


func digits_label() -> Label:
	return _digits


func caption_label() -> Label:
	return _caption


func quota_label() -> Label:
	return _quota


## Segments lit now.
func lit() -> int:
	return _lit


## The bar's lit segments for `amount` against `quota`: floor(10 x min(1, amount / quota)).
static func lit_segments(amount: int, quota: int) -> int:
	if quota <= 0:
		return SEGMENTS
	return floori(SEGMENTS * minf(1.0, float(maxi(amount, 0)) / quota))


func _place(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size
	add_child(label)
