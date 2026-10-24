class_name MonitorView
extends Control
## The hung monitor (#80, mock-up B2; ShiftStage.MONITOR_RECT): two rods from the ceiling, the
## shade under it, a rubber bezel with a little bevel and the paper screen, drawn flat in code
## (its art lands in a later step). The scanner bay (ScannerBay, BAY_RECT) stands at the paper's
## left in every mode (the monitor bay follow-up of #86, mock-up monitor_bay_v1.html, the user's
## decision of 2026-10-21): in planning it shows belt slot 1's item under NEXT (show_next, which the
## shift screen calls on every refresh) or, while a hover-hold scan holds an item, that item under
## SCAN (show_scan; ScannerBay.show_planning), and in the count the item at the belt's scanner.
## In redraw mode (plan section 3.8, the basket redraw; show_redraw) the redraw panel (RedrawPanel)
## covers the whole paper, bay included, as mock-up redraw_basket_v1.html has it (mode() REDRAW).
## Otherwise the rest of the screen, right of the bay (x 615 to 893, centre 754), shows one of four
## things (mode()):
## - CHANNEL (planning with nothing scanned, show_channel; the user's play test of 2026-10-17):
##   the store channel (MonitorChannel, CHANNEL_RECT): the shift's brief, the owned upgrades and the
##   coupons in play, a slide at a time; the LED is hidden (the projected total is on the receipt
##   and the top bar's SPEND chip);
## - IDLE (a notice in planning): the notices (NoticeLabel) at NOTICE_RECT;
##   the LED's compact layout only when it shows a projected total (no longer in the game: a blank
##   LED is hidden);
## - SCAN (a belt or hand item fully scanned: ScanController calls show_scan): the bay shows the
##   item and its kind (COUPON, or its base price), and beside it (TEXT_RECT) its name (ItemName:
##   Pixelify at 22 px, or the bold body font when too long) with its family glyphs after it
##   (#105: FamilyPalette.shelf_families of its tags, their tooltips above), "pays €N" for a belt
##   item, its short text (the sticker summary, its family names as glyphs: GlyphLabel; the rule
##   text when it has none) and, for a belt item, its step lines as the caller words them
##   (ScanFooter), in the largest of the TIERS sizes that shows every line; on the smallest, lines
##   that don't fit fold into "+N more";
## - COUNT (the count-up: the LED shows SUBTOTAL or TOTAL in its count layout; #86 v6's scan
##   count-up, mock-up count_up_86_v6_scan.html): the bay follows the beats (follow_beat on
##   CountUp's beat_started: the item, its name and each beat's landing sticker), the LED's number
##   and its € as one group in LED_COUNT_RECT (the € as tall as the digits, 6 px after them,
##   LedDisplay.euro_label; sized for the count's final total, the € standing still while the
##   digits grow left), the to-go line under them (TO_GO_RECT) that the SPEND MET stamp
##   (STAMP_RECT) replaces at the quota, the "+€N" tab beside the stamp (OverTab), over a sunburst
##   on the whole paper centred on the group (Sunburst, SUNBURST_CENTRE, behind them all). The count
##   starts with slot 1's item already in the bay (no first drop-in). The TOTAL keeps that layout.
##   The monitor juice (mock-up monitor_juice_v2.html, K1 one tank with FILL A, WIN B and FONT C,
##   the user's picks of 2026-10-22): the number and the € are one tank of liquid gold
##   (LedDisplay.gold_tank, GoldTank) at the shown total / the quota, held just under the brim until
##   the payout that meets the quota lands. The monitor follows the count-up (follow): its rides
##   and beats move the bay's items, tag and queue (round 7, count_up_86_v7_bay.html). As each
##   payout's roll starts (on the LED's first higher reading) the tag turns gold and one gold "+€N"
##   chip (TallyChips) flies from it into the digits' middle. As the payout lands (CountUp's
##   payout_landed) a chip still in flight goes, the gold sloshes with a ripple, droplets jump off
##   it (TankBurst.surface_drops, the stage's layer over the top bar), a spark and dust pop on the
##   digits (TankBurst.sparkle) and the shine rises up the number and the €; the TOTAL line
##   (total_landed) shines twice. The landing that meets the quota (CountUp's quota_met, in that
##   same frame) fills the gold over the brim, punches the digits to their cap
##   (CountUpTuning.win_punch), turns the bay's light, fan and pips green and knocks its sticker
##   off, turns the sunburst gold (it grows out to CountUpTuning.sunburst_met_radius and spins),
##   sprays the coin fountain out of the number and € (TankBurst.burst,
##   with a small shake of the monitor), flashes the paper (`flash`, CountUpTuning.win_flash), slams
##   the SPEND MET stamp STAMP_DELAY_S later (shaking the monitor STAMP_SHAKE px as it lands) and
##   brings the "+€N" tab in; each later landing sprays a small fountain (TankBurst.spurt) and
##   punches the tab. A resumed checkout shows the end state at once (quota_met without a pop,
##   show_end_state): the gold settled, no particles.
## A notice shows on the idle screen while it lasts, over a scan, the channel and the redraw panel
## too (they come back once it has faded), never over the count. The channel runs only while it is
## shown, and comes back on the slide it was on. The monitor follows the LED's mode (mode_changed)
## and the notice (showing_changed) itself; ScanController and the shift screen fill it. Display
## only: every amount and line is the caller's (or the LED's, from core's ShiftMargin).
##
## Text never carries the pixel material; the art does. Reduced motion (`reduced_motion`) leaves
## out the bay's motion (its drop, wobble, slide-out, flash, slap and knock-off; planning's swaps
## cut), the chips, the sunburst's turn, the gold's slosh, ripples, bubbles, shine and punches (its
## level follows the total at once), the burst's particles (a few still splashes on the bezel
## instead), the paper's flash, the shakes, the stamp's slam and the tab's pop and punches; the
## states all stay.

enum Mode { IDLE, SCAN, COUNT, CHANNEL, REDRAW }

## The parts' rects, in stage coordinates (the view stands at MONITOR_RECT's position), all on
## the paper (PAPER_RECT, inside the screen's ink border): the scanner bay (every mode), the right
## part beside it (RIGHT_RECT: x 615 to 893, centre 754), the store channel's and the scan's text
## column in it.
const PAPER_RECT := Rect2(495, 77, 402, 154)
const BAY_RECT := Rect2(499, 79, 112, 150)
const RIGHT_RECT := Rect2(615, 79, 278, 150)
const CHANNEL_RECT := Rect2(617, 83, 272, 142)
const TEXT_RECT := Rect2(617, 85, 270, 138)
## The count view's parts (stage coordinates): the LED's number and € group (centred in
## LED_COUNT_RECT; its line box 95 to 181), the to-go line under it at TO_GO_RECT, the SPEND MET
## stamp at STAMP_RECT (the "+€N" tab beside it, OverTab.POSITION); the sunburst over the whole
## paper, centred on the group's middle.
const LED_COUNT_RECT := Rect2(615, 95, 278, 86)
const TO_GO_RECT := Rect2(615, 183, 278, 24)
const STAMP_RECT := Rect2(640, 184, 156, 30)
const SUNBURST_CENTRE := Vector2(754, 137)
## The DONE state's "INSPECTION PASSED ✓" under the stamp (#77 machine v2), as the dessert stamps
## it on the receipt (CountUp.inspection_passed): bold Atkinson (✓ from the display's fallback).
const INSPECTION_RECT := Rect2(615, 213, 278, 16)
const INSPECTION_TEXT := "INSPECTION PASSED ✓"
const INSPECTION_SIZE := 12
const INSPECTION_WEIGHT := 800
## The paper's flash as the quota is met (WIN B; the mock-up's #fff3cc, the palette's mustard
## pale), at CountUpTuning.win_flash, fading over win_flash_s.
const FLASH_COLOR := Palette.MUSTARD_PALE
## The SPEND MET stamp slams this long after the burst (real time), shaking the monitor
## STAMP_SHAKE px over STAMP_SHAKE_S as it lands.
const STAMP_DELAY_S := 0.25
const STAMP_SHAKE := 4.0
const STAMP_SHAKE_S := 0.25
## A notice (planning's, with the channel off the screen): in the right part's middle.
const NOTICE_RECT := Rect2(617, 132, 272, 44)
## Every part the monitor draws, rods and shade included (stage coordinates).
const DRAWN_RECT := Rect2(484, 56, 424, 192)
const OUTLINE := 2
## The bezel's bevel: a light edge on its top and left, a dark one on its bottom and right.
const BEVEL := 2
const BEVEL_LIGHT := Palette.STEEL_DARKEST
const BEVEL_DARK := Palette.RUBBER_DARK
## The screen's inner shadow under its top border.
const SCREEN_SHADOW := 2
const SCREEN_SHADOW_ALPHA := 0.12
## Two lines of the notice's font run 47 px with its own leading; this pulls them into 44.
const NOTICE_LINE_SPACING := -4
## The notice's ink: plain, as tomato is only for fizzles, CHECKOUT and CLOSED (#80).
const NOTICE_COLOR := Palette.INK
## The scan's text: the name row (the name, its glyphs NAME_GLYPH_GAP after it, GLYPH_GAP apart,
## and "pays €N" at its right), the gaps.
const NAME_HEIGHT := 26.0
const NAME_GLYPH_GAP := 4.0
const GLYPH_GAP := 3.0
const PAYS_WORD := "pays"
const PAYS_WORD_SIZE := 13
const PAYS_AMOUNT_SIZE := 18
const PAYS_GAP := 4.0
const NAME_GAP := 8.0
const SUMMARY_GAP := 2.0
const SUMMARY_WEIGHT := 800
const FOOTER_GAP := 4.0
## The short text's and the step lines' sizes, largest first, and the short text's line pitch at
## each: the scan takes the first that shows every step line.
const TIERS: Array[Vector2i] = [Vector2i(16, 12), Vector2i(14, 11), Vector2i(13, 10)]
const SUMMARY_PITCHES: Array[float] = [19.0, 17.0, 15.0]
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The LED and the notices on the screen (the stage hands them to the shift screen).
var led: LedDisplay
var notice_label: NoticeLabel
## The store channel (planning's idle screen, at CHANNEL_RECT).
var channel: MonitorChannel
## The stage's layer for the gold outside the monitor (the pour, the burst, the spurts and the
## shakes); set by ShiftStage, it takes the LED (its €), this monitor and the reduced motion
## setting.
var tank_burst: TankBurst:
	set(value):
		tank_burst = value
		if value != null:
			value.reduced_motion = _wants_reduced_motion
			value.bind(led, self)
## The DONE state's "INSPECTION PASSED ✓" label, for checks (read only; a property, so the class
## stays within gdlint's 20 public methods).
var inspection_passed_label: Label:
	get:
		return _inspection_passed
## The paper's flash as the quota is met (WIN B), over the whole screen, for checks (read only).
var flash: ColorRect:
	get:
		return _flash

var _notice_holder: Control
## The redraw panel over the whole paper (show_redraw), and whether it is on.
var _redraw_panel: RedrawPanel
var _redraw_on: bool = false
## The channel is planning's idle screen (show_channel, until end_channel).
var _channel_on: bool = false
var _scan_view: Control
## The bay's layer (every mode), the count view (the tab) and, over the LED, the landing
## stickers' layer (clipped to the paper); behind them all, the sunburst.
var _bay_layer: Control
var _count_view: Control
var _count_top: Control
var _sunburst: Sunburst
var _bay: ScannerBay
var _tab: OverTab
var _chips: TallyChips
## The count-up's item views (count_started), whose definitions the rides bring in.
var _views: Array[CardView] = []
## The count met the quota (quota_met); a payout waiting to rise (the beat's, its chip sent on
## the reading's first rise) with its chip's flight, and the last reading's amount; the stamp's
## delayed slam and the paper's flash.
var _met: bool = false
var _chip_due: int = 0
var _chip_s: float = 0.0
var _last_amount: int = 0
var _met_motion: Tween
var _flash: ColorRect
var _flash_motion: Tween
var _scanning: bool = false
## Planning's bay (show_next, show_scan): belt slot 1's item (null when empty), the belt's slots
## and filled ones, and the held item (null with no scan).
var _next: CardDefinition
var _slots: int = 0
var _filled: int = 0
var _held: CardDefinition
var _scan_name: Control
var _scan_summary: GlyphLabel
var _scan_glyphs: Array[FamilyGlyph] = []
var _scan_footer: ScanFooter
## How many of the scan's first step lines are "gives" lines (show_scan).
var _scan_gives: int = 0
var _scan_tier: int = 0
var _inspection_passed: Label
## Each label's rect (local), set again once in the tree (a label never shrinks back by itself).
var _rects: Dictionary[Label, Rect2] = {}


func _init() -> void:
	name = "Monitor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.MONITOR_RECT.position
	size = ShiftStage.MONITOR_RECT.size
	_notice_holder = _layer("Idle")
	# Plain ink on the paper screen (NOTICE_COLOR, no outline), on up to two lines.
	notice_label = NoticeLabel.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", NOTICE_COLOR)
	notice_label.add_theme_constant_override("outline_size", 0)
	notice_label.add_theme_constant_override("line_spacing", NOTICE_LINE_SPACING)
	_notice_holder.add_child(notice_label)
	_place(notice_label, ShiftStage.NOTICE_RECT)
	notice_label.showing_changed.connect(_on_notice_showing)
	_sunburst = Sunburst.new(PAPER_RECT.size, SUNBURST_CENTRE - PAPER_RECT.position)
	_sunburst.position = local(PAPER_RECT).position
	_sunburst.reduced_motion = _wants_reduced_motion
	add_child(_sunburst)
	_bay_layer = _layer("Bay")
	_bay = ScannerBay.new()
	_bay.position = local(BAY_RECT).position
	_bay.reduced_motion = _wants_reduced_motion
	_bay.make_tween = _count_tween
	_bay_layer.add_child(_bay)
	_count_view = _layer("Count")
	_tab = OverTab.new()
	_tab.position = local(Rect2(OverTab.POSITION, Vector2.ZERO)).position
	_tab.reduced_motion = _wants_reduced_motion
	_count_view.add_child(_tab)
	_inspection_passed = UiKit.body_label(INSPECTION_TEXT, INSPECTION_SIZE, Palette.TEAL_SHADE)
	_inspection_passed.name = "InspectionPassed"
	_inspection_passed.add_theme_font_override(
		"font", MachineDisplay.marked_font(INSPECTION_WEIGHT)
	)
	_inspection_passed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspection_passed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inspection_passed.visible = false
	_count_view.add_child(_inspection_passed)
	_place(_inspection_passed, INSPECTION_RECT)
	led = LedDisplay.new()
	led.position = local(ShiftStage.LED_RECT).position
	led.gold_tank.reduced_motion = _wants_reduced_motion
	add_child(led)
	_sunburst.met_radius = led.gold_tank.tuning().sunburst_met_radius
	_sunburst.grow_seconds = led.gold_tank.tuning().sunburst_grow_s
	led.mode_changed.connect(_on_led_mode)
	led.reading_changed.connect(_on_reading)
	led.beat().stamp().landed.connect(_on_stamp_landed)
	_count_top = _layer("CountTop")
	var stickers: Control = Control.new()
	stickers.name = "Stickers"
	stickers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stickers.clip_contents = true
	stickers.position = local(PAPER_RECT).position
	stickers.size = PAPER_RECT.size
	_count_top.add_child(stickers)
	_bay.sticker_parent = stickers
	_chips = TallyChips.new()
	_chips.size = size
	_chips.make_tween = _count_tween
	_count_top.add_child(_chips)
	_bay.tag_holder = _count_top
	_bay.tag().place(local(Rect2(BayTag.POSITION, Vector2.ZERO)).position)
	channel = MonitorChannel.new()
	channel.reduced_motion = _wants_reduced_motion
	channel.position = local(CHANNEL_RECT).position
	channel.size = CHANNEL_RECT.size
	add_child(channel)
	_scan_view = _layer("Scan")
	_redraw_panel = RedrawPanel.new()
	_redraw_panel.position = local(PAPER_RECT).position
	add_child(_redraw_panel)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(FLASH_COLOR, 0.0)
	_flash.position = local(PAPER_RECT).position
	_flash.size = PAPER_RECT.size
	add_child(_flash)
	_apply()


func _ready() -> void:
	for label: Label in _rects:
		label.position = _rects[label].position
		label.size = _rects[label].size


func _draw() -> void:
	for rod: Rect2 in ShiftStage.ROD_RECTS:
		_draw_hung(local(rod), Palette.RUBBER)
	_draw_hung(local(ShiftStage.MONITOR_UNDER_RECT), Palette.CHARCOAL)
	var bezel: Rect2 = local(ShiftStage.MONITOR_RECT)
	draw_rect(bezel, Palette.INK)
	var face: Rect2 = bezel.grow(-OUTLINE)
	draw_rect(face, BEVEL_DARK)
	draw_rect(Rect2(face.position, face.size - Vector2(BEVEL, BEVEL)), BEVEL_LIGHT)
	draw_rect(face.grow(-BEVEL), Palette.RUBBER)
	var screen: Rect2 = local(ShiftStage.MONITOR_SCREEN_RECT)
	draw_rect(screen, Palette.INK)
	var paper: Rect2 = screen.grow(-OUTLINE)
	draw_rect(paper, Palette.PAPER)
	draw_rect(
		Rect2(paper.position, Vector2(paper.size.x, SCREEN_SHADOW)),
		Color(Palette.INK, SCREEN_SHADOW_ALPHA)
	)


## What the screen shows now.
func mode() -> Mode:
	if _counting():
		return Mode.COUNT
	if _redraw_panel.visible:
		return Mode.REDRAW
	if _scan_view.visible:
		return Mode.SCAN
	return Mode.CHANNEL if channel.visible else Mode.IDLE


## Planning's idle screen is the store channel, showing `run`'s shift (MonitorChannel's
## show_state): its number, quota and inspections, the owned upgrades and the coupons in play
## (on the belt in slot order, then in the hand), whether passing the shift earns the bonus ticket
## (RewardMachine.bonus_if_passed: the brief's PASS IT plate) and the brief's `news` lines (#77
## machine v2). The shift screen calls it on every planning refresh, with the LED blank.
func show_channel(run: RunState, news: PackedStringArray = PackedStringArray()) -> void:
	var coupons: Array[CardDefinition] = []
	for cards: Array[CardInstance] in [run.row, run.hand()]:
		for card: CardInstance in cards:
			if card.definition.is_coupon():
				coupons.append(card.definition)
	var bonus: bool = run.machine != null and run.machine.bonus_if_passed(run)
	channel.show_state(
		run.shift_index + 1,
		run.shift_count(),
		run.quota(),
		run.inspections,
		run.upgrades,
		coupons,
		bonus,
		news
	)
	_channel_on = true
	_apply()


## The planning brief's sticker key (#71, H1_BUILD_SPEC.md section 7): `entries` (PlanningModel's
## key_entries; none takes the key off), shown by the channel's brief.
func set_planning_key(entries: Array[StickerSpec]) -> void:
	channel.set_key(entries)


## Redraw mode's panel (plan section 3.8): `notice` over the whole paper until null ends it. A
## notice still shows over it while it lasts; the count takes it off.
func show_redraw(notice: RedrawNotice) -> void:
	_redraw_on = notice != null
	_redraw_panel.show_notice(notice)
	_apply()


## Planning is over (the CHECKOUT click): the channel leaves the screen. The bay keeps its item
## (the count starts with it).
func end_channel() -> void:
	_channel_on = false
	_apply()


## Planning's bay (the shift screen, on every refresh): belt slot 1's item (`definition`, null for
## an empty slot 1) under NEXT, with a pip per belt slot (`slots`, the first `filled` of them
## holding items). A held scan's item shows instead while it lasts (show_scan); null and 0 show an
## empty bed. Nothing changes in the count.
func show_next(definition: CardDefinition, slots: int, filled: int) -> void:
	_next = definition
	_slots = slots
	_filled = filled
	_update_bay()


## Shows a scanned item (ScanController): `definition` with its `tags`
## (on the belt the scored ones). A belt item passes its `payout` and step lines (each with
## whether it is a fizzle; the first `gives` of them are its "gives" lines, #71, their amount in
## mustard darkest); a hand item passes payout -1. Call it once the monitor is in the
## tree: the text is measured with the real font. A notice showing, or the count-up, keeps the
## scan off the screen until it ends.
func show_scan(
	definition: CardDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	gives: int = 0
) -> void:
	_scanning = true
	_scan_gives = gives
	_held = definition
	_fill_scan(definition, tags, payout, lines, fizzles)
	_apply()
	_update_bay()


## The scan ended: the idle screen comes back, and the bay goes back to belt slot 1's item.
func end_scan() -> void:
	_scanning = false
	_held = null
	_apply()
	_update_bay()


## Follows `count_up`: its count's start (the bay's queue), its rides and beats (the bay's items,
## tag and stickers, the payouts' chips), the payouts' and the total's landings (the gold) and the
## quota met (see the class comment).
func follow(count_up: CountUp) -> void:
	count_up.count_started.connect(_on_count_started)
	count_up.ride.connect(_on_ride)
	count_up.beat_started.connect(_on_beat_started)
	count_up.payout_landed.connect(_on_payout_landed)
	count_up.total_landed.connect(_on_total_landed)
	count_up.quota_met.connect(_on_quota_met)
	count_up.inspection_passed.connect(_show_inspection_passed)


## The DONE state's "INSPECTION PASSED ✓" (the dessert stamped it; hidden at the next count).
func _show_inspection_passed() -> void:
	_inspection_passed.visible = true


## A resumed checkout's end state (after CountUp's show_end_state, which met the quota or not):
## the bay with all of `views`' items paid and bagged (ALL PAID, DONE), the gold settled at its
## level, no chips or particles. `_plan` is the count-up's; an inspected pass shows INSPECTION
## PASSED ✓ (`inspection_passed`).
func show_end_state(
	_plan: CountUpPlan, views: Array[CardView], inspection_passed: bool = false
) -> void:
	_bay.show_end_state(views.size(), _met)
	_inspection_passed.visible = inspection_passed
	_chips.clear()
	_chip_due = 0
	led.gold_tank.settle()
	if tank_burst != null:
		tank_burst.clear()


## The scan's name (ItemName.make's control; its family glyphs are FamilyGlyphs after it), short
## text and step lines (while a scan was shown), and the size tier it took (an index into TIERS).
func scan_name() -> Control:
	return _scan_name


func scan_summary() -> GlyphLabel:
	return _scan_summary


func scan_footer() -> ScanFooter:
	return _scan_footer


func scan_tier() -> int:
	return _scan_tier


## The scanner bay (every mode) and the count view's sunburst.
func bay() -> ScannerBay:
	return _bay


func sunburst() -> Sunburst:
	return _sunburst


## The "+€N" tab beside the stamp, and the tag's chips.
func over_tab() -> OverTab:
	return _tab


func chips() -> TallyChips:
	return _chips


## The art shown in the bay for the scan (the held item's, once it is in), or null.
func scan_art() -> TextureRect:
	if not _scan_view.visible or _bay.bed().shown_definition() != _held:
		return null
	return _bay.bed().art()


## Every text label the screen shows now (the LED's aside), for layout checks.
func shown_labels() -> Array[Label]:
	var labels: Array[Label] = []
	var layers: Array[Control] = [
		_notice_holder, channel, _scan_view, _bay_layer, _count_view, _redraw_panel
	]
	for layer: Control in layers:
		if layer.visible:
			_collect_labels(layer, labels)
	return labels


## A rect in stage coordinates, in the monitor's own.
static func local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - ShiftStage.MONITOR_RECT.position, rect.size)


## Shows what the state says (see the class comment) and lays the LED out for it.
func _apply() -> void:
	var counting: bool = _counting()
	var scanning: bool = _scanning and not counting and not notice_label.is_showing()
	var channel_idle: bool = _channel_on and not counting
	var led_rect: Rect2 = LED_COUNT_RECT if counting else ShiftStage.LED_RECT
	led.position = local(led_rect).position
	# A blank LED stays off the screen: the bay has its place.
	var projected: bool = led.mode() == LedDisplay.Mode.PROJECTED
	led.visible = counting or (projected and not scanning and not channel_idle)
	_notice_holder.visible = not counting and not scanning
	var notice_rect: Rect2 = local(ShiftStage.NOTICE_RECT if led.visible else NOTICE_RECT)
	_rects[notice_label] = notice_rect
	notice_label.position = notice_rect.position
	var redrawing: bool = _redraw_on and not counting and not notice_label.is_showing()
	_redraw_panel.visible = redrawing
	_bay_layer.visible = not redrawing
	_scan_view.visible = scanning and not redrawing
	channel.visible = (
		channel_idle and not scanning and not redrawing and not notice_label.is_showing()
	)
	channel.set_running(channel.visible)
	_count_view.visible = counting
	_count_top.visible = counting
	_sunburst.visible = counting


func _counting() -> bool:
	return led.mode() == LedDisplay.Mode.SUBTOTAL or led.mode() == LedDisplay.Mode.TOTAL


## Planning's bay (outside the count): the held item under SCAN, else belt slot 1's under NEXT.
func _update_bay() -> void:
	if _counting():
		return
	var held: bool = _held != null
	_bay.show_planning(_held if held else _next, held, _slots, _filled)


## A count-up starts over (start_count), or the LED leaves the count: the bay reset (a count's
## start keeps its item for start(); planning's bay stays as it is and, out of the count, the bay
## goes back to planning), the sunburst not met, the tab off, the gold outside gone and the
## monitor at rest.
func _on_led_mode(led_mode: LedDisplay.Mode) -> void:
	if led_mode == LedDisplay.Mode.SUBTOTAL:
		_bay.reset(true)
		_inspection_passed.visible = false
		# Planning's belt is spent: the next planning shows an empty bay until the screen says.
		_next = null
		_slots = 0
		_filled = 0
	elif led_mode != LedDisplay.Mode.TOTAL and not _bay.is_planning():
		_bay.reset()
	if led_mode != LedDisplay.Mode.TOTAL:
		_sunburst.set_met(false)
		_met = false
		_chip_due = 0
		_last_amount = 0
		_chips.clear()
		_tab.reset()
		_stop_met_motion()
		_set_flash(0.0)
		if tank_burst != null:
			tank_burst.clear()
	_apply()
	_update_bay()


## The LED's reading: the tab follows it; the first rise after a payout's beat turns the bay's tag
## gold and sends its chip into the digits (none under reduced motion).
func _on_reading(amount: int, quota: int, met: bool) -> void:
	_tab.set_reading(amount, quota, met)
	if amount > _last_amount and _chip_due > 0 and _counting():
		_bay.pay()
		if not _wants_reduced_motion():
			var tag: BayTag = _bay.tag()
			var from: Vector2 = tag.send_point() if tag.visible else _bay.landing_point()
			_chips.fly(_chip_due, from, led.digits_text_rect().get_center(), _chip_s)
		_chip_due = 0
	_last_amount = amount


## CountUp.payout_landed: any chip still in flight goes, the gold sloshes (a ripple from the
## group's middle), droplets jump off it, the digits sparkle and the shine rises up the number and
## the €; a payout after the quota sprays a small fountain and punches the tab. The landing that
## meets the quota comes before its quota_met, so it is not one of those.
func _on_payout_landed(_payout: int, _subtotal: int) -> void:
	# The chip still flying (its flight on the count's tweens may outlast the roll) goes as the
	# payout lands, as the mock-up's: nothing covers the number at the win.
	_chips.drop()
	if not _counting():
		return
	var tank: GoldTank = led.gold_tank
	tank.land()
	tank.shine()
	if tank_burst != null:
		var drops: int = tank.tuning().tank_drops_met if _met else tank.tuning().tank_drops
		tank_burst.surface_drops(tank.surface_points(drops))
		tank_burst.sparkle(led.digits_text_rect().get_center())
		if _met:
			tank_burst.spurt()
	if _met:
		_punch_tab()


## CountUp.total_landed: the TOTAL line's shine, twice.
func _on_total_landed() -> void:
	if _counting():
		led.gold_tank.shine(true)


## CountUp.count_started: a count of `views` starts (the bay's queue; it keeps the first item when
## planning left it in the bay).
func _on_count_started(views: Array[CardView]) -> void:
	_views = views
	var first: CardDefinition = null
	if not views.is_empty() and views[0] != null:
		first = views[0].card.definition
	_bay.start(views.size(), first)


## CountUp.ride: item `scan_slot` rides in over `ride_ms` while `bag_slot` bags.
func _on_ride(bag_slot: int, scan_slot: int, ride_ms: int) -> void:
	var definition: CardDefinition = null
	if scan_slot >= 0 and scan_slot < _views.size() and _views[scan_slot] != null:
		definition = _views[scan_slot].card.definition
	_bay.ride(bag_slot, scan_slot, definition, ride_ms / 1000.0)


## CountUp.beat_started: the scanner bay follows the beat (ScannerBay.follow_beat); a payout waits
## for its rise, its chip flying as long as the receipt's (ReceiptFly). The step line and the item
## count are the receipt's.
func _on_beat_started(
	beat: CountUpBeat, step: ScoreStep, _line: String, view: CardView, _items: int
) -> void:
	var definition: CardDefinition = view.card.definition if view != null else null
	_bay.follow_beat(beat, step, definition)
	if beat.payout > 0:
		_chip_due = beat.payout
		_chip_s = clampf(beat.roll_ms / 1000.0, ReceiptFly.FLIGHT_MIN, ReceiptFly.FLIGHT_MAX)


## CountUp.quota_met: the quota is met (see the class comment), with `pop` (the burst, the slam,
## the tab's pop) or at once (a resumed checkout).
func _on_quota_met(pop: bool) -> void:
	_met = true
	_bay.set_met(true)
	_sunburst.set_met(true)
	_tab.arm(pop)
	_stop_met_motion()
	led.beat().set_met(true)
	var stamp: MetStamp = led.beat().stamp()
	if not pop:
		stamp.show_static()
		return
	_bay.knock_off()
	_sunburst.boost()
	# WIN B's own punch (the mock-up's ding): the digits to the cap, from the landing's punch.
	led.gold_tank.punch(led.gold_tank.tuning().win_punch)
	if tank_burst != null:
		tank_burst.burst()
	if _wants_reduced_motion() or not is_inside_tree():
		stamp.slam(true)
		return
	var tuning: CountUpTuning = led.gold_tank.tuning()
	_set_flash(tuning.win_flash)
	_flash_motion = create_tween()
	_flash_motion.tween_method(_set_flash, tuning.win_flash, 0.0, tuning.win_flash_s)
	_met_motion = create_tween()
	_met_motion.tween_callback(stamp.slam.bind(false)).set_delay(STAMP_DELAY_S)


func _punch_tab() -> void:
	if _met and _counting():
		_tab.punch()


## The stamp lands: the monitor shakes.
func _on_stamp_landed() -> void:
	if tank_burst != null:
		tank_burst.shake(STAMP_SHAKE, STAMP_SHAKE_S)


func _stop_met_motion() -> void:
	if _met_motion != null:
		_met_motion.kill()
		_met_motion = null
	if _flash_motion != null:
		_flash_motion.kill()
		_flash_motion = null


## The paper's flash at `alpha`.
func _set_flash(alpha: float) -> void:
	_flash.color = Color(FLASH_COLOR, alpha)


func _on_notice_showing(_showing: bool) -> void:
	_apply()


## Builds the scan's text (show_scan) in the first of TIERS whose step lines all show (the bay
## shows the item's art and kind).
func _fill_scan(
	definition: CardDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool]
) -> void:
	for tier: int in range(TIERS.size()):
		_clear(_scan_view)
		_scan_tier = tier
		var fits: bool = _build_scan(definition, tags, payout, lines, fizzles, tier)
		if fits:
			return


## The scan's text at TIERS[`tier`] (the short text's size, the step lines') in TEXT_RECT.
## Returns whether everything shows inside it, no step line folded.
func _build_scan(
	definition: CardDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	tier: int
) -> bool:
	var sizes: Vector2i = TIERS[tier]
	var column: Rect2 = local(TEXT_RECT)
	var palette: FamilyPalette = FamilyPalette.shared()
	var row_width: float = column.size.x
	if payout >= 0:
		row_width -= _add_pays(payout, column) + NAME_GAP
	var shown: PackedStringArray = (
		palette.shelf_families(tags) if definition.is_product() else PackedStringArray()
	)
	_scan_glyphs.clear()
	for family: String in shown:
		var style: FamilyStyle = palette.style(family)
		if style != null and style.glyph != null:
			_scan_glyphs.append(FamilyGlyph.new(style))
	var glyphs_width: float = 0.0
	if not _scan_glyphs.is_empty():
		glyphs_width = (
			NAME_GLYPH_GAP
			+ _scan_glyphs.size() * ArtStyle.FAMILY_GLYPH_SIZE
			+ (_scan_glyphs.size() - 1) * GLYPH_GAP
		)
	var name_room: float = row_width - glyphs_width
	_scan_name = ItemName.make(definition.display_name, name_room, NAME_HEIGHT, Palette.INK)
	_scan_view.add_child(_scan_name)
	_scan_name.position = column.position
	# The glyphs follow the name's text, not its row.
	var name_end: float = minf(_name_width(_scan_name), name_room)
	var x: float = column.position.x + ceilf(name_end) + NAME_GLYPH_GAP
	for glyph: FamilyGlyph in _scan_glyphs:
		glyph.position = Vector2(x, column.position.y + (NAME_HEIGHT - glyph.size.y) / 2.0)
		_scan_view.add_child(glyph)
		x += glyph.size.x + GLYPH_GAP
	# A name with a number ("2 for 1") is as tall as the number font's line.
	var y: float = column.position.y + maxf(NAME_HEIGHT, _scan_name.size.y)
	var text: String = definition.sticker_summary()
	if text.is_empty():
		text = definition.rule_text
	_scan_summary = GlyphLabel.new(
		text,
		ArtStyle.bold_font(SUMMARY_WEIGHT),
		sizes.x,
		Palette.INK,
		SUMMARY_PITCHES[tier],
		column.size.x
	)
	_scan_summary.name = "ScanSummary"
	_scan_summary.position = Vector2(column.position.x, y + SUMMARY_GAP)
	_scan_view.add_child(_scan_summary)
	y = _scan_summary.position.y + _scan_summary.size.y
	var bottom: float = local(TEXT_RECT).end.y
	_scan_footer = null
	if payout < 0:
		return y <= bottom
	_scan_footer = ScanFooter.new(column.size.x, sizes.y)
	_scan_footer.gives_lines = _scan_gives
	_scan_view.add_child(_scan_footer)
	_scan_footer.position = Vector2(column.position.x, y + FOOTER_GAP)
	var all_shown: bool = _scan_footer.fill(lines, fizzles, bottom - _scan_footer.position.y)
	return all_shown and y <= bottom


## The width of a name's text (ItemName.make's control).
static func _name_width(name_control: Control) -> float:
	if name_control is MixedLabel:
		return name_control.get_combined_minimum_size().x
	var label: Label = name_control as Label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## "pays €N" right-aligned on the name row of `column`. Returns its width.
func _add_pays(payout: int, column: Rect2) -> float:
	var amount: Label = UiKit.number_label("€%d" % payout, PAYS_AMOUNT_SIZE, false)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_view.add_child(amount)
	var amount_width: float = amount.get_minimum_size().x
	amount.position = Vector2(column.end.x - amount_width, column.position.y)
	amount.size = Vector2(amount_width, NAME_HEIGHT)
	var word: Label = UiKit.body_label(PAYS_WORD, PAYS_WORD_SIZE, Palette.INK_LIGHT)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_view.add_child(word)
	var word_width: float = word.get_minimum_size().x
	word.position = Vector2(amount.position.x - PAYS_GAP - word_width, column.position.y)
	word.size = Vector2(word_width, NAME_HEIGHT)
	return amount_width + PAYS_GAP + word_width


## Adds `label` to the scan at `rect` (local), in the tree first: out of it a label measures
## with the default font size.
func _add(label: Label, rect: Rect2) -> void:
	_scan_view.add_child(label)
	label.position = rect.position
	label.size = rect.size


## A layer over the whole monitor, taking no clicks.
func _layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = size
	add_child(layer)
	return layer


## A hung part (a rod, the shade): `color` with an ink outline on its sides and foot.
func _draw_hung(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Palette.INK)
	var inside: Vector2 = rect.size - Vector2(2 * OUTLINE, OUTLINE)
	draw_rect(Rect2(rect.position + Vector2(OUTLINE, 0), inside), color)


func _place(label: Label, rect: Rect2) -> void:
	var at: Rect2 = local(rect)
	_rects[label] = at
	label.position = at.position
	label.size = at.size


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


## A tween on the count-up's clock (the LED beat's make_tween, which CountUp sets to its
## tween_maker()), for the bay's per-beat motion; the monitor's own outside a count-up.
func _count_tween() -> Tween:
	return led.beat().new_tween()


static func _clear(layer: Control) -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
