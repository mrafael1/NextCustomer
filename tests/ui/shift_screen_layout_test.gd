extends GdUnitTestSuite
## The shift screen's layout (#80, mock-up B2's greybox; ShiftStage) on the real screen: the
## 1280x720 stage centred in the window (headless runs use 1280x1280, so it sits 280 px down) over
## the store's bands that cover the viewport; the top bar with its longest texts above the shade;
## the hung monitor with the totals and the notices on its screen; the belt with the row's items on
## its top face and their tickets on the rail (its rows: shift_screen_belt_test); the register
## with the printer the receipt rises from; nothing printed between the rail and the hand;
## CHECKOUT, Redraw and Cancel on the register column (every caption fits); the hand's row over the
## baskets (its baskets, items, hover order and drag ghost: hand_baskets_test), with no hint under
## it, and the seed line under Redraw. Every rect is checked on screen against the stage and against
## the layout's constants. Also the style checks: no text carries the pixel material, numbers use
## the number font, every printed character has its glyph, and the sharp-pixel shader switches off
## and on. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SHORT_BELT := preload("res://data/inspections/short_belt.tres")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The stage is centred and every part sits on it where the layout puts it, without overlaps.
func test_the_stage_is_laid_out_without_overlaps() -> void:
	var screen: ShiftScreen = await _screen()
	var window: Rect2 = screen.get_viewport_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_vector(stage.size).is_equal(ShiftStage.SIZE)
	assert_vector(stage.get_center()).is_equal_approx(window.get_center(), Vector2(1, 1))
	# The wall fills the window behind the stage; the counter runs from the belt's back down.
	# (#77 machine v2: in the store's camera, running past the window's right edge.)
	var wall: Control = screen._wall
	assert_vector(wall.get_global_rect().position).is_equal(window.position)
	assert_float(wall.get_global_rect().end.y).is_equal(window.end.y)
	assert_float(wall.get_global_rect().end.x).is_greater_equal(window.end.x)
	var counter: Control = screen._camera.content.get_node("Counter") as Control
	assert_float(counter.get_global_rect().position.y).is_equal(
		stage.position.y + ShiftStage.COUNTER_TOP
	)
	assert_float(counter.get_global_rect().end.y).is_greater_equal(window.end.y)

	var bar_bottom: float = stage.position.y + ShiftStage.TOP_BAR_BOTTOM
	assert_float(ShiftStage.TOP_BAR_BOTTOM).is_less_equal(ShiftStage.PANEL_TOP)
	var top_parts: Array[Control] = []
	for child: Node in screen._top_bar.get_children():
		var part: Control = child as Control
		if part != null and part.visible and (part is PanelContainer or part is Button):
			top_parts.append(part)
	assert_int(top_parts.size()).is_greater_equal(5)
	for part: Control in top_parts:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.y).is_less_equal(bar_bottom)
	_assert_apart(top_parts)

	# The monitor hangs under the top bar; its one screen (#105 piece 2): the scanner bay, the item
	# column and the checkout column side by side on the paper, apart, the checkout column's number
	# clear of its caption and ladder, and the notice strip over the item column's step area.
	var monitor: Rect2 = _on_stage(screen, ShiftStage.MONITOR_RECT)
	var monitor_screen: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT)
	assert_that(screen._stage.monitor.get_global_rect()).is_equal(monitor)
	assert_bool(monitor.encloses(monitor_screen)).is_true()
	assert_float(monitor.position.y).is_greater_equal(bar_bottom)
	var paper: Rect2 = _on_stage(screen, MonitorView.PAPER_RECT)
	assert_bool(monitor_screen.encloses(paper)).override_failure_message(str(paper)).is_true()
	var bay: Rect2 = screen._monitor.bay().get_global_rect()
	assert_that(bay).is_equal(_on_stage(screen, MonitorView.BAY_RECT))
	var items: Rect2 = screen._monitor.item_column().get_global_rect()
	assert_that(items).is_equal(_on_stage(screen, MonitorView.ITEM_RECT))
	# Checkout Rhythm v3: the spend objective is the register's, never the monitor's.
	assert_bool(screen._monitor.checkout().is_visible_in_tree()).is_false()
	for part: Rect2 in [bay, items]:
		assert_bool(paper.encloses(part)).override_failure_message(str(part)).is_true()
	_assert_apart_rects([bay, items])
	_assert_digits_clear(screen)
	var notice: Rect2 = screen._notice_label.get_global_rect()
	assert_bool(_on_stage(screen, MonitorView.NOTICE_RECT).encloses(notice)).is_true()
	assert_bool(paper.encloses(notice)).is_true()
	assert_bool(notice.intersects(bay)).is_false()

	# The register: the printer box on the counter top, the column under it; the receipt stands on
	# the printer's slot.
	var register: Rect2 = screen._register.get_global_rect()
	assert_that(register).is_equal(_on_stage(screen, ShiftStage.REGISTER_RECT))
	assert_bool(stage.encloses(register)).is_true()
	var printer: Rect2 = _on_stage(screen, ShiftStage.PRINTER_RECT)
	var slot: Rect2 = _on_stage(screen, ShiftStage.PRINTER_SLOT_RECT)
	var column: Rect2 = _on_stage(screen, ShiftStage.COLUMN_RECT)
	for part: Rect2 in [printer, column]:
		assert_bool(register.encloses(part)).override_failure_message(str(part)).is_true()
	assert_bool(printer.encloses(slot)).is_true()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_bool(stage.encloses(receipt)).override_failure_message(str(receipt)).is_true()
	assert_float(receipt.end.y).is_equal(stage.position.y + ShiftStage.RECEIPT_BOTTOM)
	assert_float(receipt.position.x).is_equal(stage.position.x + ShiftStage.RECEIPT_X)
	assert_float(receipt.size.x).is_equal(ShiftStage.RECEIPT_WIDTH)
	assert_bool(slot.has_point(Vector2(receipt.get_center().x, receipt.end.y))).is_true()
	assert_float(slot.position.x).is_less_equal(receipt.position.x)
	assert_float(slot.end.x).is_greater_equal(receipt.end.x)
	# The slot's lip covers the receipt's foot: its teeth over the paper, its edge under it.
	var lip: Rect2 = screen._stage.printer_lip.get_global_rect()
	assert_that(lip).is_equal(slot)
	assert_float(lip.position.y).is_less(receipt.end.y)
	assert_float(lip.end.y).is_greater(receipt.end.y)
	assert_int(screen._stage.printer_lip.get_index()).is_greater(screen._receipt.get_index())
	assert_float(receipt.position.y).is_greater_equal(bar_bottom)
	assert_bool(receipt.intersects(monitor)).is_false()

	# The belt, right of the register, with the row's cells on it: each item on the top face, each
	# ticket on the rail.
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	assert_that(belt).is_equal(_on_stage(screen, ShiftStage.BELT_RECT))
	assert_float(belt.position.x).is_greater_equal(register.end.x)
	assert_bool(belt.intersects(receipt)).is_false()
	assert_float(belt.position.y).is_greater_equal(monitor.end.y)
	var top_face: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.top_face()
	var rail: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.rail()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	for view: CardView in screen._row_views:
		var item: ItemView = view as ItemView
		var foot: Vector2 = item.sprite().get_global_rect().end
		(
			assert_bool(top_face.has_point(foot - Vector2(1, 1)))
			. override_failure_message(str(foot))
			. is_true()
		)
		var ticket: Rect2 = item.sticker().get_global_rect()
		assert_bool(rail.encloses(ticket)).override_failure_message(str(ticket)).is_true()
	for panel: PanelContainer in screen._slots:
		var rect: Rect2 = panel.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(receipt)).is_false()
		assert_bool(rect.intersects(register)).is_false()
		# Under the monitor's shade: the value plaques stand inside the cells.
		assert_float(rect.position.y).is_greater_equal(monitor.end.y)
	assert_vector(screen._slots[0].get_global_rect().position).is_equal(
		stage.position + ShiftStage.ROW_POSITION
	)

	# No text on the counter between the rail and the hand, and none under the hand (#80, step
	# 12: B2 has neither the capacity line, the cue nor the controls hint).
	var below_rail: Rect2 = Rect2(
		register.end.x, rail.end.y, stage.end.x - register.end.x, stage.end.y - rail.end.y
	)
	for label: Node in screen._stage.find_children("*", "Label", true, false):
		var printed: Label = label as Label
		if printed.text.is_empty() or not printed.is_visible_in_tree():
			continue
		if screen._hand_box.is_ancestor_of(printed):
			continue
		var rect: Rect2 = printed.get_global_rect()
		(
			assert_bool(below_rail.intersects(rect))
			. override_failure_message("'%s' at %s" % [printed.text, rect])
			. is_false()
		)

	# CHECKOUT, Redraw and Cancel on the register column, apart.
	var expected: Dictionary[Control, Rect2] = {
		screen._cancel_button: ShiftStage.CANCEL_RECT,
		screen._redraw_button: ShiftStage.REDRAW_RECT,
		screen._checkout_button: ShiftStage.CHECKOUT_RECT,
	}
	var keys: Array[Control] = []
	for part: Control in expected:
		var rect: Rect2 = part.get_global_rect()
		assert_that(rect).is_equal(_on_stage(screen, expected[part]))
		assert_bool(column.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(printer)).is_false()
		keys.append(part)
	_assert_apart(keys)

	# The hand over the baskets, right of the register; the seed line under Redraw, on the column.
	var hand: Rect2 = screen._hand_box.get_global_rect()
	assert_that(hand).is_equal(_on_stage(screen, ShiftStage.HAND_RECT))
	assert_bool(_on_stage(screen, ShiftStage.HAND_AREA).encloses(hand)).is_true()
	assert_float(hand.position.x).is_greater_equal(register.end.x)
	var seed_rect: Rect2 = screen._seed_label.get_global_rect()
	assert_that(seed_rect).is_equal(_on_stage(screen, ShiftStage.SEED_RECT))
	assert_float(screen._seed_label.get_minimum_size().y).is_less_equal(seed_rect.size.y)
	assert_bool(column.encloses(seed_rect)).is_true()
	for part: Control in keys:
		assert_bool(seed_rect.intersects(part.get_global_rect())).is_false()
	assert_bool(seed_rect.intersects(_on_stage(screen, ShiftStage.DRAWER_RECT))).is_false()
	assert_str(screen._seed_label.text).contains("Seed %d" % screen.run.run_seed)


## The store's kraft bag (#86 v6, #123) stands at BAG_RECT on the bagging shelf behind the belt's
## first cell, right of the receipt and above the belt, its foot on the shelf, under the top bar
## and clear of the monitor and the register's keys; on the stage the shelf and the bag are drawn
## under the belt (the scanner's item stands in front) and under the top bar. It prints no text
## (not even an art-pending item's or an icon-less coupon's name) and takes no click, and a full
## bag's items peek out inside its width, on the stage, clear of the receipt and the belt.
func test_the_kraft_bag_stands_on_its_shelf_behind_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	var bag: PaperBag = screen._stage.bag
	var rect: Rect2 = bag.get_global_rect()
	assert_bool(bag.is_visible_in_tree()).is_true()
	assert_that(rect).is_equal(_on_stage(screen, ShiftStage.BAG_RECT))
	assert_bool(stage.encloses(rect)).is_true()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	assert_float(rect.position.x).is_greater_equal(receipt.end.x)
	assert_float(rect.end.y).is_less_equal(belt.position.y)
	assert_float(rect.end.y).is_equal(stage.position.y + ShiftStage.BAGGING_SHELF_RECT.position.y)
	var shelf: Control = screen._stage.fore.get_node("BaggingShelf") as Control
	assert_that(shelf.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.BAGGING_SHELF_RECT))
	assert_float(rect.position.x).is_greater_equal(shelf.get_global_rect().position.x)
	assert_float(rect.end.x).is_less_equal(shelf.get_global_rect().end.x)
	assert_float(rect.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	assert_bool(rect.intersects(_on_stage(screen, ShiftStage.MONITOR_RECT))).is_false()
	assert_bool(rect.intersects(_on_stage(screen, ShiftStage.COLUMN_RECT))).is_false()
	# In the stage's fore (#77 machine v2: it drops out of frame at the machine), over its shelf
	# and under the belt; the top bar is on the hud, over the whole world.
	var index: int = bag.get_index()
	assert_object(bag.get_parent()).is_same(screen._stage.fore)
	assert_int(index).is_greater(shelf.get_index())
	assert_int(index).is_less(screen._stage.belt.get_index())
	assert_object(screen._top_bar.get_parent()).is_same(screen._stage)
	assert_int(screen._camera.get_index()).is_less(screen._stage.get_index())
	var products: Array[CardDefinition] = []
	# An undrawn product (Bread with no art_ref; every stocked product is drawn since #57) and
	# Bundle, a slip with no icon: their names are not printed here.
	var bagged: Array[String] = ["milk", "eggs", "coffee", "cheese", "banana", "croissant"]
	bagged.append_array(["crisps", "bread", "bundle"])
	for card_id: String in bagged:
		products.append(load("res://data/cards/%s.tres" % card_id) as CardDefinition)
	products[-2] = products[-2].duplicate()
	products[-2].art_ref = ""
	# Their belt art prints their names: the bag's must not.
	for definition: CardDefinition in products.slice(-2):
		var belt_art: TextureRect = ItemView.item_art(definition)
		assert_object(belt_art.get_node_or_null(ItemView.PRINTED_NAME)).is_not_null()
		belt_art.free()
	products.append_array(products.slice(0, 2))
	bag.show_items(products)
	await _frames(2)
	assert_array(bag.find_children("*", "Label", true, false)).is_empty()
	for node: Node in bag.find_children("*", "Control", true, false):
		assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for item: Control in bag.items():
		var peek: Rect2 = item.get_global_rect()
		assert_bool(stage.encloses(peek)).override_failure_message(str(peek)).is_true()
		assert_float(peek.position.x).is_greater_equal(rect.position.x)
		assert_float(peek.end.x).is_less_equal(rect.end.x)
		assert_float(peek.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
		assert_bool(peek.intersects(receipt)).is_false()
		assert_bool(peek.intersects(belt)).is_false()
	var mouth: Rect2 = bag.mouth_rect()
	assert_bool(rect.encloses(mouth)).is_true()
	bag.clear()


## The shade starts under the top bar wherever the stage sits, so Cart and the menu stay
## reachable behind the deck view: nothing over them takes their clicks.
func test_the_shade_leaves_the_top_bar_uncovered() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	assert_bool(screen._deck_view.visible).is_true()
	var shade: Rect2 = screen._shade.get_global_rect()
	var top_bar: TopBar = screen._stage.top_bar
	for button: Control in [screen._deck_button, top_bar.menu_button, screen._loyalty_card]:
		assert_bool(shade.intersects(button.get_global_rect())).is_false()
		(
			assert_bool(screen._deck_view.get_global_rect().intersects(button.get_global_rect()))
			. is_false()
		)
	assert_float(shade.position.y).is_equal(
		screen._stage.get_global_rect().position.y + ShiftStage.PANEL_TOP
	)
	# Nothing over Cart or the menu button takes their clicks; the menu opens over everything
	# (its own popup window), Export log in it.
	for button: Control in [screen._deck_button, top_bar.menu_button]:
		assert_array(_blockers(screen, button)).is_empty()
	# The hand under the shade is out of reach (the check finds what covers it).
	assert_array(_blockers(screen, screen._hand_box.cards()[0])).is_not_empty()
	top_bar.menu_button.pressed.emit()
	await _frames(2)
	assert_bool(top_bar.menu.visible).is_true()
	assert_bool(top_bar.export_button.is_visible_in_tree()).is_true()
	top_bar.menu.hide()


## The top bar with its longest texts (#80 step 10): the last shift's quota with a 4-digit
## subtotal and the quota check, a 4-box loyalty chip, each inspection's chip (the longest name
## included), a full cart and a 10-digit seed. The chips stay on the stage above the shade line,
## apart and in B2's order (QUOTA, week, day, LOYALTY, Cart, menu; no SHIFT chip with weeks since
## v0.82), each holding its text
## and icons; the quota bar keeps its room; the seed and build label stay under Redraw, clear of
## the hand, the keys and the receipt.
func test_the_top_bar_fits_its_longest_texts() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar_bottom: float = stage.position.y + ShiftStage.PANEL_TOP
	run.upgrades = _upgrades(["coupon_engine", "slot_engine", "category_engine", "rule_bender"])
	run.run_seed = 4294967295
	var last: int = run.shift_count() - 1
	run.debug_skip_to_shift(last)
	var largest: int = 0
	for quota: int in run.balance.quotas:
		largest = maxi(largest, quota)
	var inspections: Array[InspectionDefinition] = _all_inspections()
	assert_int(inspections.size()).is_greater_equal(2)
	for inspection: InspectionDefinition in inspections:
		run.inspections = [inspection]
		run.debug_skip_to_shift(last)  # The same shift: it keeps the inspection.
		screen._on_shift_started()
		var deck_limit: int = run.balance.deck_limit
		screen._deck_button.caption = "Cart %d/%d" % [deck_limit, deck_limit]
		# The widest quota chip: a 4-digit subtotal past the quota, with its flag.
		screen._led.start_count(largest)
		screen._led.show_subtotal(9999, true)
		await _frames(2)
		var top_bar: TopBar = screen._stage.top_bar
		# Rush hour's and Quiet morning's quota percent (v0.69) change the quota shown, on top of
		# the last week's (v0.70, Holiday rush's +15%).
		var week: WeekEventDefinition = WeekSchedule.event_for(run.balance, last + 1)
		var percent: int = inspection.quota_percent + week.quota_percent
		var shown: int = ShiftLimits.with_percent(largest, percent)
		assert_str(screen._quota_label.text).is_equal(QuotaMeter.QUOTA_AMOUNT % shown)
		assert_str(top_bar.quota_meter.amount_label.text).is_equal("€9999")
		assert_bool(top_bar.quota_meter.flag_shown()).is_true()
		assert_int(screen._loyalty_card.box_texts().size()).is_equal(4)
		# A boon's chip (v0.69) reads "Today: name — effect".
		var chip_text: String = (
			"Today: %s — %s" % [inspection.display_name, inspection.chip_text]
			if inspection.is_boon()
			else "Inspection · %s" % inspection.chip_text
		)
		assert_str(screen._inspection_tag.text()).is_equal(chip_text)
		# With weeks the SHIFT chip is gone past the training week (v0.82).
		assert_bool(top_bar.shift_chip.visible).is_false()
		var parts: Array[Control] = [
			screen._top_bar.get_child(1) as Control,
			top_bar.week_chip,
			screen._inspection_tag,
			screen._loyalty_card,
			screen._deck_button,
			top_bar.menu_button,
		]
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			assert_bool(part.visible).is_true()
			assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_float(rect.end.y).is_less_equal(bar_bottom)
			assert_float(rect.end.y).is_less_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
			# Nothing is squeezed below what its text needs.
			var needed: Vector2 = part.get_combined_minimum_size()
			assert_bool(rect.size.x >= needed.x and rect.size.y >= needed.y).is_true()
			# Every text and icon in a chip lies inside it.
			for inner: Control in _texts(part) + _icons(part):
				if not inner.is_visible_in_tree():
					continue  # E.g. the training week's hint, hidden on the last shift.
				var inside: Rect2 = inner.get_global_rect()
				(
					assert_bool(rect.encloses(inside))
					. override_failure_message("%s: %s" % [inner.get_path(), inside])
					. is_true()
				)
		_assert_apart(parts)
		for index: int in range(1, parts.size()):
			assert_float(parts[index].get_global_rect().position.x).is_greater(
				parts[index - 1].get_global_rect().end.x
			)
		var meter_bar: Control = top_bar.quota_meter.bar()
		assert_float(meter_bar.size.x).is_greater_equal(QuotaMeter.BAR_MIN_WIDTH)

	var seed_line: Rect2 = screen._seed_label.get_global_rect()
	assert_str(screen._seed_label.text).contains("4294967295")
	var build_label: String = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	assert_str(screen._seed_label.text).contains(build_label)
	assert_bool(stage.encloses(seed_line)).override_failure_message(str(seed_line)).is_true()
	var others: Array[Control] = [
		screen._receipt, screen._checkout_button, screen._redraw_button, screen._cancel_button
	]
	others.append_array(screen._hand_box.cards())
	for other: Control in others:
		assert_bool(seed_line.intersects(other.get_global_rect())).is_false()


## The receipt stands on the printer's slot and grows up as its lines print: a short receipt is
## as tall as its lines; a long one stops at RECEIPT_TOP, under the top bar, still standing on the
## slot, and clear of the monitor.
func test_the_receipt_grows_up_from_the_printer() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	var receipt: ReceiptView = screen._receipt
	var bottom: float = stage.position.y + ShiftStage.RECEIPT_BOTTOM
	assert_float(receipt.get_global_rect().end.y).is_equal(bottom)
	assert_float(receipt.size.y).is_equal_approx(receipt.natural_height(), 1.0)
	var short_top: float = receipt.get_global_rect().position.y
	receipt.add_line("LINE", "€1", ReceiptView.LineStyle.ITEM)
	await _frames(2)
	assert_float(receipt.get_global_rect().end.y).is_equal(bottom)
	assert_float(receipt.get_global_rect().position.y).is_less(short_top)
	while receipt.natural_height() <= ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP:
		receipt.add_line("LINE", "€1", ReceiptView.LineStyle.ITEM)
		await _frames(1)
	receipt.add_line("LINE", "€1", ReceiptView.LineStyle.ITEM)
	await _frames(2)
	var rect: Rect2 = receipt.get_global_rect()
	assert_float(rect.end.y).is_equal(bottom)
	assert_float(rect.position.y).is_equal(stage.position.y + ShiftStage.RECEIPT_TOP)
	assert_float(rect.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	assert_bool(rect.intersects(_on_stage(screen, ShiftStage.MONITOR_RECT))).is_false()


## The longest notice on the monitor (planning's, on its strip), the checkout column's caption,
## number and status line, and the register stay on the stage, clear of the belt, the hand and the
## receipt where they must, on shifts that close slots.
func test_the_status_line_and_the_register_stay_clear() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	screen._debug.give_upgrade("big_basket")
	for inspection_id: String in ["short_belt"]:
		run.inspections = [load("res://data/inspections/%s.tres" % inspection_id)]
		run.debug_skip_to_shift(run.shift_index)
		screen._on_shift_started()
		screen._notice_label.show_notice("Row full (8/8 items): take an item out first")
		screen._quota_meter.show_projected(999, run.quota())
		await _frames(2)
		assert_int(screen._row_strip.closed.size()).is_equal(1)
		_assert_status_clear(screen)


## Every Redraw caption the run can show fits REDRAW_RECT without growing it, with every upgrade
## that adds redraws: "Redraw" with its "M left" note for each M, "Redraw used", "Redraw" with
## "none to draw" (an empty draw pile) and, in redraw mode (plan section 3.8), "Pick a basket"
## with its "M left" note, held lit, for each M. The note sits beside the caption, on the
## key's face, smaller; Redraw keeps its rect on the register column, clear of Cancel and
## CHECKOUT.
func test_every_redraw_caption_fits() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var extra_redraws: int = 0
	for upgrade: UpgradeDefinition in _all_upgrades():
		if upgrade.extra_redraws > 0:
			run.upgrades.append(upgrade)
			extra_redraws += upgrade.extra_redraws
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	assert_int(extra_redraws).is_greater(0)
	assert_int(run.redraws_allowed).is_equal(run.balance.base_redraws + extra_redraws)
	var captions: PackedStringArray = PackedStringArray()
	for used: int in range(run.redraws_allowed, -1, -1):
		run.redraws_used = used
		screen._refresh_buttons()
		captions.append("%s %s" % [screen._redraw_button.caption, screen._redraw_button.note()])
		await _assert_redraw_in_place(screen)
	assert_str(";".join(captions)).contains("Redraw %d left" % run.redraws_allowed)
	assert_str(";".join(captions)).contains("Redraw used")
	for used: int in range(run.redraws_allowed):
		run.redraws_used = used
		screen._refresh()
		screen._on_redraw_pressed()
		assert_bool(screen._cancel_button.visible).is_true()
		assert_str(screen._redraw_button.caption).is_equal("Pick a basket")
		assert_int(screen._redraw_button.look()).is_equal(RegisterKey.Look.LIT)
		captions.append("%s %s" % [screen._redraw_button.caption, screen._redraw_button.note()])
		await _assert_redraw_in_place(screen)
		screen._on_cancel_pressed()
	assert_str(";".join(captions)).contains("Pick a basket %d left" % run.redraws_allowed)
	assert_int(screen._redraw_button.look()).is_not_equal(RegisterKey.Look.LIT)
	# An empty draw pile: nothing to draw.
	run.redraws_used = 0
	while not run.deck.draw_pile().is_empty():
		run.deck.redraw_places([0])
	screen._refresh_buttons()
	assert_str(screen._redraw_button.note()).is_equal("none to draw")
	assert_bool(screen._redraw_button.disabled).is_true()
	await _assert_redraw_in_place(screen)


func _assert_redraw_in_place(screen: ShiftScreen) -> void:
	await _frames(1)
	var button: RegisterKey = screen._redraw_button
	var needed: Vector2 = button.get_combined_minimum_size()
	(
		assert_bool(needed.x <= ShiftStage.REDRAW_RECT.size.x)
		. override_failure_message("'%s %s' needs %s" % [button.caption, button.note(), needed])
		. is_true()
	)
	var caption: Rect2 = button.caption_label().get_global_rect()
	var caption_width: float = button.caption_label().get_minimum_size().x
	assert_float(caption.size.x).is_greater_equal(caption_width - 0.5)
	if not button.note().is_empty():
		var note_label: Label = button.note_label()
		var note: Rect2 = note_label.get_global_rect()
		assert_bool(note_label.visible).is_true()
		(
			assert_bool(button.get_global_rect().encloses(note))
			. override_failure_message(str(note))
			. is_true()
		)
		assert_float(note.position.x).is_greater_equal(caption.end.x)
		assert_float(note.size.x).is_greater_equal(note_label.get_minimum_size().x - 0.5)
		assert_int(note_label.get_theme_font_size("font_size")).is_less(
			button.caption_label().get_theme_font_size("font_size")
		)
		# The pair is centred on the face.
		var middle: float = (caption.position.x + note.end.x) / 2.0
		assert_float(middle).is_equal_approx(button.get_global_rect().get_center().x, 1.0)
	elif button.note_label() != null:
		assert_bool(button.note_label().visible).is_false()
	assert_that(button.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.REDRAW_RECT))
	var others: Array[Control] = [screen._checkout_button]
	if screen._cancel_button.visible:
		others.append(screen._cancel_button)
	for other: Control in others:
		assert_bool(button.get_global_rect().intersects(other.get_global_rect())).is_false()
	(
		assert_bool(_on_stage(screen, ShiftStage.COLUMN_RECT).encloses(button.get_global_rect()))
		. is_true()
	)


## The wall and the counter cover the whole viewport, whatever its shape, and the top band and
## the floor span it.
func test_the_wall_and_counter_cover_the_viewport() -> void:
	var screen: ShiftScreen = await _screen()
	var window: Rect2 = screen.get_viewport_rect()
	var content: Control = screen._camera.content
	var wall: Rect2 = screen._wall.get_global_rect()
	var counter: Rect2 = (content.get_node("Counter") as Control).get_global_rect()
	assert_bool(wall.encloses(window)).is_true()
	var bands: Array[Control] = [screen.get_node("TopBand"), content.get_node("Floor")]
	for band_control: Control in bands:
		var band: Rect2 = band_control.get_global_rect()
		assert_float(band.position.x).is_less_equal(window.position.x)
		assert_float(band.end.x).is_greater_equal(window.end.x)
	assert_float(counter.position.x).is_less_equal(window.position.x)
	assert_float(counter.end.x).is_greater_equal(window.end.x)
	assert_float(counter.end.y).is_greater_equal(window.end.y)
	# The counter starts at the stage's counter line, wherever the stage sits.
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(counter.position.y).is_equal(stage.position.y + ShiftStage.COUNTER_TOP)


## Text never goes through the sharp-pixel shader: no Label or Button text carries its material
## or the pixel-art mark (the gold number's own gold-bands shader aside).
func test_no_text_carries_the_pixel_material() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var texts: Array[Control] = _texts(screen)
	assert_int(texts.size()).is_greater(20)
	for text: Control in texts:
		# The checkout column's gold number has its gold-bands shader (TotalNumber), no other.
		var gold: bool = (
			text.material is ShaderMaterial
			and (text.material as ShaderMaterial).shader == TotalNumber.SHADER
		)
		if gold:
			continue
		(
			assert_object(text.material)
			. override_failure_message("%s has a material" % text.get_path())
			. is_null()
		)
		assert_bool(text.use_parent_material).is_false()
		assert_bool(text.has_meta(ArtStyle.PIXEL_ART_META)).is_false()


## Numbers and money use the number font: text on the stage or overlay without a font of its
## own (the count-up's flying numbers), the shift and quota, the checkout column's number and the
## paid chips.
func test_numbers_use_the_number_font() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var number_font: Font = ArtStyle.number_font()
	var loose: Label = Label.new()
	screen._overlay.add_child(loose)
	assert_object(loose.get_theme_default_font()).is_same(number_font)
	assert_object(loose.get_theme_font("font")).is_same(number_font)
	# The screen's root keeps the plain default font (ShiftDebug, the panels #56 restyles).
	var plain: Label = Label.new()
	screen.add_child(plain)
	assert_object(plain.get_theme_default_font()).is_not_same(number_font)
	plain.queue_free()
	var numbers: Array[Label] = [
		screen._shift_label,
		screen._quota_label,
		screen._monitor.checkout().total_number().slam_label(),
		screen._deck_button.caption_label(),
		screen._redraw_button.note_label(),
	]
	assert_int(screen._row_views.size()).is_greater(0)
	# The paid chips show only in the count-up (#80, step 7), in the number font all the same.
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_false()
		numbers.append(view.badge)
	for label: Label in numbers:
		(
			assert_object(label.get_theme_font("font"))
			. override_failure_message("%s: %s" % [label.get_path(), label.text])
			. is_same(number_font)
		)


## Every character the screen prints is in the font that prints it, including "−" (U+2212) on
## the inspection chip and the receipt's end-of-shift lines.
func test_every_printed_character_has_its_glyph() -> void:
	var screen: ShiftScreen = await _rich_screen()
	assert_str(screen._inspection_tag.text()).contains("−")
	var checked: int = 0
	for text: Control in _texts(screen):
		var label: Label = text as Label
		if label == null:
			continue
		var font: Font = label.get_theme_font("font")
		for character: String in label.text:
			if character.strip_edges().is_empty():
				continue
			var code: int = character.unicode_at(0)
			checked += 1
			(
				assert_bool(font.has_char(code))
				. override_failure_message(
					"%s lacks '%s' (U+%04X) in %s" % [font, character, code, label.get_path()]
				)
				. is_true()
			)
	assert_int(checked).is_greater(200)
	var fonts: Array[Font] = [
		ArtStyle.DISPLAY_FONT, ArtStyle.BODY_FONT, ArtStyle.number_font(), ArtStyle.MONO_FONT
	]
	for font: Font in fonts:
		for character: String in ArtStyle.REQUIRED_GLYPHS:
			assert_bool(font.has_char(character.unicode_at(0))).is_true()


## The sharp-pixel shader switches off (plain nearest filtering) and back on across the whole
## screen (ArtStyle.set_sharp, the capture scene's S key).
func test_the_shader_switches_off_and_on() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var marked: Array[CanvasItem] = _pixel_art(screen)
	assert_int(marked.size()).is_greater(10)
	# A grey or a halo (#71) is the node's look (ArtStyle.set_look), kept in both modes.
	for item: CanvasItem in marked:
		assert_object(item.material).is_same(_look(item, ArtStyle.pixel_material()))
	ArtStyle.set_sharp(screen, false)
	for item: CanvasItem in marked:
		if item.has_meta(ArtStyle.LOOK_META):
			assert_object(item.material).is_same(_look(item, null))
		else:
			assert_object(item.material).is_null()
		assert_int(item.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	ArtStyle.set_sharp(screen, true)
	for item: CanvasItem in marked:
		assert_object(item.material).is_same(_look(item, ArtStyle.pixel_material()))
		assert_int(item.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_PARENT_NODE)


# --- Helpers ---------------------------------------------------------------------------------


## `item`'s look material (ArtStyle.set_look), else `plain`.
static func _look(item: CanvasItem, plain: Material) -> Material:
	if item.has_meta(ArtStyle.LOOK_META):
		return item.get_meta(ArtStyle.LOOK_META) as Material
	return plain


## The checkout column's number (its ink, punched or not: the line box is taller than the ink)
## inside the column, under its caption's text and above its ladder (#105 piece 2).
func _assert_digits_clear(screen: ShiftScreen) -> void:
	var column: CheckoutColumn = screen._monitor.checkout()
	var ink: Rect2 = column.total_number().ink_rect()
	var room: Rect2 = _on_stage(screen, MonitorView.CHECKOUT_RECT)
	assert_bool(room.encloses(ink)).override_failure_message("%s in %s" % [ink, room]).is_true()
	var caption: Label = column.caption()
	var font: Font = caption.get_theme_font("font")
	var font_size: int = caption.get_theme_font_size("font_size")
	var caption_ink: Vector2 = TotalNumber.ink_span(caption.text, font, font_size)
	var caption_line: float = (caption.size.y - font.get_height(font_size)) / 2.0
	var caption_bottom: float = (
		caption.get_global_rect().position.y
		+ caption_line
		+ font.get_ascent(font_size)
		+ caption_ink.y
	)
	assert_float(ink.position.y).is_greater_equal(caption_bottom)
	assert_float(ink.end.y).is_less_equal(column.ladder().get_global_rect().position.y)


## Rects that must not overlap one another.
func _assert_apart_rects(rects: Array[Rect2]) -> void:
	for index: int in range(rects.size()):
		for other: int in range(index + 1, rects.size()):
			(
				assert_bool(rects[index].intersects(rects[other]))
				. override_failure_message("%s on %s" % [rects[index], rects[other]])
				. is_false()
			)


## A shift with a bit of everything: an inspection that closes a slot (its top-bar chip prints
## "−"), placed cards, 4 stamped boxes and the receipt's end-of-shift lines.
func _rich_screen() -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	run.upgrades = _upgrades(["coupon_engine", "slot_engine", "category_engine", "rule_bender"])
	run.inspections = [SHORT_BELT]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	_place(screen, ["bread", "milk", "eggs", "repeat"])
	screen._notice_label.show_notice("Row full (9/9 items): take an item out first")
	var result: ScoreResult = run.preview()
	screen._receipt.show_shift_end(result.total, run.quota())
	await _frames(2)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % card_id))
		assert_bool(run.place(card, run.row.size())).is_true()
	screen._refresh()


func _assert_status_clear(screen: ShiftScreen) -> void:
	var stage: Rect2 = screen._stage.get_global_rect()
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	var hand: Rect2 = screen._hand_box.get_global_rect()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var places: Dictionary[Control, Rect2] = {
		screen._notice_label: MonitorView.NOTICE_RECT,
	}
	for part: Control in places:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		var inside: Rect2 = _on_stage(screen, places[part])
		assert_bool(inside.encloses(rect)).override_failure_message(str(rect)).is_true()
		for other: Rect2 in [belt, hand, receipt]:
			(
				assert_bool(rect.intersects(other))
				. override_failure_message("%s %s overlaps %s" % [part.get_path(), rect, other])
				. is_false()
			)
		# The text fits its label.
		var needed: Vector2 = part.get_minimum_size()
		(
			assert_bool(needed.x <= rect.size.x and needed.y <= rect.size.y)
			. override_failure_message("%s needs %s in %s" % [part.get_path(), needed, rect.size])
			. is_true()
		)
	_assert_digits_clear(screen)
	var register: Rect2 = screen._register.get_global_rect()
	assert_bool(stage.encloses(register)).override_failure_message(str(register)).is_true()
	assert_bool(register.intersects(hand)).is_false()
	assert_bool(register.intersects(belt)).is_false()


## Every Label and Button under `node` (text on screen, wherever it is).
static func _texts(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Label or node is Button:
		result.append(node as Control)
	for child: Node in node.get_children():
		result.append_array(_texts(child))
	return result


static func _pixel_art(node: Node) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	var item: CanvasItem = node as CanvasItem
	if item != null and item.has_meta(ArtStyle.PIXEL_ART_META):
		result.append(item)
	for child: Node in node.get_children():
		result.append_array(_pixel_art(child))
	return result


static func _upgrades(ids: Array[String]) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for upgrade_id: String in ids:
		result.append(load("res://data/upgrades/%s.tres" % upgrade_id) as UpgradeDefinition)
	return result


static func _all_upgrades() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	var folder: String = "res://data/upgrades"
	for file_name: String in ResourceLoader.list_directory(folder):
		if file_name.ends_with(".tres"):
			result.append(load(folder.path_join(file_name)) as UpgradeDefinition)
	return result


static func _all_inspections() -> Array[InspectionDefinition]:
	var result: Array[InspectionDefinition] = []
	var folder: String = "res://data/inspections"
	for file_name: String in ResourceLoader.list_directory(folder):
		if file_name.ends_with(".tres"):
			result.append(load(folder.path_join(file_name)) as InspectionDefinition)
	return result


## The screen on shift 1, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _assert_apart(controls: Array[Control]) -> void:
	for first: int in range(controls.size()):
		for second: int in range(first + 1, controls.size()):
			var a: Rect2 = controls[first].get_global_rect()
			var b: Rect2 = controls[second].get_global_rect()
			(
				assert_bool(a.intersects(b))
				. override_failure_message("%s overlaps %s" % [a, b])
				. is_false()
			)


## The TextureRects under `node` (the chips' icons, rings and checks).
static func _icons(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in node.get_children(true):
		if child is TextureRect and (child as Control).visible:
			result.append(child as Control)
		result.append_array(_icons(child))
	return result


## The controls that would take a click at `target`'s centre before it: those after it in the
## tree (drawn and picked over it), outside it, shown, not ignoring the mouse, under the point.
static func _blockers(screen: ShiftScreen, target: Control) -> Array[String]:
	var point: Vector2 = target.get_global_rect().get_center()
	var result: Array[String] = []
	var past_target: bool = false
	for node: Node in screen.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control == target:
			past_target = true
			continue
		if not past_target or target.is_ancestor_of(control) or not control.is_visible_in_tree():
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.get_global_rect().has_point(point):
			result.append(str(control.get_path()))
	return result


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
