extends GdUnitTestSuite
## The top bar on its own (#80 step 10, mock-up B2; TopBar): the quota chip shows the projected
## total in planning (the screen's preview hands it over: the monitor shows its store channel
## then; #86's flag once it reaches the quota) and mirrors the LED from the checkout (the subtotal
## while counting so the gauge never shows the final total early, the flag once the count meets
## the quota and until the next shift) and keeps its gauge's width
## through a count (#86's gauge itself: quota_meter_test); the menu opens under its button
## with Export log, drawn sharp, which closes it and says so; Cart's trolley sits left of its
## caption inside the button and the menu's bars in its middle; the chips' decor takes no clicks.
## Its place on the screen: shift_screen_layout_test.


func test_the_quota_chip_follows_the_led() -> void:
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	add_child(meter)
	meter.follow(led)
	led.clear()
	assert_str(meter.amount_label.text).is_empty()
	assert_float(meter.fill()).is_equal(0.0)
	# Planning: the projected total from the screen's preview (the LED blank), the flag planted
	# once it reaches the quota.
	meter.show_projected(22, 73)
	assert_str(meter.amount_label.text).is_equal("€22")
	assert_float(meter.fill()).is_equal_approx(22.0 / 73.0, 0.0001)
	assert_bool(meter.flag_shown()).is_false()
	meter.show_projected(90, 73)
	assert_float(meter.fill()).is_equal(1.0)
	assert_bool(meter.flag_shown()).is_true()
	# The count starts from 0 and follows the subtotal; the flag comes with the count's ding.
	led.start_count(73)
	assert_str(meter.amount_label.text).is_equal("€0")
	assert_float(meter.fill()).is_equal(0.0)
	led.show_subtotal(40, false)
	assert_float(meter.fill()).is_equal_approx(40.0 / 73.0, 0.0001)
	assert_bool(meter.flag_shown()).is_false()
	led.show_subtotal(80, true)
	assert_bool(meter.flag_shown()).is_true()
	assert_float(meter.fill()).is_equal(1.0)
	# It stays through the TOTAL, then the next shift's planning (the LED blanked, the projected
	# total handed over) frees it.
	led.show_total()
	assert_bool(meter.flag_shown()).is_true()
	assert_str(meter.amount_label.text).is_equal("€80")
	led.clear()
	meter.show_projected(10, 90)
	assert_bool(meter.flag_shown()).is_false()
	assert_str(meter.amount_label.text).is_equal("€10")
	led.clear()
	assert_bool(meter.flag_shown()).is_false()
	assert_float(meter.fill()).is_equal(0.0)


func test_fill_fraction() -> void:
	assert_float(QuotaMeter.fill_fraction(0, 50)).is_equal(0.0)
	assert_float(QuotaMeter.fill_fraction(25, 50)).is_equal(0.5)
	assert_float(QuotaMeter.fill_fraction(80, 50)).is_equal(1.0)
	assert_float(QuotaMeter.fill_fraction(-5, 50)).is_equal(0.0)
	assert_float(QuotaMeter.fill_fraction(3, 0)).is_equal(1.0)


func test_the_menu_holds_export_log() -> void:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	await _frames(2)
	var exported: Array[bool] = []
	bar.export_pressed.connect(func() -> void: exported.append(true))
	assert_bool(bar.menu.visible).is_false()
	bar.menu_button.pressed.emit()
	await _frames(2)
	assert_bool(bar.menu.visible).is_true()
	assert_str(bar.export_button.caption).is_equal("Export log")
	# The chip frame is drawn by a panel inside the popup, with the sharp-pixel material (a
	# Window cannot take it); the popup's own style is empty.
	assert_object(bar.menu.get_theme_stylebox("panel")).is_instanceof(StyleBoxEmpty)
	var frame: PanelContainer = bar.menu.get_child(0) as PanelContainer
	assert_object(frame.material).is_same(ArtStyle.pixel_material())
	var frame_style: StyleBoxTexture = frame.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(frame_style.texture).is_same(TopBar.CHIP_FRAME)
	assert_bool(frame.is_ancestor_of(bar.export_button)).is_true()
	# Under its button, right-aligned with it, inside the window.
	var button: Rect2 = bar.menu_screen_rect()
	var menu: Rect2 = Rect2(Vector2(bar.menu.position), Vector2(bar.menu.size))
	assert_float(menu.position.y).is_greater_equal(button.end.y)
	assert_float(menu.end.x).is_equal_approx(button.end.x, 1.0)
	(
		assert_bool(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(menu))
		. is_true()
	)
	var entry: Rect2 = bar.export_button.get_global_rect()
	assert_bool(Rect2(Vector2.ZERO, menu.size).encloses(entry)).is_true()
	bar.export_button.pressed.emit()
	assert_array(exported).is_equal([true])
	assert_bool(bar.menu.visible).is_false()


func test_cart_and_menu_icons_sit_in_their_buttons() -> void:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	bar.deck_button.caption = "Cart 15/15"
	await _frames(2)
	var cart: Rect2 = bar.deck_button.face().get_global_rect()
	var trolley: Rect2 = bar.deck_button.icon_rect().get_global_rect()
	var caption: Label = bar.deck_button.caption_label()
	var text: Rect2 = Rect2(
		caption.get_global_rect().position, Vector2(caption.get_minimum_size().x, caption.size.y)
	)
	assert_vector(trolley.size).is_equal(TopBar.CART_ICON_SIZE)
	assert_bool(cart.encloses(trolley)).is_true()
	assert_bool(cart.encloses(text)).override_failure_message(str(text)).is_true()
	assert_float(trolley.end.x).is_less_equal(text.position.x)
	var menu: Rect2 = bar.menu_button.face().get_global_rect()
	var bars: Rect2 = bar.menu_button.icon_rect().get_global_rect()
	assert_bool(menu.encloses(bars)).is_true()
	assert_float(bars.get_center().x).is_equal_approx(menu.get_center().x, 1.0)
	assert_str(bar.menu_button.accessibility_name).is_equal("Menu")


## The chips, their texts, bar and icons are decor: no clicks (the inspection chip and the
## stamps only pass the mouse on for their hover text).
func test_the_decor_takes_no_clicks() -> void:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	assert_int(bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var decor: Array[Node] = bar.get_child(0).find_children("*", "Control", true, false)
	decor.append_array(bar.get_child(1).find_children("*", "Control", true, false))
	decor.append(bar.get_child(0))
	decor.append(bar.get_child(1))
	decor.append(bar.loyalty_card)
	for node: Node in decor:
		(
			assert_int((node as Control).mouse_filter)
			. override_failure_message(str(node.get_path()))
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)
	assert_int(bar.inspection_tag.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	for node: Node in bar.inspection_tag.find_children("*", "Control", true, false):
		assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The quota gauge keeps its width through a count: the amount has room for four digits and the
## tag's slot is reserved, so the gauge never jumps while its fill moves.
func test_the_quota_bar_keeps_its_width_through_a_count() -> void:
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	# Layout only: no punch scaling the amount over the tag's slot (#86).
	meter.reduced_motion = func() -> bool: return true
	meter.size = Vector2(400, TopBar.ROW_SIZE.y)
	add_child(meter)
	meter.follow(led)
	meter.show_projected(73, 900)
	await _frames(2)
	var width: float = meter.bar().size.x
	assert_float(width).is_greater_equal(QuotaMeter.BAR_MIN_WIDTH)
	led.start_count(900)
	for subtotal: int in [0, 9, 99, 999, 9999]:
		led.show_subtotal(subtotal, subtotal >= 900)
		await _frames(2)
		assert_bool(meter.flag_shown()).is_equal(subtotal >= 900)
		(
			assert_float(meter.bar().size.x)
			. override_failure_message("€%d moved the bar" % subtotal)
			. is_equal(width)
		)
		assert_float(meter.amount_label.size.x).is_greater_equal(
			meter.amount_label.get_minimum_size().x
		)
	# The tag, shown, sits in its slot inside the meter, after the amount.
	var meter_rect: Rect2 = meter.get_global_rect()
	assert_bool(meter_rect.encloses(meter.tag_label.get_global_rect())).is_true()
	assert_float(meter.tag_label.get_global_rect().position.x).is_greater_equal(
		meter.amount_label.get_global_rect().end.x
	)


## A drag's would-be total and change (#71) keep the bar's width too: the amount's reserve holds
## "› €" and four digits, the change ("(+6)" to "(-999)") takes the tag's slot, so nothing in the
## meter moves or grows as the drag crosses the slots and ends; both texts lie inside the meter.
func test_the_quota_bar_keeps_its_width_through_a_drag() -> void:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	# Layout only: no punch scaling the amount over the tag's slot (#86).
	meter.reduced_motion = func() -> bool: return true
	meter.size = Vector2(400, TopBar.ROW_SIZE.y)
	add_child(meter)
	meter.show_projected(46, 900)
	await _frames(2)
	var width: float = meter.bar().size.x
	var minimum: Vector2 = meter.get_combined_minimum_size()
	var cases: Array = [[52, 6], [40, -6], [9999, 999], [1, -999], [152, 120]]
	for case: Array in cases:
		meter.show_hypothetical(case[0], case[1], 900)
		await _frames(2)
		var text: String = QuotaMeter.HYPOTHETICAL_TEXT % [case[0], case[1]]
		assert_str(meter.shown_text()).is_equal(text)
		assert_float(meter.bar().size.x).override_failure_message(text).is_equal(width)
		assert_vector(meter.get_combined_minimum_size()).override_failure_message(text).is_equal(
			minimum
		)
		var meter_rect: Rect2 = meter.get_global_rect()
		for label: Label in [meter.amount_label, meter.delta_label]:
			var font: Font = label.get_theme_font("font")
			var font_size: int = label.get_theme_font_size("font_size")
			var drawn: float = (
				font.get_string_size(label.text, label.horizontal_alignment, -1, font_size).x
			)
			var at: Vector2 = label.get_global_rect().position
			var ink: Rect2 = Rect2(at, Vector2(drawn, label.size.y))
			assert_bool(meter_rect.encloses(ink)).override_failure_message(text).is_true()
			assert_float(drawn).override_failure_message(text).is_less_equal(label.size.x)
		assert_float(meter.delta_label.get_global_rect().position.x).is_greater_equal(
			meter.amount_label.get_global_rect().end.x
		)
	meter.show_projected(46, 900)
	await _frames(2)
	assert_str(meter.shown_text()).is_equal("€46")
	assert_float(meter.bar().size.x).is_equal(width)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
