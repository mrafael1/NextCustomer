class_name MonitorView
extends Control
## The hung monitor (#80, mock-up B2; ShiftStage.MONITOR_RECT): two rods from the ceiling, the
## shade under it, a rubber bezel with a little bevel and the paper screen, drawn flat in code
## (its art lands in a later step). Its screen shows one of four things (mode()):
## - CHANNEL (planning with nothing scanned, show_channel; the user's play test of 2026-10-17):
##   the store channel (MonitorChannel): the shift's brief, the owned upgrades and the coupons in
##   play, a slide at a time; the LED is hidden (the projected total is on the receipt and the
##   top bar's SPEND chip);
## - IDLE (the impulse rack, and a notice in planning): the LED (LedDisplay, compact, blank in the
##   rack) and the notices (NoticeLabel) under it; in planning the notice alone, at the screen's
##   middle (NOTICE_CHANNEL_RECT);
## - SCAN (a belt or hand item fully scanned: ScanController calls show_scan): the item's art
##   (ItemView's item_art), its kind under it (COUPON, or its base price), and beside it its
##   name, "pays €N" for a belt item, its tag line, its rule text and, for a belt item, its step
##   lines as the caller words them (ScanFooter), in the largest of the TIERS sizes that shows
##   every line; on the smallest, lines that don't fit fold into "+N more";
## - COUNT (the count-up: the LED shows SUBTOTAL or TOTAL in its count layout; #86 v6's scan
##   count-up, mock-up count_up_86_v6_scan.html): the scanner bay at the left (ScannerBay,
##   BAY_RECT: the item at the belt's scanner, its name and each beat's landing sticker; follow_beat
##   on CountUp's beat_started), the LED's number column in the middle (LED_COUNT_RECT: the gold
##   digits, with the to-go line under them that the SPEND MET stamp replaces at the quota, LedBeat)
##   and the big € tank at the right (EuroTank, TANK_RECT, fed by the LED's reading_changed), over
##   a sunburst on the whole paper (Sunburst, behind them all). The TOTAL keeps that layout.
##   The monitor follows the count-up (follow): its rides and beats move the bay's items, tag and
##   queue (round 7, count_up_86_v7_bay.html). As each payout's roll starts (on the LED's first
##   higher reading) the tag turns gold and one gold "+€N" chip (TallyChips) flies from it into the
##   number; as it lands the gold pours from the number (POUR_POINT) into the tank (TankBurst, the
##   stage's layer over the top bar), whose level follows EuroTank.LAG_S later. At the quota
##   (CountUp's quota_met) the bay's light, fan and pips turn green and its sticker is knocked
##   off, the sunburst turns gold and spins, the tank bursts (its blink and kick, and TankBurst's
##   jets, coins and splashes, with a shake of the monitor), the SPEND MET stamp slams
##   STAMP_DELAY_S later (shaking the monitor STAMP_SHAKE px as it lands) and the "+€N" tab
##   (OverTab) comes in on the tank; each later payout spurts and punches the tab as its gold
##   reaches the tank. A resumed checkout shows the end state at once (quota_met without a pop,
##   show_end_state): no particles.
## A notice shows on the idle screen while it lasts, over a scan and the channel too (they come
## back once it has faded), never over the count. The channel runs only while it is shown, and
## comes back on the slide it was on. The monitor follows the LED's mode (mode_changed) and the
## notice (showing_changed) itself; ScanController and the shift screen fill it. Display only:
## every amount and line is the caller's (or the LED's, from core's ShiftMargin).
##
## Text never carries the pixel material; the art does. Reduced motion (`reduced_motion`) leaves
## out the bay's motion (its drop, wobble, slide-out, flash, slap and knock-off), the chips, the
## tank's motion and lag, the sunburst's turn, the pour, the burst's particles (a few still
## splashes on the bezel instead), the shakes, the stamp's slam and the tab's pop and punches; the
## states all stay.

enum Mode { IDLE, SCAN, COUNT, CHANNEL }

## The parts' rects, in stage coordinates (the view stands at MONITOR_RECT's position): the
## screen's content inside its ink border and padding, the art and the kind under it, and the
## text column beside the art.
const CONTENT_RECT := Rect2(505, 85, 382, 138)
const ART_RECT := Rect2(505, 85, 96, 96)
const KIND_RECT := Rect2(505, 185, 96, 18)
const TEXT_RECT := Rect2(611, 85, 276, 138)
## The count view's parts (stage coordinates), all on the paper (PAPER_RECT): the scanner bay,
## the LED's number column (its digits' box; the to-go line under it at TO_GO_RECT, the SPEND MET
## stamp over that at STAMP_RECT) and the € tank; the sunburst over the whole paper, centred on
## the digits.
const PAPER_RECT := Rect2(495, 77, 402, 154)
const BAY_RECT := Rect2(499, 79, 112, 150)
const LED_COUNT_RECT := Rect2(613, 93, 160, 86)
const TO_GO_RECT := Rect2(613, 185, 160, 24)
const STAMP_RECT := Rect2(615, 183, 156, 30)
const TANK_RECT := Rect2(773, 79, 120, 150)
const SUNBURST_CENTRE := Vector2(693, 137)
## The tag's chips land in the number at NUMBER_POINT; the gold pours on from the digits' upper
## right, POUR_POINT (stage coordinates).
const NUMBER_POINT := Vector2(693, 127)
const POUR_POINT := Vector2(741, 111)
## The SPEND MET stamp slams this long after the burst (real time), shaking the monitor
## STAMP_SHAKE px over STAMP_SHAKE_S as it lands.
const STAMP_DELAY_S := 0.25
const STAMP_SHAKE := 4.0
const STAMP_SHAKE_S := 0.25
## A notice in planning, with the channel off the screen: at the content's middle.
const NOTICE_CHANNEL_RECT := Rect2(500, 132, 392, 44)
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
const KIND_SIZE := 13
const RULE_GAP := 2.0
const RULE_LINE_SPACING := 0
const FOOTER_GAP := 4.0
const COUPON_TEXT := "COUPON"
const BASE_TEXT := "BASE €%d"
## The rule text's and the step lines' sizes, largest first: the scan takes the first that shows
## every step line.
const TIERS: Array[Vector2i] = [Vector2i(13, 12), Vector2i(12, 11), Vector2i(11, 10)]
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The LED and the notices on the screen (the stage hands them to the shift screen).
var led: LedDisplay
var notice_label: NoticeLabel
## The store channel (planning's idle screen, at CONTENT_RECT).
var channel: MonitorChannel
## The stage's layer for the gold outside the monitor (the pour, the burst, the spurts and the
## shakes); set by ShiftStage, it takes the tank, this monitor and the reduced motion setting.
var tank_burst: TankBurst:
	set(value):
		tank_burst = value
		if value != null:
			value.reduced_motion = _wants_reduced_motion
			value.bind(_tank, self)

var _notice_holder: Control
## The channel is planning's idle screen (show_channel, until end_channel).
var _channel_on: bool = false
var _scan_view: Control
## The count view: the tank and the bay; over the LED, the landing stickers' layer (clipped to the
## paper); behind them all, the sunburst.
var _count_view: Control
var _count_top: Control
var _sunburst: Sunburst
var _bay: ScannerBay
var _tank: EuroTank
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
	_count_view = _layer("Count")
	_tank = EuroTank.new()
	_tank.position = local(TANK_RECT).position
	_tank.reduced_motion = _wants_reduced_motion
	_count_view.add_child(_tank)
	_bay = ScannerBay.new()
	_bay.position = local(BAY_RECT).position
	_bay.reduced_motion = _wants_reduced_motion
	_bay.make_tween = _count_tween
	_count_view.add_child(_bay)
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
	channel.position = local(CONTENT_RECT).position
	channel.size = CONTENT_RECT.size
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


## Planning is over (the CHECKOUT click, the impulse rack): the channel leaves the screen.
func end_channel() -> void:
	_channel_on = false
	_apply()


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
	_fill_scan(definition, aisle, tags, payout, lines, fizzles)
	_apply()


## The scan ended: the idle screen comes back.
func end_scan() -> void:
	_scanning = false
	_apply()


## Follows `count_up`: its count's start (the bay's queue), its rides and beats (the bay's items,
## tag and stickers, the payouts' chips) and the quota met (see the class comment).
func follow(count_up: CountUp) -> void:
	count_up.count_started.connect(_on_count_started)
	count_up.ride.connect(_on_ride)
	count_up.beat_started.connect(_on_beat_started)
	count_up.quota_met.connect(_on_quota_met)


## A resumed checkout's end state (after CountUp's show_end_state, which met the quota or not):
## the bay with all of `views`' items paid and bagged (ALL PAID, DONE), the tank at rest on its
## level, no chips or particles. `_plan` is the count-up's.
func show_end_state(_plan: CountUpPlan, views: Array[CardView]) -> void:
	_bay.show_end_state(views.size(), _met)
	_tank.settle()
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


## The count view's scanner bay, € tank and sunburst.
func bay() -> ScannerBay:
	return _bay


func tank() -> EuroTank:
	return _tank


func sunburst() -> Sunburst:
	return _sunburst


## The "+€N" tab on the tank, and the tag's chips.
func over_tab() -> OverTab:
	return _tab


func chips() -> TallyChips:
	return _chips


## The art shown for the scan, or null.
func scan_art() -> TextureRect:
	return _art_in(_scan_view)


## Every text label the screen shows now (the LED's aside), for layout checks.
func shown_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for layer: Control in [_notice_holder, channel, _scan_view, _count_view]:
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
	led.visible = not scanning and not channel_idle
	_notice_holder.visible = not counting and not scanning
	var notice_rect: Rect2 = local(NOTICE_CHANNEL_RECT if channel_idle else ShiftStage.NOTICE_RECT)
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


## A count-up starts over (start_count), or the LED leaves the count: the bay idle, the sunburst
## not met, the tab off, the gold outside gone and the monitor at rest.
func _on_led_mode(led_mode: LedDisplay.Mode) -> void:
	if led_mode != LedDisplay.Mode.TOTAL:
		_bay.reset()
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


## The LED's reading: the tab and the tank follow it; the first rise after a payout's beat turns
## the bay's tag gold and sends its chip into the number (none under reduced motion), the tank
## holding its gains until the chip lands.
func _on_reading(amount: int, quota: int, met: bool) -> void:
	_tab.set_reading(amount, quota, met)
	if amount > _last_amount and _pour_due > 0 and _counting():
		_bay.pay()
		if not _wants_reduced_motion():
			var tag: BayTag = _bay.tag()
			var from: Vector2 = tag.send_point() if tag.visible else _bay.landing_point()
			_tank.hold()
			var chip: int = _chips.fly(_pour_due, from, _global(NUMBER_POINT), _chip_s)
			_spurts[chip] = _spurt_due
		_pour_due = 0
	_last_amount = amount
	_tank.set_reading(amount, quota, met)


## A chip lands in the number: the gold pours on into the tank (whose level follows LAG_S later);
## a payout after the quota spurts and punches the tab as it reaches the tank (EuroTank.LAG_S
## later, real time).
func _on_chip_landed(amount: int, chip: int) -> void:
	_tank.release()
	var spurt: bool = _spurts.get(chip, false)
	_spurts.erase(chip)
	if not _counting():
		return
	if tank_burst != null:
		tank_burst.pour(_global(POUR_POINT), amount)
		if spurt:
			tank_burst.spurt(amount, EuroTank.LAG_S)
	if spurt and is_inside_tree():
		create_tween().tween_callback(_punch_tab).set_delay(EuroTank.LAG_S)


## CountUp.count_started: a count of `views` starts (the bay's queue).
func _on_count_started(views: Array[CardView]) -> void:
	_views = views
	_bay.start(views.size())


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
	_tank.burst()
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


## A point in stage coordinates, global (the monitor shaking with it).
func _global(point: Vector2) -> Vector2:
	return get_global_transform() * (point - ShiftStage.MONITOR_RECT.position)


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


## Builds the scan's content (show_scan) in the first of TIERS whose step lines all show.
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


## The scan's content at `sizes` (the rule's, the step lines'). Returns whether everything shows
## inside CONTENT_RECT, no step line folded.
func _build_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	sizes: Vector2i
) -> bool:
	var art: TextureRect = ItemView.item_art(definition)
	art.position = local(ART_RECT).position
	_scan_view.add_child(art)
	var kind: Label
	if definition.is_coupon():
		kind = UiKit.display_label(COUPON_TEXT, KIND_SIZE, false)
		kind.add_theme_color_override("font_color", Palette.VELVET)
	else:
		kind = UiKit.number_label(BASE_TEXT % definition.base, KIND_SIZE, false)
		kind.add_theme_color_override("font_color", Palette.INK_LIGHT)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(kind, local(KIND_RECT))
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
	var bottom: float = local(CONTENT_RECT).end.y
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


static func _art_in(layer: Control) -> TextureRect:
	for child: Node in layer.get_children():
		if child is TextureRect and not child.is_queued_for_deletion():
			return child as TextureRect
	return null


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
