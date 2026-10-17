extends GdUnitTestSuite
## The hover scanner on the real shift screen (#75, ScanController), opt-in since #80: hovering a
## hand item or a belt item shows nothing (nothing on the monitor, no lift, no brackets, no beep);
## only the pointer staying on that item for the hold (ScanController.hold_ms, from
## data/balance/scan.tres) scans it: its sprite lifts, tomato brackets mark it, it beeps
## (scan_hover, the scan sound at ScanController.HOVER_DB), throttled, and the hung monitor shows
## the item (MonitorView) with the card's rule text, no popup. Leaving the item before the hold
## cancels it; another item starts its own. The layout tests use a hold of 0 (instant). A belt
## item's scan lists every step of its slot but BASE and PAYOUT, worded as the receipt words them:
## all the belt items' scans together hold every step line of the planning receipt, for #60's
## reference row (the golden rows are in scan_popup_golden_rows_test). No scan while dragging,
## counting or with the deck view open; leaving the item, the window or the game ends the scan,
## clears the marks and brings the monitor's idle screen back; reduced motion runs no beam loop.
## The count-up marks each item it lifts in gold and clears the marks as its beats end. Every
## card's scan fits the monitor. Headless runs never move the mouse, so the tests set the
## controller's pointer (and its clock, which the hold and the throttle read) and send the items'
## hover signals. Every rect is checked on screen (headless runs use a 1280x1280 window: the stage
## is centred, 280 px down). The real saves and logs are never touched.

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


## A hand item's scan shows on the monitor once the hover is held, never in a popup: its name and
## rule text verbatim, no pays and no step lines; the item lifts, tomato brackets mark it, and it
## beeps once.
func test_a_held_hand_item_shows_on_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_place(screen, ["milk", "bread"])
	var view: ItemView = _hand_views(screen)[1]
	await _hover(screen, view)
	_assert_quiet(screen, view, sfx)
	await _hold(screen)
	assert_bool(screen._scan.is_full()).is_true()
	var monitor: MonitorView = screen._scan.monitor()
	assert_object(monitor).is_same(screen._monitor)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.popup().visible).is_false()
	assert_float(view.body.position.y).is_equal(-ItemView.BASKET_LIFT)
	assert_str(monitor.scan_rule_label().text).is_equal(view.card.definition.rule_text)
	assert_str(monitor.scan_name_label().text).is_equal(view.card.definition.display_name)
	assert_object(monitor.scan_footer()).is_null()
	_assert_monitor_holds_its_text(screen)
	_assert_scanner_posed(screen, view)
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	var beep: Dictionary = sfx.sounds[sfx.sound_names().find(ScanController.HOVER_SOUND)]
	assert_str(beep["take"]).is_equal("scan")
	assert_float(beep["volume_db"]).is_equal(ScanController.HOVER_DB)
	assert_int(sfx.count("scan")).is_equal(0)


## A belt item's scan on the monitor shows its payout and every step of its slot but BASE and
## PAYOUT, as the receipt words them: here Coffee's fizzle (nothing after it).
func test_a_held_belt_item_lists_its_fizzles_on_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread", "coffee"])
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	await _hold(screen)
	var monitor: MonitorView = screen._scan.monitor()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.popup().visible).is_false()
	var result: ScoreResult = screen.run.preview()
	var expected: PackedStringArray = PackedStringArray()
	var fizzles: int = 0
	for step: ScoreStep in ScanController.footer_steps(result, 2):
		expected.append(ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)))
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles += 1
	assert_int(fizzles).is_equal(1)
	assert_str(expected[expected.size() - 1]).ends_with("  fizzle")
	var texts: PackedStringArray = monitor.scan_footer().texts()
	(
		assert_bool(texts == expected)
		. override_failure_message("%s != %s" % [texts, expected])
		. is_true()
	)
	assert_bool(_monitor_texts(screen).has("€%d" % result.payouts[2])).is_true()
	assert_str(monitor.scan_rule_label().text).is_equal(view.card.definition.rule_text)
	_assert_monitor_holds_its_text(screen)
	_assert_scanner_posed(screen, view)


## A belt item's slot takes drops over the item's art too (#80 play test, 2026-10-17), and the
## hover scan still works there: the pointer resting on the art's top rows, inside the slot's
## drop target, scans the item in full once the hold is up.
func test_a_belt_item_scans_inside_its_slots_drop_target() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["milk", "bread"])
	var view: ItemView = screen._row_views[0] as ItemView
	await _hover(screen, view)
	var sprite: Rect2 = view.sprite().get_global_rect()
	_point = Vector2(sprite.get_center().x, sprite.position.y + 2.0)
	assert_bool(RowStrip.drop_rect(screen._slots[0]).has_point(_point)).is_true()
	await _frames(1)
	await _hold(screen)
	assert_object(screen._scan.scanned()).is_same(view)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(screen._scan.monitor().mode()).is_equal(MonitorView.Mode.SCAN)


## The done-when of #80: a plain hover shorter than the hold shows nothing (nothing on the monitor,
## no lift, no brackets, no scan line, no beep); staying on the item for the hold plays the full
## scan, the monitor included, and beeps once. Leaving the item before the hold cancels it (coming
## back starts it again), and moving to another item starts that item's own hold.
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
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_float(hand[0].body.position.y).is_equal(-ItemView.BASKET_LIFT)
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
	# Straight on to another item: scanned, but within the throttle.
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


## Nothing on the monitor and no beep while an item is dragged or the shift is counted, or with
## the deck view open; a scan shown when the drag starts, or at the CHECKOUT click, ends at once,
## its scanner docked and its item at rest.
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
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.COUNT)
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


## With no popup over the counter, the pointer leaving the scanned item moves the scan: onto
## another item, that one is hovered (quietly, the monitor idle); back on the first one, its hold
## starts again; off every item, the scan ends: the item rests and the marks clear.
func test_leaving_the_item_moves_or_ends_the_scan() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_fill_hand(screen, EIGHT)
	var hand: Array[ItemView] = _hand_views(screen)
	await _hover(screen, hand[0])
	await _hold(screen)
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	# Onto its neighbour: that one is hovered, quietly.
	_leave(hand[0])
	_point = hand[1].sprite().get_global_rect().get_center()
	hand[1].hovered.emit(hand[1])
	await _frames(2)
	_assert_quiet(screen, hand[1], sfx, 1)
	assert_float(hand[0].body.position.y).is_equal(0.0)
	# Back on the first: its hold starts again.
	_leave(hand[1])
	_point = hand[0].sprite().get_global_rect().get_center()
	hand[0].hovered.emit(hand[0])
	await _frames(2)
	_assert_quiet(screen, hand[0], sfx, 1)
	_clock += ScanController.THROTTLE_MS
	await _hold(screen)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(2)
	# Off every item: the scan ends.
	await _leave_to(_on_stage(screen, Rect2(600, 20, 1, 1)).position, hand[0])
	_assert_cleared(screen)
	assert_float(hand[0].body.position.y).is_equal(0.0)


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
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.is_full()).is_true()
	assert_bool(scanned.lifted).is_true()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	screen._let_go()


## A belt item clicked out to the hand moves away from the pointer: the scan ends with the
## refresh. Checked straight after the refresh's deferred calls (a call queued after the click
## runs after them, before the next process step): the monitor is idle and the scanner docked,
## and it stays so.
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
		shown[0] = screen._monitor.mode() == MonitorView.Mode.SCAN or overlay.is_posed()
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
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.IDLE)
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
## check), all the belt items' scans on the monitor together hold every step line of the planning
## receipt but the BASE and PAYOUT lines, each in its own item's scan, in receipt order, none
## folded.
func test_the_scans_hold_every_line_of_the_planning_receipt() -> void:
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
	var expected: Dictionary[int, PackedStringArray] = ReceiptFooters.by_slot(
		receipt,
		result,
		ShiftScreen._names(screen.run.row),
		LoyaltyCard.names(screen.run.upgrades),
		InspectionTag.names(screen.run.inspections)
	)
	var footers: Dictionary[int, PackedStringArray] = {}
	var kinds: Dictionary[int, bool] = {}
	for slot: int in range(screen._row_views.size()):
		var view: ItemView = screen._row_views[slot] as ItemView
		await _hover(screen, view)
		assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
		assert_bool(_monitor_texts(screen).has("€%d" % result.payouts[slot])).is_true()
		footers[slot] = screen._monitor.scan_footer().texts()
		_assert_monitor_holds_its_text(screen)
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


## Wherever any card in data/cards is scanned (each hand position, a full hand of 8, and each belt
## cell, a full row of products and a coupon), its scan's text fits the monitor's screen, its
## rule text whole.
func test_every_card_scan_fits_the_monitor() -> void:
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
			screen._scan.clear()
			await _hover(screen, view)
			_assert_scanned_on_monitor(screen, view)
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
			_assert_scanned_on_monitor(screen, view as ItemView)
	while coupon < coupons.size():
		_fill_row(screen, [products[0], coupons[coupon]])
		coupon += 1
		await _hover(screen, screen._row_views[1] as ItemView)
		_assert_scanned_on_monitor(screen, screen._row_views[1] as ItemView)


# --- Helpers ---------------------------------------------------------------------------------


## `view` scanned in full on the monitor (its name and rule), its text inside the screen.
func _assert_scanned_on_monitor(screen: ShiftScreen, view: ItemView) -> void:
	var message: String = String(view.card.definition.id)
	assert_object(screen._scan.scanned()).override_failure_message(message).is_same(view)
	var monitor: MonitorView = screen._monitor
	assert_int(monitor.mode()).override_failure_message(message).is_equal(MonitorView.Mode.SCAN)
	assert_str(monitor.scan_name_label().text).is_equal(view.card.definition.display_name)
	_assert_monitor_holds_its_text(screen)


## Every text label the monitor's scan shows inside its screen's content, its rule text whole.
func _assert_monitor_holds_its_text(screen: ShiftScreen) -> void:
	var content: Rect2 = _on_stage(screen, MonitorView.CONTENT_RECT)
	for label: Label in screen._monitor.shown_labels():
		var rect: Rect2 = label.get_global_rect()
		(
			assert_bool(content.encloses(rect))
			. override_failure_message("'%s' %s outside %s" % [label.text, rect, content])
			. is_true()
		)
	var rule: Label = screen._monitor.scan_rule_label()
	assert_int(rule.get_visible_line_count()).is_equal(rule.get_line_count())


static func _monitor_texts(screen: ShiftScreen) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in screen._monitor.shown_labels():
		texts.append(label.text)
	return texts


## Tomato brackets around `view`'s lifted sprite with the scan line across it, on the stage. A
## basket item's sprite counts down to the basket's front rim: the lower arms lie on its lip.
func _assert_scanner_posed(screen: ShiftScreen, view: ItemView) -> void:
	var overlay: ScanOverlay = screen._scan.overlay()
	assert_bool(overlay.is_posed()).is_true()
	var sprite: Rect2 = view.sprite().get_global_rect()
	if view.form == ItemView.Form.BASKET:
		var rim: float = _on_stage(screen, Rect2(0, HandBaskets.RIM_FRONT_Y, 0, 0)).position.y
		var lip: float = _on_stage(screen, Rect2(0, HandBaskets.LIP_BOTTOM_Y, 0, 0)).position.y
		assert_float(sprite.end.y).is_greater(rim)
		sprite.size.y = rim - sprite.position.y
		var arms: float = (overlay.get_global_transform() * overlay.brackets()).end.y
		assert_float(arms).is_greater(rim).is_less_equal(lip)
	var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
	assert_bool(brackets == sprite.grow(ScanOverlay.BRACKET_OUTSET)).is_true()
	assert_object(overlay.bracket_color()).is_equal(Palette.TOMATO)
	_assert_on_stage(screen, brackets, "brackets")
	var line: Rect2 = overlay.get_global_transform() * overlay.scan_line()
	assert_bool(sprite.encloses(line)).override_failure_message(str(line)).is_true()


## The slot of the view whose count-up frame (ScanOverlay.scan_frame, its lifted sprite hugging
## the art's top) has `brackets` (global) round it, or -1.
func _lifted_slot(views: Array[CardView], brackets: Rect2) -> int:
	for slot: int in range(views.size()):
		if not is_instance_valid(views[slot]):
			continue
		var frame: Rect2 = ScanOverlay.scan_frame(views[slot] as ItemView)
		if frame.grow(ScanOverlay.BRACKET_OUTSET).is_equal_approx(brackets):
			return slot
	return -1


## No scan: no item scanned, the popup hidden, the monitor not showing a scan and no marks.
func _assert_cleared(screen: ShiftScreen) -> void:
	assert_object(screen._scan.scanned()).is_null()
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(screen._monitor.mode() == MonitorView.Mode.SCAN).is_false()
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


## `view` hovered quietly: nothing on the monitor and no popup, the item at rest, the scanner
## docked with no marks or beam, no looping tween and no beep beyond the `beeps` already heard.
func _assert_quiet(screen: ShiftScreen, view: ItemView, sfx: RecordingSfx, beeps: int = 0) -> void:
	assert_object(screen._scan.scanned()).is_same(view)
	assert_bool(screen._scan.is_full()).is_false()
	assert_bool(screen._scan.popup().visible).is_false()
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.IDLE)
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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
