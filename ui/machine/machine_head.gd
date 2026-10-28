class_name MachineHead
extends Control
## The machine's marquee (#77; redrawn front-on in v0.50, mock-up premium_machine_v1.html): the
## mustard sign over the cabinet with "RECEIPT REWARDS" (bold Atkinson 28, 2 px apart, a mustard
## light shadow) and "ONE PRIZE PER RECEIPT", ringed by BULBS dark bulbs. On a PREMIUM visit the
## same sign turns PREMIUM (MachineLook, dressing A): a white flash frame, then the dark night face
## with a brass ring and lit gold "PREMIUM REWARDS" over "RARE OR BETTER" (v0.61, #108: a PREMIUM
## visit is a rarity boost), its bulbs coming on
## in turn, then chasing (one in four dark) and a hard shine band crossing it every 2.4 s, for the
## whole visit. The chase and the shine run on view.idle_time (still under reduced motion).
##
## The visit's head stamp: BONUS TICKET! (-4°, with the inspection passed, or "shift n" for a
## bonus extra shift, under it), paper with a tomato-dark double border. A stamp covers the title.
## It blinks in and lands from twice its size at the visit's start (reduced motion: at rest), and
## lifts once the visit's landing is over (the punch's end + 0.6 s).

const SIZE := Vector2(488, 56)
const TITLE := "RECEIPT REWARDS"
const SUB_LINE := "ONE PRIZE PER RECEIPT"
const PREMIUM_TITLE := "PREMIUM REWARDS"
const PREMIUM_SUB := "RARE OR BETTER"
const TITLE_SIZE := 28
const TITLE_SPACING := 2
const SUB_SIZE := 11
const TITLE_RECT := Rect2(8, 6, 472, 34)
const SUB_RECT := Rect2(8, 36, 472, 16)
const BOLD_WEIGHT := 800
const SUB_WEIGHT := 750
## The bulbs: BULBS_ALONG on the top and bottom rows, BULBS_SIDE on each side.
const BULBS_ALONG := 24
const BULBS_SIDE := 3
const STAMP_TEXT_SIZE := 24
const UNDER_SIZE := 10
## The stamp: its double border (2 px line, 2 px paper, 2 px line), its side padding, the line
## heights inside it, its top and its tilt (degrees) per stamp.
const STAMP_RIM := 6.0
const STAMP_PAD := 10.0
const STAMP_LINE := 26.0
const UNDER_LINE := 12.0
const STAMP_TOP := 2.0
const BONUS_TILT := -4.0
const BONUS_TEXT := "BONUS TICKET!"
## Look F's stamp motion: it lands from STAMP_FROM x its size in MachineTuning.head_stamp_land_ms,
## blinks (on every other tenth of a second) for head_stamp_blink_ms, and lifts
## head_stamp_lift_ms after the punch's end.
const STAMP_FROM := 2.0
## A BONUS visit's stamp lands from this (machine v2), on a back ease (overshoot BACK_C).
const BONUS_STAMP_FROM := 2.2
const BACK_C := 1.7
const BLINK_RATE := 10.0
const FLASH_ALPHA := 0.85

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _title: Label
var _sub: Label
var _stamp: Control
var _stamp_label: Label
var _under: Label
var _stamp_text: String = ""
var _under_text: String = ""
var _look: MachineLook = MachineLook.new()
var _chase: float = 0.0
var _night: bool = false


func _init() -> void:
	name = "MachineHead"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_title = UiKit.body_label(TITLE, TITLE_SIZE, Palette.INK)
	_title.name = "Title"
	_title.add_theme_font_override(
		"font", MachineArt.spaced(ArtStyle.bold_font(BOLD_WEIGHT), TITLE_SPACING)
	)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.add_theme_constant_override("shadow_outline_size", 0)
	_place(_title, TITLE_RECT, self)
	_sub = UiKit.body_label(SUB_LINE, SUB_SIZE, Palette.MUSTARD_DARKEST)
	_sub.name = "SubLine"
	_sub.add_theme_font_override("font", ArtStyle.bold_font(SUB_WEIGHT))
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
	_show_face(false)
	set_stamp("", "")


## The head stamp ("BONUS TICKET!", or "" for none) and the line under it.
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
	_stamp.rotation_degrees = BONUS_TILT
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


## Whether the sign shows its PREMIUM night face.
func premium_face() -> bool:
	return _night


## Where bulb `index` (0 .. bulb_count() - 1, round the sign from the top left) sits (local px,
## its centre pixel's top-left), as the mock-up rings them.
static func bulb_point(index: int) -> Vector2:
	var step: float = (SIZE.x / 2.0 - 8.0) / (BULBS_ALONG - 1)
	if index < BULBS_ALONG:
		return MachineArt.snap_point(Vector2((4.0 + index * step) * 2.0, -8.0))
	index -= BULBS_ALONG
	if index < BULBS_SIDE:
		return MachineArt.snap_point(Vector2(SIZE.x + 4.0, (-4.0 + (index + 1) * 8.5) * 2.0))
	index -= BULBS_SIDE
	if index < BULBS_ALONG:
		var along: int = BULBS_ALONG - 1 - index
		return MachineArt.snap_point(Vector2((4.0 + along * step) * 2.0, SIZE.y + 2.0))
	index -= BULBS_ALONG
	return MachineArt.snap_point(Vector2(-8.0, (-4.0 + (BULBS_SIDE - index) * 8.5) * 2.0))


static func bulb_count() -> int:
	return 2 * (BULBS_ALONG + BULBS_SIDE)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The sign at time `t` (seconds) of view.plan: its face and bulbs (MachineLook), and the stamp,
## blinking in and landing from twice its size at the visit's start (reduced motion: at rest at
## once), lifted once the landing is over.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	_look = MachineLook.at(plan, t)
	_chase = view.idle_time if view != null else 0.0
	_show_face(_look.night_face())
	queue_redraw()
	_frame_stamp(plan, t)


func _frame_stamp(plan: MachinePlan, t: float) -> void:
	if _stamp_text.is_empty():
		_show_stamp(false, 1.0)
		return
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


## When the stamp lifts: head_stamp_lift_ms after the punch's end.
static func lift_time(plan: MachinePlan) -> float:
	return plan.punch_end + MachineTuning.sec(plan.tuning.head_stamp_lift_ms)


## The sign's texts and colours: the classic face, or the night face (`night`).
func _show_face(night: bool) -> void:
	_night = night
	_title.text = PREMIUM_TITLE if night else TITLE
	_sub.text = PREMIUM_SUB if night else SUB_LINE
	_title.add_theme_color_override("font_color", Palette.GOLD if night else Palette.INK)
	_title.add_theme_color_override(
		"font_shadow_color", Palette.BRASS_DARK if night else Palette.MUSTARD_LIGHT
	)
	_sub.add_theme_color_override(
		"font_color", Palette.MUSTARD_LIGHT if night else Palette.MUSTARD_DARKEST
	)
	_sub.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT if night else SUB_WEIGHT))


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
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	if _night:
		MachineArt.bevel(
			self, rect, Palette.CHARCOAL, Palette.STEEL_DARKEST, Palette.INK, Palette.BRASS_DARKEST
		)
		MachineArt.ring(self, rect.grow(-4.0), Palette.BRASS)
		MachineArt.shine(self, rect.grow(-2.0), _look.sign_shine(_chase), Palette.MUSTARD_PALE, 3.0)
	else:
		MachineArt.bevel(self, rect, Palette.MUSTARD, Palette.MUSTARD_LIGHT, Palette.MUSTARD_DARK)
	if _look.flash():
		draw_rect(rect, Color(Palette.PAPER, FLASH_ALPHA))
	var premium: bool = _look.premium()
	for index: int in range(bulb_count()):
		var at: Vector2 = bulb_point(index)
		var lit: bool = _look.bulb_lit(index, _chase)
		var bulb: Rect2 = Rect2(at - Vector2(2, 2), Vector2(6, 6))
		draw_rect(bulb, Palette.GOLD if lit else Palette.INK)
		var core: Color = Palette.BRASS_DARK if premium else Palette.MUSTARD_DARKEST
		draw_rect(Rect2(at, Vector2(2, 2)), Palette.PAPER if lit else core)


## The stamp: paper with a tomato-dark double border (2 px line, 2 px paper, 2 px line).
func _draw_stamp() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _stamp.size)
	_stamp.draw_rect(rect, Palette.PAPER)
	_stamp.draw_rect(rect.grow(-1.0), Palette.TOMATO_DARK, false, 2.0)
	_stamp.draw_rect(rect.grow(-5.0), Palette.TOMATO_DARK, false, 2.0)
