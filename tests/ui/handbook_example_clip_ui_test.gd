extends GdUnitTestSuite
## The handbook's clips on test-made pages (the guide feedback of 2026-11-11 took the GAINED and
## TODAY'S TARGET pages away with the SHIFT tab; the clip still shows what they showed): a Price gun
## relabel's tag and gained glyph, a quota's receipt. The real saves and logs are never touched.

const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The step the clips' tweens are driven by.
const STEP := 0.05

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A Price gun relabel's clip wears the Price gun's tag on the relabelled item and the gained
## glyph on its ticket.
func test_a_relabel_wears_the_price_gun_tag() -> void:
	var book: HandbookBook = _book_of(["potatoes", "milk"], ["1:Breakfast"], 0)
	var clip: HandbookClip = await _clip(book.first_entry, true, book)
	var tagged: int = 0
	for item: ItemView in clip.items():
		if PinFlow.price_tag(item) != null:
			tagged += 1
			assert_object(item.sticker().gained()).is_not_null()
	assert_int(tagged).is_greater(0)


## A quota's clip shows the receipt's TODAY'S TARGET inside it, apart from the LED.
func test_a_quota_shows_its_receipt() -> void:
	var book: HandbookBook = _book_of(["bread", "eggs", "milk"], [], 15)
	var clip: HandbookClip = await _clip(book.first_entry, true, book)
	assert_object(clip.receipt_target()).is_not_null()
	var receipt: Rect2 = clip.receipt_target().get_global_rect()
	assert_bool(clip.get_global_rect().encloses(receipt)).is_true()
	assert_bool(receipt.intersects(clip.led().get_global_rect())).is_false()


## A handbook of one test-made keyword page whose example is `row`, its Price gun `relabels`
## and its `quota`.
static func _book_of(row: Array[String], relabels: Array[String], quota: int) -> HandbookBook:
	var entry: HandbookEntry = HandbookEntry.new()
	entry.id = &"test_entry"
	entry.group = &"keywords"
	entry.title = "TEST"
	entry.rule = "A test page."
	entry.example_row = PackedStringArray(row)
	entry.example_relabels = PackedStringArray(relabels)
	entry.example_quota = quota
	var book: HandbookBook = HandbookBook.new()
	book.group_ids = [entry.group]
	book.group_titles = PackedStringArray(["KEYWORDS"])
	book.entries = [entry]
	book.first_entry = entry.id
	return book


## The clip of entry `id` (in `book`, the game's by default) on a fresh handbook page, `still` or
## playing (its tween paused, to be stepped by hand).
func _clip(id: StringName, still: bool, book: HandbookBook = null) -> HandbookClip:
	var page: HandbookPage = auto_free(HandbookPage.new(book))
	page.still = still
	add_child(page)
	page.size = SCREEN_RECT.size
	await _frames(1)
	page.open_at(id)
	await _frames(3)
	var clip: HandbookClip = page.entry_view().clip()
	_advance(clip, 0.0)
	return clip


## Steps the clip's tween (the current loop's) `seconds` on, holding it paused.
func _advance(clip: HandbookClip, seconds: float = STEP) -> void:
	var tween: Tween = clip._tween
	if tween == null or not tween.is_valid():
		return
	tween.pause()
	if seconds > 0.0:
		tween.custom_step(seconds)
	if clip._tween != null and clip._tween != tween and clip._tween.is_valid():
		clip._tween.pause()


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
