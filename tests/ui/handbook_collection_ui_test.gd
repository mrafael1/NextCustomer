extends GdUnitTestSuite
## The handbook's COLLECTION link (2026-11-19, the user: "adding figurine book link (rename to
## collection) in handbook"; memory: UI tests check on-screen geometry): where offered, a
## COLLECTION tab stands on the binder's top edge left of CLOSE, inside the screen at 1280x720 and
## 1920x1080, apart from the group tabs and CLOSE, its name inside it. A click opens the card book
## over the binder (its stage on the screen, covering the binder); Esc or BACK close the book and
## leave the handbook open; closing the handbook closes the book. The title and the run offer it.
## The real saves and logs are never touched.

const TITLE := "res://ui/title_screen.tscn"
const SHIFT := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Not offered: no tab. Offered: the tab on the tabs' row, inside the screen at both sizes, apart
## from the group tabs and CLOSE, its name inside it.
func test_the_tab_fits_beside_close() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var page: HandbookPage = await _page(false)
		page.open_at()
		await _frames(2)
		assert_bool(page.collection_tab.is_visible_in_tree()).is_false()
		page.offer_collection(_empty_profile, load(BALANCE) as BalanceDefinition)
		await _frames(1)
		var screen: Rect2 = page.get_viewport_rect()
		var tab: Rect2 = page.collection_tab.get_global_rect()
		var name_text: String = "%s %s" % [window, tab]
		assert_bool(page.collection_tab.is_visible_in_tree()).is_true()
		assert_bool(screen.encloses(tab)).override_failure_message(name_text).is_true()
		var others: Array[Rect2] = [tab, page.close_button().get_global_rect()]
		for group_id: StringName in page._book.group_ids:
			var group_tab: Rect2 = page.tab(group_id).get_global_rect()
			others.append(group_tab)
			assert_float(tab.end.y).is_equal_approx(group_tab.end.y, 0.5)  # A picked one rises.
		for a: int in range(others.size()):
			for b: int in range(a + 1, others.size()):
				(
					assert_bool(others[a].intersects(others[b]))
					. override_failure_message("%s %s" % [others[a], others[b]])
					. is_false()
				)
		var label: Label = page.collection_tab.get_node("Text") as Label
		assert_str(label.text).is_equal(HandbookPage.COLLECTION_TEXT)
		assert_float(UiKit.pixel_text_size(label).x).is_less(tab.size.x)
		page.close()


## A click opens the book over the binder; Esc closes only the book, BACK too, and closing the
## handbook closes an open book.
func test_the_tab_opens_the_book_and_back_returns() -> void:
	get_tree().root.size = SIZES[0]
	var page: HandbookPage = await _page(true)
	page.open_at()
	await _frames(1)
	page.collection_tab.pressed.emit()
	await _frames(2)
	var collection: HandbookCollection = page.collection
	assert_object(collection).is_not_null()
	assert_bool(collection.is_open()).is_true()
	var book: FigurineBook = collection.book()
	assert_bool(book.is_visible_in_tree()).is_true()
	var stage: Rect2 = book.get_global_rect()
	assert_bool(page.get_viewport_rect().encloses(stage)).is_true()
	assert_bool(stage.encloses(page.binder_rect())).is_true()
	assert_bool(page.get_viewport_rect().encloses(book.back_button().get_global_rect())).is_true()
	# The binder leaves Esc to the book: the book closes, the handbook stays.
	page._input(_key(KEY_ESCAPE))
	assert_bool(collection.is_open()).is_true()
	collection._input(_key(KEY_ESCAPE))
	assert_bool(collection.is_open()).is_false()
	assert_bool(page.is_open()).is_true()
	page.collection_tab.pressed.emit()
	assert_bool(collection.is_open()).is_true()
	book.back_button().pressed.emit()
	assert_bool(collection.is_open()).is_false()
	assert_bool(page.is_open()).is_true()
	page.collection_tab.pressed.emit()
	page.close()
	assert_bool(collection.is_open()).is_false()
	await _frames(1)


## The title's handbook and the run's both offer the COLLECTION.
func test_the_title_and_the_run_offer_it() -> void:
	get_tree().root.size = SIZES[0]
	var title_runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = title_runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(3)
	var title_page: HandbookPage = title.find_child("HandbookPage", false, false) as HandbookPage
	title_page.open_at()
	await _frames(1)
	assert_bool(title_page.collection_tab.is_visible_in_tree()).is_true()
	title_page.collection_tab.pressed.emit()
	assert_bool(title_page.collection.is_open()).is_true()
	title_page.close()
	var shift_runner: GdUnitSceneRunner = scene_runner(SHIFT)
	var shift: ShiftScreen = shift_runner.scene()
	await _frames(2)
	var page: HandbookPage = shift.find_child("HandbookPage", false, false) as HandbookPage
	page.open_at()
	await _frames(1)
	assert_bool(page.collection_tab.is_visible_in_tree()).is_true()
	page.collection_tab.pressed.emit()
	assert_bool(page.collection.is_open()).is_true()
	page.close()
	await _frames(1)


func _page(offered: bool) -> HandbookPage:
	var page: HandbookPage = HandbookPage.new()
	page.still = true
	add_child(page)
	if offered:
		page.offer_collection(_empty_profile, load(BALANCE) as BalanceDefinition)
	await _frames(1)
	return auto_free(page)


static func _empty_profile() -> ProfileState:
	return ProfileState.new()


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
