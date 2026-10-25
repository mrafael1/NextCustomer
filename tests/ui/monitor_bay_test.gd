extends GdUnitTestSuite
## The monitor bay (the follow-up of #86, mock-up monitor_bay_v1.html; #105 piece 2, mock-up
## readability_v3.html; MonitorView, ScannerBay, CheckoutColumn). The checkout column's number: the
## group ("N€") sized for the count's final total (CountTotalTuning.number_sizes, fit_size),
## centred on its column, for one- to four-digit totals, inside the column and the paper at the
## largest punch, clear of the caption, and its widest status texts fitting their line. Planning's
## bay: at BAY_RECT in every mode, belt slot 1's item under NEXT with a pip per belt slot and its
## family chip, the held item under SCAN, the bare bed and "–" for an empty slot 1, SCANNER with no
## belt slots; swaps slide out then drop in on the bay's own tweens (cut under reduced motion); on
## the real screen slot 1 follows every refresh, a held scan replaces it, and the count starts
## with it in the bay. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
## The totals the number is checked at: one to four digits, the widest three-digit one, the
## simulator's largest total (reports/balance_sim, shift 8's max: 1118) and a wide four-digit one.
const TOTALS: Array[int] = [7, 88, 888, 1118, 9999]
## The largest quota (shift 8's 120 with the Big basket's 15%) for the widest status texts.
const LARGEST_QUOTA := 138

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


## The checkout column's number in the count (#105 piece 2): for each of TOTALS it takes the
## largest of number_sizes its digit count fits the column's room at rest at (fit_size), is centred
## on the column's NUMBER_X, and its ink stays inside the column, on the paper and under the
## caption's line; a punch runs into the column's clip at the paper's edge. The status texts'
## widest ("N€ to go" at the largest quota, "+N€ over" at 9999) fit their line.
func test_the_count_number_fits_the_column() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	var column: CheckoutColumn = monitor.checkout()
	var number: TotalNumber = column.total_number()
	var room: Rect2 = MonitorView.CHECKOUT_RECT
	var paper: Rect2 = MonitorView.PAPER_RECT
	var sizes: PackedStringArray = PackedStringArray()
	for total: int in TOTALS:
		# The number is sized for the digits it shows: a quota under the total.
		var quota: int = mini(total, LARGEST_QUOTA)
		monitor.led.start_count(quota)
		monitor.led.show_subtotal(total, true)
		await _frames(1)
		var expected: int = TotalNumber.fit_size(
			total, tuning.number_sizes, CheckoutColumn.NUMBER_ROOM, tuning.euro_gap
		)
		assert_int(number.font_size()).is_equal(expected)
		sizes.append("%d: %d px" % [total, number.font_size()])
		assert_str(number.text()).is_equal("%d" % total)
		var centre: float = room.position.x + CheckoutColumn.NUMBER_X
		assert_float(number.get_global_rect().get_center().x).is_equal_approx(centre, 1.0)
		var caption: Rect2 = column.caption().get_global_rect()
		# At rest inside the column; a punch may run past it for a moment, into the column's clip
		# at the paper's edge (the mock-up's screen clips it too).
		var ink: Rect2 = number.ink_rect()
		var message: String = "%d: %s" % [total, ink]
		assert_bool(paper.encloses(ink)).override_failure_message(message).is_true()
		assert_bool(room.encloses(ink)).override_failure_message(message).is_true()
		assert_float(ink.position.y).is_greater_equal(caption.position.y + 8.0)
	assert_bool(column.clip_contents).is_true()
	assert_bool(paper.encloses(column.get_global_rect())).is_true()
	prints("#105 number sizes:", ", ".join(sizes))
	# The widest status texts.
	var status: Label = column.status_label()
	for reading: int in [0, 9999]:
		monitor.led.start_count(LARGEST_QUOTA)
		monitor.led.show_subtotal(reading, reading >= LARGEST_QUOTA)
		await _frames(1)
		assert_str(status.text).is_equal(MonitorText.status(reading, LARGEST_QUOTA))
		var width: float = _text_width(status)
		assert_float(width).override_failure_message(status.text).is_less_equal(status.size.x)
		var rect: Rect2 = status.get_global_rect()
		assert_bool(room.encloses(rect)).override_failure_message(str(rect)).is_true()


## Planning's bay (the monitor bay follow-up of #86, mock-up monitor_bay_v1.html), under reduced
## motion (every swap at once): at BAY_RECT in every mode; belt slot 1's item under NEXT with its
## family chip, a pip per belt slot (slot 1's gold, the other filled ones teal light, the empty
## ones teal shade); a new slot 1 replaces it; a held scan shows the held item under SCAN with its
## chip and the light on, then slot 1's item comes back; a hold on the item
## already in the bay scans it there (no new art); an empty slot 1 shows the bare bed and "–"; with
## no belt slots it reads SCANNER with no pips.
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
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(milk))
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
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(bread))
	var first: Color = BayQueue.FIRST_SLOT_COLOR
	assert_array(queue.pip_colours()).is_equal([first, shade, shade, shade, shade])
	# A held scan: the held item under SCAN, its chip, the light on.
	monitor.show_scan(milk, milk.tags)
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_object(monitor.scan_art()).is_same(bay.bed().art())
	assert_bool(bay.shows_scan()).is_true()
	assert_str(queue.text()).is_equal(BayQueue.SCAN_TEXT)
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(milk))
	# The light blinks on for the scan, then stays on in HELD_COLOR while the item is held.
	await get_tree().create_timer(ScannerBay.LIGHT_S + 0.05).timeout
	assert_that(bay.light_colour()).is_equal(ScannerBay.HELD_COLOR)
	monitor.show_scan(coupon, coupon.tags)
	assert_object(bay.bed().shown_definition()).is_same(coupon)
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(coupon))
	# The scan ends: slot 1's item again, under NEXT.
	monitor.end_scan()
	assert_object(bay.bed().shown_definition()).is_same(bread)
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(bread))
	assert_str(queue.text()).is_equal(BayQueue.NEXT_TEXT)
	assert_bool(bay.shows_scan()).is_false()
	await get_tree().create_timer(ScannerBay.LIGHT_S + 0.05).timeout
	assert_that(bay.light_colour()).is_equal(ScannerBay.LIGHT_OFF_COLOR)
	# A hold on the item already in the bay: scanned there, the same art (no drop).
	var art: TextureRect = bay.bed().art()
	monitor.show_scan(bread, bread.tags)
	assert_object(bay.bed().art()).is_same(art)
	assert_bool(bay.shows_scan()).is_true()
	monitor.end_scan()
	assert_object(bay.bed().art()).is_same(art)
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(bread))
	# An empty slot 1: the bare bed and "–", every pip shaded.
	monitor.show_next(null, 5, 0)
	assert_object(bay.bed().art()).is_null()
	assert_object(bay.bed().shown_definition()).is_null()
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.GONE_NAME)
	assert_str(bay.bed().idle_label().text).is_equal("")
	assert_array(queue.pip_colours()).is_equal([shade, shade, shade, shade, shade])
	# A held hand item over an empty slot 1 still shows, and goes again.
	monitor.show_scan(milk, milk.tags)
	assert_object(bay.bed().shown_definition()).is_same(milk)
	monitor.end_scan()
	assert_object(bay.bed().shown_definition()).is_null()
	# No belt slots.
	monitor.show_next(null, 0, 0)
	assert_str(queue.text()).is_equal(BayQueue.IDLE_TEXT)
	assert_array(queue.pip_rects()).is_empty()


## Planning's swaps with motion (mock-up monitor_bay_v1.html): the item in the bay slides out
## over PLAN_OUT_S keeping its chip, the new one drops in over BayBed.FALL_S with a blank chip, its
## own once it has landed; a held item drops in the same way, and the header reads SCAN from its
## drop. Planning's motion runs on the bay's own tweens (real time), never the count-up's.
func test_planning_bay_swaps_slide_out_then_drop_in() -> void:
	var monitor: MonitorView = await _monitor()
	var count_tweens: Array[int] = [0]
	var bay: ScannerBay = monitor.bay()
	bay.make_tween = func() -> Tween:
		count_tweens[0] += 1
		return monitor.create_tween()
	var milk: CardDefinition = _card("milk")
	var bread: CardDefinition = _card("bread")
	var chip: FamilyChip = bay.chip()
	monitor.show_next(milk, 3, 2)
	assert_str(chip.chip_text()).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(chip.chip_text()).is_equal(FamilyChip.item_text(milk))
	monitor.show_next(bread, 3, 2)
	assert_bool(bay.bed().is_leaving()).is_true()
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_str(chip.chip_text()).is_equal(FamilyChip.item_text(milk))
	await get_tree().create_timer(ScannerBay.PLAN_OUT_S + 0.05).timeout
	assert_object(bay.bed().shown_definition()).is_same(bread)
	assert_str(chip.chip_text()).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(chip.chip_text()).is_equal(FamilyChip.item_text(bread))
	monitor.show_scan(milk, milk.tags)
	assert_str(bay.queue().text()).is_equal(BayQueue.NEXT_TEXT)
	await get_tree().create_timer(ScannerBay.PLAN_OUT_S + 0.05).timeout
	assert_object(bay.bed().shown_definition()).is_same(milk)
	assert_str(bay.queue().text()).is_equal(BayQueue.SCAN_TEXT)
	assert_str(chip.chip_text()).is_equal("")
	await get_tree().create_timer(BayBed.FALL_S + 0.1).timeout
	assert_str(chip.chip_text()).is_equal(FamilyChip.item_text(milk))
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
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.GONE_NAME)
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
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(run.row[0].definition))
	assert_str(bay.queue().text()).is_equal(BayQueue.LEFT_TEXT % run.row.size())
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	# Out of the count the bay is planning's again, showing the next belt's slot 1 (or nothing).
	screen._machine.debug_skip()
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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
