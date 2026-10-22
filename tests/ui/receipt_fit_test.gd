extends GdUnitTestSuite
## The receipt in fit-up mode on the shift screen (#80, mock-up B2): it stands on the printer's
## slot (ShiftStage.RECEIPT_BOTTOM) as tall as its lines; a long receipt stops at RECEIPT_TOP and
## shows its newest line, with no scroll bar while the mouse wheel still scrolls; the end of a
## shift printed at once (a resume, ReceiptView.show_shift_end) takes the same fit; a 9-item
## count-up with 27 steps keeps its framed line in view at every step, then its TOTAL line. The
## real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"

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


## The preview is itemised (#80): a short receipt standing on the printer's slot, as tall as its
## lines, every line in view. A longer belt's is as short: its items take the empty slots' lines.
func test_a_short_preview_gives_a_short_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk"])
	await _frames(2)
	var receipt: ReceiptView = screen._receipt
	assert_int(receipt._lines.get_child_count()).is_greater(0)
	var one: float = receipt.natural_height()
	_place(screen, ["bread", "bread", "bread", "bread"])
	await _frames(2)
	assert_float(receipt.natural_height()).is_equal(one)
	assert_float(receipt.size.y).is_equal(receipt.natural_height())
	var stage_y: float = screen._stage.get_global_rect().position.y
	assert_float(receipt.get_global_rect().end.y).is_equal(stage_y + ShiftStage.RECEIPT_BOTTOM)
	assert_float(receipt.position.y).is_greater(ShiftStage.RECEIPT_TOP)
	assert_bool(receipt._scroll.get_v_scroll_bar().visible).is_false()
	_assert_lines_in_view(receipt)


## A long receipt grows up to RECEIPT_TOP, still standing on the printer's slot, scrolls to its
## newest line with no scroll bar, and the wheel (the scroll area) still reaches its first line.
func test_a_long_receipt_stops_under_the_top_bar_and_scrolls_to_its_end() -> void:
	var screen: ShiftScreen = await _screen()
	await _long_receipt(screen)
	var receipt: ReceiptView = screen._receipt
	assert_float(receipt.natural_height()).is_greater(receipt.size.y)
	assert_float(receipt.position.y).is_equal(ShiftStage.RECEIPT_TOP)
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
	assert_bool(receipt._scroll.get_v_scroll_bar().visible).is_false()
	_assert_newest_in_view(receipt)
	# The wheel scrolls the area: back at the top, the first line shows and stays.
	receipt._scroll.scroll_vertical = 0
	await _frames(3)
	assert_int(receipt._scroll.scroll_vertical).is_equal(0)
	var first: Rect2 = (receipt._lines.get_child(0) as Control).get_global_rect()
	assert_bool(receipt._scroll.get_global_rect().grow(1.0).encloses(first)).is_true()
	# Cleared, it is short again, still on the slot.
	receipt.clear()
	await _frames(2)
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
	assert_float(receipt.position.y).is_greater(ShiftStage.RECEIPT_TOP)


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
	var natural: float = receipt.natural_height()
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	assert_float(receipt.size.y).is_equal(minf(natural, room))
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
	_assert_newest_in_view(receipt)


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
	receipt.begin_count(ReceiptView.header_lines(5, 8, 9), names)
	await _frames(3)
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
	assert_float(receipt.position.y).is_equal(ShiftStage.RECEIPT_TOP)
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
		receipt.add_line("LINE %d" % count, "€%d" % count, ReceiptView.LineStyle.ITEM)
		count += 1
		await _frames(1)
		assert_int(count).is_less(200)
	await _frames(2)


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
