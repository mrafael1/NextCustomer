extends GdUnitTestSuite
## The deck view's family filter on the real shift screen (the cart and run info polish, play
## feedback 2026-11-12; the cart as cards, 2026-11-13): the Cart's tag chips and the Run info's
## family tiles filter the page's items (hover previews, a click pins): the Cart's cards re-packed
## from its top left (the coupons hidden), the Run info's stock icons dimmed where they stand, the
## icons never moving, at 1280x720 and 1920x1080.

const Cart := preload("res://tests/ui/deck_view_ui_test.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
## A point outside the view: the pointer on no family icon.
const OFF_VIEW := Vector2(-10, -10)

var _folder: String = ""
## The page's scroll when _assert_family_filter started: the filter never changes it.
var _scroll_at: int = 0


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The family filter (play feedback 2026-11-12) on a full cart at 1280x720 and 1920x1080: the
## pointer on a tag chip shows only its family's products (the coupons hide), packed from the
## grid's top left (CartLayout); a click pins it; another chip previews over the pin; Esc and
## closing the view clear it; the chips never move (_assert_family_filter).
func test_a_family_chip_filters_the_cart() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		Cart._fill_distinct(screen.run)
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		await get_tree().create_timer(0.4).timeout
		assert_array(view.family_icons()).is_equal(Cart._tag_chips(view))
		await _assert_family_filter(view, "cart %s" % window)


## The family filter on the Run info page at 1280x720 and 1920x1080 (the slim page fits unscrolled):
## the cart's family tiles filter the machine's stock the same way, and neither the scroll nor the
## hero's tiles move (the stock's other icons only dim), so a still pointer keeps its preview.
func test_a_family_tile_filters_the_run_info_stock() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		view.show_page(true)
		await get_tree().create_timer(0.4).timeout
		var hero: RunInfoHero = view._info_page.find_child("RunInfoHero", false, false)
		assert_array(view.family_icons()).is_equal(hero.family_tiles())
		# A family with no item in the stock filters nothing.
		view.preview_family("NoSuchFamily")
		assert_str(view.filter_family()).is_empty()
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).is_less_equal(view._scroll.size.y)
		await _settle()
		await _assert_family_filter(view, "info %s" % window)


## Nothing filters while choosing an item to remove or placing a machine prize (open_placing): no
## family can filter, and a preview, a click or the pointer's motion on a chip changes nothing.
func test_choosing_and_placing_filter_nothing() -> void:
	var screen: ShiftScreen = await _screen_at(WINDOWS[0])
	var view: DeckView = screen._deck_view
	var prize: CardDefinition = load("res://data/cards/lemon.tres")
	for placing: bool in [false, true]:
		if placing:
			view.open_placing(screen.run, "Place", prize, 1)
		else:
			view.open(screen.run, "choose", true)
		await get_tree().create_timer(0.4).timeout
		var where: String = "placing" if placing else "choosing"
		var shown: Array[StringName] = _ids(view.cells())
		var icons: Array[FamilyCount] = view.family_icons()
		assert_int(icons.size()).override_failure_message(where).is_greater(0)
		for icon: FamilyCount in icons:
			var centre: Vector2 = icon.get_global_rect().get_center()
			assert_bool(view.can_filter(icon.family)).override_failure_message(where).is_false()
			view.preview_family(icon.family)
			view.toggle_pin(icon.family)
			assert_bool(view.click_at(centre)).override_failure_message(where).is_false()
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = centre
			view._input(motion)
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = centre
			view._input(click)
			await _settle()
			assert_str(view.filter_family()).override_failure_message(where).is_empty()
			assert_str(view.pinned_family()).is_empty()
			assert_bool(icon.lit or icon.pinned).override_failure_message(where).is_false()
			assert_array(_ids(view.cells())).override_failure_message(where).is_equal(shown)
		view._close()
		await get_tree().process_frame


## Runs the family filter on `view`'s shown page (then closes it): two families on part of the
## page's items, previewed, pinned, previewed over the pin, switched, unpinned, cleared by Esc and
## by closing the view. The shown items are exactly the family's, in the page's order (the Cart's
## packed from the first card's place, the Run info's where they stood); the icons keep the rects
## they had before any filter, and the page's scroll never changes.
func _assert_family_filter(view: DeckView, where: String) -> void:
	_scroll_at = view._scroll.scroll_vertical
	var icons: Array[FamilyCount] = view.family_icons()
	var everything: Array[StringName] = _shown_ids(view)
	var origin: Vector2 = _items(view)[0].get_global_rect().position
	var items: Array[Rect2] = []
	for item: Control in _items(view):
		items.append(item.get_global_rect())
	var rects: Array[Rect2] = []
	for icon: FamilyCount in icons:
		rects.append(icon.get_global_rect())
	var picked: Array[FamilyCount] = []
	for icon: FamilyCount in icons:
		var ids: Array[StringName] = _family_ids(view, icon.family)
		if view.can_filter(icon.family) and ids.size() < everything.size():
			picked.append(icon)
	assert_int(picked.size()).override_failure_message(where).is_greater_equal(2)
	var first: FamilyCount = picked[0]
	var second: FamilyCount = picked[1]
	var first_ids: Array[StringName] = _family_ids(view, first.family)
	var second_ids: Array[StringName] = _family_ids(view, second.family)
	# The pointer on an icon previews its family; off it, every item shows again.
	view.point_at(first.get_global_rect().get_center())
	await _settle()
	assert_str(view.filter_family()).is_equal(first.family)
	assert_str(view.pinned_family()).is_empty()
	assert_bool(first.lit and not first.pinned).override_failure_message(where).is_true()
	assert_that(first.fill_color()).is_equal(FamilyCount.LIT_FILL)
	_assert_packed(view, origin, items, first_ids, rects, where)
	view.point_at(OFF_VIEW)
	await _settle()
	assert_str(view.filter_family()).is_empty()
	assert_bool(first.lit).is_false()
	_assert_still(view, rects, where)
	assert_array(_shown_ids(view)).is_equal(everything)
	# A click pins it: the pointer may leave for the items.
	assert_bool(view.click_at(first.get_global_rect().get_center())).is_true()
	view.point_at(OFF_VIEW)
	await _settle()
	assert_str(view.pinned_family()).is_equal(first.family)
	assert_bool(first.pinned and not first.lit).override_failure_message(where).is_true()
	assert_that(first.fill_color()).is_equal(FamilyCount.PINNED_FILL)
	_assert_packed(view, origin, items, first_ids, rects, where)
	# Another icon previews over the pin; leaving it returns to the pinned family.
	view.point_at(second.get_global_rect().get_center())
	await _settle()
	assert_str(view.filter_family()).is_equal(second.family)
	assert_bool(first.pinned and second.lit).is_true()
	_assert_packed(view, origin, items, second_ids, rects, where)
	view.point_at(OFF_VIEW)
	await _settle()
	assert_str(view.filter_family()).is_equal(first.family)
	_assert_packed(view, origin, items, first_ids, rects, where)
	# Clicking another icon switches the pin; clicking the pinned one unpins it.
	assert_bool(view.click_at(second.get_global_rect().get_center())).is_true()
	assert_str(view.pinned_family()).is_equal(second.family)
	assert_bool(first.pinned).is_false()
	assert_bool(view.click_at(second.get_global_rect().get_center())).is_true()
	view.point_at(OFF_VIEW)
	await _settle()
	assert_str(view.filter_family()).is_empty()
	assert_bool(second.pinned).is_false()
	_assert_still(view, rects, where)
	assert_array(_shown_ids(view)).is_equal(everything)
	# Esc clears a pin (before the pause).
	view.click_at(first.get_global_rect().get_center())
	view.point_at(OFF_VIEW)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	view._input(escape)
	await _settle()
	assert_str(view.pinned_family()).is_empty()
	_assert_still(view, rects, where)
	assert_array(_shown_ids(view)).is_equal(everything)
	# Closing the view clears it too.
	view.click_at(first.get_global_rect().get_center())
	assert_str(view.pinned_family()).is_equal(first.family)
	view._close()
	assert_str(view.pinned_family()).is_empty()
	await get_tree().process_frame


## The shown page shows exactly `ids`' items in order: on the Cart its cards packed from `origin`
## (CartLayout with no coupons), on Run info the stock's icons at their rects `items` with the
## others dimmed; the scroll and the family icons where they were (_assert_still).
func _assert_packed(
	view: DeckView,
	origin: Vector2,
	items: Array[Rect2],
	ids: Array[StringName],
	rects: Array[Rect2],
	where: String
) -> void:
	var shown: Array[StringName] = _shown_ids(view)
	assert_array(shown).override_failure_message(where).is_equal(ids)
	if view._info_page.visible:
		var icons: Array[StockIcon] = view.stock_grid().icons()
		for index: int in icons.size():
			assert_that(icons[index].get_global_rect()).is_equal(items[index])
			assert_bool(icons[index].dimmed).is_equal(not ids.has(icons[index].card.id))
	else:
		var cells: Array[DeckCell] = view.cells()
		var layout: CartLayout = CartLayout.of(cells.size(), 0, DeckView._line_width())
		var start: Vector2 = origin - layout.positions[0]
		for index: int in cells.size():
			(
				assert_vector(cells[index].get_global_rect().position)
				. override_failure_message("%s %s" % [where, shown[index]])
				. is_equal_approx(start + layout.positions[index], Vector2.ONE * 0.5)
			)
			assert_bool(cells[index].card.is_product()).is_true()
	_assert_still(view, rects, where)


## The page's scroll is still _scroll_at and its family icons still at `rects`.
func _assert_still(view: DeckView, rects: Array[Rect2], where: String) -> void:
	assert_int(view._scroll.scroll_vertical).override_failure_message(where).is_equal(_scroll_at)
	var icons: Array[FamilyCount] = view.family_icons()
	for index: int in icons.size():
		assert_that(icons[index].get_global_rect()).override_failure_message(where).is_equal(
			rects[index]
		)


## The card ids of `cells`, in order.
static func _ids(cells: Array[DeckCell]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell: DeckCell in cells:
		ids.append(cell.card.id)
	return ids


## The shown page's items: the Cart's cards, or the Run info's stock icons.
static func _items(view: DeckView) -> Array[Control]:
	var items: Array[Control] = []
	if view._info_page.visible:
		items.assign(view.stock_grid().icons())
	else:
		items.assign(view.cells())
	return items


## The card ids of the shown page's items the filter shows (on Run info: not dimmed), in order.
static func _shown_ids(view: DeckView) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: Control in _items(view):
		var icon: StockIcon = item as StockIcon
		if icon != null and not icon.dimmed:
			ids.append(icon.card.id)
		elif item is DeckCell:
			ids.append((item as DeckCell).card.id)
	return ids


## The card ids of the shown page's items `family` shows, in order: the Cart's products with its
## printed tag, the Run info's stocked cards with it.
static func _family_ids(view: DeckView, family: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: Control in _items(view):
		var card: CardDefinition = (
			(item as StockIcon).card if item is StockIcon else (item as DeckCell).card
		)
		if card.is_product() and card.tags.has(family):
			ids.append(card.id)
	return ids


## Two frames: the containers lay the rebuilt grid out.
func _settle() -> void:
	for frame: int in range(2):
		await get_tree().process_frame


func _screen_at(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for frame: int in range(2):
		await get_tree().process_frame
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	for frame: int in range(3):
		await get_tree().process_frame
	return screen


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
