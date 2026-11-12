class_name WelcomeSlip
extends Control
## The WELCOME BACK slip (mock-up options_pause.html, direction A): a strip of receipt paper under
## the top bar when a saved run resumes ("WELCOME BACK · Shift 4/16, as you left it"), for
## SHOW_TIME seconds; still under reduced motion. Never on a run's first start.

const SHOW_TIME := 1.8
const SIZE := Vector2(420, 44)
const TOP := 70.0
const BODY_FONT := 14
const RECEIPT_FRAME := preload("res://art/frames/receipt_paper.png")

var _paper: PanelContainer
var _body: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_paper = UiKit.frame_panel(RECEIPT_FRAME, 2)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.size = SIZE
	add_child(_paper)
	var head: Label = UiKit.pixel_label("WELCOME BACK", 2, Palette.GREEN_DARK)
	UiKit.place_pixel_label(head, Rect2(16, 14, 0, 0))
	add_child(head)
	_body = UiKit.body_label("", BODY_FONT, Palette.INK)
	_body.position = Vector2(30 + OptionChip.pixel_width("WELCOME BACK", 2), 12)
	add_child(_body)
	visible = false


## Shows the slip for `shift_line` ("Shift 4/16") centred over the store, then hides it.
func show_for(shift_line: String, centre_x: float) -> void:
	_body.text = "%s, as you left it" % shift_line
	_body.add_theme_font_size_override("font_size", UiKit.text_size(BODY_FONT))
	position = Vector2(2.0 * roundf((centre_x - SIZE.x / 2.0) / 2.0), TOP)
	visible = true
	var timer: Tween = create_tween()
	timer.tween_interval(SHOW_TIME)
	timer.tween_callback(func() -> void: visible = false)
