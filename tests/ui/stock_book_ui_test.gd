extends GdUnitTestSuite
## The deck view's STOCK BOOK on the real shift screen (2026-11-19; it replaced the Run info page):
## it fits 1280x720 and 1920x1080 unscrolled (its banner, tabs, ribbon and every tab's sleeves
## inside it, none overlapping), its tabs (a click or Left and Right) show one section at a time,
## its tally counts the stocked items the cart holds, its slots are filled with their badge when
## owned and silhouettes otherwise, its FAMILY ribbon dims the other families' slots (the keys
## too; Esc clears it), and its pixel art stands on whole screen pixels at both window scales.

const Cart := preload("res://tests/ui/deck_view_ui_test.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const LAYOUT := Vector2(1280, 720)
const SCALES: Array[float] = [1.0, 1.5]
const SEED := 20261014

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## At 1280x720 and 1920x1080 the book sits whole in the window and in the basket's well, the Cart's
## scroll hidden; its title and tally inside the banner, clear of the ribbon; its tabs on the
## pages' top edge, side by side, clear of the ribbon; every tab's slots inside their page, none
## overlapping; the ribbon's open list inside the window.
func test_the_stock_book_fits_both_windows() -> void:
	for window: Vector2 in WINDOWS:
		var view: DeckView = await _open_book(window, true)
		var where: String = str(window)
		var book: StockBook = view.stock_book()
		var stage: Rect2 = Rect2(Vector2.ZERO, window)
		var box: Rect2 = book.get_global_rect()
		assert_bool(view._scroll.visible).is_false()
		assert_bool(stage.encloses(box)).override_failure_message(where).is_true()
		assert_bool(view.get_global_rect().encloses(box)).override_failure_message(where).is_true()
		assert_bool(view._info_page.get_global_rect().grow(0.5).encloses(box)).is_true()
		var origin: Vector2 = box.position
		var banner: Rect2 = _art_rect(origin, StockBook.BANNER)
		var ribbon: Rect2 = book.ribbon().plate().get_global_rect()
		assert_bool(box.encloses(ribbon)).override_failure_message(where).is_true()
		var title: Rect2 = (
			(book.find_child(StockBook.TITLE, false, false) as Control).get_global_rect()
		)
		var tally: Rect2 = book.tally_line().get_global_rect()
		for part: Rect2 in [title, tally]:
			assert_bool(banner.encloses(part)).override_failure_message(where).is_true()
			assert_bool(part.intersects(ribbon)).override_failure_message(where).is_false()
		assert_bool(title.intersects(tally)).is_false()
		var tabs: Array[StockBook.SectionTab] = book.tabs()
		assert_int(tabs.size()).is_equal(book.sections().size())
		var pages_top: float = origin.y + StockBook.PAGES[0].position.y * StockBook.ART
		for index: int in tabs.size():
			var tab: Rect2 = tabs[index].get_global_rect()
			assert_bool(box.encloses(tab)).override_failure_message(where).is_true()
			assert_float(tab.end.y).is_equal_approx(pages_top, 0.01)
			assert_bool(tab.intersects(ribbon)).override_failure_message(where).is_false()
			assert_bool(tab.intersects(banner)).is_false()
			if index > 0:
				var left: Rect2 = tabs[index - 1].get_global_rect()
				assert_bool(left.intersects(tab)).is_false()
				assert_float(tab.position.x).is_greater(left.position.x)
		var pages: Array[Rect2] = []
		for page: Rect2i in StockBook.PAGES:
			pages.append(_art_rect(origin, page))
		for index: int in book.sections().size():
			book.show_section(index)
			var slots: Array[StockIcon] = book.shown_icons()
			for at: int in slots.size():
				var slot: Rect2 = slots[at].get_global_rect()
				var message: String = "%s %s" % [where, slots[at].name]
				assert_bool(slots[at].is_visible_in_tree()).is_true()
				var page: Rect2 = pages[0] if at < StockBook.PER_PAGE else pages[1]
				assert_bool(page.encloses(slot)).override_failure_message(message).is_true()
				for other: int in range(at):
					var clash: bool = slots[other].get_global_rect().intersects(slot)
					assert_bool(clash).override_failure_message(message).is_false()
		book.ribbon().still = true
		book.ribbon().open_list()
		await _frames(2)
		var list: Rect2 = book.ribbon().list().get_global_rect()
		assert_bool(stage.encloses(list)).override_failure_message(where).is_true()
		book.ribbon().close_list()
		view._close()
		await _frames(1)


## The sections are MACHINE STOCK's groups (STAPLES, the stocked aisles, COUPONS), one tab each;
## a tab's click shows its section alone and picks it, Left and Right step the tabs (wrapping);
## each tab and the cover's tally count the stocked items the cart holds.
func test_the_tabs_turn_the_sections_and_count_the_cart() -> void:
	var view: DeckView = await _open_book(LAYOUT, true)
	var book: StockBook = view.stock_book()
	var run: RunState = view._run
	var counts: Dictionary[StringName, Vector2i] = StockBook.cart_counts(run)
	var owned: int = 0
	for card: CardDefinition in run.stock.cards:
		owned += 1 if counts.has(card.id) else 0
	assert_that(book.tally()).is_equal(Vector2i(owned, run.stock.cards.size()))
	assert_str(book.tally_line().text()).is_equal(
		"%s %d/%d" % [StockBook.TALLY_WORD, owned, run.stock.cards.size()]
	)
	var tabs: Array[StockBook.SectionTab] = book.tabs()
	for index: int in tabs.size():
		var section: StockBook.Section = book.sections()[index]
		var held: int = (
			section
			. cards
			. filter(func(card: CardDefinition) -> bool: return counts.has(card.id))
			. size()
		)
		assert_str(tabs[index].line().text()).is_equal(
			"%s %d/%d" % [section.caption, held, section.cards.size()]
		)
	for index: int in [2, 0, tabs.size() - 1]:
		_click(tabs[index])
		assert_int(book.shown_section()).is_equal(index)
		for at: int in tabs.size():
			assert_bool(tabs[at].picked).is_equal(at == index)
		for icon: StockIcon in book.all_icons():
			var shown: bool = book.sections()[index].icons.has(icon)
			assert_bool(icon.visible).override_failure_message(icon.name).is_equal(shown)
	view._input(_key(KEY_RIGHT))
	assert_int(book.shown_section()).is_equal(0)
	view._input(_key(KEY_LEFT))
	assert_int(book.shown_section()).is_equal(tabs.size() - 1)
	view._close()


## A slot the cart holds is filled (its sprite plain, its ×N badge with the tier mark: the GOLDEN
## Banana's gold star); one it does not is a silhouette with its price (a coupon: its rarity) and
## no badge. Hovering a slot shows only its card face (no extra lines or boxes) beside it, inside
## the window.
func test_owned_slots_are_filled_and_the_rest_silhouettes() -> void:
	var view: DeckView = await _open_book(LAYOUT, true)
	var book: StockBook = view.stock_book()
	var counts: Dictionary[StringName, Vector2i] = StockBook.cart_counts(view._run)
	var filled: int = 0
	var empty: int = 0
	for icon: StockIcon in book.all_icons():
		var held: Vector2i = counts.get(icon.card.id, Vector2i.ZERO)
		assert_bool(icon.owned()).override_failure_message(icon.name).is_equal(held.x > 0)
		if icon.owned():
			filled += 1
			assert_that(icon.art().modulate).is_equal(Color.WHITE)
			assert_str(icon.badge().text()).is_equal("×%d" % held.x)
			assert_int(icon.badge().tier).is_equal(held.y)
		else:
			empty += 1
			assert_that(icon.art().modulate).is_equal(StockIcon.SILHOUETTE)
			assert_object(icon.badge()).is_null()
		var price: String = (
			StockIcon.COUPON_WORDS[icon.look]
			if icon.card.is_coupon()
			else PriceSticker.price_text(icon.card.base)
		)
		assert_str(icon.price_label().text).is_equal(price)
	assert_int(filled).is_greater(0)
	assert_int(empty).is_greater(0)
	var banana: StockIcon = null
	for icon: StockIcon in book.all_icons():
		if icon.card.id == &"banana":
			banana = icon
	assert_int(banana.badge().tier).is_equal(CardDefinition.Tier.GOLDEN)
	assert_that(banana.badge().fill()).is_equal(Palette.GOLD)
	var slot: StockIcon = book.shown_icons()[0]
	slot.hovered.emit(slot)
	assert_bool(view.tip().visible and slot.lit).is_true()
	var tip: CardTip = view.tip()
	assert_object(tip.face().card).is_same(slot.card)
	assert_object(tip.main_card()).is_null()
	assert_array(tip.keyword_cards()).is_empty()
	assert_array(tip.lines()).is_empty()
	assert_array(tip.card_rects()).has_size(1)
	assert_int(tip.get_child_count()).is_equal(1)
	var shown: Rect2 = tip.face().get_global_rect()
	assert_bool(view.get_viewport_rect().encloses(shown)).is_true()
	assert_bool(shown.intersects(slot.get_global_rect())).is_false()
	view._close()


## The FAMILY ribbon lists ALL and every family printed on the stock; picking one (with the keys
## too: Down then Enter in its open list) dims every slot of every
## tab without it, the slots never moving; Esc clears it (ALL back on the ribbon); switching to the
## Cart and back clears it too.
func test_the_family_ribbon_dims_the_other_families() -> void:
	var view: DeckView = await _open_book(LAYOUT, false)
	var book: StockBook = view.stock_book()
	var ribbon: FamilyRibbon = book.ribbon()
	ribbon.still = true
	var families: PackedStringArray = book.families()
	assert_str(families[0]).is_empty()
	for index: int in range(1, families.size()):
		var listed: String = families[index]
		var printed: bool = view._run.stock.cards.any(
			func(card: CardDefinition) -> bool: return card.tags.has(listed)
		)
		assert_bool(printed).override_failure_message(listed).is_true()
	assert_int(families.size()).is_greater(2)
	var rects: Array[Rect2] = []
	for icon: StockIcon in book.shown_icons():
		rects.append(icon.get_global_rect())
	ribbon.open_list()
	view._input(_key(KEY_DOWN))
	view._input(_key(KEY_ENTER))
	assert_bool(ribbon.is_open()).is_false()
	var family: String = families[1]
	assert_str(view.pinned_family()).is_equal(family)
	assert_int(ribbon.value()).is_equal(1)
	var dimmed: int = 0
	for icon: StockIcon in book.all_icons():
		assert_bool(icon.dimmed).override_failure_message(icon.name).is_equal(
			not icon.card.tags.has(family)
		)
		dimmed += 1 if icon.dimmed else 0
	assert_int(dimmed).is_greater(0)
	for index: int in rects.size():
		assert_that(book.shown_icons()[index].get_global_rect()).is_equal(rects[index])
	# Another pick switches; Esc clears.
	ribbon.picked.emit(2)
	assert_str(view.pinned_family()).is_equal(families[2])
	view._input(_key(KEY_ESCAPE))
	assert_str(view.pinned_family()).is_empty()
	assert_int(ribbon.value()).is_equal(0)
	assert_bool(book.all_icons().any(func(icon: StockIcon) -> bool: return icon.dimmed)).is_false()
	ribbon.picked.emit(1)
	view.show_page(false)
	view.show_page(true)
	assert_str(view.pinned_family()).is_empty()
	assert_bool(book.all_icons().any(func(icon: StockIcon) -> bool: return icon.dimmed)).is_false()
	view._close()


## The book's art, its slots' sprites, badges and stickers and the ribbon stand on whole screen
## pixels at both window scales (the game lays out at 1280x720 and scales by 1 or 1.5): every
## texture is sharp-sampled at an even layout px and drawn 2 layout px (or more, a whole number of
## screen px at 1.5) an art px.
func test_the_stock_book_is_crisp_at_both_scales() -> void:
	var view: DeckView = await _open_book(LAYOUT, true)
	var book: StockBook = view.stock_book()
	var problems: PackedStringArray = PackedStringArray()
	for index: int in book.sections().size():
		book.show_section(index)
		await _frames(1)
		for rect: TextureRect in _textures(book):
			_check_texture(rect, problems)
		for control: Control in book.shown_icons() + book.tabs():
			_check_origin(control, problems)
		for icon: StockIcon in book.shown_icons():
			if icon.badge() != null:
				_check_origin(icon.badge(), problems)
	assert_array(problems).is_empty()
	view._close()


func _check_texture(rect: TextureRect, problems: PackedStringArray) -> void:
	var where: String = str(rect.get_path()).get_slice("StockBook/", 1)
	var sharp: bool = (
		rect.material == ArtStyle.pixel_material()
		or rect.has_meta(ArtStyle.LOOK_META)
		or rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	)
	if not sharp:
		problems.append("%s: not sharp-sampled" % where)
	var to_layout: Transform2D = rect.get_global_transform_with_canvas()
	var texel: Vector2 = rect.size / rect.texture.get_size() * to_layout.get_scale()
	for scale: float in SCALES:
		var origin: Vector2 = to_layout.origin * scale
		if not origin.is_equal_approx(origin.round()):
			problems.append("%s: at %s screen px (x%s)" % [where, origin, scale])
		var pixel: Vector2 = texel * scale
		if not pixel.is_equal_approx(pixel.round()) or minf(pixel.x, pixel.y) < 1.0:
			problems.append("%s: %s screen px a pixel (x%s)" % [where, pixel, scale])


func _check_origin(control: Control, problems: PackedStringArray) -> void:
	for scale: float in SCALES:
		var origin: Vector2 = control.get_global_transform_with_canvas().origin * scale
		if not origin.is_equal_approx(origin.round()):
			problems.append("%s: at %s screen px (x%s)" % [control.name, origin, scale])


func _textures(root: Node) -> Array[TextureRect]:
	var found: Array[TextureRect] = []
	for child: Node in root.get_children():
		var rect: TextureRect = child as TextureRect
		if rect != null and rect.texture != null and rect.is_visible_in_tree():
			found.append(rect)
		found.append_array(_textures(child))
	return found


## `art` (book art px) in the window's px from the book's top left `origin`.
static func _art_rect(origin: Vector2, art: Rect2i) -> Rect2:
	return Rect2(origin + Vector2(art.position) * StockBook.ART, Vector2(art.size) * StockBook.ART)


## The shift screen at `window` on a new run (a full cart of distinct items with a GOLDEN Banana
## and a BIG Milk when `full`) with the deck view open on the STOCK BOOK, past its pop-in.
func _open_book(window: Vector2, full: bool) -> DeckView:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen.start_new_run(SEED, false)
	screen._week.skip()
	if full:
		Cart._fill_distinct(screen.run)
	await _frames(3)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	await get_tree().create_timer(0.5).timeout
	await _frames(2)
	return view


static func _click(control: Control) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	control._gui_input(press)


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
