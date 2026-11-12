extends GdUnitTestSuite
## The FIGURINE BOOK's dropdowns (PixelDropdown; v1.30 round 5's SORT dropdown, round 7's FAMILY
## dropdown, the user: "sort by family can be removed from sort and have its own dropdown
## somewhere where old bookmarks where ... sort can keep newest / food / non-food. it will sort
## selected first dropdown"; memory: UI tests check on-screen geometry). Round 8: FAMILY is a
## ribbon bookmark (FamilyRibbon) and SORT moved up to the top bar. Closed, the SORT plate ("SORT:
## BOOK ORDER", its arrow) stands over the binder's top left, on the stage clear of the pages and
## the other controls; the ribbon hangs over the binder's top edge (in ALL's cream with the ALL
## mark, a family's colours and glyph once picked), clear of the LEDs, the title, the plates, the
## pockets and the page headers. Open, SORT's list hangs under its plate, the ribbon's paper strip
## unrolls under the ribbon (its rows below the ribbon's foot), each inside the stage, clear of
## the footer, every option inside it with its words and dot on its face. FAMILY
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
	var family: FamilyRibbon = book.family_menu()
	var sort: PixelDropdown = book.sort_menu()
	var binder: Rect2 = _art_rect(BookArt.BINDER_RECT, stage.position)
	# SORT closed: its plate in the top bar, on the stage, clear of the pages and of every other
	# control, its face (sunk too) over the binder's top edge; its words and arrow on its face.
	var plate: Rect2 = sort.plate().get_global_rect()
	assert_bool(stage.encloses(plate)).override_failure_message(str(plate)).is_true()
	for rect: Rect2 in pages + footer + top:
		assert_bool(plate.intersects(rect)).override_failure_message(str(rect)).is_false()
	var sort_plate: MenuPlate = sort.plate() as MenuPlate
	var face: Rect2 = sort_plate.face().get_global_rect()
	assert_float(face.end.y + MenuPlate.PLATE_SINK).is_less_equal(binder.position.y)
	assert_float(plate.position.x).is_greater_equal(binder.position.x)
	var arrow: Rect2 = sort.arrow().get_global_rect()
	var words: Rect2 = sort.caption_line().get_global_rect()
	assert_bool(face.encloses(arrow)).override_failure_message(str(arrow)).is_true()
	assert_bool(face.encloses(words)).override_failure_message(str(words)).is_true()
	assert_float(arrow.position.x - words.end.x).is_greater_equal(4.0 * ArtStyle.ART_SCALE)
	assert_bool(sort.is_open()).is_false()
	# The ribbon closed: on the stage, hanging over the binder's top edge (its top above it, its
	# foot below it), clear of the LEDs, the title, the plates, every pocket and the headers.
	var ribbon: Rect2 = family.plate().get_global_rect()
	_assert_ribbon_clear(book, stage, top + footer + [plate])
	assert_float(ribbon.position.y).is_less(binder.position.y)
	assert_float(ribbon.end.y).is_greater(binder.position.y)
	assert_bool(family.is_open()).is_false()
	assert_bool(family.list().visible).is_false()
	# Open: each list inside the stage under its plate (the ribbon's strip tucked under its foot,
	# across the ribbon), clear of the footer; its options inside it, apart, in order (the strip's
	# below the ribbon's foot), each with its tick inside the list and its words (and dot) on its
	# face; the picked option marked (lit, its tick showing) on opening.
	for menu: PixelDropdown in [sort, family]:
		var shown: Rect2 = menu.plate().get_global_rect()
		menu.plate().pressed.emit()
		await _frames(1)
		assert_bool(menu.is_open()).is_true()
		var list: Rect2 = menu.list().get_global_rect()
		assert_bool(stage.encloses(list)).override_failure_message(str(list)).is_true()
		if menu == family:
			assert_float(list.position.y).is_less(shown.end.y)
			assert_float(list.position.y).is_greater(shown.position.y)
			assert_float(list.position.x).is_less_equal(shown.position.x)
			assert_float(list.end.x).is_greater_equal(shown.end.x)
		else:
			assert_float(list.position.x).is_equal(shown.position.x)
			assert_float(list.position.y).is_greater_equal(shown.end.y)
		for rect: Rect2 in footer:
			assert_bool(list.intersects(rect)).override_failure_message(str(rect)).is_false()
		var options: Array[MenuPlate] = menu.options()
		for index: int in options.size():
			var option: Rect2 = options[index].get_global_rect()
			assert_bool(list.encloses(option)).override_failure_message(str(option)).is_true()
			if menu == family:
				assert_float(option.position.y).is_greater_equal(shown.end.y)
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
	assert_object(family.emblem().texture).is_same(FamilyRibbon.ALL_MARK)
	assert_object(family.cloth().texture).is_same(FamilyRibbon.RIBBON)
	var sorts: Array[String] = []
	for index: int in sort.options().size():
		sorts.append(sort.option_line(index).text())
	assert_array(sorts).is_equal(["BOOK ORDER", "NEWEST", "FOOD", "NON-FOOD"])
	assert_str(sort.caption_line().text()).is_equal("SORT: BOOK ORDER")
	# The lists stand over everything on the stage: the dropdowns are the book's last children.
	# (Only the GlyphTips, drawing no control of its own but the cards' tips, is after them.)
	assert_object(book.get_child(book.get_child_count() - 1)).is_instanceof(GlyphTips)
	assert_int(family.get_index()).is_equal(book.get_child_count() - 2)
	assert_int(sort.get_index()).is_equal(book.get_child_count() - 3)
	await _frames(2)


## Round 8: the ribbon in the TOY MACHINES (not reduced motion) unrolls its strip from under its
## foot over FamilyRibbon.UNROLL_SECONDS, then holds it whole; the mouse over the ribbon lifts it,
## and it stays lifted while the list is open; under reduced motion the strip shows whole at once.
func test_the_ribbon_lifts_and_unrolls() -> void:
	var book: FigurineBook = await _book_in_machines()
	var ribbon: FamilyRibbon = book.family_menu()
	assert_bool(ribbon.still).is_false()
	var rest: Vector2 = ribbon.cloth().get_global_rect().position
	assert_bool(ribbon.is_lifted()).is_false()
	_move(ribbon.plate().get_global_rect().get_center())
	await _frames(1)
	assert_bool(ribbon.is_lifted()).is_true()
	var lifted: Vector2 = ribbon.cloth().get_global_rect().position
	assert_vector(lifted).is_equal(rest - Vector2(0, FamilyRibbon.LIFT))
	_move(Vector2.ZERO)
	await _frames(1)
	assert_bool(ribbon.is_lifted()).is_false()
	ribbon.open_list()
	await _frames(1)
	assert_bool(ribbon.is_lifted()).is_true()
	assert_float(ribbon.roll().size.y).is_less(ribbon.list().size.y)
	await get_tree().create_timer(FamilyRibbon.UNROLL_SECONDS + 0.2).timeout
	assert_float(ribbon.roll().size.y).is_equal(ribbon.list().size.y)
	ribbon.close_list()
	assert_bool(ribbon.is_lifted()).is_false()
	var calm: FigurineBook = await _book(Kit.profile(0, 0))
	calm.family_menu().open_list()
	assert_float(calm.family_menu().roll().size.y).is_equal(calm.family_menu().list().size.y)
	calm.family_menu().close_list()
	await _frames(2)


## Round 8: the ribbon shows the family picked: its glyph (ALL: the ALL mark) on the cloth, the
## cloth in the family's face (ALL: cream), the NEW dot on the cloth clear of the glyph when any
## option has one; it stays clear of the pockets, the headers and the other controls whichever
## family and sort are shown. The picked option of the strip is a swatch in its family's face,
## its words in paper on a family that prints them, else ink.
func test_the_ribbon_shows_the_family_picked() -> void:
	var profile: ProfileState = Kit.profile(0, 0, Kit.full_counts())
	var fresh: Array[StringName] = []
	fresh.assign(profile.unlocked_items.keys())
	var book: FigurineBook = await _book(profile, fresh)
	var menu: FamilyRibbon = book.family_menu()
	var palette: FamilyPalette = FamilyPalette.shared()
	var others: Array[Rect2] = [book.sort_menu().plate().get_global_rect()]
	for led: ToyLed in book.leds():
		others.append(led.get_global_rect())
	others.append((book.get_node("Title") as Control).get_global_rect())
	for plate: MenuPlate in [book.prev_button(), book.next_button(), book.back_button()]:
		others.append(plate.get_global_rect())
	var body: Vector2i = Vector2i(6, 20)
	for index: int in book.families().size():
		var family: String = book.families()[index]
		book.set_filter(family)
		for sort: int in BookOrder.Sort.size():
			book.set_sort(sort as BookOrder.Sort)
			await _frames(1)
			_assert_ribbon_clear(book, STAGE, others)
		book.set_sort(BookOrder.Sort.BOOK)
		assert_int(menu.value()).is_equal(index)
		var cloth: Rect2 = menu.cloth().get_global_rect()
		var emblem: Rect2 = menu.emblem().get_global_rect()
		assert_bool(cloth.encloses(emblem)).override_failure_message(family).is_true()
		var colours: Image = menu.cloth().texture.get_image()
		var style: FamilyStyle = null
		if family.is_empty():
			assert_object(menu.emblem().texture).is_same(FamilyRibbon.ALL_MARK)
			assert_bool(_near(colours.get_pixelv(body), Palette.CREAM)).is_true()
		else:
			style = BookCard.family_style(family, palette)
			assert_object(menu.emblem().texture).is_same(style.glyph)
			var face_ok: bool = _near(colours.get_pixelv(body), style.face)
			assert_bool(face_ok).override_failure_message(family).is_true()
		assert_object(menu.dot()).is_not_null()
		var dot: Rect2 = menu.dot().get_global_rect()
		assert_bool(cloth.encloses(dot)).override_failure_message(family).is_true()
		assert_bool(dot.intersects(emblem)).override_failure_message(family).is_false()
		# The picked option's swatch in the family's face, its words paper or ink.
		var frame: StyleBoxTexture = (
			menu.options()[index].face().get_theme_stylebox("panel") as StyleBoxTexture
		)
		var swatch: Image = frame.texture.get_image()
		var expected: Color = Palette.CREAM if style == null else style.face
		(
			assert_bool(_near(swatch.get_pixel(4, 8), expected))
			. override_failure_message(family)
			. is_true()
		)
		var paper: bool = style != null and style.paper_text
		var ink: Color = Palette.PAPER if paper else Palette.INK
		var labels: Array[Node] = menu.option_line(index).find_children("*", "Label", true, false)
		assert_array(labels).is_not_empty()
		var label: Label = labels[0] as Label
		assert_bool(_near(label.get_theme_color("font_color"), ink)).is_true()
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
		assert_int(book.family_menu().value()).is_equal(0)
		assert_object(book.family_menu().emblem().texture).is_same(FamilyRibbon.ALL_MARK)
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


## The ribbon (closed, its cloth lifted or not) inside `stage`, clear of `others`, of every pocket
## of the spread and of the shown page headers.
func _assert_ribbon_clear(book: FigurineBook, stage: Rect2, others: Array) -> void:
	var ribbon: Rect2 = book.family_menu().plate().get_global_rect()
	ribbon = ribbon.merge(book.family_menu().cloth().get_global_rect())
	assert_bool(stage.encloses(ribbon)).override_failure_message(str(ribbon)).is_true()
	for other: Rect2 in others:
		assert_bool(ribbon.intersects(other)).override_failure_message(str(other)).is_false()
	for side: int in 2:
		for slot: int in FigurineBook.PER_PAGE:
			var pocket: Rect2 = _art_rect(
				Rect2i(BookArt.pocket_origin(side, slot), BookArt.POCKET_SIZE), stage.position
			)
			assert_bool(ribbon.intersects(pocket)).override_failure_message(str(pocket)).is_false()
		var header: PixelLine = book.header(side)
		if header != null:
			var words: Rect2 = header.get_global_rect()
			assert_bool(ribbon.intersects(words)).override_failure_message(header.text()).is_false()


static func _near(colour: Color, expected: Color) -> bool:
	return colour.is_equal_approx(expected) or colour.to_html(false) == expected.to_html(false)


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
