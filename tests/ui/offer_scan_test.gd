extends GdUnitTestSuite
## The offers as items on the real shift screen (#75, decision 4A): the impulse rack and the
## reward print-out show tray ItemViews (a product with its aisle's glyph, a print-out product
## with its PROMO tag on its price sticker), laid out inside their panel on the 1280x720 stage
## without overlapping, and the hover scanner reads them like hand items
## (ScanController.cover_offers): a hover shows nothing; held (#80), the item lifts, the
## offers' layer marks it with tomato brackets, it beeps once and the one scan popup
## opens in that layer, above the panel, beside the item and inside the stage, with the card's
## rule text and no footer. The offers are
## scanned only while their panel accepts clicks: not while the rack pops in or the print-out's
## items lift, nor with the deck view open; a pick ends the scan and docks the scanner. A click
## on an offer's popup picks nothing, not the neighbour it covers. Headless runs never move the
## mouse, so the tests set the controller's pointer and clock and send the items' hover signals
## (the click test sends real mouse input too). The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Milk, Multipack, Milk x5 = 109: passes the first five quotas (reward_printout_test).
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## A wall-clock limit for the panel to arm.
const ARM_LIMIT_MS := 3000

var _folder: String = ""
var _runner: GdUnitSceneRunner
var _window_size: Vector2i
## Where the tests put the pointer (global).
var _point: Vector2 = Vector2.ZERO
## The controller's clock (ms): only the tests move it.
var _clock: int = 0


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	_point = Vector2(-100, -100)
	_clock = 1000


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The rack's three products are tray items with their aisles' glyphs, side by side without
## overlapping, each sprite and sticker inside the panel, the panel on the 1280x720 stage.
func test_the_rack_shows_its_offer_as_items() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: RewardPanel = screen._reward_panel
	await _until_scannable(panel)
	var items: Array[ItemView] = panel.items()
	assert_int(items.size()).is_equal(3)
	var rect: Rect2 = panel.get_global_rect()
	_assert_inside(SCREEN_RECT, rect, "rack panel")
	_assert_inside(screen._stage.get_global_rect(), rect, "rack panel")
	_assert_items_laid_out(panel)
	for item: ItemView in items:
		assert_object(item.aisle).is_same(screen.run.balance.aisle_of(item.card.definition))
		assert_object(RewardPanel.promo_sticker(item)).is_null()


## Hovering a rack item shows nothing: no popup, no lift, no marks, no beep. Held, the item
## lifts, the offers' layer marks it with tomato brackets, one
## beep, and its popup opens in the layer above the panel (and the shade), beside the item and
## inside the stage, clear of the item's sprite and sticker, with its rule text and no footer.
## Every rack item's popup stays on the stage.
func test_hovering_a_rack_item_scans_it() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_scannable(panel)
	var items: Array[ItemView] = panel.items()
	await _hover(items[0])
	var scan: ScanController = screen._scan
	assert_object(scan.scanned()).is_same(items[0])
	assert_bool(scan.is_full()).is_false()
	assert_float(items[0].body.position.y).is_equal(0.0)
	assert_bool(scan.popup().visible).is_false()
	assert_bool(scan.offer_overlay().is_posed()).is_false()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(0)
	await _hold(screen)
	assert_bool(scan.is_full()).is_true()
	assert_float(items[0].body.position.y).is_equal(-ItemView.LIFT)
	var popup: ScanPopup = scan.popup()
	assert_bool(popup.visible).is_true()
	var layer: Control = popup.get_parent_control()
	assert_str(layer.name).is_equal("OfferScanLayer")
	# Drawn over the panel and the shade, under the deck view.
	assert_int(layer.get_index()).is_greater(panel.get_index())
	assert_int(layer.get_index()).is_greater(screen._shade.get_index())
	assert_int(layer.get_index()).is_less(screen._deck_view.get_index())
	assert_str(popup.rule_label().text).is_equal(items[0].card.definition.rule_text)
	assert_str(popup.name_label().text).is_equal(items[0].card.definition.display_name)
	_assert_offer_popup(screen, items[0])
	_assert_offer_scanner(screen, items[0])
	assert_bool(scan.overlay().is_posed()).is_false()
	assert_int(sfx.count(ScanController.HOVER_SOUND)).is_equal(1)
	for item: ItemView in items:
		await _scan_next(item)
		assert_object(scan.scanned()).is_same(item)
		_assert_offer_popup(screen, item)
		_assert_offer_scanner(screen, item)
	# Off every item and the popup: the scan ends and the marks clear.
	_point = Vector2(-100, -100)
	items[items.size() - 1].unhovered.emit(items[items.size() - 1])
	await _frames(2)
	_assert_cleared(screen)


## No offer scan while the rack pops in (before it arms) or with the deck view open; a scan
## shown when the deck view opens ends; a pick ends the scan and clears the marks.
func test_offers_scan_only_while_their_panel_takes_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: RewardPanel = screen._reward_panel
	assert_bool(panel.can_scan()).is_false()
	_hover_now(panel.items()[0])
	_assert_cleared(screen)
	await _until_scannable(panel)
	await _hover(panel.items()[1])
	assert_object(screen._scan.scanned()).is_same(panel.items()[1])
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	await _frames(2)
	_assert_cleared(screen)
	await _hover(panel.items()[1])
	_assert_cleared(screen)
	screen._on_deck_closed()
	await _hover(panel.items()[2])
	assert_object(screen._scan.scanned()).is_same(panel.items()[2])
	screen._on_reward_picked(screen.run.impulse_offer[2])
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	await _frames(2)
	_assert_cleared(screen)


## An offer's popup covers its neighbours: a click on it while reading it picks nothing (not the
## neighbour under it) and the scan stays; a click on the scanned item itself still picks it.
func test_a_click_on_an_offer_popup_picks_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: RewardPanel = screen._reward_panel
	await _until_scannable(panel)
	var picks: Array[CardDefinition] = []
	panel.picked.connect(func(card: CardDefinition) -> void: picks.append(card))
	var items: Array[ItemView] = panel.items()
	await _hover(items[0])
	await _hold(screen)
	var popup: Rect2 = screen._scan.popup().get_global_rect()
	var covered: Rect2 = Rect2()
	for item: ItemView in items.slice(1):
		var hit: Rect2 = item.get_global_transform() * item.hit_rect()
		if hit.intersects(popup):
			covered = hit.intersection(popup)
			break
	assert_bool(covered.has_area()).override_failure_message(str(popup)).is_true()
	await _click(covered.get_center())
	assert_array(picks).is_empty()
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_object(screen._scan.scanned()).is_same(items[0])
	var picked: CardDefinition = items[0].card.definition
	await _click(items[0].sprite().get_global_rect().get_center())
	assert_array(picks).is_equal([picked])


## The print-out's items: nothing scans while they lift out of the printer; once armed, each
## item scans, its popup beside it on the stage, clear of the receipt and of the item. Its
## products wear the PROMO tag on their price sticker: over the glyph corner, inside the sticker,
## clear of the base value and the summary.
func test_the_printout_scans_once_lifted() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	assert_bool(panel.is_lifting()).is_true()
	_hover_now(panel.items()[0])
	_assert_cleared(screen)
	await _until_scannable(panel)
	await _frames(2)
	_assert_items_laid_out(panel)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var promos: int = 0
	for item: ItemView in panel.items():
		await _scan_next(item)
		assert_object(screen._scan.scanned()).is_same(item)
		_assert_offer_popup(screen, item)
		_assert_offer_scanner(screen, item)
		var popup: Rect2 = screen._scan.popup().get_global_rect()
		assert_bool(popup.intersects(receipt)).override_failure_message(str(popup)).is_false()
		var promo: Label = RewardPanel.promo_sticker(item)
		assert_bool(promo != null).is_equal(item.card.definition.is_product())
		if promo != null:
			promos += 1
			_assert_promo_on_sticker(item, promo)
	# Shift 1's offer is coupons plus promo products: check there was one, or force one.
	if promos == 0:
		var offer: Array[CardDefinition] = [_card("milk"), _card("repeat")]
		panel.show_printout(
			offer, 13, 15, "", screen._receipt, screen._stage, 0, 1.0, RewardPanel.Lift.NONE
		)
		await _frames(2)
		_assert_promo_on_sticker(panel.items()[0], RewardPanel.promo_sticker(panel.items()[0]))
		assert_object(RewardPanel.promo_sticker(panel.items()[1])).is_null()


# --- Helpers ---------------------------------------------------------------------------------


## The offered items are tray items, side by side without overlapping, each one's sprite and
## sticker inside the panel, inside the 1280x720 screen.
func _assert_items_laid_out(panel: RewardPanel) -> void:
	var rect: Rect2 = panel.get_global_rect()
	var previous: Rect2 = Rect2()
	for item: ItemView in panel.items():
		var message: String = (
			"%s: %s in %s" % [item.card.definition.id, item.get_global_rect(), rect]
		)
		assert_int(item.form).is_equal(ItemView.Form.TRAY)
		assert_vector(item.size).is_equal(ItemView.TRAY_SIZE)
		for part: Control in [item, item.sprite(), item.sticker()]:
			_assert_inside(rect, part.get_global_rect(), message)
			_assert_inside(SCREEN_RECT, part.get_global_rect(), message)
		var sticker: Rect2 = item.sticker().get_global_rect()
		assert_bool(item.sprite().get_global_rect().intersects(sticker)).is_false()
		if previous.size != Vector2.ZERO:
			(
				assert_bool(item.get_global_rect().intersects(previous))
				. override_failure_message(message)
				. is_false()
			)
		previous = item.get_global_rect()


## The PROMO tag, as drawn (tilted), inside `item`'s price sticker and clear of its base value's
## text and its summary.
func _assert_promo_on_sticker(item: ItemView, promo: Label) -> void:
	assert_object(promo).is_not_null()
	assert_str(promo.text).is_equal(RewardPanel.PROMO_TEXT)
	var drawn: Rect2 = _drawn_rect(promo)
	var sticker: PriceSticker = item.sticker()
	var message: String = "%s: PROMO %s" % [item.card.definition.id, drawn]
	_assert_inside(sticker.get_global_rect(), drawn, message)
	var base: Label = sticker.base_label()
	var base_text: Rect2 = Rect2(base.get_global_rect().position, base.get_minimum_size())
	assert_bool(drawn.intersects(base_text)).override_failure_message(message).is_false()
	var summary: Rect2 = sticker.summary_label().get_global_rect()
	assert_bool(drawn.intersects(summary)).override_failure_message(message).is_false()
	assert_bool(drawn.intersects(item.sprite().get_global_rect())).is_false()


## The popup beside `item`, inside the stage, clear of the item's sprite and sticker, its text
## inside it.
func _assert_offer_popup(screen: ShiftScreen, item: ItemView) -> void:
	var popup: ScanPopup = screen._scan.popup()
	var rect: Rect2 = popup.get_global_rect()
	var message: String = "%s offered: %s" % [item.card.definition.id, rect]
	_assert_inside(screen._stage.get_global_rect(), rect, message)
	_assert_inside(SCREEN_RECT, rect, message)
	assert_bool(popup.placement in [ScanPopup.Placement.RIGHT, ScanPopup.Placement.LEFT]).is_true()
	for part: Control in [item.sprite(), item.sticker()]:
		(
			assert_bool(rect.intersects(part.get_global_rect()))
			. override_failure_message(message)
			. is_false()
		)
	for label: Label in popup.text_labels():
		_assert_inside(rect, label.get_global_rect(), "'%s'" % label.text)


## Tomato brackets around `item`'s lifted sprite on the offers' layer, on the screen.
func _assert_offer_scanner(screen: ShiftScreen, item: ItemView) -> void:
	var overlay: ScanOverlay = screen._scan.offer_overlay()
	assert_bool(overlay.is_posed()).is_true()
	var sprite: Rect2 = item.sprite().get_global_rect()
	var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
	assert_bool(brackets == sprite.grow(ScanOverlay.BRACKET_OUTSET)).is_true()
	assert_object(overlay.bracket_color()).is_equal(Palette.TOMATO)
	_assert_inside(SCREEN_RECT, brackets, "brackets")


## No scan: nothing scanned, the popup hidden and no marks on either layer.
func _assert_cleared(screen: ShiftScreen) -> void:
	var scan: ScanController = screen._scan
	assert_object(scan.scanned()).is_null()
	assert_bool(scan.popup().visible).is_false()
	for overlay: ScanOverlay in [scan.overlay(), scan.offer_overlay()]:
		assert_bool(overlay.is_posed()).is_false()
		assert_that(overlay.brackets()).is_equal(Rect2())


func _assert_inside(outer: Rect2, inner: Rect2, message: String) -> void:
	(
		assert_bool(outer.encloses(inner))
		. override_failure_message("%s: %s outside %s" % [message, inner, outer])
		. is_true()
	)


## The pointer on `view`'s sprite and its hover sent (headless runs never move the mouse).
func _hover(view: ItemView) -> void:
	await _frames(1)
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)
	await _frames(1)


## A real left click at `point` (global), the pointer moved there first.
func _click(point: Vector2) -> void:
	_point = point
	_runner.simulate_mouse_move(point)
	await _frames(2)
	_runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(2)


## The pointer on `view`'s sprite and its hover sent at once, with no frame for the panel to
## arm or its items to lift.
func _hover_now(view: ItemView) -> void:
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)


## The next item scanned from the one before, past the throttle: its hover arrives while the
## pointer is still off the popup (a popup may cover its neighbours), then the pointer moves on
## and holds there for the full scan.
func _scan_next(view: ItemView) -> void:
	_clock += ScanController.THROTTLE_MS
	view.hovered.emit(view)
	_point = view.sprite().get_global_rect().get_center()
	await _frames(1)
	await _hold(_runner.scene() as ShiftScreen)


## The pointer stays where it is for the hold (on the tests' clock): a scan on an item turns full.
func _hold(screen: ShiftScreen) -> void:
	_clock += screen._scan.hold_ms()
	await _frames(1)


## The screen at the impulse rack, its scanner following _point on the tests' clock.
func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	screen._scan.pointer = func() -> Vector2: return _point
	screen._scan.now_ms = func() -> int: return _clock
	# No music: the Music autoload's bus is left alone.
	screen._count_up.music = null
	await _frames(2)
	return screen


## Waits until the panel's items can be scanned (a generous wall-clock limit).
func _until_scannable(panel: RewardPanel) -> void:
	var start: int = Time.get_ticks_msec()
	while not panel.can_scan() and Time.get_ticks_msec() - start < ARM_LIMIT_MS:
		await get_tree().process_frame
	assert_bool(panel.can_scan()).is_true()


## Passes shift 1 through the real checkout: returns once the print-out has appeared.
func _pass_shift(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		var card: CardInstance = screen.run.hand()[-1]
		assert_bool(screen.run.place(card, screen.run.row.size())).is_true()
	screen._refresh()
	await _frames(2)
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)
	assert_bool(screen._reward_panel.is_printout()).is_true()


## A recording Sfx in place of the screen's: the scan controller finds it on the screen.
func _recording_sfx(screen: ShiftScreen) -> RecordingSfx:
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._sfx = sfx
	screen._count_up._sfx = sfx
	return sfx


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [ShiftDebug.CARDS_FOLDER, id]) as CardDefinition


## A control's rect as drawn: its corners through its global transform (rotation included).
static func _drawn_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform()
	var rect: Rect2 = Rect2(xform * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(control.size.x, 0), Vector2(0, control.size.y), control.size]:
		rect = rect.expand(xform * corner)
	return rect


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
