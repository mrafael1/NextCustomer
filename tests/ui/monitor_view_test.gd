extends GdUnitTestSuite
## The hung monitor (#80, step 4; MonitorView). Its geometry on the real screen: hung under the top
## bar, on the stage, clear of the belt, the receipt and the register, every part of its screen
## inside the paper: the scanner bay at the left in every mode, the channel, the scan's text and
## the notice right of it. A scan's text fits the screen for every card in data/cards, in the hand
## and on the belt (with the worst footer, folded into "+N more" on the smallest size), its art and
## kind in the bay. Its states on the real screen: the store channel in planning
## (monitor_channel_test), the scanned item once a hover is held (never on a plain hover), the
## channel again when the scan ends, a notice over a scan (in ink, never tomato); during the
## count-up the bay shows each beat's item and landing sticker, the line under the digits the to-go
## text from core's ShiftMargin, the digits in gold; the TOTAL keeps the layout, the stamp and the
## "+€N" tab side by side. The bay's motion runs on the count-up's tweens and reduced motion leaves
## it out; the sunburst turns in real time, gold once met. ScreenShade leaves its hole unshaded.
## The count's number and € and planning's bay are in monitor_bay_test. Headless runs never move
## the mouse: the tests set the scanner's pointer and clock. The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## More step lines than any belt item carries, every other one a fizzle whose reason wraps.
const WORST_LINES := 12
const LONG_LINE := "Coupon engine: needs a coupon two slots earlier and finds none there  WASTED"
const SHORT_LINE := "× Multipack  ×3"

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
## its screen's parts lie inside the paper (PAPER_RECT, inside the ink outline), the scan's art
## column apart from its text column, and the count view's parts on the paper and apart.
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
	for part: Rect2 in [ShiftStage.LED_RECT, ShiftStage.NOTICE_RECT]:
		var rect: Rect2 = _on_stage(screen, part)
		assert_bool(paper.encloses(rect)).override_failure_message(str(rect)).is_true()
	# The bay at the paper's left (every mode), the right part beside it (x 615 to 893, centre
	# 754) holding the store channel, the scan's text and the notice, clear of the bay.
	var right: Rect2 = MonitorView.RIGHT_RECT
	assert_bool(MonitorView.PAPER_RECT.encloses(MonitorView.BAY_RECT)).is_true()
	assert_bool(MonitorView.PAPER_RECT.encloses(right)).is_true()
	assert_float(right.position.x).is_greater_equal(MonitorView.BAY_RECT.end.x)
	assert_float(right.get_center().x).is_equal(754.0)
	for part: Rect2 in [MonitorView.CHANNEL_RECT, MonitorView.TEXT_RECT, MonitorView.NOTICE_RECT]:
		assert_bool(right.encloses(part)).override_failure_message(str(part)).is_true()
	# The count view's parts: on the paper, and apart but for the stamp over the to-go line.
	var count_parts: Array[Rect2] = [
		MonitorView.BAY_RECT,
		MonitorView.LED_COUNT_RECT,
		MonitorView.TO_GO_RECT,
	]
	for index: int in range(count_parts.size()):
		var part: Rect2 = count_parts[index]
		(
			assert_bool(MonitorView.PAPER_RECT.encloses(part))
			. override_failure_message(str(part))
			. is_true()
		)
		for other: int in range(index + 1, count_parts.size()):
			var message: String = "%s over %s" % [part, count_parts[other]]
			(
				assert_bool(part.intersects(count_parts[other]))
				. override_failure_message(message)
				. is_false()
			)
	assert_bool(MonitorView.PAPER_RECT.encloses(MonitorView.STAMP_RECT)).is_true()
	assert_bool(MonitorView.STAMP_RECT.intersects(MonitorView.TO_GO_RECT)).is_true()
	assert_bool(MonitorView.PAPER_RECT.has_point(MonitorView.SUNBURST_CENTRE)).is_true()
	assert_bool(MonitorView.LED_COUNT_RECT.has_point(MonitorView.SUNBURST_CENTRE)).is_true()
	assert_float(MonitorView.SUNBURST_CENTRE.x).is_equal(right.get_center().x)
	for part: Rect2 in [MonitorView.LED_COUNT_RECT, MonitorView.TO_GO_RECT, MonitorView.STAMP_RECT]:
		assert_bool(right.encloses(part)).override_failure_message(str(part)).is_true()
	# In planning the store channel has the right part (the LED hidden at its compact place) and
	# the bay its place at the left, showing belt slot 1's item; the monitor takes no clicks.
	assert_that(screen._led.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.LED_RECT))
	assert_bool(screen._led.visible).is_false()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_that(monitor.channel.get_global_rect()).is_equal(
		_on_stage(screen, MonitorView.CHANNEL_RECT)
	)
	assert_bool(monitor.bay().is_visible_in_tree()).is_true()
	assert_that(monitor.bay().get_global_rect()).is_equal(_on_stage(screen, MonitorView.BAY_RECT))
	assert_bool(monitor.bay().is_planning()).is_true()
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Every card in data/cards, scanned in the hand and on the belt (with a short footer, then the
## worst one): its art in the bay's bed, its kind on the bay's label (fitted), its name, pays, tag
## line, rule text and step lines inside TEXT_RECT right of the bay, none overlapping, the name and
## the rule whole; a short footer shows at the largest size, the worst one folds into "+N more" on
## the smallest.
func test_every_card_scan_fits_the_screen() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var worst: PackedStringArray = PackedStringArray()
	var worst_fizzles: Array[bool] = []
	for index: int in range(WORST_LINES):
		worst.append(LONG_LINE if index % 2 == 0 else SHORT_LINE)
		worst_fizzles.append(index % 2 == 0)
	var short: PackedStringArray = PackedStringArray([SHORT_LINE, LONG_LINE])
	var short_fizzles: Array[bool] = [false, true]
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(59)
	var tiers: Dictionary[int, int] = {}
	for definition: CardDefinition in cards:
		var aisle: AisleDefinition = balance.aisle_of(definition)
		var none: Array[bool] = []
		monitor.show_scan(definition, aisle, definition.tags, -1, PackedStringArray(), none)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s in the hand" % definition.id)
		assert_object(monitor.scan_footer()).is_null()
		monitor.show_scan(definition, aisle, definition.tags, definition.base, short, short_fizzles)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s on the belt" % definition.id)
		var texts: PackedStringArray = monitor.scan_footer().texts()
		assert_bool(texts == short).override_failure_message(str(texts)).is_true()
		var count: int = tiers.get(monitor.scan_tier(), 0)
		tiers[monitor.scan_tier()] = count + 1
		monitor.show_scan(definition, aisle, definition.tags, definition.base, worst, worst_fizzles)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s, worst footer" % definition.id)
		assert_int(monitor.scan_tier()).is_equal(MonitorView.TIERS.size() - 1)
		texts = monitor.scan_footer().texts()
		var shown: int = texts.size() - 1
		assert_int(shown).override_failure_message(definition.id).is_greater_equal(1)
		assert_str(texts[shown]).is_equal(ScanFooter.MORE_TEXT % (WORST_LINES - shown))
	prints("#80 monitor scan tiers with a short footer:", tiers)
	var at_largest: int = tiers.get(0, 0)
	assert_int(2 * at_largest).is_greater(cards.size())


## On the real screen: the store channel in planning; a plain hover on a belt item leaves it on the
## channel; the held hover fills it with the item (its art, name, rule, pays and step lines worded
## as the receipt words them, no popup); a notice takes the screen while it lasts, then the scan
## comes back; leaving the item brings the channel back, with no projected total on the monitor.
## A hand item shows no pays or step lines.
func test_a_held_scan_fills_the_monitor_then_it_goes_back_to_the_channel() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "bread", "coffee"])
	var monitor: MonitorView = screen._monitor
	# The held item in the bay at once (monitor_bay_test covers the swaps' motion).
	monitor.reduced_motion = func() -> bool: return true
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	_clock += screen._scan.hold_ms() - 1
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_bool(monitor.channel.visible).is_true()
	_clock += 1
	await _frames(2)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(screen._led.visible).is_false()
	var definition: CardDefinition = view.card.definition
	assert_str(monitor.scan_name_label().text).is_equal(definition.display_name)
	assert_str(monitor.scan_rule_label().text).is_equal(definition.rule_text)
	assert_object(monitor.scan_art().texture).is_same(ArtStyle.item_sprite(definition))
	var result: ScoreResult = screen.run.preview()
	var expected: PackedStringArray = PackedStringArray()
	for step: ScoreStep in ScanController.footer_steps(result, 2):
		expected.append(ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)))
	var texts: PackedStringArray = monitor.scan_footer().texts()
	assert_bool(texts == expected).override_failure_message(str(texts)).is_true()
	assert_bool(_shown_texts(monitor).has("€%d" % result.payouts[2])).is_true()
	assert_bool(_shown_texts(monitor).has(MonitorView.PAYS_WORD)).is_true()
	# A notice takes the screen while it lasts, in ink (tomato is for fizzles, CHECKOUT and
	# CLOSED); the scan comes back.
	screen._notice_label.show_notice("Row full (9/9 items): take an item out first")
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_bool(screen._led.visible).is_false()
	assert_bool(monitor.channel.visible).is_false()
	assert_bool(screen._notice_label.is_visible_in_tree()).is_true()
	var notice_colour: Color = screen._notice_label.get_theme_color("font_color")
	assert_that(notice_colour).is_equal(MonitorView.NOTICE_COLOR)
	for tomato: Color in [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT]:
		assert_bool(notice_colour == tomato).is_false()
	screen._notice_label.clear_notice()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	# Off the item: the store channel again, no projected total on the monitor.
	_point = Vector2(-100, -100)
	view.unhovered.emit(view)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_null()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_bool(screen._led.visible).is_false()
	assert_bool(_shown_texts(monitor).has(LedDisplay.PROJECTED_TEXT)).is_false()
	# A hand item: no pays and no step lines.
	var hand_item: ItemView = screen._hand_box.cards()[0] as ItemView
	await _hover(screen, hand_item)
	_clock += screen._scan.hold_ms()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_object(monitor.scan_footer()).is_null()
	assert_bool(_shown_texts(monitor).has(MonitorView.PAYS_WORD)).is_false()
	screen._scan.clear()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)


## On the real screen, every count-up beat shows on the monitor as it starts: the bay holds the
## beat's scanned item (its art and name) and the beat's landing sticker when it has one on that
## item (ScannerBay.landing_spec), the step line is the receipt's wording, the line under the
## digits the to-go text of the subtotal shown (core's ShiftMargin), the digits gold; the LED in
## its count place. At the end the TOTAL keeps the place with the total's margin, met (quota_met
## once, with its pop, at the ding).
func test_the_count_up_shows_each_beat_on_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var monitor: MonitorView = screen._monitor
	var led: LedDisplay = screen._led
	var quota: int = screen.run.quota()
	var failures: Array[String] = []
	var beats: Array[int] = []
	var stickers: Array[int] = [0]
	var count_place: Rect2 = _on_stage(screen, MonitorView.LED_COUNT_RECT)
	var record: Callable = func(
		beat: CountUpBeat, step: ScoreStep, line: String, _view: CardView, _items: int
	) -> void:
		beats.append(beat.slot)
		var where: String = "beat on slot %d (%s)" % [beat.slot, CountUpBeat.Kind.keys()[beat.kind]]
		if monitor.mode() != MonitorView.Mode.COUNT:
			failures.append("%s: monitor in mode %d" % [where, monitor.mode()])
		var bay: ScannerBay = monitor.bay()
		if beat.scan_slot >= 0:
			var scanned: CardDefinition = screen.run.row[beat.scan_slot].definition
			if bay.bed().art() == null or bay.bed().art().texture != ArtStyle.item_sprite(scanned):
				failures.append("%s: another item in the bay" % where)
			if bay.name_label().text != scanned.display_name.to_upper():
				failures.append("%s: bay name '%s'" % [where, bay.name_label().text])
			var spec: StickerSpec = ScannerBay.landing_spec(beat, step)
			if spec != null and step.slot == beat.scan_slot:
				stickers[0] += 1
				var sticker: EffectSticker = bay.landing_sticker()
				if sticker == null or sticker.text() != spec.text:
					failures.append("%s: sticker not '%s'" % [where, spec.text])
		if line != ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)):
			failures.append("%s: line '%s'" % [where, line])
		var shown: int = int(led.digits_label().text)
		var to_go: String = LedBeat.to_go_text(ShiftMargin.of(shown, quota))
		if led.beat().to_go_label().text != to_go:
			failures.append("%s: to go '%s'" % [where, led.beat().to_go_label().text])
		if led.digits_label().get_theme_color("font_color") != Palette.GOLD:
			failures.append("%s: digits not gold" % where)
		# The monitor shakes at the quota (the stage's TankBurst moves it).
		var shaken: Rect2 = Rect2(
			count_place.position + screen._stage.tank_burst.shake_offset(), count_place.size
		)
		if not led.get_global_rect().is_equal_approx(shaken):
			failures.append("%s: LED at %s" % [where, led.get_global_rect()])
	screen._count_up.beat_started.connect(record)
	var pops: Array[bool] = []
	screen._count_up.quota_met.connect(func(pop: bool) -> void: pops.append(pop))
	screen._on_checkout_pressed()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	screen._count_up.beat_started.disconnect(record)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(beats.size()).is_equal(screen._count_up.plan.beats.size())
	# Every item's base, and Multipack's x3 on the milks, slapped their stickers.
	assert_int(stickers[0]).is_greater(PASSING_ROW.size())
	for slot: int in range(PASSING_ROW.size()):
		assert_bool(beats.has(slot)).override_failure_message(str(slot)).is_true()
	# The TOTAL in the count place, with the total's margin, met.
	var total: int = screen.run.last_result.total
	assert_str(led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	var offset: Vector2 = screen._stage.tank_burst.shake_offset()
	assert_that(led.get_global_rect()).is_equal(
		Rect2(count_place.position + offset, count_place.size)
	)
	assert_str(led.beat().to_go_label().text).is_equal(
		LedBeat.to_go_text(ShiftMargin.of(total, quota))
	)
	assert_str(led.beat().to_go_label().text).is_equal(LedBeat.OVER_TEXT % (total - quota))
	assert_bool(monitor.bay().is_visible_in_tree()).is_true()
	await _frames(2)
	assert_array(pops).is_equal([true])
	assert_that(led.digits_label().get_theme_color("font_color")).is_equal(Palette.GOLD)
	# Met (#86 v6): the light green, the sunburst gold; once the tab is in, the stamp over the
	# line and the "+€N" tab beside it, both on the paper, and the monitor back at rest.
	await get_tree().create_timer(OverTab.DELAY_S + OverTab.POP_S + 0.6).timeout
	var paper: Rect2 = _on_stage(screen, MonitorView.PAPER_RECT)
	assert_that(monitor.bay().light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
	assert_bool(monitor.sunburst().is_met()).is_true()
	assert_bool(led.beat().stamp().is_showing()).is_true()
	assert_bool(led.beat().to_go_label().visible).is_false()
	assert_bool(paper.encloses(led.beat().stamp().drawn_rect())).is_true()
	var tab: OverTab = monitor.over_tab()
	assert_bool(tab.is_visible_in_tree()).is_true()
	assert_str(tab.label().text).is_equal(LedBeat.OVER_TEXT % (total - quota))
	assert_bool(paper.encloses(tab.get_global_rect())).is_true()
	_assert_tab_beside_stamp(tab, led.beat().stamp())
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)
	# The next shift's planning: the store channel, the LED blank, hidden and compact.
	screen._on_reward_skipped()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_bool(led.visible).is_false()
	assert_that(led.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.LED_RECT))
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	# Nothing of the met state is left for the next count.
	assert_bool(tab.is_showing()).is_false()
	assert_bool(monitor.sunburst().is_met()).is_false()
	assert_bool(monitor.bay().is_met()).is_false()
	assert_bool(screen._stage.tank_burst.is_active()).is_false()


## A last payout crossing the quota (met with the TOTAL, D5): through the held breath the number is
## past the quota yet the to-go line stays hidden (never "+€N" under the number before the stamp)
## and the stamp is not in yet. At the TOTAL the SPEND MET stamp lands at STAMP_RECT on the paper
## in place of the line, the "+€N" tab sits beside it, and both stay through the dessert.
func test_a_total_met_on_the_last_payout_shows_the_stamp_and_the_tab_not_the_line() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var result: ScoreResult = screen.run.preview()
	# A euro under the total: only the last payout reaches it, and the tab says "+€1".
	var quota: int = result.total - 1
	var count_up: CountUp = screen._count_up
	var led: LedDisplay = screen._led
	var monitor: MonitorView = screen._monitor
	var line: Label = led.beat().to_go_label()
	var stamp: MetStamp = led.beat().stamp()
	count_up.play(
		result,
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	)
	assert_bool(count_up.plan.chip_at_total).is_true()
	var failures: Array[String] = []
	var past_frames: int = 0
	while not count_up._met:
		if int(led.digits_label().text) >= quota:
			past_frames += 1
			if line.is_visible_in_tree():
				failures.append("line '%s' shown at %s" % [line.text, led.digits_label().text])
			if stamp.is_showing():
				failures.append("stamp in at %s before the met" % led.digits_label().text)
		elif not line.is_visible_in_tree():
			failures.append("line hidden at %s, short" % led.digits_label().text)
		await get_tree().process_frame
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(past_frames).is_greater(0)
	assert_str(led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	# The stamp slams and the tab pops in (real time); the monitor back at rest after the shakes.
	var waited: int = Time.get_ticks_msec()
	var wait_ms: float = (OverTab.DELAY_S + OverTab.POP_S + 0.6) * 1000.0
	while Time.get_ticks_msec() - waited < wait_ms:
		await get_tree().process_frame
	while monitor.position != ShiftStage.MONITOR_RECT.position:
		await get_tree().process_frame
	_assert_stamp_and_tab(screen, result.total - quota)
	while count_up._playing:
		await get_tree().process_frame
	_assert_stamp_and_tab(screen, result.total - quota)


## The met TOTAL on screen: the stamp at STAMP_RECT on the paper, the to-go line hidden, the tab
## saying `over` beside the stamp, on the paper.
func _assert_stamp_and_tab(screen: ShiftScreen, over: int) -> void:
	var origin: Vector2 = screen._stage.get_global_rect().position
	var paper: Rect2 = Rect2(origin + MonitorView.PAPER_RECT.position, MonitorView.PAPER_RECT.size)
	var stamp: MetStamp = screen._led.beat().stamp()
	var stamp_rect: Rect2 = Rect2(
		origin + MonitorView.STAMP_RECT.position, MonitorView.STAMP_RECT.size
	)
	assert_str(screen._led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	assert_bool(stamp.is_visible_in_tree()).is_true()
	assert_that(stamp.get_global_rect()).is_equal(stamp_rect)
	assert_bool(paper.encloses(stamp.drawn_rect())).is_true()
	assert_bool(screen._led.beat().to_go_label().is_visible_in_tree()).is_false()
	var tab: OverTab = screen._monitor.over_tab()
	assert_bool(tab.is_visible_in_tree()).is_true()
	assert_str(tab.label().text).is_equal(LedBeat.OVER_TEXT % over)
	assert_bool(paper.encloses(tab.get_global_rect())).is_true()
	_assert_tab_beside_stamp(tab, stamp)


## The "+€N" tab beside the stamp, one row under the number: its drawn rect (tilted) right of the
## stamp's, not over it, both on the paper, the two centred together under the group (on x 754,
## within 20 px: the tab's width follows its amount).
func _assert_tab_beside_stamp(tab: OverTab, stamp: MetStamp) -> void:
	var stamp_rect: Rect2 = stamp.drawn_rect()
	var tab_rect: Rect2 = _tilted_rect(tab)
	var message: String = "tab %s, stamp %s" % [tab_rect, stamp_rect]
	assert_bool(tab_rect.intersects(stamp_rect)).override_failure_message(message).is_false()
	assert_float(tab_rect.position.x).override_failure_message(message).is_greater(
		stamp_rect.end.x - 1.0
	)
	var origin: Vector2 = tab.get_global_rect().position - OverTab.POSITION
	var paper: Rect2 = Rect2(origin + MonitorView.PAPER_RECT.position, MonitorView.PAPER_RECT.size)
	assert_bool(paper.encloses(tab_rect)).override_failure_message(message).is_true()
	var row_centre: float = stamp_rect.merge(tab_rect).get_center().x - origin.x
	assert_float(row_centre).override_failure_message(message).is_equal_approx(754.0, 20.0)


## A control's rect as drawn (global), with its rotation about its pivot.
static func _tilted_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform()
	var rect: Rect2 = Rect2(transform.origin, Vector2.ZERO)
	var size: Vector2 = control.size
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		rect = rect.expand(transform * corner)
	return rect


## The quota met on the monitor (show_met, CountUp's quota_met; #86 v6), with its pop: the bay's
## light green and its sticker knocked off, the sunburst gold and boosted, the stage's TankBurst
## out of the € (the monitor shaking), all in real time; the stamp slams after STAMP_DELAY_S
## (another shake as it lands), the "+€N" tab comes in after OverTab.DELAY_S beside the stamp, on
## the paper, turned. A payout's chip flies into the digits (on the LED's first rise after its
## beat) and, as it lands, the gold pours from the gap before the € into the €; once met it spurts
## and punches the tab. A new count takes it all off.
func test_the_quota_met_bursts_on_the_monitor() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	var origin: Vector2 = stage.get_global_rect().position
	monitor.led.start_count(40)
	var count_up: CountUp = _follow(monitor)
	var bay: ScannerBay = monitor.bay()
	bay.land(StickerSpec.new())
	count_up.beat_started.emit(_payout_beat(30), _payout_step(30), "", null, 1)
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()
	monitor.led.show_subtotal(30, false)
	# The chip flies first; the pour follows as it lands in the number.
	assert_int(monitor.chips().chip_rects().size()).is_equal(1)
	await get_tree().create_timer(ReceiptFly.FLIGHT_MAX + 0.05).timeout
	burst.advance(0.001)
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_not_empty()
	# One pour per payout: the roll's next readings pour nothing more.
	var pours: int = burst._pours.size()
	monitor.led.show_subtotal(31, false)
	assert_array(monitor.chips().chip_rects()).is_empty()
	assert_int(burst._pours.size()).is_equal(pours)
	monitor.led.show_subtotal(52, true)
	count_up.quota_met.emit(true)
	assert_bool(bay.is_met()).is_true()
	assert_that(bay.light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
	assert_object(bay.landing_sticker()).is_null()
	assert_bool(monitor.sunburst().is_met()).is_true()
	assert_float(monitor.sunburst().turn_speed()).is_greater(Sunburst.TURN)
	assert_float(monitor.sunburst().radius()).is_equal(Sunburst.MET_RADIUS)
	assert_bool(burst.is_active()).is_true()
	var stamp: MetStamp = monitor.led.beat().stamp()
	assert_bool(stamp.is_showing()).is_false()
	# The to-go line goes at the quota, before the stamp lands.
	assert_bool(monitor.led.beat().to_go_label().visible).is_false()
	var tab: OverTab = monitor.over_tab()
	assert_bool(tab.is_showing()).is_false()
	var shaken: bool = false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < roundi(MonitorView.STAMP_DELAY_S * 1000.0) + 200:
		shaken = shaken or monitor.position != ShiftStage.MONITOR_RECT.position
		await get_tree().process_frame
	assert_bool(shaken).is_true()
	assert_bool(stamp.is_showing()).is_true()
	await get_tree().create_timer(OverTab.DELAY_S).timeout
	assert_bool(tab.is_visible_in_tree()).is_true()
	assert_str(tab.label().text).is_equal("+€12")
	await get_tree().create_timer(OverTab.POP_S + 0.6).timeout
	var paper: Rect2 = Rect2(origin + MonitorView.PAPER_RECT.position, MonitorView.PAPER_RECT.size)
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	assert_float(tab.rotation_degrees).is_equal_approx(OverTab.TILT_DEG, 0.001)
	assert_vector(tab.position).is_equal(
		MonitorView.local(Rect2(OverTab.POSITION, Vector2.ZERO)).position
	)
	assert_float(tab.size.y).is_equal(OverTab.HEIGHT)
	assert_float(tab.size.x).is_greater(OverTab.PAD_X * 2.0 + 20.0)
	assert_bool(paper.encloses(tab.get_global_rect())).is_true()
	_assert_tab_beside_stamp(tab, stamp)
	assert_bool(paper.encloses(stamp.drawn_rect())).is_true()
	# A later payout: a chip, then a pour, a spurt (a jet) and the tab punched.
	burst.clear()
	count_up.beat_started.emit(_payout_beat(5), _payout_step(5), "", null, 1)
	monitor.led.show_subtotal(57, true)
	assert_str(tab.label().text).is_equal("+€17")
	await get_tree().create_timer(ReceiptFly.FLIGHT_MAX + 0.05).timeout
	burst.advance(0.001)
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_not_empty()
	assert_bool(burst._jets.is_empty()).is_false()
	assert_float(await _largest_scale(tab, TankBurst.POUR_S + 0.3)).is_greater(1.0)
	# A new count: everything off.
	monitor.led.start_count(40)
	assert_bool(tab.is_showing()).is_false()
	assert_bool(stamp.is_showing()).is_false()
	assert_bool(bay.is_met()).is_false()
	assert_bool(monitor.sunburst().is_met()).is_false()
	assert_bool(burst.is_active()).is_false()
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)


## Reduced motion keeps the met states and drops the motion: the stamp and the tab at once and
## still, no pour, no particles but the bezel's still splashes, no shake, no punch; without a pop
## (a resumed checkout) the stamp and the tab show at once and nothing bursts at all.
func test_reduced_motion_meets_the_quota_at_once() -> void:
	var stage: ShiftStage = await _stage()
	var monitor: MonitorView = stage.monitor
	var burst: TankBurst = stage.tank_burst
	monitor.reduced_motion = func() -> bool: return true
	monitor.led.start_count(40)
	var count_up: CountUp = _follow(monitor)
	count_up.beat_started.emit(_payout_beat(45), _payout_step(45), "", null, 1)
	monitor.led.show_subtotal(45, false)
	# No chip, no pour.
	assert_array(monitor.chips().chip_rects()).is_empty()
	assert_array(burst.drawn_rects(TankBurst.Layer.POUR)).is_empty()
	monitor.led.show_subtotal(45, true)
	count_up.quota_met.emit(true)
	var stamp: MetStamp = monitor.led.beat().stamp()
	var tab: OverTab = monitor.over_tab()
	assert_bool(stamp.is_showing()).is_true()
	assert_bool(stamp.is_slamming()).is_false()
	assert_bool(tab.is_showing()).is_true()
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	assert_int(burst._splashes.size()).is_equal(TankBurst.STILL_SPLASHES.size())
	# The still splashes stay drawn but take no frames: the layer's clock stands still.
	var clock: float = burst._time
	await _frames(3)
	assert_float(burst._time).is_equal(clock)
	assert_int(burst._splashes.size()).is_equal(TankBurst.STILL_SPLASHES.size())
	assert_vector(monitor.position).is_equal(ShiftStage.MONITOR_RECT.position)
	count_up.beat_started.emit(_payout_beat(5), _payout_step(5), "", null, 1)
	monitor.led.show_subtotal(50, true)
	await _frames(1)
	assert_vector(tab.scale).is_equal(Vector2.ONE)
	assert_array(burst.drawn_rects(TankBurst.Layer.PARTICLES)).is_empty()
	assert_array(monitor.chips().chip_rects()).is_empty()
	# No pop: at once, with nothing bursting, even with motion.
	monitor.reduced_motion = func() -> bool: return false
	monitor.led.start_count(40)
	monitor.led.show_subtotal(50, true)
	count_up.quota_met.emit(false)
	assert_bool(stamp.is_showing()).is_true()
	assert_bool(stamp.is_slamming()).is_false()
	assert_bool(tab.is_showing()).is_true()
	assert_bool(burst.is_active()).is_false()


## The to-go text from core's ShiftMargin: short of the quota, on it and past it.
func test_the_to_go_text_follows_the_margin() -> void:
	assert_str(LedBeat.to_go_text(ShiftMargin.of(22, 73))).is_equal("€51 to go")
	assert_str(LedBeat.to_go_text(ShiftMargin.of(73, 73))).is_equal(LedBeat.ON_QUOTA_TEXT)
	assert_str(LedBeat.to_go_text(ShiftMargin.of(85, 73))).is_equal("+€12")


## The bay follows the monitor's reduced motion (the item at rest, the sticker at its size, the tag
## at once) and takes its per-beat tweens from the LED's beat (make_tween: the count-up's on the
## real screen): the bed's, the tag's and the chips'.
func test_the_bay_takes_the_monitors_motion_and_tweens() -> void:
	var monitor: MonitorView = await _monitor()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var reduced: Array[bool] = [true]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	var made: Array[Tween] = []
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween().set_speed_scale(CountUp.FAST_FORWARD)
		made.append(tween)
		return tween
	monitor.led.start_count(34)
	var count_up: CountUp = _follow(monitor)
	var bay: ScannerBay = monitor.bay()
	var base: ScoreStep = ScoreStep.new()
	base.value = 2
	base.value_after = 2
	base.slot = 0
	var beat: CountUpBeat = CountUpBeat.new()
	beat.kind = CountUpBeat.Kind.MERGED_PLAIN
	beat.steps = PackedInt32Array([0])
	beat.slot = 0
	beat.scan_slot = 0
	beat.opens_slot = true
	# No view: no item to bring in, the sticker still slaps (at its size).
	count_up.beat_started.emit(beat, base, "", null, 1)
	assert_object(bay.bed().art()).is_null()
	assert_object(bay.landing_sticker()).is_not_null()
	assert_vector(bay.landing_sticker().scale).is_equal(Vector2.ONE)
	bay.follow_beat(beat, base, milk)
	assert_object(bay.bed().art()).is_not_null()
	assert_vector(bay.bed().art().scale).is_equal(Vector2.ONE)
	assert_int(bay.tag().value()).is_equal(2)
	var made_before: int = made.size()
	reduced[0] = false
	bay.bed().drop_in(milk, BayBed.FALL_S)
	bay.bed().scan(false)
	bay.tag().count_to(5, true, 0.0)
	bay.land(ScannerBay.landing_spec(beat, base))
	assert_int(made.size()).is_equal(made_before + 4)
	assert_float(bay.landing_sticker().scale.x).is_greater(1.0)
	monitor.chips().fly(3, bay.tag().send_point(), monitor.led.digits_text_rect().get_center(), 0.2)
	assert_int(made.size()).is_equal(made_before + 5)
	# On the real screen the LED's beat takes the count-up's.
	var screen: ShiftScreen = await _screen()
	assert_bool(screen._led.beat().make_tween == screen._count_up._tween).is_true()


## The sunburst over the whole paper: shown in the count only, cream and paper rays, mustard light
## and pale once met (set_met), back to cream for a new count; it turns in real time, BOOST times
## faster after boost(), easing back; under reduced motion it stands still.
func test_the_sunburst_turns_and_turns_gold() -> void:
	var monitor: MonitorView = await _monitor()
	var sunburst: Sunburst = monitor.sunburst()
	var reduced: Array[bool] = [false]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	assert_bool(sunburst.is_visible_in_tree()).is_false()
	monitor.led.start_count(34)
	await _frames(1)
	assert_bool(sunburst.is_visible_in_tree()).is_true()
	assert_that(sunburst.get_global_rect()).is_equal(MonitorView.PAPER_RECT)
	assert_int(sunburst.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_array(sunburst.ray_colours()).is_equal([Palette.CREAM, Palette.PAPER])
	var start: float = sunburst.angle()
	await get_tree().create_timer(0.3).timeout
	assert_float(sunburst.angle()).is_not_equal(start)
	assert_float(sunburst.turn_speed()).is_equal_approx(Sunburst.TURN, 0.0001)
	sunburst.set_met(true)
	assert_bool(sunburst.is_met()).is_true()
	assert_array(sunburst.ray_colours()).is_equal([Palette.MUSTARD_LIGHT, Palette.MUSTARD_PALE])
	assert_float(sunburst.radius()).is_greater(Sunburst.RADIUS)
	sunburst.boost()
	assert_float(sunburst.turn_speed()).is_greater(Sunburst.TURN * (Sunburst.BOOST - 1.0))
	await get_tree().create_timer(Sunburst.BOOST_SECONDS + 0.1).timeout
	assert_float(sunburst.turn_speed()).is_equal_approx(Sunburst.TURN, 0.0001)
	reduced[0] = true
	assert_float(sunburst.turn_speed()).is_equal(0.0)
	start = sunburst.angle()
	await _frames(3)
	assert_float(sunburst.angle()).is_equal(start)
	sunburst.boost()
	assert_float(sunburst.turn_speed()).is_equal(0.0)
	# A new count: cream again.
	monitor.led.start_count(40)
	assert_bool(sunburst.is_met()).is_false()
	assert_array(sunburst.ray_colours()).is_equal([Palette.CREAM, Palette.PAPER])
	monitor.led.clear()
	assert_bool(sunburst.is_visible_in_tree()).is_false()


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


## The scan on the screen: the art in the bay's bed (at rest: the monitor here has reduced
## motion), its kind on the bay's label, whole; every other text label shown inside TEXT_RECT, the
## bay's inside BAY_RECT; the scan's own labels (name, pays, tag line and rule) apart, the name on
## one row and the rule whole.
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
	var kind: Label = bay.name_label()
	assert_str(kind.text).is_equal(ScannerBay.kind_text(definition))
	assert_float(_text_width(kind)).override_failure_message(message).is_less_equal(kind.size.x)
	for label: Label in monitor.shown_labels():
		var rect: Rect2 = label.get_global_rect()
		var room: Rect2 = (
			MonitorView.BAY_RECT if bay.is_ancestor_of(label) else MonitorView.TEXT_RECT
		)
		(
			assert_bool(room.encloses(rect))
			. override_failure_message("%s: '%s' %s" % [message, label.text, rect])
			. is_true()
		)
	var own: Array[Control] = [bay]
	for child: Node in monitor._scan_view.get_children():
		if child is Label:
			own.append(child as Control)
	for index: int in range(own.size()):
		for other: int in range(index + 1, own.size()):
			var a: Rect2 = own[index].get_global_rect()
			var b: Rect2 = own[other].get_global_rect()
			(
				assert_bool(a.intersects(b))
				. override_failure_message("%s: %s over %s" % [message, a, b])
				. is_false()
			)
	var name_label: Label = monitor.scan_name_label()
	assert_str(name_label.text).is_equal(definition.display_name)
	assert_float(_text_width(name_label)).override_failure_message(message).is_less_equal(
		name_label.size.x
	)
	var rule: Label = monitor.scan_rule_label()
	assert_str(rule.text).is_equal(definition.rule_text)
	assert_int(rule.get_visible_line_count()).override_failure_message(message).is_equal(
		rule.get_line_count()
	)


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## A bare stage (the monitor with the tank's burst layer) in the window.
func _stage() -> ShiftStage:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await _frames(1)
	return stage


## The largest x scale `control` takes over the next `seconds` (real time, frame by frame).
func _largest_scale(control: Control, seconds: float) -> float:
	var largest: float = control.scale.x
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame
		largest = maxf(largest, control.scale.x)
	return largest


## A count-up (not played) the monitor follows: the tests emit its signals.
func _follow(monitor: MonitorView) -> CountUp:
	var count_up: CountUp = auto_free(CountUp.new())
	monitor.follow(count_up)
	return count_up


## A payout beat of `amount` on the item in the scanner (slot 0).
static func _payout_beat(amount: int) -> CountUpBeat:
	var beat: CountUpBeat = CountUpBeat.new()
	beat.kind = CountUpBeat.Kind.PAYOUT
	beat.steps = PackedInt32Array([0])
	beat.slot = 0
	beat.scan_slot = 0
	beat.payout = amount
	return beat


static func _payout_step(amount: int) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = ScoreStep.StepType.PAYOUT
	step.value = amount
	step.value_after = amount
	step.slot = 0
	return step


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			cards.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return cards


## A label's text width, in its own font and size.
static func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _shown_texts(monitor: MonitorView) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in monitor.shown_labels():
		texts.append(label.text)
	return texts


## The screen past the impulse rack, its scanner following _point on the tests' clock.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
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
