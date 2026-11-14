class_name WelcomeSlip
extends Control
## The WELCOME BACK slip (mock-up options_pause.html, direction A): a strip of receipt paper under
## the top bar when a saved run resumes ("WELCOME BACK · SHIFT 4/16, AS YOU LEFT IT"), for
## SHOW_TIME seconds; still under reduced motion. Never on a run's first start. Its words are hard
## pixel capitals (MachineLine, 2x; the shift's numbers in the chunky digits) since polish batch 2,
## its width following them. A run resumed at the machine (MACHINE_TOP, polish batch 2) shows it
## low over the cabinet's kick panel instead, so the marquee and its stamp stay in view.

const SHOW_TIME := 1.8
const HEIGHT := 44.0
const TOP := 70.0
## Its top when the run resumes at the RECEIPT REWARDS machine: over the cabinet's kick panel, under
## the keys, the tray and the prize bay (1280x720 canvas px).
const MACHINE_TOP := 648.0
const HEAD_TEXT := "WELCOME BACK"
const BODY_TEXT := "%s, AS YOU LEFT IT"
## The paper's padding each side, the gap between the two words' runs and the words' cap top.
const PAD := 16.0
const WORD_GAP := 14.0
const CAP_TOP := 16.0
const RECEIPT_FRAME := preload("res://art/frames/receipt_paper.png")

var _paper: PanelContainer
var _head: MachineLine
var _body: MachineLine


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper = UiKit.frame_panel(RECEIPT_FRAME, 2)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_head = MachineLine.make("Head", HEAD_TEXT, Palette.GREEN_DARK)
	_head.position = Vector2(PAD, CAP_TOP)
	add_child(_head)
	_body = MachineLine.make("Body", "", Palette.INK)
	add_child(_body)
	visible = false


## Shows the slip for `shift_line` ("Shift 4/16") centred on `centre_x` with its top at `top`, then
## hides it.
func show_for(shift_line: String, centre_x: float, top: float = TOP) -> void:
	_body.show_text(BODY_TEXT % shift_line.to_upper(), Palette.INK)
	_body.position = Vector2(PAD + _head.width() + WORD_GAP, CAP_TOP)
	size = Vector2(2.0 * ceilf((_body.position.x + _body.width() + PAD) / 2.0), HEIGHT)
	_paper.size = size
	position = Vector2(2.0 * roundf((centre_x - size.x / 2.0) / 2.0), top)
	visible = true
	var timer: Tween = create_tween()
	timer.tween_interval(SHOW_TIME)
	timer.tween_callback(func() -> void: visible = false)


## The slip's words: WELCOME BACK and the shift's line, for tests.
func lines() -> Array[MachineLine]:
	return [_head, _body]
