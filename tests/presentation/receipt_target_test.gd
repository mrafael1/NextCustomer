extends GdUnitTestSuite
## The receipt's TODAY'S TARGET block (the shift scene polish, mock-up shift_scene_polish_v2.html
## section 2; ReceiptTarget): hidden without a quota; the quota as whole euros with the € after
## them ("80€", the user's call of 2026-11-02) in the 6x8 pixel digits (v4's D), centred inside the
## block over its double rule; on a ReceiptView it opens the paper, outside the scrolled lines. No
## saves, no logs.


func test_hidden_without_a_quota() -> void:
	var target: ReceiptTarget = auto_free(ReceiptTarget.new())
	assert_bool(target.visible).is_false()
	assert_int(target.shown_quota()).is_equal(-1)
	target.show_quota(80)
	assert_bool(target.visible).is_true()
	assert_int(target.shown_quota()).is_equal(80)
	target.show_quota(-1)
	assert_bool(target.visible).is_false()
	assert_int(target.shown_quota()).is_equal(-1)


func test_the_quota_prints_in_whole_euros_with_the_euro_after() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	target.show_quota(80)
	for line: int in range(30):
		receipt.add_line("Milk %d" % line, "1.00€", ReceiptView.LineStyle.ITEM)
	await _frames(3)
	assert_str(target.caption.text).is_equal("TODAY'S TARGET")
	# The caption in ink (the PR #138 review), the number in tomato dark.
	assert_that(target.caption.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_str(target.amount.text).is_equal("80€")
	assert_that(target.amount.color).is_equal(Palette.TOMATO_DARK)
	var block: Rect2 = target.get_global_rect()
	assert_bool(receipt.get_global_rect().encloses(block)).is_true()
	var digits: Rect2 = target.digits_rect()
	digits.position += target.global_position
	assert_bool(block.encloses(digits)).override_failure_message(str(digits)).is_true()
	assert_float(absf(digits.get_center().x - block.get_center().x)).is_less_equal(4.0)
	# The 6x8 digits at 3 art px per font px (v4's D): 48 px tall, 72 at 1920x1080, on the grid.
	assert_float(digits.size.y).is_equal(48.0)
	assert_float(fmod(target.amount.position.x, 2.0)).is_equal(0.0)
	# The digits and the €: "80€" is 6 + 1 + 6 + 1 + 6 font px wide.
	assert_float(digits.size.x).is_equal(20.0 * ReceiptTarget.AMOUNT_CELL)
	# A number too wide for the paper steps down a size, still inside the block.
	target.show_quota(888888)
	await _frames(2)
	assert_float(target.amount.cell).is_equal(ReceiptTarget.AMOUNT_SMALL_CELL)
	var wide: Rect2 = target.digits_rect()
	wide.position += target.global_position
	assert_bool(block.encloses(wide)).override_failure_message(str(wide)).is_true()
	target.show_quota(80)
	await _frames(2)
	# The lines scroll under it: the block stays above the scroll area.
	receipt.scroll_to_end()
	await _frames(2)
	assert_float(block.end.y).is_less_equal(receipt._scroll.get_global_rect().position.y)
	assert_that(target.get_global_rect()).is_equal(block)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
