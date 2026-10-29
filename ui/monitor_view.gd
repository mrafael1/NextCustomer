class_name MonitorView
extends Control
## The hung monitor (#80, mock-up B2; ShiftStage.MONITOR_RECT): two rods from the ceiling, the
## shade under it, a rubber bezel with a little bevel and the paper screen, drawn flat in code.
## Since #105 piece 2 (mock-up readability_v3.html, monitor b, the user's pick of 2026-10-24) it
## shows one screen in every mode, with no switching: two columns on the paper (PAPER_RECT).
## - The scanner bay (ScannerBay, BAY_RECT): the item at the scanner, with the queue over it and
##   its family chip under it (FamilyChip: what the item works with, in its ticket's colour).
## - The item column (MonitorItemColumn, ITEM_RECT): that item read in full: its name and family
##   glyphs, its price ("€N", the struck old price under a changed one), its effect text, a dashed
##   rule and its step lines.
## - The checkout column (CheckoutColumn, CHECKOUT_RECT) is kept for its readings but never shown:
##   since Checkout Rhythm v3 the spend objective and the total are the register's and the top
##   bar's, and the item column takes the paper's whole right side.
## In planning (mode() NEXT) the bay and the item column show belt slot 1's item with its lines
## (show_next, on every refresh; on an empty belt the item column's hint, MonitorText.EMPTY_BELT),
## or SCAN a held item's (show_scan, until end_scan). In redraw mode (plan
## section 3.8, show_redraw; mode() REDRAW) the redraw panel covers the whole paper. A notice
## (NoticeLabel: a full row, a closed slot) shows on a paper strip over the item column's step
## lines (NOTICE_RECT) while it lasts, never in the count. When the item column's lines are on
## pages (MonitorItemColumn.pages, Checkout Rhythm v3.1) the monitor takes the pointer: while it is
## on the screen no page turns by itself, and the mouse wheel (or a touchpad's scroll) over it
## turns them, one page a gesture (WHEEL_NOTCH, then still for WHEEL_QUIET_MS), taking the event
## so nothing else scrolls. Otherwise (and in the count) it takes no pointer at all.
##
## The count (mode() COUNT, follow): the bay follows the rides and beats (ScannerBay); the item
## column shows the item in the bay coming in at its base price, its price moving at each of its
## landings and the landing's step line alone; the checkout column reads the register (LedDisplay's
## reading, which the top bar's gauge follows too, so both show the same whole number at every
## moment). Each landing's amount flies from the item column to the number's left edge and its
## sparks pop as it lands (CountChips, over the paper); a giver's effect also lights the price
## rail (RailLight, BeltRide's). The landing that meets the quota starts the climax over the whole
## paper (MonitorClimax; the dessert waits for it, CountUp.climax_running); the TOTAL line ends the
## count (CheckoutColumn.finish: the stamp and the "+N€" tab). The last item stays in the item
## column, its last step line under it (mock-up still 16.5), and an inspected pass shows INSPECTION
## PASSED ✓ at the column's foot (a step line reaching it goes). A resumed checkout shows the end
## state at once (show_end_state).
##
## Text never carries the pixel material; the art does. Reduced motion (`reduced_motion`) leaves
## out every motion (the parts' fades, the rolls, punches, chips, sparks, the climax and the
## turns); the states all stay. Display only: every amount and line is the caller's (the score's,
## or the LED's reading).

enum Mode { NEXT, SCAN, COUNT, REDRAW }

## The parts' rects, in stage coordinates (the view stands at MONITOR_RECT's position): the paper
## (inside the screen's ink border), the bay, the item column and the checkout column.
const PAPER_RECT := Rect2(495, 77, 402, 154)
const BAY_RECT := Rect2(499, 79, 112, 150)
const ITEM_RECT := Rect2(619, 81, 270, 146)
const CHECKOUT_RECT := Rect2(799, 77, 98, 154)
## A notice's paper strip over the item column's step lines, and its text inside it.
const NOTICE_RECT := Rect2(617, 163, 274, 66)
const NOTICE_MARGIN := 4.0
const NOTICE_SIZE := 14
const NOTICE_WEIGHT := 800
const NOTICE_COLOR := Palette.INK
## The DONE state's "INSPECTION PASSED ✓" at the item column's foot (#77 machine v2), as the
## dessert stamps it on the receipt (CountUp.inspection_passed).
const INSPECTION_RECT := Rect2(499, 209, 112, 18)
const INSPECTION_TEXT := "INSPECTION PASSED ✓"
const INSPECTION_SIZE := 9
const INSPECTION_WEIGHT := 800
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
## The wheel: a page turns once the gesture's scroll adds up to WHEEL_NOTCH (a wheel's notch is
## 1), then not again until the wheel has been still WHEEL_QUIET_MS.
const WHEEL_NOTCH := 1.0
const WHEEL_QUIET_MS := 200
const WHEEL_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP,
	MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT,
	MOUSE_BUTTON_WHEEL_RIGHT
]

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The register's reading (the model the checkout column and the top bar follow) and the notices.
var upgrades: Array[UpgradeDefinition] = []
var led: LedDisplay
var notice_label: NoticeLabel
## The DONE state's "INSPECTION PASSED ✓" label, for checks (read only).
var inspection_passed_label: Label:
	get:
		return _inspection_passed

var _bay: ScannerBay
var _items: MonitorItemColumn
var _checkout: CheckoutColumn
var _chips: CountChips
var _climax: MonitorClimax
var _notice_strip: ColorRect
var _redraw_panel: RedrawPanel
var _redraw_on: bool = false
var _inspection_passed: Label
var _count_up: CountUp
## The count-up's item views (count_started), and each landing beat's step (beat_started) until
## it lands.
var _views: Array[CardView] = []
var _steps: Dictionary[CountUpBeat, ScoreStep] = {}
## The slot in the bay in the count (-1 for none).
var _scanned: int = -1
var _bagged: Dictionary[int, bool] = {}
var _step_at: Dictionary[int, ScoreStep] = {}
var _met: bool = false
## A bonus or multiplier's step line waiting for its moment in the beat (v3.1), on the count's
## clock; it shows at once when its value lands first or the next beat starts.
var _pending_line: Callable = Callable()
var _pending_wait: Tween
## Planning: belt slot 1's item and its lines, the belt's slots and filled ones, and the held
## item (null with no scan) with its lines.
var _next: CardDefinition
var _next_tags: PackedStringArray = PackedStringArray()
var _next_lines: ScanController.ItemLines
var _slots: int = 0
var _filled: int = 0
var _held: CardDefinition
var _held_tags: PackedStringArray = PackedStringArray()
var _held_lines: ScanController.ItemLines
## What the item column shows in planning now (it fades in when this changes).
var _shown_item: CardDefinition
## Each label's rect (local), set again once in the tree (a label never shrinks back by itself).
var _rects: Dictionary[Label, Rect2] = {}
## The pointer is on the monitor (while it takes it), and the wheel's gesture so far.
var _hovered: bool = false
var _wheel_sum: float = 0.0
var _wheel_at: int = -WHEEL_QUIET_MS - 1
var _wheel_locked: bool = false
var _last_motion: InputEventMouseMotion


func _init() -> void:
	name = "Monitor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.MONITOR_RECT.position
	size = ShiftStage.MONITOR_RECT.size
	led = LedDisplay.new()
	add_child(led)
	_bay = ScannerBay.new()
	_bay.position = local(BAY_RECT).position
	_bay.reduced_motion = _wants_reduced_motion
	add_child(_bay)
	_items = MonitorItemColumn.new()
	_items.position = local(ITEM_RECT).position
	_items.reduced_motion = _wants_reduced_motion
	add_child(_items)
	_checkout = CheckoutColumn.new()
	_checkout.position = local(CHECKOUT_RECT).position
	_checkout.reduced_motion = _wants_reduced_motion
	add_child(_checkout)
	_inspection_passed = UiKit.body_label(INSPECTION_TEXT, INSPECTION_SIZE, Palette.TEAL_SHADE)
	_inspection_passed.name = "InspectionPassed"
	_inspection_passed.add_theme_font_override(
		"font", MachineDisplay.marked_font(INSPECTION_WEIGHT)
	)
	_inspection_passed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inspection_passed.visible = false
	add_child(_inspection_passed)
	_place(_inspection_passed, INSPECTION_RECT)
	_notice_strip = ColorRect.new()
	_notice_strip.name = "Notice"
	_notice_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_strip.color = Palette.PAPER
	_notice_strip.position = local(NOTICE_RECT).position
	_notice_strip.size = NOTICE_RECT.size
	add_child(_notice_strip)
	notice_label = NoticeLabel.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_override("font", ArtStyle.bold_font(NOTICE_WEIGHT))
	notice_label.add_theme_font_size_override("font_size", NOTICE_SIZE)
	notice_label.add_theme_color_override("font_color", NOTICE_COLOR)
	notice_label.add_theme_constant_override("outline_size", 0)
	_notice_strip.add_child(notice_label)
	var notice_at: Rect2 = Rect2(
		Vector2.ONE * NOTICE_MARGIN, NOTICE_RECT.size - Vector2.ONE * 2.0 * NOTICE_MARGIN
	)
	_rects[notice_label] = notice_at
	notice_label.position = notice_at.position
	notice_label.size = notice_at.size
	notice_label.showing_changed.connect(_on_notice_showing)
	_chips = CountChips.new()
	_chips.position = local(PAPER_RECT).position
	_chips.size = PAPER_RECT.size
	_chips.reduced_motion = _wants_reduced_motion
	add_child(_chips)
	_climax = MonitorClimax.new()
	_climax.position = local(PAPER_RECT).position
	_climax.reduced_motion = _wants_reduced_motion
	add_child(_climax)
	_redraw_panel = RedrawPanel.new()
	_redraw_panel.position = local(PAPER_RECT).position
	add_child(_redraw_panel)
	led.mode_changed.connect(_on_led_mode)
	led.reading_changed.connect(_on_reading)
	mouse_entered.connect(_on_pointer.bind(true))
	mouse_exited.connect(_on_pointer.bind(false))
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
	return Mode.SCAN if _held != null else Mode.NEXT


## Planning's checkout column: PLAN over `projected` (the preview's total, or a drag's would-be
## total) against `quota`. Nothing changes in the count.
func show_plan(projected: int, quota: int) -> void:
	if not _counting():
		_checkout.show_plan(projected, quota)


## Redraw mode's panel (plan section 3.8): `notice` over the whole paper until null ends it. A
## notice still shows over it while it lasts; the count takes it off.
func show_redraw(notice: RedrawNotice) -> void:
	_redraw_on = notice != null
	_redraw_panel.show_notice(notice)
	_apply()


## Planning's bay and item column (the shift screen, on every refresh): belt slot 1's item
## (`definition`, null for an empty slot 1, with its scored `tags` and its `lines`) under NEXT,
## with a pip per belt slot (`slots`, the first `filled` of them holding items). A held scan's
## item shows instead while it lasts (show_scan). Nothing changes in the count.
func show_next(
	definition: CardDefinition,
	slots: int,
	filled: int,
	tags: PackedStringArray = PackedStringArray(),
	lines: ScanController.ItemLines = null
) -> void:
	_next = definition
	_next_tags = tags
	_next_lines = lines
	_slots = slots
	_filled = filled
	_update_planning()


## Shows a scanned item (ScanController): `definition` with its `tags` (on the belt the scored
## ones) and its payout and step lines (`lines`; a hand item's payout is -1). Call it once the
## monitor is in the tree: the text is measured with the real font.
func show_scan(
	definition: CardDefinition, tags: PackedStringArray, lines: ScanController.ItemLines = null
) -> void:
	_held = definition
	_held_tags = tags
	_held_lines = lines
	_update_planning()


## The scan ended: the bay and the item column go back to belt slot 1's item.
func end_scan() -> void:
	_held = null
	_held_lines = null
	_update_planning()


## Follows `count_up` (see the class comment): its count's start, rides, beats and landings, the
## quota met, the TOTAL line and the inspection's stamp. The count-up's total target is the
## checkout column's number (the dessert's slam).
func follow(count_up: CountUp) -> void:
	_count_up = count_up
	var maker: Callable = count_up.tween_maker()
	_bay.make_tween = maker
	_items.make_tween = maker
	_checkout.make_tween = maker
	_chips.make_tween = maker
	_climax.speed = count_up.press_speed
	count_up.total_target = null
	count_up.climax_running = Callable()
	count_up.count_started.connect(_on_count_started)
	count_up.ride.connect(_on_ride)
	count_up.beat_started.connect(_on_beat_started)
	count_up.step_landed.connect(_on_step_landed)
	count_up.landing.connect(_on_landing)
	count_up.quota_met.connect(_on_quota_met)
	count_up.total_landed.connect(_on_total_landed)
	count_up.inspection_passed.connect(_show_inspection_passed)


## A resumed checkout's end state (after CountUp's show_end_state, which met the quota or not):
## the bay with all of `views`' items paid and bagged (ALL PAID, DONE), the item column with the
## count's last item at its payout in `result` and its last step line (`line_of` words a step:
## ReceiptView.step_line with the row's names; none without `result`), the checkout column at the
## TOTAL with a lamp lit for each of `plan`'s gain landings, no chips or climax. An inspected pass
## shows INSPECTION PASSED ✓ (`inspection_passed`).
func show_end_state(
	plan: CountUpPlan,
	views: Array[CardView],
	inspection_passed: bool = false,
	result: ScoreResult = null,
	line_of: Callable = Callable()
) -> void:
	_views = views
	_drop_pending_line()
	_bay.show_end_state(views.size(), _met)
	_items.clear()
	_chips.clear()
	_climax.stop()
	if plan != null and result != null:
		_show_last_item(plan, result, line_of)
	var lamps: int = plan.lamp_count if plan != null else 0
	_checkout.show_end_state(led.amount(), led.quota(), lamps)
	if inspection_passed:
		_show_inspection_passed()
	else:
		_inspection_passed.visible = false


## The parts: the scanner bay, the item column, the checkout column, the chips and the climax.
func bay() -> ScannerBay:
	return _bay


func item_column() -> MonitorItemColumn:
	return _items


func checkout() -> CheckoutColumn:
	return _checkout


func chips() -> CountChips:
	return _chips


func climax() -> MonitorClimax:
	return _climax


## The art shown in the bay for the scan (the held item's, once it is in), or null.
func scan_art() -> TextureRect:
	if _held == null or _bay.bed().shown_definition() != _held:
		return null
	return _bay.bed().art()


## Every text label the screen shows now (the parts' in the visible ones), for layout checks.
func shown_labels() -> Array[Label]:
	var labels: Array[Label] = []
	_collect_labels(self, labels)
	return labels


## A rect in stage coordinates, in the monitor's own.
static func local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - ShiftStage.MONITOR_RECT.position, rect.size)


## Shows what the state says (see the class comment).
func _apply() -> void:
	var counting: bool = _counting()
	var noticed: bool = notice_label.is_showing() and not counting
	_notice_strip.visible = noticed
	var redrawing: bool = _redraw_on and not counting and not noticed
	_redraw_panel.visible = redrawing
	_bay.visible = not redrawing
	_items.visible = not redrawing
	# Checkout Rhythm v3: the spend objective is the register's and the top bar's, never the
	# monitor's, so the checkout column stays hidden in every mode.
	_checkout.visible = false
	_chips.visible = false
	if not counting:
		_climax.stop()
	_follow_pages()


## Takes the pointer only while the item column's lines are on pages in planning (holding them
## while it is on the screen).
func _follow_pages() -> void:
	var pages: MonitorStepPages = _paged()
	mouse_filter = Control.MOUSE_FILTER_PASS if pages != null else Control.MOUSE_FILTER_IGNORE
	if pages == null:
		_hovered = false
		_wheel_sum = 0.0
		_wheel_locked = false
		return
	if not _hovered and _pointer_on_screen():
		# A pointer already resting on the screen (no motion since) holds the pages too.
		_hovered = true
	pages.hold(_hovered)


## The item column's pages when it shows more than one in planning, else null.
func _paged() -> MonitorStepPages:
	var pages: MonitorStepPages = _items.pages
	if pages == null or pages.count() < 2 or _counting() or not _items.visible:
		return null
	return pages


func _on_pointer(over: bool) -> void:
	_hovered = over
	var pages: MonitorStepPages = _paged()
	if pages != null:
		pages.hold(over)


## Where the pointer last moved (any motion, seen here even while the screen ignores the mouse):
## a pointer resting on the screen when its item starts paging holds the pages, and one that
## leaves it lets them go even if the screen never had it as hovered.
func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	_last_motion = motion
	if _hovered and not _pointer_on_screen() and _paged() != null:
		_on_pointer(false)


func _pointer_on_screen() -> bool:
	if _last_motion == null or not is_visible_in_tree():
		return false
	var here: InputEventMouseMotion = make_input_local(_last_motion) as InputEventMouseMotion
	return Rect2(Vector2.ZERO, size).has_point(here.position)


## The wheel over the screen turns the pages (see the class comment) and goes no further.
func _gui_input(event: InputEvent) -> void:
	var pages: MonitorStepPages = _paged()
	if pages == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and WHEEL_BUTTONS.has(button.button_index):
		if button.pressed:
			var notch: float = button.factor if button.factor > 0.0 else 1.0
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_wheel(pages, -notch)
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_wheel(pages, notch)
		accept_event()
		return
	var pan: InputEventPanGesture = event as InputEventPanGesture
	if pan != null:
		_wheel(pages, pan.delta.y)
		accept_event()


## `amount` more of the wheel's gesture (down positive): a page once it adds up to a notch.
func _wheel(pages: MonitorStepPages, amount: float) -> void:
	var now: int = Time.get_ticks_msec()
	var quiet: bool = now - _wheel_at > WHEEL_QUIET_MS
	_wheel_at = now
	if _wheel_locked and not quiet:
		return
	_wheel_locked = false
	if quiet:
		_wheel_sum = 0.0
	_wheel_sum += amount
	if absf(_wheel_sum) < WHEEL_NOTCH:
		return
	var direction: int = -1 if _wheel_sum < 0.0 else 1
	_wheel_sum = 0.0
	_wheel_locked = true
	pages.turn(direction)


func _counting() -> bool:
	return led.is_counting()


## Planning's bay and item column: the held item under SCAN, else belt slot 1's under NEXT.
func _update_planning() -> void:
	if _counting():
		return
	var held: bool = _held != null
	var shown: CardDefinition = _held if held else _next
	_bay.chip().visible = true
	_bay.show_planning(shown, held, _slots, _filled)
	if shown == null:
		_items.show_empty(MonitorText.EMPTY_BELT)
		_shown_item = null
	else:
		var lines: ScanController.ItemLines = _held_lines if held else _next_lines
		if lines == null:
			lines = ScanController.ItemLines.new()
		var animate: bool = shown != _shown_item
		_shown_item = shown
		_items.show_item(
			shown,
			_held_tags if held else _next_tags,
			lines.payout,
			lines.lines,
			lines.fizzles,
			lines.gives,
			lines.minis,
			animate
		)
	_apply()


## The LED's mode: a count starts (SUBTOTAL from blank: the bay reset with its item kept, the
## columns at the count's start), or the count is left (planning comes back).
func _on_led_mode(led_mode: LedDisplay.Mode) -> void:
	if led_mode == LedDisplay.Mode.SUBTOTAL:
		_met = false
		_scanned = -1
		_steps.clear()
		_bay.reset(true)
		_inspection_passed.visible = false
		_items.clear()
		_chips.clear()
		_climax.stop()
		_checkout.start_count(led.quota())
		_shown_item = null
		# Planning's belt is spent: the next planning shows an empty bay until the screen says.
		_next = null
		_next_lines = null
		_held = null
		_slots = 0
		_filled = 0
	elif led_mode == LedDisplay.Mode.BLANK or led_mode == LedDisplay.Mode.PROJECTED:
		_met = false
		_scanned = -1
		_steps.clear()
		_chips.clear()
		_climax.stop()
		_inspection_passed.visible = false
		if not _bay.is_planning():
			_bay.reset()
		_update_planning()
	_apply()


## The register's reading: the checkout column (and the climax) follow it in the count.
func _on_reading(amount: int, quota: int, _met_now: bool) -> void:
	if _counting():
		_checkout.set_reading(amount, quota)
		_climax.set_reading(amount)


## CountUp.count_started: a count of `views` starts (the bay's queue; it keeps the first item when
## planning left it in the bay).
func _on_count_started(views: Array[CardView]) -> void:
	_views = views
	_drop_pending_line()
	_bagged.clear()
	_step_at.clear()
	_met = false
	_scanned = -1
	_steps.clear()
	var first: CardDefinition = null
	if not views.is_empty() and views[0] != null:
		first = views[0].card.definition
	_bay.chip().visible = true
	_bay.start(views.size(), first)
	_items.clear()


## CountUp.ride: item `scan_slot` rides in over `ride_ms` while `bag_slot` bags; after the last
## (-1) the item column keeps the last item and its line (the end state, mock-up still 16.5).
func _on_ride(bag_slot: int, scan_slot: int, ride_ms: int) -> void:
	if bag_slot >= 0:
		_bagged[bag_slot] = true
	var definition: CardDefinition = _definition_of(scan_slot)
	_bay.ride(bag_slot, scan_slot, definition, ride_ms / 1000.0)
	if scan_slot < 0:
		_scanned = -1


## CountUp.beat_started: the bay follows the beat; an opening beat brings its item into the item
## column; a beat on the scanned item shows its step line, and its amount takes off toward the
## number (a WASTED drops); a landing beat waits for its landing.
func _on_beat_started(
	beat: CountUpBeat, step: ScoreStep, line: String, view: CardView, _items_count: int
) -> void:
	_show_pending_line()
	_step_at[beat.steps[0]] = step
	var definition: CardDefinition = view.card.definition if view != null else null
	_bay.follow_beat(beat, step, definition)
	if beat.opens_slot and beat.scan_slot >= 0:
		_scanned = beat.scan_slot
		var opened: CardDefinition = _definition_of(beat.scan_slot)
		if opened != null:
			_items.start_item(opened, _tags_of(beat.scan_slot))
		if beat.kind == CountUpBeat.Kind.MERGED_PLAIN:
			_items.show_paid("No bonus on this item")
	if step.slot != _scanned or _scanned < 0:
		return
	if _shows_line(beat) or beat.kind == CountUpBeat.Kind.ARMED:
		var fizzle: bool = step.step_type == ScoreStep.StepType.WASTED
		var shown: String = _line_of(step, Callable(), line)
		if shown.is_empty():
			shown = step.text
		var from_bag: bool = (
			step.source_kind == ScoreStep.SourceKind.CARD and _bagged.has(step.card_giver_slot())
		)
		var line_shown: Callable = _items.show_step.bind(
			shown, fizzle, beat.kind == CountUpBeat.Kind.ARMED, _giver_mini(step), from_bag
		)
		_show_line_in_beat(beat, line_shown)
	if beat.kind == CountUpBeat.Kind.PAYOUT:
		# Under the named bonus lines: the payment equation when the steps multiply out to the
		# payout, else what it pays.
		_items.show_paid(ReceiptView.joined_line("Pays", "€%d" % beat.payout), beat.equation)


func _on_step_landed(index: int) -> void:
	var step: ScoreStep = _step_at.get(index, null)
	if step == null or step.slot != _scanned:
		return
	# The line comes before its value.
	_show_pending_line()
	if (
		step.step_type
		in [
			ScoreStep.StepType.BASE,
			ScoreStep.StepType.FLAT,
			ScoreStep.StepType.COPY,
			ScoreStep.StepType.MULTIPLIER,
			ScoreStep.StepType.PAYOUT_OVERRIDE
		]
	):
		_items.set_value(step.value_after, step.step_type == ScoreStep.StepType.PAYOUT_OVERRIDE)


## A bonus or multiplier beat's line (`line_shown`) waits for the tuning's step_line_at of the beat
## (the mock-up's doBeat: giver, then line, then value); others, an echo, reduced motion or a
## monitor without its count-up's clock show it at once.
func _show_line_in_beat(beat: CountUpBeat, line_shown: Callable) -> void:
	var tuning: CountTotalTuning = _count_up.total_tuning() if _count_up != null else null
	var delay: float = tuning.step_line_at * beat.duration_ms / 1000.0 if tuning != null else 0.0
	var timed: bool = beat.kind in [CountUpBeat.Kind.BONUS, CountUpBeat.Kind.STAMP]
	if not timed or beat.echo or delay <= 0.0 or _wants_reduced_motion():
		line_shown.call()
		return
	_pending_line = line_shown
	_pending_wait = _count_up.tween_maker().call() as Tween
	_pending_wait.tween_interval(delay)
	_pending_wait.tween_callback(_on_line_due)


func _show_pending_line() -> void:
	if _pending_wait != null and _pending_wait.is_valid():
		_pending_wait.kill()
	_pending_wait = null
	var due: Callable = _pending_line
	_pending_line = Callable()
	if due.is_valid():
		due.call()


## The pending line's moment came (its tween's own callback: the tween ends by itself).
func _on_line_due() -> void:
	_pending_wait = null
	_show_pending_line()


func _drop_pending_line() -> void:
	_pending_line = Callable()
	_show_pending_line()


## CountUp.landing: `beat` lands on the number (its punch, lamp and sparks) and on its item's price.
func _on_landing(beat: CountUpBeat) -> void:
	_checkout.land(beat)


## CountUp.quota_met: the quota is met, with `pop` (the climax) or at once (a resumed checkout).
func _on_quota_met(_pop: bool) -> void:
	_met = true
	_bay.set_met(true)
	# The register owns the quota celebration; the item breakdown stays visible.


## CountUp.total_landed: the TOTAL line: the checkout column's end (the stamp and the tab when met).
func _on_total_landed() -> void:
	_checkout.finish(led.amount() >= led.quota())


## The DONE state's "INSPECTION PASSED ✓" (the dessert stamped it; hidden at the next count): a
## step line of the last item reaching its place goes.
func _show_inspection_passed() -> void:
	_inspection_passed.visible = true
	_bay.chip().visible = false


## The resumed end's item column: the item at the scanner on `plan`'s last beat, at its payout,
## with the step lines the count showed for it (see _on_beat_started) and its payment equation,
## if it had one.
func _show_last_item(plan: CountUpPlan, result: ScoreResult, line_of: Callable) -> void:
	var slot: int = -1
	for beat: CountUpBeat in plan.beats:
		if beat.scan_slot >= 0:
			slot = beat.scan_slot
	var definition: CardDefinition = _definition_of(slot)
	if definition == null or slot >= result.payouts.size():
		return
	_items.start_item(definition, _tags_of(slot), false)
	var last: ScoreStep = null
	for beat: CountUpBeat in plan.beats:
		var step: ScoreStep = result.steps[beat.steps[0]]
		var base: bool = beat.land == CountUpBeat.Land.BASE
		if beat.scan_slot == slot and step.slot == slot and not base and _shows_line(beat):
			last = step
			_items.show_step(
				_line_of(step, line_of),
				step.step_type == ScoreStep.StepType.WASTED,
				false,
				_giver_mini(step),
				step.source_kind == ScoreStep.SourceKind.CARD and step.card_giver_slot() < slot
			)
	for beat: CountUpBeat in plan.beats:
		if beat.slot == slot and beat.equation != null:
			_items.show_paid("", beat.equation)
	var fizzled: bool = last != null and last.step_type == ScoreStep.StepType.WASTED
	_items.set_value(result.payouts[slot], fizzled)


func _on_notice_showing(_showing: bool) -> void:
	_apply()


## `step`'s line in the item column: a WASTED step's reason (MonitorText.waste_line), else the
## receipt's words (`line_of`, or `fallback` as the count gave it).
static func _line_of(step: ScoreStep, line_of: Callable, fallback: String = "") -> String:
	if step.step_type == ScoreStep.StepType.WASTED:
		return MonitorText.waste_line(step)
	if line_of.is_valid():
		return String(line_of.call(step))
	return fallback


## Whether `beat`'s line shows in the item column: a step's own line (no base, payout or armed
## beat, which the price and the bay say).
static func _shows_line(beat: CountUpBeat) -> bool:
	match beat.kind:
		CountUpBeat.Kind.BONUS, CountUpBeat.Kind.STAMP, CountUpBeat.Kind.DENIED:
			return true
		CountUpBeat.Kind.FIZZLE:
			return true
	return false


## Where a landing's chip takes off when its item is not in the bay (a bagged item's): the item
## column's step lines.
func _chips_from_column() -> Vector2:
	return _items.step_point()


func _definition_of(slot: int) -> CardDefinition:
	if slot >= 0 and slot < _views.size() and _views[slot] != null:
		return _views[slot].card.definition
	return null


func _tags_of(slot: int) -> PackedStringArray:
	var item: ItemView = _views[slot] as ItemView if slot >= 0 and slot < _views.size() else null
	return item.tags() if item != null else PackedStringArray()


## The mini of the item that gave `step` (another item of the count), or null.
func _giver_mini(step: ScoreStep) -> Texture2D:
	if step.source_kind == ScoreStep.SourceKind.UPGRADE:
		if step.source_index >= 0 and step.source_index < upgrades.size():
			var icon: String = upgrades[step.source_index].icon_ref
			return load(icon) as Texture2D if not icon.is_empty() else null
		return null
	if step.source_kind != ScoreStep.SourceKind.CARD or step.card_giver_slot() == step.slot:
		return null
	var giver: CardDefinition = _definition_of(step.card_giver_slot())
	if giver == null:
		return null
	var ref: String = giver.badge_mini_ref()
	return load(ref) as Texture2D if not ref.is_empty() and ResourceLoader.exists(ref) else null


## A hung part (a rod, the shade): `color` with an ink outline on its sides and foot.
func _draw_hung(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Palette.INK)
	var inside: Vector2 = rect.size - Vector2(2 * OUTLINE, OUTLINE)
	draw_rect(Rect2(rect.position + Vector2(OUTLINE, 0), inside), color)


## Puts `label` at `rect` (stage coordinates).
func _place(label: Label, rect: Rect2) -> void:
	var at: Rect2 = local(rect)
	_rects[label] = at
	label.position = at.position
	label.size = at.size


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
