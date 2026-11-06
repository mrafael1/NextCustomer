extends GdUnitTestSuite
## The staff handbook (v1.06, mock-up keywords_guide.html, variant A). The binder fits the
## 1280x720 screen with its tabs, CLOSE, index and entry column apart and inside it; every entry
## opens (its example clip on the real score); the tabs and index rows pick entries; Esc and a
## right-click outside close it. On the shift screen the menu's Guide opens it and a right-click
## while a keyword's or a family's tooltip shows opens that entry (the deep link), except while a
## right-click belongs to something else. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The binder, its tabs, CLOSE, index rows and entry column: inside the screen, none overlapping,
## each tab's name inside its tab; the example clip inside the entry column.
func test_the_binder_fits_the_screen() -> void:
	var page: HandbookPage = await _page()
	page.open_at(&"morning")
	await _frames(3)
	var binder: Rect2 = page.binder_rect()
	assert_bool(SCREEN_RECT.encloses(binder.grow(HandbookPage.SHADOW))).is_true()
	var tops: Array[Rect2] = []
	for group_id: StringName in page._book.group_ids:
		var tab: HandbookButton = page.tab(group_id)
		var rect: Rect2 = tab.get_global_rect()
		assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(group_id).is_true()
		var text: Label = tab.get_node("Text") as Label
		assert_float(UiKit.pixel_text_size(text).x).override_failure_message(group_id).is_less(
			rect.size.x
		)
		tops.append(rect)
	tops.append(page.close_button().get_global_rect())
	_assert_apart(tops)
	assert_bool(SCREEN_RECT.encloses(page.close_button().get_global_rect())).is_true()
	var rows: Array[Rect2] = []
	for row: HandbookButton in page.index_rows():
		assert_bool(binder.encloses(row.get_global_rect())).is_true()
		rows.append(row.get_global_rect())
	assert_int(rows.size()).is_equal(5)
	_assert_apart(rows)
	var column: Rect2 = page.entry_scroll().get_global_rect()
	assert_bool(binder.encloses(column)).is_true()
	for row: Rect2 in rows:
		assert_bool(row.intersects(column)).is_false()
	var clip: Rect2 = page.entry_view().clip().get_global_rect()
	assert_float(clip.position.x).is_greater_equal(column.position.x)
	assert_float(clip.end.x).is_less_equal(column.end.x)
	# The clip's tickets and total sit inside it.
	for ticket: PriceSticker in page.entry_view().clip().tickets():
		assert_bool(clip.encloses(ticket.get_global_rect())).is_true()
	assert_bool(clip.encloses(page.entry_view().clip().total_label().get_global_rect())).is_true()


## Every entry opens in its tab, its rule shown and its clip's total the example's.
func test_every_entry_opens() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	assert_object(page.shown_entry()).is_same(page._book.entry(page._book.first_entry))
	for entry: HandbookEntry in page._book.entries:
		page.show_entry(entry.id)
		await _frames(1)
		var view: HandbookEntryView = page.entry_view()
		assert_object(view.entry()).is_same(entry)
		assert_str(page.shown_group()).is_equal(entry.group)
		assert_str(view.rule_label().text).is_equal(entry.rule)
		if entry.has_example():
			view.clip().stop()
			var total: String = MonitorText.euros(entry.example_total)
			assert_str(view.clip().total_text()).override_failure_message(entry.id).is_equal(total)
			assert_str(view.equation_text()).ends_with(total)
		else:
			assert_object(view.clip()).is_null()
		var picked: Array[String] = []
		for row: HandbookButton in page.index_rows():
			if row.picked:
				picked.append(row.caption())
		assert_array(picked).is_equal([entry.title])


## A tab opens its first entry; an index row its entry; the clip plays, and stops on its final
## state when the handbook closes.
func test_tabs_and_rows_pick_entries() -> void:
	var page: HandbookPage = await _page()
	page.still = false
	page.open_at(&"chain")
	await _frames(2)
	assert_bool(page.entry_view().clip().is_playing()).is_true()
	page.tab(&"families").pressed.emit()
	assert_str(page.shown_entry().id).is_equal("fam_food")
	assert_bool(page.tab(&"families").picked).is_true()
	assert_bool(page.tab(&"keywords").picked).is_false()
	page.index_rows()[4].pressed.emit()
	assert_str(page.shown_entry().id).is_equal("fam_dairy")
	page.tab(&"coupons").pressed.emit()
	assert_str(page.shown_entry().id).is_equal("coupon")
	page.close()
	assert_bool(page.is_open()).is_false()
	page.open_at()
	assert_str(page.shown_entry().id).is_equal("coupon")


## The player's reduced motion is read on every opening (a mid-run toggle holds the clips still).
func test_reduced_motion_is_read_on_each_opening() -> void:
	var page: HandbookPage = await _page()
	var reduced: Array[bool] = [false]
	page.reduced_motion = func() -> bool: return reduced[0]
	page.open_at(&"pair")
	assert_bool(page.still).is_false()
	page.close()
	reduced[0] = true
	page.open_at(&"pair")
	assert_bool(page.still).is_true()
	assert_bool(page.entry_view().clip().still).is_true()


## Esc closes it; a right-click outside the binder closes it, one inside does not.
func test_esc_and_a_right_click_outside_close_it() -> void:
	var page: HandbookPage = await _page()
	var closes: Array[bool] = []
	page.closed.connect(func() -> void: closes.append(true))
	page.open_at(&"pair")
	page._input(_key(KEY_ESCAPE))
	assert_bool(page.is_open()).is_false()
	page.open_at(&"pair")
	page._input(_right_click(page.binder_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	page._input(_right_click(Vector2(20, 700)))
	assert_bool(page.is_open()).is_false()
	assert_int(closes.size()).is_equal(2)


## The shift's menu has Guide, which opens the handbook; a right-click while a ticket's MORNING
## chip shows its tooltip opens MORNING, and on a family glyph that family; a ticket colour's tip
## opens its family. A right-click a day slip would take does nothing new.
func test_the_shift_opens_it_from_the_menu_and_a_tooltip() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee", "milk"])
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	assert_object(page).is_not_null()
	var top_bar: TopBar = screen._top_bar as TopBar
	assert_str(top_bar.guide_button.caption).is_equal("Guide")
	top_bar.guide_button.pressed.emit()
	assert_bool(page.is_open()).is_true()
	page.close()
	var tips: GlyphTips = screen._glyph_tips
	var sticker: PriceSticker = (screen._row_views[0] as ItemView).sticker()
	var chip: KeywordChip = sticker.summary().keywords()[0]
	assert_str(chip.keyword).is_equal(CardText.MORNING_WORD)
	tips.show_tip(chip)
	tips._input(_right_click(chip.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("morning")
	assert_object(tips.shown_glyph()).is_null()
	page.close()
	var glyph: FamilyGlyph = sticker.glyphs()[0]
	tips.show_tip(glyph)
	tips._input(_right_click(glyph.get_global_rect().get_center()))
	assert_str(page.shown_entry().id).is_equal("fam_breakfast")
	page.close()
	var spot: TipTarget = sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as TipTarget
	assert_str(page.entry_for_target(spot).id).is_equal("fam_breakfast")
	# A left click hides the tip and opens nothing.
	tips.show_tip(chip)
	var left: InputEventMouseButton = _right_click(Vector2.ZERO)
	left.button_index = MOUSE_BUTTON_LEFT
	tips._input(left)
	assert_bool(page.is_open()).is_false()
	# A right-click that belongs to something else opens nothing.
	page.deep_link_blocked = func() -> bool: return true
	tips.show_tip(chip)
	tips._input(_right_click(chip.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_false()


## A coupon's ticket (its colour, its glyph, its price) opens that coupon's own entry, its keyword
## chips their keywords'; a monitor line that opens with an entry's title (an inspection's, a
## coupon's) opens that entry. A tip that opens an entry says so on its footer; one that opens
## none (a plain price) has none.
func test_a_coupon_ticket_and_a_titled_line_open_their_entries() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "two_for_one", "milk"])
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	var tips: GlyphTips = screen._glyph_tips
	var sticker: PriceSticker = (screen._row_views[1] as ItemView).sticker()
	assert_bool(sticker.card().is_coupon()).is_true()
	var spot: TipTarget = sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as TipTarget
	assert_str(page.entry_for_target(spot).id).is_equal("two_for_one")
	for glyph: FamilyGlyph in sticker.glyphs():
		assert_str(page.entry_for_target(glyph).id).is_equal("two_for_one")
	tips.show_tip(spot)
	assert_bool(tips.tip().hint().visible).is_true()
	tips._input(_right_click(spot.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("two_for_one")
	page.close()
	var line: TipTarget = auto_free(TipTarget.new())
	for case: Array in [
		["Spot check · slot 3 pays 0€", "spot_check"],
		["Opening deal: ×5 on the first item", "opening_deal"],
		["2 for 1 copies the next item", "two_for_one"],
		["Today's target is 65€", "target"],
	]:
		line.tip_text = case[0]
		var found: HandbookEntry = page.entry_for_target(line)
		assert_object(found).override_failure_message(case[0]).is_not_null()
		if found != null:
			assert_str(String(found.id)).is_equal(case[1])
	line.tip_text = "Printed price 5€"
	assert_object(page.entry_for_target(line)).is_null()
	assert_bool(page.has_entry_for(line)).is_false()
	# A plain item's price window opens nothing, so its tip has no footer.
	var plain: PriceSticker = (screen._row_views[0] as ItemView).sticker()
	var window: PriceWindow = plain.get_node(PriceSticker.WINDOW_NAME) as PriceWindow
	assert_object(page.entry_for_target(window)).is_null()
	tips.show_tip(window)
	assert_bool(tips.tip().hint().visible).is_false()


func _page() -> HandbookPage:
	var page: HandbookPage = auto_free(HandbookPage.new())
	page.still = true
	add_child(page)
	page.size = SCREEN_RECT.size
	await _frames(1)
	return page


static func _assert_apart(rects: Array[Rect2]) -> void:
	for a: int in range(rects.size()):
		for b: int in range(a + 1, rects.size()):
			(
				assert_bool(rects[a].intersects(rects[b]))
				. override_failure_message("%s %s" % [rects[a], rects[b]])
				. is_false()
			)


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


static func _right_click(at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = at
	click.global_position = at
	return click


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
