extends GdUnitTestSuite
## The FIGURINE BOOK's PERKS (v1.30 round 10, decided with the user 2026-11-12; memory: UI tests
## check on-screen geometry): a card per loyalty perk of the live pool, in the LOYALTY teal with
## the perk's stamp at 3x and its level pips, grey until picked in an ended run; never NEW, no
## price; the PERKS header and the CARDS LED count them; a family perk shows under its family
## too. Every perk card fits its pocket at 1280x720 and in a 1920x1080 window.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const STAGE := Rect2(0, 0, 1280, 720)

var _window_size: Vector2i
var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_book_perks_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(STAGE.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


## Every perk card at mixed levels: inside its page and on screen, its name inside the band, its
## rule inside the paper, the stamp inside the window and clear of the glyphs, the pips inside
## the window and clear of the stamp and the glyphs, all on the 2 px grid. 1920x1080 goes
## through the TOY MACHINES, as the game opens the book.
func test_every_perk_card_fits_its_pocket(
	window: Vector2i, _test_parameters := [[Vector2i(1280, 720)], [Vector2i(1920, 1080)]]
) -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	var pool: Array[UpgradeDefinition] = Kit.balance().upgrade_pool
	for index: int in pool.size():
		profile.perk_levels[pool[index].id] = 1 + index % 3
	var book: FigurineBook = null
	if window == Vector2i(1280, 720):
		book = await _book(profile, [])
	else:
		get_tree().root.size = window
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
		book = screen.book()
	book.set_filter(BookEntry.PERK_FAMILY)
	var art: float = ArtStyle.ART_SCALE
	var window_rect: Rect2 = _art_rect(BookArt.WINDOW_RECT)
	var shown: Rect2 = get_viewport().get_visible_rect()
	var seen: int = 0
	for spread: int in book.spread_count():
		await _frames(1)
		for card: BookCard in book.cards():
			assert_bool(card.entry().is_perk()).is_true()
			seen += 1
			var id: String = str(card.entry().key())
			var rect: Rect2 = card.get_rect()
			var side: int = 0 if rect.position.x < BookArt.SPINE_RECT.position.x * art else 1
			var page: Rect2 = _art_rect(BookArt.PAGE_RECTS[side])
			assert_bool(page.encloses(rect)).override_failure_message(id).is_true()
			assert_float(fmod(rect.position.x, art) + fmod(rect.position.y, art)).is_equal(0.0)
			(
				assert_bool(shown.encloses(card.get_global_rect()))
				. override_failure_message(id)
				. is_true()
			)
			_assert_name_and_rule_fit(card)
			var glyphs: Array[TextureRect] = card.family_glyphs()
			assert_int(glyphs.size()).is_between(1, 2)
			for glyph: TextureRect in glyphs:
				assert_bool(window_rect.encloses(glyph.get_rect())).is_true()
			var ring: Control = card.perk_ring()
			assert_object(ring).override_failure_message(id).is_not_null()
			var ring_rect: Rect2 = Rect2(ring.position, ring.size * ring.scale)
			assert_vector(ring_rect.size).is_equal(LoyaltyCard.CHIP_BOX_SIZE * 3.0)
			assert_bool(window_rect.encloses(ring_rect)).override_failure_message(id).is_true()
			(
				assert_float(fmod(ring_rect.position.x, art) + fmod(ring_rect.position.y, art))
				. is_equal(0.0)
			)
			for glyph: TextureRect in glyphs:
				(
					assert_bool(glyph.get_rect().intersects(ring_rect))
					. override_failure_message(id)
					. is_false()
				)
			var pips: TextureRect = card.level_pips()
			assert_bool(pips != null).override_failure_message(id).is_equal(card.entry().levels > 1)
			if pips == null:
				continue
			var pip_rect: Rect2 = pips.get_rect()
			assert_bool(window_rect.encloses(pip_rect)).override_failure_message(id).is_true()
			assert_bool(pip_rect.intersects(ring_rect)).override_failure_message(id).is_false()
			for glyph: TextureRect in glyphs:
				assert_bool(glyph.get_rect().intersects(pip_rect)).is_false()
			assert_float(fmod(pip_rect.position.x, art) + fmod(pip_rect.position.y, art)).is_equal(
				0.0
			)
			assert_vector(pip_rect.size).is_equal(Vector2(pips.texture.get_size()) * art)
		book.turn(1)
		book.page_turn().finish()
	assert_int(seen).is_equal(pool.size())
	await _frames(2)


## A picked perk's card is teal with its stamp (no tip, no pointer, no level badge), the PERKS
## mark and its family's glyph, its pips lit to its level, no price, no NEW even when listed
## fresh; a perk that never levels up (Banana stand) has a stamp and no pips; one not picked yet
## is the shared grey face with no stamp and no pips, its name and rule readable. The PERKS
## option is last with no dot, the PERKS header and the CARDS LED count the picked perks, and
## Dairy's filter shows its perks after its items.
func test_perk_cards_show_their_ring_pips_and_grey_state() -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	profile.perk_levels = {&"dairy_regulars": 2, &"banana_stand": 1, &"perfect_pair": 3}
	var book: FigurineBook = await _book(profile, [&"dairy_regulars", &"banana_stand"])
	assert_bool(book.leds()[1].visible).is_false()
	var families: PackedStringArray = book.families()
	assert_str(families[-1]).is_equal(BookEntry.PERK_FAMILY)
	assert_object(book.family_menu().dot(families.size() - 1)).is_null()
	book.set_filter(BookEntry.PERK_FAMILY)
	await _frames(2)
	var pool: int = Kit.balance().upgrade_pool.size()
	assert_str(book.header(0).text()).is_equal("PERKS 3/%d" % pool)
	var by_id: Dictionary[StringName, bool] = {}
	var grey_face: Texture2D = BookArt.card_face(Color(), Color(), Color(), true)
	for spread: int in book.spread_count():
		await _frames(1)
		for card: BookCard in book.cards():
			var entry: BookEntry = card.entry()
			by_id[entry.key()] = true
			assert_object(card.new_tag()).is_null()
			assert_object(card.price_label()).is_null()
			assert_object(card.figurine()).is_null()
			assert_str(_name_text(card)).is_equal(entry.perk.display_name.to_upper())
			assert_bool(card.description().visible).is_true()
			assert_bool(card.description_fits()).is_true()
			assert_int(BookCard.perk_tier_of(entry.perk)).is_between(
				0, BookCard.TEXT_TIERS.size() - 1
			)
			if not entry.owned:
				assert_object(card.perk_ring()).is_null()
				assert_object(card.level_pips()).is_null()
				assert_object(card.face().texture).is_same(grey_face)
		book.turn(1)
		book.page_turn().finish()
	assert_int(by_id.size()).is_equal(pool)
	# The cards of the spreads turned past are freed: these are made like the book's.
	var dairy: BookCard = _card(profile, &"dairy_regulars")
	assert_object(dairy.family_glyphs()[0].texture).is_same(BookCard.PERK_MARK)
	var dairy_glyph: Texture2D = FamilyPalette.shared().style("Dairy").glyph
	assert_object(dairy.family_glyphs()[1].texture).is_same(dairy_glyph)
	var ring: Control = dairy.perk_ring()
	assert_object(ring).is_not_null()
	assert_str(ring.tooltip_text).is_empty()
	assert_int(ring.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(ring.get_node_or_null(NodePath(LoyaltyCard.LEVEL_MARK_NAME))).is_null()
	assert_object(dairy.level_pips().texture).is_same(BookArt.level_pips(2, 3))
	assert_object(_card(profile, &"perfect_pair").level_pips().texture).is_same(
		BookArt.level_pips(3, 3)
	)
	var band_y: int = BookArt.BAND_RECT.position.y + 4
	var teal: Image = dairy.face().texture.get_image()
	assert_bool(_near(teal.get_pixel(10, band_y), Palette.TEAL_SHADE)).is_true()
	# Two pips lit of three: mustard, mustard, then teal dark.
	var pips: Image = BookArt.level_pips(2, 3).get_image()
	var step: int = BookArt.PIP + BookArt.PIP_GAP
	assert_bool(_near(pips.get_pixel(2, 2), Palette.MUSTARD)).is_true()
	assert_bool(_near(pips.get_pixel(step + 2, 2), Palette.MUSTARD)).is_true()
	assert_bool(_near(pips.get_pixel(step * 2 + 2, 2), Palette.TEAL_DARK)).is_true()
	var banana: BookCard = _card(profile, &"banana_stand")
	assert_object(banana.perk_ring()).is_not_null()
	assert_object(banana.level_pips()).is_null()
	var lemon: BookCard = _card(profile, &"lemon_squeezer")
	assert_bool(lemon.entry().owned).is_false()
	assert_int(lemon.family_glyphs().size()).is_equal(1)
	# The CARDS LED counts the picked perks with the items.
	var counted: Vector2i = BookOrder.count(_entries(profile))
	var items: Vector2i = BookOrder.count(_entries(Kit.profile(0, 0)))
	assert_int(counted.x).is_equal(items.x + 3)
	assert_str(book.leds()[0].text()).is_equal("%d/%d CARDS" % [counted.x, counted.y])
	# Dairy's filter: its perks after its items, headed with them counted.
	book.set_filter("Dairy")
	var kinds: Array[bool] = []
	var dairy_perks: Array[StringName] = []
	for spread: int in book.spread_count():
		await _frames(1)
		for card: BookCard in book.cards():
			kinds.append(card.entry().is_perk())
			if card.entry().is_perk():
				dairy_perks.append(card.entry().key())
		book.turn(1)
		book.page_turn().finish()
	assert_array(dairy_perks).is_equal([&"dairy_regulars", &"dairy_aisle_run", &"perfect_pair"])
	assert_array(kinds.slice(kinds.size() - 3)).is_equal([true, true, true])
	assert_bool(kinds.slice(0, kinds.size() - 3).has(true)).is_false()
	await _frames(2)


## The book's card for perk `id` of `profile`'s book, in the tree (freed after the test).
func _card(profile: ProfileState, id: StringName) -> BookCard:
	for entry: BookEntry in _entries(profile):
		if entry.key() == id:
			var card: BookCard = BookCard.new(
				entry, BookCard.perks_family_style(), false, true, FamilyPalette.shared()
			)
			add_child(card)
			auto_free(card)
			return card
	return null


func _assert_name_and_rule_fit(card: BookCard) -> void:
	var id: String = str(card.entry().key())
	var name_box: Rect2 = Rect2(card.name_control().position, _name_size(card))
	(
		assert_bool(BookCard.NAME_RECT.grow(0.5).encloses(name_box))
		. override_failure_message("%s name %s" % [id, name_box])
		. is_true()
	)
	(
		assert_bool(card.description_fits())
		. override_failure_message("%s rule %s" % [id, card.description_rect()])
		. is_true()
	)


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


static func _near(a: Color, b: Color) -> bool:
	return Vector4(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a).length() < 0.01


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


func _book(profile: ProfileState, fresh: Array[StringName]) -> FigurineBook:
	var book: FigurineBook = FigurineBook.new()
	add_child(book)
	auto_free(book)
	book.show_collection(
		Kit.balance(), profile.unlocked_items, profile.coupon_uses, fresh, true, profile.perk_levels
	)
	book.visible = true
	await _frames(3)
	return book


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
