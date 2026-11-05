extends GdUnitTestSuite
## The receipt in fit-up mode on the shift screen (#80, mock-up B2): it stands on the printer's
## slot (ShiftStage.RECEIPT_BOTTOM), in planning at its full length (B2 of shift_scene_polish_v4:
## up to RECEIPT_TOP, one row per belt slot, the foot pinned at its bottom, nothing scrolling, at
## 1280x720 and 1920x1080), else as tall as its lines; a long receipt stops at RECEIPT_TOP and
## shows its newest line, with no scroll bar while the mouse wheel still scrolls; the end of a
## shift printed at once (a resume, ReceiptView.show_shift_end) takes the same fit; a 9-item
## count-up with 27 steps starts as tall as its lines and keeps its framed line in view at every
## step, then its TOTAL line. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const DOUBLE := "res://data/pins/double_checkout.tres"

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


## The planning receipt at full length (B2 at D's sizes, mock-up shift_scene_polish_v4, v4.1's
## frame): with 6, 7, 8 and 9 belt slots it reaches from the printer's slot to RECEIPT_TOP however
## few items are placed, one row per slot (a placed item's line, else "n ·····" in muted ink),
## every row the same pitch (20, 20, 18 and 18 px since the PR #138 left UI gave the fizzle
## footer's room to the rows: 30, 30, 27 and 27 at 1920x1080), the header line shown under 9
## slots and dropped at 9 (the page's rule); on a Double checkout shift (6 slots at most: its
## 4-slot row, Big basket and Extra till) both header lines print; nothing
## scrolls; and the foot (PROJECTED and its line against the target; no fizzle footer since the
## PR #138 left UI, its room the rows') stands at the paper's bottom, so neither it nor any row
## moves as items are placed, with or without a fizzle. Every row's text fits it on one row, its
## descenders inside its pitch.
func test_the_planning_receipt_is_full_length_with_a_row_per_slot() -> void:
	var screen: ShiftScreen = await _screen()
	var receipt: ReceiptView = screen._receipt
	var stage_y: float = screen._stage.get_global_rect().position.y
	var row_ids: Array[String] = [
		"birthday_candles", "bread", "milk", "multipack", "eggs", "milk", "bread", "milk", "eggs"
	]
	for case: Array in [
		[6, 20.0, true, false],
		[7, 20.0, true, false],
		[8, 18.0, true, false],
		[9, 18.0, false, false],
		[6, -1.0, true, true],
	]:
		var slots: int = case[0] as int
		var where: String = "%d slots%s" % [slots, " (double)" if case[3] else ""]
		_clear_row(screen)
		if case[3]:
			RunPins.wear(screen.run, [load(DOUBLE) as PinDefinition])
			screen.run.start_shift()
		screen.run.limits.slot_count = slots
		var projected_y: float = -1.0
		var row_tops: Array[float] = []
		for placed: int in [0, 2, slots]:
			_place(screen, row_ids.slice(screen.run.row.size(), placed))
			await _frames(3)
			assert_int(screen.run.row.size()).is_equal(placed)
			var rect: Rect2 = receipt.get_global_rect()
			assert_float(rect.position.y).is_equal(stage_y + ShiftStage.RECEIPT_TOP)
			assert_float(rect.end.y).is_equal(stage_y + ShiftStage.RECEIPT_BOTTOM)
			# Nothing scrolls in planning.
			assert_int(receipt._scroll.scroll_vertical).override_failure_message(where).is_equal(0)
			assert_float(receipt._inset.get_combined_minimum_size().y).is_less_equal(
				receipt._scroll.size.y
			)
			assert_int(receipt._rows.size()).override_failure_message(where).is_equal(slots)
			var separation: float = receipt._lines.get_theme_constant("separation")
			var tops: Array[float] = []
			for slot: int in range(slots):
				var row: HBoxContainer = receipt._rows[slot] as HBoxContainer
				var name_label: Label = row.get_child(0) as Label
				if case[1] as float > 0.0:
					var pitch: float = row.size.y + separation
					var said: String = "%s: pitch %s" % [where, pitch]
					assert_float(pitch).override_failure_message(said).is_equal(case[1] as float)
				assert_float(row.size.y + separation).is_greater_equal(ReceiptRows.MIN_PITCH)
				assert_int(name_label.get_line_count()).is_equal(1)
				_assert_row_text_fits(row, where)
				tops.append(row.get_global_rect().position.y)
				if slot < placed:
					assert_object(row).is_same(receipt._item_line_of(slot))
				else:
					assert_str(name_label.text).is_equal(ReceiptView.EMPTY_SLOT_TEXT % (slot + 1))
					assert_that(name_label.get_theme_color("font_color")).is_equal(
						Palette.MUTED_INK
					)
			if row_tops.is_empty():
				row_tops = tops
			assert_array(tops).override_failure_message(where).is_equal(row_tops)
			for line: Control in receipt._header:
				assert_bool(line.visible).override_failure_message(where).is_equal(case[2])
			# Every header line but the SHIFT one (a Double checkout's row line) always prints.
			var header_shown: int = 0
			for text: String in screen.receipt_header():
				header_shown += 1 if _shown_line(receipt, text) else 0
			var header_size: int = screen.receipt_header().size()
			assert_int(header_shown).override_failure_message(where).is_equal(
				header_size if case[2] else header_size - 1
			)
			# The foot stands at the paper's bottom: PROJECTED never moves.
			var projected: Control = _projected(receipt)
			if projected_y < 0.0:
				projected_y = projected.get_global_rect().position.y
			assert_float(projected.get_global_rect().position.y).is_equal(projected_y)
			var last: Control = receipt._lines.get_children()[-1] as Control
			var scroll: Rect2 = receipt._scroll.get_global_rect()
			assert_bool(scroll.grow(1.0).encloses(last.get_global_rect())).is_true()
			# The foot's last line is the paper's last: no footer's room kept under it.
			assert_str(last.name).override_failure_message(where).is_equal("Against")
			assert_float(scroll.end.y - last.get_global_rect().end.y).is_less_equal(
				ReceiptView.FRAME_GROW + 1.0
			)
	_clear_row(screen)


## The full-length receipt's geometry at 1280x720 and 1920x1080 (the stage at 1.5x): the paper in
## the receipt's well from RECEIPT_TOP to the printer's slot, TODAY'S TARGET's digits 72 px tall
## at 1920x1080 (48 at 1280x720), the item lines at LINE_FONT_SIZE (21 px at 1920x1080), every
## line inside the paper.
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
		var digits: Rect2 = receipt.target.digits_rect()
		assert_float(digits.size.y * stretch).override_failure_message(where).is_equal_approx(
			72.0 * window.y / 1080.0, 0.01
		)
		var item: Label = receipt._item_line_of(0).get_child(0) as Label
		assert_int(item.get_theme_font_size("font_size")).is_equal(ReceiptView.LINE_FONT_SIZE)
		var paper: Rect2 = receipt.get_global_rect()
		var stage: Rect2 = screen._stage.get_global_rect()
		assert_float(paper.position.x).is_equal(stage.position.x + ShiftStage.RECEIPT_X)
		assert_float(paper.size.x).is_equal(ShiftStage.RECEIPT_WIDTH)
		assert_float(paper.position.y).is_equal(stage.position.y + ShiftStage.RECEIPT_TOP)
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
	assert_float(receipt.position.y).is_equal(ShiftStage.RECEIPT_TOP)
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
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
	# Cleared (no longer planning's receipt), it is short again, still on the slot: only
	# planning's receipt is full length (B2).
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
	# As tall as its lines, up to its room: only planning's receipt is full length (B2).
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	assert_float(receipt.size.y).is_equal(minf(receipt.natural_height(), room))
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
	_assert_newest_in_view(receipt)


## A planning receipt shown before it was ever laid out (a fresh screen, a resume) still shrinks a
## four-digit PROJECTED amount to its paper once its lines get their width.
func test_a_projected_amount_fits_a_receipt_laid_out_after_it() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	var result: ScoreResult = ScoreResult.new()
	result.total = 12345
	receipt.show_planning(ReceiptView.header_lines(5, 12, 0), result, PackedStringArray(), 7, 100)
	var line: HBoxContainer = receipt._projected
	var amount: Label = line.get_child(1) as Label
	assert_int(amount.get_theme_font_size("font_size")).is_equal(ReceiptView.PROJECTED_FONT_SIZE)
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM)
	add_child(receipt)
	await _frames(3)
	var font_size: int = amount.get_theme_font_size("font_size")
	assert_int(font_size).is_less(ReceiptView.PROJECTED_FONT_SIZE)
	var caption: Label = line.get_child(0) as Label
	var used: float = (
		ReceiptView.text_width(caption.text, ReceiptView.MONO_FONT, ReceiptView.CAPTION_FONT_SIZE)
		+ ReceiptView.text_width(amount.text, amount.get_theme_font("font"), font_size)
		+ line.get_theme_constant("separation")
	)
	assert_float(used).is_less_equal(receipt._lines.size.x)


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
	# The count's receipt is unchanged by B2: it starts as tall as its lines, on the slot, and
	# grows up as they print.
	assert_float(receipt.size.y).is_equal(receipt.natural_height())
	assert_float(receipt.position.y).is_greater(ShiftStage.RECEIPT_TOP)
	assert_float(receipt.position.y + receipt.size.y).is_equal(ShiftStage.RECEIPT_BOTTOM)
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


static func _projected(receipt: ReceiptView) -> Control:
	for line: Node in receipt._lines.get_children():
		if (
			line is HBoxContainer
			and (line.get_child(0) as Label).text == ReceiptView.PROJECTED_TEXT
		):
			return line as Control
	return null


## A planning row's name fits past its mini on one row at its font size (else it is at the least
## size, cut); its mini and its mark sit inside the row.
func _assert_row_text_fits(row: HBoxContainer, where: String) -> void:
	var name_label: Label = row.get_child(0) as Label
	var font: Font = name_label.get_theme_font("font")
	var font_size: int = name_label.get_theme_font_size("font_size")
	var slot: float = name_label.get_theme_stylebox("normal").content_margin_left
	var width: float = ReceiptView.text_width(name_label.text, font, font_size)
	if font_size > ReceiptInk.NAME_MIN_FONT_SIZE:
		(
			assert_float(width)
			. override_failure_message("%s: %s" % [where, name_label.text])
			. is_less_equal(name_label.size.x - slot + 0.5)
		)
	var rect: Rect2 = row.get_global_rect().grow(1.0)
	for part: Node in row.find_children("*", "TextureRect", true, false):
		assert_bool(rect.encloses((part as Control).get_global_rect())).is_true()
	# A descender ("g") and a capital ("B") stay inside the row's pitch (the row and the
	# separation under it): the labels are not clipped, so nothing is cut. A glyph's rendered rect
	# keeps a 1 px margin round its ink, hence the 1 px allowance.
	var base: Font = name_label.get_meta(ReceiptRows.BASE_FONT_META) as Font
	var spaced: FontVariation = font as FontVariation
	var baseline: float = (
		name_label.get_global_rect().position.y + spaced.spacing_top + base.get_ascent(font_size)
	)
	var separation: float = row.get_parent().get_theme_constant("separation")
	for ink: Vector2 in [_ink_span(base, font_size, "g"), _ink_span(base, font_size, "B")]:
		var where_ink: String = "%s: %s %s" % [where, name_label.text, ink]
		assert_float(baseline + ink.y).override_failure_message(where_ink).is_less_equal(
			row.get_global_rect().end.y + separation + 1.0
		)
		assert_float(baseline + ink.x).override_failure_message(where_ink).is_greater_equal(
			row.get_global_rect().position.y - 1.0
		)


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
