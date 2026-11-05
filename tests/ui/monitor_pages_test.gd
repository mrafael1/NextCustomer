extends GdUnitTestSuite
## Planning's item column makes room for its step lines (Checkout Rhythm v3.1, mock-up
## checkout_rhythm_v3_1.html, scenario h; PR #138 monitor): lines that fit the rows' room under the
## base price line show there; too many go on pages of whole lines with a "1/N" marker in the
## header, turning every page_interval_s, held while the pointer is on the monitor, turned (and
## taken) by the wheel, at once under reduced motion, stopped when the item changes or the count
## starts. Never "+N more".
## Tests isolate saves and logs; the pointer and wheel are pushed into the viewport.

const MonitorParts := preload("res://tests/ui/monitor_parts.gd")
const CARDS := "res://data/cards"
## In the order the column shows them: the unused effect (WASTED) after the rows that make the
## payout (#138 review; test_unused_rows_come_after_the_payout_rows).
const LINES: Array[String] = [
	"× Multipack  ×3",
	"+1€ Eggs before it",
	"×2 Coffee",
	"+2€ Bread after it",
	"+3€ Butter beside it",
	"×2 Lemon",
	"Breakfast sticker  WASTED",
]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_monitor_pages_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Lines that fit the rows' room (as many as its ROW_PITCH rows; the description takes the tier
## that leaves the most rows when seven don't fit) show on one page from the rows' top, one line
## each, with no marker and no wait; every part inside the column and apart
## (MonitorParts), no "+N more" anywhere.
func test_lines_that_fit_show_whole_on_one_page() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(LINES.size(), definition.base + 4))
	await _frames(1)
	var room: int = _room(column)
	assert_int(room).is_greater_equal(2)
	monitor.show_scan(definition, definition.tags, _lines(room, definition.base + 4))
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	assert_object(pages).is_not_null()
	assert_int(pages.count()).is_equal(1)
	assert_object(pages.marker()).is_null()
	assert_bool(pages.timer().is_stopped()).is_true()
	assert_array(column.step_texts()).is_equal(PackedStringArray(LINES.slice(0, room)))
	_assert_rows_from(column, room)
	assert_bool(column.part_rects().has("pager")).is_false()
	_assert_parts(column, "%d lines" % room)
	for text: String in column.step_texts():
		assert_bool(text.contains("more")).override_failure_message(text).is_false()


## The rows that make the payout come first, in their scoring order, then the unused effects'
## (#138 review): a WASTED line given before them shows after them, so page 1 explains the payout.
func test_unused_rows_come_after_the_payout_rows() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk")
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = definition.base + 3
	for line: String in [LINES[-1], LINES[1], LINES[0]]:
		lines.lines.append(line)
		lines.fizzles.append(line.ends_with("WASTED"))
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	assert_array(column.step_texts()).is_equal(PackedStringArray([LINES[1], LINES[0], LINES[-1]]))


## The rows of one page print at one size, the smallest any of them needs (PR #138 round 2
## review): a long row that drops to the smaller size takes its short neighbours with it.
func test_a_pages_rows_share_one_text_size() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk")
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = definition.base + 3
	for line: String in ["+1€ Eggs", "+2€ Already Breakfast and Dairy and Bakery in the cart"]:
		lines.lines.append(line)
		lines.fizzles.append(false)
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	var sizes: Array[int] = []
	for row: Control in column.step_rows():
		var text: Label = row.get_node_or_null("Text") as Label
		if text != null:
			sizes.append(text.get_theme_font_size("font_size"))
	assert_int(sizes.size()).is_equal(2)
	assert_int(sizes[0]).is_equal(sizes[1])
	assert_int(sizes[0]).is_equal(MonitorStepRow.ROW_SIZES[-1])


## A coupon prints no base price (#138 review): no base price line, its rows under its description;
## one that gave something keeps the coupon's scissors window even with an unused part (its fizzle
## row says it), and only one that gave nothing is wasted.
func test_a_coupon_has_no_base_line_and_wastes_only_when_it_gave_nothing() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("two_for_one")
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = 0
	lines.lines = PackedStringArray(["×2 to Banana  +10€", "1 charge unused  WASTED"])
	lines.fizzles = [false, true]
	lines.gives = 1
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	assert_object(column.base_line()).is_null()
	assert_bool(column.part_rects().has("base")).is_false()
	assert_int(column.payout_view().pay_state()).is_equal(PriceWindow.State.COUPON)
	# PR #138 round 7: what its "gives" rows added shows in its zone, "+10€" in the coupon's ink
	# (the scissors window only while it added nothing).
	var payout: MonitorPayout = column.payout_view()
	assert_bool(payout.window().visible).is_true()
	lines.given = 10
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	assert_int(payout.pay_state()).is_equal(PriceWindow.State.COUPON)
	assert_int(payout.given_amount()).is_equal(10)
	assert_bool(payout.window().visible).is_false()
	assert_str(payout.equals().text).is_equal(MonitorPayout.GIVEN_SIGN)
	assert_str(payout.digit_words().text).is_equal(MonitorText.euros(10))
	assert_that(payout.digit_words().color).is_equal(MonitorPayout.GIVEN_INK)
	assert_array(MonitorParts.problems(column)).is_empty()
	lines.given = 0
	lines.lines = PackedStringArray(["1 charge unused  WASTED"])
	lines.fizzles = [true]
	lines.gives = 0
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	assert_int(column.payout_view().pay_state()).is_equal(PriceWindow.State.WASTED)
	var milk: CardDefinition = _card("milk")
	monitor.show_scan(milk, milk.tags, _lines(1, milk.base))
	await _frames(1)
	assert_object(column.base_line()).is_not_null()


## PR #138 round 7 review: a giver's "gives" rows go one per target only while the whole scan fits
## on one page; past it they give way to the one collapsed row ("to N items  +N€"), so the first
## page's rows add up to the coupon's "+N€".
func test_gives_rows_collapse_when_the_scan_would_page() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("multipack")
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = 0
	lines.gives = 2
	lines.given = 30
	lines.collapsed = "to 2 items  +30€"
	lines.lines = PackedStringArray(["to Milk  ×3 · 7€ => 21€", "to Milk  ×3 · 8€ => 24€"])
	lines.fizzles = [false, false]
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	assert_int(column.pages.count()).is_equal(1)
	assert_array(Array(column.step_texts())).contains([lines.lines[0], lines.lines[1]])
	assert_array(Array(column.step_texts())).not_contains([lines.collapsed])
	var long: ScanController.ItemLines = ScanController.ItemLines.new()
	long.payout = 0
	long.gives = 2
	long.given = 30
	long.collapsed = lines.collapsed
	long.lines = lines.lines.duplicate()
	long.fizzles = [false, false]
	for index: int in range(_room(column)):
		long.lines.append("1 charge unused  WASTED")
		long.fizzles.append(true)
	monitor.show_scan(definition, definition.tags, long)
	await _frames(1)
	var texts: Array = Array(column.step_texts())
	assert_array(texts).contains([lines.collapsed])
	assert_array(texts).not_contains([lines.lines[0], lines.lines[1]])
	assert_str(String(texts[0])).is_equal(lines.collapsed)
	assert_int(column.payout_view().given_amount()).is_equal(30)
	assert_array(MonitorParts.problems(column)).is_empty()


## Seven lines: whole lines on pages of the rows' room with "1/N" in the header, page 1 first;
## every line's text kept; each page's rows inside the rows' area; the next page after
## page_interval_s (2.5 s in data/), wrapping around; the same item shown again keeps its page.
func test_too_many_lines_go_on_pages_that_turn_and_wrap() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var column: MonitorItemColumn = monitor.item_column()
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	assert_float(tuning.page_interval_s).is_equal(2.5)
	assert_float(tuning.page_fade_s).is_equal(0.15)
	# A short wait for the test (the column's own tuning; the game's is checked above).
	var quick: CountTotalTuning = tuning.duplicate() as CountTotalTuning
	quick.page_interval_s = 0.25
	column._tuning = quick
	var definition: CardDefinition = _card("milk")
	var lines: ScanController.ItemLines = _lines(7, definition.base)
	monitor.show_scan(definition, definition.tags, lines)
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	var room: int = _room(column)
	var count: int = ceili(float(LINES.size()) / room)
	assert_int(pages.count()).is_equal(count)
	assert_int(pages.page()).is_equal(0)
	assert_str(pages.marker().text).is_equal("1/%d" % count)
	assert_array(column.step_texts()).is_equal(PackedStringArray(LINES))
	assert_int(column.step_rows().size()).is_equal(room)
	assert_float(pages.timer().wait_time).is_equal(0.25)
	assert_bool(pages.timer().is_stopped()).is_false()
	_assert_page(column, LINES.slice(0, room), "page 1")
	# The refresh's same item keeps its page and its wait.
	monitor.show_scan(definition, definition.tags, lines)
	assert_object(column.pages).is_same(pages)
	await _until_turned(pages, 1)
	var turned_at: int = Time.get_ticks_msec()
	assert_int(pages.page()).is_equal(1)
	# The turn starts the next whole wait.
	assert_float(pages.timer().wait_time).is_equal(0.25)
	assert_bool(pages.timer().is_stopped()).is_false()
	assert_str(pages.marker().text).is_equal("2/%d" % count)
	_assert_page(column, LINES.slice(room, 2 * room), "page 2")
	await _until_turned(pages, 0)
	assert_int(pages.page()).is_equal(0)
	# Not at once: the next turn waited on the timer (no upper bound: a slow frame only delays it).
	assert_int(Time.get_ticks_msec() - turned_at).is_greater_equal(100)
	_assert_page(column, LINES.slice(0, room), "page 1 again")


## The pointer on the monitor holds the page (no wait running); leaving starts the wait again.
## The wheel over it turns the page (down: the next, up: the previous, one page a gesture) and
## is taken: the control under the monitor never gets it. With no pages the monitor takes no
## pointer, so the wheel goes on to what is under it.
func test_hover_holds_and_the_wheel_turns_and_is_taken() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var under: Control = monitor.get_parent() as Control
	var reached: Array[InputEvent] = []
	under.gui_input.connect(func(event: InputEvent) -> void: reached.append(event))
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _frames(1)
	var pages: MonitorStepPages = monitor.item_column().pages
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	var on_screen: Vector2 = monitor.item_column().get_global_rect().get_center()
	_move(on_screen)
	await _frames(2)
	assert_bool(pages.is_held()).is_true()
	assert_bool(pages.timer().is_stopped()).is_true()
	_wheel(on_screen, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(1)
	assert_int(pages.page()).is_equal(1)
	# The same gesture's next notch turns nothing; after a still moment the next one does.
	_wheel(on_screen, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(1)
	assert_int(pages.page()).is_equal(1)
	await _seconds(float(MonitorView.WHEEL_QUIET_MS + 60) / 1000.0)
	_wheel(on_screen, MOUSE_BUTTON_WHEEL_UP)
	await _frames(1)
	assert_int(pages.page()).is_equal(0)
	assert_str(pages.marker().text).starts_with("1/")
	assert_int(_wheels(reached)).is_equal(0)
	assert_bool(pages.timer().is_stopped()).is_true()
	# Off the monitor: the wait starts again from the start.
	_move(Vector2(4, 4))
	await _frames(2)
	assert_bool(pages.is_held()).is_false()
	assert_bool(pages.timer().is_stopped()).is_false()
	assert_float(pages.timer().time_left).is_greater(2.0)
	# Lines that fit: no pages, no pointer taken, the wheel reaches what is under the monitor.
	monitor.show_scan(definition, definition.tags, _lines(1, definition.base))
	await _frames(1)
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_wheel(on_screen, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(1)
	assert_int(_wheels(reached)).is_greater(0)


## A pointer already resting on the screen (no motion since) when the item starts paging holds
## the new pages at once: no wait runs until it leaves.
func test_a_resting_pointer_holds_new_pages() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(1, definition.base))
	await _frames(1)
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_move(monitor.item_column().get_global_rect().get_center())
	await _frames(2)
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _frames(1)
	var pages: MonitorStepPages = monitor.item_column().pages
	assert_int(pages.count()).is_greater_equal(2)
	assert_bool(pages.is_held()).is_true()
	assert_bool(pages.timer().is_stopped()).is_true()
	_move(Vector2(4, 4))
	await _frames(2)
	assert_bool(pages.is_held()).is_false()
	assert_bool(pages.timer().is_stopped()).is_false()


## A turn crossfades its pages over page_fade_s (both shown meanwhile), the old page going; under
## reduced motion it swaps at once.
func test_a_turn_fades_or_swaps_at_once_under_reduced_motion() -> void:
	var monitor: MonitorView = await _monitor()
	var reduced: Array[bool] = [false]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _seconds(0.5)
	var pages: MonitorStepPages = monitor.item_column().pages
	var first: Control = pages.get_node("Page0") as Control
	var second: Control = pages.get_node("Page1") as Control
	pages.turn(1)
	assert_bool(first.visible and second.visible).is_true()
	assert_float(second.modulate.a).is_less(1.0)
	await _frames(1)
	assert_bool(second.visible).is_true()
	await _seconds(0.3)
	assert_bool(first.visible).is_false()
	assert_float(second.modulate.a).is_equal(1.0)
	reduced[0] = true
	pages.turn(-1)
	assert_bool(first.visible).is_true()
	assert_bool(second.visible).is_false()
	assert_float(first.modulate.a).is_equal(1.0)
	var room: int = _room(monitor.item_column())
	_assert_page(monitor.item_column(), LINES.slice(0, room), "after the instant swap")


## Another item (lines that fit: one page, no wait) or the count's start stops the pages: their
## wait ends and they go, and the monitor takes no pointer any more.
func test_the_pages_stop_when_the_item_changes_or_the_count_starts() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	var timer: Timer = pages.timer()
	monitor.show_scan(_card("bread"), _card("bread").tags, _lines(1, _card("bread").base))
	assert_bool(timer.is_stopped()).is_true()
	assert_object(column.pages).is_not_same(pages)
	assert_int(column.pages.count()).is_equal(1)
	assert_bool(column.pages.timer().is_stopped()).is_true()
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await _frames(1)
	assert_bool(is_instance_valid(pages)).is_false()
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _frames(1)
	pages = column.pages
	timer = pages.timer()
	assert_bool(timer.is_stopped()).is_false()
	monitor.led.start_count(40)
	assert_bool(timer.is_stopped()).is_true()
	assert_object(column.pages).is_null()
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await _frames(1)
	assert_bool(is_instance_valid(pages)).is_false()


## How many one-line rows the rows' area of the item shown holds.
static func _room(column: MonitorItemColumn) -> int:
	return floori(column.part_rects()["rows"].size.y / MonitorItemColumn.ROW_PITCH)


## The rows shown start at the rows' area's top, one line each (ROW_PITCH), `count` of them, one
## under another.
func _assert_rows_from(column: MonitorItemColumn, count: int) -> void:
	var rows: Array[Control] = column.step_rows()
	assert_int(rows.size()).is_equal(count)
	var area: Rect2 = column.part_rects()["rows"]
	assert_float(rows[0].get_global_rect().position.y).is_equal_approx(area.position.y, 0.5)
	for index: int in range(rows.size()):
		assert_float(rows[index].size.y).is_equal(MonitorItemColumn.ROW_PITCH)
		if index > 0:
			assert_float(rows[index].get_global_rect().position.y).is_greater_equal(
				rows[index - 1].get_global_rect().end.y
			)


## The page shown holds `texts`, its rows visible inside the rows' area, ROW_PITCH tall; the marker
## at the header's right end, inside its band (PR #138 round 2).
func _assert_page(column: MonitorItemColumn, texts: Array, message: String) -> void:
	var rows: Array[Control] = column.step_rows()
	var shown: Array[String] = []
	for row: Control in rows:
		shown.append(String(row.get_meta(&"line", "")))
		assert_bool(row.is_visible_in_tree()).override_failure_message(message).is_true()
	assert_array(shown).override_failure_message(message).is_equal(texts)
	var parts: Dictionary[String, Rect2] = column.part_rects()
	var area: Rect2 = parts["rows"]
	var marker: Rect2 = column.pages.marker().get_global_rect()
	assert_bool(column.pages.marker().is_visible_in_tree()).is_true()
	var header: Rect2 = parts["header"]
	assert_bool(header.grow(0.5).encloses(marker)).override_failure_message(str(marker)).is_true()
	var content_end: float = (
		column.get_global_rect().position.x
		+ MonitorItemColumn.INSET
		+ MonitorItemColumn.CONTENT_WIDTH
	)
	assert_float(marker.end.x).is_equal_approx(content_end, 0.5)
	for row: Control in rows:
		var rect: Rect2 = row.get_global_rect()
		assert_bool(area.grow(0.5).encloses(rect)).override_failure_message(message).is_true()
		assert_float(rect.size.y).is_equal(MonitorItemColumn.ROW_PITCH)
	_assert_parts(column, message)


## The column's layout checks (MonitorParts): every part inside it, apart, in order, nothing cut.
func _assert_parts(column: MonitorItemColumn, message: String) -> void:
	var problems: PackedStringArray = MonitorParts.problems(column)
	assert_array(problems).override_failure_message("%s: %s" % [message, problems]).is_empty()


static func _wheels(events: Array[InputEvent]) -> int:
	var count: int = 0
	for event: InputEvent in events:
		if event is InputEventMouseButton:
			count += 1
	return count


## The first `count` of LINES as a scan's lines at `payout`.
static func _lines(count: int, payout: int) -> ScanController.ItemLines:
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = payout
	for index: int in range(count):
		lines.lines.append(LINES[index])
		lines.fizzles.append(LINES[index].ends_with("WASTED"))
	return lines


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


## A monitor alone at its stage place, over a control as big as the screen (what is under it).
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	holder.size = get_tree().root.get_visible_rect().size
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	# The pointer starts off the monitor (an earlier test may have left it on).
	_move(Vector2(4, 4))
	await _frames(1)
	return monitor


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_tree().root.push_input(motion, true)


func _wheel(at: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.factor = 1.0
		event.position = at
		event.global_position = at
		get_tree().root.push_input(event, true)


## Waits (at most three seconds) for `pages` to show `page`.
func _until_turned(pages: MonitorStepPages, page: int) -> void:
	var started: int = Time.get_ticks_msec()
	while pages.page() != page and Time.get_ticks_msec() - started < 3000:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
