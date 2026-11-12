extends GdUnitTestSuite
## The FIGURINE BOOK (v1.30 round 2; memory: UI tests check on-screen geometry): on every spread,
## in every sort and filter, each card sits in its pocket on its page inside the binder inside
## the 1280x720 stage, its name inside the band, its figurine inside the window and its whole
## description inside the paper (the longest rules included); the tabs, the LEDs, the title and
## the footer's plates are on the stage, clear of each other and of the binder's pages. An owned
## card is in colour with its figurine and price, one not collected yet grey with neither, its
## name and rule still shown. NEW cards wear the tag, their tabs a pip, the LED counts them. The
## tabs filter, SORT's plates and Tab sort, the arrows, keys and wheel turn the pages (a pixel
## turn, at once when still), and BACK or Escape goes back. Round 3: the COUPONS close the book,
## each coupon a card in its ticket colours with its slip in the scissors-lined window and no
## price, grey until played; their tab is the last, in the coupon teal. Round 4: a family's tab
## shows every card carrying it (FROZEN Frozen peas, its header counting them), and the
## footer's plates centre their words on their faces. Round 5: SORT is a dropdown
## (book_dropdowns_test); FOOD and NON-FOOD sorts split the book, Food no longer a tab. Round 6:
## no FROZEN tab (too few cards); OTHER FOOD, before COUPONS, holds Frozen peas and the Food-main
## cards, headed "OTHER FOOD n/m". Round 7: no tabs; the FAMILY dropdown (book_dropdowns_test)
## picks the family, its options carrying a dot for NEW cards, and a sort applies within it
## ("BREAKFAST · NON-FOOD n/m"); a card stacks its other families' glyphs under its main one,
## inside the window and clear of the figurine and the price; pixel words draw their hyphens.
## Round 8: FAMILY is a ribbon bookmark over the binder's top edge (clear of the pockets and the
## headers, book_dropdowns_test) and SORT's plate stands in the top bar, where FAMILY's stood.
## Round 10: the LOYALTY perks close the book after the coupons, in the LOYALTY teal with the
## perk's stamp at 3x and its level pips, grey until picked in an ended run; never NEW, no price;
## the CARDS LED and the PERKS header count them; a family perk shows under its family too
## (book_perks_test).

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const STAGE := Rect2(0, 0, 1280, 720)

var _window_size: Vector2i
var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_figurine_book_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(STAGE.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_every_card_fits_its_pocket_in_every_view() -> void:
	var profile: ProfileState = Kit.profile(0, 0, {&"fruit_and_veg": 4})
	for card: CardDefinition in Kit.balance().coupon_pool.slice(0, 5):
		profile.coupon_uses[card.id] = 1
	var book: FigurineBook = await _book(profile, [])
	var art: float = ArtStyle.ART_SCALE
	var binder: Rect2 = _art_rect(BookArt.BINDER_RECT)
	assert_bool(STAGE.encloses(binder)).is_true()
	var seen: Dictionary[StringName, bool] = {}
	var views: Array[Array] = [[BookOrder.Sort.BOOK, ""], [BookOrder.Sort.NEWEST, ""]]
	views.append_array([[BookOrder.Sort.FOOD, ""], [BookOrder.Sort.NON_FOOD, ""]])
	for family: String in book.families().slice(1):
		views.append([BookOrder.Sort.BOOK, family])
	views.append_array([[BookOrder.Sort.NON_FOOD, "Breakfast"], [BookOrder.Sort.FOOD, "Bakery"]])
	for view: Array in views:
		book.set_sort(view[0])
		book.set_filter(view[1])
		for spread: int in book.spread_count():
			await _frames(1)
			var cards: Array[BookCard] = book.cards()
			assert_int(cards.size()).is_between(1, FigurineBook.PER_SPREAD)
			for index: int in cards.size():
				var card: BookCard = cards[index]
				seen[card.entry().key()] = true
				var rect: Rect2 = card.get_global_rect()
				var side: int = 0 if rect.position.x < BookArt.SPINE_RECT.position.x * art else 1
				var page: Rect2 = _art_rect(BookArt.PAGE_RECTS[side])
				assert_bool(page.encloses(rect)).override_failure_message(str(rect)).is_true()
				assert_float(fmod(rect.position.x, art)).is_equal(0.0)
				assert_float(fmod(rect.position.y, art)).is_equal(0.0)
				_assert_card_fits(card)
				for other: BookCard in cards.slice(index + 1):
					assert_bool(rect.intersects(other.get_global_rect())).is_false()
			book.turn(1)
			book.page_turn().finish()
	# Every card appears, coupons included; the longest rules (Lemon, Odd socks) were among them.
	assert_int(seen.size()).is_equal(BookOrder.count(_entries(Kit.profile(0, 0))).y)
	for card: CardDefinition in Kit.balance().coupon_pool:
		assert_bool(seen.has(card.id)).override_failure_message(str(card.id)).is_true()
	assert_bool(seen.has(&"lemon") and seen.has(&"odd_socks")).is_true()
	await _frames(2)


func test_the_controls_are_on_the_stage_clear_of_the_pages() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [&"cream"])
	var pages: Array[Rect2] = [_art_rect(BookArt.PAGE_RECTS[0]), _art_rect(BookArt.PAGE_RECTS[1])]
	var sort_plate: MenuPlate = book.sort_menu().plate() as MenuPlate
	var controls: Array[Rect2] = [sort_plate.get_global_rect()]
	for led: ToyLed in book.leds():
		controls.append(led.get_global_rect())
	controls.append((book.get_node("Title") as Control).get_global_rect())
	for plate: MenuPlate in [book.prev_button(), book.next_button(), book.back_button()]:
		controls.append(plate.get_global_rect())
	for index: int in controls.size():
		var rect: Rect2 = controls[index]
		assert_bool(STAGE.encloses(rect)).override_failure_message(str(rect)).is_true()
		for page: Rect2 in pages:
			assert_bool(rect.intersects(page)).override_failure_message(str(rect)).is_false()
		for other: Rect2 in controls.slice(index + 1):
			assert_bool(rect.intersects(other)).override_failure_message(str(rect)).is_false()
	# Round 8: the SORT plate stands where the tabs (and round 7's FAMILY plate) stood, over the
	# binder's top left edge (its sunk face too), its left edge inside the binder's; nothing is
	# left at the footer's left, under it. The FAMILY ribbon hangs over the binder's top edge,
	# clear of every control and of the pockets.
	var binder: Rect2 = _art_rect(BookArt.BINDER_RECT)
	var face: Rect2 = sort_plate.face().get_global_rect()
	assert_float(face.end.y + MenuPlate.PLATE_SINK).is_less_equal(binder.position.y)
	assert_float(controls[0].position.x).is_greater_equal(binder.position.x)
	assert_float(controls[0].end.y).is_less(binder.position.y)
	var ribbon: Rect2 = book.family_menu().plate().get_global_rect()
	assert_bool(STAGE.encloses(ribbon)).is_true()
	assert_float(ribbon.position.y).is_less(binder.position.y)
	assert_float(ribbon.end.y).is_greater(binder.position.y)
	for rect: Rect2 in controls:
		assert_bool(ribbon.intersects(rect)).override_failure_message(str(rect)).is_false()
	var pocket_top: float = (BookArt.PAGE_RECTS[0].position.y + BookArt.POCKET_ORIGIN.y) * 2.0
	assert_float(ribbon.end.y).is_less_equal(pocket_top)


func test_owned_cards_are_in_colour_and_the_rest_grey() -> void:
	var profile: ProfileState = Kit.profile(0, 0, {&"bakery": 2})
	var book: FigurineBook = await _book(profile, [])
	book.set_filter("Bakery")
	var cards: Array[BookCard] = book.cards()
	# Round 10: Bakery's two perks (Bakery regulars, Bakery aisle run) after its ten items.
	assert_int(cards.size()).is_equal(12)
	var grey_faces: Array[Texture2D] = []
	for card: BookCard in cards:
		var entry: BookEntry = card.entry()
		if entry.is_perk():
			assert_bool(entry.owned).is_false()
			grey_faces.append(card.face().texture)
			continue
		var owned: bool = entry.starter or profile.unlocked_items.has(entry.card.id)
		assert_bool(entry.owned).is_equal(owned)
		assert_bool(card.figurine() != null).is_equal(owned)
		assert_bool(card.price_label() != null).is_equal(owned)
		# The name and the rule show either way.
		assert_str(_name_text(card)).is_equal(entry.card.display_name.to_upper())
		assert_bool(card.description().visible).is_true()
		if owned:
			assert_object(card.figurine().texture).is_same(ArtStyle.item_sprite(entry.card))
			assert_str(card.price_label().text).is_equal("%d€" % entry.card.base)
		else:
			grey_faces.append(card.face().texture)
	# Every grey card shares the one grey face; Bakery's owned faces are another.
	assert_int(grey_faces.size()).is_equal(12 - 2 - 3)
	for face: Texture2D in grey_faces:
		assert_object(face).is_same(grey_faces[0])
	assert_object(cards[0].face().texture).is_not_same(grey_faces[0])
	# The grey card never reads as a family's (review fix: Household's charcoal looked locked):
	# its face is far from every family's face, and its outline is dashed (gaps along the rim).
	var grey: Image = grey_faces[0].get_image()
	var body: Color = grey.get_pixel(2, BookArt.TEXT_RECT.position.y - 1)
	for family: String in FamilyPalette.shared().main_family_order:
		var style: FamilyStyle = FamilyPalette.shared().style(family)
		if style == null or not style.has_ticket_colours():
			continue
		var gap: float = (
			Vector3(body.r - style.face.r, body.g - style.face.g, body.b - style.face.b).length()
		)
		assert_float(gap).override_failure_message(family).is_greater(0.2)
	assert_float(grey.get_pixel(BookArt.GREY_DASH * 3, 0).a).is_equal(0.0)
	var owned_face: Image = cards[0].face().texture.get_image()
	assert_float(owned_face.get_pixel(BookArt.GREY_DASH * 3, 0).a).is_equal(1.0)
	# The count: Bread, Crackers and Day-old buns are starters, two Bakery capsules drawn.
	assert_str(book.header(0).text()).is_equal("BAKERY 5/12")
	await _frames(2)


## The COUPONS (round 3): the last FAMILY option (round 7), with the coupon mark; a played
## coupon's card in its ticket colours with the mark, its slip and icon in the window and no
## price; one not played yet grey with its name and rule; the header counts the played ones;
## the LED counts them with the items; a coupon never wears NEW.
func test_the_coupons_close_the_book() -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	profile.coupon_uses[&"repeat"] = 3
	profile.coupon_uses[&"family_sticker"] = 1
	profile.coupon_uses[&"party_pack"] = 2
	var pool: int = Kit.balance().coupon_pool.size()
	var book: FigurineBook = await _book(profile, [&"repeat"])
	var families: PackedStringArray = book.families()
	# Round 10: COUPONS just before PERKS, the last option.
	assert_str(families[-2]).is_equal(BookEntry.COUPON_FAMILY)
	var menu: PixelDropdown = book.family_menu()
	var last: int = families.size() - 2
	assert_str(menu.option_line(last).text()).is_equal("COUPONS")
	var mark: Texture2D = FamilyPalette.shared().style(BookEntry.COUPON_FAMILY).glyph
	var icon: TextureRect = (
		menu.option_line(last).find_children("*", "TextureRect", false, false)[0]
	)
	assert_object(icon.texture).is_same(mark)
	assert_object(menu.dot(last)).is_null()
	assert_bool(book.leds()[1].visible).is_false()
	menu.plate().pressed.emit()
	menu.options()[last].pressed.emit()
	await _frames(2)
	assert_str(book.header(0).text()).is_equal("COUPONS 3/%d" % pool)
	var cards: Array[BookCard] = book.cards()
	assert_int(cards.size()).is_equal(pool)
	for card: BookCard in cards:
		var entry: BookEntry = card.entry()
		assert_bool(entry.coupon).is_true()
		assert_object(card.new_tag()).is_null()
		assert_object(card.price_label()).is_null()
		assert_str(_name_text(card)).is_equal(entry.card.display_name.to_upper())
		assert_bool(card.description().visible).is_true()
		var played: bool = profile.coupon_uses.has(entry.card.id)
		assert_bool(entry.owned).is_equal(played)
		assert_bool(card.figurine() != null).is_equal(played)
		if played:
			assert_object(card.figurine().texture).is_same(ArtStyle.COUPON_SLIP)
			var glyph: TextureRect = card.get_node("Glyph") as TextureRect
			assert_object(glyph.texture).is_same(mark)
			_assert_coupon_fits(card)
	# Its ticket colours: the plain Repeat and the Family sticker (its family picked on the belt)
	# in the coupon teal, Party pack in Snack's.
	var by_id: Dictionary[StringName, BookCard] = {}
	for card: BookCard in cards:
		by_id[card.entry().card.id] = card
	var band_y: int = BookArt.BAND_RECT.position.y + 4
	var repeat: Image = by_id[&"repeat"].face().texture.get_image()
	assert_bool(_near(repeat.get_pixel(10, band_y), Palette.TEAL_SHADE)).is_true()
	var sticker: Image = by_id[&"family_sticker"].face().texture.get_image()
	assert_bool(_near(sticker.get_pixel(10, band_y), Palette.TEAL_SHADE)).is_true()
	var party: Image = by_id[&"party_pack"].face().texture.get_image()
	var snack: FamilyStyle = FamilyPalette.shared().style("Snack")
	assert_bool(_near(party.get_pixel(10, band_y), snack.face)).is_true()
	# The cards' LED counts the played coupons with the items.
	var items: Vector2i = BookOrder.count(_entries(Kit.profile(0, 0)))
	assert_str(book.leds()[0].text()).is_equal("%d/%d CARDS" % [items.x + 3, items.y])
	await _frames(2)


## NEW cards wear the tag; round 7: each FAMILY option holding one carries a dot (ALL's too),
## the closed plate too; nothing new, no dot anywhere.
func test_new_cards_wear_the_tag_and_their_options_a_dot() -> void:
	var profile: ProfileState = Kit.profile(0, 0, {&"fruit_and_veg": 2, &"snacks": 1})
	var fresh: Array[StringName] = [&"strawberries", &"crisps"]
	var book: FigurineBook = await _book(profile, fresh)
	assert_bool(book.leds()[1].visible).is_true()
	assert_str(book.leds()[1].text()).is_equal("2 NEW")
	var collection: Vector2i = BookOrder.count(_entries(profile))
	assert_str(book.leds()[0].text()).is_equal("%d/%d CARDS" % [collection.x, collection.y])
	assert_int(collection.x).is_equal(23)
	var entries: Array[BookEntry] = _entries(profile)
	var menu: PixelDropdown = book.family_menu()
	var families: PackedStringArray = book.families()
	assert_bool(families.has("Food")).is_false()
	var dotted: PackedStringArray = PackedStringArray()
	for index: int in families.size():
		var family: String = families[index]
		var fresh_here: Callable = func(entry: BookEntry) -> bool:
			return fresh.has(entry.key()) and (family.is_empty() or entry.has_family(family))
		var expected: bool = entries.any(fresh_here)
		if expected:
			dotted.append(family)
		var dot: Control = menu.dot(index)
		assert_bool(dot != null).override_failure_message(family).is_equal(expected)
	assert_array(Array(dotted)).contains(["", "Produce", "Snack"])
	assert_object(menu.dot()).is_not_null()
	for filter: String in ["Produce", "Snack"]:
		book.set_filter(filter)
		await _frames(2)
		for card: BookCard in book.cards():
			var is_new: bool = fresh.has(card.entry().key())
			assert_bool(card.new_tag() != null).is_equal(is_new)
			if is_new:
				var tag: Rect2 = card.new_tag().get_global_rect()
				assert_bool(card.get_global_rect().encloses(tag)).is_true()
				var window: Rect2 = Rect2(
					card.global_position + Vector2(BookArt.WINDOW_RECT.position) * 2.0,
					Vector2(BookArt.WINDOW_RECT.size) * 2.0
				)
				assert_bool(window.encloses(tag)).override_failure_message(str(tag)).is_true()
	# Nothing new: no LED, no dot.
	var calm: FigurineBook = await _book(profile, [])
	assert_bool(calm.leds()[1].visible).is_false()
	assert_object(calm.family_menu().dot()).is_null()
	for index: int in calm.families().size():
		assert_object(calm.family_menu().dot(index)).is_null()
	await _frames(2)


## Round 7: the FAMILY dropdown filters (every card carrying the family, the plate reading it),
## Up and Down step it (wrapping), and a sort keeps the family: "PRODUCE · FOOD n/m".
func test_the_family_dropdown_and_keys_filter_and_sort() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [])
	var menu: FamilyRibbon = book.family_menu()
	var order: PackedStringArray = book.families()
	assert_str(order[0]).is_equal("")
	assert_object(menu.emblem().texture).is_same(FamilyRibbon.ALL_MARK)
	var produce: int = order.find("Produce")
	# Round 8: through the ribbon, by real clicks: on the ribbon, then (the strip unrolled) on
	# PRODUCE's row.
	_click(menu.plate().get_global_rect().get_center())
	await _frames(1)
	assert_bool(menu.is_open()).is_true()
	await get_tree().create_timer(FamilyRibbon.UNROLL_SECONDS + 0.1).timeout
	_click(menu.options()[produce].get_global_rect().get_center())
	await _frames(1)
	assert_bool(menu.is_open()).is_false()
	assert_str(book.filter()).is_equal("Produce")
	assert_int(menu.value()).is_equal(produce)
	var glyph: Texture2D = FamilyPalette.shared().style("Produce").glyph
	assert_object(menu.emblem().texture).is_same(glyph)
	for card: BookCard in book.cards():
		assert_bool(card.entry().has_family("Produce")).is_true()
	assert_str(book.header(0).text()).starts_with("PRODUCE")
	# Down steps to the next family, Up back; Up from ALL wraps to the last.
	book._unhandled_key_input(Kit.key(KEY_DOWN))
	assert_str(book.filter()).is_equal(order[produce + 1])
	book._unhandled_key_input(Kit.key(KEY_UP))
	assert_str(book.filter()).is_equal("Produce")
	for step: int in produce:
		book._unhandled_key_input(Kit.key(KEY_UP))
	assert_str(book.filter()).is_equal("")
	book._unhandled_key_input(Kit.key(KEY_UP))
	assert_str(book.filter()).is_equal(order[-1])
	assert_int(menu.value()).is_equal(order.size() - 1)
	menu.plate().pressed.emit()
	menu.options()[0].pressed.emit()
	assert_str(book.filter()).is_equal("")
	# SORT: NEWEST from the dropdown, then Tab through FOOD and NON-FOOD back to BOOK ORDER.
	book.sort_menu().plate().pressed.emit()
	book.sort_menu().options()[BookOrder.Sort.NEWEST].pressed.emit()
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.NEWEST)
	assert_str(book.header(0).text()).starts_with(FigurineBook.NEWEST_HEADER + " ")
	for sort: BookOrder.Sort in [BookOrder.Sort.FOOD, BookOrder.Sort.NON_FOOD, BookOrder.Sort.BOOK]:
		book._unhandled_key_input(Kit.key(KEY_TAB))
		assert_int(book.sort_mode()).is_equal(sort)
		assert_int(book.sort_menu().value()).is_equal(sort)
	# The family stays across the sorts, and the sort across the families.
	book.set_filter("Produce")
	book._unhandled_key_input(Kit.key(KEY_TAB))
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.NEWEST)
	book._unhandled_key_input(Kit.key(KEY_TAB))
	assert_str(book.filter()).is_equal("Produce")
	var counted: Vector2i = BookOrder.count_shown(
		_entries(Kit.profile(0, 0)), BookOrder.Sort.FOOD, "Produce"
	)
	assert_str(book.header(0).text()).is_equal(
		"PRODUCE · FOOD " + FigurineBook.COUNT_TEXT % [counted.x, counted.y]
	)
	book.set_filter("Dairy")
	assert_int(book.sort_mode()).is_equal(BookOrder.Sort.FOOD)
	await _frames(2)  # Let the dropped pages' queued frees run (no orphans).


## Round 7 (the user: "double family are a problem"): a card shows its main family's glyph and,
## under it, its other printed families' (Day-old buns: Bakery, Clearance; Bread: Bakery,
## Breakfast), never Food beside another family, Food first on a Food-main card (Soup); each names
## its family in the game's tip (a FamilyGlyph). Three glyphs (a test-made card) still stand inside
## the window, clear of the figurine's drawn pixels and the price sticker.
func test_a_card_stacks_its_families_glyphs() -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	var book: FigurineBook = await _book(profile, [])
	var palette: FamilyPalette = FamilyPalette.shared()
	var food: Texture2D = palette.style(BookEntry.FOOD_TAG).glyph
	var expected: Dictionary[StringName, Array] = {
		&"day_old_buns": ["Bakery", "Clearance"],
		&"bread": ["Bakery", "Breakfast"],
		&"soup": ["Food"],
		&"coffee": ["Breakfast"],
	}
	var found: Dictionary[StringName, bool] = {}
	for spread: int in book.spread_count():
		await _frames(1)
		for card: BookCard in book.cards():
			var entry: BookEntry = card.entry()
			var glyphs: Array[TextureRect] = card.family_glyphs()
			var families: PackedStringArray = BookCard.glyph_families(entry, palette)
			if entry.coupon:
				assert_int(glyphs.size()).is_equal(1)
				continue
			if entry.is_perk():
				continue  # Round 10: test_perk_cards_show_their_ring_pips_and_grey_state.
			assert_int(glyphs.size()).is_equal(families.size())
			if families.size() > 1:
				assert_bool(families.has(BookEntry.FOOD_TAG)).is_false()
				for glyph: TextureRect in glyphs:
					assert_object(glyph.texture).is_not_same(food)
			if expected.has(entry.card.id):
				assert_array(Array(families)).is_equal(expected[entry.card.id])
				found[entry.card.id] = true
			for index: int in glyphs.size():
				var family: String = families[index]
				assert_str((glyphs[index] as FamilyGlyph).tip_text).is_equal(
					palette.display_name(family)
				)
				var at: Vector2 = BookCard.GLYPH_AT + Vector2(0, BookCard.GLYPH_PITCH * index)
				assert_vector(glyphs[index].position).is_equal(at)
			_assert_glyphs_fit(card)
		book.turn(1)
		book.page_turn().finish()
	assert_int(found.size()).is_equal(expected.size())
	# Three families: Bakery's Day-old buns carrying Breakfast too.
	var buns: CardDefinition = load("res://data/cards/day_old_buns.tres") as CardDefinition
	var three: CardDefinition = buns.duplicate() as CardDefinition
	three.tags = PackedStringArray(["Bakery", "Clearance", "Breakfast", "Food"])
	var entry3: BookEntry = BookEntry.new(three, "Bakery", true)
	var card3: BookCard = BookCard.new(entry3, palette.style("Bakery"), false, true, palette)
	add_child(card3)
	auto_free(card3)
	assert_int(card3.family_glyphs().size()).is_equal(3)
	_assert_glyphs_fit(card3)
	await _frames(2)


## Each family glyph is served by the book's GlyphTips (the game's tip, its family's name): the
## pointer resting on it shows the tip after the wait; with a list open (its catcher over the
## glyphs), none.
func test_a_family_glyph_shows_the_games_tip() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [])
	var tips: GlyphTips = book.get_node("GlyphTips") as GlyphTips
	var glyph: FamilyGlyph = null
	for card: BookCard in book.cards():
		if card.family_glyphs().size() > 1 and not card.entry().coupon:
			glyph = card.family_glyphs()[1] as FamilyGlyph
			break
	assert_object(glyph).is_not_null()
	var at: Vector2 = glyph.get_global_rect().get_center()
	_move(at)
	await _frames(1)
	assert_object(tips.glyph_at(at)).is_same(glyph)
	tips.show_tip(glyph)
	assert_str(tips.tip().tip_text()).is_equal(glyph.tip_text)
	assert_bool(glyph.tip_text.is_empty()).is_false()
	tips.hide_tip()
	book.sort_menu().open_list()
	_move(at)
	await _frames(2)
	assert_object(tips.glyph_at(at)).is_null()
	assert_object(tips.shown_glyph()).is_null()
	book.sort_menu().close_list()
	_move(Vector2.ZERO)
	await _frames(2)


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_tree().root.push_input(motion, true)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		get_tree().root.push_input(click, true)


## The user: "non-food text has its '-' a bit weird" (round 7): pixel words draw a hyphen as a
## DASH_WIDTH dash on the capitals' middle row, DASH_GAP clear of the letters each side; the
## line's width counts it (NON-FOOD, DAY-OLD BUNS); the separator is a square on the capitals.
func test_pixel_words_draw_their_hyphens() -> void:
	var art: float = ArtStyle.ART_SCALE
	for word: String in ["NON-FOOD", "DAY-OLD BUNS"]:
		var line: PixelLine = PixelLine.new()
		add_child(line)
		auto_free(line)
		line.show_tokens([word], Palette.INK, Palette.INK)
		var parts: PackedStringArray = word.split("-")
		var marks: Array[Node] = line.find_children("*", "ColorRect", false, false)
		assert_int(marks.size()).is_equal(1)
		var dash: ColorRect = marks[0] as ColorRect
		var first_end: float = PixelLine.word_width(parts[0])
		assert_float(dash.position.x).is_equal(first_end + PixelLine.DASH_GAP * art)
		assert_float(dash.position.y).is_equal(PixelLine.DASH_ROW * art)
		assert_vector(dash.size).is_equal(Vector2(PixelLine.DASH_WIDTH, 1) * art)
		# On the capitals' middle row, and the letters' labels clear of it either side.
		assert_int(PixelLine.DASH_ROW * 2 + 1).is_equal(ArtStyle.PIXEL_CAP_HEIGHT)
		var second_at: float = dash.position.x + dash.size.x + PixelLine.DASH_GAP * art
		var labels: Array[Node] = line.find_children("*", "Label", false, false)
		assert_int(labels.size()).is_equal(2)
		var second: Label = labels[1] as Label
		var bearing: float = PixelLine.LEFT_BEARING * art
		assert_float(second.position.x + bearing).is_equal(second_at)
		assert_float(line.width()).is_equal(second_at + PixelLine.word_width(parts[1]))
		assert_float(line.width()).is_equal(PixelLine.word_width(word))
		assert_str(line.text()).is_equal(word)
	var split: PixelLine = PixelLine.new()
	add_child(split)
	auto_free(split)
	split.show_tokens(["BREAKFAST", PixelLine.SEPARATOR, "NON-FOOD"], Palette.INK, Palette.INK)
	assert_str(split.text()).is_equal("BREAKFAST · NON-FOOD")
	assert_int(split.find_children("*", "ColorRect", false, false).size()).is_equal(2)
	await _frames(1)


## The user: "food filter should show every item that is food" (round 4), then the FOOD sort
## (round 5): FOOD's pages hold every food card, Bread and Milk and Banana included, each in its
## own family's colours, the header "FOOD n/m" counting them; no FROZEN tab (round 6: OTHER FOOD
## shows Frozen peas); ALL shows each card once.
func test_the_food_sort_shows_every_food_card() -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	var book: FigurineBook = await _book(profile, [])
	var entries: Array[BookEntry] = _entries(profile)
	var food: Dictionary[StringName, bool] = {}
	for entry: BookEntry in entries:
		if entry.is_food():
			food[entry.card.id] = true
	assert_bool(book.families().has("Frozen")).is_false()
	book.set_sort(BookOrder.Sort.FOOD)
	assert_str(book.filter()).is_equal("")
	var counted: Vector2i = BookOrder.count_shown(entries, BookOrder.Sort.FOOD, "")
	assert_int(counted.y).is_equal(food.size())
	var seen: Dictionary[StringName, bool] = {}
	var mains: Dictionary[String, bool] = {}
	for spread: int in book.spread_count():
		await _frames(1)
		for side: int in 2:
			if book.header(side) != null:
				var words: String = book.header(side).text()
				assert_str(words).starts_with("FOOD")
				assert_str(words).ends_with(FigurineBook.COUNT_TEXT % [counted.x, counted.y])
		for card: BookCard in book.cards():
			var id: StringName = card.entry().card.id
			assert_bool(food.has(id)).override_failure_message(str(id)).is_true()
			assert_bool(seen.has(id)).override_failure_message(str(id)).is_false()
			seen[id] = true
			mains[card.entry().family] = true
		book.turn(1)
		book.page_turn().finish()
	assert_int(seen.size()).is_equal(food.size())
	assert_array(mains.keys()).contains(["Bakery", "Produce", "Dairy", "Snack"])
	# Round 6, OTHER FOOD: Frozen peas (in its Produce colours), the Food-main cards and the
	# Clearance-main ones (a 2-card ALL group, in Clearance's colours), the header OTHER FOOD with
	# their count (in BOOK ORDER; round 7: the family keeps the sort). They run onto a second
	# page.
	book.set_sort(BookOrder.Sort.BOOK)
	book.set_filter(BookEntry.OTHER_FOOD)
	await _frames(1)
	var other: Array[StringName] = []
	var colours: PackedStringArray = ["Food", "Produce", "Clearance"]
	for card: BookCard in book.cards():
		other.append(card.entry().card.id)
		assert_bool(colours.has(card.entry().family)).is_true()
	assert_array(other).contains_exactly_in_any_order(
		[&"soup", &"frozen_peas", &"sugar_cubes", &"mixed_herbs", &"ham_ends", &"dented_can"]
	)
	var tab_count: Vector2i = BookOrder.count(entries, BookEntry.OTHER_FOOD)
	assert_int(tab_count.y).is_equal(6)
	assert_str(book.header(0).text()).is_equal(
		"OTHER FOOD " + FigurineBook.COUNT_TEXT % [tab_count.x, tab_count.y]
	)
	# ALL: each card once.
	book.set_filter("")
	var all_seen: Dictionary[StringName, int] = {}
	for spread: int in book.spread_count():
		await _frames(1)
		for card: BookCard in book.cards():
			var id: StringName = card.entry().key()
			all_seen[id] = all_seen.get(id, 0) + 1
		book.turn(1)
		book.page_turn().finish()
	assert_int(all_seen.size()).is_equal(entries.size())
	for id: StringName in all_seen:
		assert_int(all_seen[id]).override_failure_message(str(id)).is_equal(1)
	# ALL's OTHER FOOD pages: the Food-main cards, headed with their group's count.
	var group: Vector2i = BookOrder.count(entries, BookEntry.OTHER_FOOD, true)
	var headed: bool = false
	book.set_filter("")
	for spread: int in book.spread_count():
		await _frames(1)
		for side: int in 2:
			var line: PixelLine = book.header(side)
			if line != null and line.text().begins_with("OTHER FOOD"):
				headed = true
				assert_str(line.text()).is_equal(
					"OTHER FOOD " + FigurineBook.COUNT_TEXT % [group.x, group.y]
				)
			assert_bool(line == null or not line.text().begins_with("FOOD")).is_true()
		book.turn(1)
		book.page_turn().finish()
	assert_bool(headed).is_true()
	await _frames(2)


## Round 6: a small family's item not printed Food has no food group to join, so ALL files it
## on the unfamilied last page, headed OTHER ITEMS with its count, never NEWEST FIRST (a
## test-made book: 2 Dairy cards go to OTHER FOOD, 3 Bakery ones keep Bakery, Scissors alone).
func test_the_unfamilied_pages_read_other_items() -> void:
	var balance: BalanceDefinition = BalanceDefinition.new()
	for id: String in ["cheese", "butter", "bread", "baguette", "scone", "scissors"]:
		balance.staples.append(load("res://data/cards/%s.tres" % id) as CardDefinition)
	var book: FigurineBook = FigurineBook.new()
	add_child(book)
	auto_free(book)
	var none: Dictionary[StringName, int] = {}
	var fresh: Array[StringName] = []
	book.show_collection(balance, none, none, fresh, true)
	book.visible = true
	await _frames(3)
	var headers: PackedStringArray = PackedStringArray()
	var scissors: bool = false
	for spread: int in book.spread_count():
		await _frames(1)
		for side: int in 2:
			var line: PixelLine = book.header(side)
			if line != null:
				headers.append(line.text())
		for card: BookCard in book.cards():
			scissors = scissors or card.entry().card.id == &"scissors"
		book.turn(1)
		book.page_turn().finish()
	assert_bool(scissors).is_true()
	assert_str(headers[-1]).is_equal("OTHER ITEMS " + FigurineBook.COUNT_TEXT % [1, 1])
	assert_bool(headers.has(FigurineBook.NEWEST_HEADER)).is_false()
	var other: Callable = func(h: String) -> bool: return h.begins_with("OTHER FOOD")
	assert_bool(Array(headers).any(other)).is_true()
	assert_bool(headers[0].begins_with("BAKERY")).is_true()


## The user: "newest button has its text not centered". Each dropdown plate's words (round 7:
## a PixelLine, with its NEW dot after it) sit in the middle of its face within 1 art px, the
## FAMILY and SORT plates and every option of their lists; BACK's caption too.
func test_the_plates_centre_their_words() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [&"cream"])
	for menu: PixelDropdown in [book.family_menu(), book.sort_menu()]:
		# Round 8: the ribbon has no words on it, only its strip's options.
		var plates: Array[MenuPlate] = []
		var lines: Array[PixelLine] = []
		var dots: Array[Control] = []
		if menu is not FamilyRibbon:
			plates.append(menu.plate() as MenuPlate)
			lines.append(menu.caption_line())
			dots.append(menu.dot())
		plates.append_array(menu.options())
		for index: int in menu.options().size():
			lines.append(menu.option_line(index))
			dots.append(menu.dot(index))
		for index: int in plates.size():
			var face: Rect2 = plates[index].face().get_global_rect()
			var words: Rect2 = lines[index].get_global_rect()
			var end: float = words.end.x
			if dots[index] != null:
				var dot: Rect2 = dots[index].get_global_rect()
				assert_float(dot.position.x).is_greater(words.end.x)
				assert_bool(face.encloses(dot)).is_true()
				end = dot.end.x
			var off: float = (words.position.x + end) / 2.0 - face.get_center().x
			(
				assert_float(absf(off))
				. override_failure_message("%s off by %s" % [lines[index].text(), off])
				. is_less_equal(ArtStyle.ART_SCALE)
			)
			assert_bool(face.encloses(words)).override_failure_message(str(words)).is_true()
	var back: MenuPlate = book.back_button()
	var caption: Label = back.caption_label()
	var font: Font = ArtStyle.pixel_display_font()
	var text_size: Vector2 = font.get_string_size(
		caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE
	)
	var width: float = text_size.x * caption.scale.x
	var off_back: float = (
		caption.global_position.x + width / 2.0 - back.face().get_global_rect().get_center().x
	)
	assert_float(absf(off_back)).is_less_equal(ArtStyle.ART_SCALE)


func test_the_pages_turn_with_a_pixel_turn() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [])
	var count: int = book.spread_count()
	assert_int(count).is_greater(1)
	assert_bool(book.prev_button().disabled).is_true()
	assert_bool(book.turn(-1)).is_false()
	var first: Array[BookCard] = book.cards()
	book.next_button().pressed.emit()
	assert_int(book.spread()).is_equal(1)
	assert_bool(book.page_turn().is_turning()).is_true()
	assert_bool(book.prev_button().disabled).is_false()
	# The sheet stands on the right page first, then over the left one, on the art grid. It
	# carries its cards (review fix: an empty sheet): the old right page on its front, squeezed
	# to it from the spine, then the new left page on its back.
	var old_right: Array[BookCard] = first.slice(FigurineBook.PER_PAGE)
	book.page_turn().seek(BookPageTurn.TURN_S * 0.25)
	var sheet: Rect2i = book.page_turn().sheet_rect()
	assert_int(sheet.position.x).is_equal(BookArt.SPINE_RECT.end.x)
	assert_int(sheet.size.x % 2).is_equal(0)
	var faces: Array[Control] = book.page_turn().faces()
	assert_int(faces.size()).is_equal(2)
	assert_bool(faces[0].visible and not faces[1].visible).is_true()
	_assert_face_on_sheet(faces[0], sheet, old_right)
	book.page_turn().seek(BookPageTurn.TURN_S * 0.75)
	sheet = book.page_turn().sheet_rect()
	assert_int(sheet.end.x).is_equal(BookArt.SPINE_RECT.position.x)
	assert_bool(faces[1].visible and not faces[0].visible).is_true()
	_assert_face_on_sheet(faces[1], sheet, book.cards().slice(0, FigurineBook.PER_PAGE))
	book.page_turn().seek(BookPageTurn.TURN_S)
	assert_bool(book.page_turn().is_turning()).is_false()
	await _frames(1)
	for card: BookCard in book.cards():
		assert_bool(first.has(card)).is_false()
		assert_bool(card.is_visible_in_tree()).is_true()
	# The keys and the wheel.
	book._unhandled_key_input(Kit.key(KEY_LEFT))
	book.page_turn().finish()
	assert_int(book.spread()).is_equal(0)
	# The wheel through the viewport, over a card's rule (the cards and their chips pass it on).
	await _frames(1)
	var over: Vector2 = book.cards()[0].get_global_rect().position + BookCard.TEXT_AREA.get_center()
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = over
	wheel.global_position = over
	get_tree().root.push_input(wheel, true)
	await _frames(1)
	book.page_turn().finish()
	assert_int(book.spread()).is_equal(1)
	for step: int in count:
		book._unhandled_key_input(Kit.key(KEY_RIGHT))
		book.page_turn().finish()
	assert_int(book.spread()).is_equal(count - 1)
	assert_bool(book.next_button().disabled).is_true()
	await _frames(2)


## While the book is idle the next spread's pages are built ahead, one a frame, and a turn swaps
## them in (review fix: a turn built both pages' cards on its first frame and dropped frames);
## each card's rule tier is found once and kept.
func test_the_next_spread_is_built_ahead() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [])
	await _frames(3)
	assert_array(book.ready_pages()).contains([2, 3])
	var ahead: Array[Node] = []
	for card: BookCard in book.find_children("*", "BookCard", true, false):
		if not card.is_visible_in_tree():
			ahead.append(card)
			if card.entry().is_perk():
				continue
			var rule: CardDefinition = card.entry().card
			if not BookCard.description_text(rule).is_empty():
				var tier: int = BookCard.tier_of(rule)
				assert_int(tier).is_between(0, BookCard.TEXT_TIERS.size() - 1)
	assert_int(ahead.size()).is_greater(0)
	book.turn(1)
	book.page_turn().finish()
	for card: BookCard in book.cards():
		assert_bool(ahead.has(card)).is_true()
	# Moved on, the pages two spreads back are let go and the next ones built.
	await _frames(4)
	assert_array(book.ready_pages()).contains([0, 1, 4, 5])
	await _frames(2)


func test_a_still_book_turns_at_once() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [&"cream"], true)
	assert_bool(book.turn(1)).is_true()
	assert_bool(book.page_turn().is_turning()).is_false()
	assert_int(book.cards().size()).is_greater(0)
	for card: BookCard in book.cards():
		assert_bool(card.is_visible_in_tree()).is_true()
	await _frames(2)


func test_back_and_escape_go_back() -> void:
	var book: FigurineBook = await _book(Kit.profile(0, 0), [])
	var backs: Array[int] = [0]
	book.back_pressed.connect(func() -> void: backs[0] += 1)
	book.back_button().pressed.emit()
	assert_int(backs[0]).is_equal(1)
	book._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_int(backs[0]).is_equal(2)


## Through the TOY MACHINES in a 1920x1080 window: the book opens on the centred stage, the new
## card wears its tag this time and the profile has it seen (saved).
func test_the_book_opens_centred_in_a_1080p_window() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
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
	var book: FigurineBook = screen.book()
	assert_bool(book.is_visible_in_tree()).is_true()
	var shown: Rect2 = get_viewport().get_visible_rect()
	var rect: Rect2 = book.get_global_rect()
	assert_bool(shown.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_vector(rect.get_center()).is_equal_approx(shown.get_center(), Vector2.ONE)
	assert_array(profile.new_figurines).is_empty()
	assert_array(saves.load_profile().new_figurines).is_empty()
	# NEWEST puts the drawn one first.
	book.set_sort(BookOrder.Sort.NEWEST)
	var tagged: Array[StringName] = []
	for card: BookCard in book.cards():
		if card.new_tag() != null:
			tagged.append(card.entry().card.id)
	assert_array(tagged).is_equal([&"sugar_cubes"])
	await _frames(2)


func _assert_card_fits(card: BookCard) -> void:
	var name_rect: Rect2 = BookCard.NAME_RECT
	var name_box: Rect2 = Rect2(card.name_control().position, _name_size(card))
	(
		assert_bool(name_rect.grow(0.5).encloses(name_box))
		. override_failure_message("%s name %s" % [card.entry().key(), name_box])
		. is_true()
	)
	(
		assert_bool(card.description_fits())
		. override_failure_message("%s rule %s" % [card.entry().key(), card.description_rect()])
		. is_true()
	)
	if card.figurine() != null and card.entry().coupon:
		_assert_coupon_fits(card)
	elif card.figurine() != null:
		var window: Rect2 = Rect2(
			Vector2(BookArt.WINDOW_RECT.position) * 2.0, Vector2(BookArt.WINDOW_RECT.size) * 2.0
		)
		# The figurine at the game's 2x (its sprite's art px = 2 canvas px), its drawn pixels
		# inside the window, standing on the plinth.
		var figurine: TextureRect = card.figurine()
		assert_vector(figurine.size).is_equal(Vector2(figurine.texture.get_size()) * 2.0)
		var used: Rect2i = figurine.texture.get_image().get_used_rect()
		var figure: Rect2 = Rect2(
			figurine.position + Vector2(used.position) * 2.0, Vector2(used.size) * 2.0
		)
		assert_bool(window.encloses(figure)).override_failure_message(str(figure)).is_true()
		assert_float(figurine.get_rect().end.y).is_equal(BookArt.PLINTH_TOP * 2.0)
		# The price is centred on its sticker, its words narrower than it, clear of the figurine.
		var label: Label = card.price_label()
		var price: Rect2 = Rect2(label.position, label.size)
		assert_bool(window.has_point(price.get_center())).is_true()
		assert_vector(price.get_center()).is_equal_approx(
			BookCard.PRICE_RECT.get_center(), Vector2.ONE
		)
		assert_float(label.get_minimum_size().x).is_less_equal(BookCard.PRICE_RECT.size.x)
		assert_float(figure.end.x).is_less_equal(BookCard.PRICE_RECT.position.x)


## A card's family glyphs (round 7): inside the card and its window, apart, on the art grid,
## clear of the figurine's drawn pixels and of the price sticker.
func _assert_glyphs_fit(card: BookCard) -> void:
	var window: Rect2 = _art_rect(BookArt.WINDOW_RECT)
	var glyphs: Array[TextureRect] = card.family_glyphs()
	for index: int in glyphs.size():
		var rect: Rect2 = glyphs[index].get_rect()
		var id: String = str(card.entry().key())
		assert_bool(window.encloses(rect)).override_failure_message(id + str(rect)).is_true()
		assert_float(fmod(rect.position.y, ArtStyle.ART_SCALE)).is_equal(0.0)
		if index > 0:
			assert_float(rect.position.y).is_greater_equal(glyphs[index - 1].get_rect().end.y)
		if card.price_label() != null:
			assert_bool(rect.intersects(BookCard.PRICE_RECT)).is_false()
		var figurine: TextureRect = card.figurine()
		if figurine != null and not card.entry().coupon:
			var used: Rect2i = figurine.texture.get_image().get_used_rect()
			var figure: Rect2 = Rect2(
				figurine.position + Vector2(used.position) * 2.0, Vector2(used.size) * 2.0
			)
			assert_bool(rect.intersects(figure)).override_failure_message(id).is_false()


## A coupon card's slip: at the game's 2x, its drawn pixels inside the scissors line, on the art
## grid; its icon on it; no price.
func _assert_coupon_fits(card: BookCard) -> void:
	var slip: TextureRect = card.figurine()
	assert_object(slip.get_parent()).is_same(card)
	assert_vector(slip.size).is_equal(Vector2(slip.texture.get_size()) * 2.0)
	assert_float(fmod(slip.position.x, 2.0) + fmod(slip.position.y, 2.0)).is_equal(0.0)
	var used: Rect2i = slip.texture.get_image().get_used_rect()
	var drawn: Rect2 = Rect2(slip.position + Vector2(used.position) * 2.0, Vector2(used.size) * 2.0)
	var cut: Rect2i = BookArt.WINDOW_RECT.grow(-1 - BookArt.COUPON_CUT_INSET)
	assert_bool(_art_rect(cut).encloses(drawn)).override_failure_message(str(drawn)).is_true()
	for icon: TextureRect in slip.find_children("*", "TextureRect", false, false):
		var at: Rect2 = Rect2(slip.position + icon.position, icon.size)
		assert_bool(drawn.encloses(at)).override_failure_message(str(at)).is_true()
	assert_object(card.price_label()).is_null()


## A coupon card's scissors line leaves out the corner under the coupon mark (BookCard.GLYPH_AT, a
## texel clear round it) and still runs everywhere else. The face is painted with a light that
## is not tomato, so the dither never reads as a dash (Clearance tag's light is tomato).
func test_the_scissors_line_leaves_the_coupon_mark_clear() -> void:
	var face: Image = (
		BookArt.card_face(Palette.GREY, Palette.CREAM, Palette.INK, false, true).get_image()
	)
	var art: float = ArtStyle.ART_SCALE
	var mark: Rect2i = (
		Rect2i(Vector2i(BookCard.GLYPH_AT / art), Vector2i(BookCard.GLYPH_SIZE / art)).grow(1)
	)
	var dashes: int = 0
	for y: int in face.get_height():
		for x: int in face.get_width():
			if not _near(face.get_pixel(x, y), Palette.TOMATO):
				continue
			dashes += 1
			(
				assert_bool(mark.has_point(Vector2i(x, y)))
				. override_failure_message("a dash under the coupon mark at %d,%d" % [x, y])
				. is_false()
			)
	var cut: Rect2i = BookArt.WINDOW_RECT.grow(-1 - BookArt.COUPON_CUT_INSET)
	assert_int(dashes).is_greater(cut.size.x)  # The rest of the line is there.


## Whether two colours match to the image's 8 bits.
static func _near(a: Color, b: Color) -> bool:
	return Vector4(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a).length() < 0.01


## A page `face` on the turning sheet: squeezed from the spine to the sheet's width (pivot on the
## spine, its pixels' rows kept), holding `cards` (the page's), and inside the sheet's columns.
func _assert_face_on_sheet(face: Control, sheet: Rect2i, cards: Array[BookCard]) -> void:
	var page: Rect2i = BookArt.PAGE_RECTS[0]
	assert_float(face.scale.x).is_equal_approx(float(sheet.size.x) / page.size.x, 0.001)
	assert_float(face.scale.y).is_equal(1.0)
	var held: Array[BookCard] = []
	for child: Node in face.get_children():
		if child is BookCard:
			held.append(child as BookCard)
	assert_int(held.size()).is_equal(cards.size())
	for card: BookCard in cards:
		assert_bool(held.has(card)).is_true()
		var rect: Rect2 = card.get_global_transform() * Rect2(Vector2.ZERO, card.size)
		var column: Rect2 = _art_rect(sheet).grow_individual(1, 0, 1, 0)
		assert_bool(rect.position.x >= column.position.x and rect.end.x <= column.end.x).is_true()


static func _name_size(card: BookCard) -> Vector2:
	var line: PixelLine = card.name_control() as PixelLine
	if line != null:
		return Vector2(line.width(), line.size.y)
	var label: Label = card.name_control() as Label
	return Vector2(label.get_minimum_size().x, label.size.y)


static func _name_text(card: BookCard) -> String:
	var line: PixelLine = card.name_control() as PixelLine
	if line != null:
		return line.text().to_upper()
	return (card.name_control() as Label).text.to_upper()


static func _art_rect(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) * 2.0, Vector2(rect.size) * 2.0)


static func _entries(profile: ProfileState) -> Array[BookEntry]:
	return BookOrder.entries(
		Kit.balance(),
		profile.unlocked_items,
		FamilyPalette.shared().main_family_order,
		profile.coupon_uses,
		profile.perk_levels
	)


func _book(profile: ProfileState, fresh: Array[StringName], still: bool = false) -> FigurineBook:
	var book: FigurineBook = FigurineBook.new()
	add_child(book)
	auto_free(book)
	book.show_collection(
		Kit.balance(),
		profile.unlocked_items,
		profile.coupon_uses,
		fresh,
		still,
		profile.perk_levels
	)
	book.visible = true
	await _frames(3)
	return book


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
