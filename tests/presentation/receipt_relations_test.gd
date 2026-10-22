extends GdUnitTestSuite
## The planning receipt's hover explanation (#71, H1_BUILD_SPEC.md section 8.2): show_relations
## frames the hovered item's line, marks its targets' lines (a mustard-pale fill and the token's
## chip before the amount) and names it in the fizzle footer's hint, and an inspection's denial
## marks its item's line with the warning icon. The receipt is laid out on its own, at the shift
## screen's width (receipt_stub_test's fixtures). No saves, no event log.

const STUB := preload("res://tests/presentation/receipt_stub_test.gd")

var _receipt: ReceiptView


func before_test() -> void:
	_receipt = auto_free(ReceiptView.new()) as ReceiptView
	add_child(_receipt)
	_receipt.size = STUB.RECEIPT_SIZE


## A hovered item (#71): show_relations frames its line, gives each target's line a mustard-pale
## fill and its token's chip right before the amount, and names the item in the footer's hint;
## show_relations(-1) takes it all off; outside planning it does nothing.
func test_show_relations_explains_a_hovered_item() -> void:
	_receipt.show_planning(
		PackedStringArray(STUB.HEADER), STUB._result(), PackedStringArray(STUB.NAMES), 4
	)
	await _frames(2)
	var tokens: Dictionary[int, String] = {1: "+2"}
	_receipt.show_relations(0, tokens, ReceiptView.HOVERED_HINT % "Milk")
	await _frames(1)
	assert_object(_receipt._framed_line()).is_same(_receipt._items[0])
	var bread: HBoxContainer = _receipt._items[1]
	var chip: Label = ReceiptDecor.relation_chip(bread)
	assert_object(chip).is_not_null()
	assert_str(chip.text).is_equal("+2")
	assert_int(chip.get_index()).is_equal(bread.get_child_count() - 2)
	assert_str((bread.get_child(bread.get_child_count() - 1) as Label).text).is_equal("€5.00")
	assert_bool(bread.get_meta("related", false)).is_true()
	var face: StyleBoxFlat = chip.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(face.bg_color).is_equal(Palette.MUSTARD)
	assert_object(face.border_color).is_equal(Palette.INK)
	assert_float(chip.get_global_rect().end.x).is_less_equal(bread.get_global_rect().end.x)
	assert_object(ReceiptDecor.relation_chip(_receipt._items[2])).is_null()
	assert_bool(_receipt._items[2].get_meta("related", false)).is_false()
	assert_str(STUB._lines(_receipt)[-1]).is_equal("1 WASTED |  · Milk hovered")
	_receipt.show_relations(-1)
	await _frames(1)
	assert_object(_receipt._framed_line()).is_null()
	assert_object(ReceiptDecor.relation_chip(bread)).is_null()
	assert_bool(bread.get_meta("related", false)).is_false()
	assert_str(STUB._lines(_receipt)[-1]).is_equal("1 WASTED |  · hover an item")
	_receipt.begin_count(PackedStringArray(STUB.HEADER), PackedStringArray(STUB.NAMES))
	_receipt.show_relations(0, tokens, "Milk hovered")
	assert_object(_receipt._framed_line()).is_null()
	await _frames(1)


## An item an inspection sets to €0 shows the warning icon (DENIED, over a fizzle on it too).
func test_an_inspection_denial_marks_its_line() -> void:
	var result: ScoreResult = STUB._closing_result()
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.DENIED)
	result.steps.insert(6, STUB._step(ScoreStep.StepType.WASTED, "Coffee bonus"))
	result.steps[6].slot = 1
	assert_int(ReceiptView.slot_mark(result, 1)).is_equal(ReceiptView.Mark.DENIED)
	assert_int(ReceiptView.slot_mark(result, 2)).is_equal(ReceiptView.Mark.FIZZLED)
	_receipt.show_planning(
		PackedStringArray(STUB.HEADER), result, PackedStringArray(["Multipack", "Milk", "Soup"]), 3
	)
	await _frames(2)
	var mark: TextureRect = _receipt._items[1].get_child(1).get_node("Mark") as TextureRect
	assert_object(mark.texture).is_same(ReceiptDecor.WARNING_ICON)
	assert_int(STUB._marks(_receipt)[1]).is_equal(ReceiptView.Mark.DENIED)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
