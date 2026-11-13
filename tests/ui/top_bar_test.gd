extends GdUnitTestSuite
## The top bar on its own (#80 step 10, mock-up B2; TopBar), with no SPEND chip since the shift
## scene polish; and the quota gauge it held (QuotaMeter, now the tube beside the receipt): it
## shows the projected total in planning (the screen's preview hands it over; its laps once it
## reaches the quota) and mirrors the LED from the checkout (the subtotal while counting so the
## gauge never shows the final total early, its laps once the count meets the quota and until the
## next shift) and keeps its size through a count and a drag (#86's gauge itself:
## quota_meter_test); the menu opens under its button
## with Export log, drawn sharp, which closes it and says so; Cart's trolley sits left of its
## caption inside the button and the menu's bars in its middle; the chips' decor takes no clicks.
## Its place on the screen: shift_screen_layout_test. The week glass's and the desk calendar's
## lettering on whole pixels (v1.17; the calendar on the register's top since left column v2) are
## checked here; their layout in week_card_ui_test and day_calendar_test.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
## The gauge's glass in the bar (GaugePanel.glass_rect at GAUGE_PANEL_RECT's width).
const GLASS := Vector2(360, 26)


func test_the_quota_gauge_follows_the_led() -> void:
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	add_child(meter)
	meter.follow(led)
	led.clear()
	assert_int(meter.amount()).is_equal(-1)
	assert_float(meter.fill()).is_equal(0.0)
	# Planning: the projected total from the screen's preview (the LED blank), lap 2 refilling
	# from the quota on.
	meter.show_projected(22, 73)
	assert_int(meter.amount()).is_equal(22)
	assert_float(meter.fill()).is_equal_approx(22.0 / 73.0, 0.0001)
	assert_bool(_met(meter)).is_false()
	meter.show_projected(90, 73)
	assert_float(meter.fill()).is_equal_approx(17.0 / 73.0, 0.0001)
	assert_bool(_met(meter)).is_true()
	# The count starts from 0 and follows the subtotal; the laps come with the count's ding.
	led.start_count(73)
	assert_int(meter.amount()).is_equal(0)
	assert_float(meter.fill()).is_equal(0.0)
	led.show_subtotal(40, false)
	assert_float(meter.fill()).is_equal_approx(40.0 / 73.0, 0.0001)
	assert_bool(_met(meter)).is_false()
	led.show_subtotal(80, true)
	assert_bool(_met(meter)).is_true()
	assert_float(meter.fill()).is_equal_approx(7.0 / 73.0, 0.0001)
	# It stays through the TOTAL, then the next shift's planning (the LED blanked, the projected
	# total handed over) frees it.
	led.show_total()
	assert_bool(_met(meter)).is_true()
	assert_int(meter.amount()).is_equal(80)
	led.clear()
	meter.show_projected(10, 90)
	assert_bool(_met(meter)).is_false()
	assert_int(meter.amount()).is_equal(10)
	led.clear()
	assert_bool(_met(meter)).is_false()
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
	assert_str(bar.export_button.caption).is_equal(TopBar.EXPORT_TEXT)
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


## The chips, their texts, the spacer and icons are decor: no clicks (the day calendar and the
## stamps only pass the mouse on for their hover text; the calendar's SKIP tag alone takes a tap).
func test_the_decor_takes_no_clicks() -> void:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	assert_int(bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var decor: Array[Node] = bar.shift_chip.find_children("*", "Control", true, false)
	decor.append(bar.shift_chip)
	decor.append(bar.get_node("Spacer"))
	decor.append(bar.loyalty_card)
	for node: Node in decor:
		(
			assert_int((node as Control).mouse_filter)
			. override_failure_message(str(node.get_path()))
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)
	# The desk calendar (left column v2: on the register's top, no longer in the bar).
	var calendar: DayCalendar = auto_free(DayCalendar.new())
	add_child(calendar)
	assert_int(calendar.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	var skip: Control = calendar.tags.skip_tag()
	assert_int(skip.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# The bonus pill passes its hover and tap to the calendar (the slip).
	var pill: Control = calendar.tags.pill()
	assert_int(pill.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	for node: Node in calendar.find_children("*", "Control", true, false):
		if node == skip or node == pill:
			continue
		(
			assert_int((node as Control).mouse_filter)
			. override_failure_message(str(node.name))
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)


## The quota gauge (lying in the bar's gauge chip since left column v2) keeps its size through a
## count and a drag (#71): it prints nothing, so nothing in it can grow or move.
func test_the_quota_gauge_keeps_its_size() -> void:
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	meter.reduced_motion = func() -> bool: return true
	meter.horizontal = true
	meter.size = GLASS
	add_child(meter)
	meter.follow(led)
	meter.show_projected(73, 900)
	await _frames(2)
	led.start_count(900)
	for subtotal: int in [0, 9, 99, 999, 9999]:
		led.show_subtotal(subtotal, subtotal >= 900)
		await _frames(2)
		assert_bool(_met(meter)).is_equal(subtotal >= 900)
		assert_vector(meter.size).is_equal(GLASS)
	led.clear()
	for case: Array in [[52, 6], [40, -6], [9999, 999], [1, -999]]:
		meter.show_hypothetical(case[0], case[1], 900)
		await _frames(2)
		assert_int(meter.hypothetical()).is_equal(case[0])
		assert_vector(meter.size).is_equal(GLASS)
	assert_array(meter.find_children("*", "Label", true, false)).is_empty()


## The SPEND chip is gone (the shift scene polish): the bar's only gauge is the quota gauge's chip
## (left column v2), and a spacer keeps Cart and the menu at the row's end.
func test_the_bar_has_no_spend_chip() -> void:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	await _frames(2)
	var meters: Array[Node] = bar.find_children("*", "QuotaMeter", true, false)
	assert_array(meters).is_equal([bar.gauge_panel.quota_meter])
	var spacer: Control = bar.get_node("Spacer") as Control
	assert_int(spacer.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
	assert_int(spacer.get_index()).is_less(bar.deck_button.get_index())
	assert_float(bar.menu_button.get_rect().end.x).is_equal_approx(TopBar.ROW_SIZE.x, 0.5)


## The week glass's words (v1.17, in place of the week chip's lettering): WEEK in the 3x5
## capitals, the week's number in the chunky digits with "/4" after it, their feet level;
## on every shift, at 1x and at 1920x1080's 1.5x (the glass where the stretched stage puts it),
## each word's corner lies on whole pixels of the screen, the words inside the glass's inside
## and apart, the number's group centred on it within a canvas pixel.
func test_the_glass_letters_its_week_on_whole_pixels() -> void:
	var glass: WeekGlass = auto_free(WeekGlass.new())
	add_child(glass)
	glass.size = ShiftStage.WEEK_GLASS_RECT.size
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(43, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	for scale: float in [1.0, 1.5]:
		glass.scale = Vector2(scale, scale)
		glass.position = ShiftStage.WEEK_GLASS_RECT.position * scale  # The stage stretched.
		for shift_index: int in range(run.shift_count()):
			run.debug_skip_to_shift(shift_index)
			glass.show_week(WeekCardModel.of(run), true)
			await _frames(1)
			var message: String = "shift %d at %sx" % [shift_index + 1, scale]
			assert_bool(glass.visible).override_failure_message(message).is_true()
			var inner: Rect2 = glass.get_global_transform() * WeekGlass.INSIDE_RECT
			var words: Array[PixelWords] = [glass.week_label, glass.number_label, glass.count_label]
			for index: int in range(words.size()):
				var rect: Rect2 = words[index].get_global_rect()
				var what: String = "%s: %s" % [message, words[index].text]
				assert_bool(inner.encloses(rect)).override_failure_message(what).is_true()
				(
					assert_bool(_is_whole(rect.position.x) and _is_whole(rect.position.y))
					. override_failure_message(what)
					. is_true()
				)
				for other: int in range(index + 1, words.size()):
					var apart: bool = not rect.intersects(words[other].get_global_rect())
					assert_bool(apart).override_failure_message(what).is_true()
			var number: Rect2 = glass.number_label.get_global_rect()
			var count: Rect2 = glass.count_label.get_global_rect()
			assert_float(count.end.y).is_equal_approx(number.end.y, 0.01)
			var group: float = (number.position.x + count.end.x) / 2.0
			assert_float(group).override_failure_message(message).is_equal_approx(
				inner.get_center().x, 2.0 * scale
			)


## The desk calendar's parts (left column v2) lie on whole art pixels: at 1x on even canvas pixels,
## and at the 1920x1080 window's 1.5x on whole screen pixels, on every day of the run and every
## kind.
func test_the_calendar_draws_on_whole_pixels() -> void:
	var calendar: DayCalendar = auto_free(DayCalendar.new())
	add_child(calendar)
	var balance: BalanceDefinition = load(BALANCE)
	var pool: Array[InspectionDefinition] = balance.inspection_pool + balance.boon_pool
	var run: RunState = RunState.new(43, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	for scale: float in [1.0, 1.5]:
		# The bar where the stage puts it, the stage scaled as the window stretches it.
		calendar.scale = Vector2(scale, scale)
		calendar.position = ShiftStage.DESK_CALENDAR_RECT.position * scale
		for shift_index: int in range(run.shift_count()):
			run.debug_skip_to_shift(shift_index)
			calendar.show_inspections(run.inspections, shift_index + 1, pool, run.shift_count())
			calendar.show_week(WeekCardModel.of(run))
			await _frames(1)
			var parts: Dictionary = calendar.part_rects()
			var rects: Array[Rect2] = [parts["pad"], parts["number"], parts["day"]]
			for sign_rect: Rect2 in parts["signs"]:
				rects.append(sign_rect)
			var step: float = DayCalendarArt.CELL * scale
			for rect: Rect2 in rects:
				var message: String = "day %d at %sx: %s" % [shift_index + 1, scale, rect]
				var cells: Vector2 = rect.size / step
				(
					assert_bool(_is_whole(cells.x) and _is_whole(cells.y))
					. override_failure_message(message)
					. is_true()
				)
				(
					assert_bool(_is_whole(rect.position.x) and _is_whole(rect.position.y))
					. override_failure_message(message)
					. is_true()
				)


## Whether `value` is a whole number (within float error).
static func _is_whole(value: float) -> bool:
	return absf(value - roundf(value)) < 0.001


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


## The gauge shows the quota met: its laps past the first.
static func _met(meter: QuotaMeter) -> bool:
	return meter.shown_lap() >= QuotaLaps.FIRST_LAP
