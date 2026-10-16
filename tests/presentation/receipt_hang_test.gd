extends GdUnitTestSuite
## ReceiptView's hanging indent (#55): an indented step line (a DETAIL or FIZZLE line whose text
## starts with spaces) wraps under the text after its lead and marker, not at the receipt's left
## edge, its marker printed beside the first row; the amount or "fizzle" sits on the last row.
## The receipt is laid out on its own, narrow enough for the long lines to wrap. No saves, no
## event log.

## Narrow enough for "Coupon engine: the first coupon paid nothing" to wrap.
const RECEIPT_SIZE := Vector2(240, 400)
## How far a character may sit from where the indent puts it, in pixels.
const TOLERANCE := 1.0

var _receipt: ReceiptView


func before_test() -> void:
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	add_child(_receipt)
	_receipt.size = RECEIPT_SIZE


func test_hang_parts_splits_the_lead_the_marker_and_the_rest() -> void:
	assert_array(Array(ReceiptView.hang_parts("  + Strawberries beside Produce"))).is_equal(
		["  ", "+ ", "Strawberries beside Produce"]
	)
	assert_array(Array(ReceiptView.hang_parts("  × Multipack"))).is_equal(["  ", "× ", "Multipack"])
	assert_array(Array(ReceiptView.hang_parts("  Coupon engine: no coupon"))).is_equal(
		["  ", "", "Coupon engine: no coupon"]
	)
	# A marker only counts after leading spaces.
	assert_array(Array(ReceiptView.hang_parts("+ MILK"))).is_equal(["", "", "+ MILK"])
	assert_array(Array(ReceiptView.hang_parts("MILK"))).is_equal(["", "", "MILK"])


## A wrapped fizzle: every row starts at the indent (the lead's width), and "fizzle" is
## bottom-aligned on the last row.
func test_a_wrapped_fizzle_hangs_and_its_fizzle_sits_on_the_last_row() -> void:
	var step: ScoreStep = _step(ScoreStep.StepType.WASTED, "Coupon engine")
	step.reason = "the first coupon paid nothing"
	var line: Control = _receipt.add_step(step, PackedStringArray(["Milk"]))
	await _frames(2)
	var left: Label = line.get_child(0) as Label
	var right: Label = line.get_child(1) as Label
	assert_str(left.text).is_equal("Coupon engine: the first coupon paid nothing")
	assert_object(left.get_node_or_null("Marker")).is_null()
	assert_bool(left.has_theme_stylebox_override("normal")).is_true()
	var indent: float = left.get_theme_stylebox("normal").content_margin_left
	assert_float(indent).is_greater(0.0)
	assert_float(indent).is_equal_approx(_width(left, "  "), 0.01)
	assert_int(left.get_line_count()).is_greater(1)
	var first: Rect2 = left.get_character_bounds(0)
	assert_float(first.position.x).is_equal_approx(indent, TOLERANCE)
	var second_row: int = _second_row_start(left)
	assert_int(second_row).is_greater(0)
	assert_float(left.get_character_bounds(second_row).position.x).is_equal_approx(
		indent, TOLERANCE
	)
	# "fizzle" fills the line's height and is drawn on the left side's last row.
	assert_str(right.text).is_equal("fizzle")
	assert_int(right.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_BOTTOM)
	assert_float(right.size.y).is_equal_approx(line.size.y, 0.01)
	var last: Rect2 = left.get_character_bounds(left.text.length() - 1)
	var fizzle: Rect2 = right.get_character_bounds(0)
	assert_float(right.position.y + fizzle.get_center().y).is_equal_approx(
		left.position.y + last.get_center().y, TOLERANCE
	)


## A flat bonus's "+ " is a "Marker" label after the lead, inside the indent; the text after it
## starts at the indent.
func test_a_flat_line_prints_its_marker_beside_the_indent() -> void:
	var line: Control = _receipt.add_step(
		_step(ScoreStep.StepType.FLAT, "Strawberries beside Produce"), PackedStringArray(["Milk"])
	)
	await _frames(2)
	var left: Label = line.get_child(0) as Label
	assert_str(left.text).is_equal("Strawberries beside Produce")
	var indent: float = left.get_theme_stylebox("normal").content_margin_left
	assert_float(indent).is_equal_approx(_width(left, "  + "), 0.01)
	var marker: Label = left.get_node_or_null("Marker") as Label
	assert_object(marker).is_not_null()
	assert_str(marker.text).is_equal("+")
	assert_float(marker.position.x).is_equal_approx(_width(left, "  "), 0.01)
	assert_float(marker.position.x + marker.get_minimum_size().x).is_less_equal(indent)
	assert_float(left.get_character_bounds(0).position.x).is_equal_approx(indent, TOLERANCE)


## Lines without leading spaces keep their text and get no indent; their amounts sit on their
## last row too.
func test_lines_without_a_lead_are_not_hung() -> void:
	var item: Control = _receipt.add_step(
		_step(ScoreStep.StepType.BASE, "Milk"), PackedStringArray(["Milk"])
	)
	var total: Control = _receipt.add_total(12)
	var margin: Control = _receipt.add_margin(ShiftMargin.of(12, 10))
	await _frames(2)
	for line: Control in [item, total, margin]:
		var left: Label = line.get_child(0) as Label
		assert_bool(left.has_theme_stylebox_override("normal")).is_false()
		assert_object(left.get_node_or_null("Marker")).is_null()
		var right: Label = line.get_child(1) as Label
		assert_int(right.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_BOTTOM)
	assert_str((item.get_child(0) as Label).text).is_equal("MILK")
	assert_str((total.get_child(0) as Label).text).is_equal("TOTAL")


static func _step(type: ScoreStep.StepType, text: String) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = 0
	step.source_slot = 0
	step.value = 2
	step.text = text
	return step


## The width of `text` in `label`'s font at its size.
static func _width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The index of the first visible character on `label`'s second row, or -1.
static func _second_row_start(label: Label) -> int:
	var first_y: float = label.get_character_bounds(0).position.y
	for index: int in range(1, label.text.length()):
		var bounds: Rect2 = label.get_character_bounds(index)
		if bounds.size.x > 0.0 and bounds.position.y > first_y + TOLERANCE:
			return index
	return -1


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
