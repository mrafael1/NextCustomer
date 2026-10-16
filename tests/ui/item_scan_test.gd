extends GdUnitTestSuite
## The hover scanner on the real shift screen (#75, ScanController), opt-in since #80: hovering a
## hand item or a belt item shows nothing (no popup, no lift, no brackets, no
## beep); only the pointer staying on that item for the hold (ScanController.hold_ms, from
## data/balance/scan.tres) scans it: its sprite lifts, tomato brackets mark it, it beeps
## (scan_hover, the scan sound at ScanController.HOVER_DB), throttled, and the one scan popup opens
## inside the 1280x720 stage with the card's rule text. Leaving the item before the hold cancels it;
## another item starts its own. The layout tests use a hold of 0 (instant). A hand item's popup
## opens beside it over the tray, never over the belt; a belt item's flips below its sticker and
## chips and lists every step of its slot but BASE and PAYOUT, worded as the receipt words them: all
## the belt popups together hold every step line of the planning receipt, for #60's reference row
## (the golden rows are in scan_popup_golden_rows_test). No scan while dragging, counting or with
## the deck view open; the pointer on the popup keeps the item; leaving the item and its popup, the
## window or the game ends the scan and clears the marks; reduced motion runs no beam loop. The
## count-up marks each item it lifts in gold and clears the marks as its beats end.
## Headless runs never move the mouse, so the tests set the controller's pointer (and its clock,
## which the hold and the throttle read) and send the items' hover signals. Every rect is checked on
## screen (headless runs use a 1280x1280 window: the stage is centred, 280 px down). The real saves
## and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
const ReceiptFooters := preload("res://tests/ui/receipt_footers.gd")
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]

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
## the card's rule text verbatim and no footer, only once the hover is held: then the item
## lifts, tomato brackets mark it, and it beeps once.
func test_the_scan_popup_points_at_the_hovered_item() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_place(screen, ["milk", "bread"])
	var view: ItemView = _hand_views(screen)[1]
	await _hover(screen, view)
	var popup: ScanPopup = screen._scan.popup()
	_assert_quiet(screen, view, sfx)
	await _hold(screen)
	assert_bool(screen._scan.is_full()).is_true()
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


## A belt item's popup opens above its lifted sprite (B2's belt leaves room under the top bar),
## its tail at the sprite's middle, and its footer lists its payout and every step of its slot
## but BASE and PAYOUT, as the receipt words them: here Coffee's fizzle (nothing after it).
func test_a_hovered_belt_item_opens_its_popup_and_lists_its_fizzles() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread", "coffee"])
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	await _hold(screen)
	var popup: ScanPopup = screen._scan.popup()
	assert_int(popup.placement).is_equal(ScanPopup.Placement.ABOVE)
	assert_object(popup.tail().texture).is_same(ScanPopup.TAIL)
	var rect: Rect2 = popup.get_global_rect()
	_assert_on_stage(screen, rect, "belt popup")
	var lifted: Rect2 = ScanOverlay.lifted_sprite(view)
	assert_float(rect.end.y).is_equal(lifted.position.y - ScanPopup.GAP_ABOVE)
	assert_float(rect.position.y).is_greater_equal(_y(screen, ShiftStage.TOP_BAR_BOTTOM))
	assert_bool(rect.intersects(view.below_rect())).is_false()
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


## The done-when of #80: a plain hover shorter than the hold shows nothing (no popup, no lift, no
## brackets, no scan line, no beep); staying on the item for the hold plays the full
## scan, popup included, and beeps once. Leaving the item before the hold cancels it (coming back
## starts it again), and moving to another item starts that item's own hold.
func test_a_plain_hover_is_quiet_until_it_is_held() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	var hold: int = screen._scan.hold_ms()
	# The tuned hold (data/balance/scan.tres): a neutral 0 would make every hover scan at once.
	assert_int(hold).override_failure_message(ScanController.TUNING_PATH).is_greater(0)
	await _hover(screen, hand[0])
	_clock += hold - 1
	await _frames(2)
	_assert_quiet(screen, hand[0], sfx)
	_clock += 1
	await _frames(1)
	assert_bool(screen._scan.is_full()).is_true()
	assert_bool(screen._scan.popup().visible).is_true()
	assert_float(hand[0].body.position.y).is_equal(-ItemView.LIFT)
	assert_bool(screen._scan.overlay().is_posed()).is_true()
	# Still held: no second beep.
	_clock += hold
	await _frames(2)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	# Off every item before the hold: the scan ends, and nothing plays later.
	_clock += ScanController.THROTTLE_MS
	await _leave_to(Vector2(-100, -100), hand[0])
	_assert_cleared(screen)
	await _hover(screen, hand[5])
	_clock += hold - 1
	await _leave_to(Vector2(-100, -100), hand[5])
	_assert_cleared(screen)
	_clock += hold
	await _frames(2)
	_assert_cleared(screen)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	# Back on it, the hold starts again.
	await _hover(screen, hand[5])
	_clock += hold - 1
	await _frames(2)
	_assert_quiet(screen, hand[5], sfx, 1)
	# Onto another item: its own hold starts there.
	_leave(hand[5])
	_point = hand[7].sprite().get_global_rect().get_center()
	hand[7].hovered.emit(hand[7])
	await _frames(2)
	assert_object(screen._scan.scanned()).is_same(hand[7])
	_clock += 1
	await _frames(2)
	_assert_quiet(screen, hand[7], sfx, 1)
	assert_float(hand[5].body.position.y).is_equal(0.0)
	_clock += hold
	await _frames(1)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(2)
	assert_int(sfx.count("scan")).is_equal(0)


## One beep per full scan, at most one per THROTTLE_MS: with a hold of 0 (a tuning given in its
## place), a second item scanned at once is shown in full but silent, a third after the throttle
## beeps, the same item hovered again doesn't, and a scan that ended and starts again on that
## item does.
func test_one_beep_per_full_scan_and_the_throttle_holds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	screen._scan.tuning = ScanTuning.new()
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	await _hover(screen, hand[0])
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	await _hover(screen, hand[0])
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	# Straight on to an item clear of the first one's popup: scanned, but within the throttle.
	_leave(hand[0])
	_point = hand[5].sprite().get_global_rect().get_center()
	hand[5].hovered.emit(hand[5])
	await _frames(1)
	assert_object(screen._scan.scanned()).is_same(hand[5])
	assert_bool(screen._scan.is_full()).is_true()
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
	# The drag cancelled the pending hold: it never ends in a scan.
	_clock += screen._scan.hold_ms()
	await _frames(2)
	_assert_cleared(screen)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(0)
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
## overlay marks it with gold brackets around its lifted sprite, no scan line and no pulse, on
## the stage, every item in turn; the marks clear as the beats end, before the dessert. No hover
## scan shows meanwhile.
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
		if overlay.scan_line().has_area():
			failures.append("slot %d: a scan line on the count-up's marks" % slot)
		if not screen._stage.get_global_rect().encloses(brackets):
			failures.append("slot %d: brackets %s off the stage" % [slot, brackets])
		if posed.is_empty() or posed[-1] != slot:
			posed.append(slot)
		if screen._count_up.intensity != null:
			failures.append("still posed once the total shows")
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_array(posed).is_equal([0, 1, 2, 3])
	_assert_cleared(screen)


## While the pointer is on the popup, the item stays scanned, even over a hand item the popup
## covers, and back on the item it is still scanned, with no second beep. Off the popup and onto
## another item, that one is hovered (quietly); off every item and the popup, the scan ends: the
## popup hides, the item rests and the marks clear.
func test_the_pointer_on_the_popup_keeps_the_item() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	await _hover(screen, hand[0])
	await _hold(screen)
	var popup: Rect2 = screen._scan.popup().get_global_rect()
	var covered: ItemView = hand[1]
	var inside: Vector2 = covered.sprite().get_global_rect().get_center()
	assert_bool(popup.has_point(inside)).is_true()
	_leave(hand[0])
	_point = inside
	covered.hovered.emit(covered)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_same(hand[0])
	assert_bool(screen._scan.is_full()).is_true()
	# Back on the item after reading the popup: still scanned, no second beep.
	_clock += screen._scan.hold_ms()
	covered.unhovered.emit(covered)
	_point = hand[0].sprite().get_global_rect().get_center()
	hand[0].hovered.emit(hand[0])
	await _frames(2)
	assert_object(screen._scan.scanned()).is_same(hand[0])
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	# Off the popup onto an item it doesn't cover.
	_clock += ScanController.THROTTLE_MS
	var free: ItemView = hand[hand.size() - 1]
	var outside: Vector2 = free.sprite().get_global_rect().get_center()
	assert_bool(popup.has_point(outside)).is_false()
	covered.unhovered.emit(covered)
	_point = outside
	free.hovered.emit(free)
	await _frames(2)
	_assert_quiet(screen, free, sfx, 1)
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


## A refresh that rebuilds the items (a pick) keeps the full scan on the same card's new view,
## without a second beep.
func test_a_refresh_keeps_the_scan_on_the_same_card() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	var view: ItemView = _hand_views(screen)[0]
	var card: CardInstance = view.card
	await _hover(screen, view)
	await _hold(screen)
	screen._on_hand_card_clicked(view)
	await _frames(2)
	var scanned: ItemView = screen._scan.scanned()
	assert_object(scanned).is_not_null()
	assert_object(scanned).is_not_same(view)
	assert_object(scanned.card).is_same(card)
	assert_bool(screen._scan.popup().visible).is_true()
	assert_bool(screen._scan.is_full()).is_true()
	assert_bool(scanned.lifted).is_true()
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
	await _hold(screen)
	assert_object(screen._scan.scanned()).is_same(view)
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_true()
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


## Reduced motion: a quiet hover moves nothing; the hold still ends in the full scan, which snaps
## into place with no looping tween (no beam pulse); without it, the beam pulses until the scan
## ends.
func test_reduced_motion_runs_no_beam_loop() -> void:
	var screen: ShiftScreen = await _screen()
	var overlay: ScanOverlay = screen._scan.overlay()
	screen.profile.set_reduced_motion(true)
	await _hover(screen, _hand_views(screen)[0])
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(overlay.is_posed()).is_false()
	assert_int(_looping_tweens()).is_equal(0)
	await _hold(screen)
	assert_bool(screen._scan.is_full()).is_true()
	assert_bool(overlay.is_posed()).is_true()
	assert_bool(overlay.has_beam_loop()).is_false()
	assert_int(_looping_tweens()).is_equal(0)
	await _leave_to(Vector2(-100, -100), _hand_views(screen)[0])
	screen.profile.set_reduced_motion(false)
	await _hover(screen, _hand_views(screen)[1])
	assert_bool(overlay.has_beam_loop()).is_false()
	await _hold(screen)
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
	_instant(screen)
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
	assert_int(ReceiptFooters.printed(receipt).size()).is_equal(
		ReceiptFooters.printing_steps(result).size() + 1
	)
	var expected: Dictionary[int, PackedStringArray] = ReceiptFooters.by_slot(receipt, result)
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
	var failures: PackedStringArray = ReceiptFooters.failures(expected, footers, "reference row")
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	for kind: ScoreStep.StepType in [
		ScoreStep.StepType.FLAT,
		ScoreStep.StepType.MULTIPLIER,
		ScoreStep.StepType.PAYOUT_OVERRIDE,
		ScoreStep.StepType.WASTED,
	]:
		assert_bool(kinds.has(kind)).override_failure_message(str(kind)).is_true()


## Wherever any card in data/cards is hovered (each hand position, a full hand of 8, and each
## belt cell, a full row of products and a coupon), its popup stays in the stage, under the top
## bar and off the item's sprite and sticker (and chips, on the belt); a hand item's opens beside
## it, off the belt (at or below the counter line).
func test_the_popup_keeps_every_card_in_the_stage() -> void:
	var screen: ShiftScreen = await _screen()
	_instant(screen)
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


## Tomato brackets around `view`'s lifted sprite with the scan line across it, on the stage.
func _assert_scanner_posed(screen: ShiftScreen, view: ItemView) -> void:
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_true()
	var sprite: Rect2 = view.sprite().get_global_rect()
	var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
	assert_bool(brackets == sprite.grow(ScanOverlay.BRACKET_OUTSET)).is_true()
	assert_object(overlay.bracket_color()).is_equal(Palette.TOMATO)
	_assert_on_stage(screen, brackets, "brackets")
	var line: Rect2 = overlay.get_global_transform() * overlay.scan_line()
	assert_bool(sprite.encloses(line)).override_failure_message(str(line)).is_true()


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


## No scan: no item scanned, the popup hidden and no marks.
func _assert_cleared(screen: ShiftScreen) -> void:
	assert_object(screen._scan.scanned()).is_null()
	assert_bool(screen._scan.popup().visible).is_false()
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_false()
	assert_that(overlay.brackets()).is_equal(Rect2())


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


## The pointer stays where it is for the hold (on the tests' clock): a scan on an item turns full.
func _hold(screen: ShiftScreen) -> void:
	_clock += screen._scan.hold_ms()
	await _frames(1)


## A hold of 0 (a tuning given in its place): a hover is scanned in full on the next frame.
static func _instant(screen: ShiftScreen) -> void:
	screen._scan.tuning = ScanTuning.new()


## `view` hovered quietly: no popup, the item at rest, the scanner docked with no marks or beam,
## no looping tween and no beep beyond the `beeps` already heard.
func _assert_quiet(screen: ShiftScreen, view: ItemView, sfx: RecordingSfx, beeps: int = 0) -> void:
	assert_object(screen._scan.scanned()).is_same(view)
	assert_bool(screen._scan.is_full()).is_false()
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(view.lifted).is_false()
	assert_float(view.body.position.y).is_equal(0.0)
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_false()
	assert_that(overlay.brackets()).is_equal(Rect2())
	assert_bool(overlay.scan_line().has_area()).is_false()
	assert_int(_looping_tweens()).is_equal(0)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(beeps)


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
