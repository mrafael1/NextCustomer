extends GdUnitTestSuite
## The FIGURINE BOOK's dropdowns (PixelDropdown; v1.26 round 5's SORT dropdown, round 7's FAMILY
## dropdown, the user: "sort by family can be removed from sort and have its own dropdown
## somewhere where old bookmarks where ... sort can keep newest / food / non-food. it will sort
## selected first dropdown"; memory: UI tests check on-screen geometry). Closed, the FAMILY plate
## ("FAMILY: ALL") stands over the binder's top left and the SORT plate ("SORT: BOOK ORDER") in
## the footer, each with its arrow, on the stage clear of the pages and the other controls; open,
## FAMILY's list hangs under its plate and SORT's stands on its plate, inside the stage, clear of
## the footer's other controls, every option inside it with its words and dot on its face. FAMILY
## lists ALL, the families in palette order, OTHER FOOD and COUPONS, each with its glyph; SORT
## BOOK ORDER, NEWEST, FOOD and NON-FOOD, applied within the family (BREAKFAST + NON-FOOD: its
## non-food cards, the header "BREAKFAST · NON-FOOD n/m"; a pick showing nothing says NO CARDS).
## The mouse and the keys drive them; only one list is open at a time; a click outside closes it
## and does nothing more; Esc closes the open list before it leaves the book. Checked at 1280x720
## and through the TOY MACHINES in a 1920x1080 window.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const STAGE := Rect2(0, 0, 1280, 720)

var _window_size: Vector2i
var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_book_dropdowns_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(STAGE.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_the_dropdowns_sit_on_the_stage_closed_and_open(
	window: Vector2i, _test_parameters := [[Vector2i(1280, 720)], [Vector2i(1920, 1080)]]
) -> void:
	get_tree().root.size = window
	var book: FigurineBook = await _book_in_machines()
	var stage: Rect2 = book.get_global_rect()
	assert_vector(stage.size).is_equal(STAGE.size)
	assert_bool(get_viewport().get_visible_rect().encloses(stage)).is_true()
	var pages: Array[Rect2] = []
	for page: Rect2i in BookArt.PAGE_RECTS:
		pages.append(_art_rect(page, stage.position))
	var footer: Array[Rect2] = [
		book.prev_button().get_global_rect(),
		book.next_button().get_global_rect(),
		book.back_button().get_global_rect(),
		book.leds()[2].get_global_rect(),
	]
	var top: Array[Rect2] = [
		book.leds()[0].get_global_rect(),
		book.leds()[1].get_global_rect(),
		(book.get_node("Title") as Control).get_global_rect(),
	]
	var family: PixelDropdown = book.family_menu()
	var sort: PixelDropdown = book.sort_menu()
	var binder: Rect2 = _art_rect(BookArt.BINDER_RECT, stage.position)
	for menu: PixelDropdown in [family, sort]:
		var plate: Rect2 = menu.plate().get_global_rect()
		# Closed: the plate on the stage, clear of the pages and of every other control; its
		# words (and dot) and arrow on its face, apart.
		assert_bool(stage.encloses(plate)).override_failure_message(str(plate)).is_true()
		for rect: Rect2 in pages + footer + top:
			assert_bool(plate.intersects(rect)).override_failure_message(str(rect)).is_false()
		assert_bool(menu.is_open()).is_false()
		assert_bool(menu.list().visible).is_false()
		var face: Rect2 = menu.plate().face().get_global_rect()
		var arrow: Rect2 = menu.arrow().get_global_rect()
		var words: Rect2 = menu.caption_line().get_global_rect()
		var end: float = words.end.x
		if menu.dot() != null:
			end = menu.dot().get_global_rect().end.x
			assert_bool(face.encloses(menu.dot().get_global_rect())).is_true()
		assert_bool(face.encloses(arrow)).override_failure_message(str(arrow)).is_true()
		assert_bool(face.encloses(words)).override_failure_message(str(words)).is_true()
		assert_float(arrow.position.x - end).is_greater_equal(4.0 * ArtStyle.ART_SCALE)
		# Open: the list inside the stage on its side of the plate, its left edge the plate's,
		# clear of the footer's other controls; its options inside it, apart, in order, each with
		# its tick inside the list and its words (and dot) on its face.
		menu.plate().pressed.emit()
		await _frames(1)
		assert_bool(menu.is_open()).is_true()
		var list: Rect2 = menu.list().get_global_rect()
		assert_bool(stage.encloses(list)).override_failure_message(str(list)).is_true()
		assert_float(list.position.x).is_equal(plate.position.x)
		if menu == family:
			assert_float(list.position.y).is_greater_equal(plate.end.y)
		else:
			assert_float(list.end.y).is_less_equal(plate.position.y)
		for rect: Rect2 in footer:
			assert_bool(list.intersects(rect)).override_failure_message(str(rect)).is_false()
		var options: Array[MenuPlate] = menu.options()
		for index: int in options.size():
			var option: Rect2 = options[index].get_global_rect()
			assert_bool(list.encloses(option)).override_failure_message(str(option)).is_true()
			var tick: Rect2 = options[index].tick().get_global_rect()
			assert_bool(list.encloses(tick)).override_failure_message(str(tick)).is_true()
			var option_face: Rect2 = options[index].face().get_global_rect()
			var line: Rect2 = menu.option_line(index).get_global_rect()
			assert_bool(option_face.encloses(line)).override_failure_message(str(line)).is_true()
			if menu.dot(index) != null:
				assert_bool(option_face.encloses(menu.dot(index).get_global_rect())).is_true()
			if index > 0:
				var above: Rect2 = options[index - 1].get_global_rect()
				assert_float(option.position.y).is_greater(above.end.y)
		# The picked option in the tomato frames, marked (lit, its tick showing) on opening.
		assert_int(menu.marked()).is_equal(0)
		assert_bool(options[0].is_lit()).is_true()
		assert_bool(options[0].tick().visible).is_true()
		for option: MenuPlate in options.slice(1):
			assert_bool(option.is_lit()).is_false()
		menu.close_list()
	# The options: FAMILY's ALL then every family (its glyph first), OTHER FOOD, COUPONS; SORT's
	# the four sorts.
	var captions: Array[String] = []
	for index: int in family.options().size():
		captions.append(family.option_line(index).text())
		var icons: Array[Node] = family.option_line(index).find_children(
			"*", "TextureRect", false, false
		)
		assert_int(icons.size()).is_equal(0 if index == 0 else 1)
	(
		assert_array(captions)
		. is_equal(
			[
				"ALL",
				"BAKERY",
				"PRODUCE",
				"DAIRY",
				"SNACK",
				"HOUSEHOLD",
				"BREAKFAST",
				"CLEARANCE",
				"OTHER FOOD",
				"COUPONS",
			]
		)
	)
	assert_str(family.caption_line().text()).is_equal("FAMILY: ALL")
	var sorts: Array[String] = []
	for index: int in sort.options().size():
		sorts.append(sort.option_line(index).text())
	assert_array(sorts).is_equal(["BOOK ORDER", "NEWEST", "FOOD", "NON-FOOD"])
	assert_str(sort.caption_line().text()).is_equal("SORT: BOOK ORDER")
	# The FAMILY plate's face (sunk too) over the binder's top edge; the lists stand over
	# everything on the stage: the dropdowns are the book's last children.
	var sunk: float = family.plate().face().get_global_rect().end.y + MenuPlate.PLATE_SINK
	assert_float(sunk).is_less_equal(binder.position.y)
	# (Only the GlyphTips, drawing no control of its own but the cards' tips, is after them.)
	assert_object(book.get_child(book.get_child_count() - 1)).is_instanceof(GlyphTips)
	assert_int(family.get_index()).is_equal(book.get_child_count() - 2)
	assert_int(sort.get_index()).is_equal(book.get_child_count() - 3)
	await _frames(2)


## The longest FAMILY caption still fits its plate with its glyph and dot before the arrow.
func test_every_family_fits_the_plate_with_its_dot() -> void:
	var profile: ProfileState = Kit.profile(0, 0, Kit.full_counts())
	var fresh: Array[StringName] = []
	fresh.assign(profile.unlocked_items.keys())
	var book: FigurineBook = await _book(profile, fresh)
	var menu: PixelDropdown = book.family_menu()
	for index: int in book.families().size():
		book.set_filter(book.families()[index])
		var face: Rect2 = menu.plate().face().get_global_rect()
		var words: Rect2 = menu.caption_line().get_global_rect()
		var arrow: Rect2 = menu.arrow().get_global_rect()
		assert_bool(face.encloses(words)).override_failure_message(str(words)).is_true()
		if menu.dot() != null:
			var dot: Rect2 = menu.dot().get_global_rect()
			assert_float(dot.position.x).is_greater(words.end.x)
			assert_float(arrow.position.x - dot.end.x).is_greater_equal(4.0 * ArtStyle.ART_SCALE)
		else:
			assert_float(arrow.position.x - words.end.x).is_greater_equal(4.0 * ArtStyle.ART_SCALE)
	await _frames(2)


## Each sort within each family shows the cards carrying the family that the sort keeps (FOOD
## its food cards, NON-FOOD the others, NEWEST and BOOK ORDER all of them), once each, headed
## "<FAMILY> · <SORT> n/m" (BOOK ORDER: "<FAMILY> n/m"); under ALL, "FOOD n/m", "NON-FOOD n/m",
## "NEWEST FIRST n/m". BREAKFAST + NON-FOOD holds Coffee and Tea bags; COUPONS + FOOD none.
func test_each_sort_applies_within_the_family() -> void:
	var profile: ProfileState = Kit.profile(0, 0, {&"pantry": 1, &"household": 1})
	profile.coupon_uses[Kit.balance().coupon_pool[0].id] = 1
	var book: FigurineBook = await _book(profile)
	var entries: Array[BookEntry] = BookOrder.entries(
		Kit.balance(),
		profile.unlocked_items,
		FamilyPalette.shared().main_family_order,
		profile.coupon_uses
	)
	var palette: FamilyPalette = FamilyPalette.shared()
	for family: String in ["", "Breakfast", BookEntry.OTHER_FOOD]:
		book.set_filter(family)
		for sort: int in BookOrder.Sort.size():
			book.sort_menu().plate().pressed.emit()
			book.sort_menu().options()[sort].pressed.emit()
			assert_int(book.sort_mode()).is_equal(sort)
			assert_str(book.filter()).is_equal(family)
			var counted: Vector2i = BookOrder.count_shown(entries, sort, family)
			var count: String = FigurineBook.COUNT_TEXT % [counted.x, counted.y]
			var expected: String = ""
			if not family.is_empty():
				expected = BookCard.family_style(family, palette).display_name.to_upper()
				if sort != BookOrder.Sort.BOOK:
					expected += " · " + FigurineBook.SORT_WORDS[sort]
			elif sort == BookOrder.Sort.NEWEST:
				expected = FigurineBook.NEWEST_HEADER
			else:
				expected = FigurineBook.SORT_WORDS[sort]
			var seen: Array[StringName] = []
			for spread: int in book.spread_count():
				await _frames(1)
				for side: int in 2:
					var header: PixelLine = book.header(side)
					if header != null and not (family.is_empty() and sort == BookOrder.Sort.BOOK):
						assert_str(header.text()).is_equal(expected + " " + count)
				for card: BookCard in book.cards():
					var entry: BookEntry = card.entry()
					assert_bool(seen.has(entry.card.id)).is_false()
					seen.append(entry.card.id)
					assert_bool(BookOrder.shows(entry, sort, family)).is_true()
				book.turn(1)
				book.page_turn().finish()
			assert_int(seen.size()).is_equal(counted.y)
			if family == "Breakfast" and sort == BookOrder.Sort.NON_FOOD:
				assert_array(seen).contains([&"coffee", &"tea_bags"])
	# COUPONS + FOOD: one page, headed, saying NO CARDS.
	book.set_filter(BookEntry.COUPON_FAMILY)
	book.set_sort(BookOrder.Sort.FOOD)
	await _frames(1)
	assert_int(book.spread_count()).is_equal(1)
	assert_int(book.cards().size()).is_equal(0)
	assert_str(book.header(0).text()).is_equal("COUPONS · FOOD 0/0")
	var empty: PixelLine = book.header(0).get_parent().get_node("Empty") as PixelLine
	assert_str(empty.text()).is_equal(FigurineBook.EMPTY_TEXT)
	var page: Rect2 = _art_rect(BookArt.PAGE_RECTS[0], book.global_position)
	assert_bool(page.encloses(empty.get_global_rect())).is_true()
	await _frames(2)


func test_the_keys_drive_the_dropdowns() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0))
	var menu: PixelDropdown = book.sort_menu()
	# Enter opens SORT, the picked sort marked; Down moves the mark (wrapping), Up back.
	book._unhandled_key_input(Kit.key(KEY_ENTER))
	assert_bool(menu.is_open()).is_true()
	assert_int(menu.marked()).is_equal(BookOrder.Sort.BOOK)
	book._unhandled_key_input(Kit.key(KEY_DOWN))
	book._unhandled_key_input(Kit.key(KEY_DOWN))
	assert_int(menu.marked()).is_equal(BookOrder.Sort.FOOD)
	assert_bool(menu.options()[BookOrder.Sort.FOOD].is_lit()).is_true()
	assert_bool(menu.options()[BookOrder.Sort.BOOK].is_lit()).is_false()
	# Keys that turn pages or step the family do nothing while it is open.
	book._unhandled_key_input(Kit.key(KEY_RIGHT))
	assert_int(book.spread()).is_equal(0)
	assert_str(book.filter()).is_equal("")
	# Enter picks the marked sort and closes it.
	book._unhandled_key_input(Kit.key(KEY_ENTER))
	assert_bool(menu.is_open()).is_false()
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.FOOD)
	# Up from FOOD wraps; Esc closes with nothing picked, and does not leave.
	var backs: Array[int] = [0]
	book.back_pressed.connect(func() -> void: backs[0] += 1)
	book._unhandled_key_input(Kit.key(KEY_ENTER))
	for step: int in 3:
		book._unhandled_key_input(Kit.key(KEY_UP))
	assert_int(menu.marked()).is_equal(BookOrder.Sort.NON_FOOD)
	book._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_bool(menu.is_open()).is_false()
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.FOOD)
	assert_int(backs[0]).is_equal(0)
	# The FAMILY list open (by the mouse): the keys are its, Esc closes it first.
	var family: PixelDropdown = book.family_menu()
	family.plate().pressed.emit()
	book._unhandled_key_input(Kit.key(KEY_DOWN))
	assert_int(family.marked()).is_equal(1)
	assert_str(book.filter()).is_equal("")
	book._unhandled_key_input(Kit.key(KEY_ENTER))
	assert_bool(family.is_open()).is_false()
	assert_str(book.filter()).is_equal(book.families()[1])
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.FOOD)
	family.plate().pressed.emit()
	book._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_bool(family.is_open()).is_false()
	assert_int(backs[0]).is_equal(0)
	# Closed, Esc leaves the book; Tab steps through the four sorts (Shift back).
	book._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_int(backs[0]).is_equal(1)
	book._unhandled_key_input(Kit.key(KEY_TAB))
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.NON_FOOD)
	book._unhandled_key_input(Kit.key(KEY_TAB))
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.BOOK)
	var back_tab: InputEventKey = Kit.key(KEY_TAB)
	back_tab.shift_pressed = true
	book._unhandled_key_input(back_tab)
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.NON_FOOD)
	assert_str(menu.caption_line().text()).is_equal("SORT: NON-FOOD")
	await _frames(2)


## Only one list is open at a time: opening one closes the other.
func test_one_list_open_at_a_time() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0))
	var family: PixelDropdown = book.family_menu()
	var sort: PixelDropdown = book.sort_menu()
	family.plate().pressed.emit()
	assert_bool(family.is_open()).is_true()
	sort.open_list()
	assert_bool(sort.is_open()).is_true()
	assert_bool(family.is_open()).is_false()
	family.open_list()
	assert_bool(family.is_open()).is_true()
	assert_bool(sort.is_open()).is_false()
	family.close_list()
	await _frames(2)


func test_the_lists_close_when_the_book_hides_or_is_filled_again() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0))
	var profile: ProfileState = Kit.profile(0, 0)
	for menu: PixelDropdown in [book.sort_menu(), book.family_menu()]:
		# Hidden from code with the list open, the book comes back with it closed (no catcher).
		menu.open_list()
		book.visible = false
		assert_bool(menu.is_open()).is_false()
		book.visible = true
		await _frames(2)
		assert_bool(menu.is_open()).is_false()
		assert_bool(menu.list().is_visible_in_tree()).is_false()
		# Filled again with the list open, it opens closed, on ALL in BOOK ORDER.
		book.set_filter("Dairy")
		book.set_sort(BookOrder.Sort.NEWEST)
		menu.open_list()
		book.show_collection(Kit.balance(), profile.unlocked_items, profile.coupon_uses, [], true)
		assert_bool(menu.is_open()).is_false()
		assert_str(book.sort_menu().caption_line().text()).is_equal("SORT: BOOK ORDER")
		assert_str(book.family_menu().caption_line().text()).is_equal("FAMILY: ALL")
	await _frames(2)


func test_the_mouse_marks_picks_and_a_click_outside_closes() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0))
	assert_int(book.spread_count()).is_greater(1)
	var backs: Array[int] = [0]
	book.back_pressed.connect(func() -> void: backs[0] += 1)
	for menu: PixelDropdown in [book.sort_menu(), book.family_menu()]:
		var start: int = menu.value()
		menu.plate().pressed.emit()
		assert_bool(menu.is_open()).is_true()
		menu.options()[1].mouse_entered.emit()
		assert_int(menu.marked()).is_equal(1)
		assert_bool(menu.options()[1].is_lit()).is_true()
		assert_bool(menu.options()[0].is_lit()).is_false()
		# The pointer over a card under the open list: the card stays in its pocket; the wheel
		# there turns no page (and leaves the list open).
		var card: BookCard = _card_outside(book, menu)
		var rest: float = card.position.y
		var over: Vector2 = card.get_global_rect().get_center()
		_move(over)
		await _frames(1)
		assert_float(card.position.y).is_equal(rest)
		_press(over, MOUSE_BUTTON_WHEEL_DOWN)
		await _frames(1)
		assert_int(book.spread()).is_equal(0)
		assert_bool(menu.is_open()).is_true()
		# A real click outside the list (on that card): closes it and picks nothing; the card,
		# the page and BACK get nothing.
		_click(over)
		await _frames(1)
		assert_bool(menu.is_open()).is_false()
		assert_int(menu.value()).is_equal(start)
		assert_int(book.spread()).is_equal(0)
		# A real click on BACK under the open list only closes the list: the book stays.
		menu.open_list()
		_click(book.back_button().get_global_rect().get_center())
		await _frames(1)
		assert_bool(menu.is_open()).is_false()
		assert_int(backs[0]).is_equal(0)
		assert_bool(book.is_visible_in_tree()).is_true()
		_move(Vector2.ZERO)
		# A click on the plate opens it, on the plate again closes it; a real click on an
		# option picks it.
		menu.plate().pressed.emit()
		menu.plate().pressed.emit()
		assert_bool(menu.is_open()).is_false()
		menu.plate().pressed.emit()
		await _frames(1)
		_click(menu.options()[2].get_global_rect().get_center())
		await _frames(1)
		assert_bool(menu.is_open()).is_false()
		assert_int(menu.value()).is_equal(2)
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.FOOD)
	assert_str(book.filter()).is_equal(book.families()[2])
	await _frames(2)


## One real click opens a list from the other dropdown's plate, either way round, the pointer
## having come onto that plate while the list was open: the open list closes and the other opens
## (the FAMILY list's catcher stands over the whole SORT dropdown, so the GUI never saw the pointer
## enter the SORT plate).
func test_a_click_on_the_other_plate_opens_its_list() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0))
	var family: PixelDropdown = book.family_menu()
	var sort: PixelDropdown = book.sort_menu()
	for pair: Array in [[family, sort], [sort, family]]:
		var open: PixelDropdown = pair[0]
		var other: PixelDropdown = pair[1]
		open.open_list()
		_move(other.plate().get_global_rect().get_center())
		await _frames(1)
		_click(other.plate().get_global_rect().get_center())
		await _frames(1)
		assert_bool(open.is_open()).override_failure_message(open.name).is_false()
		assert_bool(other.is_open()).override_failure_message(other.name).is_true()
		# Its own plate again closes it.
		_click(other.plate().get_global_rect().get_center())
		await _frames(1)
		assert_bool(other.is_open()).is_false()
	assert_int(family.value()).is_equal(0)
	assert_int(sort.value()).is_equal(0)
	await _frames(2)


## Through the TOY MACHINES in a window that is not 16:9 (the canvas expands, the stage stays
## centred with bands round it: 16:10 above and below, 21:9 left and right): a click in a band,
## off the stage, closes the open list and nothing more.
func test_a_click_off_the_stage_closes_the_list(
	window: Vector2i, _test_parameters := [[Vector2i(1920, 1200)], [Vector2i(2560, 1080)]]
) -> void:
	get_tree().root.size = window
	var book: FigurineBook = await _book_in_machines()
	var stage: Rect2 = book.get_global_rect()
	var shown: Rect2 = get_viewport().get_visible_rect()
	var margins: Array[Vector2] = []
	if stage.position.x - shown.position.x >= 2.0:
		margins.append(Vector2((shown.position.x + stage.position.x) / 2.0, stage.get_center().y))
		margins.append(Vector2((stage.end.x + shown.end.x) / 2.0, stage.position.y + 8.0))
	if stage.position.y - shown.position.y >= 2.0:
		margins.append(Vector2(stage.get_center().x, (shown.position.y + stage.position.y) / 2.0))
		margins.append(Vector2(stage.position.x + 8.0, (stage.end.y + shown.end.y) / 2.0))
	assert_array(margins).is_not_empty()
	var backs: Array[int] = [0]
	book.back_pressed.connect(func() -> void: backs[0] += 1)
	for menu: PixelDropdown in [book.family_menu(), book.sort_menu()]:
		for at: Vector2 in margins:
			assert_bool(stage.has_point(at)).is_false()
			menu.open_list()
			_click(at)
			await _frames(1)
			assert_bool(menu.is_open()).override_failure_message(str(at)).is_false()
			assert_int(menu.value()).is_equal(0)
	assert_int(backs[0]).is_equal(0)
	assert_bool(book.is_visible_in_tree()).is_true()
	await _frames(2)


func _click(at: Vector2) -> void:
	_press(at, MOUSE_BUTTON_LEFT)


func _press(at: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.position = at
		click.global_position = at
		get_tree().root.push_input(click, true)


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_tree().root.push_input(motion, true)


## A card of the shown spread clear of `menu`'s list and plate.
static func _card_outside(book: FigurineBook, menu: PixelDropdown) -> BookCard:
	for card: BookCard in book.cards():
		var rect: Rect2 = card.get_global_rect()
		var list: Rect2 = menu.list().get_global_rect()
		if not rect.intersects(list) and not rect.intersects(menu.plate().get_global_rect()):
			return card
	return null


static func _art_rect(rect: Rect2i, origin: Vector2) -> Rect2:
	return Rect2(origin + Vector2(rect.position) * 2.0, Vector2(rect.size) * 2.0)


func _book(profile: ProfileState, fresh: Array[StringName] = []) -> FigurineBook:
	var book: FigurineBook = FigurineBook.new()
	add_child(book)
	auto_free(book)
	book.show_collection(Kit.balance(), profile.unlocked_items, profile.coupon_uses, fresh, true)
	book.visible = true
	await _frames(3)
	return book


## The book opened through the TOY MACHINES (centred on the window, never scaled), a NEW card in
## it (a dot on its options).
func _book_in_machines() -> FigurineBook:
	var profile: ProfileState = Kit.profile(2, 2, {&"pantry": 1})
	profile.new_figurines.assign([&"sugar_cubes"])
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	var saves: SaveService = SaveService.new(_folder)
	screen.open(
		CapsuleCounter.new(profile, saves, Kit.balance(), Kit.event_log(), false, true),
		Kit.balance()
	)
	await _frames(2)
	screen.shelf_button().pressed.emit()
	await _frames(2)
	assert_bool(screen.book().is_visible_in_tree()).is_true()
	return screen.book()


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
