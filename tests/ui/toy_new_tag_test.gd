extends GdUnitTestSuite
## The FIGURINE BOOK button's NEW tag (v1.30, ToyNewTag): a draw's new figurine puts it up once
## the figurine has joined its lineup card (not at the draw), it hangs over the button's top
## right corner inside the screen, clear of the LED strip and DONE, its word inside the tag; it
## stays up through reopening the screen and goes when the book opens, which marks the figurines
## seen and saves that (CapsuleCounter.mark_all_seen). Under reduced motion it is simply there
## and still; otherwise it swings now and then. Only ids the book can show tag the button.
## Saves and logs go to a temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_new_tag_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_a_new_figurine_tags_the_book_button_after_it_joins() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	var screen: ToyMachinesScreen = await _open(profile)
	var tag: ToyNewTag = _tag(screen)
	assert_bool(tag.visible).is_false()
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	assert_array(profile.new_figurines).has_size(1)
	assert_bool(tag.visible).is_false()  # Held through the reveal.
	screen.reveal().finish_hold()
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(ToyLineupJoin.TO_S * 0.5)
	assert_bool(tag.visible).is_false()  # Still flying.
	join.seek(ToyLineupJoin.TO_S + 0.01)
	assert_bool(tag.visible).is_true()  # The tick: the figurine has joined.
	join.finish()
	await await_millis(roundi(ToyNewTag.DROP_S * 1000.0) + 100)
	await _frames(2)
	_assert_tag_placed(screen)


func test_opening_the_book_marks_them_seen_and_saves_it() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.new_figurines.assign([&"sugar_cubes"])
	profile.unlocked_items[&"sugar_cubes"] = 0
	var screen: ToyMachinesScreen = await _open(profile)
	assert_bool(_tag(screen).visible).is_true()
	# Reopened, it is still up: nothing has been seen yet.
	screen.close()
	screen.open(screen.counter(), Kit.balance())
	await _frames(2)
	assert_bool(_tag(screen).visible).is_true()
	screen.shelf_button().pressed.emit()
	assert_bool(screen.book().visible).is_true()
	assert_bool(_tag(screen).visible).is_false()
	assert_array(profile.new_figurines).is_empty()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_object(saved).is_not_null()
	assert_array(saved.new_figurines).is_empty()
	assert_bool(saved.unlocked_items.has(&"sugar_cubes")).is_true()
	screen.book().back_button().pressed.emit()
	assert_bool(_tag(screen).visible).is_false()


func test_the_counter_marks_single_items_seen() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.new_figurines.assign([&"sugar_cubes", &"crisps"])
	profile.unlocked_items[&"sugar_cubes"] = 0
	profile.unlocked_items[&"crisps"] = 0
	var counter: CapsuleCounter = _counter(profile)
	assert_array(counter.new_figurines()).is_equal([&"sugar_cubes", &"crisps"])
	assert_bool(counter.mark_seen([&"crisps"])).is_true()
	assert_bool(counter.mark_seen([&"crisps"])).is_false()  # Nothing changed: no save.
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_array(saved.new_figurines).is_equal([&"sugar_cubes"])
	# The machines switched off (saves don't work): the change stays in memory only.
	var off: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, false
	)
	assert_bool(off.mark_all_seen()).is_false()
	assert_array(profile.new_figurines).is_empty()


func test_reduced_motion_shows_the_tag_in_place() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.set_reduced_motion(true)
	profile.new_figurines.assign([&"sugar_cubes"])
	profile.unlocked_items[&"sugar_cubes"] = 0
	var screen: ToyMachinesScreen = await _open(profile)
	_assert_tag_placed(screen)
	# Still: it never swings.
	var tag: ToyNewTag = _tag(screen)
	for step: int in 40:
		tag.advance(ToyNewTag.SWING_EVERY_S / 20.0)
		assert_int(tag.swing()).is_equal(0)


## Once on, the tag swings on its string every SWING_EVERY_S, one art px each way, and is back at
## rest in between (review fix: it went still and was easy to miss).
func test_the_tag_swings_now_and_then() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.new_figurines.assign([&"sugar_cubes"])
	profile.unlocked_items[&"sugar_cubes"] = 0
	var screen: ToyMachinesScreen = await _open(profile)
	var tag: ToyNewTag = _tag(screen)
	tag.set_shown(false, true)
	tag.set_shown(true, false)
	tag.advance(ToyNewTag.DROP_S + 0.01)
	var seen: Array[int] = []
	for step: int in 100:
		tag.advance(ToyNewTag.SWING_EVERY_S / 50.0)
		if not seen.has(tag.swing()):
			seen.append(tag.swing())
	seen.sort()
	assert_array(seen).is_equal([-1, 0, 1])
	tag.advance(0.01)
	tag.advance(ToyNewTag.SWING_EVERY_S - ToyNewTag.SWING_S - 0.1)
	assert_int(tag.swing()).is_equal(0)


## A second draw while a figurine is still new: the tag stays up through the reveal and the join
## and doesn't drop in again. An id the book can't show (not owned, or no longer in the data) never
## tags the button, and opening the book clears it too. Reopened, the book shows nothing new.
func test_the_tag_follows_what_the_book_can_show() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	profile.new_figurines.assign([&"sugar_cubes"])
	profile.unlocked_items[&"sugar_cubes"] = 0
	var screen: ToyMachinesScreen = await _open(profile)
	var tag: ToyNewTag = _tag(screen)
	await await_millis(roundi(ToyNewTag.DROP_S * 1000.0) + 100)
	var rest: Vector2 = (tag.get_child(0) as Control).position
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	assert_bool(tag.visible).is_true()
	screen.reveal().finish_hold()
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(ToyLineupJoin.TO_S + 0.01)
	assert_bool(tag.visible).is_true()
	assert_float((tag.get_child(0) as Control).position.y).is_equal(rest.y)  # No new drop.
	join.finish()
	assert_array(profile.new_figurines).has_size(2)
	screen.shelf_button().pressed.emit()
	var tagged: int = 0
	for card: BookCard in _all_cards(screen.book()):
		tagged += 1 if card.new_tag() != null else 0
	assert_int(tagged).is_equal(2)
	screen.book().back_button().pressed.emit()
	await _frames(2)
	# Reopened: nothing new, no tag, no dot, no NEW LED.
	screen.shelf_button().pressed.emit()
	for card: BookCard in _all_cards(screen.book()):
		assert_object(card.new_tag()).is_null()
	var menu: PixelDropdown = screen.book().family_menu()
	assert_object(menu.dot()).is_null()
	for index: int in menu.options().size():
		assert_object(menu.dot(index)).is_null()
	assert_bool(screen.book().leds()[1].visible).is_false()
	screen.book().back_button().pressed.emit()
	# Stale ids: one not owned, one no product has.
	profile.new_figurines.assign([&"crisps", &"gone_item"])
	profile.unlocked_items[&"gone_item"] = 0
	screen.close()
	screen.open(screen.counter(), Kit.balance())
	await _frames(2)
	assert_array(screen.counter().new_figurines()).is_empty()
	assert_bool(tag.visible).is_false()
	screen.shelf_button().pressed.emit()
	assert_array(profile.new_figurines).is_empty()
	await _frames(2)


## Every card in the book, NEWEST spread by spread (then back to BOOK ORDER).
static func _all_cards(book: FigurineBook) -> Array[BookCard]:
	var found: Array[BookCard] = []
	book.set_sort(BookOrder.Sort.NEWEST)
	for spread: int in book.spread_count():
		found.append_array(book.cards())
		book.turn(1)
		book.page_turn().finish()
	book.set_sort(BookOrder.Sort.BOOK)
	return found


## The tag on screen, over the button's top right corner (sticking out above it and past its
## right edge), its word inside its body, clear of the strip and DONE, on the 2 px grid.
func _assert_tag_placed(screen: ToyMachinesScreen) -> void:
	var tag: ToyNewTag = _tag(screen)
	var art: Rect2 = Kit.rect(tag.get_child(0) as Control)
	var button: Rect2 = Kit.rect(screen.shelf_button())
	assert_bool(Kit.SCREEN_RECT.encloses(art)).override_failure_message(str(art)).is_true()
	assert_vector(art.size).is_equal(Vector2(ToyNewTag.ART.get_size()) * ArtStyle.ART_SCALE)
	assert_vector(art.position).is_equal(button.position + ToyNewTag.ON_BUTTON)
	assert_bool(art.intersects(button)).is_true()
	assert_float(art.position.y).is_less(button.position.y)
	assert_float(art.end.x).is_greater(button.end.x)
	assert_vector(art.position.posmodv(Vector2(2, 2))).is_equal(Vector2.ZERO)
	var word: Rect2 = Kit.rect(tag.word())
	var body: Rect2 = Rect2(
		art.position + Vector2(ToyNewTag.BODY_LEFT * ArtStyle.ART_SCALE, 0),
		Vector2((ToyNewTag.BODY_RIGHT - ToyNewTag.BODY_LEFT + 1) * ArtStyle.ART_SCALE, art.size.y)
	)
	assert_bool(body.encloses(word)).override_failure_message(str(word)).is_true()
	assert_str(tag.word().text()).is_equal(ToyNewTag.TEXT)
	assert_bool(art.intersects(Kit.rect(screen.strip()))).is_false()
	assert_bool(art.intersects(Kit.rect(screen.done_button()))).is_false()


func _tag(screen: ToyMachinesScreen) -> ToyNewTag:
	return screen.shelf_button().get_node("NewTag") as ToyNewTag


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _counter(profile: ProfileState) -> CapsuleCounter:
	return CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)


func _open(profile: ProfileState) -> ToyMachinesScreen:
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(_counter(profile), Kit.balance())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
