class_name MachineHead
extends Control
## The RECEIPT REWARDS machine's head plate (#77, look F; build spec 4.2): the mustard plate with
## "RECEIPT REWARDS" (Pixelify 24) and the look's sub line (bold Atkinson 10 caps), over a 4 px
## shadow, and the visit's head stamp: BONUS TICKET! (-4°, with the inspection passed, or
## "shift n" for a bonus extra shift, under it) or STAMP DAY! (-5°), paper with a tomato-dark
## double border. A stamp covers the title (no stray title letters around it). It blinks in and
## lands from twice its size at the visit's start (reduced motion: at rest), and lifts once the
## visit's landing is over (look F's head: the BONUS stamp until the punch's end + 0.6 s, the
## STAMP DAY stamp until its landing + 0.6 s).

const SIZE := Vector2(440, 54)
const TITLE := "RECEIPT REWARDS"
const SUB_LINE := "RESTOCK HATCH"
const TITLE_SIZE := 24
const SUB_SIZE := 10
const STAMP_TEXT_SIZE := 24
const UNDER_SIZE := 10
const TITLE_RECT := Rect2(0, 4, 440, 28)
const SUB_RECT := Rect2(0, 34, 440, 14)
const SHADOW := 4.0
const BORDER := 2.0
const BOLD_WEIGHT := 800
## The stamp: its double border (2 px line, 2 px paper, 2 px line), its side padding, the line
## heights inside it, its top and its tilt (degrees) per stamp.
const STAMP_RIM := 6.0
const STAMP_PAD := 10.0
const STAMP_LINE := 26.0
const UNDER_LINE := 12.0
const STAMP_TOP := 2.0
const BONUS_TILT := -4.0
const STAMP_DAY_TILT := -5.0
const BONUS_TEXT := "BONUS TICKET!"
## Look F's stamp motion: it lands from STAMP_FROM x its size in MachineTuning.head_stamp_land_ms,
## blinks (on every other tenth of a second) for head_stamp_blink_ms, and lifts
## head_stamp_lift_ms after the punch's end (STAMP DAY: its landing).
const STAMP_FROM := 2.0
## A BONUS visit's stamp lands from this (machine v2), on a back ease (overshoot BACK_C).
const BONUS_STAMP_FROM := 2.2
const BACK_C := 1.7
const BLINK_RATE := 10.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _title: Label
var _sub: Label
var _stamp: Control
var _stamp_label: Label
var _under: Label
var _stamp_text: String = ""
var _under_text: String = ""


func _init() -> void:
	name = "MachineHead"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_title = UiKit.display_label(TITLE, TITLE_SIZE, false)
	_title.name = "Title"
	_place(_title, TITLE_RECT, self)
	_sub = UiKit.body_label(SUB_LINE, SUB_SIZE, Palette.MUSTARD_DARKEST)
	_sub.name = "SubLine"
	_sub.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	_place(_sub, SUB_RECT, self)
	_stamp = Control.new()
	_stamp.name = "HeadStamp"
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.draw.connect(_draw_stamp)
	add_child(_stamp)
	_stamp_label = UiKit.display_label("", STAMP_TEXT_SIZE, false)
	_stamp_label.name = "StampText"
	_stamp_label.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	_stamp.add_child(_stamp_label)
	_under = UiKit.body_label("", UNDER_SIZE, Palette.INK_LIGHT)
	_under.name = "StampUnder"
	_under.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	_stamp.add_child(_under)
	set_stamp("", "")


## The head stamp ("BONUS TICKET!", "STAMP DAY!", or "" for none) and the line under it.
func set_stamp(text: String, under: String) -> void:
	_stamp_text = text
	_under_text = under
	_stamp_label.text = text
	_under.text = under
	_under.visible = not under.is_empty()
	var font: Font = ArtStyle.DISPLAY_FONT
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_TEXT_SIZE).x
	var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var under_width: float = (
		bold.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, UNDER_SIZE).x
	)
	var inner: float = ceilf(maxf(width, under_width) / 2.0) * 2.0
	var stamp_size: Vector2 = Vector2(
		inner + 2.0 * (STAMP_PAD + STAMP_RIM),
		STAMP_LINE + 2.0 * STAMP_RIM + (UNDER_LINE if _under.visible else 0.0)
	)
	_stamp.size = stamp_size
	_stamp.position = Vector2(roundf((SIZE.x - stamp_size.x) / 4.0) * 2.0, STAMP_TOP)
	_stamp.pivot_offset = stamp_size / 2.0
	_stamp.rotation_degrees = BONUS_TILT if text == BONUS_TEXT else STAMP_DAY_TILT
	RewardMachineView.fit(
		_stamp_label,
		Rect2(Vector2(STAMP_RIM, STAMP_RIM), Vector2(stamp_size.x - 2.0 * STAMP_RIM, STAMP_LINE))
	)
	_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(
		_under,
		Rect2(
			Vector2(STAMP_RIM, STAMP_RIM + STAMP_LINE - 2.0),
			Vector2(stamp_size.x - 2.0 * STAMP_RIM, UNDER_LINE)
		)
	)
	_under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_show_stamp(not text.is_empty(), 1.0)
	_stamp.queue_redraw()


## The head stamp's text ("" for none) and the line under it, for tests (the stamp set, even
## while it blinks).
func stamp_texts() -> PackedStringArray:
	return PackedStringArray([_stamp_text, _under_text if not _stamp_text.is_empty() else ""])


## Whether the stamp shows now (frame(t): blinking in, at rest, or lifted).
func stamp_shown() -> bool:
	return _stamp.visible


## The stamp's current scale (2 as it starts landing, 1 at rest).
func stamp_scale() -> float:
	return _stamp.scale.x


## The title and the sub line's labels, for layout tests.
func title_labels() -> Array[Label]:
	return [_title, _sub]


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Shows the stamp at time `t` (seconds) of view.plan: blinking in and landing from twice its
## size at the visit's start (reduced motion: at rest at once), lifted once the landing is over.
func frame(t: float) -> void:
	if _stamp_text.is_empty():
		_show_stamp(false, 1.0)
		return
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		_show_stamp(true, 1.0)
		return
	var blink_on: bool = true
	var landing: float = 1.0
	var land_time: float = MachineTuning.sec(plan.tuning.head_stamp_land_ms)
	var since: float = t
	if plan.kind == MachineVisit.Kind.BONUS:
		# Machine v2: the BONUS stamp lands once the ticket is over the slot, from 2.2x, backed.
		since = t - plan.fly_end
		if since < 0.0:
			_show_stamp(false, 1.0)
			return
		land_time = MachineTuning.sec(plan.tuning.bonus_stamp_land_ms)
	if not plan.reduced_motion and since < MachineTuning.sec(plan.tuning.head_stamp_blink_ms):
		blink_on = int(floorf(since * BLINK_RATE)) % 2 == 0
	if not plan.reduced_motion and since < land_time and land_time > 0.0:
		var p: float = clampf(since / land_time, 0.0, 1.0)
		if plan.kind == MachineVisit.Kind.BONUS:
			landing = lerpf(BONUS_STAMP_FROM, 1.0, back_ease(p))
		else:
			landing = lerpf(STAMP_FROM, 1.0, 1.0 - (1.0 - p) * (1.0 - p))
	if plan.has_landing and t >= lift_time(plan):
		_show_stamp(false, 1.0)
		return
	_show_stamp(true, landing, blink_on)


## The approved page's back ease (backE): 0 at 0, overshooting past 1, 1 at 1.
static func back_ease(p: float) -> float:
	return 1.0 + (BACK_C + 1.0) * pow(p - 1.0, 3.0) + BACK_C * pow(p - 1.0, 2.0)


## When the stamp lifts: head_stamp_lift_ms after the punch's end (STAMP DAY: its landing).
static func lift_time(plan: MachinePlan) -> float:
	var lift: float = MachineTuning.sec(plan.tuning.head_stamp_lift_ms)
	if plan.kind == MachineVisit.Kind.STAMP_DAY:
		return plan.land + lift
	return plan.punch_end + lift


## Sets the stamp (`stamped`) at `stamp_scale_now`, shown on the blink's on frames; while it is
## set the title and sub line stay hidden, between the blinks too.
func _show_stamp(stamped: bool, stamp_scale_now: float, blink_on: bool = true) -> void:
	_stamp.visible = stamped and blink_on
	_stamp.scale = Vector2.ONE * stamp_scale_now
	_title.visible = not stamped
	_sub.visible = not stamped


func _place(label: Label, rect: Rect2, parent: Control) -> void:
	RewardMachineView.fit(label, rect)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	parent.add_child(label)


func _draw() -> void:
	draw_rect(Rect2(Vector2(0, SHADOW), SIZE), Palette.TEAL_BLACK)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.MUSTARD)
	draw_rect(Rect2(Vector2.ONE, SIZE - Vector2.ONE * BORDER), Palette.INK, false, BORDER)


## The stamp: paper with a tomato-dark double border (2 px line, 2 px paper, 2 px line).
func _draw_stamp() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _stamp.size)
	_stamp.draw_rect(rect, Palette.PAPER)
	_stamp.draw_rect(rect.grow(-1.0), Palette.TOMATO_DARK, false, 2.0)
	_stamp.draw_rect(rect.grow(-5.0), Palette.TOMATO_DARK, false, 2.0)
