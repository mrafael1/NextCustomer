extends GdUnitTestSuite
## V3's wider monitor retains the explanation and leaves the quota celebration on the register.


func test_the_monitor_keeps_bonus_lines_and_folds_only_the_earliest_overflow() -> void:
	var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
	add_child(column)
	column.reduced_motion = func() -> bool: return true
	column.start_item(load("res://data/cards/banana.tres"), PackedStringArray(["Produce"]))
	var giver_icon: Texture2D = load("res://art/minis/banana.png")
	column.show_step("Banana chain  +€3", false, false, giver_icon, true)
	column.show_step("Produce regulars  +€2", false)
	column.show_step("Produce aisle run  ×3", false)
	column.show_step("Multipack  ×3", false)
	assert_int(column.step_texts().size()).is_equal(4)
	assert_bool(column.step_rows()[0].get_meta(&"from_bag")).is_true()
	var text: Label = column.step_rows()[0].get_node("Text") as Label
	assert_str(text.text).contains("from the bag")
	column.show_step("Slot engine  ×2", false)
	assert_int(column.step_texts().size()).is_equal(5)
	column.show_step("Pays  €126", false)
	assert_int(column.step_texts().size()).is_equal(5)
	assert_str(column.step_texts()[0]).is_equal("+2 earlier")
	assert_str(column.step_texts()[-1]).is_equal("Pays  €126")
	for row: Control in column.step_rows():
		(
			assert_bool(
				Rect2(Vector2.ZERO, column.size).encloses(
					Rect2(row.position + Vector2(0, MonitorItemColumn.COUNT_STEPS_TOP), row.size)
				)
			)
			. is_true()
		)

	await get_tree().process_frame
	await get_tree().process_frame


func test_the_customer_display_follows_the_same_total_and_clears_for_planning() -> void:
	var count: CountUp = auto_free(CountUp.new())
	var led: LedDisplay = auto_free(LedDisplay.new())
	var display: RegisterTotal = auto_free(RegisterTotal.new())
	add_child(count)
	add_child(display)
	display.follow(count, led)
	led.start_count(73)
	assert_bool(display.visible).is_true()
	led.show_subtotal(21, false)
	assert_int(display.amount()).is_equal(21)
	assert_str(display.number_label().text).is_equal("€21")
	assert_str(display.status_text()).contains("€52 TO GO")
	led.show_subtotal(170, true)
	assert_str(display.status_text()).contains("+€97 OVER")
	led.clear()
	assert_bool(display.visible).is_false()
