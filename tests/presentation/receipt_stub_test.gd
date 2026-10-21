extends GdUnitTestSuite
## ReceiptView's planning receipt, count-up lines, header and combo lines (#75, #80). Planning
## (show_planning) is itemised: the header, a dashed rule, one line per item (name, payout with
## cents, its mark: the check when raised, the fizzle icon when it fizzles), "n ·····" per open
## empty slot, a dashed rule, "PROJECTED €N.00" (given the quota: green with the met mark at or
## over it, red under it, the shortfall "short €1.00" on its own row under it), then the fizzle
## footer ("2 fizzles · hover an item", none without fizzles); highlight_slot frames a line
## (planning only). The count-up
## (begin_count) pre-prints every item's line greyed and "TOTAL •••••" with its footer; the steps
## fill the lines in (the base, kept) and print under their item, the newest framed; an item whose
## lines don't add up to its payout closes with "= €3.00"; add_total fills TOTAL in and
## drops the footer and the frame; show_result prints the same receipt at once. Every bonus,
## multiplier or copy another source caused is a combo line, marked by a gold band and a diamond
## in place of its marker. The receipt is laid out on its own, at the shift screen's width. No
## saves, no event log.

const RECEIPT_SIZE := Vector2(ShiftStage.RECEIPT_WIDTH, 600)
const HEADER: Array[String] = ["NEXT CUSTOMER · REG 3", "SHIFT 5/8 · 4 ITEMS"]
const NAMES: Array[String] = ["Milk", "Bread", "Coffee"]

var _receipt: ReceiptView


func before_test() -> void:
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	add_child(_receipt)
	_receipt.size = RECEIPT_SIZE


func test_the_header_counts_the_shift_and_every_item() -> void:
	assert_array(Array(ReceiptView.header_lines(5, 8, 4))).is_equal(HEADER)
	assert_array(Array(ReceiptView.header_lines(1, 10, 1))).is_equal(
		["NEXT CUSTOMER · REG 3", "SHIFT 1/10 · 1 ITEM"]
	)
	assert_array(Array(ReceiptView.header_lines(1, 10, 0))).is_equal(
		["NEXT CUSTOMER · REG 3", "SHIFT 1/10 · 0 ITEMS"]
	)


## Every money amount on the receipt prints with cents; the values stay whole euros.
func test_money_prints_cents() -> void:
	assert_str(ReceiptView.money(3)).is_equal("€3.00")
	assert_str(ReceiptView.money(22)).is_equal("€22.00")
	assert_str(ReceiptView.money(15, true)).is_equal("+€15.00")
	assert_str(ReceiptView.money(0)).is_equal("€0.00")
	assert_str(ReceiptView.verdict_text(51, 40)).is_equal("€51.00 / €40.00")
	assert_str(ReceiptView.margin_text(ShiftMargin.Kind.OVER, 11)).is_equal("+€11.00 OVER QUOTA")
	assert_str(ReceiptView.margin_text(ShiftMargin.Kind.SHORT, 4)).is_equal("SHORT €4.00")
	assert_str(ReceiptView.margin_text(ShiftMargin.Kind.ON, 0)).is_equal("ON QUOTA")


## The receipt's font has every glyph its lines print (the dots, the bullets, € and ×).
func test_the_font_has_the_receipts_glyphs() -> void:
	for text: String in [
		ReceiptView.WAITING_DOTS, ReceiptView.TOTAL_WAITING, ReceiptView.HEADER_TEXT, "€×+="
	]:
		for index: int in range(text.length()):
			(
				assert_bool(ReceiptView.MONO_FONT.has_char(text.unicode_at(index)))
				. override_failure_message(text[index])
				. is_true()
			)


## The planning footer's two labels: the count, then where to read them; one fizzle and many.
func test_the_fizzle_footer_words_one_and_many() -> void:
	for pair: Array in [[1, "1 fizzle |  · hover an item"], [2, "2 fizzles |  · hover an item"]]:
		var result: ScoreResult = _result()
		for _extra: int in range((pair[0] as int) - 1):
			result.steps.append(_step(ScoreStep.StepType.WASTED, "Coffee bonus"))
		_receipt.show_planning(PackedStringArray(HEADER), result, PackedStringArray(NAMES), 3)
		assert_str(_lines(_receipt)[-1]).is_equal(pair[1] as String)
	await _frames(1)


## Every WASTED step counts, an upgrade's too; nothing else does.
func test_fizzle_count_counts_every_wasted_step() -> void:
	var result: ScoreResult = ScoreResult.new()
	assert_int(ReceiptView.fizzle_count(result)).is_equal(0)
	result.steps.append(_step(ScoreStep.StepType.WASTED, "Coffee bonus"))
	result.steps.append(_step(ScoreStep.StepType.FLAT, "Coffee bonus"))
	var upgrade: ScoreStep = _step(ScoreStep.StepType.WASTED, "Coupon engine")
	upgrade.source_kind = ScoreStep.SourceKind.UPGRADE
	result.steps.append(upgrade)
	assert_int(ReceiptView.fizzle_count(result)).is_equal(2)


## An item's mark comes from its recorded amounts: raised when its payout is above its base (that
## wins, as on its belt ticket), fizzled when a WASTED step is on it, none otherwise.
func test_slot_marks_read_the_recorded_amounts() -> void:
	var result: ScoreResult = _result()
	assert_int(ReceiptView.slot_mark(result, 0)).is_equal(ReceiptView.Mark.NONE)
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.RAISED)
	assert_int(ReceiptView.slot_mark(result, 2)).is_equal(ReceiptView.Mark.FIZZLED)
	assert_int(ReceiptView.slot_mark(result, 5)).is_equal(ReceiptView.Mark.NONE)
	# Slot 1 also fizzles a condition of its own (#45): it was still raised, so it keeps the check.
	var waste: ScoreStep = _step(ScoreStep.StepType.WASTED, "Cheese after Bread")
	waste.slot = 1
	waste.source_slot = 1
	result.steps.append(waste)
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.RAISED)


## The itemised planning receipt: header, dashed rule, the items with their payouts and marks,
## the open slots waiting, dashed rule, PROJECTED, the footer; every line on one row inside the
## lines' width, every mark inside the receipt and right of its line.
func test_the_planning_receipt_is_itemised() -> void:
	_receipt.show_planning(PackedStringArray(HEADER), _result(), PackedStringArray(NAMES), 5)
	await _frames(2)
	(
		assert_array(_lines(_receipt))
		. is_equal(
			[
				"NEXT CUSTOMER · REG 3 | ",
				"SHIFT 5/8 · 4 ITEMS | ",
				"---",
				"Milk | €2.00",
				"Bread | €5.00",
				"Coffee | €1.00",
				"4 ····· | ",
				"5 ····· | ",
				"---",
				"PROJECTED | €8.00",
				"1 fizzle |  · hover an item",
			]
		)
	)
	assert_array(_marks(_receipt)).is_equal(
		[ReceiptView.Mark.NONE, ReceiptView.Mark.RAISED, ReceiptView.Mark.FIZZLED]
	)
	var paper: Rect2 = _receipt.get_global_rect()
	for line: Node in _receipt._lines.get_children():
		var rect: Rect2 = (line as Control).get_global_rect()
		assert_float((line as Control).get_rect().end.x).is_less_equal(_receipt._lines.size.x)
		assert_bool(paper.encloses(rect)).override_failure_message(str(rect)).is_true()
		if line is HBoxContainer:
			assert_int((line.get_child(0) as Label).get_line_count()).is_equal(1)
			var mark: Control = line.get_child(1).get_node_or_null("Mark") as Control
			if mark != null:
				var mark_rect: Rect2 = mark.get_global_rect()
				(
					assert_bool(paper.encloses(mark_rect))
					. override_failure_message(str(mark_rect))
					. is_true()
				)
				# In the line's mark column: past its amount by B2's gap, at the line's end.
				var amount: Label = line.get_child(1) as Label
				var text_end: float = amount.get_global_rect().end.x - ReceiptView.MARK_COLUMN
				assert_float(mark_rect.position.x).is_greater_equal(text_end + 6.0 - 0.5)
				assert_float(mark_rect.end.x).is_equal_approx(rect.end.x, 0.5)
				assert_float(mark_rect.get_center().y).is_equal_approx(rect.get_center().y, 1.0)
	# The dashed rules run across the lines' width, the mark column included.
	for rule: Node in _receipt._lines.get_children():
		if rule is HSeparator:
			assert_float((rule as Control).size.x).is_equal_approx(_receipt._lines.size.x, 0.5)
	# No TOTAL line: the dessert never lands on the planning receipt.
	assert_object(_receipt.total_label()).is_null()
	# Without fizzles, no footer.
	var clean: ScoreResult = _result()
	clean.steps = clean.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type != ScoreStep.StepType.WASTED
	)
	_receipt.show_planning(PackedStringArray(HEADER), clean, PackedStringArray(NAMES), 3)
	assert_str(_lines(_receipt)[-1]).is_equal("PROJECTED | €8.00")
	await _frames(1)


## Against the quota (#71's play test): PROJECTED's amount is Palette.GOOD with the met mark (the
## belt's mark_check disc, in the mark column, centred on the line) at the quota and over it, with
## no footer for a clean row; under it, Palette.TOMATO with no mark and the shortfall ("short
## €1.00", dark tomato) on the footer's first row, before the fizzle footer; without a quota it
## stays ink. Every footer row stays one line inside the stub's width, even with a long hover hint.
func test_the_projected_total_reads_against_the_quota() -> void:
	var clean: ScoreResult = _result()
	clean.steps = clean.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type != ScoreStep.StepType.WASTED
	)
	var paper: Rect2 = _receipt.get_global_rect()
	for quota: int in [8, 5, 0]:
		_receipt.show_planning(PackedStringArray(HEADER), clean, PackedStringArray(NAMES), 3, quota)
		await _frames(2)
		var projected: HBoxContainer = _projected(_receipt)
		assert_that(_color(projected, 1)).is_equal(Palette.GOOD)
		var mark: TextureRect = projected.get_child(1).get_node_or_null("Mark") as TextureRect
		assert_object(mark).is_not_null()
		assert_int(mark.get_meta("mark") as int).is_equal(ReceiptView.Mark.MET)
		assert_object(mark.texture).is_same(ReceiptDecor.CHECK_DISC)
		var mark_rect: Rect2 = mark.get_global_rect()
		var line_rect: Rect2 = projected.get_global_rect()
		assert_bool(paper.encloses(mark_rect)).override_failure_message(str(mark_rect)).is_true()
		assert_float(mark_rect.end.x).is_equal_approx(line_rect.end.x, 0.5)
		assert_float(mark_rect.get_center().y).is_equal_approx(line_rect.get_center().y, 1.0)
		var amount: Label = projected.get_child(1) as Label
		var text_end: float = amount.get_global_rect().end.x - ReceiptView.MARK_COLUMN
		assert_float(mark_rect.position.x).is_greater_equal(text_end + 6.0 - 0.5)
		assert_str(_lines(_receipt)[-1]).is_equal("PROJECTED | €8.00")
	var cases: Array[Array] = [
		[_result(), 9, ["short €1.00 | ", "1 fizzle |  · hover an item"]],
		[clean, 20, ["short €12.00 | "]],
	]
	for case: Array in cases:
		var result: ScoreResult = case[0] as ScoreResult
		var quota: int = case[1] as int
		_receipt.show_planning(
			PackedStringArray(HEADER), result, PackedStringArray(NAMES), 3, quota
		)
		await _frames(2)
		var projected: HBoxContainer = _projected(_receipt)
		assert_that(_color(projected, 1)).is_equal(Palette.TOMATO)
		assert_object(projected.get_child(1).get_node_or_null("Mark")).is_null()
		var tail: Array[String] = _lines(_receipt)
		tail = tail.slice(tail.find("PROJECTED | €8.00") + 1)
		assert_array(tail).is_equal(case[2] as Array)
		# A long hint is cut, never wrapped or widening the stub.
		_receipt.show_relations(-1, {}, ReceiptView.HOVERED_HINT % "Squashed cake")
		await _frames(2)
		var rows: Array[Node] = _receipt._lines.get_children()
		rows = rows.slice(rows.find(projected) + 1)
		assert_int(rows.size()).is_equal(tail.size())
		for row: Node in rows:
			var footer: HBoxContainer = row as HBoxContainer
			assert_that(_color(footer, 0)).is_equal(Palette.TOMATO_DARK)
			assert_int((footer.get_child(0) as Label).get_line_count()).is_equal(1)
			assert_float(footer.get_combined_minimum_size().x).is_less_equal(_receipt._lines.size.x)
			assert_float(footer.get_rect().end.x).is_less_equal(_receipt._lines.size.x + 0.5)
			for label: Node in footer.get_children():
				var rect: Rect2 = (label as Control).get_global_rect()
				assert_bool(paper.encloses(rect)).override_failure_message(str(rect)).is_true()
	# Without a quota: ink, no mark.
	_receipt.show_planning(PackedStringArray(HEADER), clean, PackedStringArray(NAMES), 3)
	await _frames(1)
	assert_that(_color(_projected(_receipt), 1)).is_equal(Palette.INK)
	assert_object(_projected(_receipt).get_child(1).get_node_or_null("Mark")).is_null()


## The planning receipt's styles: dashed rules (no solid one), PROJECTED's caption smaller than
## its amount (the total's size), waiting lines muted, the footer's count in dark tomato and the
## rest muted.
func test_the_planning_styles() -> void:
	_receipt.show_planning(PackedStringArray(HEADER), _result(), PackedStringArray(NAMES), 4)
	await _frames(2)
	var lines: Array[Node] = _receipt._lines.get_children()
	for line: Node in lines:
		if line is HSeparator:
			assert_object((line as HSeparator).get_theme_stylebox("separator")).is_instanceof(
				StyleBoxEmpty
			)
	var projected: HBoxContainer = lines[-2] as HBoxContainer
	assert_str((projected.get_child(0) as Label).text).is_equal(ReceiptView.PROJECTED_TEXT)
	assert_int(_size(projected, 0)).is_equal(ReceiptView.CAPTION_FONT_SIZE)
	assert_int(_size(projected, 1)).is_equal(ReceiptView.TOTAL_FONT_SIZE)
	assert_that(_color(lines[6] as HBoxContainer, 0)).is_equal(Palette.MUTED_INK)
	assert_that(_color(lines[3] as HBoxContainer, 1)).is_equal(Palette.INK)
	var footer: HBoxContainer = lines[-1] as HBoxContainer
	assert_that(_color(footer, 0)).is_equal(Palette.TOMATO_DARK)
	assert_that(_color(footer, 1)).is_equal(Palette.INK_LIGHT)
	# The count and the rest run on as one line, the rest right after the count.
	var count: Label = footer.get_child(0) as Label
	var rest: Label = footer.get_child(1) as Label
	assert_float(rest.position.x).is_equal_approx(count.position.x + count.size.x, 0.5)
	assert_float(footer.get_combined_minimum_size().x).is_less_equal(_receipt._lines.size.x)


## highlight_slot frames the scanned item's line in planning (none for -1); outside planning it
## does nothing.
func test_highlight_frames_a_planning_line() -> void:
	_receipt.show_planning(PackedStringArray(HEADER), _result(), PackedStringArray(NAMES), 4)
	await _frames(2)
	_receipt.highlight_slot(1)
	assert_object(_receipt._framed_line()).is_same(_receipt._items[1])
	_receipt.highlight_slot(7)
	assert_object(_receipt._framed_line()).is_null()
	_receipt.highlight_slot(2)
	assert_object(_receipt._framed_line()).is_same(_receipt._items[2])
	_receipt.highlight_slot(-1)
	assert_object(_receipt._framed_line()).is_null()
	_receipt.begin_count(PackedStringArray(HEADER), PackedStringArray(NAMES))
	_receipt.highlight_slot(1)
	assert_object(_receipt._framed_line()).is_null()
	await _frames(1)


## The count-up's receipt: pre-printed greyed lines and TOTAL with the footer; each step fills
## its item's line in or prints under its item, framed; the item's line keeps its base, and a
## payout its lines already add up to prints nothing (the item's line is framed); add_total fills
## TOTAL in plainly and drops the footer and the frame.
func test_the_count_up_fills_its_waiting_lines() -> void:
	var names: PackedStringArray = PackedStringArray(NAMES)
	_receipt.begin_count(PackedStringArray(HEADER), names)
	var waiting: Array[String] = [
		"NEXT CUSTOMER · REG 3 | ",
		"SHIFT 5/8 · 4 ITEMS | ",
		"---",
		"Milk ····· | ",
		"Bread ····· | ",
		"Coffee ····· | ",
		"---",
		"TOTAL | •••••",
		"tap: skip · hold: fast | ",
	]
	assert_array(_lines(_receipt)).is_equal(waiting)
	assert_that(_color(_receipt._items[0], 0)).is_equal(Palette.MUTED_INK)
	assert_that(_color(_receipt._total_line, 1)).is_equal(Palette.MUTED_INK)
	var result: ScoreResult = _result()
	var returned: Array[Control] = []
	for step: ScoreStep in result.steps:
		returned.append(_receipt.add_step(step, names))
		if step.step_type == ScoreStep.StepType.FLAT:
			# The bonus line under Bread is framed.
			assert_object(_receipt._framed_line()).is_same(returned[-1])
			assert_str(_lines(_receipt)[5]).is_equal("Coffee bonus | +€2.00")
			assert_str(_lines(_receipt)[4]).is_equal("Bread | €3.00")
		if step.step_type == ScoreStep.StepType.PAYOUT:
			assert_object(_receipt._framed_line()).is_same(_receipt._items[step.slot])
	# A BASE step returns its item's line; a PAYOUT step that adds up its amount label when
	# nothing printed under the item (Milk), else null (Bread: nothing new to fade in).
	assert_object(returned[0]).is_same(_receipt._items[0])
	assert_object(returned[1]).is_same(_receipt._items[0].get_child(1))
	assert_object(returned[4]).is_null()
	assert_object(_receipt._framed_line()).is_same(returned[-1])
	var total: Control = _receipt.add_total(result.total)
	assert_object(total).is_same(_receipt._total_line)
	assert_object(_receipt._framed_line()).is_null()
	await _frames(1)
	(
		assert_array(_lines(_receipt))
		. is_equal(
			[
				"NEXT CUSTOMER · REG 3 | ",
				"SHIFT 5/8 · 4 ITEMS | ",
				"---",
				"Milk | €2.00",
				"Bread | €3.00",
				"Coffee bonus | +€2.00",
				"Coffee | €1.00",
				"Coffee bonus: no Breakfast product after it | ",
				"---",
				"TOTAL | €8.00",
			]
		)
	)
	assert_that(_color(_receipt._items[0], 0)).is_equal(Palette.INK)
	assert_that(_color(_receipt._total_line, 0)).is_equal(Palette.INK)
	# The fizzle's line is dark tomato with the fizzle mark.
	var fizzle: HBoxContainer = _receipt._lines.get_child(7) as HBoxContainer
	assert_that(_color(fizzle, 0)).is_equal(Palette.TOMATO_DARK)
	var mark: Control = fizzle.get_child(1).get_node_or_null("Mark") as Control
	assert_object(mark).is_not_null()
	assert_int(int(mark.get_meta("mark"))).is_equal(ReceiptView.Mark.FIZZLED)


## Every item's lines add up (#80): when the base and the bonus lines don't come to the payout (a
## multiplier), the PAYOUT step closes the item with a small "= €payout" in ink with the mark
## column, framed, and returns its amount; a later line of the item prints above it. An
## override's "= €0.00" is the item's amount from then on, so its payout prints nothing more
## (null), and a fizzled item at €0 that adds up gets no closing line. show_result prints the
## same.
func test_an_item_that_does_not_add_up_closes_with_its_payout() -> void:
	var names: PackedStringArray = PackedStringArray(["Multipack", "Milk", "Soup"])
	var none: PackedStringArray = PackedStringArray()
	var inspections: PackedStringArray = PackedStringArray(["Spot check"])
	_receipt.begin_count(PackedStringArray(), names)
	var result: ScoreResult = _closing_result()
	var returned: Dictionary[int, Control] = {}
	for index: int in range(result.steps.size()):
		var step: ScoreStep = result.steps[index]
		returned[index] = _receipt.add_step(step, names, none, inspections)
		if index == 2:
			var closing: HBoxContainer = _receipt._lines.get_child(2) as HBoxContainer
			assert_object(returned[index]).is_same(closing.get_child(1))
			assert_object(_receipt._framed_line()).is_same(closing)
			assert_that(_color(closing, 1)).is_equal(Palette.INK)
			assert_int(_size(closing, 1)).is_equal(ReceiptView.FOOTER_FONT_SIZE)
			var column: StyleBox = (closing.get_child(1) as Label).get_theme_stylebox("normal")
			assert_float(column.content_margin_right).is_equal(ReceiptView.MARK_COLUMN)
	# Milk's override line closes it: its PAYOUT frames its line and returns nothing to fade in.
	assert_object(returned[6]).is_null()
	# The fizzled Soup adds up at €0: its PAYOUT frames its line and prints nothing.
	assert_object(returned[9]).is_same(_receipt._items[2].get_child(1))
	_receipt.add_total(result.total)
	var expected: Array[String] = [
		"Multipack | €1.00",
		"Multipack | ×3",
		"Multipack: nothing to multiply after it | ",
		" | = €3.00",
		"Milk | €2.00",
		"Spot check: the 2nd product pays €0 | = €0.00",
		"Soup | €0.00",
		"Soup bonus: no Frozen product after it | ",
		"---",
		"TOTAL | €3.00",
	]
	assert_array(_lines(_receipt)).is_equal(expected)
	var at_once: ReceiptView = auto_free(ReceiptView.new())
	at_once.show_result(result, names, none, inspections)
	assert_array(_lines(at_once)).is_equal(expected)
	await _frames(1)


## A late-run verdict ("€1118.00 / €120.00", the simulator's largest total on shift 8's
## quota) shrinks to stay on the TOTAL line: the caption on one row, the line inside the lines'
## width; a short one keeps VERDICT_FONT_SIZE.
func test_a_four_digit_verdict_stays_on_the_total_line() -> void:
	for pair: Array in [[109, 34], [1118, 120], [10000, 120]]:
		_receipt.begin_count(PackedStringArray(HEADER), PackedStringArray(NAMES))
		_receipt.add_total(pair[0] as int)
		await _frames(2)
		var label: Label = _receipt.show_verdict(pair[0] as int, pair[1] as int)
		await _frames(2)
		var line: HBoxContainer = _receipt._total_line
		assert_int((line.get_child(0) as Label).get_line_count()).is_equal(1)
		assert_float(line.get_combined_minimum_size().x).is_less_equal(_receipt._lines.size.x)
		assert_float(line.get_rect().end.x).is_less_equal(_receipt._lines.size.x)
		var font_size: int = label.get_theme_font_size("font_size")
		if pair[0] == 109:
			assert_int(font_size).is_equal(ReceiptView.VERDICT_FONT_SIZE)
		else:
			assert_int(font_size).is_less(ReceiptView.VERDICT_FONT_SIZE)


## show_result prints the count-up's receipt at once (no footer); without a header it prints
## none and no rule under it.
func test_show_result_is_the_count_ups_receipt() -> void:
	var result: ScoreResult = _result()
	var names: PackedStringArray = PackedStringArray(NAMES)
	_receipt.begin_count(PackedStringArray(HEADER), names, false)
	for step: ScoreStep in result.steps:
		_receipt.add_step(step, names)
	_receipt.add_total(result.total)
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		result, names, PackedStringArray(), PackedStringArray(), PackedStringArray(HEADER)
	)
	assert_array(_lines(_receipt)).is_equal(_lines(expected))
	expected.show_result(result, names)
	assert_str(_lines(expected)[0]).is_equal("Milk | €2.00")
	_receipt.begin()
	assert_int(_lines(_receipt).size()).is_equal(0)
	# The lines let go are freed at the frame's end.
	await _frames(1)


## The monitor's and the scan footer's step lines word a bonus as B2 does, amount first in whole
## euros; the other lines are the receipt's on one row.
func test_step_lines_word_bonuses_amount_first() -> void:
	var names: PackedStringArray = PackedStringArray(NAMES)
	var flat: ScoreStep = _step(ScoreStep.StepType.FLAT, "Category engine")
	flat.value = 15
	assert_str(ReceiptView.step_line(flat, names)).is_equal("+€15 Category engine")
	var multiplier: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, "Multipack")
	assert_str(ReceiptView.step_line(multiplier, names)).is_equal("×2 Multipack")
	# A receipt text that ends in its factor prints it once.
	multiplier.text = "Multipack ×3"
	multiplier.value = 3
	assert_str(ReceiptView.step_line(multiplier, names)).is_equal("×3 Multipack")
	assert_array(Array(ReceiptView.step_text(multiplier, names))).is_equal(["  × Multipack", "×3"])
	var upgrade: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, "Slot engine ×2")
	upgrade.source_kind = ScoreStep.SourceKind.UPGRADE
	upgrade.source_index = 0
	var upgrades: PackedStringArray = PackedStringArray(["Slot engine"])
	assert_str(ReceiptView.step_line(upgrade, names, upgrades)).is_equal("×2 Slot engine")
	var copy: ScoreStep = _step(ScoreStep.StepType.COPY, "Repeat")
	copy.linked_slot = 1
	assert_str(ReceiptView.step_line(copy, names)).is_equal("+€2 Repeat: copy of Bread")
	var wasted: ScoreStep = _step(ScoreStep.StepType.WASTED, "Coffee bonus")
	wasted.reason = "no Breakfast product after it"
	assert_str(ReceiptView.step_line(wasted, names)).is_equal(
		"Coffee bonus: no Breakfast product after it  fizzle"
	)
	assert_str(ReceiptView.step_line(_step(ScoreStep.StepType.BASE, ""), names)).is_equal("MILK  2")
	assert_str(ReceiptView.step_line(_step(ScoreStep.StepType.PAYOUT, ""), names)).is_equal("€2")
	var override: ScoreStep = _step(ScoreStep.StepType.PAYOUT_OVERRIDE, "the 3rd product pays €0")
	override.value = 0
	assert_str(ReceiptView.step_line(override, names)).is_equal("the 3rd product pays €0  = 0")


## A combo is a bonus or multiplier another item, an upgrade or an inspection caused, or a copy;
## a card's own bonus, a fizzle, a base and a payout are not.
func test_is_combo_marks_what_another_source_caused() -> void:
	var own: ScoreStep = _step(ScoreStep.StepType.FLAT, "Strawberries beside Produce")
	assert_bool(ReceiptView.is_combo(own)).is_false()
	var other: ScoreStep = _step(ScoreStep.StepType.FLAT, "Coffee bonus")
	other.source_slot = 1
	assert_bool(ReceiptView.is_combo(other)).is_true()
	var multiplier: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, "Multipack")
	multiplier.source_slot = 1
	assert_bool(ReceiptView.is_combo(multiplier)).is_true()
	var upgrade: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, "Slot engine")
	upgrade.source_kind = ScoreStep.SourceKind.UPGRADE
	assert_bool(ReceiptView.is_combo(upgrade)).is_true()
	var copy: ScoreStep = _step(ScoreStep.StepType.COPY, "Repeat")
	copy.linked_slot = 1
	assert_bool(ReceiptView.is_combo(copy)).is_true()
	for kind: ScoreStep.StepType in [
		ScoreStep.StepType.WASTED,
		ScoreStep.StepType.BASE,
		ScoreStep.StepType.PAYOUT,
		ScoreStep.StepType.PAYOUT_OVERRIDE,
		ScoreStep.StepType.TAG_ADDED,
	]:
		var step: ScoreStep = _step(kind, "Milk")
		step.source_slot = 1
		assert_bool(ReceiptView.is_combo(step)).override_failure_message(str(kind)).is_false()
	assert_int(ReceiptView.step_style(other)).is_equal(ReceiptView.LineStyle.COMBO)
	assert_int(ReceiptView.step_style(own)).is_equal(ReceiptView.LineStyle.DETAIL)


## Every combo line, not only the newest, gets the band (drawn behind the line) and the diamond
## after the bar, in place of its marker; its text, wrapped too, hangs past both. A card's own
## bonus stays a plain hung line with its "+" marker.
func test_every_combo_line_is_marked_and_hangs_past_its_diamond() -> void:
	var other: ScoreStep = _step(ScoreStep.StepType.FLAT, "Coupon engine on the first coupon of 3")
	other.source_kind = ScoreStep.SourceKind.UPGRADE
	var multiplier: ScoreStep = _step(ScoreStep.StepType.MULTIPLIER, "Multipack")
	multiplier.source_slot = 1
	var copy: ScoreStep = _step(ScoreStep.StepType.COPY, "Repeat")
	copy.linked_slot = 1
	var own: ScoreStep = _step(ScoreStep.StepType.FLAT, "Strawberries beside Produce")
	var names: PackedStringArray = PackedStringArray(["Milk", "Bread"])
	var lines: Array[Control] = []
	for step: ScoreStep in [other, multiplier, copy]:
		lines.append(_receipt.add_step(step, names))
	var plain: Control = _receipt.add_step(own, names)
	await _frames(2)
	for line: Control in lines:
		assert_bool(line.draw.get_connections().is_empty()).is_false()
		var left: Label = line.get_child(0) as Label
		var diamond: TextureRect = left.get_node_or_null("ComboDiamond") as TextureRect
		assert_object(diamond).is_not_null()
		assert_object(diamond.texture).is_same(ReceiptView.COMBO_DIAMOND)
		var icon: Rect2 = diamond.get_rect()
		(
			assert_bool(icon == ReceiptView.COMBO_ICON_RECT)
			. override_failure_message(str(icon))
			. is_true()
		)
		assert_float(icon.position.x).is_greater_equal(ReceiptView.COMBO_BAR)
		assert_float(icon.end.x).is_less_equal(ReceiptView.COMBO_INDENT)
		assert_float(icon.end.y).is_less_equal(line.size.y)
		var indent: float = left.get_theme_stylebox("normal").content_margin_left
		assert_float(indent).is_equal(ReceiptView.COMBO_INDENT)
		assert_float(left.get_character_bounds(0).position.x).is_equal_approx(indent, 1.0)
		assert_object(left.get_node_or_null("Marker")).is_null()
		# The whole line stays inside the receipt's lines.
		assert_float(line.get_rect().end.x).is_less_equal(_receipt._lines.size.x)
	# The long upgrade line wraps, every row hung past the diamond.
	var wrapped: Label = lines[0].get_child(0) as Label
	assert_int(wrapped.get_line_count()).is_greater(1)
	assert_str((lines[0].get_child(1) as Label).text).is_equal("+€2.00")
	assert_str((lines[2].get_child(0) as Label).text).is_equal("Repeat: copy of Bread")
	var own_left: Label = plain.get_child(0) as Label
	assert_object(own_left.get_node_or_null("ComboDiamond")).is_null()
	assert_object(own_left.get_node_or_null("Marker")).is_not_null()
	assert_bool(plain.draw.get_connections().is_empty()).is_true()


## A combo line just printed is the framed one, and drops its band and bar while framed (B2:
## the frame's mustard-pale fill and mustard frame alone, its diamond kept); the next line
## printed takes the frame, and the band comes back.
func test_a_framed_combo_line_shows_the_frame_alone() -> void:
	var names: PackedStringArray = PackedStringArray(["Milk", "Bread"])
	var bonus: ScoreStep = _step(ScoreStep.StepType.FLAT, "Category engine")
	bonus.source_kind = ScoreStep.SourceKind.UPGRADE
	var combo: Control = _receipt.add_step(bonus, names)
	assert_object(_receipt._framed_line()).is_same(combo)
	assert_bool(combo.get_meta("framed", false)).is_true()
	assert_object(combo.get_child(0).get_node_or_null("ComboDiamond")).is_not_null()
	var next: Control = _receipt.add_step(_step(ScoreStep.StepType.FLAT, "Own bonus"), names)
	assert_object(_receipt._framed_line()).is_same(next)
	assert_bool(combo.get_meta("framed", true)).is_false()
	_receipt.add_total(4)
	assert_bool(next.get_meta("framed", true)).is_false()


## The raised mark's check is B2's small thin tick: at most 9 px tall, inside the mark, its
## strokes no more than three pixels across on any row.
func test_the_check_is_b2s_small_tick() -> void:
	var check: Vector2 = ReceiptDecor.check_size()
	assert_float(check.y).is_between(6.0, 9.0)
	assert_float(check.x).is_less_equal(ReceiptDecor.MARK_RECT.size.x)
	assert_float(check.y).is_less_equal(ReceiptDecor.MARK_RECT.size.y)
	for row: String in ReceiptDecor.CHECK_ROWS:
		assert_int(row.length()).is_equal(int(check.x))
		assert_int(row.count("#")).is_greater(0)
		for run: String in row.split(".", false):
			assert_int(run.length()).is_less_equal(3)


static func _step(type: ScoreStep.StepType, text: String) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = 0
	step.source_slot = 0
	step.value = 2
	step.text = text
	return step


## Milk (2), Bread (base 3, +2 from Milk's Coffee bonus: 5), Coffee (1) whose bonus fizzles; the
## steps in the scoring's order, total 8.
static func _result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	var rows: Array[Array] = [
		[0, ScoreStep.StepType.BASE, 2, ""],
		[0, ScoreStep.StepType.PAYOUT, 2, ""],
		[1, ScoreStep.StepType.BASE, 3, ""],
		[1, ScoreStep.StepType.FLAT, 2, "Coffee bonus"],
		[1, ScoreStep.StepType.PAYOUT, 5, ""],
		[2, ScoreStep.StepType.BASE, 1, ""],
		[2, ScoreStep.StepType.PAYOUT, 1, ""],
		[2, ScoreStep.StepType.WASTED, 0, "Coffee bonus"],
	]
	for row: Array in rows:
		var step: ScoreStep = _step(row[1] as ScoreStep.StepType, row[3] as String)
		step.slot = row[0] as int
		step.source_slot = step.slot
		step.value = row[2] as int
		result.steps.append(step)
	result.steps[3].source_slot = 0
	result.steps[7].reason = "no Breakfast product after it"
	result.payouts = PackedInt32Array([2, 5, 1])
	result.total = 8
	return result


## Multipack (base 1, ×3: 3) whose second multiplier fizzles after its payout, Milk (2) that the
## Spot check sets to €0, and Soup (0) whose bonus fizzles; total 3.
static func _closing_result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	var rows: Array[Array] = [
		[0, ScoreStep.StepType.BASE, 1, ""],
		[0, ScoreStep.StepType.MULTIPLIER, 3, "Multipack"],
		[0, ScoreStep.StepType.PAYOUT, 3, ""],
		[0, ScoreStep.StepType.WASTED, 0, "Multipack"],
		[1, ScoreStep.StepType.BASE, 2, ""],
		[1, ScoreStep.StepType.PAYOUT_OVERRIDE, 0, "the 2nd product pays €0"],
		[1, ScoreStep.StepType.PAYOUT, 0, ""],
		[2, ScoreStep.StepType.BASE, 0, ""],
		[2, ScoreStep.StepType.EFFECT_ARMED, 3, "Soup bonus"],
		[2, ScoreStep.StepType.PAYOUT, 0, ""],
		[2, ScoreStep.StepType.WASTED, 0, "Soup bonus"],
	]
	for row: Array in rows:
		var step: ScoreStep = _step(row[1] as ScoreStep.StepType, row[3] as String)
		step.slot = row[0] as int
		step.source_slot = step.slot
		step.value = row[2] as int
		result.steps.append(step)
	result.steps[3].reason = "nothing to multiply after it"
	result.steps[5].source_kind = ScoreStep.SourceKind.INSPECTION
	result.steps[5].source_index = 0
	result.steps[10].reason = "no Frozen product after it"
	result.payouts = PackedInt32Array([3, 0, 0])
	result.total = 3
	return result


## Each item line's mark (NONE without one), in slot order.
static func _marks(receipt: ReceiptView) -> Array[ReceiptView.Mark]:
	var marks: Array[ReceiptView.Mark] = []
	for slot: int in range(receipt._items.size()):
		var mark: Node = receipt._items[slot].get_child(1).get_node_or_null("Mark")
		marks.append(
			ReceiptView.Mark.NONE if mark == null else mark.get_meta("mark") as ReceiptView.Mark
		)
	return marks


## The PROJECTED line, or null.
static func _projected(receipt: ReceiptView) -> HBoxContainer:
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer and not line.is_queued_for_deletion():
			if (line.get_child(0) as Label).text == ReceiptView.PROJECTED_TEXT:
				return line as HBoxContainer
	return null


static func _size(line: HBoxContainer, index: int) -> int:
	return (line.get_child(index) as Label).get_theme_font_size("font_size")


static func _color(line: HBoxContainer, index: int) -> Color:
	return (line.get_child(index) as Label).get_theme_color("font_color")


## A receipt's lines as text ("left | right"; "---" for a rule).
static func _lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line.is_queued_for_deletion():
			continue
		if line is HSeparator:
			lines.append("---")
			continue
		var texts: PackedStringArray = PackedStringArray()
		for label: Node in line.get_children():
			texts.append((label as Label).text)
		lines.append(" | ".join(texts))
	return lines


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
