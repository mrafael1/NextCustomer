extends GdUnitTestSuite
## The bay's queue (#86 round 7, BayQueue): its text for each moment ("n LEFT", LAST, DONE,
## SCANNER outside a count) and its pips' geometry for 1 to 9 items: inside the header, right-
## aligned on RIGHT_EDGE, on the 2 px grid across, all one size, clear of the widest header text,
## PIP px for a short row, every row of up to 9 fitting.


func test_the_text_counts_down() -> void:
	assert_str(BayQueue.text_for(0, -1, false)).is_equal(BayQueue.IDLE_TEXT)
	assert_str(BayQueue.text_for(5, -1, false)).is_equal("5 LEFT")
	assert_str(BayQueue.text_for(5, 0, false)).is_equal("4 LEFT")
	assert_str(BayQueue.text_for(5, 3, false)).is_equal("1 LEFT")
	assert_str(BayQueue.text_for(5, 4, false)).is_equal(BayQueue.LAST_TEXT)
	assert_str(BayQueue.text_for(5, 4, true)).is_equal(BayQueue.DONE_TEXT)
	assert_str(BayQueue.text_for(1, -1, false)).is_equal("1 LEFT")
	assert_str(BayQueue.text_for(1, 0, false)).is_equal(BayQueue.LAST_TEXT)


## Every layout from 1 to 9 items fits the header beside its widest text.
func test_the_pips_fit_beside_the_text() -> void:
	var queue: BayQueue = auto_free(BayQueue.new())
	add_child(queue)
	await get_tree().process_frame
	var header: Rect2 = ScannerBay.HEADER_RECT
	for items: int in range(1, 10):
		queue.start(items)
		var rects: Array[Rect2] = queue.pip_rects()
		var message: String = "%d items: %s" % [items, rects]
		assert_int(rects.size()).override_failure_message(message).is_equal(items)
		var text_end: float = BayQueue.TEXT_X + BayQueue.widest_text(items) + BayQueue.TEXT_GAP
		var right: float = 0.0
		for rect: Rect2 in rects:
			assert_bool(header.encloses(rect)).override_failure_message(message).is_true()
			assert_vector(rect.size).override_failure_message(message).is_equal(rects[0].size)
			assert_float(fmod(rect.position.x, 2.0)).override_failure_message(message).is_equal(0.0)
			assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
				text_end
			)
			assert_bool(ScannerBay.LIGHT_RECT.grow(1.0).intersects(rect)).is_false()
			right = maxf(right, rect.end.x)
			for other: Rect2 in rects:
				if other != rect:
					assert_bool(other.intersects(rect)).override_failure_message(message).is_false()
		assert_float(right).is_equal(BayQueue.RIGHT_EDGE)
		prints("#86 queue pips for", items, "items:", rects[0].size.x, "px, rows:", _rows(rects))
	queue.start(5)
	assert_float(queue.pip_rects()[0].size.x).is_equal(BayQueue.PIP)
	# The drawn label is the header's font, its text within the header.
	var label: Label = queue.get_child(0) as Label
	assert_object(label.get_theme_font("font")).is_same(ScannerBay.header_font())
	var width: float = BayQueue.widest_text(9)
	assert_float(BayQueue.TEXT_X + width).is_less(BayQueue.RIGHT_EDGE)
	# Its line (the mock-up's bold 9 px) fits the header's height, centred on it.
	var font: Font = ScannerBay.header_font()
	assert_float(font.get_height(BayQueue.FONT_SIZE)).is_less_equal(header.size.y)
	var line: Rect2 = Rect2(queue.global_position + label.position, label.size)
	assert_float(line.get_center().y).is_equal_approx(header.get_center().y, 0.5)
	# One row of SMALL_PIP for the --effects checkout's 7 items.
	queue.start(7)
	assert_int(_rows(queue.pip_rects())).is_equal(1)


static func _rows(rects: Array[Rect2]) -> int:
	var tops: Dictionary[float, bool] = {}
	for rect: Rect2 in rects:
		tops[rect.position.y] = true
	return tops.size()
