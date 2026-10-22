extends GdUnitTestSuite
## The monitor bay (the follow-up of #86, mock-up monitor_bay_v1.html, decided with the user on
## 2026-10-21; MonitorView, ScannerBay, LedDisplay). The count view's group: the number and its
## plain gold € centred on x 754 for one- to four-digit totals, the € as tall as the digits, on
## the paper at the largest punch, clear of the bay, the to-go line and the stamp. Planning's bay:
## at BAY_RECT in every mode, belt slot 1's item under NEXT with a pip per belt slot, the held
## item under SCAN with its kind, the bare bed for an empty slot 1, SCANNER in the impulse rack;
## swaps slide out then drop in on the bay's own tweens (cut under reduced motion); on the real
## screen slot 1 follows every refresh, a held scan replaces it, and the count starts with it in
## the bay. Split from monitor_view_test for the file's line limit. The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
## The longest amounts the count layout is expected to show: the digits, and a quota (shift 8's
## 120 with the Big basket's 15%) for the widest to-go texts.
const LONGEST_DIGITS := "9999"
const WIDEST_QUOTA := 138
## The widest three-digit total in the count's digits font, the simulator's largest total
## (reports/balance_sim, shift 8's max: 1118), and a wide four-digit total.
const WIDEST_TOTAL := 400
const LARGEST_TOTAL := 1118
const WIDE_FOUR_DIGITS := 1000

var _folder: String = ""
## Where the tests put the pointer (global), and the scanner's clock (ms).
var _point: Vector2 = Vector2.ZERO
var _clock: int = 0


func before_test() -> void:
	_folder = "user://test_monitor_bay_%d" % Time.get_ticks_usec()
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


## The count view at its fullest (mock-ups count_up_86_v6_scan.html and monitor_bay_v1.html, on the
## paper): the bay at BAY_RECT, the LED's room right of it, the to-go line and the stamp at their
## rects over the sunburst on the whole paper. The number and its plain gold € are one group centred
## on x 754 (the right part's centre) for one- to four-digit totals, inside the room, the € as tall
## as the digits (within 2 px), on their baseline, EURO_GAP px after them; every realistic total up
## to the simulator's largest (1118) shows at the largest digits size. Unpunched, the group's ink
## with its outline and shadow stays on the paper and clear of the bay, the to-go line and the
## stamp; the count-up's punches scale the group about its middle (the € carried with the digits),
## so at the largest punch (capped at the LED's punch_room, with the ease's overshoot: a one-digit
## total keeps it whole) the group stays centred on 754, drawn on the paper and clear
## of the bay. The widest to-go texts fit their line. The digits and
## the € are gold with an ink outline, met or not. At the TOTAL nothing moves.
func test_the_count_content_fits_at_the_largest_punch() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var led: LedDisplay = monitor.led
	led.start_count(WIDEST_QUOTA)
	led.show_subtotal(9999, false)
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	assert_that(led.get_global_rect()).is_equal(MonitorView.LED_COUNT_RECT)
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COUNT)
	assert_bool(led.clip_contents).is_false()
	var paper: Rect2 = MonitorView.PAPER_RECT
	var bay: Rect2 = monitor.bay().get_global_rect()
	var to_go: Label = led.beat().to_go_label()
	var stamp: MetStamp = led.beat().stamp()
	var euro: Label = led.euro_label()
	assert_that(bay).is_equal(MonitorView.BAY_RECT)
	assert_that(to_go.get_global_rect()).is_equal(MonitorView.TO_GO_RECT)
	assert_that(stamp.get_global_rect()).is_equal(MonitorView.STAMP_RECT)
	assert_that(monitor.sunburst().get_global_rect()).is_equal(paper)
	for part: Control in [monitor.bay(), monitor.sunburst(), euro]:
		assert_bool(part.is_visible_in_tree()).override_failure_message(part.name).is_true()
	assert_str(euro.text).is_equal(LedDisplay.EURO_TEXT)
	# The to-go line shows while short of the quota only (past it, the stamp's place).
	assert_bool(to_go.is_visible_in_tree()).is_false()
	led.show_subtotal(1, false)
	assert_bool(to_go.is_visible_in_tree()).is_true()
	led.show_subtotal(9999, false)
	# The z-order: the sunburst behind the bay, the LED over them; over the LED the stickers, then
	# the chips, then the bay's tag (#86 round 7).
	assert_int(monitor.sunburst().get_index()).is_less(monitor.bay().get_parent().get_index())
	assert_int(monitor.bay().get_parent().get_index()).is_less(led.get_index())
	var tag: BayTag = monitor.bay().tag()
	var top: Control = tag.get_parent() as Control
	assert_object(monitor.chips().get_parent()).is_same(top)
	assert_int(top.get_index()).is_greater(led.get_index())
	var stickers: Control = monitor.bay().sticker_parent
	assert_int(stickers.get_index()).is_less(monitor.chips().get_index())
	assert_int(monitor.chips().get_index()).is_less(tag.get_index())
	# The widest plausible tag and a chip mid-flight stay on the paper.
	tag.show_value(999, true)
	var tag_rect: Rect2 = tag.get_global_rect().merge(
		Rect2(tag.get_global_rect().position + BayTag.STRING_RECT.position, BayTag.STRING_RECT.size)
	)
	assert_bool(paper.encloses(tag_rect)).override_failure_message(str(tag_rect)).is_true()
	monitor.chips().make_tween = func() -> Tween:
		var paused: Tween = monitor.create_tween()
		paused.pause()
		return paused
	monitor.chips().fly(999, tag.send_point(), led.digits_text_rect().get_center(), 0.2)
	for progress: float in [0.0, 0.5, 1.0]:
		monitor.chips()._chips[0].progress = progress
		for chip: Rect2 in monitor.chips().chip_rects():
			assert_bool(paper.encloses(chip)).override_failure_message(str(chip)).is_true()
	monitor.chips().clear()
	tag.hide_tag()
	stamp.show_static()
	var stamped: Rect2 = stamp.drawn_rect()
	assert_bool(paper.encloses(stamped)).override_failure_message(str(stamped)).is_true()
	stamp.hide_stamp()
	# The group: centred on 754, the € as tall as the digits; every realistic total at the largest
	# size.
	var digits: Label = led.digits_label()
	assert_str(digits.text).is_equal(LONGEST_DIGITS)
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var largest: float = maxf(
		CountUp.SUBTOTAL_PUNCH + CountUp.SUBTOTAL_PUNCH_MAX + tuning.passes_best_punch,
		CountUp.TOTAL_PUNCH
	)
	var centre: float = MonitorView.RIGHT_RECT.get_center().x
	for amount: int in [7, 56, WIDEST_TOTAL, LARGEST_TOTAL, WIDE_FOUR_DIGITS, 9999]:
		led.show_subtotal(amount, false)
		await _frames(1)
		var text: String = digits.text
		var font_size: int = digits.get_theme_font_size("font_size")
		var message: String = "%s at %d" % [text, font_size]
		if amount <= LARGEST_TOTAL:
			assert_int(font_size).override_failure_message(message).is_equal(
				LedDisplay.COUNT_DIGITS_SIZES[0]
			)
		var ink: Rect2 = led.digits_text_rect()
		var euro_ink: Rect2 = led.euro_text_rect()
		var group: Rect2 = led.digits_text_rect().merge(led.euro_text_rect())
		prints("monitor bay: count group", text, font_size, ":", ink, euro_ink, group)
		var centre_message: String = "%s %s" % [message, group]
		assert_float(group.get_center().x).override_failure_message(centre_message).is_equal_approx(
			centre, 1.5
		)
		(
			assert_bool(MonitorView.LED_COUNT_RECT.encloses(group))
			. override_failure_message(centre_message)
			. is_true()
		)
		assert_float(euro_ink.size.y).override_failure_message(message).is_equal_approx(
			ink.size.y, 2.0
		)
		assert_float(euro_ink.end.y).override_failure_message(message).is_equal_approx(
			ink.end.y, 2.0
		)
		assert_float(euro_ink.position.x - ink.end.x).is_equal_approx(LedDisplay.EURO_GAP, 0.01)
		var outlined: Rect2 = group.grow(LedDisplay.COUNT_OUTLINE)
		var shadowed: Rect2 = outlined.merge(
			Rect2(outlined.position + Vector2.ONE * LedDisplay.COUNT_SHADOW, outlined.size)
		)
		assert_bool(paper.encloses(shadowed)).override_failure_message(text + str(group)).is_true()
		for rect: Rect2 in [bay, MonitorView.TO_GO_RECT, stamped]:
			var clear: String = "%s %s over %s" % [text, shadowed, rect]
			assert_bool(shadowed.intersects(rect)).override_failure_message(clear).is_false()
		# The punch is capped at the room (with the ease's overshoot): a one-digit total keeps the
		# full punch, a longer one punches less and still fits.
		var peak: float = CountUpMotion.peak_of(
			CountUpMotion.capped_punch(largest, led.punch_room())
		)
		if amount < 10:
			assert_float(peak).is_equal_approx(CountUpMotion.peak_of(largest), 0.001)
		else:
			assert_float(peak).is_greater(1.0)
		digits.scale = Vector2(peak, peak)
		var punched: Rect2 = led.digits_text_rect().merge(led.euro_text_rect())
		var punched_outlined: Rect2 = punched.grow(LedDisplay.COUNT_OUTLINE * peak)
		var punched_drawn: Rect2 = punched_outlined.merge(
			Rect2(
				punched_outlined.position + Vector2.ONE * LedDisplay.COUNT_SHADOW * peak,
				punched_outlined.size
			)
		)
		prints("monitor bay: count group", text, font_size, "at", peak, ":", punched_drawn)
		var punched_message: String = "%s at %.3f %s" % [text, peak, punched_drawn]
		(
			assert_float(punched.get_center().x)
			. override_failure_message(punched_message)
			. is_equal_approx(centre, 1.5)
		)
		(
			assert_bool(paper.encloses(punched_drawn))
			. override_failure_message(punched_message)
			. is_true()
		)
		(
			assert_bool(punched_drawn.intersects(bay))
			. override_failure_message(punched_message)
			. is_false()
		)
		digits.scale = Vector2.ONE
	# The widest to-go texts fit their line: short of the quota, on it and past it.
	for amount: int in [WIDEST_QUOTA - 1, WIDEST_QUOTA, 9999]:
		led.show_subtotal(amount if amount != WIDEST_QUOTA - 1 else 1, amount >= WIDEST_QUOTA)
		var line: String = to_go.text
		assert_float(_text_width(to_go)).override_failure_message(line).is_less_equal(
			MonitorView.TO_GO_RECT.size.x
		)
	# Gold with an ink outline, met or not; no green.
	led.show_subtotal(WIDEST_QUOTA, true)
	for label: Label in [digits, euro]:
		assert_that(label.get_theme_color("font_color")).is_equal(Palette.GOLD)
		assert_that(label.get_theme_color("font_outline_color")).is_equal(Palette.INK)
	# The TOTAL keeps the layout; met, the to-go line is off (the stamp replaces it).
	led.show_total()
	await _frames(1)
	assert_that(led.get_global_rect()).is_equal(MonitorView.LED_COUNT_RECT)
	for part: Control in [monitor.bay(), monitor.sunburst(), euro]:
		assert_bool(part.is_visible_in_tree()).override_failure_message(part.name).is_true()
	assert_bool(to_go.visible).is_false()


## Planning's bay (the monitor bay follow-up of #86, mock-up monitor_bay_v1.html), under reduced
## motion (every swap at once): at BAY_RECT in every mode; belt slot 1's item under NEXT with its
## name, a pip per belt slot (slot 1's gold, the other filled ones teal light, the empty ones teal
## shade); a new slot 1 replaces it; a held scan shows the held item under SCAN with its kind on the
## label ("BASE €N", COUPON) and the light on, then slot 1's item comes back; a hold on the item
## already in the bay scans it there (no new art); an empty slot 1 shows the bare bed and "–"; the
## impulse rack's (no belt) reads SCANNER with no pips.
func test_planning_bay_shows_slot_one_and_the_held_item() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var milk: CardDefinition = _card("milk")
	var bread: CardDefinition = _card("bread")
	var coupon: CardDefinition = _first_coupon()
	var bay: ScannerBay = monitor.bay()
	var queue: BayQueue = bay.queue()
	monitor.show_next(milk, 5, 2)
	assert_bool(bay.is_planning()).is_true()
	assert_bool(bay.is_visible_in_tree()).is_true()
	assert_that(bay.get_global_rect()).is_equal(MonitorView.BAY_RECT)
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_object(bay.bed().art().texture).is_same(ArtStyle.item_sprite(milk))
	assert_str(bay.name_label().text).is_equal("MILK")
	assert_bool(bay.shows_scan()).is_false()
	assert_str(queue.text()).is_equal(BayQueue.NEXT_TEXT)
	var shade: Color = BayQueue.EMPTY_SLOT_COLOR
	assert_array(queue.pip_colours()).is_equal(
		[BayQueue.FIRST_SLOT_COLOR, BayQueue.FILLED_SLOT_COLOR, shade, shade, shade]
	)
	var inside: Rect2 = Rect2(Vector2.ZERO, bay.size)
	for pip: Rect2 in queue.pip_rects():
		assert_bool(inside.encloses(pip)).override_failure_message(str(pip)).is_true()
	# A new slot 1.
	monitor.show_next(bread, 5, 1)
	assert_object(bay.bed().shown_definition()).is_same(bread)
	assert_str(bay.name_label().text).is_equal("BREAD")
	var first: Color = BayQueue.FIRST_SLOT_COLOR
	assert_array(queue.pip_colours()).is_equal([first, shade, shade, shade, shade])
	# A held scan: the held item under SCAN, its kind on the label, the light on.
	var none: Array[bool] = []
	monitor.show_scan(milk, null, milk.tags, -1, PackedStringArray(), none)
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_object(monitor.scan_art()).is_same(bay.bed().art())
	assert_bool(bay.shows_scan()).is_true()
	assert_str(queue.text()).is_equal(BayQueue.SCAN_TEXT)
	assert_str(bay.name_label().text).is_equal(ScannerBay.KIND_BASE_TEXT % milk.base)
	# The light blinks on for the scan, then stays on in HELD_COLOR while the item is held.
	await get_tree().create_timer(ScannerBay.LIGHT_S + 0.05).timeout
	assert_that(bay.light_colour()).is_equal(ScannerBay.HELD_COLOR)
	monitor.show_scan(coupon, null, coupon.tags, -1, PackedStringArray(), none)
	assert_object(bay.bed().shown_definition()).is_same(coupon)
	assert_str(bay.name_label().text).is_equal(ScannerBay.KIND_COUPON_TEXT)
	# The scan ends: slot 1's item again, under NEXT.
	monitor.end_scan()
	assert_object(bay.bed().shown_definition()).is_same(bread)
	assert_str(bay.name_label().text).is_equal("BREAD")
	assert_str(queue.text()).is_equal(BayQueue.NEXT_TEXT)
	assert_bool(bay.shows_scan()).is_false()
	await get_tree().create_timer(ScannerBay.LIGHT_S + 0.05).timeout
	assert_that(bay.light_colour()).is_equal(ScannerBay.LIGHT_OFF_COLOR)
	# A hold on the item already in the bay: scanned there, the same art (no drop).
	var art: TextureRect = bay.bed().art()
	monitor.show_scan(bread, null, bread.tags, 2, PackedStringArray(), none)
	assert_object(bay.bed().art()).is_same(art)
	assert_bool(bay.shows_scan()).is_true()
	assert_str(bay.name_label().text).is_equal(ScannerBay.KIND_BASE_TEXT % bread.base)
	monitor.end_scan()
	assert_object(bay.bed().art()).is_same(art)
	assert_str(bay.name_label().text).is_equal("BREAD")
	# An empty slot 1: the bare bed and "–", every pip shaded.
	monitor.show_next(null, 5, 0)
	assert_object(bay.bed().art()).is_null()
	assert_object(bay.bed().shown_definition()).is_null()
	assert_str(bay.name_label().text).is_equal(ScannerBay.GONE_NAME)
	assert_str(bay.bed().idle_label().text).is_equal("")
	assert_array(queue.pip_colours()).is_equal([shade, shade, shade, shade, shade])
	# A held hand item over an empty slot 1 still shows, and goes again.
	monitor.show_scan(milk, null, milk.tags, -1, PackedStringArray(), none)
	assert_object(bay.bed().shown_definition()).is_same(milk)
	monitor.end_scan()
	assert_object(bay.bed().shown_definition()).is_null()
	# The impulse rack: no belt.
	monitor.show_next(null, 0, 0)
	assert_str(queue.text()).is_equal(BayQueue.IDLE_TEXT)
	assert_array(queue.pip_rects()).is_empty()


## Planning's swaps with motion (mock-up monitor_bay_v1.html): the item in the bay slides out
## over PLAN_OUT_S keeping its name, the new one drops in over BayBed.FALL_S with a blank label,
## its name once it has landed; a held item drops in the same way, its kind once landed, and the
## header reads SCAN from its drop. Planning's motion runs on the bay's own tweens (real time),
## never the count-up's.
func test_planning_bay_swaps_slide_out_then_drop_in() -> void:
	var monitor: MonitorView = await _monitor()
	var count_tweens: Array[int] = [0]
	monitor.led.beat().make_tween = func() -> Tween:
		count_tweens[0] += 1
		return monitor.create_tween()
	var milk: CardDefinition = _card("milk")
	var bread: CardDefinition = _card("bread")
	var bay: ScannerBay = monitor.bay()
	monitor.show_next(milk, 3, 2)
	assert_str(bay.name_label().text).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(bay.name_label().text).is_equal("MILK")
	monitor.show_next(bread, 3, 2)
	assert_bool(bay.bed().is_leaving()).is_true()
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_str(bay.name_label().text).is_equal("MILK")
	await get_tree().create_timer(ScannerBay.PLAN_OUT_S + 0.05).timeout
	assert_object(bay.bed().shown_definition()).is_same(bread)
	assert_str(bay.name_label().text).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(bay.name_label().text).is_equal("BREAD")
	var none: Array[bool] = []
	monitor.show_scan(milk, null, milk.tags, -1, PackedStringArray(), none)
	assert_str(bay.queue().text()).is_equal(BayQueue.NEXT_TEXT)
	await get_tree().create_timer(ScannerBay.PLAN_OUT_S + 0.05).timeout
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_str(bay.queue().text()).is_equal(BayQueue.SCAN_TEXT)
	assert_str(bay.name_label().text).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(bay.name_label().text).is_equal(ScannerBay.KIND_BASE_TEXT % milk.base)
	assert_int(count_tweens[0]).is_equal(0)


## On the real screen the shift screen tells the monitor belt slot 1's item on every refresh:
## placing, taking slot 1 out (the next item moves up) and emptying the belt; a held scan on a hand
## item replaces it in the bay until the hold ends. The checkout's count starts with slot 1's item
## already in the bay (the same art: no first drop-in), the queue reading the count's items left.
func test_the_shift_screen_keeps_slot_one_in_the_bay() -> void:
	var screen: ShiftScreen = await _screen()
	var monitor: MonitorView = screen._monitor
	monitor.reduced_motion = func() -> bool: return true
	var bay: ScannerBay = monitor.bay()
	assert_object(bay.bed().shown_definition()).is_null()
	assert_str(bay.name_label().text).is_equal(ScannerBay.GONE_NAME)
	await _place(screen, ["milk", "bread"])
	var run: RunState = screen.run
	assert_object(bay.bed().shown_definition()).is_same(run.row[0].definition)
	assert_str(bay.queue().text()).is_equal(BayQueue.NEXT_TEXT)
	assert_int(bay.queue().pip_rects().size()).is_equal(RowCapacity.card_limit(run.limits))
	# Slot 1 taken out: bread moves up.
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(1)
	assert_str(run.row[0].definition.id).is_equal("bread")
	assert_object(bay.bed().shown_definition()).is_same(run.row[0].definition)
	screen._let_go()
	# A held hand item replaces it while the hold lasts.
	var hand_item: ItemView = screen._hand_box.cards()[0] as ItemView
	await _hover(screen, hand_item)
	_clock += screen._scan.hold_ms()
	await _frames(2)
	assert_object(bay.bed().shown_definition()).is_same(hand_item.card.definition)
	assert_bool(bay.shows_scan()).is_true()
	screen._scan.clear()
	assert_object(bay.bed().shown_definition()).is_same(run.row[0].definition)
	assert_bool(bay.shows_scan()).is_false()
	# A row that passes the shift (slot 1 stays bread), then the checkout: the count starts with
	# slot 1's item in the bay, no drop-in.
	await _place(screen, ["multipack", "milk", "milk", "milk", "milk", "milk"])
	assert_str(run.row[0].definition.id).is_equal("bread")
	assert_int(run.preview().total).is_greater_equal(run.quota())
	var art: TextureRect = bay.bed().art()
	monitor.reduced_motion = func() -> bool: return false
	screen._on_checkout_pressed()
	await _frames(1)
	assert_bool(bay.is_planning()).is_false()
	assert_object(bay.bed().art()).is_same(art)
	assert_str(bay.name_label().text).is_equal(run.row[0].definition.display_name.to_upper())
	assert_str(bay.queue().text()).is_equal(BayQueue.LEFT_TEXT % run.row.size())
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	# Out of the count the bay is planning's again, showing the next belt's slot 1 (or nothing).
	screen._on_reward_skipped()
	await _frames(2)
	assert_bool(bay.is_planning()).is_true()
	var next: CardDefinition = null if run.row.is_empty() else run.row[0].definition
	assert_object(bay.bed().shown_definition()).is_same(next)


# --- Helpers ---------------------------------------------------------------------------------


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _first_coupon() -> CardDefinition:
	for definition: CardDefinition in _cards():
		if definition.is_coupon():
			return definition
	return null


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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
