extends GdUnitTestSuite
## ReceiptView's hanging indent (#55): an indented step line (a DETAIL or FIZZLE line whose text
## starts with spaces) wraps under the text after its lead and marker, not at the receipt's left
## edge, its marker printed beside the first row; the amount sits on the last row, and a fizzle's
## line has none (its mark, on its first row, says it). The receipt is laid out on its own, as
## wide as the shift screen's (ShiftStage.RECEIPT_WIDTH), so the long lines wrap. No saves, no
## event log.

## The shift screen's receipt width: "Coupon engine: the first coupon paid nothing" wraps.
const RECEIPT_SIZE := Vector2(ShiftStage.RECEIPT_WIDTH, 400)
## How far a character may sit from where the indent puts it, in pixels.
const TOLERANCE := 1.0

var _receipt: ReceiptView
var _folder: String = ""


func before_test() -> void:
	# Saves and logs go to a temporary folder, never the real user:// ones.
	_folder = "user://test_receipt_hang_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	# The shift screen's paper margins (ShiftStage._build_register), so the lines are as wide.
	var paper: StyleBoxFlat = StyleBoxFlat.new()
	paper.set_content_margin_all(ShiftStage.RECEIPT_PADDING)
	paper.content_margin_left = ShiftStage.RECEIPT_PADDING - ReceiptView.FRAME_OUT
	paper.content_margin_right = ShiftStage.RECEIPT_PADDING - ReceiptView.FRAME_OUT
	_receipt.add_theme_stylebox_override("panel", paper)
	add_child(_receipt)
	_receipt.size = RECEIPT_SIZE


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_hang_parts_splits_the_lead_the_marker_and_the_rest() -> void:
	assert_array(Array(ReceiptDecor.hang_parts("  + Strawberries beside Produce"))).is_equal(
		["  ", "+ ", "Strawberries beside Produce"]
	)
	assert_array(Array(ReceiptDecor.hang_parts("  × Multipack"))).is_equal(
		["  ", "× ", "Multipack"]
	)
	assert_array(Array(ReceiptDecor.hang_parts("  Coupon engine: no coupon"))).is_equal(
		["  ", "", "Coupon engine: no coupon"]
	)
	# A marker only counts after leading spaces.
	assert_array(Array(ReceiptDecor.hang_parts("+ MILK"))).is_equal(["", "", "+ MILK"])
	assert_array(Array(ReceiptDecor.hang_parts("MILK"))).is_equal(["", "", "MILK"])


## A wrapped fizzle: every row starts at the indent (the lead's width), on at most two rows: no
## "WASTED" word takes room beside the reason, only the mark column, and the fizzle mark is
## centred on the reason's first row, inside the line.
func test_a_wrapped_fizzle_hangs_with_its_mark_on_the_first_row() -> void:
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
	assert_int(left.get_line_count()).is_less_equal(2)
	# No "WASTED" word: the right side is only the mark column.
	assert_str(right.text).is_empty()
	assert_float(right.size.x).is_less_equal(ReceiptView.FIZZLE_MARK_COLUMN + 1.0)
	var mark: Control = right.get_node_or_null("Mark") as Control
	assert_object(mark).is_not_null()
	var line_rect: Rect2 = line.get_global_rect()
	assert_bool(line_rect.grow(0.5).encloses(mark.get_global_rect())).is_true()
	var first_row: float = left.get_global_rect().position.y + first.get_center().y
	assert_float(mark.get_global_rect().get_center().y).is_equal_approx(first_row, 1.5)
	# Clear of the reason's text.
	var widest: float = 0.0
	for index: int in range(left.text.length()):
		widest = maxf(widest, left.get_character_bounds(index).end.x)
	assert_float(mark.get_global_rect().position.x).is_greater(
		left.get_global_rect().position.x + widest
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


## Lines without leading spaces keep their text and get no indent (an item line only its mini's
## two-character slot, ReceiptInk); their amounts sit on their last row too.
func test_lines_without_a_lead_are_not_hung() -> void:
	var item: Control = _receipt.add_step(
		_step(ScoreStep.StepType.BASE, "Milk"), PackedStringArray(["Milk"])
	)
	var total: Control = _receipt.add_total(12)
	var margin: Control = _receipt.add_margin(ShiftMargin.of(12, 10))
	await _frames(2)
	for line: Control in [item, total, margin]:
		var left: Label = line.get_child(0) as Label
		if line == item:
			var slot: float = left.get_theme_stylebox("normal").content_margin_left
			assert_float(slot).is_equal_approx(_width(left, ReceiptInk.ICON_SLOT), 0.01)
		else:
			assert_bool(left.has_theme_stylebox_override("normal")).is_false()
		assert_object(left.get_node_or_null("Marker")).is_null()
		var right: Label = line.get_child(1) as Label
		assert_int(right.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_BOTTOM)
	assert_str((item.get_child(0) as Label).text).is_equal("Milk")
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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
