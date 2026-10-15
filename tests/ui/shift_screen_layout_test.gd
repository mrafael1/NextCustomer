extends GdUnitTestSuite
## The shift screen's layout (#55, ShiftStage) on the real screen: the 1280x720 stage centred in
## the window (headless runs use 1280x1280, so it sits 280 px down) over a wall and a counter that
## cover the viewport; the top bar with its longest texts above the shade; the fixed belt (its
## rows: shift_screen_belt_test); the register with the totals on its LED
## and the receipt hanging from its printer slot, joined to the paper pile; the docked scanner;
## the status panel, Cancel, Redraw (every caption fits) and CHECKOUT on the counter above a hand
## of 8 items that fits the tray without overlapping; past 8, hover bringing an item to the front
## by child order, so it takes the click; the drag ghost (the item's sprite); the hint and the
## seed line in the bottom band. Every rect is checked on screen against the stage and against
## the layout's constants. Also the style checks:
## no text carries the pixel material, numbers use the number font, every printed character has
## its glyph, and the sharp-pixel shader switches off and on. The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SHORT_BELT := preload("res://data/inspections/short_belt.tres")
## The kickplate's top (the window's bottom 12 px, at 1280x720): nothing on the stage reaches it.
const KICKPLATE_TOP := 708.0
## The tray's velvet rim, in canvas pixels (style frame v2): the hand's items stay inside it.
const TRAY_RIM := 6.0

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
	# The wall fills the window behind the stage; the counter runs from its top to the bottom.
	var wall: Control = screen.get_child(0) as Control
	assert_that(wall.get_global_rect()).is_equal(window)
	var counter: Control = screen.get_child(1) as Control
	assert_float(counter.get_global_rect().position.y).is_equal(
		stage.position.y + ShiftStage.COUNTER_TOP
	)
	assert_float(counter.get_global_rect().end.y).is_greater_equal(window.end.y)

	var bar_bottom: float = stage.position.y + RewardPanel.PRINTOUT_TOP
	var top_parts: Array[Control] = []
	for child: Node in screen._top_bar.get_children():
		var part: Control = child as Control
		if part.visible and (part is PanelContainer or part is Button):
			top_parts.append(part)
	assert_int(top_parts.size()).is_greater_equal(4)
	for part: Control in top_parts:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.y).is_less_equal(bar_bottom)
	_assert_apart(top_parts)

	# The belt and the register stand on the counter line, side by side; the receipt hangs from
	# the printer slot and ends at the pile's foot.
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	var register: Rect2 = screen._register.get_global_rect()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_that(belt).is_equal(_on_stage(screen, ShiftStage.BELT_RECT))
	assert_that(register).is_equal(_on_stage(screen, ShiftStage.REGISTER_RECT))
	var counter_top: float = stage.position.y + ShiftStage.COUNTER_TOP
	assert_float(belt.end.y).is_equal(counter_top)
	assert_float(register.end.y).is_equal(counter_top)
	assert_float(belt.position.y).is_greater_equal(bar_bottom)
	assert_float(register.position.y).is_greater_equal(bar_bottom)
	assert_bool(belt.intersects(register)).is_false()
	assert_bool(stage.encloses(register)).is_true()
	assert_bool(stage.encloses(receipt)).override_failure_message(str(receipt)).is_true()
	# The printer slot spans the cabinet between its frame's inner edges (style frame v2's
	# proportions); the receipt hangs from its mouth, RECEIPT_MOUTH_GAP inside it at each side.
	var slot: Rect2 = _on_stage(screen, ShiftStage.PRINTER_SLOT_RECT)
	assert_that(ShiftStage.PRINTER_SLOT_RECT).is_equal(Rect2(952, 264, 304, 16))
	assert_bool(register.encloses(slot)).is_true()
	var frame: float = RegisterCabinet.BODY_MARGIN * ArtStyle.ART_SCALE
	assert_float(slot.position.x).is_equal(register.position.x + frame)
	assert_float(slot.end.x).is_equal(register.end.x - frame)
	var mouth: Rect2 = slot.grow_individual(
		-RegisterCabinet.PRINTER_SLOT_INSET, 0, -RegisterCabinet.PRINTER_SLOT_INSET, 0
	)
	assert_float(receipt.position.y).is_equal(slot.end.y)
	assert_float(receipt.position.x).is_equal(mouth.position.x + ShiftStage.RECEIPT_MOUTH_GAP)
	assert_float(receipt.end.x).is_equal(mouth.end.x - ShiftStage.RECEIPT_MOUTH_GAP)
	assert_float(receipt.size.x).is_equal(ShiftStage.RECEIPT_WIDTH)
	assert_vector(ShiftStage.RECEIPT_ORIGIN).is_equal(Vector2(966, 280))
	assert_float(ShiftStage.RECEIPT_WIDTH).is_equal(276.0)
	assert_float(receipt.end.y).is_less_equal(stage.position.y + ShiftStage.PILE_BOTTOM)
	assert_float(receipt.end.y).is_less_equal(stage.position.y + KICKPLATE_TOP)
	# The LED (the totals) sits on the register, its caption, digits and quota line on it, the
	# digits and the quota line apart; the key bed and the TOTAL key under it, above the slot.
	var led: Rect2 = _on_stage(screen, ShiftStage.LED_RECT)
	assert_that(screen._led.get_global_rect()).is_equal(led)
	assert_bool(register.encloses(led)).is_true()
	for label: Control in _led_labels(screen):
		var rect: Rect2 = label.get_global_rect()
		assert_bool(led.encloses(rect)).override_failure_message(str(rect)).is_true()
	_assert_digits_clear(screen)
	var keys: Rect2 = _on_stage(screen, ShiftStage.KEYS_RECT)
	var total_key: Rect2 = screen._cabinet.total_key().get_global_rect()
	assert_that(total_key).is_equal(_on_stage(screen, ShiftStage.TOTAL_KEY_RECT))
	assert_bool(register.encloses(keys)).is_true()
	assert_bool(keys.encloses(total_key)).is_true()
	assert_float(keys.position.y).is_greater_equal(led.end.y)
	# A strip of cream between the key bed and the slot's lip.
	assert_float(keys.end.y).is_less(slot.position.y)

	var scanner: Rect2 = screen._stage.scanner.get_global_rect()
	assert_that(scanner).is_equal(_on_stage(screen, ShiftStage.CRADLE_RECT))
	assert_bool(stage.encloses(scanner)).is_true()
	assert_bool(scanner.intersects(register)).is_false()
	assert_bool(scanner.intersects(screen._checkout_button.get_global_rect())).is_false()
	for panel: PanelContainer in screen._slots:
		var rect: Rect2 = panel.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(belt.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(receipt)).is_false()
		assert_bool(rect.intersects(scanner)).is_false()
		# Under the top bar: the value plaques stand inside the cells, on the mats' top rims.
		assert_float(rect.position.y).is_greater_equal(bar_bottom)
	assert_vector(screen._slots[0].get_global_rect().position).is_equal(
		stage.position + ShiftStage.ROW_POSITION
	)

	# The status panel's lines sit on the counter, inside the panel, the capacity line and the
	# cue apart.
	var cue: Label = _label_with(screen._stage, ShiftStage.CUE_TEXT)
	var status_rect: Rect2 = _on_stage(screen, ShiftStage.STATUS_RECT)
	assert_float(status_rect.position.y).is_greater_equal(counter_top)
	for label: Control in [screen._capacity_label, cue, screen._notice_label]:
		var rect: Rect2 = label.get_global_rect()
		assert_bool(status_rect.encloses(rect)).override_failure_message(str(rect)).is_true()
	_assert_apart([screen._capacity_label, cue])

	# Cancel, Redraw, CHECKOUT and the scanner beside the status panel, above the hand, apart.
	var hand: Rect2 = screen._hand_box.get_global_rect()
	assert_that(hand).is_equal(_on_stage(screen, ShiftStage.HAND_RECT))
	assert_bool(_on_stage(screen, ShiftStage.TRAY_RECT).encloses(hand)).is_true()
	var expected: Dictionary[Control, Rect2] = {
		screen._cancel_button: ShiftStage.CANCEL_RECT,
		screen._redraw_button: ShiftStage.REDRAW_RECT,
		screen._checkout_button: ShiftStage.CHECKOUT_RECT,
	}
	var strip: Array[Control] = [screen._stage.scanner]
	for part: Control in expected:
		assert_that(part.get_global_rect()).is_equal(_on_stage(screen, expected[part]))
		strip.append(part)
	_assert_apart(strip)
	for part: Control in strip:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.position.y).is_greater_equal(counter_top)
		# The strip ends above the tray, which holds a selected item's lift and brackets.
		assert_float(rect.end.y).is_less_equal(_on_stage(screen, ShiftStage.TRAY_RECT).position.y)
		assert_float(rect.end.x).is_less_equal(register.position.x)
		if part != screen._cancel_button:
			assert_bool(rect.intersects(status_rect)).is_false()

	# The bottom band: the hint in its inset under the tray, then the seed line above the
	# kickplate, clear of the hint.
	var hint: Label = screen._stage.hint_label
	var hint_rect: Rect2 = hint.get_global_rect()
	(
		assert_bool(_on_stage(screen, ShiftStage.HINT_RECT).encloses(hint_rect))
		. override_failure_message("hint at %s needs %s" % [hint_rect, hint.get_minimum_size()])
		. is_true()
	)
	assert_float(hint_rect.position.y).is_greater_equal(
		stage.position.y + ShiftStage.TRAY_RECT.end.y
	)
	assert_float(hint.get_minimum_size().y).is_less_equal(hint.size.y)
	assert_float(hint.get_minimum_size().x).is_less_equal(hint.size.x)
	var seed_rect: Rect2 = screen._seed_label.get_global_rect()
	assert_that(seed_rect).is_equal(_on_stage(screen, ShiftStage.SEED_RECT))
	assert_float(screen._seed_label.get_minimum_size().y).is_less_equal(seed_rect.size.y)
	assert_float(seed_rect.position.y).is_greater_equal(hand.end.y)
	assert_float(seed_rect.end.y).is_less_equal(stage.position.y + KICKPLATE_TOP)
	assert_bool(seed_rect.intersects(hint_rect)).is_false()
	assert_float(seed_rect.end.x).is_less_equal(stage.position.x + ShiftStage.PURSE_RECT.position.x)
	assert_str(screen._seed_label.text).contains("Seed %d" % screen.run.run_seed)
	# Shift 1's planning receipt is short and the pile empty: no pile on the counter.
	assert_bool(screen._paper_pile.visible).is_false()


## A full hand of 8 fits the tray at the natural pitch (style frame v2): each item in its
## ItemView.TRAY_SIZE cell inside the tray's velvet rim, GAP apart, none overlapping, all left of
## the receipt. Debug-added items (10) squeeze closer, still inside the rim, and an overlap never
## covers an item's base value.
func test_a_hand_of_eight_fits_without_overlap() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(8)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var inside_rim: Rect2 = _on_stage(screen, ShiftStage.TRAY_RECT).grow(-TRAY_RIM)
	assert_bool(screen._hand_box.overlaps()).is_false()
	for index: int in range(views.size()):
		var view: ItemView = views[index] as ItemView
		assert_object(view).is_not_null()
		assert_int(view.form).is_equal(ItemView.Form.TRAY)
		var rect: Rect2 = view.get_global_rect()
		assert_vector(rect.size).is_equal(ItemView.TRAY_SIZE)
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(inside_rim.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.x).is_less_equal(receipt.position.x)
		if index > 0:
			var previous: Rect2 = views[index - 1].get_global_rect()
			assert_float(rect.position.x - previous.position.x).is_equal(
				ItemView.TRAY_SIZE.x + HandRow.GAP
			)
			assert_bool(previous.intersects(rect)).is_false()
	assert_float(HandRow.step_for(8, ShiftStage.HAND_RECT.size.x)).is_equal(
		ItemView.TRAY_SIZE.x + HandRow.GAP
	)
	assert_float(HandRow.step_for(9, ShiftStage.HAND_RECT.size.x)).is_less(ItemView.TRAY_SIZE.x)
	# Debug-added items still fit, closer together.
	screen._debug.add_card("bread")
	screen._debug.add_card("bread")
	await _frames(2)
	views = screen._hand_box.cards()
	assert_int(views.size()).is_equal(10)
	assert_bool(screen._hand_box.overlaps()).is_true()
	for index: int in range(views.size()):
		var view: ItemView = views[index] as ItemView
		assert_bool(inside_rim.encloses(view.get_global_rect())).is_true()
		# No item drawn above covers its base value (or COUPON), at the sticker's left.
		var base: Rect2 = view.sticker().get_global_transform() * PriceSticker.BASE_RECT
		for other: Control in views.slice(index + 1):
			var hit: Rect2 = other.get_global_transform() * (other as ItemView).hit_rect()
			(
				assert_bool(base.intersects(hit))
				. override_failure_message("item %d's base value is covered" % index)
				. is_false()
			)


## Hovering an item brings it to the front by child order (clicks follow what is drawn on top)
## only while items overlap (more than 8); leaving it puts the hand order back. A full hand of 8
## keeps its order. A selected item's lifted sprite and its gold brackets stay on the tray.
func test_hover_brings_an_item_to_the_front() -> void:
	var screen: ShiftScreen = await _screen()
	var views: Array[Control] = screen._hand_box.cards()
	views[3].mouse_entered.emit()
	assert_int(views[3].get_index()).is_equal(3)
	views[3].mouse_exited.emit()
	screen._debug.add_card("bread")
	await _frames(2)
	views = screen._hand_box.cards()
	var hovered: Control = views[3]
	hovered.mouse_entered.emit()
	assert_int(hovered.get_index()).is_equal(screen._hand_box.get_child_count() - 1)
	hovered.mouse_exited.emit()
	for index: int in range(views.size()):
		assert_int(views[index].get_index()).is_equal(index)
	screen._on_hand_card_clicked(views[0] as CardView)
	await _frames(2)
	var picked: ItemView = screen._hand_box.cards()[0] as ItemView
	var rest_y: float = picked.get_global_rect().position.y + ItemView.TRAY_SPRITE.y
	var lifted: Rect2 = picked.body.get_global_rect()
	assert_float(lifted.position.y).is_equal(rest_y - ItemView.LIFT)
	var brackets: Rect2 = picked.get_global_transform() * picked.brackets()
	assert_bool(brackets.encloses(lifted)).is_true()
	var tray: Rect2 = _on_stage(screen, ShiftStage.TRAY_RECT)
	assert_bool(tray.encloses(brackets)).override_failure_message(str(brackets)).is_true()


## The shade starts under the top bar wherever the stage sits, so Deck and Export log stay
## reachable.
func test_the_shade_leaves_the_top_bar_uncovered() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	var shade: Rect2 = screen._shade.get_global_rect()
	for button: Control in [screen._deck_button, screen._loyalty_card]:
		assert_bool(shade.intersects(button.get_global_rect())).is_false()
	assert_float(shade.position.y).is_equal(
		screen._stage.get_global_rect().position.y + RewardPanel.PRINTOUT_TOP
	)


## The top bar with its longest texts: the last shift's quota, a 4-box loyalty card, each
## inspection's tag (the longest one included), the FINE GROCERIES plaque, a full deck and a
## 10-digit seed. Everything stays on the stage above the shade line and apart; the seed and
## build label stay in the counter's bottom-left corner, clear of the hand, the buttons and the
## paper pile.
func test_the_top_bar_fits_its_longest_texts() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar_bottom: float = stage.position.y + RewardPanel.PRINTOUT_TOP
	run.upgrades = _upgrades(["coupon_engine", "slot_engine", "category_engine", "rule_bender"])
	run.run_seed = 4294967295
	var last: int = run.shift_count() - 1
	run.debug_skip_to_shift(last)
	var largest: int = 0
	for quota: int in run.balance.quotas:
		largest = maxi(largest, quota)
	var inspections: Array[InspectionDefinition] = _all_inspections()
	assert_int(inspections.size()).is_greater_equal(3)
	for inspection: InspectionDefinition in inspections:
		run.inspections = [inspection]
		run.debug_skip_to_shift(last)  # The same shift: it keeps the inspection.
		screen._on_shift_started()
		var deck_limit: int = run.balance.deck_limit
		screen._deck_button.caption = "Deck %d/%d" % [deck_limit, deck_limit]
		await _frames(2)
		assert_str(screen._quota_label.text).is_equal("€%d" % largest)
		assert_int(screen._loyalty_card.box_texts().size()).is_equal(4)
		assert_str(screen._inspection_tag.text()).contains(inspection.notice_text)
		var parts: Array[Control] = [
			screen._top_bar.get_child(0) as Control,
			screen._loyalty_card,
			screen._inspection_tag,
			screen._stage.plaque,
			screen._deck_button,
			screen._stage.export_button,
		]
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			assert_bool(part.visible).is_true()
			assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_float(rect.end.y).is_less_equal(bar_bottom)
			# Nothing is squeezed below what its text needs.
			var needed: Vector2 = part.get_combined_minimum_size()
			assert_bool(rect.size.x >= needed.x and rect.size.y >= needed.y).is_true()
		_assert_apart(parts)
		var tag_text: Rect2 = (screen._inspection_tag.get_child(0) as Control).get_global_rect()
		assert_bool(screen._inspection_tag.get_global_rect().encloses(tag_text)).is_true()

	var seed_line: Rect2 = screen._seed_label.get_global_rect()
	assert_str(screen._seed_label.text).contains("4294967295")
	var build_label: String = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	assert_str(screen._seed_label.text).contains(build_label)
	assert_bool(stage.encloses(seed_line)).override_failure_message(str(seed_line)).is_true()
	var others: Array[Control] = [screen._receipt, screen._paper_pile, screen._checkout_button]
	others.append_array(screen._hand_box.cards())
	for other: Control in others:
		assert_bool(seed_line.intersects(other.get_global_rect())).is_false()


## A full hand of 8 (with Cancel shown, in redraw mode) stays on the stage, clear of CHECKOUT,
## Redraw, Cancel, the scanner, the hint, the receipt and the paper pile (at its cap, curled and
## spilled), even with an item selected (its sprite lifted inside its brackets).
func test_a_full_hand_clears_the_buttons_and_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	_full_pile(screen)
	screen._on_redraw_pressed()
	await _frames(2)
	assert_bool(screen._cancel_button.visible).is_true()
	var stage: Rect2 = screen._stage.get_global_rect()
	var strip: Array[Control] = [
		screen._stage.hint_label,
		screen._cancel_button,
		screen._redraw_button,
		screen._checkout_button,
		screen._stage.scanner,
	]
	_assert_apart(strip)
	var blockers: Array[Control] = strip.duplicate()
	blockers.append(screen._receipt)
	blockers.append(screen._paper_pile)
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(screen.run.balance.hand_size)
	for view: Control in views:
		assert_vector(view.size).is_equal(ItemView.TRAY_SIZE)
		# A selected item's sprite lifts by LIFT inside its brackets.
		var lifted: Rect2 = Rect2(
			view.global_position + ItemView.TRAY_SPRITE - Vector2(0, ItemView.LIFT),
			ItemView.SPRITE_SIZE
		)
		var rect: Rect2 = view.get_global_rect().merge(lifted.grow(ScanOverlay.BRACKET_OUTSET))
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		for blocker: Control in blockers:
			(
				assert_bool(rect.intersects(blocker.get_global_rect()))
				. override_failure_message("%s overlaps %s" % [rect, blocker])
				. is_false()
			)
	for part: Control in strip:
		assert_bool(stage.encloses(part.get_global_rect())).is_true()


## The paper pile stands joined under the receipt: on the counter at PILE_BOTTOM, its top fold
## spanning exactly the receipt and the later folds FOLD_SHIFT either side; a long receipt ends
## PILE_JOIN under the pile's top (min(PILE_BOTTOM, top + PILE_JOIN): with the empty pile of
## shift 1 that is the pile's foot, above the kickplate). At its cap, curled and spilled, the
## pile stays on the stage, right of the tray, the hand, the purse and CHECKOUT. The pile shows
## only when it has paper and the receipt's lines reach its top: a long receipt or a pile grown
## up to a short receipt's foot.
func test_the_pile_joins_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	var pile: PaperPile = screen._paper_pile
	var receipt: ReceiptView = screen._receipt
	assert_bool(pile.is_joined()).is_true()
	# Shift 1: no paper yet, so no pile; the receipt may run to the pile's foot and no further.
	assert_float(pile.height_px).is_equal(0.0)
	assert_bool(pile.visible).is_false()
	assert_float(screen._stage.receipt_bottom()).is_equal(ShiftStage.PILE_BOTTOM)
	assert_float(ShiftStage.PILE_BOTTOM).is_less_equal(KICKPLATE_TOP)
	# Later shifts' paper under the short planning receipt: still no pile (no lone strip of
	# paper far under the receipt).
	screen._count_up.show_pile_for_shift(6)
	await _frames(2)
	assert_float(pile.height_px).is_greater(0.0)
	assert_bool(screen._stage.receipt_reaches_pile()).is_false()
	assert_bool(pile.visible).is_false()
	# A receipt longer than its room reaches the pile, which shows, joined to it.
	while receipt.natural_height() <= ShiftStage.PILE_BOTTOM - ShiftStage.RECEIPT_ORIGIN.y:
		receipt.add_line("LINE", "€1", ReceiptView.LineStyle.ITEM)
		await _frames(1)
	await _frames(2)
	assert_bool(screen._stage.receipt_reaches_pile()).is_true()
	assert_bool(pile.visible).is_true()
	var rect: Rect2 = receipt.get_global_rect()
	var paper: Rect2 = pile.paper_rect()
	assert_float(paper.end.y).is_equal(stage.position.y + ShiftStage.PILE_BOTTOM)
	assert_float(rect.end.y).is_equal(paper.position.y + ShiftStage.PILE_JOIN)
	assert_float(pile.top_y()).is_equal(paper.position.y - stage.position.y)
	var top_fold: Rect2 = pile.get_global_transform() * pile.fold_rect(0)
	assert_float(top_fold.position.x).is_equal(rect.position.x)
	assert_float(top_fold.end.x).is_equal(rect.end.x)
	assert_int(pile.fold_count()).is_greater_equal(3)
	assert_float(paper.position.x).is_equal(rect.position.x - PaperPile.FOLD_SHIFT)
	assert_float(paper.end.x).is_equal(rect.end.x + PaperPile.FOLD_SHIFT)
	# Pile drawn over the receipt's foot.
	assert_int(pile.get_index()).is_greater(receipt.get_index())
	_full_pile(screen)
	await _frames(2)
	paper = pile.paper_rect()
	assert_float(receipt.get_global_rect().end.y).is_equal(paper.position.y + ShiftStage.PILE_JOIN)
	for part: Rect2 in [paper, pile.get_global_rect()]:
		assert_bool(stage.encloses(part)).override_failure_message(str(part)).is_true()
		assert_float(part.end.y).is_less_equal(stage.position.y + KICKPLATE_TOP)
		for other: Rect2 in [
			_on_stage(screen, ShiftStage.TRAY_RECT),
			_on_stage(screen, ShiftStage.PURSE_RECT),
			screen._checkout_button.get_global_rect(),
			screen._stage.scanner.get_global_rect(),
			screen._stage.belt.get_global_rect(),
		]:
			(
				assert_bool(part.intersects(other))
				. override_failure_message("pile %s overlaps %s" % [part, other])
				. is_false()
			)
	# A short receipt hides the pile again; the pile growing up to the receipt's foot shows it.
	screen._count_up.show_pile_for_shift(6)
	receipt.clear()
	await _frames(2)
	assert_bool(pile.visible).is_false()
	var top_at_cap: float = ShiftStage.PILE_BOTTOM - pile.cap_px
	while receipt.position.y + receipt.natural_height() < top_at_cap:
		receipt.add_line("LINE", "€1", ReceiptView.LineStyle.ITEM)
		await _frames(1)
	await _frames(2)
	pile.set_height(ArtStyle.ART_SCALE)
	assert_bool(screen._stage.receipt_reaches_pile()).is_false()
	assert_bool(pile.visible).is_false()
	pile.set_height(pile.cap_px)
	assert_bool(screen._stage.receipt_reaches_pile()).is_true()
	assert_bool(pile.visible).is_true()


## The paper pile at its cap, curled and spilled (a huge total's end).
static func _full_pile(screen: ShiftScreen) -> void:
	var pile: PaperPile = screen._paper_pile
	pile.set_height(pile.cap_px)
	pile.curl(true)


## The status panel (the capacity line at its longest, the cue, the longest notice), the totals on
## the register's LED, the register, the scanner and the paper pile stay on the stage, clear of
## the belt, the hand and the receipt where they must.
func test_the_status_line_and_the_register_stay_clear() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	screen._debug.give_upgrade("extra_coupon_slot")
	for inspection_id: String in ["short_belt", "coupon_slot_closed"]:
		run.inspections = [load("res://data/inspections/%s.tres" % inspection_id)]
		run.debug_skip_to_shift(run.shift_index)
		screen._on_shift_started()
		screen._notice_label.show_notice("Row full (9/9 items): take an item out first")
		screen._show_projected(999)
		await _frames(2)
		assert_str(screen._capacity_label.text).contains("(inspection −1)")
		_assert_status_clear(screen)


## Every Redraw caption the run can show fits REDRAW_RECT without growing it, with every upgrade
## that adds redraws: "Redraw up to N (M left)" for each M, "Redraw used" and, in redraw mode,
## "Confirm redraw (K/N)" for each K. Redraw keeps its rect, clear of Cancel and CHECKOUT.
func test_every_redraw_caption_fits() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	for upgrade: UpgradeDefinition in _all_upgrades():
		if upgrade.extra_redraws > 0:
			run.upgrades.append(upgrade)
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	assert_int(run.redraws_allowed).is_greater(1)
	var captions: PackedStringArray = PackedStringArray()
	for used: int in range(run.redraws_allowed, -1, -1):
		run.redraws_used = used
		screen._refresh_buttons()
		captions.append(screen._redraw_button.caption)
		await _assert_redraw_in_place(screen)
	screen._on_redraw_pressed()
	assert_bool(screen._cancel_button.visible).is_true()
	var hand: Array[CardInstance] = []
	for view: Control in screen._hand_box.cards():
		hand.append((view as CardView).card)
	for picked: int in range(mini(run.balance.redraw_limit, hand.size()) + 1):
		screen._redraw_pick.assign(hand.slice(0, picked))
		screen._refresh_buttons()
		captions.append(screen._redraw_button.caption)
		await _assert_redraw_in_place(screen)
	assert_str(";".join(captions)).contains("Redraw used")
	assert_str(";".join(captions)).contains("Confirm redraw (%d/" % run.balance.redraw_limit)


func _assert_redraw_in_place(screen: ShiftScreen) -> void:
	await _frames(1)
	var button: FramedButton = screen._redraw_button
	var needed: Vector2 = (
		button.caption_label().get_minimum_size() + 2.0 * FramedButton.CAPTION_PADDING
	)
	(
		assert_bool(needed.x <= ShiftStage.REDRAW_RECT.size.x)
		. override_failure_message("'%s' needs %s" % [button.caption, needed])
		. is_true()
	)
	assert_that(button.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.REDRAW_RECT))
	var others: Array[Control] = [screen._checkout_button]
	if screen._cancel_button.visible:
		others.append(screen._cancel_button)
	for other: Control in others:
		assert_bool(button.get_global_rect().intersects(other.get_global_rect())).is_false()
	assert_float(button.get_global_rect().end.x).is_less_equal(
		screen._checkout_button.get_global_rect().position.x - 8.0
	)


## The wall and the counter cover the whole viewport, whatever its shape.
func test_the_wall_and_counter_cover_the_viewport() -> void:
	var screen: ShiftScreen = await _screen()
	var window: Rect2 = screen.get_viewport_rect()
	var wall: Rect2 = (screen.get_child(0) as Control).get_global_rect()
	var counter: Rect2 = (screen.get_child(1) as Control).get_global_rect()
	assert_bool(wall.encloses(window)).is_true()
	assert_float(counter.position.x).is_less_equal(window.position.x)
	assert_float(counter.end.x).is_greater_equal(window.end.x)
	assert_float(counter.end.y).is_greater_equal(window.end.y)
	# The counter starts at the stage's counter line, wherever the stage sits.
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(counter.position.y).is_equal(stage.position.y + ShiftStage.COUNTER_TOP)


## A dragged item's ghost is its sprite alone (an ItemView in the GHOST form, SPRITE_SIZE, no
## sticker), centred on the mouse.
func test_the_drag_ghost_is_centred_on_the_mouse() -> void:
	var screen: ShiftScreen = await _screen()
	var view: CardView = screen._hand_box.cards()[2] as CardView
	var card: CardInstance = view.card
	var start: Vector2 = view.get_global_rect().get_center()
	screen._on_hand_card_clicked(view)
	assert_object(screen._picked).is_same(card)
	var target: Vector2 = start + Vector2(37, -151)
	screen._drag._input(_motion(target, MOUSE_BUTTON_MASK_LEFT))
	var ghost: ItemView = screen._drag._ghost
	assert_object(ghost).is_not_null()
	assert_int(ghost.form).is_equal(ItemView.Form.GHOST)
	assert_object(ghost.card).is_same(card)
	assert_vector(ghost.size).is_equal(ItemView.SPRITE_SIZE)
	assert_bool(ghost.sticker().visible).is_false()
	assert_vector(ghost.get_global_rect().get_center()).is_equal_approx(target, Vector2(1, 1))
	# The tilted, enlarged sprite turns about its centre, so it stays centred too.
	var body_center: Vector2 = ghost.body.get_global_transform() * (ItemView.SPRITE_SIZE / 2.0)
	assert_vector(body_center).is_equal_approx(target, Vector2(1, 1))
	screen._drag.cancel()


## Clearing the hand under the mouse: the hovered card's mouse_exited, sent while it leaves the
## tree, must not reorder the hand mid-removal (Godot would print a move_child error, which
## fails the run). Headless runs have no mouse, so the card sends it as a real mouse would.
func test_clearing_a_hovered_hand_reorders_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var hovered: Control = screen._hand_box.cards()[2]
	hovered.mouse_entered.emit()
	hovered.tree_exiting.connect(hovered.mouse_exited.emit)
	screen._hand_box.clear()
	assert_int(screen._hand_box.get_child_count()).is_equal(0)
	assert_int(screen._hand_box.cards().size()).is_equal(0)


## In a hand of more than 8 (debug), hovering an item brings it to the front, so a click where it
## overlaps the next item (on their stickers) goes to the hovered item, the one drawn on top.
## Headless runs deliver no mouse input, so this follows Godot's own rule: a click goes to the
## last child (drawn on top) whose hit area (ItemView.hit_rect) is under the mouse and stops it.
func test_the_hovered_item_takes_the_click() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.add_card("bread")
	await _frames(2)
	var views: Array[Control] = screen._hand_box.cards()
	var hovered: CardView = views[3] as CardView
	var under: Rect2 = views[4].get_global_rect()
	var rect: Rect2 = hovered.get_global_rect()
	assert_float(rect.end.x).is_greater(under.position.x)
	var sticker_y: float = rect.position.y + ItemView.TRAY_STICKER.y + PriceSticker.SIZE.y / 2.0
	var overlap: Vector2 = Vector2((under.position.x + rect.end.x) / 2.0, sticker_y)
	# Before the hover, the next item is on top where they overlap.
	assert_object(_card_at(screen._hand_box, overlap)).is_same(views[4])
	hovered.mouse_entered.emit()
	var top: CardView = _card_at(screen._hand_box, overlap) as CardView
	assert_object(top).is_same(hovered)
	top._gui_input(_button(overlap, true))
	assert_object(screen._picked).is_same(hovered.card)


## Text never goes through the sharp-pixel shader: no Label or Button text carries its material
## or the pixel-art mark.
func test_no_text_carries_the_pixel_material() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var texts: Array[Control] = _texts(screen)
	assert_int(texts.size()).is_greater(20)
	for text: Control in texts:
		(
			assert_object(text.material)
			. override_failure_message("%s has a material" % text.get_path())
			. is_null()
		)
		assert_bool(text.use_parent_material).is_false()
		assert_bool(text.has_meta(ArtStyle.PIXEL_ART_META)).is_false()


## Numbers and money use the number font: text on the stage or overlay without a font of its
## own (the count-up's flying numbers), the shift and quota, the LED's digits and quota line
## and the value badges.
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
		screen._led.digits_label(),
		screen._led.quota_label(),
		screen._deck_button.caption_label(),
		screen._redraw_button.caption_label(),
	]
	assert_int(screen._row_views.size()).is_greater(0)
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_true()
		numbers.append(view.badge)
	for label: Label in numbers:
		(
			assert_object(label.get_theme_font("font"))
			. override_failure_message("%s: %s" % [label.get_path(), label.text])
			. is_same(number_font)
		)


## Every character the screen prints is in the font that prints it, including "−" (U+2212) on
## the capacity line and the receipt's end-of-shift lines.
func test_every_printed_character_has_its_glyph() -> void:
	var screen: ShiftScreen = await _rich_screen()
	assert_str(screen._capacity_label.text).contains("−")
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
	for item: CanvasItem in marked:
		assert_object(item.material).is_same(ArtStyle.pixel_material())
	ArtStyle.set_sharp(screen, false)
	for item: CanvasItem in marked:
		assert_object(item.material).is_null()
		assert_int(item.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	ArtStyle.set_sharp(screen, true)
	for item: CanvasItem in marked:
		assert_object(item.material).is_same(ArtStyle.pixel_material())
		assert_int(item.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_PARENT_NODE)


# --- Helpers ---------------------------------------------------------------------------------


## The LED's digits (their ink: the line box is taller than the ink) on the glass, clear of the
## caption's and the quota line's text.
func _assert_digits_clear(screen: ShiftScreen) -> void:
	var led: LedDisplay = screen._led
	var ink: Rect2 = led.digits_text_rect()
	assert_bool(led.interior().encloses(ink)).override_failure_message(str(ink)).is_true()
	assert_bool(ink.intersects(led.quota_label().get_global_rect())).is_false()
	var caption: Label = led.caption_label()
	var font: Font = caption.get_theme_font("font")
	var caption_ink: Vector2 = LedDisplay.ink_span(
		led.caption(), font, caption.get_theme_font_size("font_size")
	)
	var caption_line: float = (
		(caption.size.y - font.get_height(caption.get_theme_font_size("font_size"))) / 2.0
	)
	var caption_bottom: float = (
		caption.get_global_rect().position.y
		+ caption_line
		+ font.get_ascent(caption.get_theme_font_size("font_size"))
		+ caption_ink.y
	)
	assert_float(ink.position.y).is_greater_equal(caption_bottom)


## The LED's caption, digits and quota line.
static func _led_labels(screen: ShiftScreen) -> Array[Control]:
	var led: LedDisplay = screen._led
	return [led.caption_label(), led.digits_label(), led.quota_label()]


## A shift with a bit of everything: an inspection that closes a slot (its capacity line prints
## "−"), placed cards with their badges, 4 stamped boxes and the receipt's end-of-shift lines.
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
	var belt: Rect2 = (screen._row_strip.get_parent() as Control).get_global_rect()
	var hand: Rect2 = screen._hand_box.get_global_rect()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var cue: Label = _label_with(screen._stage, ShiftStage.CUE_TEXT)
	assert_object(cue).is_not_null()
	var status: Array[Control] = [screen._capacity_label, cue, screen._notice_label]
	var totals: Array[Control] = [screen._led.digits_label(), screen._led.quota_label()]
	var status_rect: Rect2 = _on_stage(screen, ShiftStage.STATUS_RECT)
	var led: Rect2 = _on_stage(screen, ShiftStage.LED_RECT)
	for part: Control in status + totals:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		var inside: Rect2 = led if totals.has(part) else status_rect
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
	# The capacity line and the cue stay apart, and so do the totals. (The notice covers both
	# lines while it shows.)
	_assert_apart([screen._capacity_label, cue])
	_assert_digits_clear(screen)
	var register: Rect2 = screen._register.get_global_rect()
	var scanner: Rect2 = screen._stage.scanner.get_global_rect()
	var pile: Rect2 = screen._paper_pile.get_global_rect()
	for rect: Rect2 in [register, scanner, pile]:
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
	for rect: Rect2 in [register, scanner, pile]:
		assert_bool(rect.intersects(hand)).override_failure_message(str(rect)).is_false()
	assert_bool(register.intersects(belt)).is_false()
	assert_bool(pile.intersects(belt)).is_false()
	assert_bool(scanner.intersects(receipt)).is_false()
	assert_bool(scanner.intersects(register)).is_false()
	assert_bool(scanner.intersects(status_rect)).is_false()


## Every Label and Button under `node` (text on screen, wherever it is).
static func _texts(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Label or node is Button:
		result.append(node as Control)
	for child: Node in node.get_children():
		result.append_array(_texts(child))
	return result


static func _label_with(node: Node, text: String) -> Label:
	for found: Node in node.find_children("*", "Label", true, false):
		if (found as Label).text == text:
			return found as Label
	return null


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


static func _motion(point: Vector2, mask: int = 0) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = mask
	return motion


## The control a click at `point` reaches among `parent`'s children: the last one (drawn on top)
## under it that stops the mouse.
static func _card_at(parent: Control, point: Vector2) -> Control:
	for index: int in range(parent.get_child_count() - 1, -1, -1):
		var child: Control = parent.get_child(index) as Control
		if (
			child != null
			and child.visible
			and child.mouse_filter == Control.MOUSE_FILTER_STOP
			and _hits(child, point)
		):
			return child
	return null


## Whether `point` (global) is in `child`'s hit area: an item's hit_rect, else its rect.
static func _hits(child: Control, point: Vector2) -> bool:
	var item: ItemView = child as ItemView
	if item == null:
		return child.get_global_rect().has_point(point)
	return item.hit_rect().has_point(item.get_global_transform().affine_inverse() * point)


static func _button(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = pressed
	press.position = point
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return press


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
