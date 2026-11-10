extends GdUnitTestSuite
## The shift receipt's item marks at checkout (main scene v2, 2026-11-08): planning prints no item
## rows, so the receipt no longer explains a hovered item (#71's framed line and "×N" chips went
## with the rows: the rails and the tickets explain it); the count prints each row as it reaches
## it (ReceiptPrintRows), and an inspection's denial marks its item's row with the warning icon
## (DENIED, over a fizzle on it too), a fizzle of its own with the fizzle icon. The receipt is laid
## out on its own, at the shift screen's width (receipt_stub_test's fixtures). No saves, no event
## log.

const STUB := preload("res://tests/presentation/receipt_stub_test.gd")
const NAMES: Array[String] = ["Multipack", "Milk", "Soup"]

var _receipt: ReceiptView


func before_test() -> void:
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	add_child(_receipt)
	_receipt.size = STUB.RECEIPT_SIZE


## Planning shows no rows to frame or explain: only the header (2026-11-08: no band).
func test_planning_has_no_rows_to_explain() -> void:
	_receipt.anchored = true
	_receipt.show_planning(
		PackedStringArray(), STUB._closing_result(), PackedStringArray(NAMES), 3, 5
	)
	await _frames(2)
	assert_bool(_receipt._items.is_empty()).is_true()
	assert_object(_receipt._framed_line()).is_null()
	assert_int(_receipt._lines.get_child_count()).is_equal(0)
	assert_array(_receipt.printed_rows()).is_empty()


## An item an inspection sets to 0€ shows the warning icon on its printed row (DENIED, over a
## fizzle on it too); a fizzle of its own the fizzle icon.
func test_an_inspection_denial_marks_its_row() -> void:
	var result: ScoreResult = STUB._closing_result()
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.DENIED)
	result.steps.insert(6, STUB._step(ScoreStep.StepType.WASTED, "Coffee bonus"))
	result.steps[6].slot = 1
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.DENIED)
	assert_int(ReceiptView.slot_mark(result, 2)).is_equal(ReceiptView.Mark.FIZZLED)
	_receipt.anchored = true
	_receipt.reduced_motion = true
	var names: PackedStringArray = PackedStringArray(NAMES)
	_receipt.show_planning(PackedStringArray(), result, names, 3, 5)
	await _frames(1)
	_receipt.begin_count(PackedStringArray(), names)
	for step: ScoreStep in result.steps:
		_receipt.add_step(step, names)
	_receipt.add_total(result.total)
	await _frames(2)
	var rows: Array[Control] = _receipt.printed_rows()
	assert_int(rows.size()).is_equal(3)
	var marks: Array = []
	for row: Control in rows:
		var mark: Node = row.get_child(1).get_node_or_null("Mark")
		marks.append(-1 if mark == null else mark.get_meta("mark") as int)
	assert_array(marks).is_equal(
		[ReceiptView.Mark.FIZZLED, ReceiptView.Mark.DENIED, ReceiptView.Mark.FIZZLED]
	)
	var denied: TextureRect = rows[1].get_child(1).get_node("Mark") as TextureRect
	assert_object(denied.texture).is_same(ReceiptDecor.WARNING_ICON)
	var paper: Rect2 = _receipt.get_global_rect()
	for row: Control in rows:
		var mark_rect: Rect2 = (row.get_child(1).get_node("Mark") as Control).get_global_rect()
		assert_bool(paper.encloses(mark_rect)).override_failure_message(str(mark_rect)).is_true()


## A context pass's fizzle on the denied item comes before the slot loop (before its row prints and
## before the inspection's override): the row still ends DENIED, the warning icon alone.
func test_a_denial_replaces_an_earlier_fizzle() -> void:
	var result: ScoreResult = STUB._closing_result()
	var early: ScoreStep = STUB._step(ScoreStep.StepType.WASTED, "no item in the next slot")
	early.slot = 1
	result.steps.insert(0, early)
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.DENIED)
	_receipt.anchored = true
	_receipt.reduced_motion = true
	var names: PackedStringArray = PackedStringArray(NAMES)
	_receipt.show_planning(PackedStringArray(), result, names, 3, 5)
	await _frames(1)
	_receipt.begin_count(PackedStringArray(), names)
	for step: ScoreStep in result.steps:
		_receipt.add_step(step, names)
	_receipt.add_total(result.total)
	await _frames(2)
	var row: Control = _receipt.printed_rows()[1]
	var marks: Array[Node] = row.find_children("Mark", "", true, false)
	assert_int(marks.size()).is_equal(1)
	assert_int(marks[0].get_meta("mark") as int).is_equal(ReceiptView.Mark.DENIED)
	# Fizzled on a printed row first, then denied: the warning replaces the fizzle icon.
	var later: ScoreResult = STUB._closing_result()
	var fizzle: ScoreStep = STUB._step(ScoreStep.StepType.WASTED, "Coffee bonus")
	fizzle.slot = 1
	var at: int = 0
	while later.steps[at].slot != 1 or later.steps[at].step_type != ScoreStep.StepType.BASE:
		at += 1
	later.steps.insert(at + 1, fizzle)
	_receipt.show_planning(PackedStringArray(), later, names, 3, 5)
	_receipt.begin_count(PackedStringArray(), names)
	for step: ScoreStep in later.steps:
		_receipt.add_step(step, names)
	await _frames(2)
	marks = _receipt.printed_rows()[1].find_children("Mark", "", true, false)
	assert_int(marks.size()).is_equal(1)
	assert_int(marks[0].get_meta("mark") as int).is_equal(ReceiptView.Mark.DENIED)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
