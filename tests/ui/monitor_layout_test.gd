extends GdUnitTestSuite
## The single monitor screen's geometry (#105 piece 2, mock-up readability_v3.html, monitor b),
## read back from the drawn controls on a monitor at its stage place. The checkout column for
## totals of one to four digits, in planning, in the count (the number at rest and at a ×'s full
## punch, the gain box) and at a met end: every part inside the column and the paper, the number
## at rest clear of the divider (punched it runs into the column's clip at the paper's edge for a
## moment, as the mock-up's), the TOTAL caption 4 px clear of the digits at the full punch, and
## the caption, the number, the ladder, the SPEND line, the status line (or the gain box), the
## stamp and the tab apart. The item column's step amounts share one
## right-hand edge, and its glyphs sit after the name and inside the column. The scans of every
## card are in monitor_view_test; the count's timing and sync in monitor_count_sync_test.

const CARDS := "res://data/cards"
## (quota, total) pairs: one to four digits, under and over the quota.
const CASES: Array[Vector2i] = [
	Vector2i(26, 8),
	Vector2i(26, 21),
	Vector2i(73, 80),
	Vector2i(73, 143),
	Vector2i(300, 999),
	Vector2i(1500, 1234),
	Vector2i(9000, 9999),
]
## The digits' clearance under the TOTAL caption at the full punch (the mock-up's 4 px).
const CAPTION_CLEAR := 4.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_monitor_layout_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## For every case: planning's PLAN, the count short of the quota (the number at rest, then held at
## the ×'s punch, then the gain box), and the met end (the stamp and the tab).
func test_the_checkout_column_parts_stand_apart_for_every_total() -> void:
	var monitor: MonitorView = await _monitor()
	var count_up: CountUp = _follow(monitor)
	var tuning: CountTotalTuning = count_up.total_tuning()
	var column: CheckoutColumn = monitor.checkout()
	var failures: Array[String] = []
	for case: Vector2i in CASES:
		var quota: int = case.x
		var total: int = case.y
		var where: String = "quota %d, total %d" % [quota, total]
		# Planning.
		monitor.show_plan(total, quota)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " plan", false))
		# The count, short of the quota (the status line shows): at rest, then at the full punch.
		monitor.led.start_count(quota)
		var shown: int = mini(total, quota - 1)
		monitor.led.show_subtotal(shown, false)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " count", false))
		var number: TotalNumber = column.total_number()
		number.scale = Vector2.ONE * tuning.punch_mul
		failures.append_array(_column_failures(column, where + " punched", true))
		number.scale = Vector2.ONE
		# A × lands: its gain box takes the status line's place.
		var times: CountUpBeat = CountUpBeat.new()
		times.land = CountUpBeat.Land.MUL
		times.factor_text = "×3"
		times.gain = maxi(1, total - shown)
		times.lamp = 0
		column.land(times)
		# The punch eases out over punch_s; the gain box stays for gain_box_s.
		await get_tree().create_timer(tuning.punch_s + 0.05).timeout
		failures.append_array(_column_failures(column, where + " gain box", false))
		# The met end: the stamp and the tab.
		monitor.led.show_subtotal(maxi(total, quota), true)
		column.finish(true)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " met", false))
		monitor.led.clear()
		await _frames(1)
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 16))).is_empty()


## The number's size steps down only as its digits need it: every total of one or two digits at
## the mock-up's 38 px (its 6€, 8€, 21€ and 28€), one size per digit count, and the group as drawn
## at rest always fits the room (a punch may run into the column's clip).
func test_the_number_keeps_the_mock_ups_size_for_its_totals() -> void:
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	var sizes: PackedInt32Array = tuning.number_sizes
	var room: float = CheckoutColumn.NUMBER_ROOM
	var gap: float = tuning.euro_gap
	for amount: int in [0, 6, 8, 11, 21, 28, 39, 80, 86, 99]:
		(
			assert_int(TotalNumber.fit_size(amount, sizes, room, gap))
			. override_failure_message(str(amount))
			. is_equal(sizes[0])
		)
	for pair: Vector2i in [Vector2i(100, 999), Vector2i(111, 888), Vector2i(1000, 9999)]:
		assert_int(TotalNumber.fit_size(pair.x, sizes, room, gap)).is_equal(
			TotalNumber.fit_size(pair.y, sizes, room, gap)
		)
	var last: int = sizes[0]
	for amount: int in [0, 9, 99, 143, 999, 1234, 9999]:
		var size_px: int = TotalNumber.fit_size(amount, sizes, room, gap)
		assert_int(size_px).override_failure_message(str(amount)).is_less_equal(last)
		last = size_px
		var group: float = TotalNumber.group_width("%d" % amount, size_px, gap)
		var drawn: float = group + 2.0 * TotalNumber.OUTLINE
		assert_float(drawn).override_failure_message(str(amount)).is_less_equal(room)


## In a count that ends past 99€ (or peaks past it before a fall) the number follows the value
## shown: its 2-digit values at the mock-up's 38 px, a 3-digit one at its own size inside the
## column, and back to 38 px when it falls under 100. A rolling digit's old glyph is centred in the
## new glyph's cell (no gap, no shift), and the roll's first frame is already moving.
func test_the_number_follows_the_digits_it_shows() -> void:
	var monitor: MonitorView = await _monitor()
	var count_up: CountUp = _follow(monitor)
	var tuning: CountTotalTuning = count_up.total_tuning()
	var column: CheckoutColumn = monitor.checkout()
	var number: TotalNumber = column.total_number()
	var room: Rect2 = MonitorView.CHECKOUT_RECT
	monitor.led.start_count(90)
	for reading: int in [16, 86, 103, 95, 143]:
		monitor.led.show_subtotal(reading, false)
		await _frames(1)
		var expected: int = TotalNumber.fit_size(
			reading, tuning.number_sizes, CheckoutColumn.NUMBER_ROOM, tuning.euro_gap
		)
		assert_int(number.font_size()).override_failure_message(str(reading)).is_equal(expected)
		if reading < 100:
			assert_int(number.font_size()).is_equal(tuning.number_sizes[0])
		var drawn: Rect2 = number.drawn_rect()
		(
			assert_bool(room.grow(0.5).encloses(drawn))
			. override_failure_message("%d: %s" % [reading, drawn])
			. is_true()
		)
	# A roll from 11 to 18: the old "1" centred in the "8"'s cell.
	monitor.led.show_subtotal(11, false)
	await get_tree().create_timer(tuning.digit_roll_s + 0.05).timeout
	monitor.led.show_subtotal(18, false)
	var cell: Control = number.cells()[1]
	var glyph: Label = cell.get_node("Glyph") as Label
	var old: Label = cell.get_node_or_null("Old") as Label
	assert_object(old).is_not_null()
	var old_middle: float = old.position.x + old.size.x / 2.0
	assert_float(old_middle).is_equal_approx(glyph.position.x + glyph.size.x / 2.0, 1.0)
	await get_tree().create_timer(tuning.digit_roll_s + 0.05).timeout
	assert_str(number.text()).is_equal("18")
	await _frames(2)


## The item column's step amounts share one right-hand edge (right-aligned in their column), and
## the name's glyphs sit after its text, inside the column; nothing overlaps.
func test_the_step_amounts_share_one_edge_and_the_glyphs_follow_the_name() -> void:
	var monitor: MonitorView = await _monitor()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = 10
	# Two lines: a third folds into "+N more" in the step area's 56 px.
	lines.lines = PackedStringArray(["+€1 Eggs before it", "× Multipack  ×3"])
	var fizzles: Array[bool] = [false, false]
	lines.fizzles = fizzles
	monitor.show_next(milk, 6, 3, milk.tags, lines)
	await _frames(2)
	var column: MonitorItemColumn = monitor.item_column()
	var edges: Array[float] = []
	for row: Control in column.step_rows():
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount == null:
			continue
		assert_int(amount.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_RIGHT)
		edges.append(amount.get_global_rect().end.x)
	assert_int(edges.size()).is_greater_equal(2)
	for edge: float in edges:
		assert_float(edge).is_equal_approx(edges[0], 1.0)
	var item_rect: Rect2 = MonitorView.ITEM_RECT
	assert_float(edges[0]).is_less_equal(item_rect.end.x)
	var rects: Dictionary[String, Rect2] = column.part_rects()
	var name_rect: Rect2 = rects["name"]
	var glyphs: Array[FamilyGlyph] = column.glyphs()
	assert_bool(glyphs.is_empty()).is_false()
	for glyph: FamilyGlyph in glyphs:
		var glyph_rect: Rect2 = glyph.get_global_rect()
		assert_float(glyph_rect.position.x).is_greater_equal(name_rect.end.x)
		assert_bool(item_rect.grow(0.5).encloses(glyph_rect)).is_true()
	var names: Array[String] = rects.keys()
	for index: int in range(names.size()):
		(
			assert_bool(item_rect.grow(0.5).encloses(rects[names[index]]))
			. override_failure_message(names[index])
			. is_true()
		)
		for other: int in range(index + 1, names.size()):
			(
				assert_bool(rects[names[index]].intersects(rects[names[other]]))
				. override_failure_message("%s over %s" % [names[index], names[other]])
				. is_false()
			)


# --- Helpers ---------------------------------------------------------------------------------


## The checkout column's parts now, as failures (see the suite comment). `punched`: the number is
## held at the full punch, so only its clearances are read (the ladder may take its drop).
static func _column_failures(column: CheckoutColumn, where: String, punched: bool) -> Array[String]:
	var failures: Array[String] = []
	var room: Rect2 = MonitorView.CHECKOUT_RECT
	var paper: Rect2 = MonitorView.PAPER_RECT
	var number: TotalNumber = column.total_number()
	var drawn: Rect2 = number.drawn_rect()
	var ink: Rect2 = number.ink_rect()
	# At rest it stays clear of the divider and inside the paper; punched it may cover the divider
	# and run into the column's clip at the paper's edge for a moment (as in the mock-up).
	var left: float = room.position.x + CheckoutColumn.DIVIDER_RECT.end.x
	if not column.clip_contents or not paper.encloses(column.get_global_rect()):
		failures.append("%s: the column does not clip at the paper" % where)
	if not punched and (drawn.position.x < left - 0.5 or drawn.end.x > paper.end.x - 0.5):
		failures.append("%s: number %s left of %s or past the paper" % [where, drawn, left])
	var caption: Rect2 = column.caption().get_global_rect()
	if ink.position.y < caption.end.y + CAPTION_CLEAR - 0.5:
		failures.append(
			(
				"%s: digits' ink %s under %s px of the caption %s"
				% [where, ink, CAPTION_CLEAR, caption]
			)
		)
	var parts: Dictionary[String, Rect2] = {
		"caption": caption,
		"number": ink if punched else drawn,
		"ladder": column.ladder().get_global_rect(),
		"spend": column.spend_line().get_global_rect(),
	}
	if column.status_label().visible:
		parts["status"] = _text_rect(column.status_label())
	if column.gain_box().visible:
		parts["gain"] = MonitorKit.drawn_rect(column.gain_box(), MonitorKit.BOX_BORDER)
	if column.stamp().visible:
		parts["stamp"] = MonitorKit.drawn_rect(column.stamp())
	if column.tab().visible:
		parts["tab"] = MonitorKit.drawn_rect(column.tab(), MonitorKit.BOX_BORDER)
	var names: Array[String] = parts.keys()
	for index: int in range(names.size()):
		var rect: Rect2 = parts[names[index]]
		var clipped: bool = punched and names[index] == "number"
		if not clipped and (not room.grow(0.5).encloses(rect) or not paper.encloses(rect)):
			failures.append("%s: %s %s outside the column %s" % [where, names[index], rect, room])
		for other: int in range(index + 1, names.size()):
			# A tilted stamp's bounding box may graze its neighbour by a corner: a pixel's grace.
			if rect.grow(-1.0).intersects(parts[names[other]]):
				failures.append(
					(
						"%s: %s %s over %s %s"
						% [where, names[index], rect, names[other], parts[names[other]]]
					)
				)
	return failures


## A centred label's text as drawn (global): its text's width about its middle, its full height.
static func _text_rect(label: Label) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font("font")
	var size_px: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	width *= label.scale.x
	return Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, rect.size.y)


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## A count-up (not played, in the tree for its tweens) the monitor follows.
func _follow(monitor: MonitorView) -> CountUp:
	var count_up: CountUp = auto_free(CountUp.new())
	get_tree().root.add_child(count_up)
	monitor.follow(count_up)
	return count_up


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
