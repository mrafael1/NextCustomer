class_name ScannerBay
extends Control
## The scanner bay on the monitor (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html; round
## 7's TALLY, ALIVE and QUEUE, count_up_86_v7_bay.html; MonitorView.BAY_RECT, on the screen in every
## mode since the monitor bay follow-up, mock-up monitor_bay_v1.html): in the count the item at the
## belt's scanner, in planning belt slot 1's item or the held one (show_planning, below), shown
## big. A teal panel with an ink
## header (the queue, BayQueue: "4 LEFT", LAST, DONE and a pip per item, beside the scan light),
## the scan bed (BayBed: the item's art at 2x, alive, in gold corners), the item's name on a paper
## label under it ("–" between items, "THANK YOU" at the end) and its price tag (BayTag) hung off
## the top right, toward the number.
##
## The count-up's rides (ride, CountUp.ride) move the items: the item in the bay slides out toward
## the bag (OUT_SHARE of the ride, at most BayBed.OUT_S; its tag and sticker with it), the next one
## drops in as the belt brings it, and its pip turns gold once it is in the bag; after the last,
## the bed reads "ALL PAID" and the header DONE. Each scan group's opening beat (follow_beat) scans
## its item: the scan light blinks tomato light for LIGHT_S (green light once met), the bed's laser
## fan sweeps it and BEEP! pops up, and its tag shows its worth on paper. Each beat on the scanned
## item slaps its landing sticker (landing_spec: a cream price label for a plain or base beat, a
## cream "+N" for a bonus, a gold "×N" starburst for a stamp, a grey label for a denial or a
## fizzle, none for a payout) over the bay's bottom-right corner (STICKER_CORNER), from SLAP_FROM
## through SLAP_UNDER to its size, wobbling the item; the tag counts to the step's value_after
## (gold on a gain, paper on a denial) and turns gold as the payout rises (pay). That motion runs
## on make_tween's tweens (the count-up's, so it follows its taps, holds and hit-stops). At the
## quota knock_off() sends the sticker flying off, left and up, spinning, on the bay's own
## real-time tween. Reduced motion (`reduced_motion`) keeps every state (the item shows at its
## opening beat and goes at once) and drops the motion.
##
## In planning (show_planning) the header reads NEXT over belt slot 1's item (its name on the
## label; an empty bed and GONE_NAME when slot 1 is empty) with a pip per belt slot (BayQueue
## show_slots; SCANNER with no belt, the impulse rack's), or SCAN while a hover-hold scan holds an
## item (belt or hand): that item, its kind on a cream label (KIND_COUPON_TEXT, KIND_BASE_TEXT), the
## fan and BEEP, the light on in HELD_COLOR.
## When the item to show changes, the one in the bay slides out over PLAN_OUT_S and the new one
## drops in (BayBed.FALL_S); the label keeps the old item's text until it has slid out, is blank
## while the new one falls and shows its text once it has landed (the header follows the label). A
## hold on the item already in the bay just scans it (fan, BEEP, wobble), with no drop. Planning's
## motion runs on the bay's own tweens. start() (the count) keeps the item in the bay when it is the
## count's first one, so the first scan needs no drop-in. Reduced motion swaps at once.
##
## The landing sticker is drawn on `sticker_parent` when set (the monitor's layer over the digits),
## else on the bay; the tag on `tag_holder` (the monitor's top layer), else on the bay at TAG_AT.
## Display only: the item, the beat and its step are the count-up's; the stickers' and the tag's
## numbers are the steps' (StickerSpec, ScoreStep.value_after).

## The bay's size, and its parts in its own coordinates: the header (inside the BORDER-wide ink
## border), the scan light (7x7 inside a one-pixel ink ring), the header's text from
## HEADER_TEXT_X, the scan bed (its BED_BORDER-wide dark border included), the art over the bed's
## inside, the name label and the tag's place.
const SIZE := Vector2(112, 150)
const BORDER := 2
const HEADER_RECT := BayQueue.RECT
const LIGHT_RECT := Rect2(8, 6, 7, 7)
const HEADER_TEXT_X := BayQueue.TEXT_X
const BED_RECT := Rect2(6, 19, 100, 100)
const BED_BORDER := BayBed.BORDER
const ART_RECT := Rect2(8, 21, 96, 96)
const NAME_RECT := Rect2(6, 123, 100, 20)
const TAG_AT := Vector2(66, 23)
## The panel's foot (a dark band over its bottom border) and its shadow (ink at SHADOW_ALPHA,
## down and right; it stays on the monitor's paper).
const FOOT := 4
const SHADOW := 2
const SHADOW_ALPHA := 0.3
const HEADER_TEXT := BayQueue.IDLE_TEXT
## The header's words in the body font (Atkinson Hyperlegible Next) at HEADER_WEIGHT,
## BayQueue.FONT_SIZE px, HEADER_SPACING px apart (mock-up count_up_86_v7_bay.html's 800 9 px,
## letter-spacing 2 px), drawn by header_font() from the raster import, not an MSDF. Pixelify Sans
## read badly this small: its C as O ("SOANNER"), its 5 as S and its T as an arrow.
const HEADER_FONT_SIZE := BayQueue.FONT_SIZE
const HEADER_WEIGHT := 800
const HEADER_SPACING := 2
## The name: the display font, NAME_SPACING px apart, in the first of NAME_SIZES that fits the
## label's inside on one line (trimmed past the smallest), on paper in a NAME_BORDER ink border;
## GONE_NAME between items, END_NAME once all are bagged.
const NAME_SIZES: Array[int] = [12, 11, 10, 9]
const NAME_SPACING := 1
const NAME_BORDER := 2
const GONE_NAME := "–"
const END_NAME := "THANK YOU"
## The item in the bay slides out over this share of a ride (at most BayBed.OUT_S; all of the
## last ride's), and the next one falls over the rest (at most BayBed.FALL_S).
const OUT_SHARE := 0.5
## Planning's swap: the item in the bay slides out over PLAN_OUT_S, then the next one drops in.
const PLAN_OUT_S := 0.12
## A held item's kind on the label (as the scan's art used to say it), on cream in dark tomato.
const KIND_COUPON_TEXT := "COUPON"
const KIND_BASE_TEXT := "BASE €%d"
const KIND_FACE_COLOR := Palette.CREAM
const KIND_INK_COLOR := Palette.TOMATO_DARK
## The scan light while an item is held in planning (after its blink).
const HELD_COLOR := Palette.TOMATO
## An opening beat: the light blinks (on and off LIGHT_BLINK_HZ times a second) for LIGHT_S.
const LIGHT_S := 0.35
const LIGHT_BLINK_HZ := 10.0
## The landing sticker: its bottom-right corner (bay coordinates; stage (623,195)), turned by the
## next of STICKER_TILTS each beat, slapped from SLAP_FROM to SLAP_UNDER over SLAP_IN_S, then to
## its size over SLAP_SETTLE_S, about its centre.
const STICKER_CORNER := Vector2(124, 116)
const STICKER_TILTS: Array[float] = [-6.0, 5.0, -4.0, 6.0, -5.0, 4.0]
const SLAP_FROM := 1.8
const SLAP_UNDER := 0.92
const SLAP_IN_S := 0.1
const SLAP_SETTLE_S := 0.1
## The knock-off: KNOCK_S seconds from KNOCK_VELOCITY px per second, falling at KNOCK_GRAVITY px
## per second squared, spinning KNOCK_SPIN degrees per second.
const KNOCK_S := 0.45
const KNOCK_VELOCITY := Vector2(-200, -140)
const KNOCK_GRAVITY := 1400.0
const KNOCK_SPIN := -300.0
const PANEL_COLOR := Palette.PANEL
const FOOT_COLOR := Palette.BACKGROUND
const HEADER_COLOR := Palette.INK
const LIGHT_OFF_COLOR := Palette.TOMATO_DARKEST
const LIGHT_ON_COLOR := Palette.TOMATO_LIGHT
const LIGHT_MET_COLOR := Palette.GREEN_LIGHT
const NAME_FACE_COLOR := Palette.PAPER
const NAME_INK_COLOR := Palette.INK

static var _header_font: FontVariation

## Returns a new tween on the count-up's clock (MonitorView hands it the count-up's, through the
## LED's beat); none means the bay's own.
var make_tween: Callable = Callable():
	set(value):
		make_tween = value
		if _bed != null:
			_bed.make_tween = value
			_tag.make_tween = value
## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable():
	set(value):
		reduced_motion = value
		if _bed != null:
			_bed.reduced_motion = value
			_tag.reduced_motion = value
## Where the landing sticker is drawn (the monitor's layer over the digits); none means the bay.
var sticker_parent: Control
## Where the tag hangs (the monitor's top layer; its caller places it there); none means the bay.
var tag_holder: Control:
	set(value):
		tag_holder = value
		if _tag != null:
			_tag.get_parent().remove_child(_tag)
			(value if value != null else self as Control).add_child(_tag)

var _queue: BayQueue
var _bed: BayBed
var _tag: BayTag
var _name: Label
var _sticker: EffectSticker
## The landing sticker's place at rest (its parent's coordinates).
var _sticker_rest: Vector2 = Vector2.ZERO
## The sticker the knock-off is flying away, until its tween frees it.
var _knocked: EffectSticker
## The item in the bed (its slot; -1 for none) and whether it is a coupon (no tag at €0).
var _bed_slot: int = -1
var _coupon: bool = false
var _met: bool = false
var _light_on: bool = false
## Beats slapped since the last reset (they pick the sticker's tilt).
var _slaps: int = 0
var _motion: Tween
var _ride: Tween
var _slap: Tween
var _knock: Tween
## The name label's faces: the name's (paper) and a held item's kind (cream).
var _name_face: StyleBoxFlat
var _kind_face: StyleBoxFlat
## Planning (show_planning): on, the item wanted in the bay and whether it is held (a scan), the
## item in the bed scanned (its kind on the label), a swap's slide-out running, the drop's landing
## pending, and whether the label (so the header) shows a scan.
var _planning: bool = false
var _want: CardDefinition
var _want_scan: bool = false
var _scanned: bool = false
var _swapping: bool = false
var _land: Tween
var _label_scan: bool = false
## Planning's belt: its slots and how many hold items (the header's pips).
var _slots: int = 0
var _filled: int = 0


func _init() -> void:
	name = "ScannerBay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_queue = BayQueue.new()
	add_child(_queue)
	_bed = BayBed.new()
	_bed.position = BED_RECT.position
	_bed.emptied.connect(_on_emptied)
	add_child(_bed)
	_name = UiKit.display_label("", NAME_SIZES[0], false)
	_name.add_theme_font_override("font", ArtStyle.spaced_display_font(NAME_SPACING))
	_name.add_theme_color_override("font_color", NAME_INK_COLOR)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_face = _face(NAME_FACE_COLOR)
	_kind_face = _face(KIND_FACE_COLOR)
	_name.add_theme_stylebox_override("normal", _name_face)
	_name.position = NAME_RECT.position
	_name.size = NAME_RECT.size
	add_child(_name)
	_tag = BayTag.new()
	_tag.place(TAG_AT)
	add_child(_tag)


func _ready() -> void:
	_name.position = NAME_RECT.position
	_name.size = NAME_RECT.size
	_fit_name()


func _process(_delta: float) -> void:
	if not _bed.is_leaving():
		return
	var pose: BayBed.BayPose = _bed.out_offset()
	_tag.follow_out(pose)
	if _sticker != null:
		_sticker.position = _sticker_rest + pose.offset
		_sticker.rotation_degrees = pose.rotation_deg
		_sticker.modulate.a = pose.alpha


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var shadow: Color = Color(Palette.INK, SHADOW_ALPHA)
	draw_rect(Rect2(SIZE.x, SHADOW, SHADOW, SIZE.y), shadow)
	draw_rect(Rect2(SHADOW, SIZE.y, SIZE.x - SHADOW, SHADOW), shadow)
	draw_rect(rect, Palette.INK)
	var inside: Rect2 = rect.grow(-BORDER)
	draw_rect(inside, PANEL_COLOR)
	draw_rect(Rect2(inside.position.x, inside.end.y - FOOT, inside.size.x, FOOT), FOOT_COLOR)
	draw_rect(HEADER_RECT, HEADER_COLOR)
	draw_rect(LIGHT_RECT.grow(1.0), Palette.INK)
	draw_rect(LIGHT_RECT, _light_colour())


## CountUp.ride, through MonitorView: item `scan_slot` (`definition`'s; -1 after the last) rides
## into the scanner over `seconds` while item `bag_slot` (-1 for none) hops into the bag. The item
## in the bay slides out, the next drops in to land as the belt brings it, the bagged one's pip
## turns gold at the ride's end; after the last, ALL PAID, THANK YOU and DONE. Under reduced
## motion the item in the bay goes at once and the next shows at its opening beat.
func ride(bag_slot: int, scan_slot: int, definition: CardDefinition, seconds: float) -> void:
	_stop_ride()
	# The item already in the bay (the count's first, kept from planning) stays: no drop-in.
	if scan_slot >= 0 and scan_slot == _bed_slot and _bed.has_item():
		definition = null
	var out_s: float = 0.0
	if bag_slot >= 0 and bag_slot == _bed_slot and _bed.has_item():
		out_s = minf(BayBed.OUT_S, seconds if scan_slot < 0 else seconds * OUT_SHARE)
		_bed.slide_out(out_s)
		if _reduced():
			out_s = 0.0
	# The next item drops in once the bay is empty, as late as lets it land as the belt brings it.
	var enter_at: float = maxf(out_s, seconds - BayBed.FALL_S)
	var enter: Callable = Callable()
	if scan_slot >= 0 and definition != null and not _reduced():
		enter = _enter.bind(scan_slot, definition, maxf(0.0, seconds - enter_at))
	var arrive: Callable = _arrive.bind(bag_slot, scan_slot)
	if seconds <= 0.0 or not is_inside_tree():
		if enter.is_valid():
			enter.call()
		arrive.call()
		return
	_ride = _new_tween()
	var waited: float = 0.0
	if enter.is_valid():
		if enter_at <= 0.0:
			enter.call()
		else:
			_ride.tween_interval(enter_at)
			_ride.tween_callback(enter)
			waited = enter_at
	_ride.tween_interval(maxf(0.0, seconds - waited))
	_ride.tween_callback(arrive)


## A count of `items` starts: the queue reads "n LEFT". When the bay holds `first` (the count's
## first item, from planning, at rest or still landing) it stays there at rest with its name, as
## slot 0's: its first scan needs no drop-in. Else the bed is empty, the name blank.
func start(items: int, first: CardDefinition = null) -> void:
	var keep: bool = (
		first != null and not _swapping and _bed.has_item() and _bed.shown_definition() == first
	)
	reset(keep)
	_queue.start(items)
	if keep:
		_bed_slot = 0
		_coupon = first.is_coupon()
		_set_name(first.display_name.to_upper())


## Slaps `spec`'s landing sticker over the bay's bottom-right corner (the last one goes); none for
## a null spec, which keeps the last.
func land(spec: StickerSpec) -> void:
	if spec == null:
		return
	_drop_sticker()
	var tilt: float = STICKER_TILTS[_slaps % STICKER_TILTS.size()]
	_slaps += 1
	_sticker = EffectSticker.new(spec, tilt)
	var holder: Control = sticker_parent if sticker_parent != null else self
	holder.add_child(_sticker)
	var corner: Vector2 = get_global_transform() * STICKER_CORNER
	var at: Vector2 = holder.get_global_transform().affine_inverse() * corner - _sticker.size
	_sticker.position = at.round()
	_sticker_rest = _sticker.position
	_sticker.pivot_offset = _sticker.size / 2.0
	if _reduced() or not is_inside_tree():
		return
	_sticker.scale = Vector2.ONE * SLAP_FROM
	_slap = _new_tween()
	_slap.tween_property(_sticker, "scale", Vector2.ONE * SLAP_UNDER, SLAP_IN_S)
	_slap.tween_property(_sticker, "scale", Vector2.ONE, SLAP_SETTLE_S)


## CountUp.beat_started, through MonitorView: an opening beat scans its item (`definition`, the
## beat's view's; dropped in now if no ride brought it) and hangs its tag at the step's worth;
## each beat on the scanned item slaps its landing sticker (landing_spec), wobbles the item and
## counts its tag to the step's value_after. A context-pass beat before the first scan leaves the
## bay idle; a beat on another item (a bagged one's fizzle) changes nothing.
func follow_beat(beat: CountUpBeat, step: ScoreStep, definition: CardDefinition) -> void:
	if beat.scan_slot < 0:
		return
	var own: bool = step.slot == beat.scan_slot
	if beat.opens_slot:
		if (_bed_slot != beat.scan_slot or not _bed.has_item()) and definition != null:
			_enter(beat.scan_slot, definition, 0.0)
		_queue.enter(beat.scan_slot)
		_bed.scan(_met)
		_scan_light()
		if own:
			_open_tag(step.value_after)
	if not own:
		return
	var spec: StickerSpec = landing_spec(beat, step)
	land(spec)
	if spec != null:
		_bed.wobble(SLAP_IN_S)
	match beat.kind:
		CountUpBeat.Kind.BONUS, CountUpBeat.Kind.STAMP:
			_count_tag(step.value_after, true, SLAP_IN_S)
		CountUpBeat.Kind.DENIED:
			_count_tag(step.value_after, false, SLAP_IN_S)
		CountUpBeat.Kind.PAYOUT:
			_count_tag(step.value_after, _tag.is_paid() or beat.payout > 0, 0.0)


## The scanned item's payout rises (MonitorView, on the number's first rise): its tag turns gold.
func pay() -> void:
	_tag.pay()


## The quota met (green light, fan and pips), or not.
func set_met(met: bool) -> void:
	_met = met
	_queue.set_met(met)
	_bed.set_met(met)
	queue_redraw()


## The quota's burst knocks the landing sticker off: it flies left and up, spinning, over KNOCK_S
## on the bay's own real-time tween, then goes; under reduced motion it goes at once.
func knock_off() -> void:
	if _sticker == null:
		return
	var sticker: EffectSticker = _sticker
	_sticker = null
	if _slap != null:
		_slap.kill()
		_slap = null
	sticker.scale = Vector2.ONE
	if _reduced() or not is_inside_tree():
		sticker.queue_free()
		return
	_drop_knocked()
	_knocked = sticker
	_knock = create_tween()
	_knock.tween_method(
		_fly_off.bind(sticker, sticker.position, sticker.rotation_degrees), 0.0, KNOCK_S, KNOCK_S
	)
	_knock.tween_callback(_on_knocked_off)


## Where the landing sticker sits (global): its centre, or where the next one lands's.
func landing_point() -> Vector2:
	if _sticker != null:
		return _sticker.get_global_rect().get_center()
	var half: Vector2 = EffectSticker.size_for(StickerSpec.new()) / 2.0
	return get_global_transform() * (STICKER_CORNER - half)


## A resumed checkout's end state for a row of `items`: every item bagged (ALL PAID, THANK YOU,
## DONE, every pip gold), no art, tag or sticker, the quota `met` or not, nothing moving.
func show_end_state(items: int, met: bool) -> void:
	reset()
	_queue.start(items)
	_finish()
	set_met(met)


## A new count: the bed empty (or, with `keep_item`, its item kept, at rest), no tag or sticker,
## light off, not met, the queue's count kept with none in yet, out of planning, on the count's
## clock.
func reset(keep_item: bool = false) -> void:
	_stop_ride()
	_stop_light()
	_stop_land()
	_drop_sticker()
	_drop_knocked()
	_slaps = 0
	_met = false
	_bed_slot = -1
	_coupon = false
	_planning = false
	_want = null
	_want_scan = false
	_scanned = false
	_swapping = false
	_label_scan = false
	_bed.make_tween = make_tween
	if keep_item:
		_bed.settle()
		_bed.set_met(false)
	else:
		_bed.reset()
	_tag.hide_tag()
	_queue.restart()
	_set_name("")
	queue_redraw()


## Planning (see the class comment): the bay shows `definition` (belt slot 1's item, or the held
## one when `held`; null for an empty slot 1) under NEXT or SCAN, with a pip per belt slot
## (`slots`, the first `filled` of them holding items).
func show_planning(definition: CardDefinition, held: bool, slots: int, filled: int) -> void:
	if not _planning:
		_enter_planning()
	_want = definition
	_want_scan = held and definition != null
	_slots = slots
	_filled = filled
	_queue_text()
	_sync_planning()
	queue_redraw()


## Whether the bay shows planning's items (show_planning) rather than a count's.
func is_planning() -> bool:
	return _planning


## Whether the label shows a held item's kind (the header SCAN), not a name.
func shows_scan() -> bool:
	return _label_scan


## The bay's parts: the scan bed, the price tag and the header's queue.
func bed() -> BayBed:
	return _bed


func tag() -> BayTag:
	return _tag


func queue() -> BayQueue:
	return _queue


## The name label and the landing sticker (null for none), for tests.
func name_label() -> Label:
	return _name


func landing_sticker() -> EffectSticker:
	return _sticker


func is_met() -> bool:
	return _met


## The scan light's colour now.
func light_colour() -> Color:
	return _light_colour()


## A beat's landing sticker (see the class comment), or null for none: the base price ("€N") for a
## plain or base beat, "+N" for a bonus, "×N" for a stamp, the denied payout ("€N") or "pfff" in
## grey. Pure: the numbers are the step's.
static func landing_spec(beat: CountUpBeat, step: ScoreStep) -> StickerSpec:
	var spec: StickerSpec = StickerSpec.new()
	match beat.kind:
		CountUpBeat.Kind.MERGED_PLAIN, CountUpBeat.Kind.BASE:
			spec.text = "€%d" % step.value
		CountUpBeat.Kind.BONUS:
			spec.text = "+%d" % step.value
		CountUpBeat.Kind.STAMP:
			spec.kind = StickerSpec.Kind.MULTIPLY
			spec.text = EffectLinks.token_text(step)
		CountUpBeat.Kind.DENIED:
			spec.kind = StickerSpec.Kind.FIZZLE
			spec.text = "€%d" % step.value
		CountUpBeat.Kind.FIZZLE:
			spec.kind = StickerSpec.Kind.FIZZLE
			spec.text = "pfff"
		_:
			return null
	spec.step_index = beat.steps[0]
	return spec


## The header's font: the body font at HEADER_WEIGHT, HEADER_SPACING px apart.
static func header_font() -> Font:
	if _header_font == null:
		_header_font = FontVariation.new()
		_header_font.base_font = ArtStyle.BODY_FONT
		var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		_header_font.variation_opentype = {weight: HEADER_WEIGHT}
		_header_font.spacing_glyph = HEADER_SPACING
	return _header_font


## Item `slot` (`definition`'s) drops into the bed over `fall_s`: its pip in, its name, no tag yet.
func _enter(slot: int, definition: CardDefinition, fall_s: float) -> void:
	_bed_slot = slot
	_coupon = definition.is_coupon()
	_queue.enter(slot)
	_set_name(definition.display_name.to_upper())
	_tag.hide_tag()
	_bed.drop_in(definition, fall_s)


## Planning starts: the count's tag, sticker, light and queue go; the bed keeps its item, on the
## bay's own clock.
func _enter_planning() -> void:
	_stop_ride()
	_stop_light()
	_drop_sticker()
	_drop_knocked()
	_tag.hide_tag()
	_met = false
	_bed.set_met(false)
	_bed_slot = -1
	_bed.make_tween = Callable()
	_planning = true
	_scanned = false
	_label_scan = false
	if not _bed.has_item():
		_bed.show_idle(BayBed.IDLE_TEXT)
		_set_name(GONE_NAME)


## Brings the bed to what planning wants (see the class comment): a different item slides out
## first (then _on_emptied comes back here), an empty bed takes the wanted one, the same item is
## scanned when held.
func _sync_planning() -> void:
	if _swapping:
		return
	var shown: CardDefinition = _bed.shown_definition()
	if shown != null and shown != _want:
		_stop_land()
		_swapping = true
		_bed.slide_out(PLAN_OUT_S)
		return
	if shown == null:
		if _want == null:
			_label_scan = false
			_set_name(GONE_NAME)
			_queue_text()
			return
		_drop_planning()
		return
	if _land != null:
		return
	if _want_scan and not _scanned:
		_scan_planning()
	elif not _want_scan and _scanned:
		_scanned = false
		_show_planning_label()


## The wanted item drops in: a blank label (the header saying what it is for) until it lands.
func _drop_planning() -> void:
	_scanned = false
	_label_scan = _want_scan
	_set_name("")
	_queue_text()
	_bed.drop_in(_want, BayBed.FALL_S)
	if _reduced() or not is_inside_tree():
		_on_planning_landed()
		return
	_land = create_tween()
	_land.tween_callback(_on_planning_landed).set_delay(BayBed.FALL_S)


## The dropped item landed: its label, and its scan when it is held.
func _on_planning_landed() -> void:
	_land = null
	if _want_scan:
		_scan_planning()
	else:
		_show_planning_label()


## A held item's scan in the bay: the fan, BEEP and wobble, the light's blink, its kind.
func _scan_planning() -> void:
	_scanned = true
	_bed.scan(false)
	_bed.wobble()
	_scan_light()
	_show_planning_label()


## The label for the item in the bed: its kind when scanned, else its name.
func _show_planning_label() -> void:
	var shown: CardDefinition = _bed.shown_definition()
	_label_scan = _scanned and shown != null
	if shown == null:
		_set_name(GONE_NAME)
	elif _scanned:
		_set_name(kind_text(shown), true)
	else:
		_set_name(shown.display_name.to_upper())
	_queue_text()


## The header's text in planning: SCAN while the label shows a scan (or a held item drops in),
## else NEXT over the belt (SCANNER with no belt: the impulse rack).
func _header_text() -> String:
	if _label_scan:
		return BayQueue.SCAN_TEXT
	return BayQueue.NEXT_TEXT if _slots > 0 else BayQueue.IDLE_TEXT


## The header in planning: its text over the belt's pips.
func _queue_text() -> void:
	if _planning:
		_queue.show_slots(_slots, _filled, _header_text())


func _stop_land() -> void:
	if _land != null:
		_land.kill()
		_land = null


## A held item's kind for the label: "COUPON" or "BASE €N". Pure.
static func kind_text(definition: CardDefinition) -> String:
	if definition.is_coupon():
		return KIND_COUPON_TEXT
	return KIND_BASE_TEXT % definition.base


## The name label's text (a held item's kind on the cream face when `kind`), fitted.
func _set_name(text: String, kind: bool = false) -> void:
	_name.text = text
	_name.add_theme_stylebox_override("normal", _kind_face if kind else _name_face)
	_name.add_theme_color_override("font_color", KIND_INK_COLOR if kind else NAME_INK_COLOR)
	_fit_name()


## A label face: `colour` in a NAME_BORDER ink border.
static func _face(colour: Color) -> StyleBoxFlat:
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = colour
	face.border_color = NAME_INK_COLOR
	face.set_border_width_all(NAME_BORDER)
	return face


## A ride's end: item `bag_slot` is in the bag; after the last (`scan_slot` -1), all are.
func _arrive(bag_slot: int, scan_slot: int) -> void:
	_ride = null
	if bag_slot >= 0:
		_queue.bag(bag_slot)
	if scan_slot < 0:
		_finish()


## Every item paid and bagged: ALL PAID, THANK YOU, DONE.
func _finish() -> void:
	_bed_slot = -1
	_queue.finish()
	_bed.show_idle(BayBed.END_TEXT)
	_tag.hide_tag()
	_drop_sticker()
	_set_name(END_NAME)


## The opening beat's tag: the item's worth on paper, popping; none for a coupon at €0.
func _open_tag(worth: int) -> void:
	if _coupon and worth <= 0:
		_tag.hide_tag()
		return
	_tag.show_value(worth, false)
	_tag.count_to(worth, false, SLAP_IN_S)


## A step's worth on the tag (`paid`: gold), counting after `delay`; a coupon's shows once it is
## worth something.
func _count_tag(worth: int, paid: bool, delay: float) -> void:
	if not _tag.visible and (_coupon and worth <= 0):
		return
	_tag.count_to(worth, paid, delay)


## The item left the bed: its tag and sticker go, the name reads GONE_NAME; in planning the wanted
## item comes in next.
func _on_emptied() -> void:
	_bed_slot = -1
	_tag.hide_tag()
	_drop_sticker()
	if _planning:
		_swapping = false
		_scanned = false
		_sync_planning()
		return
	_set_name(GONE_NAME)


## The opening beat's light: on (blinking, without reduced motion) for LIGHT_S.
func _scan_light() -> void:
	_stop_light()
	_light_on = true
	if is_inside_tree():
		_motion = _new_tween().set_parallel(true)
		if not _reduced():
			_motion.tween_method(_blink, 0.0, LIGHT_S, LIGHT_S)
		_motion.tween_callback(_light_off).set_delay(LIGHT_S)
	queue_redraw()


## The name in the first of NAME_SIZES that fits the label's inside on one line.
func _fit_name() -> void:
	var font: Font = _name.get_theme_font("font")
	var room: float = NAME_RECT.size.x - 2.0 * NAME_BORDER
	for font_size: int in NAME_SIZES:
		_name.add_theme_font_size_override("font_size", font_size)
		if font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			return


func _light_colour() -> Color:
	if _met:
		return LIGHT_MET_COLOR
	if _light_on:
		return LIGHT_ON_COLOR
	return HELD_COLOR if _planning and _want_scan else LIGHT_OFF_COLOR


func _blink(seconds: float) -> void:
	_light_on = int(seconds * LIGHT_BLINK_HZ * 2.0) % 2 == 0
	queue_redraw()


func _light_off() -> void:
	_light_on = false
	queue_redraw()


## The knock-off's flight at `seconds` in, from `from` turned `tilt`.
func _fly_off(seconds: float, sticker: EffectSticker, from: Vector2, tilt: float) -> void:
	var drop: Vector2 = (
		KNOCK_VELOCITY * seconds + Vector2(0.0, KNOCK_GRAVITY * seconds * seconds / 2.0)
	)
	sticker.position = from + drop
	sticker.rotation_degrees = tilt + KNOCK_SPIN * seconds


func _stop_light() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	_light_on = false


func _stop_ride() -> void:
	if _ride != null:
		_ride.kill()
		_ride = null


func _drop_sticker() -> void:
	if _slap != null:
		_slap.kill()
		_slap = null
	if _sticker != null:
		_sticker.queue_free()
		_sticker = null


## The knock-off's end: the sticker goes.
func _on_knocked_off() -> void:
	_knock = null
	_drop_knocked()


## Stops the knock-off and frees the sticker it was flying away.
func _drop_knocked() -> void:
	if _knock != null:
		_knock.kill()
		_knock = null
	if is_instance_valid(_knocked):
		_knocked.queue_free()
	_knocked = null


## A tween on the count-up's clock (make_tween) in the count, the bay's own in planning.
func _new_tween() -> Tween:
	if make_tween.is_valid() and not _planning:
		return make_tween.call() as Tween
	return create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
