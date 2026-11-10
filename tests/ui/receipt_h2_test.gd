extends GdUnitTestSuite
## The shift receipt's H2 header and its rows at checkout (v1.18, main scene v2: mock-up
## docs/art/mockups/main_scene_v2.html, H2), on the real shift screen at 1280x720 and 1920x1080 and
## alone: BEAT TODAY'S TARGET over the target in tomato dark, the hero (PROJECTED, then TOTAL) at
## least 1.5x the target, every part inside the paper and apart (BEATEN! included; no gold stamp
## since left column v2); planning prints the header alone (2026-11-08: no band; the paper as
## short as the header, hanging from the overhead printer since left column v2; its PROJECTED
## rolling to each new projection); the count prints each item's row in slot order, the rows
## adding up to the hero on every frame; BEATEN! only after the count-up's quota_met, slammed at
## SLAM_CELL then settled at CELL, the target green dark and its rule green;
## whole euros everywhere (no ".00"). Layout asserts on-screen geometry (memory: UI tests check
## layout).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const MILK := "res://data/cards/milk.tres"
const DOUBLE := "res://data/pins/double_checkout.tres"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const MAX_FRAMES := 3000

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_receipt_h2_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Planning at both sizes: the header's parts inside the paper and apart, the hero 1.5x the target
## or more, PROJECTED (once rolled), the line against the target; nothing under the header, the
## paper as short as it (standing on the printer's slot, under RECEIPT_TOP).
func test_planning_shows_the_header_alone() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen(window)
		_place_milks(screen, 3)
		await _frames(3)
		for _frame: int in range(600):
			if not screen._receipt.target.roll.rolling():
				break
			await get_tree().process_frame
		var message: String = str(window)
		var receipt: ReceiptView = screen._receipt
		var target: ReceiptTarget = receipt.target
		var preview: int = screen.run.preview().total
		var quota: int = screen.run.quota()
		assert_str(target.amount.text).is_equal(ReceiptTarget.AMOUNT_TEXT % quota)
		assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % preview)
		assert_str(target.total_caption.text).is_equal(ReceiptTarget.PROJECTED_TEXT)
		assert_str(target.over.text).is_equal(ReceiptTarget.against_text(preview, quota))
		assert_that(target.amount.color).is_equal(ReceiptTarget.COLOR)
		assert_bool(target.beaten.visible).override_failure_message(message).is_false()
		_assert_header(receipt, message)
		# Nothing under the header: the paper is the header and its frame.
		assert_int(receipt._lines.get_child_count()).override_failure_message(message).is_equal(0)
		assert_bool(receipt._items.is_empty()).is_true()
		assert_array(receipt.printed_rows()).is_empty()
		var frame: float = receipt.get_theme_stylebox("panel").get_minimum_size().y
		var tall: float = target.size.y + frame + 2.0 * ReceiptView.FRAME_GROW
		assert_float(receipt.size.y).override_failure_message(message).is_equal_approx(tall, 1.0)
		var stage: Rect2 = screen._stage.get_global_rect()
		var scale: float = stage.size.y / screen._stage.size.y
		var top: float = stage.position.y + ShiftStage.RECEIPT_TOP * scale
		assert_float(_paper(receipt).position.y).is_equal_approx(top, 1.0)
		_assert_whole_euros(receipt, message)


## The hero stays at least 1.5x the target and inside the head for any total.
func test_the_hero_steps_down_but_stays_bigger_than_the_target() -> void:
	var target: ReceiptTarget = auto_free(ReceiptTarget.new())
	add_child(target)
	target.size = Vector2(ReceiptTarget.DEFAULT_WIDTH, ReceiptTarget.HEIGHT)
	for total: int in [9, 129, 2329, 99999]:
		target.show_planned(total, 80)
		await _frames(2)
		var message: String = str(total)
		assert_float(target.cells.x).override_failure_message(message).is_greater_equal(
			1.5 * target.cells.y
		)
		assert_float(target.hero.cell).is_equal(target.cells.x)
		assert_float(target.amount.cell).is_equal(target.cells.y)
		var head: Rect2 = target.get_global_rect()
		assert_bool(head.encloses(target.hero_rect())).override_failure_message(message).is_true()
		assert_bool(target.digits_rect().intersects(target.hero_rect())).is_false()
	# A reading wider than the projection the sizes came from steps the target down with the hero.
	target.show_planned(9, 80)
	target.begin_count(0)
	target.show_running(99999)
	await _frames(2)
	assert_float(target.hero.cell).is_greater_equal(1.5 * target.amount.cell)
	assert_bool(target.get_global_rect().encloses(target.hero_rect())).is_true()


## BEATEN! alone: slammed big, then settled at its cell; the target and its rule green; clear()
## takes it off. Still: settled at once.
func test_beaten_slams_then_settles() -> void:
	var target: ReceiptTarget = auto_free(ReceiptTarget.new())
	add_child(target)
	target.size = Vector2(ReceiptTarget.DEFAULT_WIDTH, ReceiptTarget.HEIGHT)
	target.show_planned(90, 80)
	target.begin_count(0)
	await _frames(1)
	target.show_met(true, false)
	assert_bool(target.is_met()).is_true()
	assert_bool(target.beaten.visible).is_true()
	assert_float(target.beaten.cell).is_equal(BeatenStamp.SLAM_CELL)
	assert_that(target.amount.color).is_equal(ReceiptTarget.MET_COLOR)
	await get_tree().create_timer(0.5).timeout
	assert_float(target.beaten.cell).is_equal(BeatenStamp.CELL)
	assert_bool(target.beaten.settled()).is_true()
	var stamp: Rect2 = target.stamp_rect()
	assert_bool(target.get_global_rect().encloses(stamp)).is_true()
	assert_bool(stamp.intersects(target.hero_rect())).is_false()
	var still: ReceiptTarget = auto_free(ReceiptTarget.new())
	add_child(still)
	still.show_planned(90, 80)
	still.show_met(false, true)
	assert_float(still.beaten.cell).is_equal(BeatenStamp.CELL)
	assert_bool(still.beaten.settled()).is_true()


## The count at both sizes: rows print in slot order, add up to the hero on every frame, BEATEN!
## shows only after quota_met and ends settled, the target green; the header stays inside the
## paper and whole euros throughout.
func test_the_count_prints_rows_that_add_up_to_the_hero_at_1280x720() -> void:
	await _count_at(WINDOWS[0])


func test_the_count_prints_rows_that_add_up_to_the_hero_at_1920x1080() -> void:
	await _count_at(WINDOWS[1])


## One count at `window` (a screen per test: a second checkout in one test meets no quota).
func _count_at(window: Vector2) -> void:
	var screen: ShiftScreen = await _screen(window)
	_place_milks(screen, 4)
	var total: int = screen.run.preview().total
	screen.run.limits.quota = maxi(1, floori(total / 2.0))
	screen._refresh()
	await _frames(2)
	var message: String = str(window)
	var receipt: ReceiptView = screen._receipt
	var target: ReceiptTarget = receipt.target
	var seen: Dictionary = {"met": false, "early": false, "off": "", "rows": 0}
	screen._count_up.quota_met.connect(func(_pop: bool) -> void: seen["met"] = true)
	var count_up: CountUp = screen._count_up
	var cells: Array[float] = []
	var header_checked: bool = false
	screen._on_checkout_pressed()
	for frame: int in range(MAX_FRAMES):
		await get_tree().process_frame
		if not screen._counting or count_up._verdict_shown:
			break
		if target.beaten.visible and (cells.is_empty() or cells[-1] != target.beaten.cell):
			cells.append(target.beaten.cell)
		if target.beaten.visible and target.beaten.settled() and not header_checked:
			header_checked = true
			_assert_header(receipt, message + " crossed")
		if target.beaten.visible and not (seen["met"] as bool):
			seen["early"] = true
		var printed: Array[Control] = receipt.printed_rows()
		seen["rows"] = printed.size()
		if printed.is_empty() or target.hero.text.is_empty():
			continue
		var sum: int = 0
		for row: Control in printed:
			sum += _euros((row.get_child(1) as Label).text)
		var hero: int = _euros(target.hero.text)
		if sum != hero and (seen["off"] as String).is_empty():
			seen["off"] = "frame %d: rows %d, hero %d" % [frame, sum, hero]
	assert_str(seen["off"] as String).override_failure_message(message).is_empty()
	assert_bool(seen["early"] as bool).override_failure_message(message).is_false()
	var quota_note: String = "%s quota %d total %d" % [message, screen.run.quota(), total]
	assert_bool(seen["met"] as bool).override_failure_message(quota_note).is_true()
	# Slammed big, then settled at its cell.
	assert_array(cells).override_failure_message(message + str(cells)).is_equal(
		[BeatenStamp.SLAM_CELL, BeatenStamp.CELL]
	)
	assert_bool(header_checked).is_true()
	# At the verdict (the paper still in place, before the machine takes it).
	assert_bool(target.is_met()).is_true()
	assert_bool(target.beaten.settled()).is_true()
	assert_float(target.beaten.cell).is_equal(BeatenStamp.CELL)
	assert_that(target.amount.color).is_equal(ReceiptTarget.MET_COLOR)
	assert_str(target.total_caption.text).is_equal(ReceiptTarget.TOTAL_TEXT)
	assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % total)
	var rows: Array[Control] = receipt.printed_rows()
	assert_int(rows.size()).override_failure_message(message).is_equal(4)
	for index: int in range(1, rows.size()):
		assert_float(rows[index].get_global_rect().position.y).is_greater(
			rows[index - 1].get_global_rect().position.y
		)
	_assert_header(receipt, message + " total")
	_assert_whole_euros(receipt, message)
	await Rush.finish(screen)


## A Double checkout's row 2 (#122): the hero starts at row 1's total, BEATEN! shows settled from
## the start when row 1 met the quota (never slammed), and on every frame the printed rows (row
## 2's alone) add up to the hero less row 1's total, which the small "ROW 1 N€ · ROW 2 OF 2" line
## above them names; at the verdict both rows' total.
func test_a_double_checkouts_row_two_counts_on_from_row_one() -> void:
	var screen: ShiftScreen = await _screen(WINDOWS[0])
	RunPins.wear(screen.run, [load(DOUBLE)])
	screen.run.start_shift()
	screen._refresh()
	await _frames(2)
	_place_milks(screen, 2)
	await _frames(2)
	await Rush.checkout(screen)
	await _frames(2)
	var run: RunState = screen.run
	var first_total: int = run.first_result.total
	assert_int(first_total).is_greater(0)
	run.limits.quota = first_total
	_place_milks(screen, 2)
	await _frames(2)
	var second_total: int = run.preview().total
	var receipt: ReceiptView = screen._receipt
	var target: ReceiptTarget = receipt.target
	var row_line: String = DoubleCheckoutFlow.ROW_TWO_TEXT % ReceiptView.money(first_total)
	var seen: Dictionary = {"first": -1, "off": "", "slam": false, "unsettled": false}
	var count_up: CountUp = screen._count_up
	screen._on_checkout_pressed()
	for frame: int in range(MAX_FRAMES):
		await get_tree().process_frame
		if not screen._counting or count_up._verdict_shown:
			break
		if target.hero.text.is_empty():
			continue
		var hero: int = _euros(target.hero.text)
		if int(seen["first"]) < 0:
			seen["first"] = hero
		if target.beaten.cell == BeatenStamp.SLAM_CELL:
			seen["slam"] = true
		if not (target.beaten.visible and target.beaten.settled()):
			seen["unsettled"] = true
		var sum: int = 0
		for row: Control in receipt.printed_rows():
			sum += _euros((row.get_child(1) as Label).text)
		if sum + first_total != hero and (seen["off"] as String).is_empty():
			seen["off"] = "frame %d: rows %d + row 1 %d, hero %d" % [frame, sum, first_total, hero]
	assert_int(int(seen["first"])).is_equal(first_total)
	assert_str(seen["off"] as String).is_empty()
	assert_bool(seen["slam"] as bool).is_false()
	assert_bool(seen["unsettled"] as bool).is_false()
	assert_bool(target.is_met()).is_true()
	assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % (first_total + second_total))
	assert_int(receipt.printed_rows().size()).is_equal(2)
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in receipt.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_bool(texts.has(row_line)).override_failure_message(str(texts)).is_true()
	_assert_header(receipt, "row 2")
	await Rush.finish(screen)


## The header's parts are inside the paper and apart from each other (in the header's own
## coordinates: the stage scales the receipt).
func _assert_header(receipt: ReceiptView, message: String) -> void:
	var target: ReceiptTarget = receipt.target
	var paper: Rect2 = _local(target, _paper(receipt))
	var parts: Dictionary[String, Rect2] = {
		"beat": _local(target, target.beat.get_global_rect()),
		"caption": _local(target, target.caption.get_global_rect()),
		"target": target.digits_rect(),
		"hero": target.hero_rect(),
		"total": _local(target, target.total_caption.get_global_rect()),
		"over": _local(target, _text_rect(target.over)),
	}
	if target.beaten.visible:
		parts["beaten"] = target.stamp_rect()
	for part: String in parts:
		var rect: Rect2 = parts[part]
		(
			assert_bool(paper.grow(1).encloses(rect))
			. override_failure_message("%s %s %s in %s" % [message, part, rect, paper])
			. is_true()
		)
	for pair: Array in [
		["beat", "target"],
		["caption", "target"],
		["target", "hero"],
		["total", "hero"],
		["over", "hero"],
		["target", "total"],
	]:
		var a: Rect2 = parts[pair[0]]
		var b: Rect2 = parts[pair[1]]
		(
			assert_bool(a.intersects(b))
			. override_failure_message("%s %s over %s" % [message, pair[0], pair[1]])
			. is_false()
		)
	assert_float(target.cells.x).is_greater_equal(1.5 * target.cells.y)
	assert_float(target.hero.cell).is_greater_equal(1.5 * target.amount.cell)


## No label on the receipt prints cents.
func _assert_whole_euros(receipt: ReceiptView, message: String) -> void:
	for label: Node in receipt.find_children("*", "Label", true, false):
		var text: String = (label as Label).text
		assert_bool(text.contains(".00")).override_failure_message(message + " " + text).is_false()
	for words: Node in receipt.find_children("*", "PixelWords", true, false):
		assert_bool((words as PixelWords).text.contains(".00")).is_false()


## `rect` (global) in `control`'s coordinates.
static func _local(control: Control, rect: Rect2) -> Rect2:
	var inverse: Transform2D = control.get_global_transform().affine_inverse()
	return Rect2(inverse * rect.position, inverse.basis_xform(rect.size))


## A right-aligned label's text rect (global): its text's width at its right end.
static func _text_rect(label: Label) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var scale: float = label.get_global_transform().get_scale().x
	return Rect2(rect.end.x - width * scale, rect.position.y, width * scale, rect.size.y)


static func _paper(receipt: ReceiptView) -> Rect2:
	return receipt.get_global_rect()


## An amount's whole euros ("+12€", "0€", "" as 0).
static func _euros(text: String) -> int:
	var digits: String = text.replace("€", "").replace("+", "").replace("−", "-").strip_edges()
	return int(digits) if digits.is_valid_int() else 0


func _place_milks(screen: ShiftScreen, count: int) -> void:
	for _card: int in range(count):
		screen.run.place(screen.run.debug_add_to_hand(load(MILK)), screen.run.row.size())
	screen._refresh()


func _screen(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	# The week's medals already spent (caps of 0): no medal prelude (MedalPrelude) before the
	# count these tests watch from the click (week_medals_test covers the prelude).
	var machine: MachineDefinition = screen.run.machine.machine.duplicate()
	machine.overtime_ticket_per_week = 0
	machine.overtime_premium_per_week = 0
	screen.run.machine.machine = machine
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
