extends GdUnitTestSuite
## The hover scanner on the real shift screen (#75, ScanController): hovering a hand item or a
## belt item lifts its sprite, poses the scanner over it (out of its cradle), opens the one scan
## popup inside the 1280x720 stage with the card's rule text, and beeps (scan_hover, the scan
## sound at ScanController.HOVER_DB) once per new item, throttled. A hand item's popup opens beside
## it over the tray, never over the belt; a belt item's flips below its sticker and chips and
## lists every step of its slot but BASE and PAYOUT, worded as the receipt words them: all the
## belt popups together hold every step line of the planning receipt, for the golden rows and
## #60's reference row. No scan while dragging, counting or with the deck view open; the pointer
## on the popup keeps the item; leaving the item and its popup, the window or the game ends the
## scan and docks the scanner; reduced motion runs no beam loop. The count-up poses the scanner
## in gold over each item it lifts and docks it as its beats end. Headless runs never move the
## mouse, so the tests set the controller's pointer (and its clock, so the throttle never hangs
## on how long a frame takes) and send the items' hover signals. Every
## rect is checked on screen (headless runs use a 1280x1280 window: the stage is centred, 280 px
## down). The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## The golden rows (docs/PROTOTYPE_PLAN.md section 3.7, tests/core/golden_rows_test.gd), each
## scored with its frozen fixture.
const GOLDEN_ROWS: Dictionary[String, Array] = {
	"res://tests/fixtures/cards_v0_4":
	[
		"eggs,bread,cheese,banana,banana,repeat",
		"banana,repeat,bread,eggs,banana,cheese",
		"eggs,banana,banana",
		"banana,bundle,banana",
		"banana,repeat,banana",
		"bread,bundle,cheese",
		"eggs,bread,multipack,bread",
		"milk,multipack,cheese",
		"coffee,coffee,bread",
		"breakfast_sticker,banana,milk",
		"eggs,eggs,bread,bread,bread",
		"repeat,repeat",
		"soup,frozen_peas",
		"bread,final_markdown",
		"final_markdown,bread",
		"eggs,bread,repeat,bread",
		"bread,multipack,bread,repeat",
		"multipack,bread,bread",
		"bread,repeat,multipack,bread",
		"breakfast_sticker,repeat,banana,milk",
		"frozen_peas,frozen_peas",
		"soup,bundle,frozen_peas",
		"soup,repeat,frozen_peas",
		"eggs,coffee,bread,bread",
		"coffee,banana,bread",
		"coffee,bread,milk",
		"coffee,repeat,bread",
		"coffee,multipack,banana,bread",
		"bread,multipack,bread,multipack,bread",
		"breakfast_sticker,banana,multipack,coffee,bread",
		"banana,bundle,bundle,banana",
		"bread,bundle,repeat",
		"coffee,breakfast_sticker,soup,frozen_peas,bread",
		"eggs,soup,frozen_peas,bread",
		"banana,bundle,multipack,banana",
		"bundle,banana,banana,bundle",
		"bread,coffee",
		"breakfast_sticker,bread,milk",
		"bread,repeat,repeat",
		"coffee,breakfast_sticker,banana",
		"coffee,multipack,breakfast_sticker,banana",
	],
	"res://tests/fixtures/cards_v0_5":
	[
		"banana,two_for_one,banana",
		"bread,two_for_one,cheese",
		"banana,two_for_one,two_for_one,banana",
		"frozen_peas,two_for_one,frozen_peas",
		"eggs,banana,two_for_one,banana,repeat",
		"bread,banana,shelf_swap,cheese",
		"soup,bread,shelf_swap,frozen_peas",
		"frozen_peas,bread,shelf_swap,frozen_peas",
		"banana,two_for_one,banana,shelf_swap,banana",
	],
	"res://tests/fixtures/cards_v0_6":
	[
		"clearance_tag,bread,day_old_buns",
		"clearance_tag,day_old_buns,day_old_buns",
		"bread,clearance_tag",
		"flickering_bulb,clearance_tag,bread",
		"clearance_tag,bread,dented_can,dented_can",
		"clearance_tag,bread,reduced_yogurt",
		"opening_deal,soup,bread",
		"bread,opening_deal,soup",
		"opening_deal,repeat",
		"opening_deal,soup,repeat",
		"opening_deal,soup,eggs,bread,milk",
		"opening_deal,breakfast_sticker,banana,milk",
		"opening_deal,frozen_peas,bread,shelf_swap,frozen_peas",
		"opening_deal,soup,frozen_peas",
		"opening_deal,clearance_tag,bread,day_old_buns",
		"clearance_tag,opening_deal,bread",
	],
}

## A full hand of 8 (HandRow's natural pitch, no overlap).
const EIGHT: Array[String] = [
	"milk", "bread", "eggs", "coffee", "cheese", "banana", "soup", "crisps"
]

var _folder: String = ""
## Where the tests put the pointer (global).
var _point: Vector2 = Vector2.ZERO
## The controller's clock (ms): only the tests move it.
var _clock: int = 0


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_point = Vector2(-100, -100)
	_clock = 1000


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A hand item's popup (style frame v2's round 3) opens beside it over the tray, never over the
## belt: every belt item's sprite and sticker stay in view while a hand item is read. It shows
## the card's rule text verbatim and no footer; the item lifts, the scanner leaves its cradle for
## the side away from the popup, and it beeps once.
func test_the_scan_popup_points_at_the_hovered_item() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_place(screen, ["milk", "bread"])
	var view: ItemView = _hand_views(screen)[1]
	await _hover(screen, view)
	var popup: ScanPopup = screen._scan.popup()
	assert_object(screen._scan.scanned()).is_same(view)
	assert_bool(popup.visible).is_true()
	assert_float(view.body.position.y).is_equal(-ItemView.LIFT)
	var rect: Rect2 = popup.get_global_rect()
	_assert_on_stage(screen, rect, "hand popup")
	assert_float(rect.position.y).is_greater_equal(_y(screen, ShiftStage.COUNTER_TOP))
	assert_bool(rect.intersects(_on_stage(screen, ShiftStage.BELT_RECT))).is_false()
	for belt_view: CardView in screen._row_views:
		var item: ItemView = belt_view as ItemView
		for part: Control in [item.sprite(), item.sticker()]:
			assert_bool(rect.intersects(part.get_global_rect())).is_false()
	# On the item's right (it fits over the tray), level with the lifted sprite, clear of the
	# item's own sprite and sticker; the side tail points at the sprite's middle.
	assert_int(popup.placement).is_equal(ScanPopup.Placement.RIGHT)
	var sprite: Rect2 = view.sprite().get_global_rect()
	var sticker: Rect2 = view.sticker().get_global_rect()
	assert_float(rect.position.y).is_equal(sprite.position.y)
	assert_float(rect.position.x).is_equal(maxf(sprite.end.x, sticker.end.x) + ScanPopup.SIDE_GAP)
	for part: Rect2 in [sprite, sticker]:
		assert_bool(rect.intersects(part)).is_false()
		assert_bool(popup.tail().get_global_rect().intersects(part)).is_false()
	var tip: Vector2 = popup.get_parent_control().get_global_transform() * popup.tail_tip()
	assert_float(tip.x).is_equal(maxf(sprite.end.x, sticker.end.x))
	assert_float(tip.y).is_equal(sprite.get_center().y)
	assert_str(popup.rule_label().text).is_equal(view.card.definition.rule_text)
	assert_str(popup.name_label().text).is_equal(view.card.definition.display_name)
	assert_array(popup.footer_texts()).is_empty()
	_assert_popup_holds_its_text(popup)
	_assert_scanner_posed(screen, view)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	var beep: Dictionary = sfx.sounds[sfx.sound_names().find(ScanController.HOVER_SOUND)]
	assert_str(beep["take"]).is_equal("scan")
	assert_float(beep["volume_db"]).is_equal(ScanController.HOVER_DB)
	assert_int(sfx.count("scan")).is_equal(0)


## A belt item's popup flips below its sticker and chips (above it, it would reach the top bar),
## its tail at the sprite's middle, and its footer lists its payout and every step of its slot
## but BASE and PAYOUT, as the receipt words them: here Coffee's fizzle (nothing after it).
func test_a_hovered_belt_item_flips_its_popup_and_lists_its_fizzles() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread", "coffee"])
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	var popup: ScanPopup = screen._scan.popup()
	assert_int(popup.placement).is_equal(ScanPopup.Placement.BELOW)
	assert_object(popup.tail().texture).is_same(ScanPopup.TAIL)
	var rect: Rect2 = popup.get_global_rect()
	_assert_on_stage(screen, rect, "belt popup")
	var below: Rect2 = view.below_rect()
	assert_float(rect.position.y).is_equal(below.end.y + ScanPopup.FLIP_GAP)
	assert_bool(rect.intersects(below)).is_false()
	var sprite: Rect2 = view.sprite().get_global_rect()
	assert_bool(rect.intersects(sprite)).is_false()
	assert_float(popup.tail().get_global_rect().get_center().x).is_equal(sprite.get_center().x)
	var result: ScoreResult = screen.run.preview()
	var expected: PackedStringArray = PackedStringArray(["Pays €%d" % result.payouts[2]])
	var fizzles: int = 0
	for step: ScoreStep in ScanController.footer_steps(result, 2):
		expected.append(ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)))
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles += 1
	assert_int(fizzles).is_equal(1)
	assert_str(expected[expected.size() - 1]).ends_with("  fizzle")
	(
		assert_bool(popup.footer_texts() == expected)
		. override_failure_message("%s != %s" % [popup.footer_texts(), expected])
		. is_true()
	)
	assert_str(popup.rule_label().text).is_equal(view.card.definition.rule_text)
	_assert_popup_holds_its_text(popup)
	_assert_scanner_posed(screen, view)


## One beep per new item, at most one per THROTTLE_MS: a second item scanned at once is shown
## but silent, a third after the throttle beeps, the same item hovered again doesn't, and a scan
## that ended and starts again on that item does.
func test_one_beep_per_new_item_and_the_throttle_holds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	await _hover(screen, hand[0])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	await _hover(screen, hand[0])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	# Straight on to an item clear of the first one's popup: scanned, but within the throttle.
	_leave(hand[0])
	_point = hand[5].sprite().get_global_rect().get_center()
	hand[5].hovered.emit(hand[5])
	assert_object(screen._scan.scanned()).is_same(hand[5])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	_clock += ScanController.THROTTLE_MS
	_leave(hand[5])
	await _hover(screen, hand[7])
	assert_object(screen._scan.scanned()).is_same(hand[7])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(2)
	_clock += ScanController.THROTTLE_MS
	await _leave_to(Vector2(-100, -100), hand[7])
	assert_object(screen._scan.scanned()).is_null()
	await _hover(screen, hand[7])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(3)
	assert_int(sfx.count("scan")).is_equal(0)


## No popup and no beep while an item is dragged or the shift is counted, or with the deck view
## open; a scan shown when the drag starts, or at the CHECKOUT click, ends at once, its scanner
## docked and its item at rest.
func test_no_scan_while_dragging_counting_or_with_the_deck_open() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_place(screen, ["milk", "bread"])
	var card: CardInstance = screen.run.hand()[0]
	await _hover(screen, _hand_views(screen)[0])
	assert_object(screen._scan.scanned()).is_not_null()
	# A press picks the item up and arms the drag; moving past the threshold drags it.
	screen._on_hand_card_clicked(_view_for(screen, card))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _slot_center(screen, 3)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen._drag._input(motion)
	assert_bool(screen._drag.is_dragging()).is_true()
	await _frames(1)
	_assert_cleared(screen)
	var beeps: int = sfx.count(ScanController.HOVER_SOUND)
	await _hover(screen, _hand_views(screen)[1])
	_assert_cleared(screen)
	screen._drag.cancel()
	screen._let_go()
	# The deck view.
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	await _hover(screen, _hand_views(screen)[1])
	_assert_cleared(screen)
	screen._deck_view.visible = false
	# The count-up: the scan shown at the click ends with it.
	await _hover(screen, screen._row_views[0] as ItemView)
	assert_object(screen._scan.scanned()).is_not_null()
	beeps = sfx.count(ScanController.HOVER_SOUND)
	screen._on_checkout_pressed()
	_assert_cleared(screen)
	_clock += ScanController.THROTTLE_MS
	await _hover(screen, screen._row_views[1] as ItemView)
	# The count-up's own gold pose may show by now, never a hover's.
	assert_object(screen._scan.scanned()).is_null()
	assert_bool(screen._scan.popup().visible).is_false()
	var overlay: ScanOverlay = screen._scan.overlay()
	if overlay.is_posed():
		assert_object(overlay.bracket_color()).is_equal(Palette.GOLD)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(beeps)
	while screen._counting:
		await get_tree().process_frame


## The count-up scans the belt (#75, the 2026-10-15 decision): as each item's scan lifts it, the
## handheld poses in gold overhead-right of its lifted sprite, gold brackets around it, no beam
## pulse, on the stage, every item in turn; it docks in its cradle as the beats end, before the
## dessert. No hover scan shows meanwhile.
func test_the_count_up_poses_the_scanner_over_each_item_in_turn() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread", "eggs", "milk"])
	await _frames(1)
	var overlay: ScanOverlay = screen._scan.overlay()
	var posed: Array[int] = []
	var failures: Array[String] = []
	screen._on_checkout_pressed()
	while screen._counting:
		await get_tree().process_frame
		if not overlay.is_posed():
			continue
		if overlay.bracket_color() != Palette.GOLD or overlay.has_beam_loop():
			failures.append("a pose that is not the count-up's")
		var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
		var slot: int = _lifted_slot(screen._row_views, brackets)
		if slot < 0:
			failures.append("brackets %s on no lifted item" % brackets)
			continue
		var scanner: Rect2 = overlay.handheld().get_global_rect()
		var sprite: Rect2 = brackets.grow(-ScanOverlay.BRACKET_OUTSET)
		if not scanner.is_equal_approx(ScanOverlay.scanner_rect(sprite, false)):
			failures.append("slot %d: scanner at %s" % [slot, scanner])
		if not screen._stage.get_global_rect().encloses(scanner):
			failures.append("slot %d: scanner %s off the stage" % [slot, scanner])
		if posed.is_empty() or posed[-1] != slot:
			posed.append(slot)
		if screen._count_up.intensity != null:
			failures.append("still posed once the total shows")
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_array(posed).is_equal([0, 1, 2, 3])
	_assert_cleared(screen)


## While the pointer is on the popup, the item stays scanned, even over a hand item the popup
## covers; off the popup and onto another item, that one is scanned; off every item and the
## popup, the scan ends: the popup hides, the item rests and the scanner docks in its cradle.
func test_the_pointer_on_the_popup_keeps_the_item() -> void:
	var screen: ShiftScreen = await _screen()
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	await _hover(screen, hand[0])
	var popup: Rect2 = screen._scan.popup().get_global_rect()
	var covered: ItemView = hand[1]
	var inside: Vector2 = covered.sprite().get_global_rect().get_center()
	assert_bool(popup.has_point(inside)).is_true()
	_leave(hand[0])
	_point = inside
	covered.hovered.emit(covered)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_same(hand[0])
	# Off the popup onto an item it doesn't cover.
	var free: ItemView = hand[hand.size() - 1]
	var outside: Vector2 = free.sprite().get_global_rect().get_center()
	assert_bool(popup.has_point(outside)).is_false()
	covered.unhovered.emit(covered)
	_point = outside
	free.hovered.emit(free)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_same(free)
	assert_float(hand[0].body.position.y).is_equal(0.0)
	# Off every item: the scan ends.
	await _leave_to(_on_stage(screen, Rect2(600, 20, 1, 1)).position, free)
	_assert_cleared(screen)
	assert_float(free.body.position.y).is_equal(0.0)


## The pointer leaving the window, or the player leaving the game, ends the scan.
func test_leaving_the_window_or_the_game_ends_the_scan() -> void:
	var screen: ShiftScreen = await _screen()
	var view: ItemView = _hand_views(screen)[0]
	await _hover(screen, view)
	screen.get_window().mouse_exited.emit()
	_assert_cleared(screen)
	await _hover(screen, _hand_views(screen)[1])
	assert_object(screen._scan.scanned()).is_not_null()
	screen._focus.player_left.emit()
	_assert_cleared(screen)


## A refresh that rebuilds the items (a pick) keeps the scan on the same card's new view, without
## a second beep.
func test_a_refresh_keeps_the_scan_on_the_same_card() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	var view: ItemView = _hand_views(screen)[0]
	var card: CardInstance = view.card
	await _hover(screen, view)
	screen._on_hand_card_clicked(view)
	await _frames(2)
	var scanned: ItemView = screen._scan.scanned()
	assert_object(scanned).is_not_null()
	assert_object(scanned).is_not_same(view)
	assert_object(scanned.card).is_same(card)
	assert_bool(screen._scan.popup().visible).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	screen._let_go()


## A belt item clicked out to the hand moves away from the pointer: the scan ends with the
## refresh. Checked straight after the refresh's deferred calls (a call queued after the click
## runs after them, before the next process step): the popup is hidden and the scanner docked,
## never shown over the tray, and it stays so.
func test_a_belt_item_clicked_out_ends_the_scan() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread"])
	var view: ItemView = screen._row_views[1] as ItemView
	var card: CardInstance = view.card
	await _hover(screen, view)
	assert_object(screen._scan.scanned()).is_same(view)
	var overlay: ScanOverlay = screen._scan.overlay()
	var shown: Array[bool] = [true]
	var look: Callable = func() -> void:
		shown[0] = screen._scan.popup().visible or overlay.is_posed()
	screen._on_row_card_clicked(view)
	look.call_deferred()
	assert_bool(screen.run.hand().has(card)).is_true()
	for _frame: int in range(3):
		await get_tree().process_frame
		assert_bool(shown[0]).override_failure_message("scanned after the refresh").is_false()
		_assert_cleared(screen)
	screen._let_go()


## Reduced motion: the scan snaps into place with no looping tween (no beam pulse); without it,
## the beam pulses until the scan ends.
func test_reduced_motion_runs_no_beam_loop() -> void:
	var screen: ShiftScreen = await _screen()
	var overlay: ScanOverlay = screen._scan.overlay()
	screen.profile.set_reduced_motion(true)
	await _hover(screen, _hand_views(screen)[0])
	assert_bool(screen._scan.popup().visible).is_true()
	assert_bool(overlay.is_posed()).is_true()
	assert_bool(overlay.has_beam_loop()).is_false()
	assert_int(_looping_tweens()).is_equal(0)
	await _leave_to(Vector2(-100, -100), _hand_views(screen)[0])
	screen.profile.set_reduced_motion(false)
	await _hover(screen, _hand_views(screen)[1])
	assert_bool(overlay.has_beam_loop()).is_true()
	assert_int(_looping_tweens()).is_equal(1)
	screen._scan.clear()
	assert_bool(overlay.has_beam_loop()).is_false()
	assert_int(_looping_tweens()).is_equal(0)


## The exact test (#75, decision 1A): on #60's reference row (Coupon engine, Slot engine, the Spot
## check), all the belt popups' footers together hold every step line of the planning receipt
## but the BASE and PAYOUT lines, each in its own item's popup, in receipt order, none folded.
func test_the_popups_hold_every_line_of_the_planning_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	_place(screen, FULL_ROW)
	await _frames(2)
	var result: ScoreResult = screen.run.preview()
	# The receipt the planning screen printed before the stub (#75, step 7): every step's line.
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 0)
	add_child(receipt)
	receipt.show_result(
		result,
		ShiftScreen._names(screen.run.row),
		LoyaltyCard.names(screen.run.upgrades),
		InspectionTag.names(screen.run.inspections)
	)
	var expected: Dictionary[int, PackedStringArray] = _receipt_lines_by_slot(receipt, result)
	var footers: Dictionary[int, PackedStringArray] = {}
	var kinds: Dictionary[int, bool] = {}
	for slot: int in range(screen._row_views.size()):
		var view: ItemView = screen._row_views[slot] as ItemView
		await _hover(screen, view)
		var footer: PackedStringArray = screen._scan.popup().footer_texts()
		assert_str(footer[0]).is_equal("Pays €%d" % result.payouts[slot])
		footers[slot] = footer.slice(1)
		_assert_on_stage(screen, screen._scan.popup().get_global_rect(), "slot %d" % slot)
		_assert_popup_holds_its_text(screen._scan.popup())
	for step: ScoreStep in result.steps:
		kinds[step.step_type] = true
	_assert_footers_match(expected, footers, "reference row")
	for kind: ScoreStep.StepType in [
		ScoreStep.StepType.FLAT,
		ScoreStep.StepType.MULTIPLIER,
		ScoreStep.StepType.PAYOUT_OVERRIDE,
		ScoreStep.StepType.WASTED,
	]:
		assert_bool(kinds.has(kind)).override_failure_message(str(kind)).is_true()


## The exact test on every golden row, each scored with its frozen fixture: the receipt printed
## for the row and a popup filled as ScanController fills a belt item's hold the same lines per
## slot, none folded.
func test_the_popups_hold_every_line_of_each_golden_rows_receipt() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(276, 0)
	add_child(receipt)
	var popup: ScanPopup = auto_free(ScanPopup.new())
	add_child(popup)
	var rows: int = 0
	for fixture: String in GOLDEN_ROWS:
		for row_ids: String in GOLDEN_ROWS[fixture]:
			var row: Array[CardInstance] = _fixture_row(fixture, row_ids)
			var result: ScoreResult = Scoring.score(row)
			var names: PackedStringArray = ShiftScreen._names(row)
			receipt.show_result(result, names)
			var expected: Dictionary[int, PackedStringArray] = _receipt_lines_by_slot(
				receipt, result
			)
			var footers: Dictionary[int, PackedStringArray] = {}
			for slot: int in range(row.size()):
				var lines: PackedStringArray = PackedStringArray()
				var fizzles: Array[bool] = []
				for step: ScoreStep in ScanController.footer_steps(result, slot):
					lines.append(ReceiptView.step_line(step, names))
					fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
				var definition: CardDefinition = row[slot].definition
				popup.show_card(
					definition, null, result.tags[slot], result.payouts[slot], lines, fizzles
				)
				footers[slot] = popup.footer_texts().slice(1)
			_assert_footers_match(expected, footers, row_ids)
			rows += 1
			# The lines the receipt and the popup let go of are freed at the frame's end.
			await get_tree().process_frame
	assert_int(rows).is_equal(66)


## Wherever any card in data/cards is hovered (each hand position, a full hand of 8, and each
## belt cell, a full row of products and a coupon), its popup stays in the stage, under the top
## bar and off the item's sprite and sticker (and chips, on the belt); a hand item's opens beside
## it, off the belt (at or below the counter line).
func test_the_popup_keeps_every_card_in_the_stage() -> void:
	var screen: ShiftScreen = await _screen()
	var products: Array[String] = []
	var coupons: Array[String] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if not file_name.ends_with(".tres"):
			continue
		var definition: CardDefinition = load(CARDS.path_join(file_name)) as CardDefinition
		if definition.is_coupon():
			coupons.append(String(definition.id))
		else:
			products.append(String(definition.id))
	assert_int(products.size() + coupons.size()).is_equal(59)
	var all: Array[String] = []
	all.append_array(products)
	all.append_array(coupons)
	for start: int in range(0, all.size(), 8):
		_fill_hand(screen, _ids(all, start, 8))
		for view: ItemView in _hand_views(screen):
			# Each scan ends first: a popup keeps its item while the pointer is on it.
			screen._scan.clear()
			await _hover(screen, view)
			_assert_hand_popup(screen, view)
	var coupon: int = 0
	var per_row: int = screen.run.limits.slot_count
	for start: int in range(0, products.size(), per_row):
		var batch: Array[String] = _ids(products, start, per_row)
		batch.append(coupons[coupon % coupons.size()])
		coupon += 1
		_fill_row(screen, batch)
		for view: CardView in screen._row_views:
			screen._scan.clear()
			await _hover(screen, view as ItemView)
			_assert_belt_popup(screen, view as ItemView)
	while coupon < coupons.size():
		_fill_row(screen, [products[0], coupons[coupon]])
		coupon += 1
		await _hover(screen, screen._row_views[1] as ItemView)
		_assert_belt_popup(screen, screen._row_views[1] as ItemView)


# --- Helpers ---------------------------------------------------------------------------------


## The planning receipt's printed lines (read back from its labels, on one row each as
## ReceiptView.joined_line puts them), by the slot of the step that printed them, leaving out
## BASE and PAYOUT; the receipt prints one line per step that prints one, then the TOTAL line.
func _receipt_lines_by_slot(
	receipt: ReceiptView, result: ScoreResult
) -> Dictionary[int, PackedStringArray]:
	var printed: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer:
			printed.append(_line_text(line as HBoxContainer))
	var steps: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if not ReceiptView.step_text(step, PackedStringArray(_names_for(result))).is_empty():
			steps.append(step)
	assert_int(printed.size()).is_equal(steps.size() + 1)
	var by_slot: Dictionary[int, PackedStringArray] = {}
	for index: int in range(steps.size()):
		var step: ScoreStep = steps[index]
		if step.step_type in [ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT]:
			continue
		if not by_slot.has(step.slot):
			by_slot[step.slot] = PackedStringArray()
		by_slot[step.slot].append(printed[index])
	return by_slot


## Names long enough for every step's slot (only whether a step prints a line is read).
static func _names_for(result: ScoreResult) -> Array[String]:
	var names: Array[String] = []
	for slot: int in range(result.payouts.size()):
		names.append("x")
	return names


## A receipt line's text on one row: its marker (if hung) and left text, then its right side.
static func _line_text(line: HBoxContainer) -> String:
	var left: Label = line.get_child(0) as Label
	var right: Label = line.get_child(1) as Label
	var marker: Label = left.get_node_or_null("Marker") as Label
	var text: String = left.text if marker == null else "%s %s" % [marker.text, left.text]
	return ReceiptView.joined_line(text, right.text)


func _assert_footers_match(
	expected: Dictionary[int, PackedStringArray],
	footers: Dictionary[int, PackedStringArray],
	message: String
) -> void:
	var lines: int = 0
	for slot: int in footers:
		var want: PackedStringArray = expected.get(slot, PackedStringArray())
		lines += want.size()
		(
			assert_bool(footers[slot] == want)
			. override_failure_message(
				"%s slot %d: %s != %s" % [message, slot, footers[slot], want]
			)
			. is_true()
		)
	var receipt_lines: int = 0
	for slot: int in expected:
		receipt_lines += expected[slot].size()
	assert_int(lines).override_failure_message(message).is_equal(receipt_lines)


func _assert_hand_popup(screen: ShiftScreen, view: ItemView) -> void:
	var rect: Rect2 = screen._scan.popup().get_global_rect()
	var message: String = "%s in the hand: %s" % [view.card.definition.id, rect]
	_assert_on_stage(screen, rect, message)
	assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
		_y(screen, ShiftStage.COUNTER_TOP)
	)
	(
		assert_bool(rect.intersects(_on_stage(screen, ShiftStage.BELT_RECT)))
		. override_failure_message(message)
		. is_false()
	)
	for part: Control in [view.sprite(), view.sticker()]:
		(
			assert_bool(rect.intersects(part.get_global_rect()))
			. override_failure_message(message)
			. is_false()
		)
	_assert_popup_holds_its_text(screen._scan.popup())


func _assert_belt_popup(screen: ShiftScreen, view: ItemView) -> void:
	var rect: Rect2 = screen._scan.popup().get_global_rect()
	var message: String = "%s on the belt: %s" % [view.card.definition.id, rect]
	_assert_on_stage(screen, rect, message)
	assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
		_y(screen, ShiftStage.TOP_BAR_BOTTOM)
	)
	assert_bool(rect.intersects(view.below_rect())).override_failure_message(message).is_false()
	(
		assert_bool(rect.intersects(view.sprite().get_global_rect()))
		. override_failure_message(message)
		. is_false()
	)
	_assert_popup_holds_its_text(screen._scan.popup())


## Every text label inside the popup, and the popup within its height range.
func _assert_popup_holds_its_text(popup: ScanPopup) -> void:
	var rect: Rect2 = popup.get_global_rect()
	for label: Label in popup.text_labels():
		var inner: Rect2 = label.get_global_rect()
		(
			assert_bool(rect.encloses(inner))
			. override_failure_message("'%s' %s outside %s" % [label.text, inner, rect])
			. is_true()
		)
	assert_float(popup.size.y).is_between(ScanPopup.MIN_HEIGHT, ScanPopup.MAX_HEIGHT)


## The scanner out of its cradle in its posed look overhead beside `view`'s lifted sprite (on its
## left, flipped, when the popup opens on its right), tomato brackets around the sprite, all on
## the stage and clear of the popup.
func _assert_scanner_posed(screen: ShiftScreen, view: ItemView) -> void:
	var overlay: ScanOverlay = screen._scan.overlay()
	var handheld: TextureRect = overlay.handheld()
	assert_bool(overlay.is_posed()).is_true()
	assert_object(handheld.get_parent()).is_same(overlay)
	assert_object(handheld.texture).is_same(ScanOverlay.SCANNER_AIM)
	var sprite: Rect2 = view.sprite().get_global_rect()
	var on_left: bool = screen._scan.popup().placement == ScanPopup.Placement.RIGHT
	var scanner: Rect2 = handheld.get_global_rect()
	(
		assert_bool(scanner == ScanOverlay.scanner_rect(sprite, on_left))
		. override_failure_message(
			"%s vs %s" % [scanner, ScanOverlay.scanner_rect(sprite, on_left)]
		)
		. is_true()
	)
	assert_bool(handheld.flip_h).is_equal(on_left)
	_assert_on_stage(screen, scanner, "scanner")
	assert_bool(scanner.intersects(screen._scan.popup().get_global_rect())).is_false()
	var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
	assert_bool(brackets == sprite.grow(ScanOverlay.BRACKET_OUTSET)).is_true()
	assert_object(overlay.bracket_color()).is_equal(Palette.TOMATO)


## The slot of the view whose lifted sprite (ScanOverlay.lifted_sprite) has `brackets` (global)
## round it, or -1.
func _lifted_slot(views: Array[CardView], brackets: Rect2) -> int:
	for slot: int in range(views.size()):
		if not is_instance_valid(views[slot]):
			continue
		var sprite: Rect2 = ScanOverlay.lifted_sprite(views[slot] as ItemView)
		if sprite.grow(ScanOverlay.BRACKET_OUTSET).is_equal_approx(brackets):
			return slot
	return -1


## No scan: no item scanned, the popup hidden and the scanner docked in its cradle.
func _assert_cleared(screen: ShiftScreen) -> void:
	assert_object(screen._scan.scanned()).is_null()
	assert_bool(screen._scan.popup().visible).is_false()
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_false()
	assert_object(overlay.handheld().get_parent()).is_same(screen._stage.scanner)
	assert_object(overlay.handheld().texture).is_same(ShiftStage.SCANNER_HANDHELD)
	var docked: Rect2 = _on_stage(
		screen,
		Rect2(ShiftStage.CRADLE_RECT.position + ShiftStage.DOCKED_OFFSET, ShiftStage.DOCKED_SIZE)
	)
	assert_bool(overlay.handheld().get_global_rect() == docked).is_true()


func _assert_on_stage(screen: ShiftScreen, rect: Rect2, message: String) -> void:
	(
		assert_bool(screen._stage.get_global_rect().encloses(rect))
		. override_failure_message("%s: %s" % [message, rect])
		. is_true()
	)


## The pointer on `view`'s sprite, and its hover sent (headless runs never move the mouse), once
## a refresh's new items are laid out.
func _hover(screen: ShiftScreen, view: ItemView) -> void:
	await _frames(1)
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)
	await _frames(1)
	assert_object(screen._scan).is_not_null()


func _leave(view: ItemView) -> void:
	view.unhovered.emit(view)


## The pointer moves to `point` (global), off `view`.
func _leave_to(point: Vector2, view: ItemView) -> void:
	_point = point
	view.unhovered.emit(view)
	await _frames(2)


## The screen past the impulse rack, its scanner following _point.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	screen._scan.pointer = func() -> Vector2: return _point
	screen._scan.now_ms = func() -> int: return _clock
	await _frames(3)
	return screen


## A recording Sfx in place of the screen's: the scan controller finds it on the screen.
func _recording_sfx(screen: ShiftScreen) -> RecordingSfx:
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._sfx = sfx
	screen._count_up._sfx = sfx
	return sfx


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, card_id]))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()


## The row emptied back into the hand, then `card_ids` placed.
func _fill_row(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card: CardInstance in run.row.duplicate():
		run.remove(card)
	_place(screen, card_ids)


## The hand emptied (its cards dropped from the deck's hand; the row's stay), then `card_ids`
## added.
func _fill_hand(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card: CardInstance in run.hand():
		run.deck._hand.erase(card)
	for card_id: String in card_ids:
		run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, card_id]))
	screen._refresh()


## Up to `count` of `ids` from `start`.
static func _ids(ids: Array[String], start: int, count: int) -> Array[String]:
	var picked: Array[String] = []
	for index: int in range(start, mini(start + count, ids.size())):
		picked.append(ids[index])
	return picked


static func _hand_views(screen: ShiftScreen) -> Array[ItemView]:
	var views: Array[ItemView] = []
	for view: Control in screen._hand_box.cards():
		views.append(view as ItemView)
	return views


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: ItemView in _hand_views(screen):
		if view.card == card:
			return view
	return null


static func _fixture_row(fixture: String, ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [fixture, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


## How many looping tweens are running.
func _looping_tweens() -> int:
	var count: int = 0
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.get_loops_left() < 0:
			count += 1
	return count


static func _slot_center(screen: ShiftScreen, slot: int) -> Vector2:
	return screen._slots[slot].get_global_rect().get_center()


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


static func _y(screen: ShiftScreen, stage_y: float) -> float:
	return screen._stage.get_global_rect().position.y + stage_y


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
