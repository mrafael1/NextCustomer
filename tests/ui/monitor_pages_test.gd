extends GdUnitTestSuite
## Planning's item column makes room for its step lines (Checkout Rhythm v3.1, mock-up
## checkout_rhythm_v3_1.html, scenario h): lines that fit under the full effect stay there; when
## they don't, the effect takes one line and the rule and lines move up, all of them shown when
## they then fit; still too many go on pages of whole lines with a "1/2" marker, turning every
## page_interval_s, held while the pointer is on the monitor, turned (and taken) by the wheel, at
## once under reduced motion, stopped when the item changes or the count starts. Never "+N more".
## Tests isolate saves and logs; the pointer and wheel are pushed into the viewport.

const CARDS := "res://data/cards"
const LINES: Array[String] = [
	"× Multipack  ×3",
	"+€1 Eggs before it",
	"Breakfast sticker  WASTED",
	"×2 Coffee",
	"+€2 Bread after it",
	"+€3 Butter beside it",
	"×2 Lemon",
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


## Two lines stay in the full layout (the effect on its tiers, the rule at RULE_TOP); four lines
## take the compact one, all shown on one page with no marker: one line each from
## COUNT_STEPS_TOP, the effect on one line at the smallest tier, the price in the name row, every
## part inside the column and none over another, no "+N more" anywhere.
func test_lines_that_fit_show_whole_and_four_take_the_compact_layout() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk")
	monitor.show_scan(definition, definition.tags, _lines(2, definition.base + 4))
	await _frames(1)
	assert_object(column.pages).is_null()
	assert_array(column.step_texts()).is_equal(PackedStringArray(LINES.slice(0, 2)))
	_assert_rows_from(column, MonitorItemColumn.STEPS_TOP, 2)
	assert_float(column.effect().position.y).is_equal(MonitorItemColumn.EFFECT_TOP)
	_assert_parts(column, "2 lines")
	monitor.show_scan(definition, definition.tags, _lines(4, definition.base + 4))
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	assert_object(pages).is_not_null()
	assert_int(pages.count()).is_equal(1)
	assert_object(pages.marker()).is_null()
	assert_bool(pages.timer().is_stopped()).is_true()
	assert_array(column.step_texts()).is_equal(PackedStringArray(LINES.slice(0, 4)))
	assert_int(column.step_rows().size()).is_equal(4)
	_assert_rows_from(column, MonitorItemColumn.COUNT_STEPS_TOP, 4)
	var effect: GlyphLabel = column.effect()
	assert_int(effect.line_count()).is_equal(1)
	assert_int(effect.font_size()).is_equal(MonitorItemColumn.EFFECT_TIERS[-1].x)
	assert_float(effect.position.y).is_equal(MonitorItemColumn.COMPACT_EFFECT_TOP)
	# The price (and the struck base) in the name row, above the effect's line.
	var parts: Dictionary[String, Rect2] = column.part_rects()
	assert_float(parts["price"].get_center().y - column.get_global_rect().position.y).is_less(26.0)
	assert_bool(parts.has("struck")).is_true()
	assert_float(parts["struck"].end.y).is_less_equal(parts["effect"].position.y)
	assert_bool(parts.has("pager")).is_false()
	_assert_parts(column, "4 lines")
	for text: String in column.step_texts():
		assert_bool(text.contains("more")).override_failure_message(text).is_false()


## Seven lines: whole lines on two pages (4, then 3) with "1/2" bottom right under them, page 1
## first; every line's text kept; each page's rows inside the step area above the marker; the next
## page after page_interval_s (2.5 s in data/), wrapping around; the same item shown again keeps
## its page.
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
	assert_int(pages.count()).is_equal(2)
	assert_int(pages.page()).is_equal(0)
	assert_str(pages.marker().text).is_equal("1/2")
	assert_array(column.step_texts()).is_equal(PackedStringArray(LINES))
	assert_int(column.step_rows().size()).is_equal(4)
	assert_float(pages.timer().wait_time).is_equal(0.25)
	assert_bool(pages.timer().is_stopped()).is_false()
	_assert_page(column, LINES.slice(0, 4), "page 1")
	# The refresh's same item keeps its page and its wait.
	monitor.show_scan(definition, definition.tags, lines)
	assert_object(column.pages).is_same(pages)
	await _until_turned(pages, 1)
	var turned_at: int = Time.get_ticks_msec()
	assert_int(pages.page()).is_equal(1)
	# The turn starts the next whole wait.
	assert_float(pages.timer().wait_time).is_equal(0.25)
	assert_bool(pages.timer().is_stopped()).is_false()
	assert_str(pages.marker().text).is_equal("2/2")
	_assert_page(column, LINES.slice(4), "page 2")
	await _until_turned(pages, 0)
	assert_int(pages.page()).is_equal(0)
	# Not at once: the next turn waited on the timer (no upper bound: a slow frame only delays it).
	assert_int(Time.get_ticks_msec() - turned_at).is_greater_equal(100)
	_assert_page(column, LINES.slice(0, 4), "page 1 again")


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
	assert_str(pages.marker().text).is_equal("1/2")
	assert_int(_wheels(reached)).is_equal(0)
	assert_bool(pages.timer().is_stopped()).is_true()
	# Off the monitor: the wait starts again from the start.
	_move(Vector2(4, 4))
	await _frames(2)
	assert_bool(pages.is_held()).is_false()
	assert_bool(pages.timer().is_stopped()).is_false()
	assert_float(pages.timer().time_left).is_greater(2.0)
	# Lines that fit: no pages, no pointer taken, the wheel reaches what is under the monitor.
	monitor.show_scan(definition, definition.tags, _lines(2, definition.base))
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
	monitor.show_scan(definition, definition.tags, _lines(2, definition.base))
	await _frames(1)
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_move(monitor.item_column().get_global_rect().get_center())
	await _frames(2)
	monitor.show_scan(definition, definition.tags, _lines(7, definition.base))
	await _frames(1)
	var pages: MonitorStepPages = monitor.item_column().pages
	assert_int(pages.count()).is_equal(2)
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
	pages.turn(1)
	assert_bool(first.visible).is_true()
	assert_bool(second.visible).is_false()
	assert_float(first.modulate.a).is_equal(1.0)
	_assert_page(monitor.item_column(), LINES.slice(0, 4), "after the instant swap")


## Another item (lines that fit) or the count's start stops the pages: their wait ends and they
## go, and the monitor takes no pointer any more.
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
	assert_object(column.pages).is_null()
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


## The rows shown start at `top` (the column's), one line each, `count` of them, one under another.
func _assert_rows_from(column: MonitorItemColumn, top: float, count: int) -> void:
	var rows: Array[Control] = column.step_rows()
	assert_int(rows.size()).is_equal(count)
	var origin: float = column.get_global_rect().position.y
	assert_float(rows[0].get_global_rect().position.y - origin).is_equal(top)
	for index: int in range(1, rows.size()):
		assert_float(rows[index].get_global_rect().position.y).is_greater_equal(
			rows[index - 1].get_global_rect().end.y
		)


## The page shown holds `texts`, its rows visible, inside the step area above the marker, apart.
func _assert_page(column: MonitorItemColumn, texts: Array, message: String) -> void:
	var rows: Array[Control] = column.step_rows()
	var shown: Array[String] = []
	for row: Control in rows:
		shown.append(String(row.get_meta(&"line", "")))
		assert_bool(row.is_visible_in_tree()).override_failure_message(message).is_true()
	assert_array(shown).override_failure_message(message).is_equal(texts)
	var area: Rect2 = column.get_global_rect()
	area.position.y += MonitorItemColumn.COUNT_STEPS_TOP
	area.size.y -= MonitorItemColumn.COUNT_STEPS_TOP
	var marker: Rect2 = column.pages.marker().get_global_rect()
	assert_bool(column.pages.marker().is_visible_in_tree()).is_true()
	assert_float(marker.size.y).is_less_equal(MonitorStepPages.MARKER_HEIGHT)
	assert_bool(area.grow(0.5).encloses(marker)).override_failure_message(str(marker)).is_true()
	assert_float(marker.end.x).is_equal_approx(area.end.x - 2.0, 0.5)
	for row: Control in rows:
		var rect: Rect2 = row.get_global_rect()
		assert_bool(area.grow(0.5).encloses(rect)).override_failure_message(message).is_true()
		assert_float(rect.end.y).override_failure_message(message).is_less_equal(marker.position.y)
		assert_float(rect.size.y).is_equal(roundf(MonitorItemColumn.STEP_SIZE * 1.3))
	_assert_parts(column, message)


## Every part of the column (its name, glyphs, price, effect, rows and marker) inside it, none
## over another, and every visible label inside it.
func _assert_parts(column: MonitorItemColumn, message: String) -> void:
	var room: Rect2 = column.get_global_rect().grow(0.5)
	var parts: Dictionary[String, Rect2] = column.part_rects()
	var names: Array[String] = parts.keys()
	for index: int in range(names.size()):
		var rect: Rect2 = parts[names[index]]
		(
			assert_bool(room.encloses(rect))
			. override_failure_message("%s: %s %s" % [message, names[index], rect])
			. is_true()
		)
		for other: int in range(index + 1, names.size()):
			(
				assert_bool(rect.intersects(parts[names[other]]))
				. override_failure_message("%s: %s over %s" % [message, names[index], names[other]])
				. is_false()
			)
	var labels: Array[Label] = []
	MonitorView._collect_labels(column, labels)
	for label: Label in labels:
		(
			assert_bool(room.encloses(label.get_global_rect()))
			. override_failure_message(
				"%s: '%s' %s" % [message, label.text, label.get_global_rect()]
			)
			. is_true()
		)


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


## Waits (at most a second) for `pages` to show `page`.
func _until_turned(pages: MonitorStepPages, page: int) -> void:
	var started: int = Time.get_ticks_msec()
	while pages.page() != page and Time.get_ticks_msec() - started < 1000:
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
