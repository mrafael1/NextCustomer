extends GdUnitTestSuite
## The receipt in fit-up mode on the shift screen (#80, mock-up B2; since left column v2 it hangs
## from the overhead printer's slot, ShiftStage.RECEIPT_TOP, and grows down to RECEIPT_BOTTOM),
## as tall as its lines: in planning its header alone (no band, no
## rows since the 2026-11-08 feedback, nothing scrolling, at 1280x720 and 1920x1080); a long
## receipt stops at RECEIPT_BOTTOM and shows its newest line, with no scroll bar while the mouse
## wheel still scrolls; the end of a shift printed at once (a resume,
## ReceiptView.show_shift_end) takes the same fit; a 9-item count-up with 27 steps starts as tall as
## its lines and keeps its framed line in view at every step, then its TOTAL line. The real saves
## and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const DOUBLE := "res://data/pins/double_checkout.tres"
const ReceiptFed := preload("res://tests/ui/receipt_fed_lines.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The planning receipt (main scene v2, H2; 2026-11-08 feedback): with 6, 7, 8 and 9 belt slots it
## stands on the printer's slot as tall as its header (and a Double checkout's row line) however
## many items are placed, under RECEIPT_TOP; it prints no rows and no band; nothing scrolls, and
## the paper never moves as items are placed.
func test_the_planning_receipt_is_the_header_alone() -> void:
	var screen: ShiftScreen = await _screen()
	var receipt: ReceiptView = screen._receipt
	var stage_y: float = screen._stage.get_global_rect().position.y
	var row_ids: Array[String] = [
		"birthday_candles", "bread", "milk", "multipack", "eggs", "milk", "bread", "milk", "eggs"
	]
	for case: Array in [[6, false], [7, false], [8, false], [9, false], [6, true]]:
		var slots: int = case[0] as int
		var where: String = "%d slots%s" % [slots, " (double)" if case[1] else ""]
		_clear_row(screen)
		if case[1]:
			RunPins.wear(screen.run, [load(DOUBLE) as PinDefinition])
			screen.run.start_shift()
		screen.run.limits.slot_count = slots
		var top_y: float = -1.0
		for placed: int in [0, 2, slots]:
			_place(screen, row_ids.slice(screen.run.row.size(), placed))
			await _frames(3)
			assert_int(screen.run.row.size()).is_equal(placed)
			var rect: Rect2 = receipt.get_global_rect()
			assert_float(rect.position.y).is_equal(stage_y + ShiftStage.RECEIPT_TOP)
			assert_float(rect.end.y).is_less(stage_y + ShiftStage.RECEIPT_BOTTOM)
			assert_float(receipt.size.y).override_failure_message(where).is_equal(
				receipt.natural_height()
			)
			# Nothing scrolls in planning.
			assert_int(receipt._scroll.scroll_vertical).override_failure_message(where).is_equal(0)
			assert_bool(receipt._items.is_empty()).override_failure_message(where).is_true()
			if top_y < 0.0:
				top_y = rect.position.y
			assert_float(rect.position.y).override_failure_message(where).is_equal(top_y)
			# Every header line (a Double checkout's row line) prints.
			for text: String in screen.receipt_header():
				assert_bool(_shown_line(receipt, text)).override_failure_message(where).is_true()
			assert_bool(screen.receipt_header().is_empty()).is_equal(not case[1])
	_clear_row(screen)


## The full-length receipt's geometry at 1280x720 and 1920x1080 (the stage at 1.5x): the paper in
## the receipt's well, standing on the printer's slot under RECEIPT_TOP, TODAY'S TARGET's digits
## at the target's cell and the hero at its own, every line inside the paper.
func test_the_receipt_geometry_at_both_window_sizes() -> void:
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		_place(screen, ["eggs", "bread"])
		await _frames(3)
		var receipt: ReceiptView = screen._receipt
		var stretch: float = get_tree().root.get_final_transform().get_scale().y
		var where: String = str(window)
		assert_float(stretch).is_equal_approx(window.y / 720.0, 0.001)
		# The target's 6x8 digits at its cell (main scene v2: 32 px, 48 at 1920x1080), the hero's at
		# its own, 1.5x the target's or more.
		var target: ReceiptTarget = receipt.target
		var digits: Rect2 = target.digits_rect()
		assert_float(digits.size.y).override_failure_message(where).is_equal(8.0 * target.cells.y)
		assert_float(target.hero_rect().size.y).is_equal(8.0 * target.cells.x)
		assert_float(target.cells.x).is_greater_equal(1.5 * target.cells.y)
		var paper: Rect2 = receipt.get_global_rect()
		var stage: Rect2 = screen._stage.get_global_rect()
		assert_float(paper.position.x).is_equal(stage.position.x + ShiftStage.RECEIPT_X)
		assert_float(paper.size.x).is_equal(ShiftStage.RECEIPT_WIDTH)
		assert_float(paper.position.y).is_equal(stage.position.y + ShiftStage.RECEIPT_TOP)
		assert_float(paper.end.y).is_less(stage.position.y + ShiftStage.RECEIPT_BOTTOM)
		(
			assert_bool(paper.encloses(target.get_global_rect()))
			. override_failure_message(where)
			. is_true()
		)
		assert_bool(screen.get_viewport_rect().encloses(paper)).is_true()
		for line: Node in receipt._lines.get_children():
			var rect: Rect2 = (line as Control).get_global_rect()
			assert_bool(paper.encloses(rect)).override_failure_message(where + str(rect)).is_true()
	get_tree().root.size = Vector2i(1280, 720)


## A long receipt grows up to RECEIPT_TOP, still standing on the printer's slot, scrolls to its
## newest line with no scroll bar, and the wheel (the scroll area) still reaches its first line.
func test_a_long_receipt_stops_under_the_top_bar_and_scrolls_to_its_end() -> void:
	var screen: ShiftScreen = await _screen()
	await _long_receipt(screen)
	var receipt: ReceiptView = screen._receipt
	assert_float(receipt.natural_height()).is_greater(receipt.size.y)
	assert_float(_top(receipt)).is_equal(ShiftStage.RECEIPT_TOP)
	assert_float(_top(receipt) + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
	assert_bool(receipt._scroll.get_v_scroll_bar().visible).is_false()
	_assert_newest_in_view(receipt)
	# TODAY'S TARGET (the shift scene polish) stays pinned at the paper's top, above the scrolled
	# lines, with the shift's quota.
	var target: ReceiptTarget = receipt.target
	assert_bool(target.visible).is_true()
	assert_int(target.shown_quota()).is_equal(screen.run.quota())
	var block: Rect2 = target.get_global_rect()
	assert_bool(receipt.get_global_rect().encloses(block)).is_true()
	assert_float(block.end.y).is_less_equal(receipt._scroll.get_global_rect().position.y)
	assert_float(block.position.y - receipt.get_global_rect().position.y).is_less(24.0)
	# The wheel scrolls the area: back at the top, the first line shows and stays.
	receipt._scroll.scroll_vertical = 0
	await _frames(3)
	assert_int(receipt._scroll.scroll_vertical).is_equal(0)
	var first: Rect2 = (receipt._lines.get_child(0) as Control).get_global_rect()
	assert_bool(receipt._scroll.get_global_rect().grow(1.0).encloses(first)).is_true()
	# Cleared, it is short again, still on the slot.
	receipt.clear()
	await _frames(2)
	assert_float(_top(receipt) + receipt.size.y).is_less(ShiftStage.RECEIPT_BOTTOM)
	assert_float(_top(receipt)).is_equal(ShiftStage.RECEIPT_TOP)


## The end of a shift printed at once, as a resume does (the row's receipt, then show_shift_end):
## the same fit, ending with the inspection notice in view.
func test_a_resumed_end_of_shift_takes_the_same_fit() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk", "eggs", "repeat", "milk"])
	var run: RunState = screen.run
	var result: ScoreResult = run.preview()
	screen._show_checked_out(result)
	screen._receipt.show_shift_end(result.total, run.quota(), "Spot check next shift")
	await _frames(2)
	var receipt: ReceiptView = screen._receipt
	while receipt.hang.is_feeding():  # Left column v2: the paper feeds down to its lines.
		await _frames(1)
	# The anchored receipt (2026-11-05) keeps the count's full length through the shift's end, as
	# the checkout left it, fed on at its foot by the end's lines (2026-11-07: the margin's PAID,
	# INSPECTION PASSED, the tear and the notice under its foot, nothing beside it). Since H2 the
	# paper no longer rises by them: its header (the hero, the target) stays on the screen, and
	# the lines past its room scroll under the header, the newest in view (v1.18 review).
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	assert_bool(receipt.anchored).is_true()
	var tall: float = minf(receipt.natural_height(), room)
	assert_float(receipt.size.y).is_equal_approx(tall, ArtStyle.ART_SCALE)
	assert_float(_top(receipt)).is_equal_approx(ShiftStage.RECEIPT_TOP, 0.01)
	assert_float(_top(receipt) + receipt.size.y).is_less_equal(ShiftStage.RECEIPT_BOTTOM)
	var header: Rect2 = receipt.target.get_global_rect()
	assert_bool(screen.get_viewport_rect().encloses(header)).is_true()
	var failures: Array[String] = ReceiptFed.failures(
		receipt, ReceiptFed.planned_rect(screen), screen.get_viewport_rect()
	)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	_assert_newest_in_view(receipt)


## A planning receipt shown before it was ever laid out (a fresh screen, a resume) still steps a
## five-digit hero down to its head once it gets its width, at least 1.5x the target.
func test_a_projected_amount_fits_a_receipt_laid_out_after_it() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	var result: ScoreResult = ScoreResult.new()
	result.total = 12345
	receipt.show_planning(PackedStringArray(), result, PackedStringArray(), 7, 100)
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM)
	add_child(receipt)
	await _frames(3)
	var target: ReceiptTarget = receipt.target
	assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % 12345)
	assert_float(target.cells.x).is_greater_equal(1.5 * target.cells.y)
	var head: Rect2 = Rect2(0.0, 0.0, target._width(), ReceiptTarget.HEIGHT)
	(
		assert_bool(head.encloses(target.hero_rect()))
		. override_failure_message("%s in %s" % [target.hero_rect(), head])
		. is_true()
	)


## The screen on shift 1, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


## The longest count-up: 9 items, 3 steps each (base, a bonus, the payout), printed one by one.
## After each, once laid out, the framed line (the one being counted) is whole inside the scroll
## area; then the TOTAL line is, with the receipt at its cap.
func test_a_long_count_up_keeps_its_counted_line_in_view() -> void:
	var screen: ShiftScreen = await _screen()
	var receipt: ReceiptView = screen._receipt
	var names: PackedStringArray = PackedStringArray()
	for slot: int in range(9):
		names.append("Birthday candles" if slot % 2 == 0 else "Milk")
	# The printed lines' count (a receipt not anchored to planning: the anchored count prints its
	# rows in place, receipt_h2_test).
	receipt.anchored = false
	receipt.begin_count(PackedStringArray(["ROW 1/2"]), names)
	await _frames(3)
	# The count's receipt starts as tall as its lines, hanging from the slot, and grows down as
	# they print (left column v2).
	assert_float(receipt.size.y).is_equal(receipt.natural_height())
	assert_float(_top(receipt)).is_equal(ShiftStage.RECEIPT_TOP)
	assert_float(_top(receipt) + receipt.size.y).is_less(ShiftStage.RECEIPT_BOTTOM)
	var subtotal: int = 0
	for slot: int in range(9):
		for type: ScoreStep.StepType in [
			ScoreStep.StepType.BASE, ScoreStep.StepType.FLAT, ScoreStep.StepType.PAYOUT
		]:
			var step: ScoreStep = ScoreStep.new()
			step.step_type = type
			step.slot = slot
			step.source_slot = maxi(slot - 1, 0)
			step.value = 3 if type != ScoreStep.StepType.PAYOUT else 18
			step.text = "Category engine beside Produce"
			receipt.add_step(step, names)
			await _frames(3)
			var framed: Control = receipt._framed_line()
			assert_object(framed).is_not_null()
			_assert_in_view(receipt, framed, "%s at slot %d" % [type, slot])
		subtotal += 18
	assert_float(_top(receipt)).is_equal(ShiftStage.RECEIPT_TOP)
	receipt.add_total(subtotal)
	await _frames(3)
	_assert_in_view(receipt, receipt._total_line, "TOTAL")
	receipt.show_shift_end(subtotal, 100, "Spot check next shift")
	await _frames(3)
	_assert_newest_in_view(receipt)


func _assert_in_view(receipt: ReceiptView, line: Control, what: String) -> void:
	var rect: Rect2 = line.get_global_rect()
	var area: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
	(
		assert_bool(area.encloses(rect))
		. override_failure_message("%s: %s outside %s" % [what, rect, area])
		. is_true()
	)


## Prints lines until the receipt is longer than its room, then lets it lay out.
func _long_receipt(screen: ShiftScreen) -> void:
	var receipt: ReceiptView = screen._receipt
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	var count: int = 0
	while receipt.natural_height() <= room + 60.0:
		receipt.add_line("LINE %d" % count, "%d€" % count, ReceiptView.LineStyle.ITEM)
		count += 1
		await _frames(1)
		assert_int(count).is_less(200)
	await _frames(2)


## Takes every item off the belt.
func _clear_row(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	while not run.row.is_empty():
		assert_bool(run.remove(run.row[-1])).is_true()
	screen._refresh()


## The top and the bottom of `character`'s ink at `font_size`, from its baseline (down positive).
func _ink_span(font: Font, font_size: int, character: String) -> Vector2:
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var size: Vector2i = Vector2i(font_size, 0)
	var glyph: int = server.font_get_glyph_index(rid, font_size, character.unicode_at(0), 0)
	server.font_render_glyph(rid, size, glyph)
	var offset: Vector2 = server.font_get_glyph_offset(rid, size, glyph)
	var extent: Vector2 = server.font_get_glyph_size(rid, size, glyph)
	assert_float(extent.y).is_greater(0.0)
	return Vector2(offset.y, offset.y + extent.y)


## Whether a visible line of `receipt` reads `text` on its left.
static func _shown_line(receipt: ReceiptView, text: String) -> bool:
	for line: Node in receipt._lines.get_children():
		var control: Control = line as Control
		if control is HBoxContainer and control.visible:
			if (control.get_child(0) as Label).text == text:
				return true
	return false


func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % card_id))
		assert_bool(run.place(card, run.row.size())).is_true()
	screen._refresh()


func _assert_newest_in_view(receipt: ReceiptView) -> void:
	var lines: Array[Node] = receipt._lines.get_children()
	var newest: Rect2 = (lines[-1] as Control).get_global_rect()
	var area: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
	(
		assert_bool(area.encloses(newest))
		. override_failure_message("newest line %s outside %s" % [newest, area])
		. is_true()
	)


func _assert_lines_in_view(receipt: ReceiptView) -> void:
	var area: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
	for line: Node in receipt._lines.get_children():
		var rect: Rect2 = (line as Control).get_global_rect()
		assert_bool(area.encloses(rect)).override_failure_message(str(rect)).is_true()


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## The receipt's top on the stage (its clipping slot's top plus its own).
static func _top(receipt: ReceiptView) -> float:
	return (receipt.get_parent() as Control).position.y + receipt.position.y
