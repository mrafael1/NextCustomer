extends GdUnitTestSuite
## ReceiptView's planning receipt, count-up lines, header and combo lines (#75, #80). Planning
## (show_planning) is itemised: the header, a dashed rule, one line per item (name, payout with
## cents, its mark: the fizzle icon when it fizzles, no check), "n ·····" per open empty slot, a
## dashed rule, then PROJECTED at the left and its amount at the right, centred on the caption's
## line (given the quota, how far it is on its own row under the amount: "+3.00€ over" in green,
## "1.00€ short" in red), and no fizzle footer (the PR #138 left UI: the fizzles show on their
## lines' marks); highlight_slot frames a line (planning only).
## The count-up (begin_count) prints the header and its footer only; the steps print line by line
## (#105 piece 2): an item's line with its base, then its lines under it, the newest framed; an item
## whose lines don't add up to its payout closes with "= 3.00€"; add_total prints the dashed rule
## and TOTAL at the end and drops the footer and the frame; show_result prints the same receipt at
## once. Every bonus, multiplier or copy another source caused is a combo line, marked by a gold
## band and a diamond in place of its marker. The receipt is laid out on its own, at the shift
## screen's width. No saves, no event log.

const RECEIPT_SIZE := Vector2(ShiftStage.RECEIPT_WIDTH, 600)
const HEADER: Array[String] = ["SHIFT 5/8 · 4 ITEMS"]
const NAMES: Array[String] = ["Milk", "Bread", "Coffee"]

var _receipt: ReceiptView
var _folder: String = ""


func before_test() -> void:
	# Saves and logs go to a temporary folder, never the real user:// ones.
	_folder = "user://test_receipt_stub_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	add_child(_receipt)
	_receipt.size = RECEIPT_SIZE


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_header_counts_the_shift_and_every_item() -> void:
	assert_array(Array(ReceiptView.header_lines(5, 8, 4))).is_equal(HEADER)
	assert_array(Array(ReceiptView.header_lines(1, 10, 1))).is_equal(["SHIFT 1/10 · 1 ITEM"])
	assert_array(Array(ReceiptView.header_lines(1, 10, 0))).is_equal(["SHIFT 1/10 · 0 ITEMS"])


## Every money amount on the receipt prints with cents; the values stay whole euros.
func test_money_prints_cents() -> void:
	assert_str(ReceiptView.money(3)).is_equal("3.00€")
	assert_str(ReceiptView.money(22)).is_equal("22.00€")
	assert_str(ReceiptView.money(15, true)).is_equal("+15.00€")
	assert_str(ReceiptView.money(0)).is_equal("0.00€")
	assert_str(ReceiptView.verdict_text(51, 40)).is_equal("51.00€ / 40.00€")
	assert_str(ReceiptTarget.margin_text(ShiftMargin.Kind.OVER, 11)).is_equal("+11.00€ OVER TARGET")
	assert_str(ReceiptTarget.margin_text(ShiftMargin.Kind.SHORT, 4)).is_equal("SHORT 4.00€")
	assert_str(ReceiptTarget.margin_text(ShiftMargin.Kind.ON, 0)).is_equal("ON TARGET")
	# The receipt's font has every glyph its lines print (the dots, the bullets, € and ×; one test
	# with the amounts' words, so the suite stays at gdlint's 20 public methods).
	for text: String in [HEADER[0], "€×+="]:
		for index: int in range(text.length()):
			(
				assert_bool(ReceiptView.MONO_FONT.has_char(text.unicode_at(index)))
				. override_failure_message(text[index])
				. is_true()
			)


## No fizzle footer (the PR #138 left UI): with one fizzle or many, the receipt ends on PROJECTED
## (or its line against the quota) and each fizzled item keeps its mark.
func test_fizzles_print_no_footer() -> void:
	for count: int in [1, 2]:
		var result: ScoreResult = _result()
		for _extra: int in range(count - 1):
			result.steps.append(_step(ScoreStep.StepType.WASTED, "Coffee bonus"))
		_receipt.show_planning(PackedStringArray(HEADER), result, PackedStringArray(NAMES), 3)
		assert_str(_lines(_receipt)[-1]).is_equal("PROJECTED | 8.00€")
		assert_object(_receipt._footer).is_null()
		assert_int(_marks(_receipt)[2]).is_equal(ReceiptView.Mark.FIZZLED)
		_receipt.show_planning(PackedStringArray(HEADER), result, PackedStringArray(NAMES), 3, 9)
		assert_str(_lines(_receipt)[-1]).is_equal(" | 1.00€ short")
		for text: String in _lines(_receipt):
			assert_str(text).not_contains(EffectLink.WASTED_WORD)
	await _frames(1)


## An item's mark comes from its recorded amounts: fizzled when a WASTED step of its own is on it
## (even when its payout is raised), none otherwise: a raised item gets no check.
func test_slot_marks_read_the_recorded_amounts() -> void:
	var result: ScoreResult = _result()
	assert_int(ReceiptView.slot_mark(result, 0)).is_equal(ReceiptView.Mark.NONE)
	# Slot 1 is raised (its payout is above its base): no mark.
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.NONE)
	assert_int(ReceiptView.slot_mark(result, 2)).is_equal(ReceiptView.Mark.FIZZLED)
	assert_int(ReceiptView.slot_mark(result, 5)).is_equal(ReceiptView.Mark.NONE)
	# Slot 1 also fizzles a condition of its own (#45): raised or not, it shows the fizzle icon.
	var waste: ScoreStep = _step(ScoreStep.StepType.WASTED, "Cheese after Bread")
	waste.slot = 1
	waste.source_slot = 1
	result.steps.append(waste)
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.FIZZLED)
	# An upgrade's row-wide fizzle (#45: the Slot engine with too few cards) on a slot is not
	# that item's: Milk keeps no mark. An upgrade's fizzle on its own target (the first coupon
	# paid nothing) still marks it.
	var row_waste: ScoreStep = _step(ScoreStep.StepType.WASTED, "Slot engine")
	row_waste.source_kind = ScoreStep.SourceKind.UPGRADE
	row_waste.row_wide = true
	result.steps.append(row_waste)
	assert_int(ReceiptView.slot_mark(result, 0)).is_equal(ReceiptView.Mark.NONE)
	var own_waste: ScoreStep = _step(ScoreStep.StepType.WASTED, "Coupon engine")
	own_waste.source_kind = ScoreStep.SourceKind.UPGRADE
	result.steps.append(own_waste)
	assert_int(ReceiptView.slot_mark(result, 0)).is_equal(ReceiptView.Mark.FIZZLED)


## The itemised planning receipt: header, dashed rule, the items with their payouts and marks,
## the open slots waiting, dashed rule, PROJECTED (no footer); every line on one row inside the
## lines' width, every mark inside the receipt and right of its line.
func test_the_planning_receipt_is_itemised() -> void:
	_receipt.show_planning(PackedStringArray(HEADER), _result(), PackedStringArray(NAMES), 5)
	await _frames(2)
	(
		assert_array(_lines(_receipt))
		. is_equal(
			[
				"SHIFT 5/8 · 4 ITEMS | ",
				"---",
				"Milk | 2.00€",
				"Bread | 5.00€",
				"Coffee | 1.00€",
				"4 ····· | ",
				"5 ····· | ",
				"---",
				"PROJECTED | 8.00€",
			]
		)
	)
	assert_array(_marks(_receipt)).is_equal(
		[ReceiptView.Mark.NONE, ReceiptView.Mark.NONE, ReceiptView.Mark.FIZZLED]
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
	# Without fizzles, the same foot.
	var clean: ScoreResult = _result()
	clean.steps = clean.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type != ScoreStep.StepType.WASTED
	)
	_receipt.show_planning(PackedStringArray(HEADER), clean, PackedStringArray(NAMES), 3)
	assert_str(_lines(_receipt)[-1]).is_equal("PROJECTED | 8.00€")
	await _frames(1)


## Against the quota (#71's play test; the target since the shift scene polish): PROJECTED's
## caption at the lines' left and its amount at their right, both ink (the PR #138 left UI), with
## no mark (no check), the bold amount centred on the caption's line (half above it, half below);
## the row under it says how far over ("+3.00€ over", "on target", green dark) or short ("1.00€
## short", tomato), right-aligned under the amount, inside the paper, on one line; no footer
## follows, with fizzles or without. Without a quota there is no such row.
func test_the_projected_total_reads_against_the_quota() -> void:
	var clean: ScoreResult = _result()
	clean.steps = clean.steps.filter(
		func(step: ScoreStep) -> bool: return step.step_type != ScoreStep.StepType.WASTED
	)
	var paper: Rect2 = _receipt.get_global_rect()
	var cases: Array[Array] = [
		[clean, 8, Palette.GREEN_DARK],
		[clean, 5, Palette.GREEN_DARK],
		[clean, 0, Palette.GREEN_DARK],
		[_result(), 9, Palette.TOMATO],
		[clean, 20, Palette.TOMATO],
	]
	for case: Array in cases:
		var quota: int = case[1] as int
		_receipt.show_planning(
			PackedStringArray(HEADER), case[0] as ScoreResult, PackedStringArray(NAMES), 3, quota
		)
		await _frames(2)
		var projected: HBoxContainer = _projected(_receipt)
		assert_that(_color(projected, 0)).is_equal(Palette.INK)
		assert_that(_color(projected, 1)).is_equal(Palette.INK)
		_assert_spread(projected)
		_assert_centred_on_caption(projected)
		assert_object(projected.get_child(1).get_node_or_null("Mark")).is_null()
		assert_int(projected.get_child(1).get_child_count()).is_equal(0)
		var amount: Rect2 = (projected.get_child(1) as Control).get_global_rect()
		assert_bool(paper.encloses(amount)).override_failure_message(str(amount)).is_true()
		var tail: Array[String] = _lines(_receipt)
		tail = tail.slice(tail.find("PROJECTED | 8.00€") + 1)
		assert_array(tail).is_equal([" | " + ReceiptTarget.against_text(8, quota)])
		var against: HBoxContainer = _receipt._lines.get_children()[-1] as HBoxContainer
		assert_str(against.name).is_equal("Against")
		assert_that(_color(against, 1)).is_equal(case[2] as Color)
		var words_label: Label = against.get_child(1) as Label
		assert_int(words_label.get_line_count()).is_equal(1)
		var words: Rect2 = words_label.get_global_rect()
		assert_bool(paper.encloses(words)).override_failure_message(str(words)).is_true()
		var words_width: float = ReceiptView.text_width(
			words_label.text,
			words_label.get_theme_font("font"),
			words_label.get_theme_font_size("font_size")
		)
		assert_float(words_width).is_less_equal(words.size.x + 0.5)
		_assert_under_the_number(projected, words_label)
	assert_str(ReceiptTarget.against_text(8, 8)).is_equal("on target")
	assert_str(ReceiptTarget.against_text(8, 5)).is_equal("+3.00€ over")
	assert_str(ReceiptTarget.against_text(8, 9)).is_equal("1.00€ short")
	# Without a quota: ink, spread, no mark, nothing under it.
	_receipt.show_planning(PackedStringArray(HEADER), clean, PackedStringArray(NAMES), 3)
	await _frames(2)
	assert_that(_color(_projected(_receipt), 1)).is_equal(Palette.INK)
	_assert_spread(_projected(_receipt))
	_assert_centred_on_caption(_projected(_receipt))
	assert_object(_projected(_receipt).get_child(1).get_node_or_null("Mark")).is_null()
	assert_str(_lines(_receipt)[-1]).is_equal("PROJECTED | 8.00€")


## The planning receipt's styles: dashed rules (no solid one), PROJECTED's caption smaller than
## its amount (bold, PROJECTED_FONT_SIZE), waiting lines muted, and PROJECTED the last line (no
## fizzle footer, though slot 2 fizzles).
func test_the_planning_styles() -> void:
	_receipt.show_planning(PackedStringArray(HEADER), _result(), PackedStringArray(NAMES), 4)
	await _frames(2)
	var lines: Array[Node] = _receipt._lines.get_children()
	for line: Node in lines:
		if line is HSeparator:
			assert_object((line as HSeparator).get_theme_stylebox("separator")).is_instanceof(
				StyleBoxEmpty
			)
	var projected: HBoxContainer = lines[-1] as HBoxContainer
	assert_str((projected.get_child(0) as Label).text).is_equal(ReceiptView.PROJECTED_TEXT)
	assert_int(_size(projected, 0)).is_equal(ReceiptView.CAPTION_FONT_SIZE)
	assert_int(_size(projected, 1)).is_equal(ReceiptView.PROJECTED_FONT_SIZE)
	assert_bool(ReceiptInk.is_bold(projected.get_child(1) as Label)).is_true()
	assert_that(_color(lines[5] as HBoxContainer, 0)).is_equal(Palette.MUTED_INK)
	assert_that(_color(lines[2] as HBoxContainer, 1)).is_equal(Palette.INK)
	assert_object(_receipt._footer).is_null()


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


## The count-up's receipt prints line by line (#105 piece 2): at first only the header and the
## footer (no waiting lines, no TOTAL); each step prints its item's line (the base) or a line under
## its item, framed; the item's line keeps its base, and a payout its lines already add up to
## prints nothing (the item's line is framed); add_total prints the rule and TOTAL plainly at the
## end and drops the footer and the frame.
func test_the_count_up_prints_line_by_line() -> void:
	var names: PackedStringArray = PackedStringArray(NAMES)
	_receipt.begin_count(PackedStringArray(HEADER), names)
	var first: Array[String] = [
		"SHIFT 5/8 · 4 ITEMS | ",
		"---",
		"tap: skip · hold: fast | ",
	]
	assert_array(_lines(_receipt)).is_equal(first)
	assert_object(_receipt._items.get(0)).is_null()
	var result: ScoreResult = _result()
	var returned: Array[Control] = []
	for step: ScoreStep in result.steps:
		returned.append(_receipt.add_step(step, names))
		if step.step_type == ScoreStep.StepType.FLAT:
			# The bonus line under Bread is framed.
			assert_object(_receipt._framed_line()).is_same(returned[-1])
			assert_str(_lines(_receipt)[4]).is_equal("Coffee bonus | +2.00€")
			assert_str(_lines(_receipt)[3]).is_equal("Bread | 3.00€")
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
				"SHIFT 5/8 · 4 ITEMS | ",
				"---",
				"Milk | 2.00€",
				"Bread | 3.00€",
				"Coffee bonus | +2.00€",
				"Coffee | 1.00€",
				"Coffee bonus: no Breakfast item after it | ",
				"---",
				"TOTAL | 8.00€",
			]
		)
	)
	assert_that(_color(_receipt._items[0], 0)).is_equal(Palette.INK)
	assert_that(_color(_receipt._total_line, 0)).is_equal(Palette.INK)
	# The fizzle's line is dark tomato with the fizzle mark.
	var fizzle: HBoxContainer = _receipt._lines.get_child(6) as HBoxContainer
	assert_that(_color(fizzle, 0)).is_equal(Palette.TOMATO_DARK)
	var mark: Control = fizzle.get_child(1).get_node_or_null("Mark") as Control
	assert_object(mark).is_not_null()
	assert_int(int(mark.get_meta("mark"))).is_equal(ReceiptView.Mark.FIZZLED)


## Every item's lines add up (#80): when the base and the bonus lines don't come to the payout (a
## multiplier), the PAYOUT step closes the item with a small "= payout€" in ink with the mark
## column, framed, and returns its amount; a later line of the item prints above it. An
## override's "= 0.00€" is the item's amount from then on, so its payout prints nothing more
## (null), and a fizzled item at 0€ that adds up gets no closing line. An armed effect prints
## its arm line after its item's payout (its words: the rule's text without its card). show_result
## prints the same.
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
	# The fizzled Soup adds up at 0€: its PAYOUT frames its line and prints nothing.
	assert_object(returned[8]).is_same(_receipt._items[2].get_child(1))
	assert_bool(ReceiptInk.is_arm(returned[9])).is_true()
	_receipt.add_total(result.total)
	var expected: Array[String] = [
		"Multipack | 1.00€",
		"Multipack | ×3",
		"Multipack: nothing to multiply after it | ",
		" | = 3.00€",
		"Milk | 2.00€",
		"Spot check: the 2nd product pays 0€ | = 0.00€",
		"Soup | 0.00€",
		"arms Soup bonus | ",
		"Soup bonus: no Frozen item after it | ",
		"---",
		"TOTAL | 3.00€",
	]
	assert_array(_lines(_receipt)).is_equal(expected)
	var at_once: ReceiptView = auto_free(ReceiptView.new())
	at_once.show_result(result, names, none, inspections)
	assert_array(_lines(at_once)).is_equal(expected)
	await _frames(1)


## A late-run verdict ("1118.00€ / 120.00€", the simulator's largest total on shift 8's
## quota) stays on the TOTAL line, shrinking when it must (a 5-digit one does): the caption on
## one row, the line inside the lines' width; a short one keeps VERDICT_FONT_SIZE.
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
		elif pair[0] == 10000:
			assert_int(font_size).is_less(ReceiptView.VERDICT_FONT_SIZE)
		else:
			# The shift scene polish's wider receipt may fit it whole.
			assert_int(font_size).is_less_equal(ReceiptView.VERDICT_FONT_SIZE)


## show_result prints the count-up's receipt at once (no footer); without a header it prints
## none and no rule under it. A tag on a later item printed first keeps the items in scan order.
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
	assert_str(_lines(expected)[0]).is_equal("Milk | 2.00€")
	_receipt.begin()
	assert_int(_lines(_receipt).size()).is_equal(0)
	# The lines let go are freed at the frame's end.
	await _frames(1)
	await _assert_a_later_items_tag_keeps_the_scan_order()


## A context-pass step on a later item (a tag Milk's coupon gives Coffee) prints before any base:
## its item's line still goes in scan order, under the earlier items' groups, with the tag line
## under it, in the count and in show_result (a resumed checkout).
func _assert_a_later_items_tag_keeps_the_scan_order() -> void:
	var names: PackedStringArray = PackedStringArray(NAMES)
	var result: ScoreResult = _result()
	var tag: ScoreStep = _step(ScoreStep.StepType.TAG_ADDED, "Clearance tag")
	tag.slot = 2
	tag.tag = "Clearance"
	result.steps.insert(0, tag)
	for receipt: ReceiptView in [_receipt, auto_free(ReceiptView.new()) as ReceiptView]:
		if receipt == _receipt:
			receipt.begin_count(PackedStringArray(), names, false)
			for step: ScoreStep in result.steps:
				receipt.add_step(step, names)
			receipt.add_total(result.total)
		else:
			receipt.show_result(result, names)
		var milk: int = receipt._items[0].get_index()
		var bread: int = receipt._items[1].get_index()
		var coffee: int = receipt._items[2].get_index()
		assert_int(milk).is_less(bread)
		assert_int(bread).is_less(coffee)
		var lines: Array[String] = _lines(receipt)
		assert_str(lines[coffee]).is_equal("Coffee | 1.00€")
		assert_str(lines[coffee + 1]).is_equal("Clearance tag: Coffee gains Clearance | ")
		assert_str(lines[-1]).is_equal("TOTAL | 8.00€")
	await _frames(1)


## The monitor's and the scan footer's step lines word a bonus as B2 does, amount first in whole
## euros; the other lines are the receipt's on one row.
func test_step_lines_word_bonuses_amount_first() -> void:
	var names: PackedStringArray = PackedStringArray(NAMES)
	var flat: ScoreStep = _step(ScoreStep.StepType.FLAT, "Category engine")
	flat.value = 15
	assert_str(ReceiptView.step_line(flat, names)).is_equal("+15€ Category engine")
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
	assert_str(ReceiptView.step_line(copy, names)).is_equal("Copied from Bread  2€")
	var wasted: ScoreStep = _step(ScoreStep.StepType.WASTED, "Coffee bonus")
	wasted.reason = "no Breakfast item after it"
	assert_str(ReceiptView.step_line(wasted, names)).is_equal(
		"Coffee bonus: no Breakfast item after it  WASTED"
	)
	assert_str(ReceiptView.step_line(_step(ScoreStep.StepType.BASE, ""), names)).is_equal("MILK  2")
	assert_str(ReceiptView.step_line(_step(ScoreStep.StepType.PAYOUT, ""), names)).is_equal("2€")
	var override: ScoreStep = _step(ScoreStep.StepType.PAYOUT_OVERRIDE, "the 3rd product pays 0€")
	override.value = 0
	assert_str(ReceiptView.step_line(override, names)).is_equal("the 3rd product pays 0€  = 0")


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
	assert_str((lines[0].get_child(1) as Label).text).is_equal("+2.00€")
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
	result.steps[7].reason = "no Breakfast item after it"
	result.payouts = PackedInt32Array([2, 5, 1])
	result.total = 8
	return result


## Multipack (base 1, ×3: 3) whose second multiplier fizzles after its payout, Milk (2) that the
## Spot check sets to 0€, and Soup (0) whose bonus fizzles; total 3.
static func _closing_result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	var rows: Array[Array] = [
		[0, ScoreStep.StepType.BASE, 1, ""],
		[0, ScoreStep.StepType.MULTIPLIER, 3, "Multipack"],
		[0, ScoreStep.StepType.PAYOUT, 3, ""],
		[0, ScoreStep.StepType.WASTED, 0, "Multipack"],
		[1, ScoreStep.StepType.BASE, 2, ""],
		[1, ScoreStep.StepType.PAYOUT_OVERRIDE, 0, "the 2nd product pays 0€"],
		[1, ScoreStep.StepType.PAYOUT, 0, ""],
		[2, ScoreStep.StepType.BASE, 0, ""],
		[2, ScoreStep.StepType.PAYOUT, 0, ""],
		[2, ScoreStep.StepType.EFFECT_ARMED, 3, "Soup bonus"],
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
	result.steps[10].reason = "no Frozen item after it"
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


## The PROJECTED `line` spread across the receipt's lines (the PR #138 left UI): its caption at
## their left edge, its amount right-aligned at their right edge (no mark column), the caption
## clear of the amount.
func _assert_spread(line: HBoxContainer) -> void:
	var lines: Rect2 = _receipt._lines.get_global_rect()
	var caption: Label = line.get_child(0) as Label
	var amount: Label = line.get_child(1) as Label
	var why: String = "%s %s in %s" % [caption.get_global_rect(), amount.get_global_rect(), lines]
	(
		assert_float(caption.get_global_rect().position.x)
		. override_failure_message(why)
		. is_equal_approx(lines.position.x, 0.5)
	)
	assert_int(caption.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_LEFT)
	assert_float(amount.get_global_rect().end.x).override_failure_message(why).is_equal_approx(
		lines.end.x, 0.5
	)
	assert_int(amount.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_RIGHT)
	assert_float(amount.get_theme_stylebox("normal").get_margin(SIDE_RIGHT)).is_equal(0.0)
	var text_width: float = ReceiptView.text_width(
		caption.text, caption.get_theme_font("font"), caption.get_theme_font_size("font_size")
	)
	assert_float(caption.get_global_rect().position.x + text_width).is_less_equal(
		amount.get_global_rect().end.x - amount.get_minimum_size().x
	)


## The PROJECTED `line`'s amount is centred on its caption's line (the PR #138 left UI): the
## middle of the amount's ink (its glyphs' outlines: _ink) within 1 px of the
## middle of the caption's, so half the number stands above the caption's line and half below.
func _assert_centred_on_caption(line: HBoxContainer) -> void:
	var middles: Array[float] = []
	var spans: Array[Vector2] = []
	for index: int in 2:
		var label: Label = line.get_child(index) as Label
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var shaped: TextLine = TextLine.new()
		shaped.add_string(label.text, font, font_size)
		var baseline: float = (
			label.get_global_rect().position.y
			+ label.get_theme_stylebox("normal").get_margin(SIDE_TOP)
			+ shaped.get_line_ascent()
		)
		var ink: Rect2 = _ink(label.text, font, font_size)
		middles.append(baseline + ink.get_center().y)
		spans.append(Vector2(baseline + ink.position.y, baseline + ink.end.y))
	var why: String = "caption ink %s, amount ink %s" % [spans[0], spans[1]]
	assert_float(absf(middles[0] - middles[1])).override_failure_message(why).is_less_equal(1.0)
	# The number is taller than the caption: it reaches above and below the caption's line.
	assert_float(spans[1].x).override_failure_message(why).is_less(spans[0].x)
	assert_float(spans[1].y).override_failure_message(why).is_greater(spans[0].y)


## The ink of `text` set in `font` at `font_size`: the bounds of its glyphs' outlines from the
## pen's start on the baseline (y negative above it).
static func _ink(text: String, font: Font, font_size: int) -> Rect2:
	var server: TextServer = TextServerManager.get_primary_interface()
	var ink: Rect2 = Rect2()
	var found: bool = false
	var pen: float = 0.0
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var rid: RID = font.get_rids()[0]
		var glyph: int = server.font_get_glyph_index(rid, font_size, code, 0)
		var contours: Dictionary = server.font_get_glyph_contours(rid, font_size, glyph)
		for point: Vector3 in contours.get("points", PackedVector3Array()) as PackedVector3Array:
			var at: Vector2 = Vector2(pen + point.x, point.y)
			ink = ink.expand(at) if found else Rect2(at, Vector2.ZERO)
			found = true
		pen += font.get_char_size(code, font_size).x
	return ink


## The `words` (the line against the quota) sit under the PROJECTED `line`'s amount (the PR #138
## left UI): below its bottom, right-aligned to its right edge, inside the paper's lines.
func _assert_under_the_number(line: HBoxContainer, words: Label) -> void:
	var amount: Rect2 = (line.get_child(1) as Control).get_global_rect()
	var shown: Rect2 = words.get_global_rect()
	var lines: Rect2 = _receipt._lines.get_global_rect()
	var why: String = "'%s' %s under %s" % [words.text, shown, amount]
	assert_float(shown.position.y).override_failure_message(why).is_greater_equal(
		amount.end.y - 0.5
	)
	assert_int(words.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_RIGHT)
	assert_float(shown.end.x).override_failure_message(why).is_equal_approx(amount.end.x, 0.5)
	assert_bool(lines.grow(0.5).encloses(shown)).override_failure_message(why).is_true()


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
		if not (line as CanvasItem).visible:
			continue
		if line is HSeparator:
			lines.append("---")
			continue
		var texts: PackedStringArray = PackedStringArray()
		for label: Node in line.get_children():
			texts.append(label.get_meta(ReceiptInk.WORDS_META, (label as Label).text))
		lines.append(" | ".join(texts))
	return lines


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
