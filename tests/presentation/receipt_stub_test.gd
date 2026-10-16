extends GdUnitTestSuite
## ReceiptView's planning stub, header and combo lines (#75, decision 1A): the stub prints the
## header, a dashed rule, PROJECTED and the fizzle count ("1 fizzle · see the item", "N fizzles ·
## see the items", nothing for none), then the tear; begin() and show_result() print the same
## header before the steps; every bonus, multiplier or copy another source caused is a combo line,
## marked by a gold band and a diamond, its text hung past them. The receipt is laid out on its
## own, at the shift screen's width. No saves, no event log.

const RECEIPT_SIZE := Vector2(ShiftStage.RECEIPT_WIDTH, 400)
const HEADER: Array[String] = ["NEXT CUSTOMER · REG 3", "SHIFT 5/8 · 4 ITEMS"]

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


func test_the_fizzle_line_words_one_and_many() -> void:
	assert_str(ReceiptView.fizzle_text(0)).is_empty()
	assert_str(ReceiptView.fizzle_text(1)).is_equal("1 fizzle · see the item")
	assert_str(ReceiptView.fizzle_text(2)).is_equal("2 fizzles · see the items")
	assert_str(ReceiptView.fizzle_text(11)).is_equal("11 fizzles · see the items")


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


## The stub with no, one and several fizzles: the header, the dashed rule, PROJECTED, the fizzle
## line (none without fizzles), the tear; each line on one row inside the receipt's width.
func test_the_stub_prints_the_header_projected_and_the_fizzles() -> void:
	var tear: String = ReceiptView.TEAR_PATTERN.repeat(ReceiptView.TEAR_REPEAT) + " | "
	var head: Array[String] = ["NEXT CUSTOMER · REG 3 | ", "SHIFT 5/8 · 4 ITEMS | ", "---"]
	for fizzles: int in [0, 1, 2]:
		_receipt.show_stub(PackedStringArray(HEADER), 22, fizzles)
		await _frames(2)
		var expected: Array[String] = head.duplicate()
		expected.append("PROJECTED | €22")
		if fizzles == 1:
			expected.append("1 fizzle · see the item | ")
		elif fizzles == 2:
			expected.append("2 fizzles · see the items | ")
		expected.append(tear)
		assert_array(_lines(_receipt)).is_equal(expected)
		for line: Node in _receipt._lines.get_children():
			assert_float((line as Control).get_rect().end.x).is_less_equal(_receipt._lines.size.x)
			if line is HBoxContainer:
				assert_int((line.get_child(0) as Label).get_line_count()).is_equal(1)
	# No TOTAL line: the dessert's slam never lands on the stub.
	assert_object(_receipt.total_label()).is_null()


## A dashed rule (not the TOTAL line's solid one) right above PROJECTED, at the total's size; the
## fizzle line in tomato dark.
func test_the_stub_rule_is_dashed_and_the_fizzle_line_is_red() -> void:
	_receipt.show_stub(PackedStringArray(HEADER), 22, 2)
	await _frames(2)
	var rule: HSeparator = _receipt.find_child("StubRule", true, false) as HSeparator
	assert_object(rule).is_not_null()
	assert_object(rule.get_theme_stylebox("separator")).is_instanceof(StyleBoxEmpty)
	assert_bool(rule.draw.get_connections().is_empty()).is_false()
	var projected: HBoxContainer = rule.get_parent().get_child(rule.get_index() + 1)
	assert_str((projected.get_child(0) as Label).text).is_equal(ReceiptView.PROJECTED_TEXT)
	for label: Node in projected.get_children():
		assert_int((label as Label).get_theme_font_size("font_size")).is_equal(
			ReceiptView.TOTAL_FONT_SIZE
		)
	var note: HBoxContainer = rule.get_parent().get_child(rule.get_index() + 2)
	assert_that((note.get_child(0) as Label).get_theme_color("font_color")).is_equal(
		Palette.TOMATO_DARK
	)


## begin() starts over under the header; show_result() prints the same header, then the steps and
## the total; without a header both print none.
func test_begin_and_show_result_print_the_same_header() -> void:
	var result: ScoreResult = _result()
	var names: PackedStringArray = PackedStringArray(["Milk", "Bread"])
	_receipt.show_stub(PackedStringArray(HEADER), 22, 1)
	_receipt.begin(PackedStringArray(HEADER))
	for step: ScoreStep in result.steps:
		_receipt.add_step(step, names)
	_receipt.add_total(result.total)
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		result, names, PackedStringArray(), PackedStringArray(), PackedStringArray(HEADER)
	)
	assert_array(_lines(_receipt)).is_equal(_lines(expected))
	assert_array(_lines(expected).slice(0, 2)).is_equal(
		["NEXT CUSTOMER · REG 3 | ", "SHIFT 5/8 · 4 ITEMS | "]
	)
	expected.show_result(result, names)
	assert_str(_lines(expected)[0]).is_equal("MILK | 2")
	_receipt.begin()
	assert_int(_lines(_receipt).size()).is_equal(0)
	# The lines let go are freed at the frame's end.
	await _frames(1)


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
## after the bar; its marker sits past the diamond and its text, wrapped too, hangs past both. A
## card's own bonus stays a plain hung line.
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
		assert_float(indent).is_greater_equal(ReceiptView.COMBO_INDENT)
		assert_float(left.get_character_bounds(0).position.x).is_equal_approx(indent, 1.0)
		var marker: Label = left.get_node_or_null("Marker") as Label
		if marker != null:
			assert_float(marker.position.x).is_equal(ReceiptView.COMBO_INDENT)
			assert_float(marker.position.x + marker.get_minimum_size().x).is_less_equal(indent)
		# The whole line stays inside the receipt's lines.
		assert_float(line.get_rect().end.x).is_less_equal(_receipt._lines.size.x)
	# The long upgrade line wraps, every row hung past the diamond.
	var wrapped: Label = lines[0].get_child(0) as Label
	assert_int(wrapped.get_line_count()).is_greater(1)
	assert_str((lines[2].get_child(0) as Label).text).is_equal("Repeat: copy of Bread")
	var own_left: Label = plain.get_child(0) as Label
	assert_object(own_left.get_node_or_null("ComboDiamond")).is_null()
	assert_bool(plain.draw.get_connections().is_empty()).is_true()


static func _step(type: ScoreStep.StepType, text: String) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = 0
	step.source_slot = 0
	step.value = 2
	step.text = text
	return step


## Milk (2) then Bread (3): BASE and PAYOUT each, total 5.
static func _result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	for slot: int in range(2):
		for type: ScoreStep.StepType in [ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT]:
			var step: ScoreStep = _step(type, "")
			step.slot = slot
			step.source_slot = slot
			step.value = 2 + slot
			result.steps.append(step)
	result.total = 5
	return result


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
