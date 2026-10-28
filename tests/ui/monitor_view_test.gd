extends GdUnitTestSuite
## The real monitor keeps its planning preview and opens a wider item column during COUNT.
## Every live card's planning text fits. COUNT retains compact bonus lines, leaves the shared
## total on the register and gauge, and keeps inspection status in the scanner bay footer.
## Tests isolate saves and logs and drive the scanner pointer without moving the real mouse.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## More step lines than any belt item carries, every other one a fizzle (its cause and WASTED, as
## ReceiptView.step_line words it).
const WORST_LINES := 12
const LONG_LINE := "Breakfast sticker  WASTED"
const SHORT_LINE := "× Multipack  ×3"
## A fizzle on one line.
const BRIEF_FIZZLE := "Bundle  WASTED"

var _folder: String = ""
## Where the tests put the pointer (global), and the scanner's clock (ms).
var _point: Vector2 = Vector2.ZERO
var _clock: int = 0


func before_test() -> void:
	_folder = "user://test_monitor_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_point = Vector2(-100, -100)
	_clock = 1000


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The monitor hangs at MONITOR_RECT under the top bar, everything it draws (rods and shade
## included) on the stage and clear of the belt, the row's cells, the receipt and the register;
## its one screen lies on the paper (PAPER_RECT, inside the ink outline): the bay, the item column
## and the checkout column side by side and apart, the notice strip over the item column only,
## INSPECTION PASSED inside the item column, the chips and the climax over the whole paper. In
## planning it shows NEXT: belt slot 1's item in the bay and the item column, PLAN in the checkout
## column; it takes no clicks.
func test_the_monitor_hangs_on_the_stage_clear_of_the_rest() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "bread"])
	var stage: Rect2 = screen._stage.get_global_rect()
	var monitor: MonitorView = screen._monitor
	assert_object(monitor).is_same(screen._stage.monitor)
	assert_object(screen._led.get_parent()).is_same(monitor)
	assert_that(monitor.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.MONITOR_RECT))
	var drawn: Rect2 = _on_stage(screen, MonitorView.DRAWN_RECT)
	var parts: Array[Rect2] = [ShiftStage.MONITOR_RECT, ShiftStage.MONITOR_UNDER_RECT]
	parts.append_array(ShiftStage.ROD_RECTS)
	for part: Rect2 in parts:
		var rect: Rect2 = _on_stage(screen, part)
		assert_bool(drawn.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(stage.encloses(drawn)).is_true()
	assert_float(drawn.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	for child: Node in screen._top_bar.get_children():
		var bar_part: Control = child as Control
		if bar_part.visible and (bar_part is PanelContainer or bar_part is Button):
			assert_bool(drawn.intersects(bar_part.get_global_rect())).is_false()
	var others: Array[Rect2] = [
		_on_stage(screen, ShiftStage.BELT_RECT),
		_on_stage(screen, ShiftStage.REGISTER_RECT),
		screen._receipt.get_global_rect(),
	]
	for slot: PanelContainer in screen._slots:
		others.append(slot.get_global_rect())
	for other: Rect2 in others:
		assert_bool(drawn.intersects(other)).override_failure_message(str(other)).is_false()
	# The screen's parts, on its paper (inside its ink border).
	var paper: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT).grow(-MonitorView.OUTLINE)
	assert_that(paper).is_equal(_on_stage(screen, MonitorView.PAPER_RECT))
	# Checkout Rhythm v3: no spend objective on the monitor; the item column takes its room.
	var columns: Array[Rect2] = [MonitorView.BAY_RECT, MonitorView.ITEM_RECT]
	for index: int in range(columns.size()):
		var column: Rect2 = columns[index]
		(
			assert_bool(MonitorView.PAPER_RECT.encloses(column))
			. override_failure_message(str(column))
			. is_true()
		)
		for other: int in range(index + 1, columns.size()):
			assert_bool(column.intersects(columns[other])).is_false()
			assert_float(columns[other].position.x).is_greater_equal(column.end.x)
	var notice: Rect2 = MonitorView.NOTICE_RECT
	assert_bool(MonitorView.PAPER_RECT.encloses(notice)).is_true()
	assert_bool(notice.intersects(MonitorView.BAY_RECT)).is_false()
	assert_float(notice.position.y).is_greater_equal(
		MonitorView.ITEM_RECT.position.y + MonitorItemColumn.STEPS_TOP - 8.0
	)
	assert_bool(MonitorView.BAY_RECT.encloses(MonitorView.INSPECTION_RECT)).is_true()
	# The parts where their rects say, the chips and the climax over the whole paper.
	assert_that(monitor.bay().get_global_rect()).is_equal(_on_stage(screen, MonitorView.BAY_RECT))
	assert_that(monitor.item_column().get_global_rect()).is_equal(
		_on_stage(screen, MonitorView.ITEM_RECT)
	)
	assert_bool(monitor.checkout().is_visible_in_tree()).is_false()
	assert_that(monitor.chips().get_global_rect()).is_equal(paper)
	assert_bool(monitor.chips().clip_contents).is_true()
	assert_that(monitor.climax().get_global_rect()).is_equal(paper)
	assert_bool(monitor.climax().clip_contents).is_true()
	# Planning: NEXT with belt slot 1's item and no spend objective; no clicks taken.
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.NEXT)
	assert_bool(monitor.bay().is_planning()).is_true()
	assert_object(monitor.bay().bed().shown_definition()).is_same(screen.run.row[0].definition)
	assert_object(monitor.item_column().shown_definition()).is_same(screen.run.row[0].definition)
	assert_bool(monitor.checkout().is_visible_in_tree()).is_false()
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await _assert_layout(monitor, screen._stage.get_global_rect().position, "planning")


## Every card in data/cards, scanned in the hand (no lines), on the belt with two lines, then with
## the worst lines: its art in the bay's bed and its chip; its name, glyphs, price, effect and
## lines inside the item column, none overlapping, every text label inside its column, the effect
## whole; the two lines both shown, the worst ones folded into "+N more" at the column's foot.
func test_every_card_scan_fits_the_screen() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var worst: ScanController.ItemLines = ScanController.ItemLines.new()
	for index: int in range(WORST_LINES):
		worst.lines.append(LONG_LINE if index % 2 == 0 else SHORT_LINE)
		worst.fizzles.append(index % 2 == 0)
	var short: ScanController.ItemLines = ScanController.ItemLines.new()
	short.lines = PackedStringArray([SHORT_LINE, BRIEF_FIZZLE])
	short.fizzles = [false, true]
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(LiveCardCount.CARDS)
	var effect_sizes: Dictionary[int, int] = {}
	for definition: CardDefinition in cards:
		monitor.show_scan(definition, definition.tags)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s in the hand" % definition.id)
		await _assert_layout(monitor, Vector2.ZERO, "%s in the hand" % definition.id)
		assert_array(monitor.item_column().step_rows()).is_empty()
		var effect: GlyphLabel = monitor.item_column().effect()
		if effect != null:
			var count: int = effect_sizes.get(effect.get_theme_font_size("font_size"), 0)
			effect_sizes[effect.get_theme_font_size("font_size")] = count + 1
		short.payout = definition.base
		monitor.show_scan(definition, definition.tags, short)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s on the belt" % definition.id)
		await _assert_layout(monitor, Vector2.ZERO, "%s on the belt" % definition.id)
		var texts: PackedStringArray = monitor.item_column().step_texts()
		assert_bool(texts == short.lines).override_failure_message(str(texts)).is_true()
		worst.payout = definition.base
		monitor.show_scan(definition, definition.tags, worst)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s, worst lines" % definition.id)
		await _assert_layout(monitor, Vector2.ZERO, "%s, worst lines" % definition.id)
		texts = monitor.item_column().step_texts()
		var shown: int = texts.size() - 1
		assert_int(shown).override_failure_message(definition.id).is_greater_equal(1)
		assert_str(texts[shown]).is_equal(MonitorItemColumn.MORE_TEXT % (WORST_LINES - shown))
	prints("#105 item column effect sizes:", effect_sizes)


## On the real screen: belt slot 1's item in planning; a plain hover on a belt item leaves it; the
## held hover shows the item (its art, chip, name, effect, price and step lines worded as the
## receipt words them, no popup); a notice shows on its strip while it lasts (in ink), the scan
## kept, then goes; leaving the item brings slot 1's item back. A hand item shows no step lines.
func test_a_held_scan_fills_the_monitor_then_it_goes_back() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "bread", "coffee"])
	var monitor: MonitorView = screen._monitor
	# The held item in the bay at once (monitor_bay_test covers the swaps' motion).
	monitor.reduced_motion = func() -> bool: return true
	var first: CardDefinition = screen.run.row[0].definition
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.NEXT)
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	_clock += screen._scan.hold_ms() - 1
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.NEXT)
	assert_object(monitor.item_column().shown_definition()).is_same(first)
	_clock += 1
	await _frames(2)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.popup().visible).is_false()
	var definition: CardDefinition = view.card.definition
	var column: MonitorItemColumn = monitor.item_column()
	assert_str(ItemName.text_of(column.name_control())).is_equal(definition.display_name)
	assert_str(column.effect().text).is_equal(_scan_text(definition))
	assert_object(monitor.scan_art().texture).is_same(ArtStyle.item_sprite(definition))
	assert_str(monitor.bay().chip().chip_text()).is_equal(FamilyChip.item_text(definition))
	var result: ScoreResult = screen.run.preview()
	var expected: PackedStringArray = PackedStringArray()
	for step: ScoreStep in ScanController.footer_steps(result, 2):
		# A WASTED line reads its reason alone (the receipt keeps its cause).
		if step.step_type == ScoreStep.StepType.WASTED:
			expected.append(MonitorText.waste_line(step))
		else:
			expected.append(ReceiptView.step_line(step, CardInstance.names(screen.run.row)))
	assert_bool(expected.has("No Breakfast product after it  WASTED")).is_true()
	var texts: PackedStringArray = column.step_texts()
	assert_bool(texts == expected).override_failure_message(str(texts)).is_true()
	assert_str(column.price_tag().text()).is_equal(PriceSticker.price_text(result.payouts[2]))
	# A notice shows on its strip while it lasts, in ink (tomato is for fizzles, CHECKOUT and
	# CLOSED), over the item column's steps; the scan stays.
	screen._notice_label.show_notice("Row full (9/9 items): take an item out first")
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._notice_label.is_visible_in_tree()).is_true()
	var strip: Rect2 = _on_stage(screen, MonitorView.NOTICE_RECT)
	assert_bool(strip.encloses(screen._notice_label.get_global_rect())).is_true()
	var notice_colour: Color = screen._notice_label.get_theme_color("font_color")
	assert_that(notice_colour).is_equal(MonitorView.NOTICE_COLOR)
	for tomato: Color in [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT]:
		assert_bool(notice_colour == tomato).is_false()
	screen._notice_label.clear_notice()
	assert_bool(screen._notice_label.is_visible_in_tree()).is_false()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	# Off the item: belt slot 1's item again.
	_point = Vector2(-100, -100)
	view.unhovered.emit(view)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_null()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.NEXT)
	assert_object(column.shown_definition()).is_same(first)
	# A hand item: no step lines.
	var hand_item: ItemView = screen._hand_box.cards()[0] as ItemView
	await _hover(screen, hand_item)
	_clock += screen._scan.hold_ms()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_array(column.step_rows()).is_empty()
	screen._scan.clear()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.NEXT)


## On the real screen, every count-up beat shows on the monitor as it starts: COUNT, the bay holds
## the beat's scanned item (its art and its chip), the step line is the receipt's wording, and on
## every frame the checkout column's number, the top bar's gauge and (while it runs) the climax's
## number read the register's same whole number, TOTAL over it, the ladder lit by the landings;
## the monitor's parts stay inside their columns on every beat. At the end the TOTAL with the
## stamp and the "+N€" tab, apart, on the paper, met (quota_met once, with its pop, at the ding).
## The next shift's planning takes it all off.
func test_the_count_keeps_the_item_breakdown_visible_and_total_on_the_register() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var monitor: MonitorView = screen._monitor
	var count: CountUp = screen._count_up
	var failures: Array[String] = []
	var observe: Callable = func(
		_beat: CountUpBeat, _beat_step: ScoreStep, _line: String, _view: CardView, _size: int
	) -> void:
		if monitor.checkout().is_visible_in_tree():
			failures.append("The old total column covered the item breakdown")
		if monitor.climax().is_running():
			failures.append("The monitor was covered by a quota celebration")
		if not screen._cabinet.total_display.visible:
			failures.append("The register display was hidden during the count")
	count.beat_started.connect(observe)
	var rush: Callable = func() -> void: count._tap(Time.get_ticks_msec())
	rush.call_deferred()
	await screen._on_checkout_pressed()
	assert_array(failures).is_empty()
	assert_int(screen._cabinet.total_display.amount()).is_equal(count.plan.total)
	assert_int(monitor.item_column().step_texts().size()).is_greater(0)


func test_a_last_payment_starts_the_register_celebration_without_covering_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	var count: CountUp = screen._count_up
	screen._led.start_count(73)
	count.quota_met.emit(true)
	assert_bool(screen._cabinet.total_display.is_celebrating()).is_true()
	assert_bool(screen._monitor.climax().is_running()).is_false()
	assert_bool(screen._monitor.item_column().visible).is_true()


func test_payment_landings_leave_the_monitor_clear() -> void:
	var screen: ShiftScreen = await _screen()
	screen._led.start_count(73)
	var beat: CountUpBeat = _landing(CountUpBeat.Kind.PAYOUT, CountUpBeat.Land.ADD, 21, 0)
	screen._count_up.landing.emit(beat)
	assert_array(screen._monitor.chips().chips()).is_empty()
	assert_bool(screen._monitor.chips().visible).is_false()


func test_a_resumed_quota_uses_a_quiet_end_state() -> void:
	var screen: ShiftScreen = await _screen()
	screen._led.start_count(73)
	screen._led.show_subtotal(170, true)
	screen._led.show_total()
	screen._count_up.quota_met.emit(false)
	assert_bool(screen._cabinet.total_display.visible).is_true()
	assert_int(screen._cabinet.total_display.amount()).is_equal(170)
	assert_bool(screen._cabinet.total_display.is_celebrating()).is_false()
	assert_bool(screen._monitor.climax().is_running()).is_false()


func test_the_empty_belt_hint_and_a_long_wasted_line_read_whole() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.show_next(null, 6, 0)
	monitor.show_plan(0, 29)
	await _frames(1)
	var items: MonitorItemColumn = monitor.item_column()
	var hint: Label = items.get_node_or_null("Hint") as Label
	assert_object(hint).is_not_null()
	assert_str(hint.text).is_equal(MonitorText.EMPTY_BELT)
	var hint_rect: Rect2 = hint.get_global_rect()
	(
		assert_bool(MonitorView.ITEM_RECT.grow(0.5).encloses(hint_rect))
		. override_failure_message(str(hint_rect))
		. is_true()
	)
	assert_object(items.shown_definition()).is_null()
	assert_str(monitor.checkout().status_label().text).is_equal("29€ to go")
	# The same hint on a refresh is the same label (no rebuild).
	monitor.show_next(null, 6, 0)
	assert_object(items.get_node_or_null("Hint")).is_same(hint)
	# A long WASTED reason (an upgrade's) in the count.
	var count_up: CountUp = _follow(monitor)
	var multipack: CardDefinition = load("%s/multipack.tres" % CARDS) as CardDefinition
	monitor.led.start_count(40)
	items.start_item(multipack, PackedStringArray())
	var waste: ScoreStep = _step(ScoreStep.StepType.WASTED)
	waste.reason = "the first coupon paid nothing"
	waste.text = "Coupon engine"
	var line: String = MonitorText.waste_line(waste)
	assert_str(line).is_equal("The first coupon paid nothing  WASTED")
	items.show_step(line, true)
	await _frames(1)
	var row: Control = items.step_rows()[0]
	var text: Label = row.get_node("Text") as Label
	assert_int(text.get_line_count()).is_less_equal(text.max_lines_visible)
	(
		assert_bool(
			Rect2(MonitorView.ITEM_RECT.position, MonitorItemColumn.COUNT_SIZE).grow(0.5).encloses(
				row.get_global_rect()
			)
		)
		. is_true()
	)
	var amount: Label = row.get_node("Amount") as Label
	assert_bool(text.get_global_rect().intersects(amount.get_global_rect())).is_false()
	# INSPECTION PASSED ✓ at the column's foot drops a line that reaches it.
	count_up.inspection_passed.emit()
	await _frames(1)
	var passed: Rect2 = monitor.inspection_passed_label.get_global_rect()
	(
		assert_bool(MonitorView.PAPER_RECT.grow(0.5).encloses(passed))
		. override_failure_message(str(passed))
		. is_true()
	)
	for shown: Control in items.step_rows():
		assert_bool(shown.get_global_rect().intersects(passed)).is_false()
	await _frames(1)


## The checkout column's words from core's ShiftMargin: the count's status short of the quota, on
## it and past it; planning's; the tab's.
func test_the_status_text_follows_the_margin() -> void:
	assert_str(MonitorText.status(22, 73)).is_equal("51€ to go")
	assert_str(MonitorText.status(73, 73)).is_equal(MonitorText.ON_QUOTA)
	assert_str(MonitorText.status(85, 73)).is_equal("+12€ over")
	assert_str(MonitorText.planned(85, 73)).is_equal("+12€ planned")
	assert_str(MonitorText.planned(60, 73)).is_equal("13€ to go")
	assert_str(MonitorText.over_tab(85, 73)).is_equal("+12€")
	assert_str(MonitorText.spend(73)).is_equal("73€+")
	assert_str(MonitorText.gain(-4)).is_equal("−4€")


## The shade dims its rect but its hole: up to four bands around it that cover the rest, none over
## the hole; an empty hole (or one off the shade) shades it all.
func test_the_shade_leaves_its_hole_unshaded() -> void:
	var shade: ScreenShade = auto_free(ScreenShade.new())
	get_tree().root.add_child(shade)
	shade.position = Vector2(0, 64)
	shade.size = Vector2(944, 656)
	var area: Rect2 = shade.get_global_rect()
	assert_array(shade.shaded_rects()).is_equal([area])
	var hole: Rect2 = MonitorView.DRAWN_RECT
	shade.set_hole(hole)
	var cut: Rect2 = area.intersection(hole)
	var shaded: float = 0.0
	for rect: Rect2 in shade.shaded_rects():
		assert_bool(area.encloses(rect)).is_true()
		assert_bool(rect.intersects(cut)).override_failure_message(str(rect)).is_false()
		shaded += rect.get_area()
	assert_float(shaded).is_equal_approx(area.get_area() - cut.get_area(), 0.01)
	shade.set_hole(Rect2(2000, 2000, 10, 10))
	assert_array(shade.shaded_rects()).is_equal([area])
	assert_int(shade.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# --- Helpers ---------------------------------------------------------------------------------


## The met TOTAL in `column`: the stamp and the "+N€" tab for `total` against `quota` shown, both
## on the paper and inside the column (read back through `to_world`), not over each other.
func _assert_stamp_and_tab(
	column: CheckoutColumn, total: int, quota: int, to_world: Transform2D
) -> void:
	var paper: Rect2 = MonitorView.PAPER_RECT
	var stamp: Label = column.stamp()
	var tab: Label = column.tab()
	assert_bool(stamp.is_visible_in_tree()).is_true()
	assert_bool(tab.is_visible_in_tree()).is_true()
	assert_str(tab.text).is_equal(MonitorText.over_tab(total, quota))
	assert_bool(column.status_label().visible).is_false()
	var stamp_rect: Rect2 = to_world * _tilted_rect(stamp)
	var tab_rect: Rect2 = to_world * _tilted_rect(tab)
	var message: String = "tab %s, stamp %s" % [tab_rect, stamp_rect]
	for rect: Rect2 in [stamp_rect, tab_rect]:
		assert_bool(paper.encloses(rect)).override_failure_message(message).is_true()
		(
			assert_bool(MonitorView.CHECKOUT_RECT.grow(1.0).encloses(rect))
			. override_failure_message(message)
			. is_true()
		)
	# The tilted stamp's bounding box may graze the tab's by its corner: a pixel's grace.
	(
		assert_bool(tab_rect.intersects(stamp_rect.grow(-1.0)))
		. override_failure_message(message)
		. is_false()
	)


## A control's rect as drawn (global), with its rotation about its pivot.
static func _tilted_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform()
	var rect: Rect2 = Rect2(transform.origin, Vector2.ZERO)
	var size: Vector2 = control.size
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		rect = rect.expand(transform * corner)
	return rect


## The scan in the bay and the item column: the art in the bay's bed (at rest: the monitor here has
## reduced motion), the bay under SCAN with the item's chip, the item column's name whole and its
## effect the card's text, whole.
func _assert_scan_fits(monitor: MonitorView, definition: CardDefinition, message: String) -> void:
	assert_int(monitor.mode()).override_failure_message(message).is_equal(MonitorView.Mode.SCAN)
	var bay: ScannerBay = monitor.bay()
	var art: TextureRect = monitor.scan_art()
	assert_object(art).override_failure_message(message).is_not_null()
	assert_that(art.get_global_rect()).override_failure_message(message).is_equal(
		Rect2(
			MonitorView.BAY_RECT.position + ScannerBay.ART_RECT.position, ScannerBay.ART_RECT.size
		)
	)
	assert_object(art.texture).is_same(ArtStyle.item_sprite(definition))
	assert_bool(bay.shows_scan()).override_failure_message(message).is_true()
	assert_str(bay.queue().text()).is_equal(BayQueue.SCAN_TEXT)
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(definition))
	var column: MonitorItemColumn = monitor.item_column()
	assert_str(ItemName.text_of(column.name_control())).is_equal(definition.display_name)
	var effect: GlyphLabel = column.effect()
	var text: String = _scan_text(definition)
	if text.is_empty():
		assert_object(effect).override_failure_message(message).is_null()
		return
	assert_str(effect.text).is_equal(text)
	assert_bool(effect.fits()).override_failure_message(message).is_true()


## The monitor's layout now (the stage's origin at `origin`), after a frame: every text label inside
## its column (the bay's, the item column's, the checkout column's; the rest on the paper); the
## item column's parts inside it, none over another.
func _assert_layout(monitor: MonitorView, origin: Vector2, message: String) -> void:
	await get_tree().process_frame
	var failures: Array[String] = _layout_failures(monitor, origin, message)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## What _assert_layout checks, as failures.
static func _layout_failures(
	monitor: MonitorView, origin: Vector2, message: String
) -> Array[String]:
	var failures: Array[String] = []
	var rooms: Dictionary[Control, Rect2] = {
		monitor.bay(): MonitorView.BAY_RECT,
		monitor.item_column(): MonitorView.ITEM_RECT,
		monitor.checkout(): MonitorView.CHECKOUT_RECT,
		monitor.climax(): MonitorView.PAPER_RECT,
	}
	for label: Label in monitor.shown_labels():
		var room: Rect2 = MonitorView.PAPER_RECT
		for part: Control in rooms:
			if part.is_ancestor_of(label):
				room = rooms[part]
		# The tilted stamps are read by their drawn rects (_assert_stamp_and_tab), the numbers by
		# their ink (their digits roll in clipped cells; monitor_bay_test, count_up_test).
		if label.rotation != 0.0 or label.scale != Vector2.ONE or _in_number(label):
			continue
		var content: Rect2 = Rect2(origin + room.position, room.size).grow(0.5)
		var rect: Rect2 = label.get_global_rect()
		if not content.encloses(rect):
			failures.append("%s: '%s' %s outside %s" % [message, label.text, rect, content])
	var column: Rect2 = Rect2(origin + MonitorView.ITEM_RECT.position, MonitorView.ITEM_RECT.size)
	var parts: Dictionary[String, Rect2] = monitor.item_column().part_rects()
	var names: Array[String] = parts.keys()
	for index: int in range(names.size()):
		var rect: Rect2 = parts[names[index]]
		if not column.grow(0.5).encloses(rect):
			failures.append("%s: %s %s outside the item column" % [message, names[index], rect])
		for other: int in range(index + 1, names.size()):
			if rect.intersects(parts[names[other]]):
				failures.append(
					(
						"%s: %s %s over %s %s"
						% [message, names[index], rect, names[other], parts[names[other]]]
					)
				)
	return failures


## Whether `label` is a digit of a TotalNumber.
static func _in_number(label: Label) -> bool:
	var node: Node = label.get_parent()
	while node != null:
		if node is TotalNumber:
			return true
		node = node.get_parent()
	return false


## The register's reading against the top bar's gauge, the checkout column's number and the
## climax's (while it runs) now, as failures (#105 piece 2: one number everywhere).
static func _sync_failures(screen: ShiftScreen) -> Array[String]:
	var failures: Array[String] = []
	if not screen._led.is_counting():
		return failures
	var reading: int = screen._led.amount()
	var frame: int = Engine.get_process_frames()
	var top: String = screen._quota_meter.amount_label.text
	if top != "€%d" % reading:
		failures.append("frame %d: the top bar %s, the reading %d" % [frame, top, reading])
	var number: int = screen._monitor.checkout().total_number().value()
	if number != reading:
		failures.append("frame %d: the column %d, the reading %d" % [frame, number, reading])
	var climax: MonitorClimax = screen._monitor.climax()
	if climax.is_running() and climax.number().value() != reading:
		failures.append(
			"frame %d: the climax %d, the reading %d" % [frame, climax.number().value(), reading]
		)
	return failures


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## A count-up (not played, in the tree for its tweens) the monitor follows: the tests emit its
## signals.
func _follow(monitor: MonitorView) -> CountUp:
	var count_up: CountUp = auto_free(CountUp.new())
	get_tree().root.add_child(count_up)
	monitor.follow(count_up)
	return count_up


## A landing beat of `kind` landing `land` with `gain` on the item in the scanner (slot 0), its
## lamp `lamp`.
static func _landing(
	kind: CountUpBeat.Kind, land: CountUpBeat.Land, gain: int, lamp: int
) -> CountUpBeat:
	var beat: CountUpBeat = CountUpBeat.new()
	beat.kind = kind
	beat.land = land
	beat.steps = PackedInt32Array([0])
	beat.slot = 0
	beat.scan_slot = 0
	beat.gain = gain
	beat.lamp = lamp
	beat.fly_ms = 180
	return beat


## A step of `step_type` and `value` (its value_after too) on slot 0.
static func _step(step_type: ScoreStep.StepType, value: int = 0) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = step_type
	step.value = value
	step.value_after = value
	step.slot = 0
	return step


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			cards.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return cards


## The monitor's scan text for `definition` (#105): its short sticker text, else its rule text.
static func _scan_text(definition: CardDefinition) -> String:
	var summary: String = definition.sticker_summary()
	return summary if not summary.is_empty() else definition.rule_text


## The screen on shift 1, its scanner following _point on the tests' clock.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._scan.pointer = func() -> Vector2: return _point
	screen._scan.now_ms = func() -> int: return _clock
	await _frames(3)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, card_id]))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()
	await _frames(2)


## The pointer on `view`'s sprite and its hover sent, its hold starting on the tests' clock.
func _hover(screen: ShiftScreen, view: ItemView) -> void:
	await _frames(1)
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)
	await _frames(1)
	assert_object(screen._scan.scanned()).is_same(view)


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
