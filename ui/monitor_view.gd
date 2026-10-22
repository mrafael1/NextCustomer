class_name MonitorView
extends Control
## The hung monitor (#80, mock-up B2; ShiftStage.MONITOR_RECT): two rods from the ceiling, the
## shade under it, a rubber bezel with a little bevel and the paper screen, drawn flat in code
## (its art lands in a later step). The scanner bay (ScannerBay, BAY_RECT) stands at the paper's
## left in every mode (the monitor bay follow-up of #86, mock-up monitor_bay_v1.html, the user's
## decision of 2026-10-21): in planning it shows belt slot 1's item under NEXT (show_next, which the
## shift screen calls on every refresh) or, while a hover-hold scan holds an item, that item under
## SCAN (show_scan; ScannerBay.show_planning), and in the count the item at the belt's scanner.
## The rest of the screen, right of the bay (x 615 to 893, centre 754), shows one of four things
## (mode()):
## - CHANNEL (planning with nothing scanned, show_channel; the user's play test of 2026-10-17):
##   the store channel (MonitorChannel, CHANNEL_RECT): the shift's brief, the owned upgrades and the
##   coupons in play, a slide at a time; the LED is hidden (the projected total is on the receipt
##   and the top bar's SPEND chip);
## - IDLE (the impulse rack, and a notice in planning): the notices (NoticeLabel) at NOTICE_RECT;
##   the LED's compact layout only when it shows a projected total (no longer in the game: a blank
##   LED is hidden);
## - SCAN (a belt or hand item fully scanned: ScanController calls show_scan): the bay shows the
##   item and its kind (COUPON, or its base price), and beside it (TEXT_RECT) its name, "pays €N"
##   for a belt item, its tag line, its rule text and, for a belt item, its step lines as the caller
##   words them (ScanFooter), in the largest of the TIERS sizes that shows every line; on the
##   smallest, lines that don't fit fold into "+N more";
## - COUNT (the count-up: the LED shows SUBTOTAL or TOTAL in its count layout; #86 v6's scan
##   count-up, mock-up count_up_86_v6_scan.html): the bay follows the beats (follow_beat on
##   CountUp's beat_started: the item, its name and each beat's landing sticker), the LED's number
##   and plain gold € as one group centred in LED_COUNT_RECT (the € as tall as the digits, 6 px
##   after them, LedDisplay.euro_label), the to-go line under them (TO_GO_RECT) that the SPEND MET
##   stamp (STAMP_RECT) replaces at the quota, the "+€N" tab beside the stamp (OverTab), over a
##   sunburst on the whole paper centred on the group (Sunburst, SUNBURST_CENTRE, behind them all).
##   The count starts with slot 1's item already in the bay (no first drop-in). The TOTAL keeps that
##   layout. The monitor follows the count-up (follow): its rides and beats move the bay's items,
##   tag and queue (round 7, count_up_86_v7_bay.html). As each payout's roll starts (on the LED's
##   first higher reading) the tag turns gold and one gold "+€N" chip (TallyChips) flies from it
##   into the digits' middle; as it lands a few gold drops hop from the gap before the € into the €
##   (TankBurst.pour, the stage's layer over the top bar). At the quota (CountUp's quota_met) the
##   bay's light, fan and pips turn green and its sticker is knocked off, the sunburst turns gold,
##   grows and spins, the gold bursts from the € (TankBurst's jets, coins and splashes, with a shake
##   of the monitor), the SPEND MET stamp slams STAMP_DELAY_S later (shaking the monitor STAMP_SHAKE
##   px as it lands) and the "+€N" tab comes in; each later payout spurts and punches the tab as its
##   pour lands (TankBurst.POUR_S after its chip). A resumed checkout shows the end state at once
##   (quota_met without a pop, show_end_state): no particles.
## A notice shows on the idle screen while it lasts, over a scan and the channel too (they come
## back once it has faded), never over the count. The channel runs only while it is shown, and
## comes back on the slide it was on. The monitor follows the LED's mode (mode_changed) and the
## notice (showing_changed) itself; ScanController and the shift screen fill it. Display only:
## every amount and line is the caller's (or the LED's, from core's ShiftMargin).
##
## Text never carries the pixel material; the art does. Reduced motion (`reduced_motion`) leaves
## out the bay's motion (its drop, wobble, slide-out, flash, slap and knock-off; planning's swaps
## cut), the chips, the sunburst's turn, the pour, the burst's particles (a few still splashes on
## the bezel instead), the shakes, the stamp's slam and the tab's pop and punches; the states all
## stay.

enum Mode { IDLE, SCAN, COUNT, CHANNEL }

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
## The SPEND MET stamp slams this long after the burst (real time), shaking the monitor
## STAMP_SHAKE px over STAMP_SHAKE_S as it lands.
const STAMP_DELAY_S := 0.25
const STAMP_SHAKE := 4.0
const STAMP_SHAKE_S := 0.25
## A notice (planning's, with the channel off the screen, and the impulse rack's): in the right
## part's middle.
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
## The scan's text: the name row (with "pays €N" at its right), the tag row, the gaps.
const NAME_HEIGHT := 26.0
const NAME_SIZES: Array[int] = [20, 16]
const PAYS_WORD := "pays"
const PAYS_WORD_SIZE := 13
const PAYS_AMOUNT_SIZE := 18
const PAYS_GAP := 4.0
const NAME_GAP := 8.0
const TAG_HEIGHT := 16.0
const TAG_SIZE := 12
const RULE_GAP := 2.0
const RULE_LINE_SPACING := 0
const FOOTER_GAP := 4.0
## The rule text's and the step lines' sizes, largest first: the scan takes the first that shows
## every step line.
const TIERS: Array[Vector2i] = [Vector2i(13, 12), Vector2i(12, 11), Vector2i(11, 10)]
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

var _notice_holder: Control
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
## The count met the quota (quota_met); a payout waiting to rise (the beat's, sent on the
## reading's first rise) with its chip's flight and whether it spurts (a payout after the quota),
## each chip in flight's spurt, and the last reading's amount; the stamp's delayed slam.
var _met: bool = false
var _pour_due: int = 0
var _chip_s: float = 0.0
var _spurt_due: bool = false
var _spurts: Dictionary[int, bool] = {}
var _last_amount: int = 0
var _met_motion: Tween
var _scanning: bool = false
## Planning's bay (show_next, show_scan): belt slot 1's item (null when empty), the belt's slots
## and filled ones, and the held item (null with no scan).
var _next: CardDefinition
var _slots: int = 0
var _filled: int = 0
var _held: CardDefinition
var _scan_name: Label
var _scan_rule: Label
var _scan_footer: ScanFooter
## How many of the scan's first step lines are "gives" lines (show_scan).
var _scan_gives: int = 0
var _scan_tier: int = 0
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
	led = LedDisplay.new()
	led.position = local(ShiftStage.LED_RECT).position
	add_child(led)
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
	_chips.landed.connect(_on_chip_landed)
	_count_top.add_child(_chips)
	_bay.tag_holder = _count_top
	_bay.tag().place(local(Rect2(BayTag.POSITION, Vector2.ZERO)).position)
	channel = MonitorChannel.new()
	channel.reduced_motion = _wants_reduced_motion
	channel.position = local(CHANNEL_RECT).position
	channel.size = CHANNEL_RECT.size
	add_child(channel)
	_scan_view = _layer("Scan")
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
	if _scan_view.visible:
		return Mode.SCAN
	return Mode.CHANNEL if channel.visible else Mode.IDLE


## Planning's idle screen is the store channel, showing `run`'s shift (MonitorChannel's
## show_state): its number, quota and inspections, the owned upgrades and the coupons in play
## (on the belt in slot order, then in the hand). The shift screen calls it on every planning
## refresh, with the LED blank.
func show_channel(run: RunState) -> void:
	var coupons: Array[CardDefinition] = []
	for cards: Array[CardInstance] in [run.row, run.hand()]:
		for card: CardInstance in cards:
			if card.definition.is_coupon():
				coupons.append(card.definition)
	channel.show_state(
		run.shift_index + 1, run.shift_count(), run.quota(), run.inspections, run.upgrades, coupons
	)
	_channel_on = true
	_apply()


## The planning brief's sticker key (#71, H1_BUILD_SPEC.md section 7): `entries` (PlanningModel's
## key_entries; none takes the key off), shown by the channel's brief.
func set_planning_key(entries: Array[StickerSpec]) -> void:
	channel.set_key(entries)


## Planning is over (the CHECKOUT click, the impulse rack): the channel leaves the screen. The
## bay keeps its item (the count starts with it).
func end_channel() -> void:
	_channel_on = false
	_apply()


## Planning's bay (the shift screen, on every refresh): belt slot 1's item (`definition`, null for
## an empty slot 1) under NEXT, with a pip per belt slot (`slots`, the first `filled` of them
## holding items). A held scan's item shows instead while it lasts (show_scan). The impulse rack
## passes null and 0 (an empty bed). Nothing changes in the count.
func show_next(definition: CardDefinition, slots: int, filled: int) -> void:
	_next = definition
	_slots = slots
	_filled = filled
	_update_bay()


## Shows a scanned item (ScanController): `definition` (its `aisle`, or null) with its `tags`
## (on the belt the scored ones). A belt item passes its `payout` and step lines (each with
## whether it is a fizzle; the first `gives` of them are its "gives" lines, #71, their amount in
## mustard darkest); a hand item passes payout -1. Call it once the monitor is in the
## tree: the text is measured with the real font. A notice showing, or the count-up, keeps the
## scan off the screen until it ends.
func show_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	gives: int = 0
) -> void:
	_scanning = true
	_scan_gives = gives
	_held = definition
	_fill_scan(definition, aisle, tags, payout, lines, fizzles)
	_apply()
	_update_bay()


## The scan ended: the idle screen comes back, and the bay goes back to belt slot 1's item.
func end_scan() -> void:
	_scanning = false
	_held = null
	_apply()
	_update_bay()


## Follows `count_up`: its count's start (the bay's queue), its rides and beats (the bay's items,
## tag and stickers, the payouts' chips) and the quota met (see the class comment).
func follow(count_up: CountUp) -> void:
	count_up.count_started.connect(_on_count_started)
	count_up.ride.connect(_on_ride)
	count_up.beat_started.connect(_on_beat_started)
	count_up.quota_met.connect(_on_quota_met)


## A resumed checkout's end state (after CountUp's show_end_state, which met the quota or not):
## the bay with all of `views`' items paid and bagged (ALL PAID, DONE), no chips or particles.
## `_plan` is the count-up's.
func show_end_state(_plan: CountUpPlan, views: Array[CardView]) -> void:
	_bay.show_end_state(views.size(), _met)
	_chips.clear()
	_pour_due = 0
	if tank_burst != null:
		tank_burst.clear()


## The scan's name label, rule label and step lines (while a scan was shown), and the size tier
## it took (an index into TIERS).
func scan_name_label() -> Label:
	return _scan_name


func scan_rule_label() -> Label:
	return _scan_rule


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
	for layer: Control in [_notice_holder, channel, _scan_view, _bay_layer, _count_view]:
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
	# A blank LED stays off the screen (the impulse rack): the bay has its place.
	var projected: bool = led.mode() == LedDisplay.Mode.PROJECTED
	led.visible = counting or (projected and not scanning and not channel_idle)
	_notice_holder.visible = not counting and not scanning
	var notice_rect: Rect2 = local(ShiftStage.NOTICE_RECT if led.visible else NOTICE_RECT)
	_rects[notice_label] = notice_rect
	notice_label.position = notice_rect.position
	_scan_view.visible = scanning
	channel.visible = channel_idle and not scanning and not notice_label.is_showing()
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
		# Planning's belt is spent: the next planning shows an empty bay until the screen says.
		_next = null
		_slots = 0
		_filled = 0
	elif led_mode != LedDisplay.Mode.TOTAL and not _bay.is_planning():
		_bay.reset()
	if led_mode != LedDisplay.Mode.TOTAL:
		_sunburst.set_met(false)
		_met = false
		_pour_due = 0
		_spurts.clear()
		_last_amount = 0
		_chips.clear()
		_tab.reset()
		_stop_met_motion()
		if tank_burst != null:
			tank_burst.clear()
	_apply()
	_update_bay()


## The LED's reading: the tab follows it; the first rise after a payout's beat turns the bay's tag
## gold and sends its chip into the digits (none under reduced motion).
func _on_reading(amount: int, quota: int, met: bool) -> void:
	_tab.set_reading(amount, quota, met)
	if amount > _last_amount and _pour_due > 0 and _counting():
		_bay.pay()
		if not _wants_reduced_motion():
			var tag: BayTag = _bay.tag()
			var from: Vector2 = tag.send_point() if tag.visible else _bay.landing_point()
			var chip: int = _chips.fly(
				_pour_due, from, led.digits_text_rect().get_center(), _chip_s
			)
			_spurts[chip] = _spurt_due
		_pour_due = 0
	_last_amount = amount


## A chip lands in the digits: the gold hops from the gap before the € into it; a payout after
## the quota spurts and punches the tab as its pour lands (TankBurst.POUR_S later, real time).
func _on_chip_landed(amount: int, chip: int) -> void:
	var spurt: bool = _spurts.get(chip, false)
	_spurts.erase(chip)
	if not _counting():
		return
	if tank_burst != null:
		tank_burst.pour(TankBurst.pour_point(led), amount)
		if spurt:
			tank_burst.spurt(amount, TankBurst.POUR_S)
	if spurt and is_inside_tree():
		create_tween().tween_callback(_punch_tab).set_delay(TankBurst.POUR_S)


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
		_pour_due = beat.payout
		_chip_s = clampf(beat.roll_ms / 1000.0, ReceiptFly.FLIGHT_MIN, ReceiptFly.FLIGHT_MAX)
		_spurt_due = _met


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
	if tank_burst != null:
		tank_burst.burst()
	if _wants_reduced_motion() or not is_inside_tree():
		stamp.slam(true)
		return
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


func _on_notice_showing(_showing: bool) -> void:
	_apply()


## Builds the scan's text (show_scan) in the first of TIERS whose step lines all show (the bay
## shows the item's art and kind).
func _fill_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool]
) -> void:
	for tier: int in range(TIERS.size()):
		_clear(_scan_view)
		_scan_tier = tier
		var fits: bool = _build_scan(definition, aisle, tags, payout, lines, fizzles, TIERS[tier])
		if fits:
			return


## The scan's text at `sizes` (the rule's, the step lines') in TEXT_RECT. Returns whether
## everything shows inside it, no step line folded.
func _build_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	sizes: Vector2i
) -> bool:
	var column: Rect2 = local(TEXT_RECT)
	var name_width: float = column.size.x
	if payout >= 0:
		name_width -= _add_pays(payout, column) + NAME_GAP
	_scan_name = UiKit.display_label(definition.display_name, NAME_SIZES[0], false)
	_scan_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_scan_name, Rect2(column.position, Vector2(name_width, NAME_HEIGHT)))
	for name_size: int in NAME_SIZES:
		_scan_name.add_theme_font_size_override("font_size", name_size)
		if _scan_name.get_minimum_size().x <= name_width:
			break
	var y: float = column.position.y + NAME_HEIGHT
	var tag_text: String = ScanPopup.tag_line(tags, definition, aisle)
	if not tag_text.is_empty():
		var tag: Label = UiKit.body_label(tag_text, TAG_SIZE, Palette.GREY_DARK)
		_add(tag, Rect2(column.position.x, y, column.size.x, TAG_HEIGHT))
		# One TAG_HEIGHT row; a tag line too wide for it wraps.
		if tag.get_minimum_size().x > column.size.x:
			tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tag.size = Vector2(column.size.x, 1.0)
			tag.size.y = tag.get_minimum_size().y
		y += maxf(tag.size.y, TAG_HEIGHT)
	_scan_rule = UiKit.body_label(definition.rule_text, sizes.x, Palette.INK)
	_scan_rule.add_theme_constant_override("line_spacing", RULE_LINE_SPACING)
	_scan_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(_scan_rule, Rect2(column.position.x, y + RULE_GAP, column.size.x, 1.0))
	_scan_rule.size.y = _scan_rule.get_minimum_size().y
	y = _scan_rule.position.y + _scan_rule.size.y
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
