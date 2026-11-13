class_name MachineHead
extends Control
## The machine's marquee (#77; redrawn front-on in v0.50; the steel-and-brass relook in v0.98,
## mock-up docs/art/mockups/machine_relook.html V2; v0.98 one marquee over both of V3's modules,
## machine_relook_v2.html): an engraved brass plate over the cabinet,
## like the gauge's € plate (an ink outline, a mustard light top row, brass dark at its foot and
## right, a gold rivet in each corner), with "RECEIPT REWARDS" in hard pixel lettering at 4x,
## engraved (brass darkest letters over a mustard light row one art px under them), over "KEEP 1
## PRIZE PER DRAW" at 2x (2026-11-06: "PER RECEIPT" until a medal's extra draw lit 2 lamps; v1.36:
## "ONE PRIZE" beside the bay's "3 sealed prizes drop here" read as a contradiction), and
## a row of BULBS_ALONG dark bulbs along its top and its foot. On a
## PREMIUM visit the same sign turns PREMIUM (MachineLook, dressing A): a white flash frame, then
## the night face (ink, a brass dark ring, charcoal) with gold "PREMIUM REWARDS" over "RARE OR
## BETTER" (v0.61, #108: a PREMIUM visit is a rarity boost), its bulbs coming on in turn, then
## chasing (one in four dark), and a hard shine band crossing it every 2.4 s, for the whole visit.
## The chase and the shine run on view.idle_time (still under reduced motion).
##
## The visit's head stamp (-4°): BONUS TICKET! with the inspection passed (or "shift n" for a bonus
## extra shift) under it, REVIEW PASSED on a payday, SILVER MEDAL! or GOLD MEDAL! for the week
## medals' draws (2026-11-06); paper with a tomato-dark double border, its words hard pixel
## lettering (4x, the line under at 2x), on the sign's right half (2026-11-06, so the receipt
## feeding under it stays in view). While it is set the title and the sub line stay engraved on
## the sign's left part, centred in the room left of it (v1.36, polish audit: hidden, they left
## two thirds of the sign blank on the most celebratory visits); a stamp too wide for that hides
## them. It blinks in and lands from twice its size at the visit's start (reduced motion: at
## rest), and lifts once the visit's landing is over (the punch's end + 0.6 s).

const SIZE := Vector2(928, 74)
const TITLE := "RECEIPT REWARDS"
const SUB_LINE := "KEEP 1 PRIZE PER DRAW"
const PREMIUM_TITLE := "PREMIUM REWARDS"
const PREMIUM_SUB := "RARE OR LEGENDARY"
## The title's and the sub line's boxes (their capitals centred in them): the title at 4x (word
## scale 2), the sub line at 2x, each at least BULB_CLEAR (2 art px) clear of its bulb row.
const TITLE_RECT := Rect2(8, 10, 912, 28)
const SUB_RECT := Rect2(8, 50, 912, 14)
const BULB_CLEAR := 4.0
const TITLE_SCALE := 2
## The bulbs (2 art px square): BULBS_ALONG on the top row and on the foot's, BULB_STEP apart
## from BULB_LEFT.
const BULBS_ALONG := 57
const BULB_LEFT := 12.0
const BULB_STEP := 16.0
const BULB_TOP := 2.0
const BULB_SIZE := 4.0
const BULB_HALO_ALPHA := 0.35
## The stamp: its double border (2 px line, 2 px paper, 2 px line), its side padding, its lines'
## gap, its top and its tilt (degrees).
const STAMP_RIM := 6.0
const STAMP_PAD := 10.0
const STAMP_GAP := 2.0
const STAMP_TOP := 0.0
## The stamp sits on the sign's right half (2026-11-06, mock-up week_medals.html section 5), so the
## receipt feeding into the slot under the sign's left half stays in view: centred at this share of
## the sign, STAMP_EDGE px clear of its right end at most.
const STAMP_CENTRE := 0.75
const STAMP_EDGE := 8.0
## While a stamp is set, the title and the sub line keep STAMP_CLEAR px (its -4° tilt included)
## left of its rest rect.
const STAMP_CLEAR := 16.0
const BONUS_TILT := -4.0
const BONUS_TEXT := "EXTRA DRAW!"
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
var _title: MachineLine
var _title_under: MachineLine
var _sub: MachineLine
var _stamp: Control
var _stamp_line: MachineLine
var _under: MachineLine
var _stamp_text: String = ""
var _under_text: String = ""
## Whether the title and the sub line fit left of the set stamp (they show there; else hidden).
var _title_beside: bool = false
var _look: MachineLook = MachineLook.new()
var _chase: float = 0.0
var _night: bool = true


func _init() -> void:
	name = "MachineHead"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_title_under = _line("TitleEngraving", self)
	_title = _line("Title", self)
	_sub = _line("SubLine", self)
	_stamp = Control.new()
	_stamp.name = "HeadStamp"
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.draw.connect(_draw_stamp)
	add_child(_stamp)
	_stamp_line = _line("StampText", _stamp)
	_under = _line("StampUnder", _stamp)
	_show_face(false)
	set_stamp("", "")


## The head stamp ("BONUS TICKET!", or "" for none) and the line under it.
func set_stamp(text: String, under: String) -> void:
	_stamp_text = text
	_under_text = under
	_stamp_line.show_text(text, Palette.TOMATO_DARK, MachineLine.clear(), TITLE_SCALE)
	_under.show_text(under.to_upper(), Palette.INK_LIGHT)
	_under.visible = not under.is_empty()
	var inner: float = maxf(_stamp_line.width(), _under.width() if _under.visible else 0.0)
	var lines: float = _stamp_line.size.y + (STAMP_GAP + _under.size.y if _under.visible else 0.0)
	var stamp_size: Vector2 = MachineArt.snap_point(
		Vector2(inner + 2.0 * (STAMP_PAD + STAMP_RIM), lines + 2.0 * (STAMP_RIM + STAMP_GAP))
	)
	_stamp.size = stamp_size
	var left: float = SIZE.x * STAMP_CENTRE - stamp_size.x / 2.0
	var right_most: float = SIZE.x - stamp_size.x - STAMP_EDGE
	left = clampf(left, minf(SIZE.x / 2.0, right_most), right_most)
	_stamp.position = Vector2(MachineArt.snap(left), STAMP_TOP)
	_stamp.pivot_offset = stamp_size / 2.0
	_stamp.rotation_degrees = BONUS_TILT
	var top: float = STAMP_RIM + STAMP_GAP
	_stamp_line.centre_in(Rect2(0, top, stamp_size.x, _stamp_line.size.y))
	_under.centre_in(Rect2(0, top + _stamp_line.size.y + STAMP_GAP, stamp_size.x, _under.size.y))
	_place_lines()
	_show_stamp(not text.is_empty(), 1.0)
	_stamp.queue_redraw()


## The head stamp's text ("" for none) and the line under it, for tests (the stamp set, even
## while it blinks).
func stamp_texts() -> PackedStringArray:
	return PackedStringArray([_stamp_text, _under_text if not _stamp_text.is_empty() else ""])


## The stamp's rect on the sign (local px).
func stamp_rect() -> Rect2:
	return Rect2(_stamp.position, _stamp.size)


## Whether the stamp shows now (frame(t): blinking in, at rest, or lifted).
func stamp_shown() -> bool:
	return _stamp.visible


## The stamp's current scale (2 as it starts landing, 1 at rest).
func stamp_scale() -> float:
	return _stamp.scale.x


## The title's and the sub line's hard pixel lines, for layout tests.
func title_lines() -> Array[MachineLine]:
	return [_title, _sub]


## Whether the sign shows its PREMIUM night face.
func premium_face() -> bool:
	return _night


## Where bulb `index` (0 .. bulb_count() - 1, along the top from the left, then along the foot
## from the right) sits: its top left (local px).
static func bulb_point(index: int) -> Vector2:
	if index < BULBS_ALONG:
		return Vector2(BULB_LEFT + index * BULB_STEP, BULB_TOP)
	var along: int = BULBS_ALONG - 1 - (index - BULBS_ALONG)
	return Vector2(BULB_LEFT + along * BULB_STEP, SIZE.y - BULB_TOP - BULB_SIZE)


static func bulb_count() -> int:
	return 2 * BULBS_ALONG


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


## The sign's texts and colours: the engraved classic face, or the night face (`night`).
func _show_face(night: bool) -> void:
	if night == _night:
		return
	_night = night
	var title: String = PREMIUM_TITLE if night else TITLE
	var under: Color = Palette.BRASS_DARKEST if night else Palette.MUSTARD_LIGHT
	var ink: Color = Palette.GOLD if night else Palette.BRASS_DARKEST
	_title_under.show_text(title, under, MachineLine.clear(), TITLE_SCALE)
	_title.show_text(title, ink, MachineLine.clear(), TITLE_SCALE)
	_sub.show_text(PREMIUM_SUB if night else SUB_LINE, Palette.MUSTARD_LIGHT if night else ink)
	_place_lines()


## Centres the title (its engraving one art px under it) and the sub line in their rects, or,
## while a stamp is set, in the room left of it (STAMP_CLEAR clear) when both fit there.
func _place_lines() -> void:
	var title_box: Rect2 = TITLE_RECT
	var sub_box: Rect2 = SUB_RECT
	_title_beside = false
	if not _stamp_text.is_empty():
		var room: float = _stamp.position.x - STAMP_CLEAR - TITLE_RECT.position.x
		_title_beside = maxf(_title.size.x, _sub.size.x) <= room
		title_box.size.x = room
		sub_box.size.x = room
	_title.centre_in(title_box)
	_title_under.position = _title.position + Vector2(0, MachineArt.PIXEL)
	_sub.centre_in(sub_box)


## Sets the stamp (`stamped`) at `stamp_scale_now`, shown on the blink's on frames; while it is
## set the title and sub line stay left of it (_place_lines), between the blinks too, or hidden
## when they don't fit there.
func _show_stamp(stamped: bool, stamp_scale_now: float, blink_on: bool = true) -> void:
	_stamp.visible = stamped and blink_on
	_stamp.scale = Vector2.ONE * stamp_scale_now
	var lines: bool = not stamped or _title_beside
	_title.visible = lines
	_title_under.visible = lines
	_sub.visible = lines


static func _line(line_name: String, parent: Control) -> MachineLine:
	var line: MachineLine = MachineLine.new()
	line.name = line_name
	parent.add_child(line)
	return line


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var p: float = MachineArt.PIXEL
	if _night:
		draw_rect(rect, Palette.INK)
		draw_rect(rect.grow(-p), Palette.BRASS_DARK)
		draw_rect(rect.grow(-3.0 * p), Palette.INK)
		draw_rect(rect.grow(-4.0 * p), Palette.CHARCOAL)
		MachineArt.shine(self, rect.grow(-4.0 * p), _look.sign_shine(_chase), Palette.PAPER, 3.0)
	else:
		MachineArt.brass_plate(self, rect)
	if _look.flash():
		draw_rect(rect, Color(Palette.PAPER, FLASH_ALPHA))
	var halo: Color = Color(Palette.MUSTARD_LIGHT, BULB_HALO_ALPHA)
	for index: int in range(bulb_count()):
		var at: Vector2 = bulb_point(index)
		var lit: bool = _look.bulb_lit(index, _chase)
		if lit:
			draw_rect(Rect2(at - Vector2(p, p), Vector2.ONE * (BULB_SIZE + 2.0 * p)), halo)
		var bulb: Rect2 = Rect2(at, Vector2.ONE * BULB_SIZE)
		draw_rect(bulb, Palette.GOLD if lit else Palette.BRASS_DARKEST)


## The stamp: paper with a tomato-dark double border (2 px line, 2 px paper, 2 px line).
func _draw_stamp() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _stamp.size)
	_stamp.draw_rect(rect, Palette.PAPER)
	_stamp.draw_rect(rect.grow(-1.0), Palette.TOMATO_DARK, false, 2.0)
	_stamp.draw_rect(rect.grow(-5.0), Palette.TOMATO_DARK, false, 2.0)
